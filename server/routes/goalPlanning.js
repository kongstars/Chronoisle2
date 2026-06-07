const express = require('express');
const PlanningSession = require('../models/PlanningSession');
const GoalPlanningTrace = require('../models/GoalPlanningTrace');
const { createChatCompletion, getDeepSeekModel } = require('../utils/deepseekClient');

const router = express.Router();

// 这里保留 agent 标识，仅用于日志与职责区分。
const APP_IDS = {
  clarifyGoal: 'clarifyGoal',
  goalDefiner: 'goal-definer',
  progressDesigner: 'goal-progress-designer',
  difficultyAssessor: 'goal-difficulty-assessor',
  taskPlanner: 'goal-task-planner',
  taskAtomizer: 'goal-task-atomizer',
  actionPlanner: 'goal-action-planner',
  critic: 'goal-critic'
};
const GOAL_PLANNING_MODEL = process.env.GOAL_PLANNING_MODEL || process.env.DEEPSEEK_FAST_MODEL || process.env.DEEPSEEK_MODEL || 'deepseek-v4-flash';
const GOAL_PLANNING_FAST_MODEL = process.env.GOAL_PLANNING_FAST_MODEL || process.env.DEEPSEEK_FAST_MODEL || process.env.DEEPSEEK_MODEL || 'deepseek-v4-flash';
const GOAL_PLANNING_TRACE_ENABLED = process.env.GOAL_PLANNING_TRACE_ENABLED !== 'false';
const GOAL_PLANNING_HTTP_TIMEOUT_MS = parseInt(process.env.GOAL_PLANNING_HTTP_TIMEOUT_MS || '300000', 10);
const GOAL_PLANNING_DEFAULT_TIMEOUT_MS = parseInt(process.env.GOAL_PLANNING_TIMEOUT_MS || '300000', 10);
const GOAL_PLANNING_PROGRESS_CRITIC_TIMEOUT_MS = parseInt(process.env.GOAL_PLANNING_PROGRESS_CRITIC_TIMEOUT_MS || '60000', 10);
const GOAL_PLANNING_ACTION_CRITIC_TIMEOUT_MS = parseInt(process.env.GOAL_PLANNING_ACTION_CRITIC_TIMEOUT_MS || '60000', 10);
const REFERENCE_GOAL_EXAMPLES = [
  '通过2027年软考高级项目管理师考试：典型考证类目标，难度评估要考虑基础、备考周期、投入时长、关键节点。',
  '3个月内减肥10斤：典型健康类目标，要区分饮食、训练、作息、阶段结果，不要只给一句“坚持锻炼”。',
  '每个月读完3本书：典型习惯养成类目标，既要有阅读节奏，也要有完成判定和复盘动作。',
  '今年存下10万元：典型理财类目标，要拆收入、支出、记账、阶段储蓄节点，而不是一句“提高收入”。',
  '练就一手好的毛笔字：典型长期技能兴趣目标，要拆基础、练习、作品输出和阶段评估。',
  '戒掉熬夜的习惯：典型作息改善目标，要把睡眠时间、诱因管理、晚间流程和跟踪节点拆开。'
];
const TRACK_RED_LINES = [
  '进度追踪只能用于衡量结果推进，不能写成行动清单。',
  '每条追踪必须可衡量，或有清晰完成节点。',
  '禁止空泛表达，如“提升自己”“系统学习”“养成好习惯”。',
  '不同追踪必须覆盖不同维度，避免只是换说法重复。'
];
const TASK_RED_LINES = [
  '周期类动作不能作为单次任务标题，例如“每周锻炼1次”必须进入 recurringActions。',
  '没有清晰完成动作的泛化内容不能作为任务，例如“核心概念学习”。',
  '体量过大的任务必须继续拆分，例如“完成APP开发”。',
  'oneOffTasks 必须是单次可完成任务，标题要有动作、对象，description 要写清完成标准。',
  'recurringActions 只承载每天/每周/每月重复动作。',
  'countdowns 只承载关键日期，不要拿来替代任务。'
];
const GENERIC_TASK_PATTERNS = [
  /每周.+次/,
  /每天.+/,
  /每月.+/,
  /^核心概念学习$/,
  /^完成APP开发$/,
  /^学习.+$/,
  /^提升.+$/,
  /^优化.+$/,
  /^准备.+$/,
  /^复习.+$/,
  /^练习.+$/,
  /^坚持.+$/
];

const TRACE_TEXT_LIMIT = 1200;
const TRACE_ARRAY_LIMIT = 12;
const TRACE_OBJECT_KEYS_LIMIT = 20;
const ANON_ONBOARDING_PREFIX = 'anon_onboarding_';
const ANON_WINDOW_MS = 6 * 60 * 60 * 1000;
const anonQuotaStore = new Map();

router.use((req, res, next) => {
  req.setTimeout(GOAL_PLANNING_HTTP_TIMEOUT_MS);
  res.setTimeout(GOAL_PLANNING_HTTP_TIMEOUT_MS);
  next();
});

function generateSessionId() {
  return 'ps_' + Date.now() + '_' + Math.random().toString(36).substring(2, 9);
}

function toPreviewText(value, maxLength = TRACE_TEXT_LIMIT) {
  if (value === null || value === undefined) {
    return '';
  }
  const text = typeof value === 'string' ? value : JSON.stringify(value);
  if (!text) {
    return '';
  }
  return text.length > maxLength ? `${text.slice(0, maxLength)}...(truncated)` : text;
}

function sanitizeForTrace(value, depth = 0) {
  if (value === null || value === undefined) {
    return value;
  }
  if (depth >= 4) {
    return typeof value === 'string' ? toPreviewText(value, 300) : '[max_depth_reached]';
  }
  if (typeof value === 'string') {
    return toPreviewText(value, 1000);
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return value;
  }
  if (Array.isArray(value)) {
    return value.slice(0, TRACE_ARRAY_LIMIT).map((item) => sanitizeForTrace(item, depth + 1));
  }
  if (typeof value === 'object') {
    const result = {};
    const keys = Object.keys(value).slice(0, TRACE_OBJECT_KEYS_LIMIT);
    keys.forEach((key) => {
      result[key] = sanitizeForTrace(value[key], depth + 1);
    });
    return result;
  }
  return String(value);
}

async function writeTrace(trace) {
  if (!GOAL_PLANNING_TRACE_ENABLED) {
    return;
  }
  try {
    await GoalPlanningTrace.create({
      sessionId: trace.sessionId || 'unknown',
      userId: trace.userId || 'unknown',
      traceType: trace.traceType,
      stepName: trace.stepName,
      stage: trace.stage || '',
      source: trace.source || 'unknown',
      status: trace.status || 'success',
      agentKey: trace.agentKey || '',
      model: trace.model || '',
      durationMs: Number.isFinite(trace.durationMs) ? trace.durationMs : 0,
      fallbackUsed: trace.fallbackUsed === true,
      requestPreview: toPreviewText(trace.requestPreview),
      responsePreview: toPreviewText(trace.responsePreview),
      payload: sanitizeForTrace(trace.payload),
      metrics: sanitizeForTrace(trace.metrics || {}),
      errorMessage: toPreviewText(trace.errorMessage || '', 500),
      createdAt: Date.now()
    });
  } catch (error) {
    console.warn('[goalPlanning/trace] 日志写入失败:', error.message);
  }
}

async function writeStepTrace(context, detail) {
  await writeTrace({
    traceType: 'step',
    sessionId: context?.sessionId,
    userId: context?.userId,
    stepName: detail.stepName,
    stage: detail.stage || context?.stage || '',
    source: detail.source || context?.source || 'unknown',
    status: detail.status || 'success',
    durationMs: detail.durationMs || 0,
    fallbackUsed: detail.fallbackUsed === true,
    requestPreview: detail.requestPreview,
    responsePreview: detail.responsePreview,
    payload: detail.payload,
    metrics: detail.metrics,
    errorMessage: detail.errorMessage
  });
}

function createRuntimeStatus(stage, subStepKey, subStepIndex, subStepTotal, title, description, estimatedRemainingMs = 0, startedAt = Date.now()) {
  return {
    active: true,
    stage,
    subStepKey,
    subStepIndex,
    subStepTotal,
    title,
    description,
    estimatedRemainingMs,
    startedAt,
    updatedAt: Date.now(),
    isSlow: false
  };
}

async function updateRuntimeStatus(sessionId, userId, runtimeStatus) {
  try {
    await PlanningSession.findOneAndUpdate(
      { sessionId, userId },
      { runtimeStatus: runtimeStatus ? { ...runtimeStatus, updatedAt: Date.now() } : null }
    );
  } catch (error) {
    console.warn('[goalPlanning/runtimeStatus] 更新失败:', error.message);
  }
}

async function clearRuntimeStatus(sessionId, userId) {
  await updateRuntimeStatus(sessionId, userId, null);
}

function parseTraceLimit(rawLimit) {
  const parsed = parseInt(String(rawLimit || '200'), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return 200;
  }
  return Math.min(parsed, 500);
}

function getVisitorId(req) {
  const raw = String(req.headers['x-goal-planning-visitor-id'] || '').trim();
  if (!/^[A-Za-z0-9_-]{8,80}$/.test(raw)) {
    return '';
  }
  return raw;
}

function getRequestIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim()) {
    return forwarded.split(',')[0].trim();
  }
  return req.ip || req.connection?.remoteAddress || 'unknown';
}

function checkAnonymousQuota(req, visitorId) {
  const key = `${getRequestIp(req)}|${visitorId}`;
  const now = Date.now();
  const path = req.path || '';
  let record = anonQuotaStore.get(key);
  if (!record || now - record.windowStart > ANON_WINDOW_MS) {
    record = {
      windowStart: now,
      startCount: 0,
      writeCount: 0,
      readCount: 0
    };
  }

  if (path === '/start') {
    record.startCount += 1;
    if (record.startCount > 5) {
      anonQuotaStore.set(key, record);
      return { allowed: false, message: '新手体验次数已用完，请稍后再试或登录继续使用' };
    }
  } else if (path.startsWith('/session/') || path.startsWith('/trace/')) {
    record.readCount += 1;
    if (record.readCount > 240) {
      anonQuotaStore.set(key, record);
      return { allowed: false, message: '请求过于频繁，请稍后再试' };
    }
  } else {
    record.writeCount += 1;
    if (record.writeCount > 40) {
      anonQuotaStore.set(key, record);
      return { allowed: false, message: '请求过于频繁，请稍后再试或登录继续使用' };
    }
  }

  anonQuotaStore.set(key, record);
  return { allowed: true };
}

function isAnonymousGoalPlanningAllowed(req, visitorId) {
  if (!visitorId) {
    return false;
  }

  if (req.path === '/start') {
    return req.body?.onboarding === true && req.body?.source === 'create_goal';
  }

  const allowedPaths = [
    '/clarification',
    '/progress',
    '/progress/regenerate',
    '/progress/add-track',
    '/actions',
    '/actions/regenerate',
    '/review',
    '/apply'
  ];

  if (allowedPaths.includes(req.path)) {
    return true;
  }

  return req.path.startsWith('/session/') || req.path.startsWith('/trace/');
}

function buildTraceSummary(traces) {
  const summary = {
    totalCount: traces.length,
    stepCount: 0,
    agentCount: 0,
    successCount: 0,
    failedCount: 0,
    partialCount: 0,
    fallbackCount: 0,
    totalDurationMs: 0,
    stepDurations: {},
    agentDurations: {},
    latestCreatedAt: 0
  };

  traces.forEach((trace) => {
    if (trace.traceType === 'step') {
      summary.stepCount += 1;
      summary.stepDurations[trace.stepName] = (summary.stepDurations[trace.stepName] || 0) + (trace.durationMs || 0);
    } else if (trace.traceType === 'agent') {
      summary.agentCount += 1;
      const key = trace.agentKey || 'unknown';
      summary.agentDurations[key] = (summary.agentDurations[key] || 0) + (trace.durationMs || 0);
    }

    if (trace.status === 'success') {
      summary.successCount += 1;
    } else if (trace.status === 'failed') {
      summary.failedCount += 1;
    } else {
      summary.partialCount += 1;
    }

    if (trace.fallbackUsed === true) {
      summary.fallbackCount += 1;
    }

    summary.totalDurationMs += trace.durationMs || 0;
    summary.latestCreatedAt = Math.max(summary.latestCreatedAt, trace.createdAt || 0);
  });

  return summary;
}

function checkUser(req, res, next) {
  if (req.user?.userId) {
    next();
    return;
  }

  const visitorId = getVisitorId(req);
  if (!isAnonymousGoalPlanningAllowed(req, visitorId)) {
    return res.status(401).json({ success: false, message: '请求未携带Token，请先登录' });
  }

  const quota = checkAnonymousQuota(req, visitorId);
  if (!quota.allowed) {
    return res.status(429).json({ success: false, message: quota.message });
  }

  req.user = {
    userId: `${ANON_ONBOARDING_PREFIX}${visitorId}`,
    accountType: 'anonymous_onboarding'
  };
  req.goalPlanningAnonymous = true;
  next();
}

function normalizeGoalDraft(goalDraft) {
  const safeDraft = goalDraft || {};
  return {
    title: normalizeWeightUnitMentions(safeDraft.title || '未命名目标'),
    description: normalizeWeightUnitMentions(safeDraft.description || ''),
    category: ['HEALTH', 'LEARNING', 'FINANCE', 'FUN'].includes(safeDraft.category) ? safeDraft.category : 'LEARNING',
    periodDays: Number.isFinite(safeDraft.periodDays) && safeDraft.periodDays > 0 ? safeDraft.periodDays : 90,
    goalKind: safeDraft.goalKind || 'project_oriented',
    confidence: typeof safeDraft.confidence === 'number' ? safeDraft.confidence : 0.8,
    missingFields: Array.isArray(safeDraft.missingFields) ? safeDraft.missingFields : [],
    isSimpleTask: safeDraft.isSimpleTask === true
  };
}

function formatWeightValue(value) {
  const rounded = Math.round(value * 100) / 100;
  if (Number.isInteger(rounded)) {
    return String(rounded);
  }
  if (Number.isInteger(rounded * 10)) {
    return rounded.toFixed(1).replace(/\.0$/, '');
  }
  return rounded.toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
}

function normalizeWeightUnitMentions(text = '') {
  let result = String(text || '');

  // 统一纠正 “X斤（约Ykg）” 这类表述
  result = result.replace(
    /(\d+(?:\.\d+)?)\s*斤\s*[（(]?\s*(?:约\s*)?(\d+(?:\.\d+)?)\s*(?:kg|KG|Kg|公斤)\s*[)）]?/g,
    (_, jinValue) => `${jinValue}斤（约${formatWeightValue(Number(jinValue) * 0.5)}kg）`
  );

  // 统一纠正 “Xkg（约Y斤）” 这类表述
  result = result.replace(
    /(\d+(?:\.\d+)?)\s*(?:kg|KG|Kg|公斤)\s*[（(]?\s*(?:约\s*)?(\d+(?:\.\d+)?)\s*斤\s*[)）]?/g,
    (_, kgValue) => `${formatWeightValue(Number(kgValue))}kg（约${formatWeightValue(Number(kgValue) * 2)}斤）`
  );

  return result;
}

function inferGoalCategoryFromIntent(rawIntent = '') {
  const text = String(rawIntent || '');
  if (/减肥|体重|运动|锻炼|睡眠|熬夜|健康|跑步|健身/.test(text)) {
    return 'HEALTH';
  }
  if (/存款|存下|理财|收入|支出|预算|攒钱|储蓄/.test(text)) {
    return 'FINANCE';
  }
  if (/毛笔|吉他|绘画|摄影|娱乐|兴趣|书法/.test(text)) {
    return 'FUN';
  }
  return 'LEARNING';
}

function buildFallbackGoalDraftFromIntent(rawIntent = '') {
  const intent = String(rawIntent || '').trim();
  return normalizeGoalDraft({
    title: intent || '未命名目标',
    description: intent ? `围绕“${intent}”生成的目标草案，后续会继续通过追问补充细节。` : '',
    category: inferGoalCategoryFromIntent(intent),
    periodDays: 90,
    goalKind: 'project_oriented',
    confidence: 0.45,
    missingFields: ['success_criteria', 'weekly_capacity']
  });
}

function isExplicitSimpleTaskIntent(rawIntent = '') {
  const text = String(rawIntent || '').trim();
  if (!text) {
    return false;
  }

  const explicitTaskSignals = [
    /明天|今天|下午|晚上|早上|上午|本周/,
    /^买.+/,
    /^发.+/,
    /^回复.+/,
    /^提交.+/,
    /^预约.+/,
    /^联系.+/,
    /^整理.+/,
    /^发送.+/,
    /^处理.+/,
    /^给.+/,
    /^把.+/
  ];
  if (explicitTaskSignals.some((rule) => rule.test(text))) {
    return true;
  }

  const goalSignals = [
    /\d+个?月内|\d+天内|今年|明年|本月|本季度|本年度|长期/,
    /目标|计划|习惯|坚持|提升|改善|准备|完成|通过|读完|减肥|存下|练就|戒掉/,
    /考试|考证|项目|学习|阅读|理财|健康|训练|睡眠|书法|毛笔/
  ];
  if (goalSignals.some((rule) => rule.test(text))) {
    return false;
  }

  return false;
}

function normalizeQuestion(question, index) {
  const safeType = ['single_choice', 'multi_choice', 'short_text', 'number', 'date'].includes(question?.type)
    ? question.type
    : 'short_text';
  return {
    id: question?.id || `q_${index + 1}`,
    text: question?.text || question?.label || `请补充第 ${index + 1} 个问题`,
    type: safeType,
    options: Array.isArray(question?.options) ? question.options.slice(0, 4) : undefined,
    placeholder: question?.placeholder || '请输入',
    required: question?.required !== false
  };
}

function normalizeTrack(track, index) {
  return {
    id: track?.id || `track_${index + 1}`,
    title: track?.title || `进度追踪 ${index + 1}`,
    type: ['numeric', 'frequency', 'milestone', 'delivery', 'phase'].includes(track?.type) ? track.type : 'milestone',
    targetValue: Number.isFinite(track?.targetValue) ? track.targetValue : 1,
    unit: track?.unit || '项',
    baselineValue: Number.isFinite(track?.baselineValue) ? track.baselineValue : 0,
    dueDate: Number.isFinite(track?.dueDate) ? track.dueDate : undefined,
    checkpointText: track?.checkpointText || '',
    completionCriteria: track?.completionCriteria || '达到目标值或完成该节点',
    reason: track?.reason || track?.rationale || '用于衡量目标推进情况'
  };
}

function normalizeOneOffTask(item, index) {
  return {
    id: item?.id || `task_${index + 1}`,
    title: item?.title || `起步行动 ${index + 1}`,
    description: item?.description || '',
    estimatedHours: Number.isFinite(item?.estimatedHours) ? Math.max(0.5, item.estimatedHours) : 1,
    priority: ['high', 'normal', 'low'].includes(item?.priority) ? item.priority : 'normal',
    energyLevel: ['low', 'medium', 'high'].includes(item?.energyLevel) ? item.energyLevel : 'medium',
    suggestedDueDate: Number.isFinite(item?.suggestedDueDate) ? item.suggestedDueDate : undefined,
    rationale: item?.rationale || '帮助目标快速启动'
  };
}

function normalizeRecurringAction(item, index) {
  const weekdays = Array.isArray(item?.weekdays) && item.weekdays.length > 0
    ? item.weekdays
    : Array.isArray(item?.timeParams) && item.timeParams.length > 0
      ? item.timeParams
      : [];
  return {
    id: item?.id || `recurring_${index + 1}`,
    title: item?.title || `重复行动 ${index + 1}`,
    rule: ['daily', 'weekly', 'monthly'].includes(item?.rule) ? item.rule : 'daily',
    timeParams: weekdays,
    weekdays: weekdays,
    suggestedTime: item?.suggestedTime || '',
    endDate: normalizeOptionalDateString(item?.endDate),
    rationale: item?.rationale || '适合自动化重复执行'
  };
}

function normalizeCountdown(item, index) {
  return {
    id: item?.id || `countdown_${index + 1}`,
    title: item?.title || `关键日期 ${index + 1}`,
    targetDate: normalizeDateString(item?.targetDate),
    rationale: item?.rationale || '用于提醒关键时间节点'
  };
}

function normalizeDateString(targetDate) {
  if (!targetDate) {
    const fallback = new Date();
    fallback.setDate(fallback.getDate() + 30);
    return fallback.toISOString().split('T')[0];
  }

  const parsed = new Date(targetDate);
  if (isNaN(parsed.getTime())) {
    const fallback = new Date();
    fallback.setDate(fallback.getDate() + 30);
    return fallback.toISOString().split('T')[0];
  }
  return parsed.toISOString().split('T')[0];
}

function normalizeOptionalDateString(targetDate) {
  if (!targetDate) {
    return undefined;
  }
  const parsed = new Date(targetDate);
  if (isNaN(parsed.getTime())) {
    return undefined;
  }
  return parsed.toISOString().split('T')[0];
}

function normalizeCriticIssue(issue, index, module) {
  return {
    trackId: issue?.trackId,
    module: issue?.module || module,
    severity: ['high', 'medium', 'low'].includes(issue?.severity) ? issue.severity : 'medium',
    description: issue?.description || issue?.message || `发现第 ${index + 1} 个问题`,
    suggestion: issue?.suggestion || '请根据问题调整方案'
  };
}

function normalizeAssessment(assessment, goalDraft) {
  const safeLevel = ['easy', 'moderate', 'hard', 'very_hard'].includes(assessment?.level)
    ? assessment.level
    : 'moderate';
  const fallbackTrackCount = safeLevel === 'easy'
    ? 2
    : safeLevel === 'moderate'
      ? 3
      : safeLevel === 'hard'
        ? 5
        : 6;

  return {
    level: safeLevel,
    score: Number.isFinite(assessment?.score) ? assessment.score : (safeLevel === 'easy' ? 30 : safeLevel === 'moderate' ? 55 : safeLevel === 'hard' ? 75 : 90),
    summary: assessment?.summary || `当前目标在 ${goalDraft?.periodDays || 90} 天周期下难度为${safeLevel}`,
    reasons: Array.isArray(assessment?.reasons) && assessment.reasons.length > 0 ? assessment.reasons.slice(0, 5) : ['当前时间要求与目标体量需要进一步评估'],
    riskTips: Array.isArray(assessment?.riskTips) ? assessment.riskTips.slice(0, 4) : [],
    recommendedTrackCount: Number.isFinite(assessment?.recommendedTrackCount) && assessment.recommendedTrackCount > 0
      ? Math.min(Math.max(assessment.recommendedTrackCount, 1), 8)
      : fallbackTrackCount,
    shouldReviseGoal: assessment?.shouldReviseGoal === true || safeLevel === 'hard' || safeLevel === 'very_hard',
    blockingWarning: assessment?.blockingWarning || (safeLevel === 'hard' || safeLevel === 'very_hard'
      ? '当前目标难度偏高，建议先回到第一步缩小范围、拉长期限或聚焦更具体结果。'
      : '')
  };
}

function buildClarificationSummary(questions, answers) {
  if (!questions || questions.length === 0) {
    return '用户未提供额外背景信息';
  }
  return questions.map((question) => {
    const answer = answers && answers[question.id] ? answers[question.id] : '未回答';
    return `${question.text} -> ${answer}`;
  }).join('；');
}

function buildTracksSummary(tracks) {
  if (!tracks || tracks.length === 0) {
    return '暂无进度追踪';
  }
  return tracks.map((track) => {
    return `- ${track.title}（类型:${track.type}，目标:${track.targetValue}${track.unit}，完成标准:${track.completionCriteria}）`;
  }).join('\n');
}

function buildCompactAssessmentSummary(assessment) {
  if (!assessment) {
    return '暂无，按中等难度处理';
  }
  return [
    `level=${assessment.level || 'moderate'}`,
    `score=${assessment.score || 0}`,
    `recommendedTrackCount=${assessment.recommendedTrackCount || 0}`,
    `shouldReviseGoal=${assessment.shouldReviseGoal === true}`,
    `summary=${assessment.summary || ''}`
  ].join('; ');
}

function buildDraftTasksSummary(draftTasks) {
  if (!Array.isArray(draftTasks) || draftTasks.length === 0) {
    return '暂无行动草案';
  }
  return draftTasks.slice(0, 18).map((task, index) => {
    const title = task?.title || `草案${index + 1}`;
    const kind = task?.kind || 'oneoff';
    const description = task?.description || '';
    return `${index + 1}. [${kind}] ${title}｜${description}`;
  }).join('\n');
}

function buildFallbackProgressTracks(session, assessment) {
  const category = session?.goalDraft?.category || 'LEARNING';
  const targetCount = Math.max(1, assessment?.recommendedTrackCount || 3);
  const trackPoolByCategory = {
    HEALTH: [
      {
        title: '核心健康结果达成',
        type: 'numeric',
        targetValue: 10,
        unit: '斤',
        completionCriteria: '达到目标体重变化或完成约定的健康结果',
        checkpointText: '按阶段记录关键健康结果变化',
        reason: '先用最终结果衡量目标是否真正达成'
      },
      {
        title: '计划执行频次',
        type: 'frequency',
        targetValue: 12,
        unit: '次',
        completionCriteria: '按计划完成训练、饮食或作息执行次数',
        checkpointText: '每周检查执行连续性',
        reason: '执行频次决定健康目标是否能稳定推进'
      },
      {
        title: '阶段节点达成',
        type: 'milestone',
        targetValue: 3,
        unit: '个节点',
        completionCriteria: '完成阶段性复盘并确认当前策略有效',
        checkpointText: '启动期、推进期、冲刺期各完成一次检查',
        reason: '阶段节点能帮助及时纠偏'
      }
    ],
    FINANCE: [
      {
        title: '累计储蓄金额',
        type: 'numeric',
        targetValue: 100000,
        unit: '元',
        completionCriteria: '累计储蓄达到目标金额',
        checkpointText: '按月检查累计储蓄进度',
        reason: '金额结果是理财目标最直接的衡量方式'
      },
      {
        title: '月度结余达成次数',
        type: 'frequency',
        targetValue: 12,
        unit: '月',
        completionCriteria: '每个月都达到当月储蓄或结余目标',
        checkpointText: '每月月底复盘一次',
        reason: '月度结余决定全年储蓄结果'
      },
      {
        title: '支出控制节点',
        type: 'milestone',
        targetValue: 3,
        unit: '个节点',
        completionCriteria: '完成预算建立、执行复盘和关键修正节点',
        checkpointText: '至少完成 3 次阶段性预算校准',
        reason: '控制支出是理财目标的重要抓手'
      }
    ],
    FUN: [
      {
        title: '作品输出数量',
        type: 'numeric',
        targetValue: 6,
        unit: '份',
        completionCriteria: '按阶段完成可展示的作品或成果',
        checkpointText: '每个阶段至少产出一份可留存成果',
        reason: '兴趣技能类目标要有可见成果沉淀'
      },
      {
        title: '有效练习频次',
        type: 'frequency',
        targetValue: 24,
        unit: '次',
        completionCriteria: '完成有记录、有主题的有效练习次数',
        checkpointText: '每周检查练习节奏',
        reason: '持续练习是兴趣技能成长的基础'
      },
      {
        title: '阶段能力节点',
        type: 'milestone',
        targetValue: 3,
        unit: '个节点',
        completionCriteria: '完成基础、进阶、展示三个阶段节点',
        checkpointText: '按阶段验证是否达到预期能力水平',
        reason: '阶段节点能帮助判断是否真正进步'
      }
    ],
    LEARNING: [
      {
        title: '核心学习成果达成',
        type: 'milestone',
        targetValue: 3,
        unit: '个节点',
        completionCriteria: '完成关键学习阶段或通过阶段性验收',
        checkpointText: '完成基础、强化、冲刺三个阶段',
        reason: '成长类目标需要明确阶段性成果'
      },
      {
        title: '高质量学习频次',
        type: 'frequency',
        targetValue: 24,
        unit: '次',
        completionCriteria: '完成有记录、有产出的高质量学习次数',
        checkpointText: '每周复盘学习完成情况',
        reason: '稳定投入频次决定目标推进速度'
      },
      {
        title: '阶段测验或输出完成',
        type: 'delivery',
        targetValue: 3,
        unit: '次',
        completionCriteria: '完成阶段测试、总结输出或成果交付',
        checkpointText: '至少完成 3 次阶段性验证',
        reason: '输出或测验能检验是否真正掌握'
      }
    ]
  };

  const pool = trackPoolByCategory[category] || trackPoolByCategory.LEARNING;
  const fallbackTracks = [];
  for (let i = 0; i < Math.min(targetCount, pool.length); i++) {
    fallbackTracks.push(normalizeTrack(pool[i], i));
  }
  return fallbackTracks;
}

function hasUsableTracks(tracks) {
  if (!Array.isArray(tracks) || tracks.length === 0) {
    return false;
  }
  return tracks.some((track) => {
    const title = (track?.title || '').trim();
    return title.length > 0 && !/^进度追踪 \d+$/.test(title);
  });
}

function buildActionSummary(actionPlan) {
  const lines = [];
  (actionPlan?.oneOffTasks || []).forEach((task) => lines.push(`[一次性] ${task.title}`));
  (actionPlan?.recurringActions || []).forEach((task) => lines.push(`[重复:${task.rule}] ${task.title}`));
  (actionPlan?.countdowns || []).forEach((item) => lines.push(`[倒计时] ${item.title} - ${item.targetDate}`));
  return lines.length > 0 ? lines.join('\n') : '暂无行动方案';
}

function buildDifficultyInstruction(assessment) {
  if (!assessment) {
    return '默认按中等难度处理，建议生成 3-4 条进度追踪。';
  }
  return `当前难度评估：${assessment.level}，建议进度追踪数量 ${assessment.recommendedTrackCount} 条。` +
    (assessment.shouldReviseGoal ? '该目标偏难，需提醒用户可返回修改目标。' : '');
}

function buildReferenceExampleText() {
  return REFERENCE_GOAL_EXAMPLES.map((item, index) => `${index + 1}. ${item}`).join('\n');
}

function buildRuleText(rules) {
  return rules.map((item, index) => `${index + 1}. ${item}`).join('\n');
}

function buildCriticFeedbackText(issues) {
  if (!Array.isArray(issues) || issues.length === 0) {
    return '无';
  }
  return issues.map((issue, index) => {
    const severity = issue?.severity || 'medium';
    const description = issue?.description || '存在质量问题';
    const suggestion = issue?.suggestion || '请修正';
    return `${index + 1}. [${severity}] ${description}；修正建议：${suggestion}`;
  }).join('\n');
}

function hasHighSeverityIssues(issues) {
  return Array.isArray(issues) && issues.some((issue) => issue?.severity === 'high');
}

function buildUserFacingProgressIssues(criticIssues = [], tracks = []) {
  const validTracks = Array.isArray(tracks) ? tracks : [];
  return (Array.isArray(criticIssues) ? criticIssues : []).map((issue, index) => {
    const safeDescription = String(issue?.description || '');
    const safeSuggestion = String(issue?.suggestion || '');
    const safeText = `${safeDescription}\n${safeSuggestion}`;
    const targetTrack = issue?.trackId
      ? validTracks.find((track) => track.id === issue.trackId)
      : validTracks[index];
    const targetTrackId = targetTrack?.id;

    if (/baselineValue|基线值|起始值|起点|首周|真实首值/i.test(safeText)) {
      return {
        id: `ufi_${index + 1}`,
        kind: 'missing_baseline',
        severity: issue?.severity || 'medium',
        title: '这个进度指标缺少明确起点',
        reason: '如果没有真实起始值，后续完成度会失真，进度条也会不准确。',
        suggestion: '补充当前真实数值，系统会据此修正这条追踪。',
        targetTrackId,
        inputMode: 'number',
        inputLabel: targetTrack ? `请补充“${targetTrack.title}”的当前真实数值` : '请补充当前真实数值',
        inputPlaceholder: '请输入数字',
        impactScope: 'track_only',
        aiHint: '请保留现有追踪标题与目标值，但去掉不可靠的默认起始值，改成可测量且与完成标准一致的真实起点表达。'
      };
    }

    if (/completionCriteria|设备|平台|测量|记录|心率|校准|标准/i.test(safeText)) {
      return {
        id: `ufi_${index + 1}`,
        kind: 'unclear_measurement',
        severity: issue?.severity || 'medium',
        title: '这个指标的记录方式还不够清晰',
        reason: '如果测量设备、记录口径或判定标准不统一，后续进度会不准确。',
        suggestion: '补充你打算如何记录，AI 会把这条追踪改写得更清楚。',
        targetTrackId,
        inputMode: 'short_text',
        inputLabel: targetTrack ? `你打算怎样记录“${targetTrack.title}”？` : '你打算怎样记录这个指标？',
        inputPlaceholder: '例如：使用华为运动健康，每周日晚记录一次',
        impactScope: 'track_only',
        aiHint: '请把这条追踪改写成用户能稳定记录的衡量方式，明确统一的设备、平台或记录口径，避免模糊标准。'
      };
    }

    if (/checkpointText|阶段|节点|中间检查|前两次|最终日期|阶段性/i.test(safeText)) {
      return {
        id: `ufi_${index + 1}`,
        kind: 'checkpoint_conflict',
        severity: issue?.severity || 'medium',
        title: '这条追踪的阶段节点还不够清楚',
        reason: '如果只有最终结果，没有中间检查点，用户会难以判断自己是否真的在推进。',
        suggestion: '补充你希望的阶段节奏，系统会把这条追踪改成更清晰的节点型表达。',
        targetTrackId,
        inputMode: 'short_text',
        inputLabel: targetTrack ? `你希望“${targetTrack.title}”按什么节奏检查？` : '你希望按什么节奏检查这条追踪？',
        inputPlaceholder: '例如：每月检查一次，分基础、强化、冲刺三个阶段',
        impactScope: 'progress',
        aiHint: '请把这条追踪改成按阶段可检查的节点，checkpointText 与 completionCriteria 保持一致，并给出清晰的阶段完成标准。'
      };
    }

    return {
      id: `ufi_${index + 1}`,
      kind: 'generic_improvement',
      severity: issue?.severity || 'medium',
      title: '这条进度追踪还可以更清晰',
      reason: safeDescription || '当前表达还不够稳定，后续可能影响进度判断。',
      suggestion: '你可以让 AI 自动修正，或手动补充一条更明确的说明。',
      targetTrackId,
      inputMode: 'short_text',
      inputLabel: targetTrack ? `你希望“${targetTrack.title}”如何衡量得更清楚？` : '你希望这条追踪如何表达得更清楚？',
      inputPlaceholder: '请输入你希望补充的信息',
      impactScope: 'track_only',
      aiHint: safeSuggestion || '请把这条追踪改成更清晰、可测量、可执行的表达。'
    };
  });
}

function resolveAgentModel(agentKey) {
  const overrideMap = {
    [APP_IDS.goalDefiner]: process.env.GOAL_PLANNING_GOAL_DEFINER_MODEL,
    [APP_IDS.clarifyGoal]: process.env.GOAL_PLANNING_CLARIFY_MODEL,
    [APP_IDS.difficultyAssessor]: process.env.GOAL_PLANNING_DIFFICULTY_MODEL,
    [APP_IDS.progressDesigner]: process.env.GOAL_PLANNING_PROGRESS_MODEL,
    [APP_IDS.taskPlanner]: process.env.GOAL_PLANNING_TASK_PLANNER_MODEL,
    [APP_IDS.taskAtomizer]: process.env.GOAL_PLANNING_TASK_ATOMIZER_MODEL,
    [APP_IDS.actionPlanner]: process.env.GOAL_PLANNING_ACTION_MODEL,
    [APP_IDS.critic]: process.env.GOAL_PLANNING_CRITIC_MODEL
  };

  if (overrideMap[agentKey]) {
    return overrideMap[agentKey];
  }

  if (
    agentKey === APP_IDS.goalDefiner ||
    agentKey === APP_IDS.clarifyGoal ||
    agentKey === APP_IDS.critic
  ) {
    return GOAL_PLANNING_FAST_MODEL;
  }

  return GOAL_PLANNING_MODEL;
}

function resolveAgentTimeoutMs(agentKey, traceContext = {}) {
  const explicitTimeout = parseInt(String(traceContext?.timeoutMs || '0'), 10);
  if (Number.isFinite(explicitTimeout) && explicitTimeout > 0) {
    return explicitTimeout;
  }

  if (agentKey === APP_IDS.critic) {
    if (traceContext?.stepName === 'progress') {
      return GOAL_PLANNING_PROGRESS_CRITIC_TIMEOUT_MS;
    }
    if (traceContext?.stepName === 'actions') {
      return GOAL_PLANNING_ACTION_CRITIC_TIMEOUT_MS;
    }
  }

  return GOAL_PLANNING_DEFAULT_TIMEOUT_MS;
}

function padDatePart(value) {
  return String(value).padStart(2, '0');
}

function buildCurrentDateContext(nowMs = Date.now()) {
  const now = new Date(nowMs);
  const localDate = `${now.getFullYear()}-${padDatePart(now.getMonth() + 1)}-${padDatePart(now.getDate())}`;
  const localTime = `${padDatePart(now.getHours())}:${padDatePart(now.getMinutes())}:${padDatePart(now.getSeconds())}`;
  const weekday = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][now.getDay()];
  return {
    nowMs,
    localDate,
    localTime,
    weekday,
    localDateTime: `${localDate} ${localTime}`
  };
}

function buildCurrentDatePrompt(nowMs = Date.now()) {
  const current = buildCurrentDateContext(nowMs);
  return `【当前时间锚点】
- 当前日期：${current.localDate} ${current.weekday}
- 当前时间：${current.localTime}
- 当前时间戳：${current.nowMs}
- 你必须严格以以上当前日期为准，不要假设现在是 2024 年，也不要使用训练数据中的过期年份作为“今天”。`;
}

function buildDifficultyPrompt(goalDraft, clarificationSummary, nowMs = Date.now()) {
  return `你是一个专业的 Difficulty Assessor Agent。
请基于目标、时间要求、用户基础、投入能力和限制条件，评估该目标的现实难度。

规则：
1. 难度等级只能是 easy / moderate / hard / very_hard
2. 必须真实评估，不要为了鼓励用户而降低难度
3. recommendedTrackCount 必须和难度匹配：
   - easy: 1-2
   - moderate: 2-4
   - hard: 4-6
   - very_hard: 5-8
4. hard 或 very_hard 时，shouldReviseGoal 必须优先考虑为 true
5. 如果目标过大、周期过短、投入不足，要在 blockingWarning 中明确提醒
6. 高难度目标不要直接拦截，要提醒现实难度，并允许用户继续创建或返回修改目标

参考样本：
${buildReferenceExampleText()}

${buildCurrentDatePrompt(nowMs)}

【目标】${goalDraft.title}
【描述】${goalDraft.description}
【周期】${goalDraft.periodDays}天
【补充信息】${clarificationSummary}

仅输出纯 JSON：
{
  "level": "moderate",
  "score": 58,
  "summary": "一句话说明难度判断",
  "reasons": ["原因1", "原因2"],
  "riskTips": ["风险1"],
  "recommendedTrackCount": 3,
  "shouldReviseGoal": false,
  "blockingWarning": ""
}`;
}

function buildKrPlannerPrompt(goalDraft, clarificationSummary, assessment, criticIssues = [], nowMs = Date.now()) {
  return `你是一个专业的 KR Planner Agent。
请基于目标、补充信息和难度评估，只输出进度追踪。

硬约束：
${buildRuleText(TRACK_RED_LINES)}
5. 采用双轨制，进度追踪与行动清单解耦
6. 进度追踪数量必须严格受 recommendedTrackCount 约束，不能固定套路
7. 如果目标是 hard 或 very_hard，允许生成更多追踪，但仍需围绕关键维度，不要灌水

参考样本：
${buildReferenceExampleText()}

${buildCurrentDatePrompt(nowMs)}

【目标】${goalDraft.title}
【描述】${goalDraft.description}
【周期】${goalDraft.periodDays}天
【补充信息】${clarificationSummary}
【难度评估】${JSON.stringify(assessment)}
【上一轮 Critic 问题】
${buildCriticFeedbackText(criticIssues)}

仅输出纯 JSON：
{
  "tracks": [
    {
      "id": "track_1",
      "title": "追踪标题",
      "type": "frequency",
      "targetValue": 12,
      "unit": "次",
      "baselineValue": 0,
      "completionCriteria": "如何判断完成",
      "checkpointText": "阶段检查点",
      "reason": "为什么用它衡量"
    }
  ]
}`;
}

function buildTaskPlannerPrompt(session, criticIssues = [], nowMs = Date.now()) {
  return `你是一个专业的 Task Planner Agent。
请基于目标、难度和进度追踪，先生成“行动草案”，而不是最终原子任务。

规则：
1. 这里输出的是 draftTasks，不是最终 oneOffTasks
2. 动作应覆盖启动、推进、复盘、关键交付
3. 数量不设上限，但必须与目标复杂度匹配
4. 重复行为可以先保留在草案中，后续会由原子化 Agent 进一步处理
5. 草案本身也不能过泛，禁止只写“学习相关知识”“进行练习”“持续优化”
6. 如果是高难度目标，草案应更充分地覆盖基础准备、关键节点、查漏补缺和验收动作

任务红线：
${buildRuleText(TASK_RED_LINES)}

参考样本：
${buildReferenceExampleText()}

${buildCurrentDatePrompt(nowMs)}

【目标】${session.goalDraft.title}
【描述】${session.goalDraft.description}
【周期】${session.goalDraft.periodDays}天
【难度评估】${JSON.stringify(session.goalAssessment)}
【补充信息】${buildClarificationSummary(session.clarification?.questions || [], session.clarification?.answers || {})}
【进度追踪】
${buildTracksSummary(session.progressPlan?.tracks || [])}
【上一轮 Critic 问题】
${buildCriticFeedbackText(criticIssues)}

仅输出纯 JSON：
{
  "draftTasks": [
    {
      "title": "行动草案标题",
      "description": "草案说明",
      "kind": "oneoff"
    }
  ]
}`;
}

function buildTaskAtomizerPrompt(session, draftTasks, nowMs, todayStr, endDateMs, endDateStr, criticIssues = []) {
  return `你是一个专业的 Task Atomizer Agent。
只输出 oneOffTasks；不要输出 recurringActions，不要输出 countdowns。

硬约束：
1. ${TASK_RED_LINES[0]}
2. ${TASK_RED_LINES[1]}
3. ${TASK_RED_LINES[2]}
4. ${TASK_RED_LINES[3]}
5. suggestedDueDate 必须分散，不要堆在同一天
6. description 必须写清“具体动作 + 完成标准”
7. 数量按目标复杂度充分拆解，但保持可执行

${buildCurrentDatePrompt(nowMs)}

【时间】
- today=${todayStr} (${nowMs})
- endDate=${endDateStr} (${endDateMs})

【目标】${session.goalDraft.title}
【描述】${session.goalDraft.description}
【难度评估】${buildCompactAssessmentSummary(session.goalAssessment)}
【补充信息】${buildClarificationSummary(session.clarification?.questions || [], session.clarification?.answers || {})}
【进度追踪】
${buildTracksSummary(session.progressPlan?.tracks || [])}
【行动草案】
${buildDraftTasksSummary(draftTasks)}
【上一轮 Critic 问题】
${buildCriticFeedbackText(criticIssues)}

仅输出纯 JSON：
{
  "oneOffTasks": [
    {
      "id": "task_1",
      "title": "单次可完成任务",
      "description": "具体动作与完成标准",
      "estimatedHours": 1,
      "priority": "high",
      "energyLevel": "medium",
      "suggestedDueDate": ${nowMs + 3 * 86400000},
      "rationale": "为什么这一步重要"
    }
  ]
}`;
}

function buildAutomationPrompt(session, draftTasks, nowMs, todayStr, endDateMs, endDateStr, criticIssues = []) {
  return `你是一个专业的 Automation Planner Agent。
只输出 recurringActions、countdowns、focusSuggestions；不要输出 oneOffTasks。

规则：
1. recurringActions 只承载每天/每周/每月重复动作
2. countdowns 只承载关键日期，不要放普通任务
3. recurringActions 标题要具体
4. weekdays 用 0-6 数组，suggestedTime 用 HH:mm，无法判断可留空
5. 周期类/习惯养成类动作如果能从目标、补充信息或动作语义中判断出结束日期，必须填 endDate，格式为 YYYY-MM-DD；例如“连续30天”“到考试前”“坚持到月底”。无法可靠判断时可留空，不要编造
6. 自动化项数量适中，只保留高频、稳定、值得提醒的内容

${buildCurrentDatePrompt(nowMs)}

【时间】
- today=${todayStr} (${nowMs})
- endDate=${endDateStr} (${endDateMs})

【目标】${session.goalDraft.title}
【描述】${session.goalDraft.description}
【难度评估】${buildCompactAssessmentSummary(session.goalAssessment)}
【补充信息】${buildClarificationSummary(session.clarification?.questions || [], session.clarification?.answers || {})}
【进度追踪】
${buildTracksSummary(session.progressPlan?.tracks || [])}
【行动草案】
${buildDraftTasksSummary(draftTasks)}
【上一轮 Critic 问题】
${buildCriticFeedbackText(criticIssues)}

仅输出纯 JSON：
{
  "recurringActions": [
    {
      "id": "recurring_1",
      "title": "明确重复动作",
      "rule": "weekly",
      "timeParams": [1, 3, 5],
      "weekdays": [1, 3, 5],
      "suggestedTime": "20:00",
      "endDate": "${endDateStr}",
      "rationale": "为什么要重复"
    }
  ],
  "countdowns": [
    {
      "id": "countdown_1",
      "title": "关键日期",
      "targetDate": "${endDateStr}",
      "rationale": "为什么重要"
    }
  ],
  "focusSuggestions": [
    "自动化建议"
  ]
}`;
}

function isGenericTaskTitle(title) {
  const safeTitle = (title || '').trim();
  if (!safeTitle) return true;
  return GENERIC_TASK_PATTERNS.some((pattern) => pattern.test(safeTitle));
}

function buildTaskQualityIssues(actionPlan) {
  const issues = [];
  (actionPlan.oneOffTasks || []).forEach((task, index) => {
    if (isGenericTaskTitle(task.title)) {
      issues.push({
        severity: 'high',
        module: 'actions',
        description: `第 ${index + 1} 个一次性任务标题仍然过泛：${task.title}`,
        suggestion: '需要拆成单次可完成的任务，或改为周期提醒'
      });
    }
  });

  const dueDateCounter = new Map();
  (actionPlan.oneOffTasks || []).forEach((task) => {
    if (!Number.isFinite(task.suggestedDueDate)) {
      return;
    }
    const day = new Date(task.suggestedDueDate).toISOString().split('T')[0];
    dueDateCounter.set(day, (dueDateCounter.get(day) || 0) + 1);
  });
  dueDateCounter.forEach((count, day) => {
    if (count > 2) {
      issues.push({
        severity: 'medium',
        module: 'actions',
        description: `存在任务日期堆叠，${day} 安排了 ${count} 个一次性任务`,
        suggestion: '需要将一次性任务分散到整个目标周期内'
      });
    }
  });

  return issues;
}

async function runDifficultyAssessment(session, answers, traceContext = {}) {
  const clarificationSummary = buildClarificationSummary(session.clarification?.questions || [], answers || {});
  const prompt = buildDifficultyPrompt(session.goalDraft, clarificationSummary, Date.now());
  const result = await safeCallAgent(prompt, APP_IDS.difficultyAssessor, {
    ...traceContext,
    stepName: 'progress',
    stage: 'progress'
  });
  return normalizeAssessment(result, session.goalDraft);
}

async function runKrPlanning(session, assessment, answers, criticIssues = [], traceContext = {}) {
  const clarificationSummary = buildClarificationSummary(session.clarification?.questions || [], answers || {});
  const prompt = buildKrPlannerPrompt(session.goalDraft, clarificationSummary, assessment, criticIssues, Date.now());
  const result = await safeCallAgent(prompt, APP_IDS.progressDesigner, {
    ...traceContext,
    stepName: 'progress',
    stage: 'progress'
  });
  let tracks = Array.isArray(result?.tracks) ? result.tracks.map(normalizeTrack) : [];
  let fallbackUsed = false;
  if (!hasUsableTracks(tracks)) {
    tracks = buildFallbackProgressTracks(session, assessment);
    fallbackUsed = true;
  }
  const expectedTrackCount = Math.max(1, assessment?.recommendedTrackCount || 1);
  if (tracks.length > expectedTrackCount) {
    tracks = tracks.slice(0, expectedTrackCount);
  }
  return {
    tracks,
    confidence: typeof result?.confidence === 'number' ? result.confidence : 0.85,
    criticPassed: true,
    criticIssues: [],
    assessment,
    fallbackUsed
  };
}

async function runTaskPlanning(session, criticIssues = [], traceContext = {}) {
  const prompt = buildTaskPlannerPrompt(session, criticIssues, Date.now());
  const result = await safeCallAgent(prompt, APP_IDS.taskPlanner, {
    ...traceContext,
    stepName: 'actions',
    stage: 'actions'
  });
  return Array.isArray(result?.draftTasks) ? result.draftTasks : [];
}

function buildFallbackDraftTasks(session) {
  const tracks = session.progressPlan?.tracks || [];
  if (tracks.length === 0) {
    return [{
      title: `为“${session.goalDraft.title}”制定第一阶段执行清单`,
      description: '整理起步动作、关键资源和阶段安排，形成可执行清单',
      kind: 'oneoff'
    }];
  }
  return tracks.map((track, index) => ({
    title: `围绕“${track.title}”安排第 ${index + 1} 个执行块`,
    description: `根据追踪“${track.title}”补齐准备、执行和复盘动作`,
    kind: 'oneoff'
  }));
}

async function runTaskAtomization(session, draftTasks, criticIssues = [], traceContext = {}) {
  const nowMs = Date.now();
  const todayStr = new Date(nowMs).toISOString().split('T')[0];
  const periodDays = session.goalDraft.periodDays || 90;
  const endDateMs = nowMs + periodDays * 86400000;
  const endDateStr = new Date(endDateMs).toISOString().split('T')[0];
  const prompt = buildTaskAtomizerPrompt(session, draftTasks, nowMs, todayStr, endDateMs, endDateStr, criticIssues);
  const result = await safeCallAgent(prompt, APP_IDS.taskAtomizer, {
    ...traceContext,
    stepName: 'actions',
    stage: 'actions',
    extra: {
      ...(traceContext?.extra || {}),
      branch: 'one_off_tasks'
    }
  });
  return {
    oneOffTasks: Array.isArray(result?.oneOffTasks) ? result.oneOffTasks.map(normalizeOneOffTask) : [],
    recurringActions: [],
    countdowns: [],
    focusSuggestions: []
  };
}

async function runAutomationPlanning(session, draftTasks, criticIssues = [], traceContext = {}) {
  const nowMs = Date.now();
  const todayStr = new Date(nowMs).toISOString().split('T')[0];
  const periodDays = session.goalDraft.periodDays || 90;
  const endDateMs = nowMs + periodDays * 86400000;
  const endDateStr = new Date(endDateMs).toISOString().split('T')[0];
  const prompt = buildAutomationPrompt(session, draftTasks, nowMs, todayStr, endDateMs, endDateStr, criticIssues);
  const result = await safeCallAgent(prompt, APP_IDS.actionPlanner, {
    ...traceContext,
    stepName: 'actions',
    stage: 'actions',
    extra: {
      ...(traceContext?.extra || {}),
      branch: 'automation'
    }
  });
  return {
    recurringActions: Array.isArray(result?.recurringActions) ? result.recurringActions.map(normalizeRecurringAction) : [],
    countdowns: Array.isArray(result?.countdowns) ? result.countdowns.map(normalizeCountdown) : [],
    focusSuggestions: Array.isArray(result?.focusSuggestions) ? result.focusSuggestions : []
  };
}

function buildFallbackActionPlan(session, draftTasks) {
  const nowMs = Date.now();
  const periodDays = Math.max(1, session.goalDraft.periodDays || 90);
  const endDateMs = nowMs + periodDays * 86400000;
  const endDateStr = new Date(endDateMs).toISOString().split('T')[0];
  const sourceDrafts = Array.isArray(draftTasks) && draftTasks.length > 0
    ? draftTasks
    : buildFallbackDraftTasks(session);
  const taskCount = Math.max(1, Math.min(sourceDrafts.length, 6));
  const spacingDays = Math.max(1, Math.floor(periodDays / (taskCount + 1)));

  const oneOffTasks = sourceDrafts.slice(0, taskCount).map((task, index) => normalizeOneOffTask({
    id: `fallback_task_${index + 1}`,
    title: task?.title || `起步行动 ${index + 1}`,
    description: task?.description || `围绕“${session.goalDraft.title}”补齐第 ${index + 1} 个关键动作，并完成一次可验证输出。`,
    estimatedHours: Number.isFinite(task?.estimatedHours) ? task.estimatedHours : 1.5,
    priority: index < 2 ? 'high' : 'normal',
    energyLevel: index < 2 ? 'high' : 'medium',
    suggestedDueDate: nowMs + Math.min(periodDays, (index + 1) * spacingDays) * 86400000,
    rationale: '兜底生成的可执行起步动作，用于避免行动方案为空'
  }, index));

  const countdowns = periodDays >= 30
    ? [normalizeCountdown({
      id: 'fallback_countdown_1',
      title: `${session.goalDraft.title}截止检查`,
      targetDate: endDateStr,
      rationale: '兜底生成的目标截止提醒，避免关键日期缺失'
    }, 0)]
    : [];

  return {
    oneOffTasks,
    recurringActions: [],
    countdowns,
    focusSuggestions: [
      '先完成前 1-2 个起步动作，再根据进度追踪逐步推进。',
      '如果后续需要更细的自动化提醒，可在行动页手动补充或局部重生成。'
    ]
  };
}

function buildAgentSystemPrompt(agentKey) {
  const common = '你是四时清单的 AI 目标规划助手。你必须只输出纯 JSON，禁止 markdown，禁止解释过程，禁止输出无关文案。';
  switch (agentKey) {
    case APP_IDS.goalDefiner:
      return `${common} 你当前负责目标理解与目标定义，输出简洁、准确、可规划的目标草案。`;
    case APP_IDS.clarifyGoal:
      return `${common} 你当前负责补充信息收集，问题必须为后续难度评估、KR 设计和任务拆解服务。`;
    case APP_IDS.difficultyAssessor:
      return `${common} 你当前负责目标难度评估。必须真实判断目标在当前周期内是否过高，并给出 recommendedTrackCount 与 shouldReviseGoal。`;
    case APP_IDS.progressDesigner:
      return `${common} 你当前负责进度追踪设计。必须依据难度决定追踪数量，禁止固定套路，禁止空泛。`;
    case APP_IDS.taskPlanner:
      return `${common} 你当前负责生成任务草案。你输出的是待进一步原子化的行动草案，不是最终任务。`;
    case APP_IDS.taskAtomizer:
      return `${common} 你当前只负责一次性任务原子化。必须把泛化任务拆成单次可完成任务，不要输出重复动作和倒计时。`;
    case APP_IDS.actionPlanner:
      return `${common} 你当前负责自动化方案生成。只输出 recurringActions、countdowns 和必要的 focusSuggestions，不要输出 oneOffTasks。`;
    case APP_IDS.critic:
      return `${common} 你当前负责质量审查，只发现问题，不生产内容。`;
    default:
      return common;
  }
}

async function callDeepSeekAgent(prompt, agentKey, model = resolveAgentModel(agentKey), traceContext = {}) {
  const startedAt = Date.now();
  let output = '';
  const timeoutMs = resolveAgentTimeoutMs(agentKey, traceContext);
  const resolvedModel = getDeepSeekModel(model);

  try {
    const completion = await createChatCompletion({
      model: resolvedModel,
      temperature: 0.2,
      timeoutMs,
      traceLabel: `goalPlanning.${agentKey}`,
      messages: [
        {
          role: 'system',
          content: buildAgentSystemPrompt(agentKey)
        },
        {
          role: 'user',
          content: prompt
        }
      ]
    });

    output = completion.content || '';
    let text = output.replace(/```json/gi, '').replace(/```/g, '').trim();
    const arrayStart = text.indexOf('[');
    const arrayEnd = text.lastIndexOf(']');
    const objectStart = text.indexOf('{');
    const objectEnd = text.lastIndexOf('}');

    if (objectStart >= 0 && objectEnd > objectStart && (arrayStart === -1 || objectStart < arrayStart)) {
      text = text.substring(objectStart, objectEnd + 1);
    } else if (arrayStart >= 0 && arrayEnd > arrayStart) {
      text = text.substring(arrayStart, arrayEnd + 1);
    }

    const parsed = JSON.parse(text);
    await writeTrace({
      traceType: 'agent',
      sessionId: traceContext?.sessionId,
      userId: traceContext?.userId,
      stepName: traceContext?.stepName || 'unknown',
      stage: traceContext?.stage || '',
      source: traceContext?.source || 'unknown',
      status: 'success',
      agentKey,
      model: resolvedModel,
      durationMs: Date.now() - startedAt,
      requestPreview: prompt,
      responsePreview: output,
      payload: {
        parsed,
        extra: traceContext?.extra
      },
      metrics: traceContext?.metrics
    });
    return parsed;
  } catch (error) {
    await writeTrace({
      traceType: 'agent',
      sessionId: traceContext?.sessionId,
      userId: traceContext?.userId,
      stepName: traceContext?.stepName || 'unknown',
      stage: traceContext?.stage || '',
      source: traceContext?.source || 'unknown',
      status: 'failed',
      agentKey,
      model: resolvedModel,
      durationMs: Date.now() - startedAt,
      requestPreview: prompt,
      responsePreview: output,
      payload: { extra: traceContext?.extra },
      metrics: traceContext?.metrics,
      errorMessage: error?.message || 'unknown_error'
    });
    throw error;
  }
}

async function safeCallAgent(prompt, agentKey, traceContext = {}) {
  const model = resolveAgentModel(agentKey);
  try {
    return await callDeepSeekAgent(prompt, agentKey, model, traceContext);
  } catch (err) {
    console.error(`[goalPlanning] Agent 调用失败 (${agentKey}, model=${model}):`, err.message);
    return null;
  }
}

async function loadSession(sessionId, userId, res) {
  const session = await PlanningSession.findOne({ sessionId, userId });
  if (!session) {
    res.status(404).json({ success: false, message: '会话不存在' });
    return null;
  }
  return session;
}

async function runProgressCritic(goalDraft, tracks, traceContext = {}) {
  const prompt = `你是一个OKR质量审查官，只负责发现问题，不生产内容。
【目标】${goalDraft.title}
【规则】
${buildRuleText(TRACK_RED_LINES)}
【待审查进度追踪】
${JSON.stringify(tracks, null, 2)}

请检查：
1. 是否符合双轨制下的“进度追踪”定义，而不是行动清单
2. 是否可衡量或有清晰完成节点
3. 是否存在空泛表达、重复表达、完成标准不清

仅输出纯 JSON：
{
  "passed": true,
  "issues": [
    {
      "severity": "high",
      "description": "问题描述",
      "suggestion": "修复建议"
    }
  ]
}`;

  const criticResult = await safeCallAgent(prompt, APP_IDS.critic, {
    ...traceContext,
    stepName: 'progress',
    stage: 'progress'
  });
  if (!criticResult) {
    return { passed: true, issues: [] };
  }
  return {
    passed: criticResult.passed !== false,
    issues: Array.isArray(criticResult.issues)
      ? criticResult.issues.map((issue, index) => normalizeCriticIssue(issue, index, 'progress'))
      : []
  };
}

async function runActionCritic(session, draftTasks, actionPlan, traceContext = {}) {
  const prompt = `你是一个行动方案质量审查官，只负责发现问题，不生产内容。
【任务红线】
${buildRuleText(TASK_RED_LINES)}
【目标】${session.goalDraft.title}
【难度评估】${JSON.stringify(session.goalAssessment || {})}
【进度追踪】
${buildTracksSummary(session.progressPlan?.tracks || [])}
【行动草案】
${JSON.stringify(draftTasks, null, 2)}
【待审查行动方案】
${JSON.stringify(actionPlan, null, 2)}

请检查：
1. oneOffTasks 是否仍然存在周期类、过泛或过大任务
2. oneOffTasks 是否写清具体动作和完成标准
3. recurringActions 是否承接了重复行为，而不是把重复动作拆进一次性任务
4. countdowns 是否只承接关键日期
5. 是否存在明显任务日期堆叠、遗漏关键阶段、与进度追踪脱节的问题

仅输出纯 JSON：
{
  "passed": true,
  "issues": [
    {
      "severity": "high",
      "description": "问题描述",
      "suggestion": "修复建议"
    }
  ]
}`;

  const criticResult = await safeCallAgent(prompt, APP_IDS.critic, {
    ...traceContext,
    stepName: 'actions',
    stage: 'actions'
  });
  const llmIssues = criticResult && Array.isArray(criticResult.issues)
    ? criticResult.issues.map((issue, index) => normalizeCriticIssue(issue, index, 'actions'))
    : [];
  const localIssues = buildTaskQualityIssues(actionPlan);
  const issues = [...llmIssues, ...localIssues];

  return {
    passed: (criticResult?.passed !== false) && !hasHighSeverityIssues(issues),
    issues
  };
}

router.post('/start', checkUser, async (req, res) => {
  const startedAt = Date.now();
  try {
    const { rawIntent, source = 'create_goal', targetGoalId } = req.body;
    const userId = req.user.userId;
    const plannedSessionId = generateSessionId();

    if (!rawIntent || !rawIntent.trim()) {
      return res.status(400).json({ success: false, message: '目标意图不能为空' });
    }

    const startNowMs = Date.now();
    const prompt = `你是一个专业的目标定义助手。请基于用户输入，先完成“目标理解”。
${buildCurrentDatePrompt(startNowMs)}
用户输入：${rawIntent}

要求：
1. 先严格判断输入是“目标”还是“任务”
2. 只有当输入是明确的一次性待办、做完一次就结束、无需长期追踪时，才能判为 simpleTask
3. 以下内容一律不能判为 simpleTask：带周期/期限的目标、习惯养成、考试考证、减肥健康、存钱理财、技能练习、阅读学习、长期改善类目标
4. 如果你判断为 simpleTask，后端会直接终止目标创建流程，因此必须保守判断，宁可进入目标规划，也不要误拦截目标
5. 即使你判断为 simpleTask，也必须同时提供可用的 goalDraft 作为兜底
6. 分类只能是 HEALTH / LEARNING / FINANCE / FUN
7. 周期 periodDays 必须是正整数
8. 可以附带 confidence、missingFields、goalKind
9. 涉及体重单位换算时必须严格正确：1斤=0.5kg，1kg=2斤；例如 5斤=2.5kg，10斤=5kg，绝不能写错

仅输出纯 JSON：
{
  "status": "success",
  "isSimpleTask": false,
  "goalDraft": {
    "title": "目标标题",
    "description": "目标描述",
    "category": "LEARNING",
    "periodDays": 90,
    "goalKind": "project_oriented",
    "confidence": 0.82,
    "missingFields": ["weekly_capacity"]
  }
}`;

    const result = await safeCallAgent(prompt, APP_IDS.goalDefiner || APP_IDS.clarifyGoal, {
      sessionId: plannedSessionId,
      userId,
      source,
      stepName: 'start',
      stage: 'understanding',
      extra: { targetGoalId }
    });
    if (!result || result.status === 'error') {
      await writeStepTrace({ sessionId: plannedSessionId, userId, source, stage: 'understanding' }, {
        stepName: 'start',
        status: 'failed',
        durationMs: Date.now() - startedAt,
        requestPreview: rawIntent,
        responsePreview: result,
        errorMessage: 'AI 分析目标失败',
        payload: { targetGoalId }
      });
      return res.status(500).json({ success: false, message: 'AI 分析目标失败，请重试' });
    }

    const modelSuggestedSimpleTask = result.isSimpleTask === true;
    const localExplicitSimpleTask = isExplicitSimpleTaskIntent(rawIntent);
    const effectiveSimpleTask = modelSuggestedSimpleTask || localExplicitSimpleTask;

    if (effectiveSimpleTask) {
      await writeStepTrace({ sessionId: plannedSessionId, userId, source, stage: 'understanding' }, {
        stepName: 'start',
        status: 'success',
        durationMs: Date.now() - startedAt,
        requestPreview: rawIntent,
        responsePreview: result,
        payload: {
          modelSuggestedSimpleTask,
          localExplicitSimpleTask,
          effectiveSimpleTask: true,
          targetGoalId,
          suggestedTaskTitle: rawIntent.trim()
        }
      });
      return res.json({
        success: true,
        data: {
          isSimpleTask: true,
          message: '这条输入更像是一项待办任务，不属于目标规划。建议直接创建为待办并开始执行。',
          suggestedTaskTitle: rawIntent.trim()
        }
      });
    }

    const goalDraft = result.goalDraft
      ? normalizeGoalDraft(result.goalDraft)
      : buildFallbackGoalDraftFromIntent(rawIntent);
    const session = new PlanningSession({
      sessionId: plannedSessionId,
      userId,
      source,
      targetGoalId: targetGoalId || null,
      rawIntent: rawIntent.trim(),
      stage: 'understanding',
      status: 'active',
      goalDraft
    });
    await session.save();

    await writeStepTrace({ sessionId: session.sessionId, userId, source, stage: 'understanding' }, {
      stepName: 'start',
      status: 'success',
      durationMs: Date.now() - startedAt,
      requestPreview: rawIntent,
      responsePreview: goalDraft,
      payload: {
        targetGoalId,
        goalDraft
      },
      metrics: {
        modelSuggestedSimpleTask,
        localExplicitSimpleTask,
        effectiveSimpleTask: false
      }
    });

    return res.json({
      success: true,
      data: {
        sessionId: session.sessionId,
        goalDraft
      }
    });
  } catch (err) {
    console.error('[goalPlanning/start]', err);
    const { rawIntent, source = 'create_goal' } = req.body || {};
    const userId = req.user?.userId || 'unknown';
    await writeStepTrace({ sessionId: 'unknown', userId, source, stage: 'understanding' }, {
      stepName: 'start',
      status: 'failed',
      durationMs: Date.now() - startedAt,
      requestPreview: rawIntent,
      errorMessage: err.message
    });
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

router.post('/clarification', checkUser, async (req, res) => {
  const startedAt = Date.now();
  try {
    const { sessionId, goalDraft } = req.body;
    const userId = req.user.userId;
    const session = await loadSession(sessionId, userId, res);
    if (!session) return;

    const updatedDraft = normalizeGoalDraft(goalDraft || session.goalDraft);
    const clarificationStartedAt = Date.now();
    await updateRuntimeStatus(sessionId, userId, createRuntimeStatus(
      'clarifying',
      'clarification_questions',
      1,
      1,
      '正在生成 AI 追问',
      'AI 正在围绕目标背景、时间限制和关键结果补充理解。',
      15000,
      clarificationStartedAt
    ));

    const clarificationNowMs = Date.now();
    const prompt = `你是一个目标澄清助手。请围绕以下目标，提出 4-7 个最关键的问题，帮助后续先补充信息，再评估实现难度，最后拆解进度追踪和行动方案。
${buildCurrentDatePrompt(clarificationNowMs)}
【目标】${updatedDraft.title}
【描述】${updatedDraft.description}
【周期】${updatedDraft.periodDays}天

要求：
1. 优先围绕当前基础、可投入时间、关键日期、执行约束、现有资源、必须达成的结果来问
2. 问题应服务于后续“难度评估”，帮助判断目标是否过大、过急、过难
3. 问题类型仅允许：single_choice / short_text / number / date
4. 问题应简洁、可直接回答
5. 不要输出解释，不要输出 markdown

仅输出纯 JSON：
{
  "status": "success",
  "questions": [
    {
      "id": "baseline",
      "text": "你目前在这方面的基础如何？",
      "type": "single_choice",
      "options": ["完全零基础", "有一点基础", "已有一定基础", "已经比较熟练"],
      "required": true
    }
  ]
}`;

    const result = await safeCallAgent(prompt, APP_IDS.clarifyGoal, {
      sessionId,
      userId,
      source: session.source,
      stepName: 'clarification',
      stage: 'clarifying',
      extra: {
        targetGoalId: session.targetGoalId
      }
    });
    const fallbackQuestions = [
      {
        id: 'baseline',
        text: '你目前在这方面的基础如何？',
        type: 'single_choice',
        options: ['完全零基础', '有一点基础', '已有一定基础', '已经比较熟练'],
        required: true
      },
      {
        id: 'weekly_capacity',
        text: '你平均每周能投入多少时间？',
        type: 'single_choice',
        options: ['1小时内', '1-3小时', '3-5小时', '5小时以上'],
        required: true
      },
      {
        id: 'must_result',
        text: '这次最核心、必须达成的结果是什么？',
        type: 'short_text',
        placeholder: '例如：通过考试、完成上线、减脂 5 公斤',
        required: true
      },
      {
        id: 'deadline',
        text: '你希望大概在什么时候达成？',
        type: 'date',
        required: false
      },
      {
        id: 'main_constraint',
        text: '当前最大的限制或困难是什么？',
        type: 'short_text',
        placeholder: '例如：时间少、基础弱、资源不足、容易中断',
        required: false
      }
    ];

    const questions = Array.isArray(result?.questions) && result.questions.length > 0
      ? result.questions.map(normalizeQuestion)
      : fallbackQuestions;

    const clarification = {
      questions,
      answers: session.clarification?.answers || {},
      completenessScore: 0
    };

    await PlanningSession.findOneAndUpdate(
      { sessionId, userId },
      {
        goalDraft: updatedDraft,
        clarification,
        stage: 'clarifying'
      }
    );
    await clearRuntimeStatus(sessionId, userId);

    await writeStepTrace({ sessionId, userId, source: session.source, stage: 'clarifying' }, {
      stepName: 'clarification',
      status: 'success',
      durationMs: Date.now() - startedAt,
      requestPreview: updatedDraft,
      responsePreview: questions,
      fallbackUsed: !(Array.isArray(result?.questions) && result.questions.length > 0),
      payload: {
        goalDraft: updatedDraft,
        questions
      },
      metrics: {
        questionCount: questions.length
      }
    });

    return res.json({ success: true, data: { questions } });
  } catch (err) {
    console.error('[goalPlanning/clarification]', err);
    const { sessionId } = req.body || {};
    const userId = req.user?.userId || 'unknown';
    if (sessionId) {
      await clearRuntimeStatus(sessionId, userId);
    }
    await writeStepTrace({ sessionId, userId, source: 'unknown', stage: 'clarifying' }, {
      stepName: 'clarification',
      status: 'failed',
      durationMs: Date.now() - startedAt,
      requestPreview: req.body?.goalDraft,
      errorMessage: err.message
    });
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

router.post('/progress', checkUser, async (req, res) => {
  const startedAt = Date.now();
  try {
    const { sessionId, answers } = req.body;
    const userId = req.user.userId;
    const session = await loadSession(sessionId, userId, res);
    if (!session) return;

    const traceContext = {
      sessionId,
      userId,
      source: session.source,
      extra: { targetGoalId: session.targetGoalId }
    };

    const progressStartedAt = Date.now();
    await updateRuntimeStatus(sessionId, userId, createRuntimeStatus(
      'progress',
      'difficulty_assessment',
      1,
      3,
      '正在评估目标难度',
      '先判断这个目标在当前周期内是否现实，以及应该拆成多细。',
      45000,
      progressStartedAt
    ));
    const assessment = await runDifficultyAssessment(session, answers || {}, traceContext);
    await updateRuntimeStatus(sessionId, userId, createRuntimeStatus(
      'progress',
      'track_generation',
      2,
      3,
      '正在生成进度追踪',
      'AI 正在把目标拆成可衡量、可观察的追踪维度。',
      22000,
      progressStartedAt
    ));
    let progressPlan = await runKrPlanning(session, assessment, answers || {}, [], traceContext);
    await updateRuntimeStatus(sessionId, userId, createRuntimeStatus(
      'progress',
      'progress_quality_check',
      3,
      3,
      '正在检查追踪质量',
      '正在检查这些追踪是否清晰、可衡量且不空泛。',
      GOAL_PLANNING_PROGRESS_CRITIC_TIMEOUT_MS,
      progressStartedAt
    ));
    let criticResult = await runProgressCritic(session.goalDraft, progressPlan.tracks, traceContext);

    if (hasHighSeverityIssues(criticResult.issues)) {
      progressPlan = await runKrPlanning(session, assessment, answers || {}, criticResult.issues, traceContext);
      criticResult = await runProgressCritic(session.goalDraft, progressPlan.tracks, traceContext);
    }

    const interventionUsed = session.progressPlan?.userInterventionUsed === true;
    progressPlan = {
      ...progressPlan,
      criticPassed: criticResult.passed,
      criticIssues: criticResult.issues,
      userFacingIssues: interventionUsed ? [] : buildUserFacingProgressIssues(criticResult.issues, progressPlan.tracks),
      userInterventionUsed: interventionUsed,
      assessment
    };

    await PlanningSession.findOneAndUpdate(
      { sessionId, userId },
      {
        clarification: {
          questions: session.clarification?.questions || [],
          answers: answers || {},
          completenessScore: Object.keys(answers || {}).length
        },
        goalAssessment: assessment,
        progressPlan,
        stage: 'progress'
      }
    );
    await clearRuntimeStatus(sessionId, userId);

    await writeStepTrace({ sessionId, userId, source: session.source, stage: 'progress' }, {
      stepName: 'progress',
      status: 'success',
      durationMs: Date.now() - startedAt,
      requestPreview: answers,
      responsePreview: progressPlan.tracks,
      fallbackUsed: progressPlan.fallbackUsed === true,
      payload: {
        assessment,
        progressPlan,
        criticIssues: criticResult.issues
      },
      metrics: {
        answerCount: Object.keys(answers || {}).length,
        recommendedTrackCount: assessment.recommendedTrackCount,
        generatedTrackCount: progressPlan.tracks.length,
        criticIssueCount: criticResult.issues.length
      }
    });

    res.json({ success: true, data: { progressPlan, goalAssessment: assessment } });
  } catch (err) {
    console.error('[goalPlanning/progress]', err);
    const { sessionId, answers } = req.body || {};
    const userId = req.user?.userId || 'unknown';
    if (sessionId) {
      await clearRuntimeStatus(sessionId, userId);
    }
    await writeStepTrace({ sessionId, userId, source: 'unknown', stage: 'progress' }, {
      stepName: 'progress',
      status: 'failed',
      durationMs: Date.now() - startedAt,
      requestPreview: answers,
      errorMessage: err.message
    });
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

router.post('/progress/regenerate', checkUser, async (req, res) => {
  const startedAt = Date.now();
  try {
    const { sessionId, trackId, userHint } = req.body;
    const userId = req.user.userId;
    const session = await loadSession(sessionId, userId, res);
    if (!session) return;

    const existingTracks = session.progressPlan?.tracks || [];
    const otherTracks = existingTracks.filter((track) => track.id !== trackId);
    const targetTrack = existingTracks.find((track) => track.id === trackId);
    if (!targetTrack) {
      await writeStepTrace({ sessionId, userId, source: session.source, stage: 'progress' }, {
        stepName: 'progress_regenerate',
        status: 'failed',
        durationMs: Date.now() - startedAt,
        requestPreview: { trackId, userHint },
        errorMessage: '追踪不存在',
        payload: { trackId }
      });
      return res.status(404).json({ success: false, message: '追踪不存在' });
    }

    const prompt = `你是一个专业的 ProgressDesigner Agent。
当前产品规则：
1. 采用双轨制，进度追踪与行动清单解耦
2. 只输出一条新的进度追踪
3. 不能与已有追踪重复
4. 新追踪要与当前难度等级匹配，不能为了凑数而空泛

【目标】${session.goalDraft.title}
【补充信息】${buildClarificationSummary(session.clarification?.questions || [], session.clarification?.answers || {})}
【难度评估】${session.goalAssessment ? JSON.stringify(session.goalAssessment) : '按中等难度处理'}
【其他追踪】${otherTracks.map((track) => track.title).join('、')}
【旧追踪】${JSON.stringify(targetTrack)}
${userHint ? `【用户要求】${userHint}` : ''}

仅输出纯 JSON：
{
  "id": "${trackId}",
  "title": "新追踪标题",
  "type": "milestone",
  "targetValue": 1,
  "unit": "项",
  "completionCriteria": "完成标准",
  "checkpointText": "阶段检查点",
  "reason": "设计理由"
}`;

    const result = await safeCallAgent(prompt, APP_IDS.progressDesigner, {
      sessionId,
      userId,
      source: session.source,
      stepName: 'progress_regenerate',
      stage: 'progress',
      extra: {
        targetGoalId: session.targetGoalId,
        trackId,
        userHint
      },
      metrics: {
        existingTrackCount: existingTracks.length
      }
    });
    if (!result || !result.title) {
      await writeStepTrace({ sessionId, userId, source: session.source, stage: 'progress' }, {
        stepName: 'progress_regenerate',
        status: 'failed',
        durationMs: Date.now() - startedAt,
        requestPreview: { trackId, userHint, targetTrack },
        responsePreview: result,
        errorMessage: 'AI 重生成失败，请重试',
        payload: {
          trackId,
          oldTrack: targetTrack
        }
      });
      return res.status(500).json({ success: false, message: 'AI 重生成失败，请重试' });
    }

    const newTrack = normalizeTrack({ ...result, id: trackId }, 0);
    const newTracks = existingTracks.map((track) => track.id === trackId ? newTrack : track);
    await PlanningSession.findOneAndUpdate(
      { sessionId, userId },
      { 'progressPlan.tracks': newTracks }
    );

    await writeStepTrace({ sessionId, userId, source: session.source, stage: 'progress' }, {
      stepName: 'progress_regenerate',
      status: 'success',
      durationMs: Date.now() - startedAt,
      requestPreview: { trackId, userHint },
      responsePreview: newTrack,
      payload: {
        trackId,
        oldTrack: targetTrack,
        newTrack
      },
      metrics: {
        existingTrackCount: existingTracks.length,
        generatedTrackCount: newTracks.length
      }
    });

    return res.json({ success: true, data: { track: newTrack } });
  } catch (err) {
    console.error('[goalPlanning/progress/regenerate]', err);
    const { sessionId, trackId, userHint } = req.body || {};
    const userId = req.user?.userId || 'unknown';
    await writeStepTrace({ sessionId, userId, source: 'unknown', stage: 'progress' }, {
      stepName: 'progress_regenerate',
      status: 'failed',
      durationMs: Date.now() - startedAt,
      requestPreview: { trackId, userHint },
      errorMessage: err.message
    });
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

router.post('/progress/add-track', checkUser, async (req, res) => {
  const startedAt = Date.now();
  try {
    const { sessionId, userHint } = req.body;
    const userId = req.user.userId;
    const session = await loadSession(sessionId, userId, res);
    if (!session) return;

    const existingTracks = session.progressPlan?.tracks || [];

    const prompt = `你是一个专业的 ProgressDesigner Agent。
当前产品规则：
1. 采用双轨制，进度追踪与行动清单解耦
2. 进度追踪必须可衡量，或有清晰完成节点
3. 请依据用户要求，增加一条与现有追踪方向不同的全新进度追踪
4. 只输出一条新追踪
5. 新追踪需要补足当前方案，而不是重复已有维度

【目标】${session.goalDraft.title}
【补充信息】${buildClarificationSummary(session.clarification?.questions || [], session.clarification?.answers || {})}
【难度评估】${session.goalAssessment ? JSON.stringify(session.goalAssessment) : '按中等难度处理'}
【已有追踪】${existingTracks.map((track) => track.title).join('、')}
【用户新增要求】${userHint || '请补充一个尚未覆盖的综合评价维度'}

仅输出纯 JSON：
{
  "title": "新追踪标题",
  "type": "numeric",
  "targetValue": 100,
  "unit": "分",
  "completionCriteria": "如何判断完成",
  "checkpointText": "阶段检查点",
  "reason": "设计理由"
}`;

    const result = await safeCallAgent(prompt, APP_IDS.progressDesigner, {
      sessionId,
      userId,
      source: session.source,
      stepName: 'progress_add_track',
      stage: 'progress',
      extra: {
        targetGoalId: session.targetGoalId,
        userHint
      },
      metrics: {
        existingTrackCount: existingTracks.length
      }
    });
    if (!result || !result.title) {
      await writeStepTrace({ sessionId, userId, source: session.source, stage: 'progress' }, {
        stepName: 'progress_add_track',
        status: 'failed',
        durationMs: Date.now() - startedAt,
        requestPreview: { userHint },
        responsePreview: result,
        errorMessage: 'AI 重生成失败，请重试',
        payload: {
          existingTrackTitles: existingTracks.map((track) => track.title)
        }
      });
      return res.status(500).json({ success: false, message: 'AI 重生成失败，请重试' });
    }

    const newTrack = normalizeTrack({ ...result, id: `track_${Date.now()}` }, existingTracks.length);
    existingTracks.push(newTrack);
    await PlanningSession.findOneAndUpdate(
      { sessionId, userId },
      { 'progressPlan.tracks': existingTracks }
    );

    await writeStepTrace({ sessionId, userId, source: session.source, stage: 'progress' }, {
      stepName: 'progress_add_track',
      status: 'success',
      durationMs: Date.now() - startedAt,
      requestPreview: { userHint },
      responsePreview: newTrack,
      payload: {
        newTrack
      },
      metrics: {
        previousTrackCount: existingTracks.length - 1,
        currentTrackCount: existingTracks.length
      }
    });

    return res.json({ success: true, data: { track: newTrack } });
  } catch (err) {
    console.error('[goalPlanning/progress/add-track]', err);
    const { sessionId, userHint } = req.body || {};
    const userId = req.user?.userId || 'unknown';
    await writeStepTrace({ sessionId, userId, source: 'unknown', stage: 'progress' }, {
      stepName: 'progress_add_track',
      status: 'failed',
      durationMs: Date.now() - startedAt,
      requestPreview: { userHint },
      errorMessage: err.message
    });
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

router.post('/actions', checkUser, async (req, res) => {
  const startedAt = Date.now();
  try {
    const { sessionId } = req.body;
    const userId = req.user.userId;
    const session = await loadSession(sessionId, userId, res);
    if (!session) return;

    const traceContext = {
      sessionId,
      userId,
      source: session.source,
      extra: { targetGoalId: session.targetGoalId }
    };

    const actionsStartedAt = Date.now();
    await updateRuntimeStatus(sessionId, userId, createRuntimeStatus(
      'actions',
      'task_planning',
      1,
      4,
      '正在规划行动草案',
      '先整理起步动作、推进路径和关键交付，作为后续拆解的基础。',
      120000,
      actionsStartedAt
    ));
    let draftTasks = await runTaskPlanning(session, [], traceContext);
    let usedDraftFallback = draftTasks.length === 0;
    if (draftTasks.length === 0) {
      draftTasks = buildFallbackDraftTasks(session);
    }

    await updateRuntimeStatus(sessionId, userId, createRuntimeStatus(
      'actions',
      'parallel_generation',
      2,
      4,
      '正在拆解任务与提醒',
      'AI 正在并行生成一次性任务、重复提醒和关键日期，这一步通常最耗时。',
      90000,
      actionsStartedAt
    ));
    const [taskPlan, automationResult] = await Promise.all([
      runTaskAtomization(session, draftTasks, [], traceContext),
      runAutomationPlanning(session, draftTasks, [], traceContext)
    ]);

    let actionPlan = {
      oneOffTasks: taskPlan.oneOffTasks,
      recurringActions: automationResult.recurringActions,
      countdowns: automationResult.countdowns,
      focusSuggestions: automationResult.focusSuggestions
    };

    await updateRuntimeStatus(sessionId, userId, createRuntimeStatus(
      'actions',
      'action_quality_check',
      4,
      4,
      '正在检查行动质量',
      '最后检查任务是否过泛、日期是否堆叠，以及自动化是否合理。',
      GOAL_PLANNING_ACTION_CRITIC_TIMEOUT_MS,
      actionsStartedAt
    ));
    let criticResult = await runActionCritic(session, draftTasks, actionPlan, traceContext);
    let fallbackUsed = usedDraftFallback;

    if (actionPlan.oneOffTasks.length === 0 && actionPlan.recurringActions.length === 0 && actionPlan.countdowns.length === 0) {
      actionPlan = buildFallbackActionPlan(session, draftTasks);
      fallbackUsed = true;
      const fallbackIssues = buildTaskQualityIssues(actionPlan);
      criticResult = {
        passed: !hasHighSeverityIssues(fallbackIssues),
        issues: fallbackIssues
      };
    }

    const automationPlan = {
      reminders: actionPlan.recurringActions,
      countdowns: actionPlan.countdowns,
      conflicts: criticResult.issues
        .filter((issue) => issue.severity === 'high' && issue.module === 'actions')
        .map((issue) => ({
          type: 'unsupported_rule',
          message: issue.description,
          level: issue.severity
        }))
    };

    await PlanningSession.findOneAndUpdate(
      { sessionId, userId },
      {
        actionPlan,
        automationPlan,
        stage: 'actions'
      }
    );
    await clearRuntimeStatus(sessionId, userId);

    await writeStepTrace({ sessionId, userId, source: session.source, stage: 'actions' }, {
      stepName: 'actions',
      status: 'success',
      durationMs: Date.now() - startedAt,
      responsePreview: actionPlan,
      fallbackUsed,
      payload: {
        draftTasks,
        actionPlan,
        automationPlan,
        criticIssues: criticResult.issues
      },
      metrics: {
        draftTaskCount: draftTasks.length,
        oneOffTaskCount: actionPlan.oneOffTasks.length,
        recurringActionCount: actionPlan.recurringActions.length,
        countdownCount: actionPlan.countdowns.length,
        criticIssueCount: criticResult.issues.length,
        criticPassed: criticResult.passed
      }
    });

    return res.json({ success: true, data: actionPlan });
  } catch (err) {
    console.error('[goalPlanning/actions]', err);
    const { sessionId } = req.body || {};
    const userId = req.user?.userId || 'unknown';
    if (sessionId) {
      await clearRuntimeStatus(sessionId, userId);
    }
    await writeStepTrace({ sessionId, userId, source: 'unknown', stage: 'actions' }, {
      stepName: 'actions',
      status: 'failed',
      durationMs: Date.now() - startedAt,
      errorMessage: err.message
    });
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

router.post('/actions/regenerate', checkUser, async (req, res) => {
  const startedAt = Date.now();
  try {
    const { sessionId, section, userHint } = req.body;
    const userId = req.user.userId;
    const session = await loadSession(sessionId, userId, res);
    if (!session) return;

    const validSection = ['tasks', 'recurring', 'countdowns'].includes(section) ? section : 'tasks';
    const sectionLabel = validSection === 'tasks'
      ? '一次性起步行动'
      : validSection === 'recurring'
        ? '重复行动'
        : '倒计时';
    const oldData = validSection === 'tasks'
      ? session.actionPlan?.oneOffTasks || []
      : validSection === 'recurring'
        ? session.actionPlan?.recurringActions || []
        : session.actionPlan?.countdowns || [];

    const regenNowMs = Date.now();
    const regenTodayStr = new Date().toISOString().split('T')[0];
    const regenPeriodDays = session.goalDraft.periodDays || 90;
    const regenEndDateMs = regenNowMs + regenPeriodDays * 86400000;
    const regenEndDateStr = new Date(regenEndDateMs).toISOString().split('T')[0];

    const prompt = `你是一个专业的 ActionPlanner Agent。
当前产品规则：
1. 行动清单与进度追踪完全解耦
2. 只重生成指定区块，保持与其它区块的互补性
3. 一次性任务(oneOffTasks)必须是做完一次就结束的原子任务，有明确完成标准
4. 需要重复做的事（每天/每周）必须且只能放入 recurringActions，严禁拆成多个 oneOffTask
5. 不同 oneOffTask 的 suggestedDueDate 严禁相同，任务至少间隔 1-3 天
6. suggestedDueDate 是 Unix 毫秒时间戳，基于 ${regenNowMs} 偏移计算
7. 任务标题写具体要做的事，不写"第X周..."
8. description 必须让用户一看就知道做什么和完成标准
9. 如果输出 recurringActions，且能判断周期/习惯提醒的结束日期，必须补充 endDate(YYYY-MM-DD)；无法可靠判断才留空

【重要时间信息】
- 当前日期：${regenTodayStr}（时间戳：${regenNowMs}）
- 目标结束日期：${regenEndDateStr}（时间戳：${regenEndDateMs}）
- 总周期：${regenPeriodDays} 天

【目标】${session.goalDraft.title}
【进度追踪】
${buildTracksSummary(session.progressPlan?.tracks || [])}
【用户背景】${buildClarificationSummary(session.clarification?.questions || [], session.clarification?.answers || {})}
【难度评估】${session.goalAssessment ? JSON.stringify(session.goalAssessment) : '按中等难度处理'}
【当前要替换的区块】${sectionLabel}
【旧内容】${JSON.stringify(oldData)}
${userHint ? `【用户要求】${userHint}` : ''}

仅输出纯 JSON 数组。`;

    const result = await safeCallAgent(prompt, APP_IDS.actionPlanner, {
      sessionId,
      userId,
      source: session.source,
      stepName: 'actions_regenerate',
      stage: 'actions',
      extra: {
        targetGoalId: session.targetGoalId,
        section: validSection,
        userHint
      },
      metrics: {
        oldSectionCount: oldData.length
      }
    });
    const newData = Array.isArray(result)
      ? result
      : Array.isArray(result?.oneOffTasks)
        ? result.oneOffTasks
        : Array.isArray(result?.recurringActions)
          ? result.recurringActions
          : Array.isArray(result?.countdowns)
            ? result.countdowns
            : [];

    const nextActionPlan = {
      oneOffTasks: session.actionPlan?.oneOffTasks || [],
      recurringActions: session.actionPlan?.recurringActions || [],
      countdowns: session.actionPlan?.countdowns || [],
      focusSuggestions: session.actionPlan?.focusSuggestions || []
    };

    if (validSection === 'tasks') {
      nextActionPlan.oneOffTasks = newData.map(normalizeOneOffTask);
    } else if (validSection === 'recurring') {
      nextActionPlan.recurringActions = newData.map(normalizeRecurringAction);
    } else {
      nextActionPlan.countdowns = newData.map(normalizeCountdown);
    }

    const automationPlan = {
      reminders: nextActionPlan.recurringActions,
      countdowns: nextActionPlan.countdowns,
      conflicts: []
    };

    await PlanningSession.findOneAndUpdate(
      { sessionId, userId },
      { actionPlan: nextActionPlan, automationPlan }
    );

    await writeStepTrace({ sessionId, userId, source: session.source, stage: 'actions' }, {
      stepName: 'actions_regenerate',
      status: 'success',
      durationMs: Date.now() - startedAt,
      requestPreview: { section: validSection, userHint },
      responsePreview: newData,
      payload: {
        section: validSection,
        oldData,
        newData,
        nextActionPlan
      },
      metrics: {
        oldSectionCount: oldData.length,
        newSectionCount: newData.length,
        oneOffTaskCount: nextActionPlan.oneOffTasks.length,
        recurringActionCount: nextActionPlan.recurringActions.length,
        countdownCount: nextActionPlan.countdowns.length
      }
    });

    return res.json({ success: true, data: { actionPlan: nextActionPlan } });
  } catch (err) {
    console.error('[goalPlanning/actions/regenerate]', err);
    const { sessionId, section, userHint } = req.body || {};
    const userId = req.user?.userId || 'unknown';
    await writeStepTrace({ sessionId, userId, source: 'unknown', stage: 'actions' }, {
      stepName: 'actions_regenerate',
      status: 'failed',
      durationMs: Date.now() - startedAt,
      requestPreview: { section, userHint },
      errorMessage: err.message
    });
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

router.post('/review', checkUser, async (req, res) => {
  try {
    const { sessionId } = req.body;
    const userId = req.user.userId;
    const session = await loadSession(sessionId, userId, res);
    if (!session) return;

    // 直接从已有数据合成 qualityReport，跳过 AI 二次调用（节省 30-60s）
    const existingIssues = session.progressPlan?.criticIssues || [];
    const hasHighRisk = existingIssues.some((i) => i.severity === 'high');
    const trackCount = (session.progressPlan?.tracks || []).length;
    const taskCount = (session.actionPlan?.oneOffTasks || []).length;
    const recurringCount = (session.actionPlan?.recurringActions || []).length;
    const difficultyLevel = session.goalAssessment?.level || 'moderate';
    const difficultyPenalty = difficultyLevel === 'very_hard' ? 12 : difficultyLevel === 'hard' ? 8 : 0;

    let overallScore = 85;
    if (hasHighRisk) overallScore -= 20;
    if (trackCount === 0) overallScore -= 15;
    if (taskCount === 0 && recurringCount === 0) overallScore -= 10;
    overallScore -= difficultyPenalty;
    overallScore = Math.max(40, Math.min(98, overallScore));

    const summaryParts = [];
    if (session.goalAssessment?.summary) summaryParts.push(session.goalAssessment.summary);
    if (trackCount > 0) summaryParts.push(`已设计 ${trackCount} 个进度追踪`);
    if (recurringCount > 0) summaryParts.push(`${recurringCount} 项日常提醒待自动化`);
    if (taskCount > 0) summaryParts.push(`${taskCount} 个起步行动`);
    const summary = summaryParts.length > 0
      ? summaryParts.join('，') + '，可以进入最终确认阶段'
      : '方案结构完整，可以进入最终确认';

    const qualityReport = {
      passed: !hasHighRisk,
      overallScore,
      summary,
      suggestions: hasHighRisk
        ? ['建议针对高风险问题进行局部重生成']
        : (session.goalAssessment?.shouldReviseGoal ? ['目标难度偏高，建议回到第一步调整目标范围或延长周期'] : []),
      issues: existingIssues,
      needsUserAttention: hasHighRisk
        ? ['存在高风险追踪问题，建议检查']
        : (session.goalAssessment?.shouldReviseGoal && session.goalAssessment?.blockingWarning ? [session.goalAssessment.blockingWarning] : [])
    };

    await PlanningSession.findOneAndUpdate(
      { sessionId, userId },
      { qualityReport, stage: 'review' }
    );

    return res.json({
      success: true,
      data: {
        goalDraft: session.goalDraft,
        progressPlan: session.progressPlan,
        actionPlan: session.actionPlan,
        qualityReport
      }
    });
  } catch (err) {
    console.error('[goalPlanning/review]', err);
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});



router.post('/apply', checkUser, async (req, res) => {
  try {
    const { sessionId } = req.body;
    const userId = req.user.userId;

    const session = await PlanningSession.findOneAndUpdate(
      { sessionId, userId },
      { stage: 'completed', status: 'completed' },
      { new: true }
    );

    if (!session) {
      return res.status(404).json({ success: false, message: '会话不存在' });
    }

    return res.json({
      success: true,
      data: {
        session: {
          sessionId: session.sessionId,
          userId: session.userId,
          source: session.source,
          targetGoalId: session.targetGoalId,
          rawIntent: session.rawIntent,
          stage: session.stage,
          status: session.status,
          goalDraft: session.goalDraft,
          clarification: session.clarification,
          progressPlan: session.progressPlan,
          actionPlan: session.actionPlan,
          automationPlan: session.automationPlan,
          qualityReport: session.qualityReport,
          createdAt: session.createdAt,
          updatedAt: session.updatedAt
        }
      }
    });
  } catch (err) {
    console.error('[goalPlanning/apply]', err);
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

router.post('/session/save', checkUser, async (req, res) => {
  try {
    const { session } = req.body;
    const userId = req.user.userId;
    if (!session || !session.sessionId) {
      return res.status(400).json({ success: false, message: '缺少有效的会话数据' });
    }

    const existingSession = await PlanningSession.findOne({ sessionId: session.sessionId, userId });
    if (!existingSession) {
      return res.status(404).json({ success: false, message: '会话不存在' });
    }

    const nextPayload = {
      goalDraft: session.goalDraft || existingSession.goalDraft,
      clarification: session.clarification || existingSession.clarification,
      goalAssessment: session.goalAssessment || existingSession.goalAssessment,
      progressPlan: session.progressPlan || existingSession.progressPlan,
      actionPlan: session.actionPlan || existingSession.actionPlan,
      automationPlan: session.automationPlan || existingSession.automationPlan,
      qualityReport: session.qualityReport || existingSession.qualityReport,
      stage: session.stage || existingSession.stage,
      status: session.status || existingSession.status,
      updatedAt: Date.now()
    };

    const saved = await PlanningSession.findOneAndUpdate(
      { sessionId: session.sessionId, userId },
      nextPayload,
      { new: true }
    );

    return res.json({ success: true, data: saved });
  } catch (err) {
    console.error('[goalPlanning/session/save]', err);
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

router.get('/session/:id', checkUser, async (req, res) => {
  try {
    const sessionId = req.params.id;
    const userId = req.user.userId;
    const session = await PlanningSession.findOne({ sessionId, userId });
    if (!session) {
      return res.json({ success: false, message: '会话不存在或已过期' });
    }

    const isExpired = Date.now() - session.createdAt > 24 * 60 * 60 * 1000;
    if (isExpired || session.status === 'abandoned') {
      return res.json({ success: false, message: '会话已过期' });
    }

    return res.json({ success: true, data: session });
  } catch (err) {
    console.error('[goalPlanning/session]', err);
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

router.get('/trace/:id', checkUser, async (req, res) => {
  try {
    const sessionId = req.params.id;
    const userId = req.user.userId;
    const traceType = typeof req.query.traceType === 'string' ? req.query.traceType : '';
    const stepName = typeof req.query.stepName === 'string' ? req.query.stepName : '';
    const agentKey = typeof req.query.agentKey === 'string' ? req.query.agentKey : '';
    const status = typeof req.query.status === 'string' ? req.query.status : '';
    const order = req.query.order === 'desc' ? -1 : 1;
    const limit = parseTraceLimit(req.query.limit);

    const session = await PlanningSession.findOne({ sessionId, userId })
      .select({
        sessionId: 1,
        stage: 1,
        status: 1,
        source: 1,
        targetGoalId: 1,
        goalDraft: 1,
        createdAt: 1,
        updatedAt: 1
      })
      .lean();

    if (!session) {
      return res.status(404).json({ success: false, message: '会话不存在' });
    }

    const filter = { sessionId, userId };
    if (traceType === 'step' || traceType === 'agent') {
      filter.traceType = traceType;
    }
    if (stepName) {
      filter.stepName = stepName;
    }
    if (agentKey) {
      filter.agentKey = agentKey;
    }
    if (status === 'success' || status === 'failed' || status === 'partial') {
      filter.status = status;
    }

    const traces = await GoalPlanningTrace.find(filter)
      .sort({ createdAt: order })
      .limit(limit)
      .lean();

    return res.json({
      success: true,
      data: {
        session,
        filters: {
          traceType: traceType || 'all',
          stepName: stepName || 'all',
          agentKey: agentKey || 'all',
          status: status || 'all',
          order: order === -1 ? 'desc' : 'asc',
          limit
        },
        summary: buildTraceSummary(traces),
        traces
      }
    });
  } catch (err) {
    console.error('[goalPlanning/trace]', err);
    return res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

module.exports = router;
