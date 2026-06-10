const express = require('express');
const crypto = require('crypto');
const SyncData = require('../models/SyncData');
const { createChatCompletion, getDeepSeekModel } = require('../utils/deepseekClient');

const router = express.Router();

// ========================
// 配置
// ========================
function readPositiveNumberEnv(name, fallbackValue) {
  const value = Number(process.env[name]);
  return Number.isFinite(value) && value > 0 ? value : fallbackValue;
}

const VOICE_CREATE_MODEL = process.env.VOICE_CREATE_MODEL || process.env.DEEPSEEK_FAST_MODEL || process.env.DEEPSEEK_MODEL || 'deepseek-v4-flash';
const VOICE_CLASSIFY_MODEL = process.env.VOICE_CLASSIFY_MODEL || VOICE_CREATE_MODEL;
const VOICE_PARSE_MODEL = process.env.VOICE_PARSE_MODEL || VOICE_CREATE_MODEL;
const VOICE_ANALYZE_TIMEOUT_MS = readPositiveNumberEnv('VOICE_ANALYZE_TIMEOUT_MS', 15000);
const VOICE_CLASSIFY_TIMEOUT_MS = readPositiveNumberEnv('VOICE_CLASSIFY_TIMEOUT_MS', 5000);
const VOICE_PARSE_TIMEOUT_MS = readPositiveNumberEnv('VOICE_PARSE_TIMEOUT_MS', 10000);

// ========================
// 简易内存缓存（parse 结果，TTL 60s）
// ========================
const parseCache = new Map();
const PARSE_CACHE_TTL_MS = 60_000;

function buildParseCacheKey(userId, text, intent) {
  const textHash = crypto.createHash('sha1').update(String(text || '')).digest('hex');
  return `${String(userId || 'anonymous')}:${intent}:${textHash}`;
}

function normalizeTraceId(traceId) {
  const value = String(traceId || '').trim();
  if (!value) {
    return `voice_server_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  }
  return value.slice(0, 80);
}

function clipLogText(text, limit = 80) {
  const value = String(text || '').replace(/\s+/g, ' ').trim();
  return value.length > limit ? `${value.slice(0, limit)}...` : value;
}

function buildVoiceErrorData(errorCode, traceId, extra = {}) {
  return {
    error: errorCode,
    errorCode,
    traceId,
    ...extra
  };
}

function getAgentErrorCode(error, timeoutCode, fallbackCode) {
  const message = String(error?.message || '').toLowerCase();
  if (error?.code === 'ECONNABORTED' || message.includes('timeout')) {
    return timeoutCode;
  }
  return fallbackCode;
}

function getCachedParse(userId, text, intent) {
  const key = buildParseCacheKey(userId, text, intent);
  const entry = parseCache.get(key);
  if (!entry) return null;
  if (Date.now() - entry.timestamp > PARSE_CACHE_TTL_MS) {
    parseCache.delete(key);
    return null;
  }
  return entry.data;
}

function setCachedParse(userId, text, intent, data) {
  const key = buildParseCacheKey(userId, text, intent);
  parseCache.set(key, { data, timestamp: Date.now() });
  // 限制缓存条目数
  if (parseCache.size > 200) {
    const oldest = parseCache.keys().next().value;
    parseCache.delete(oldest);
  }
}

// ========================
// 通用 Agent 调用
// ========================
async function callAgent(systemPrompt, userPrompt, options = {}) {
  const completion = await createChatCompletion({
    model: getDeepSeekModel(options.model || VOICE_CREATE_MODEL),
    timeoutMs: options.timeoutMs || 30000,
    temperature: 0.15,
    traceLabel: options.traceLabel || 'voiceCreate.agent',
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userPrompt }
    ]
  });

  let content = completion.content || '';
  content = content.replace(/```json/gi, '').replace(/```/g, '').trim();

  const objStart = content.indexOf('{');
  const objEnd = content.lastIndexOf('}');
  if (objStart >= 0 && objEnd > objStart) {
    content = content.substring(objStart, objEnd + 1);
  }

  return JSON.parse(content);
}

// ========================
// 获取用户活跃目标列表（用于 Agent 上下文和本地匹配）
// ========================
async function getUserActiveGoals(userId) {
  try {
    const syncData = await SyncData.findOne({ userId });
    if (!syncData || !syncData.goals || syncData.goals.length === 0) {
      return [];
    }

    const activeGoals = syncData.goals.filter(g => !g.isArchived);
    return activeGoals.map(goal => ({
      id: goal.id,
      title: goal.title || '',
      description: goal.description || '',
      keyResults: Array.isArray(goal.keyResults) ? goal.keyResults.map(kr => ({
        id: kr.id,
        title: kr.title || ''
      })).filter(kr => kr.id || kr.title) : []
    }));
  } catch (e) {
    console.error('[voiceCreate] 获取用户目标失败:', e.message);
    return [];
  }
}

function scoreGoalForTask(text, goal) {
  if (!goal || !goal.id) {
    return 0;
  }

  const queryTerms = extractMatchTerms(text);
  if (queryTerms.length === 0) {
    return 0;
  }

  const compactQuery = compactMatchText(text);
  const compactTitle = compactMatchText(goal.title);
  const compactDescription = compactMatchText(goal.description);
  const compactKrTitles = compactMatchText(Array.isArray(goal.keyResults) ? goal.keyResults.map(kr => kr.title).join(' ') : '');

  let score = 0;
  if (compactQuery && compactTitle && compactTitle.includes(compactQuery)) {
    score += 5;
  }
  score += scoreFieldMatch(queryTerms, compactTitle, 6.5);
  score += scoreFieldMatch(queryTerms, compactDescription, 2.2);
  score += scoreFieldMatch(queryTerms, compactKrTitles, 3.5);

  return Number(score.toFixed(3));
}

function rankGoalsForTask(text, activeGoals) {
  if (!Array.isArray(activeGoals) || activeGoals.length === 0) {
    return [];
  }

  return activeGoals
    .map(goal => ({ goal, score: scoreGoalForTask(text, goal) }))
    .sort((first, second) => second.score - first.score);
}

function scoreKrForTask(text, kr) {
  if (!kr || !kr.id) {
    return 0;
  }

  const queryTerms = extractMatchTerms(text);
  if (queryTerms.length === 0) {
    return 0;
  }

  return Number(scoreFieldMatch(queryTerms, compactMatchText(kr.title), 5).toFixed(3));
}

function pickBestGoalMatchForTask(text, activeGoals) {
  const ranked = rankGoalsForTask(text, activeGoals);
  if (ranked.length === 0) {
    return null;
  }

  const best = ranked[0];
  const runnerUp = ranked[1];
  const leadScore = best.score - (runnerUp?.score || 0);
  if (best.score < 1.8) {
    return null;
  }
  if (best.score < 2.6 && leadScore < 0.5) {
    return null;
  }

  return best;
}

function buildGoalsContext(activeGoals, inputText) {
  if (!Array.isArray(activeGoals) || activeGoals.length === 0) {
    return '当前用户无活跃目标。';
  }

  const rankedGoals = rankGoalsForTask(inputText, activeGoals);
  let ctx = '以下是当前用户的活跃目标及关键结果列表（请优先结合语义和主题进行匹配，若无关请留空）：\n';
  rankedGoals.slice(0, 20).forEach(({ goal, score }) => {
    ctx += `- [目标 ID: ${goal.id}] 名称: ${goal.title || '未命名目标'} | 匹配分: ${score}\n`;
    if (goal.description) {
      ctx += `    - 目标描述: ${goal.description.substring(0, 80)}\n`;
    }
    if (goal.keyResults && goal.keyResults.length > 0) {
      goal.keyResults.forEach(kr => {
        ctx += `    - [KR ID: ${kr.id}] KR标题: ${kr.title}\n`;
      });
    }
  });
  return ctx;
}

function normalizeTaskParsedResult(rawParsed, inputText, activeGoals) {
  const parsed = rawParsed && typeof rawParsed === 'object' ? { ...rawParsed } : {};
  const result = {
    title: normalizeTaskTitle(String(parsed.title || '').trim(), inputText),
    description: String(parsed.description || '').trim() || inputText,
    priority: ['high', 'normal', 'low'].includes(parsed.priority) ? parsed.priority : 'normal',
    dueDate: resolveTaskDueDate(String(parsed.dueDate || '').trim(), inputText),
    goalId: String(parsed.goalId || '').trim(),
    krId: String(parsed.krId || '').trim(),
    estimatedHours: Number.isFinite(Number(parsed.estimatedHours)) && Number(parsed.estimatedHours) > 0
      ? Number(parsed.estimatedHours)
      : 1
  };

  const llmGoal = Array.isArray(activeGoals) ? activeGoals.find(goal => String(goal.id) === result.goalId) : null;
  const localGoalMatch = pickBestGoalMatchForTask(`${inputText} ${result.title} ${result.description}`, activeGoals);
  const llmGoalScore = llmGoal ? scoreGoalForTask(`${inputText} ${result.title} ${result.description}`, llmGoal) : 0;

  if (localGoalMatch && (!llmGoal || localGoalMatch.score >= llmGoalScore + 1)) {
    result.goalId = localGoalMatch.goal.id;
    if (!result.krId && Array.isArray(localGoalMatch.goal.keyResults) && localGoalMatch.goal.keyResults.length > 0) {
      const rankedKrs = localGoalMatch.goal.keyResults
        .map(kr => ({ kr, score: scoreKrForTask(`${inputText} ${result.title} ${result.description}`, kr) }))
        .sort((first, second) => second.score - first.score);
      if (rankedKrs[0] && rankedKrs[0].score >= 1.5) {
        result.krId = rankedKrs[0].kr.id;
      }
    }
  }

  const selectedGoal = Array.isArray(activeGoals) ? activeGoals.find(goal => String(goal.id) === result.goalId) : null;
  if (result.goalId && !selectedGoal) {
    result.goalId = '';
    result.krId = '';
  } else if (selectedGoal && result.krId) {
    const selectedKr = Array.isArray(selectedGoal.keyResults)
      ? selectedGoal.keyResults.find(kr => String(kr.id) === result.krId)
      : null;
    if (!selectedKr) {
      result.krId = '';
    }
  }

  return result;
}

// ========================
// 获取用户待办任务列表（用于番茄关联匹配）
// ========================
async function getUserPendingTasks(userId) {
  try {
    const syncData = await SyncData.findOne({ userId });
    if (!syncData || !syncData.tasks) return [];
    return syncData.tasks.filter(t => t.status === 'pending').map(t => ({
      id: t.id,
      title: t.title,
      description: t.description || '',
      goalTitle: t.goalTitle || '',
      krTitle: t.krTitle || '',
      subtaskTitles: Array.isArray(t.subtasks) ? t.subtasks.map(subtask => subtask?.title).filter(Boolean) : [],
      priority: t.priority || 'normal',
      isPinned: Boolean(t.isPinned),
      isImportant: Boolean(t.isImportant),
      dueDate: t.dueDate || 0,
      updatedAt: t.updatedAt || 0
    }));
  } catch (e) {
    return [];
  }
}

function buildVoiceInputPrompt(text) {
  return `User voice input: ${text}`;
}

function buildCurrentTimeContext(currentTime) {
  return `Current system time: ${currentTime}`;
}

function sanitizeVoiceTextForAnalysis(rawText) {
  const source = String(rawText || '').trim();
  if (!source) {
    return '';
  }

  let text = source;
  for (let index = 0; index < 3; index++) {
    const next = text
      .replace(/^(喂{2,}|嗯+|呃+|额+|啊+|哦+|噢+|诶+|欸+|哈{2,}|测试一下|测试|你好)[\s，。！？、,.!?；;：:]*/i, '')
      .trim();
    if (next === text) {
      break;
    }
    text = next;
  }

  return text
    .split(/[\s，。！？、,.!?；;：:]+/)
    .map(segment => segment.trim())
    .filter(segment => segment && !isVoiceFillerSegment(segment))
    .join(' ')
    .trim();
}

function isVoiceFillerSegment(segment) {
  const normalized = String(segment || '')
    .trim()
    .toLowerCase()
    .replace(/[\s，。！？、,.!?；;：:]/g, '');
  if (!normalized) {
    return true;
  }
  return /^(喂+|嗯+|呃+|额+|啊+|哦+|噢+|诶+|欸+|哈+|测试一下|测试|听得到吗|能听到吗|你听得到吗|在吗|你好|hello|hi)$/.test(normalized);
}

function normalizeMatchText(text) {
  return String(text || '')
    .toLowerCase()
    .replace(/application/g, ' application app 应用 ')
    .replace(/ios/g, ' ios 苹果 ios ')
    .replace(/iphone/g, ' iphone ios 苹果 ')
    .replace(/android/g, ' android 安卓 ')
    .replace(/app/g, ' app 应用 ')
    .replace(/[《》【】（）()[\]{}"'`]/g, ' ')
    .replace(/[\s，。！？、,.!?；;：:_\-\\/|]+/g, ' ')
    .trim();
}

function compactMatchText(text) {
  return normalizeMatchText(text).replace(/\s+/g, '');
}

function pushUniqueTerm(result, seen, value) {
  const term = String(value || '').trim();
  if (!term || seen.has(term)) {
    return;
  }
  seen.add(term);
  result.push(term);
}

function extractMatchTerms(text) {
  const normalized = normalizeMatchText(text);
  if (!normalized) {
    return [];
  }

  const result = [];
  const seen = new Set();
  const asciiTerms = normalized.match(/[a-z0-9+#]+/g) || [];
  asciiTerms.forEach((term) => {
    if (term.length >= 2) {
      pushUniqueTerm(result, seen, term);
    }
  });

  const chineseSegments = normalized.match(/[\u4e00-\u9fa5]+/g) || [];
  chineseSegments.forEach((segment) => {
    const compactSegment = segment.replace(/(现在|马上|立刻|一下|的|了|呢|吧|呀|啊|嘛|与|和|及|并|去|来|先|再|把|将|我|你|他|她|它|们)/g, '');
    if (compactSegment.length >= 2) {
      pushUniqueTerm(result, seen, compactSegment);
    }
    for (let size = 2; size <= 4; size += 1) {
      for (let index = 0; index <= compactSegment.length - size; index += 1) {
        pushUniqueTerm(result, seen, compactSegment.slice(index, index + size));
      }
    }
  });

  return result.slice(0, 36);
}

function extractFocusSubjectByRules(text) {
  const normalized = String(text || '').trim();
  if (!normalized) {
    return '';
  }

  return normalized
    .replace(/^(?:我)?(?:现在|马上|立刻|这就|先)?\s*(?:开始|进入|切到|切换到|准备|想要|我要)\s*/i, '')
    .replace(/^(?:开始)?\s*(?:专注|番茄|pomodoro|计时|工作)\s*/i, '')
    .replace(/(?:\d+|[零一二两三四五六七八九十百半]+)\s*(?:分钟|分|小时|个小时)\s*$/i, '')
    .replace(/[，。！？、,.!?；;：:]+$/g, '')
    .trim();
}

function parseChineseNumber(text) {
  const normalized = String(text || '').trim();
  if (!normalized) {
    return NaN;
  }
  if (/^\d+(?:\.\d+)?$/.test(normalized)) {
    return Number(normalized);
  }
  if (normalized === '半') {
    return 0.5;
  }

  const digitMap = { '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9 };
  let total = 0;
  let current = 0;

  for (let index = 0; index < normalized.length; index += 1) {
    const char = normalized[index];
    if (digitMap[char] !== undefined) {
      current = digitMap[char];
      if (index === normalized.length - 1) {
        total += current;
      }
      continue;
    }

    if (char === '十') {
      total += (current || 1) * 10;
      current = 0;
      continue;
    }

    if (char === '百') {
      total += (current || 1) * 100;
      current = 0;
      continue;
    }

    return NaN;
  }

  return total || current;
}

function extractFocusDurationByRules(text) {
  const normalized = String(text || '').trim();
  if (!normalized) {
    return 25;
  }

  if (/半小时/.test(normalized)) {
    return 30;
  }

  let match = normalized.match(/(\d+(?:\.\d+)?|[零一二两三四五六七八九十百半]+)\s*(分钟|分|小时|个小时)/);
  if (!match) {
    return 25;
  }

  const amount = parseChineseNumber(match[1]);
  if (!Number.isFinite(amount) || amount <= 0) {
    return 25;
  }

  if (match[2].includes('小时')) {
    return Math.max(5, Math.min(180, Math.round(amount * 60)));
  }

  return Math.max(5, Math.min(180, Math.round(amount)));
}

function getTermWeight(term) {
  const length = String(term || '').length;
  if (length >= 6) {
    return 2.6;
  }
  if (length >= 4) {
    return 1.8;
  }
  if (length >= 3) {
    return 1.3;
  }
  return 1;
}

function scoreFieldMatch(queryTerms, fieldText, weight) {
  if (!fieldText || !Array.isArray(queryTerms) || queryTerms.length === 0) {
    return 0;
  }

  let matchedWeight = 0;
  let totalWeight = 0;
  queryTerms.forEach((term) => {
    const termWeight = getTermWeight(term);
    totalWeight += termWeight;
    if (fieldText.includes(term)) {
      matchedWeight += termWeight;
    }
  });

  if (!totalWeight || !matchedWeight) {
    return 0;
  }
  return (matchedWeight / totalWeight) * weight;
}

function scoreTaskForFocus(text, task) {
  if (!task || !task.id) {
    return 0;
  }

  const focusSubject = extractFocusSubjectByRules(text) || String(text || '').trim();
  const queryTerms = extractMatchTerms(`${focusSubject} ${text}`);
  if (queryTerms.length === 0) {
    return 0;
  }

  const compactSubject = compactMatchText(focusSubject);
  const compactTitle = compactMatchText(task.title);
  const compactGoalTitle = compactMatchText(task.goalTitle);
  const compactKrTitle = compactMatchText(task.krTitle);
  const compactDescription = compactMatchText(task.description);
  const compactSubtasks = compactMatchText(Array.isArray(task.subtaskTitles) ? task.subtaskTitles.join(' ') : '');

  let score = 0;
  if (compactSubject && compactTitle.includes(compactSubject)) {
    score += 6.5;
  } else if (compactSubject && compactTitle && compactSubject.includes(compactTitle) && compactTitle.length >= 4) {
    score += 4;
  }

  if (compactSubject && compactGoalTitle.includes(compactSubject)) {
    score += 3;
  }

  score += scoreFieldMatch(queryTerms, compactTitle, 7);
  score += scoreFieldMatch(queryTerms, compactGoalTitle, 4);
  score += scoreFieldMatch(queryTerms, compactKrTitle, 3);
  score += scoreFieldMatch(queryTerms, compactDescription, 2.5);
  score += scoreFieldMatch(queryTerms, compactSubtasks, 2);

  if (task.isPinned) {
    score += 0.2;
  }
  if (task.isImportant) {
    score += 0.2;
  }
  if (task.priority === 'high') {
    score += 0.15;
  }

  return Number(score.toFixed(3));
}

function rankPendingTasksForFocus(text, pendingTasks) {
  if (!Array.isArray(pendingTasks) || pendingTasks.length === 0) {
    return [];
  }

  return pendingTasks
    .map(task => ({ task, score: scoreTaskForFocus(text, task) }))
    .sort((first, second) => {
      if (second.score !== first.score) {
        return second.score - first.score;
      }
      return (second.task.updatedAt || 0) - (first.task.updatedAt || 0);
    });
}

function pickBestPendingTaskForFocus(text, pendingTasks) {
  const ranked = rankPendingTasksForFocus(text, pendingTasks);
  if (ranked.length === 0) {
    return null;
  }

  const best = ranked[0];
  const runnerUp = ranked[1];
  const leadScore = best.score - (runnerUp?.score || 0);
  if (best.score < 2.6) {
    return null;
  }
  if (best.score < 3.2 && leadScore < 0.6) {
    return null;
  }

  return best;
}

function normalizeFocusParsedResult(parsed, text, pendingTasks) {
  const result = parsed && typeof parsed === 'object' ? { ...parsed } : {};
  const fallbackSubject = extractFocusSubjectByRules(text) || String(text || '').trim().substring(0, 20);
  const requestedSubject = String(result.focusSubject || '').trim();
  const matchingText = requestedSubject || fallbackSubject || String(text || '').trim();
  const localMatch = pickBestPendingTaskForFocus(matchingText, pendingTasks);
  const llmTaskId = String(result.matchedTaskId || '').trim();
  const llmTask = pendingTasks.find(task => String(task.id) === llmTaskId);
  const llmScore = llmTask ? scoreTaskForFocus(matchingText, llmTask) : 0;

  result.focusSubject = requestedSubject || fallbackSubject;
  result.duration = toPositiveInteger(result.duration, extractFocusDurationByRules(text), 5, 180);

  if (llmTask) {
    result.matchedTaskId = llmTask.id;
    result.matchedTaskTitle = llmTask.title;
  }

  if (localMatch && (!llmTask || localMatch.score >= llmScore + 1.2 || !String(result.matchedTaskTitle || '').trim())) {
    result.matchedTaskId = localMatch.task.id;
    result.matchedTaskTitle = localMatch.task.title;
  }

  if (!String(result.matchedTaskId || '').trim()) {
    result.matchedTaskId = '';
    result.matchedTaskTitle = '';
  }

  return result;
}

function isLowQualityTaskParse(parsed, inputText) {
  if (!parsed || typeof parsed !== 'object') {
    return true;
  }

  const title = String(parsed.title || '').trim();
  const description = String(parsed.description || '').trim();
  const input = String(inputText || '').trim();

  if (!title) {
    return true;
  }

  if (title.includes('未识别') || title.includes('缺失') || title.includes('无法解析')) {
    return true;
  }

  if (description.includes('无法解析') || description.includes('检查麦克风') || description.includes('重试清晰')) {
    return true;
  }

  return title === input && description === input;
}

// ========================
// Agent 2a: 任务结构化解析
// ========================
async function parseTask(text, goalsContext) {
  const currentTime = new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' });
  const systemPrompt = `你是四时清单的任务创建助手。用户通过语音输入了一段话，你需要从中提取结构化的待办任务信息。

当前系统时间：${currentTime}
${goalsContext}

请严格输出纯 JSON，不要任何解释：
{
  "title": "简洁的任务标题（8-20字）",
  "description": "任务的补充描述（30-80字，帮助后续执行）",
  "priority": "high | normal | low",
  "dueDate": "计划完成时间字符串(YYYY-MM-DD HH:mm:ss)，若未提及则留空字符串",
  "goalId": "相关联的目标ID，若无则留空字符串",
  "krId": "相关联的KR ID，若无则留空字符串",
  "estimatedHours": 1.0
}`;

  return await callAgent(systemPrompt, `用户语音输入：${text}`, {
    model: VOICE_PARSE_MODEL,
    timeoutMs: VOICE_PARSE_TIMEOUT_MS,
    traceLabel: 'voiceCreate.parseSchedule'
  });
}

// ========================
// Agent 2b: 番茄/专注结构化解析
// ========================
async function parseFocus(text, pendingTasks) {
  let taskListStr = '当前无待办任务。';
  if (pendingTasks.length > 0) {
    taskListStr = '当前用户的待办任务列表（请匹配最相关的）：\n';
    pendingTasks.slice(0, 20).forEach(t => {
      taskListStr += `- [ID: ${t.id}] ${t.title}${t.goalTitle ? ` (目标: ${t.goalTitle})` : ''}\n`;
    });
  }

  const systemPrompt = `你是四时清单的专注/番茄创建助手。用户通过语音想要开始一段专注时间。

${taskListStr}

请提取专注信息并严格输出纯 JSON：
{
  "focusSubject": "专注的核心主题（如 写论文、背单词）",
  "duration": 25,
  "matchedTaskId": "最匹配的待办任务ID，若无则留空字符串",
  "matchedTaskTitle": "匹配的任务标题，若无则留空字符串"
}`;

  return await callAgent(systemPrompt, `用户语音输入：${text}`, {
    model: VOICE_PARSE_MODEL,
    timeoutMs: VOICE_PARSE_TIMEOUT_MS,
    traceLabel: 'voiceCreate.parseFocus'
  });
}

// ========================
// 主接口：POST /analyze
// ========================
const ROUTER_SYSTEM_PROMPT_V2 = `你是四时清单的语音创建意图分流助手。
请把用户的语音文本严格判断为且仅判断为以下四种类型之一：
1. "goal"：长期目标、方向、阶段计划、需要进一步拆解的愿景。
2. "reminder"：提醒、单次提醒、周期提醒、习惯打卡、倒计时、纪念日、固定节奏的提示事项。
3. "task"：一次性、可执行、可完成的具体待办事项。
4. "focus"：用户想立刻开始专注、进入番茄钟、开始做某件事。

判断要求：
- 必须四选一，不允许返回其它类型。
- 优先理解用户当前想“创建什么”，而不是只看关键词。
- 如果一句话表达的是“我现在就开始做某事”，即使内容像任务主题，也优先判断为 "focus"。
- 如果一句话表达的是“帮我记得、到时候提醒我、每天/每周/每月提醒、还有多少天”，判断为 "reminder"。
- 如果一句话表达的是“我要达成什么结果、长期提升什么、今年/这阶段想做到什么”，判断为 "goal"。
- 如果一句话表达的是“要新增一个待办事项，之后找时间完成”，判断为 "task"。

边界判断：
- "focus" vs "task"：关键区别在于是否“立刻开始”。例如“开始写方案”“我现在做 APP 架构设计”是 "focus"；“写方案”“明天做 APP 架构设计”是 "task"。
- "task" vs "reminder"：关键区别在于是否要“提醒”。例如“明天下午提交周报”是 "task"；“明天下午提醒我提交周报”是 "reminder"。
- "goal" vs "task"：关键区别在于是否是长期结果。例“今年完成首个 APP 上架”是 "goal"；“本周输出上架材料”是 "task"。
- 当句子同时包含主题和动作时，优先看用户是要“马上开始”、“新建待办”、“新建提醒”还是“定义长期目标”。

few-shot 示例：
示例 1
输入：我现在开始 APP 的架构设计
输出：{"intent":"focus","confidence":0.96,"reasoning":"表达的是立刻开始做某事"}

示例 2
输入：开始专注做预算表二十五分钟
输出：{"intent":"focus","confidence":0.98,"reasoning":"明确要求立即进入专注状态"}

示例 3
输入：明天下午三点提交周报
输出：{"intent":"task","confidence":0.95,"reasoning":"一次性待完成事项，不是提醒"}

示例 4
输入：这周把 iOS 提审材料补齐
输出：{"intent":"task","confidence":0.94,"reasoning":"本周内完成的具体待办"}

示例 5
输入：明天下午提醒我提交周报
输出：{"intent":"reminder","confidence":0.98,"reasoning":"核心诉求是到时提醒"}

示例 6
输入：每天晚上九点提醒我吃药
输出：{"intent":"reminder","confidence":0.99,"reasoning":"周期性提醒事项"}

示例 7
输入：下周五下午两点提醒我开产品会
输出：{"intent":"reminder","confidence":0.98,"reasoning":"明确要求在具体时间提醒"}

示例 8
输入：今年完成首个 APP 的开发与上架
输出：{"intent":"goal","confidence":0.97,"reasoning":"描述的是年度长期结果"}

示例 9
输入：今年把英语口语提升到可以流畅开会
输出：{"intent":"goal","confidence":0.96,"reasoning":"描述的是长期能力提升目标"}

只返回纯 JSON，不要输出任何解释：
{
  "intent": "task | reminder | goal | focus",
  "confidence": 0.95,
  "reasoning": "一句中文简短理由"
}`;

async function routeIntentV2(text, options = {}) {
  return await callAgent(ROUTER_SYSTEM_PROMPT_V2, buildVoiceInputPrompt(text), {
    model: options.model || VOICE_CLASSIFY_MODEL,
    timeoutMs: options.timeoutMs || VOICE_CLASSIFY_TIMEOUT_MS,
    traceLabel: options.traceLabel || 'voiceCreate.routeIntentV2'
  });
}

async function classifyIntentWithRetry(text, options = {}) {
  try {
    return await routeIntentV2(text, {
      model: options.primaryModel || VOICE_CLASSIFY_MODEL,
      timeoutMs: options.primaryTimeoutMs || VOICE_CLASSIFY_TIMEOUT_MS,
      traceLabel: options.primaryTraceLabel || 'voiceCreate.routeIntentV2.primary'
    });
  } catch (primaryError) {
    const fallbackModel = options.fallbackModel || VOICE_PARSE_MODEL || VOICE_CREATE_MODEL;
    const fallbackTimeoutMs = options.fallbackTimeoutMs || Math.max(VOICE_CLASSIFY_TIMEOUT_MS * 2, VOICE_PARSE_TIMEOUT_MS);
    try {
      return await routeIntentV2(text, {
        model: fallbackModel,
        timeoutMs: fallbackTimeoutMs,
        traceLabel: options.fallbackTraceLabel || 'voiceCreate.routeIntentV2.retry'
      });
    } catch (retryError) {
      retryError.message = `${primaryError.message}; retry=${retryError.message}`;
      throw retryError;
    }
  }
}

async function parseTaskV2(text, goalsContext, options = {}) {
  const currentTime = new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' });
  const systemPrompt = `你是四时清单的任务创建助手，请从用户语音中提取结构化待办信息，并尽量关联到最相关的目标或 KR。
${buildCurrentTimeContext(currentTime)}
${goalsContext}

要求：
- 标题要简洁自然，适合作为待办名称，不要保留“今天/明天/后天/下周三/本周五”等相对时间字样。
- description 用一句话补充任务背景或执行动作。
- 如果这条任务明显服务于某个目标，请返回对应 goalId。
- 如果能明确对应到某个 KR，再返回 krId；否则留空。
- 例如“明天要买一把吉他”如果用户存在“学习吉他”这类目标，应优先关联到该目标。
- 如果用户说了时间，请把时间换算后填入 dueDate，不要继续保留在标题里。
- dueDate 必须严格基于当前系统时间换算成准确日期；例如当前是 2026-06-08（周一）时，“下周三”应换算为 2026-06-17。
- 如果只提到了日期未提具体时刻，dueDate 返回 YYYY-MM-DD；只有用户明确说了几点几分，才返回 YYYY-MM-DD HH:mm:ss。
- 只返回纯 JSON，不要输出任何解释。

{
  "title": "20字以内的任务标题",
  "description": "简短补充描述",
  "priority": "high | normal | low",
  "dueDate": "YYYY-MM-DD HH:mm:ss 或空字符串",
  "goalId": "匹配到的目标ID或空字符串",
  "krId": "匹配到的KR ID或空字符串",
  "estimatedHours": 1.0
}`;

  return await callAgent(systemPrompt, buildVoiceInputPrompt(text), {
    model: options.model || VOICE_PARSE_MODEL,
    timeoutMs: options.timeoutMs || VOICE_PARSE_TIMEOUT_MS,
    traceLabel: options.traceLabel || 'voiceCreate.parseScheduleV2'
  });
}

async function parseFocusV2(text, pendingTasks, options = {}) {
  let taskListStr = 'No pending tasks.';
  if (pendingTasks.length > 0) {
    taskListStr = 'Pending tasks:\\n';
    rankPendingTasksForFocus(text, pendingTasks).slice(0, 30).forEach(({ task, score }) => {
      taskListStr += `- [ID: ${task.id}] ${task.title}`;
      if (task.goalTitle) {
        taskListStr += ` (Goal: ${task.goalTitle})`;
      }
      if (task.krTitle) {
        taskListStr += ` (KR: ${task.krTitle})`;
      }
      if (task.description) {
        taskListStr += ` | Desc: ${task.description.substring(0, 60)}`;
      }
      if (Array.isArray(task.subtaskTitles) && task.subtaskTitles.length > 0) {
        taskListStr += ` | Subtasks: ${task.subtaskTitles.slice(0, 3).join(' / ')}`;
      }
      taskListStr += ` | Score: ${score}\\n`;
    });
  }

  const systemPrompt = `You extract a structured focus-session request from the user's voice input.
${taskListStr}

Return pure JSON only:
{
  "focusSubject": "main subject",
  "duration": 25,
  "matchedTaskId": "best matched task ID or empty string",
  "matchedTaskTitle": "best matched task title or empty string"
}`;

  const parsed = await callAgent(systemPrompt, buildVoiceInputPrompt(text), {
    model: options.model || VOICE_PARSE_MODEL,
    timeoutMs: options.timeoutMs || VOICE_PARSE_TIMEOUT_MS,
    traceLabel: options.traceLabel || 'voiceCreate.parseFocusV2'
  });

  return normalizeFocusParsedResult(parsed, text, pendingTasks);
}

function padDateValue(value) {
  return String(value).padStart(2, '0');
}

function formatDateValue(date) {
  return `${date.getFullYear()}-${padDateValue(date.getMonth() + 1)}-${padDateValue(date.getDate())}`;
}

function createLocalDate(year, month, day) {
  return new Date(year, month - 1, day, 12, 0, 0, 0);
}

function isValidDate(date) {
  return date instanceof Date && !Number.isNaN(date.getTime());
}

function addDateUnit(baseDate, amount, unit) {
  const nextDate = new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate(), 12, 0, 0, 0);
  if (unit === 'year') {
    nextDate.setFullYear(nextDate.getFullYear() + amount);
    return nextDate;
  }
  if (unit === 'month') {
    nextDate.setMonth(nextDate.getMonth() + amount);
    return nextDate;
  }
  if (unit === 'week') {
    nextDate.setDate(nextDate.getDate() + amount * 7);
    return nextDate;
  }
  nextDate.setDate(nextDate.getDate() + amount);
  return nextDate;
}

function normalizeDateString(value, baseDate) {
  if (value === undefined || value === null) {
    return '';
  }

  const text = String(value).trim();
  if (!text) {
    return '';
  }

  let match = text.match(/^(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})(?:日)?$/);
  if (match) {
    const parsed = createLocalDate(Number(match[1]), Number(match[2]), Number(match[3]));
    return isValidDate(parsed) ? formatDateValue(parsed) : '';
  }

  match = text.match(/^(\d{1,2})月(\d{1,2})[日号]?$/);
  if (match) {
    let year = baseDate.getFullYear();
    let parsed = createLocalDate(year, Number(match[1]), Number(match[2]));
    if (parsed.getTime() < createLocalDate(baseDate.getFullYear(), baseDate.getMonth() + 1, baseDate.getDate()).getTime()) {
      year += 1;
      parsed = createLocalDate(year, Number(match[1]), Number(match[2]));
    }
    return isValidDate(parsed) ? formatDateValue(parsed) : '';
  }

  return '';
}

function extractExplicitDate(text, baseDate) {
  const normalized = normalizeDateString(text, baseDate);
  return normalized || '';
}

function extractRelativeDate(text, baseDate) {
  const normalized = String(text || '').trim();

  if (/今天/.test(normalized)) {
    return formatDateValue(baseDate);
  }
  if (/明天/.test(normalized)) {
    return formatDateValue(addDateUnit(baseDate, 1, 'day'));
  }
  if (/后天/.test(normalized)) {
    return formatDateValue(addDateUnit(baseDate, 2, 'day'));
  }

  let match = normalized.match(/(?:还有|剩|只剩|倒计时|距离).*?(\d+)\s*(天|日|周|个月|月|年)/);
  if (!match) {
    match = normalized.match(/(\d+)\s*(天|日|周|个月|月|年)后/);
  }
  if (match) {
    const amount = Number(match[1]);
    const unitText = match[2];
    const unit = unitText === '周' ? 'week' : (unitText === '个月' || unitText === '月' ? 'month' : (unitText === '年' ? 'year' : 'day'));
    return formatDateValue(addDateUnit(baseDate, amount, unit));
  }

  const weekdayMatch = normalized.match(/下周([一二三四五六日天])/);
  if (weekdayMatch) {
    const weekdayMap = { '日': 0, '天': 0, '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6 };
    const targetWeekday = weekdayMap[weekdayMatch[1]];
    if (targetWeekday !== undefined) {
      const todayWeekday = baseDate.getDay();
      let delta = targetWeekday - todayWeekday;
      if (delta <= 0) {
        delta += 7;
      }
      delta += 7;
      return formatDateValue(addDateUnit(baseDate, delta, 'day'));
    }
  }

  return '';
}

function extractReminderTime(text) {
  const normalized = String(text || '').trim();
  let defaultHour = 9;
  if (/(晚上|今晚|夜里|夜间|夜晚|睡前)/.test(normalized)) {
    defaultHour = 21;
  } else if (/(下午)/.test(normalized)) {
    defaultHour = 15;
  } else if (/(中午)/.test(normalized)) {
    defaultHour = 12;
  } else if (/(早上|早晨|清晨|上午)/.test(normalized)) {
    defaultHour = 8;
  }

  let match = normalized.match(/(\d{1,2})\s*[:：]\s*(\d{1,2})/);
  if (match) {
    let hour = Number(match[1]);
    const minute = Number(match[2]);
    if (/(下午|晚上|今晚|夜里|夜间|夜晚)/.test(normalized) && hour < 12) {
      hour += 12;
    } else if (/(中午)/.test(normalized) && hour < 11) {
      hour += 12;
    } else if (/(凌晨)/.test(normalized) && hour === 12) {
      hour = 0;
    }
    return {
      hour: Math.max(0, Math.min(23, hour)),
      minute: Math.max(0, Math.min(59, minute))
    };
  }

  match = normalized.match(/(\d{1,2})\s*点半/);
  if (match) {
    let hour = Number(match[1]);
    if (/(下午|晚上|今晚|夜里|夜间|夜晚)/.test(normalized) && hour < 12) {
      hour += 12;
    } else if (/(中午)/.test(normalized) && hour < 11) {
      hour += 12;
    }
    return {
      hour: Math.max(0, Math.min(23, hour)),
      minute: 30
    };
  }

  match = normalized.match(/(\d{1,2})\s*点(?:(\d{1,2})分?)?/);
  if (match) {
    let hour = Number(match[1]);
    const minute = match[2] ? Number(match[2]) : 0;
    if (/(下午|晚上|今晚|夜里|夜间|夜晚)/.test(normalized) && hour < 12) {
      hour += 12;
    } else if (/(中午)/.test(normalized) && hour < 11) {
      hour += 12;
    } else if (/(凌晨)/.test(normalized) && hour === 12) {
      hour = 0;
    }
    return {
      hour: Math.max(0, Math.min(23, hour)),
      minute: Math.max(0, Math.min(59, minute))
    };
  }

  return { hour: defaultHour, minute: 0 };
}

function hasExplicitClockTime(text) {
  const normalized = String(text || '').trim();
  return /(\d{1,2})\s*[:：]\s*(\d{1,2})|(\d{1,2})\s*点半|(\d{1,2})\s*点(\d{1,2})?分?/.test(normalized);
}

function stripTaskTemporalInfo(text) {
  return String(text || '')
    .replace(/(?:今天|明天|后天|今晚|今早|今晨|本周[一二三四五六日天]|这周[一二三四五六日天]|下周[一二三四五六日天]|周[一二三四五六日天]|星期[一二三四五六日天])/g, ' ')
    .replace(/(?:\d{4}[/-]\d{1,2}[/-]\d{1,2}|\d{1,2}月\d{1,2}[日号]?)/g, ' ')
    .replace(/(?:凌晨|清晨|早上|上午|中午|下午|晚上|今晚|夜里|夜间|夜晚)/g, ' ')
    .replace(/(?:\d{1,2}\s*[:：]\s*\d{1,2}|\d{1,2}\s*点半|\d{1,2}\s*点(?:\d{1,2})?分?)/g, ' ')
    .replace(/(?:前|之前|当天|那天|时候|左右|前后)/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeTaskTitle(title, inputText) {
  let cleaned = stripTaskTemporalInfo(title)
    .replace(/^(请|帮我|麻烦|记得|需要|我要|我想|准备|打算|计划|安排|要)\s*/, '')
    .replace(/[，。！？、,.!?；;：:]+$/, '')
    .trim();

  if (!cleaned) {
    cleaned = stripTaskTemporalInfo(inputText)
      .replace(/^(请|帮我|麻烦|记得|需要|我要|我想|准备|打算|计划|安排|要)\s*/, '')
      .replace(/[，。！？、,.!?；;：:]+$/, '')
      .trim();
  }

  if (!cleaned) {
    cleaned = String(title || inputText || '').trim();
  }

  return cleaned.substring(0, 30);
}

function resolveTaskDueDate(existingDueDate, inputText) {
  const normalizedText = String(inputText || '').trim();
  const baseDate = new Date();
  const explicitDate = extractExplicitDate(normalizedText, baseDate);
  const relativeDate = extractRelativeDate(normalizedText, baseDate);
  const resolvedDate = explicitDate || relativeDate;

  if (!resolvedDate) {
    return String(existingDueDate || '').trim();
  }

  if (!hasExplicitClockTime(normalizedText)) {
    return resolvedDate;
  }

  const time = extractReminderTime(normalizedText);
  const hour = String(time.hour).padStart(2, '0');
  const minute = String(time.minute).padStart(2, '0');
  return `${resolvedDate} ${hour}:${minute}:00`;
}

function extractWeekdays(text) {
  const normalized = String(text || '').trim();
  const weekdayMap = { '日': 0, '天': 0, '一': 1, '二': 2, '三': 3, '四': 4, '五': 5, '六': 6 };
  const results = [];
  const explicitPattern = /(周|星期)([一二三四五六日天])/g;
  let match;

  while ((match = explicitPattern.exec(normalized)) !== null) {
    const mapped = weekdayMap[match[2]];
    if (mapped !== undefined && !results.includes(mapped)) {
      results.push(mapped);
    }
  }

  if (results.length === 0) {
    const compactMatch = normalized.match(/每周([一二三四五六日天]+)/);
    if (compactMatch) {
      const chars = compactMatch[1].split('');
      chars.forEach((char) => {
        const mapped = weekdayMap[char];
        if (mapped !== undefined && !results.includes(mapped)) {
          results.push(mapped);
        }
      });
    }
  }

  return results.sort((first, second) => first - second);
}

function toPositiveInteger(value, fallback, min = 0, max = Number.MAX_SAFE_INTEGER) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  const rounded = Math.round(parsed);
  if (rounded < min) {
    return fallback;
  }
  return Math.min(max, rounded);
}

function toBooleanValue(value) {
  if (value === true || value === 'true') {
    return true;
  }
  if (value === false || value === 'false') {
    return false;
  }
  return undefined;
}

function isValidReminderType(value) {
  return ['single', 'periodic', 'habit', 'milestone', 'counter', 'countdown'].includes(value);
}

function extractReminderTitle(text) {
  const normalized = String(text || '').trim();
  let match = normalized.match(/(?:提醒我|提醒|叫我|记得)(.+)$/);
  if (match && match[1]) {
    return match[1].trim();
  }

  match = normalized.match(/距离(.+?)(?:还有|只剩|倒计时)/);
  if (match && match[1]) {
    return match[1].trim();
  }

  let title = normalized
    .replace(/^(请|帮我|麻烦|记得|我要|我想|需要)/, '')
    .replace(/(?:每天|每日|每周[一二三四五六日天]?|每月\d+[号日]?|每隔\d+天)/g, '')
    .replace(/(?:早上|上午|中午|下午|晚上|今晚|夜里|夜间|夜晚|睡前)?\s*\d{1,2}(?::\d{1,2})?(?:点半|点\d{0,2}分?)?/g, '')
    .replace(/(?:今天|明天|后天|下周[一二三四五六日天])/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  if (!title) {
    title = normalized;
  }
  return title.substring(0, 30);
}

function buildReminderFallback(text, baseDate) {
  const normalized = String(text || '').trim();
  const weekdays = extractWeekdays(normalized);
  const explicitDate = extractExplicitDate(normalized, baseDate);
  const relativeDate = extractRelativeDate(normalized, baseDate);
  const time = extractReminderTime(normalized);
  const title = extractReminderTitle(normalized);

  const fallback = {
    title,
    rawText: normalized,
    eventType: 'periodic',
    periodicMode: 'daily',
    habitMode: 'daily',
    counterMode: 'interval',
    startDate: formatDateValue(baseDate),
    endDate: '',
    hasEndDate: false,
    targetDate: '',
    hour: time.hour,
    minute: time.minute,
    weekday: weekdays[0] !== undefined ? weekdays[0] : baseDate.getDay(),
    dayOfMonth: baseDate.getDate(),
    intervalDays: 3,
    timesPerPeriod: weekdays.length > 1 ? weekdays.length : 3,
    leadDays: 0,
    offsetValue: 100,
    offsetUnit: 'day'
  };

  const habitKeyword = /(打卡|习惯|坚持|养成)/.test(normalized);
  const countdownKeyword = /(倒计时|距离|还有\d+\s*(天|日|周|个月|月|年)|只剩)/.test(normalized);
  const counterKeyword = /(纪念日|恋爱|结婚|在一起|相识|周年)/.test(normalized);
  const weeklyCountMatch = normalized.match(/每周\s*(\d+)\s*次/);
  const monthlyCountMatch = normalized.match(/每月\s*(\d+)\s*次/);
  const monthlyDayMatch = normalized.match(/每月\s*(\d{1,2})\s*[号日]/);
  const intervalMatch = normalized.match(/每隔\s*(\d+)\s*天/);
  const leadDayMatch = normalized.match(/提前\s*(\d+)\s*天/);
  const counterIntervalMatch = normalized.match(/(?:第|满)?\s*(\d+)\s*(天|个月|月|年)/);
  const startDateMatch = normalized.match(/[从自](\d{4}[-/.年]\d{1,2}[-/.月]\d{1,2}(?:日)?|\d{1,2}月\d{1,2}[日号]?)/);
  const milestoneKeyword = /(生日|除夕|春节|跨年|出发|出行|婚礼|婚宴|纪念|周年|演唱会|发布会|考试|面试|开学|毕业|ddl|截止日|大日子|重要日子)/.test(normalized);

  if (countdownKeyword) {
    fallback.eventType = 'countdown';
    fallback.targetDate = relativeDate || explicitDate || formatDateValue(addDateUnit(baseDate, 30, 'day'));
    return fallback;
  }

  if (counterKeyword) {
    fallback.eventType = 'counter';
    if (startDateMatch && startDateMatch[1]) {
      const parsedStartDate = normalizeDateString(startDateMatch[1], baseDate);
      if (parsedStartDate) {
        fallback.startDate = parsedStartDate;
      }
    }
    if (explicitDate || relativeDate) {
      fallback.counterMode = 'date';
      fallback.targetDate = explicitDate || relativeDate;
    } else if (counterIntervalMatch) {
      fallback.counterMode = 'interval';
      fallback.offsetValue = toPositiveInteger(counterIntervalMatch[1], 100, 1, 9999);
      fallback.offsetUnit = counterIntervalMatch[2] === '年' ? 'year' : (counterIntervalMatch[2] === '个月' || counterIntervalMatch[2] === '月' ? 'month' : 'day');
    }
    return fallback;
  }

  if (habitKeyword || weekdays.length > 1 || weeklyCountMatch || monthlyCountMatch) {
    fallback.eventType = 'habit';
    if (weeklyCountMatch) {
      fallback.habitMode = 'weekly';
      fallback.timesPerPeriod = toPositiveInteger(weeklyCountMatch[1], fallback.timesPerPeriod, 1, 31);
    } else if (monthlyCountMatch) {
      fallback.habitMode = 'monthly';
      fallback.timesPerPeriod = toPositiveInteger(monthlyCountMatch[1], 12, 1, 99);
    } else if (weekdays.length > 1) {
      fallback.habitMode = 'weekly';
      fallback.timesPerPeriod = weekdays.length;
    } else {
      fallback.habitMode = 'daily';
    }
    return fallback;
  }

  if (explicitDate || relativeDate) {
    fallback.eventType = (leadDayMatch || milestoneKeyword) ? 'milestone' : 'single';
    fallback.targetDate = explicitDate || relativeDate;
    fallback.leadDays = leadDayMatch ? toPositiveInteger(leadDayMatch[1], 0, 0, 365) : 0;
    return fallback;
  }

  fallback.eventType = 'periodic';
  if (intervalMatch) {
    fallback.periodicMode = 'interval';
    fallback.intervalDays = toPositiveInteger(intervalMatch[1], 3, 1, 365);
  } else if (monthlyDayMatch) {
    fallback.periodicMode = 'monthly';
    fallback.dayOfMonth = toPositiveInteger(monthlyDayMatch[1], baseDate.getDate(), 1, 31);
  } else if (weekdays.length === 1) {
    fallback.periodicMode = 'weekly';
    fallback.weekday = weekdays[0];
  } else {
    fallback.periodicMode = 'daily';
  }

  return fallback;
}

function normalizeReminderParsed(rawParsed, fallback, inputText, baseDate) {
  const parsed = rawParsed && typeof rawParsed === 'object' ? rawParsed : {};
  const result = {
    title: fallback.title || inputText.substring(0, 30),
    rawText: inputText,
    eventType: fallback.eventType,
    periodicMode: fallback.periodicMode,
    habitMode: fallback.habitMode,
    counterMode: fallback.counterMode,
    startDate: fallback.startDate,
    endDate: fallback.endDate,
    hasEndDate: fallback.hasEndDate,
    targetDate: fallback.targetDate,
    hour: fallback.hour,
    minute: fallback.minute,
    weekday: fallback.weekday,
    dayOfMonth: fallback.dayOfMonth,
    intervalDays: fallback.intervalDays,
    timesPerPeriod: fallback.timesPerPeriod,
    leadDays: fallback.leadDays,
    offsetValue: fallback.offsetValue,
    offsetUnit: fallback.offsetUnit
  };

  if (typeof parsed.title === 'string' && parsed.title.trim()) {
    result.title = parsed.title.trim().substring(0, 30);
  }

  if (isValidReminderType(parsed.eventType)) {
    result.eventType = parsed.eventType;
  }

  if (['daily', 'weekly', 'monthly', 'interval'].includes(parsed.periodicMode)) {
    result.periodicMode = parsed.periodicMode;
  }
  if (['daily', 'weekly', 'monthly'].includes(parsed.habitMode)) {
    result.habitMode = parsed.habitMode;
  }
  if (['interval', 'date'].includes(parsed.counterMode)) {
    result.counterMode = parsed.counterMode;
  }

  const startDate = normalizeDateString(parsed.startDate, baseDate);
  const endDate = normalizeDateString(parsed.endDate, baseDate);
  const targetDate = normalizeDateString(parsed.targetDate, baseDate);
  if (startDate) {
    result.startDate = startDate;
  }
  if (endDate) {
    result.endDate = endDate;
  }
  if (targetDate) {
    result.targetDate = targetDate;
  }

  const hasEndDate = toBooleanValue(parsed.hasEndDate);
  if (hasEndDate !== undefined) {
    result.hasEndDate = hasEndDate;
  } else if (result.endDate) {
    result.hasEndDate = true;
  }

  result.hour = toPositiveInteger(parsed.hour, result.hour, 0, 23);
  result.minute = toPositiveInteger(parsed.minute, result.minute, 0, 59);
  result.weekday = toPositiveInteger(parsed.weekday, result.weekday, 0, 6);
  result.dayOfMonth = toPositiveInteger(parsed.dayOfMonth, result.dayOfMonth, 1, 31);
  result.intervalDays = toPositiveInteger(parsed.intervalDays, result.intervalDays, 1, 365);
  result.timesPerPeriod = toPositiveInteger(parsed.timesPerPeriod, result.timesPerPeriod, 1, 99);
  result.leadDays = toPositiveInteger(parsed.leadDays, result.leadDays, 0, 365);
  result.offsetValue = toPositiveInteger(parsed.offsetValue, result.offsetValue, 1, 9999);

  if (['day', 'month', 'year'].includes(parsed.offsetUnit)) {
    result.offsetUnit = parsed.offsetUnit;
  }

  if (result.eventType === 'countdown' && !result.targetDate) {
    result.targetDate = fallback.targetDate || formatDateValue(addDateUnit(baseDate, 30, 'day'));
  }
  if (result.eventType === 'single' && !result.targetDate) {
    result.targetDate = fallback.targetDate || formatDateValue(addDateUnit(baseDate, 1, 'day'));
  }
  if (result.eventType === 'milestone' && !result.targetDate) {
    result.targetDate = fallback.targetDate || formatDateValue(addDateUnit(baseDate, 7, 'day'));
  }
  if (result.eventType === 'counter' && result.counterMode === 'date' && !result.targetDate) {
    result.targetDate = fallback.targetDate || formatDateValue(addDateUnit(baseDate, 100, 'day'));
  }
  if (result.eventType === 'counter' && !result.startDate) {
    result.startDate = fallback.startDate || formatDateValue(baseDate);
  }
  if (!result.title) {
    result.title = inputText.substring(0, 30);
  }

  return result;
}

async function parseReminderV2(text, options = {}) {
  // 使用 Asia/Shanghai 时区创建 baseDate，确保与 currentTime 一致
  const currentTimeStr = new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' });
  const baseDate = new Date(currentTimeStr);
  const fallback = buildReminderFallback(text, baseDate);
  const currentTime = currentTimeStr;
  const systemPrompt = `You extract a reminder payload for a productivity app.
${buildCurrentTimeContext(currentTime)}

The app only supports these reminder types:
- "single": one-time reminder at a specific date and time, targetDate required
- "periodic": periodic reminder with periodicMode = daily | weekly | monthly | interval
- "habit": habit reminder with habitMode = daily | weekly | monthly
- "milestone": one important date, targetDate required
- "counter": a milestone counted from startDate, with counterMode = interval | date
- "countdown": targetDate required

Return pure JSON only:
{
  "title": "short reminder title",
  "eventType": "single | periodic | habit | milestone | counter | countdown",
  "periodicMode": "daily | weekly | monthly | interval",
  "habitMode": "daily | weekly | monthly",
  "counterMode": "interval | date",
  "startDate": "YYYY-MM-DD or empty string",
  "endDate": "YYYY-MM-DD or empty string",
  "hasEndDate": false,
  "targetDate": "YYYY-MM-DD or empty string",
  "hour": 21,
  "minute": 0,
  "weekday": 1,
  "dayOfMonth": 15,
  "intervalDays": 3,
  "timesPerPeriod": 3,
  "leadDays": 0,
  "offsetValue": 100,
  "offsetUnit": "day | month | year"
}

Rules:
- If the user says "明天下午提醒我交材料" or another one-time reminder at a specific date and time, use "single".
- If the user says multiple weekdays like "每周一三五跑步", use habit weekly and set timesPerPeriod to the count.
- If the user says "距离考试还有30天", use countdown and calculate targetDate.
- If the user gives a specific date like "5月20日提醒我..." and there is no "提前几天" or important-day meaning, use "single".
- If the text is about a key date such as birthday, departure day, exam day, wedding day or says "提前几天提醒", use "milestone".
- Keep fields compatible with the supported schema only.`;

  try {
    const aiParsed = await callAgent(systemPrompt, buildVoiceInputPrompt(text), {
      model: options.model || VOICE_PARSE_MODEL,
      timeoutMs: options.timeoutMs || VOICE_PARSE_TIMEOUT_MS,
      traceLabel: options.traceLabel || 'voiceCreate.parseReminderV2'
    });
    return normalizeReminderParsed(aiParsed, fallback, text, baseDate);
  } catch (error) {
    console.warn(`[voiceCreate] trace=${options.traceId || 'voice_unknown'} 提醒解析 Agent 失败，使用规则兜底:`, error.message);
    return fallback;
  }
}

function extractQuickTitle(text, intent) {
  const normalized = String(text || '').trim();
  if (!normalized) return normalized;

  if (intent === 'task') {
    return normalizeTaskTitle(normalized, normalized);
  }
  if (intent === 'reminder') {
    return extractReminderTitle(normalized);
  }
  if (intent === 'focus') {
    return normalized
      .replace(/^(开始)?专注|番茄|pomodoro|计时/, '')
      .trim()
      .substring(0, 20);
  }
  if (intent === 'goal') {
    return normalized.substring(0, 30);
  }
  return normalized.substring(0, 30);
}

router.post('/analyze', async (req, res) => {
  let traceId = 'voice_unknown';
  const startedAt = Date.now();
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ success: false, message: '未登录' });
    }

    const { text, traceId: requestTraceId } = req.body || {};
    traceId = normalizeTraceId(requestTraceId);
    if (!text || typeof text !== 'string' || !text.trim()) {
      return res.status(400).json({
        success: false,
        message: '缺少语音文本',
        data: buildVoiceErrorData('missing_text', traceId)
      });
    }

    const rawInputText = text.trim();
    const inputText = sanitizeVoiceTextForAnalysis(rawInputText);
    console.log(`[voiceCreate] trace=${traceId} user=${userId} text="${clipLogText(rawInputText)}" analysis="${clipLogText(inputText)}"`);
    if (!inputText) {
      return res.json({
        success: false,
        message: '只听到了无效语气词，请直接说任务、提醒或目标',
        data: buildVoiceErrorData('empty_analysis_text', traceId, { rawText: rawInputText })
      });
    }

    // Step 1: 意图分流（直接调用 LLM）
    let intentResult;
    try {
      intentResult = await classifyIntentWithRetry(inputText, {
        primaryTimeoutMs: VOICE_CLASSIFY_TIMEOUT_MS,
        fallbackTimeoutMs: Math.max(VOICE_ANALYZE_TIMEOUT_MS, VOICE_CLASSIFY_TIMEOUT_MS * 2)
      });
    } catch (e) {
      const errorCode = getAgentErrorCode(e, 'classify_timeout', 'router_failed');
      console.error(`[voiceCreate] trace=${traceId} 意图分流 Agent 失败:`, e.message);
      return res.json({
        success: false,
        message: '语音理解失败，请重试',
        data: buildVoiceErrorData(errorCode, traceId)
      });
    }

    const intent = intentResult?.intent;
    const confidence = intentResult?.confidence || 0;

    if (!intent || !['task', 'reminder', 'goal', 'focus'].includes(intent)) {
      return res.json({
        success: false,
        message: '无法理解您的意图，请重新描述',
        data: buildVoiceErrorData('unknown_intent', traceId, { intent: 'unknown', confidence })
      });
    }

    console.log(`[voiceCreate] trace=${traceId} intent=${intent} confidence=${confidence}`);

    // Step 2: 按 intent 调用专属解析 Agent
    let parsed = {};

    if (intent === 'task') {
      const activeGoals = await getUserActiveGoals(userId);
      const goalsContext = buildGoalsContext(activeGoals, inputText);
      try {
        parsed = await parseTaskV2(inputText, goalsContext, {
          timeoutMs: VOICE_ANALYZE_TIMEOUT_MS
        });
        parsed = normalizeTaskParsedResult(parsed, inputText, activeGoals);
        if (isLowQualityTaskParse(parsed, inputText)) {
          parsed = normalizeTaskParsedResult({
            title: inputText.substring(0, 30),
            description: inputText,
            priority: 'normal',
            dueDate: '',
            goalId: '',
            krId: '',
            estimatedHours: 1
          }, inputText, activeGoals);
        }
      } catch (e) {
        console.error(`[voiceCreate] trace=${traceId} 任务解析 Agent 失败:`, e.message);
        // fallback：用原始文本作为标题
        parsed = normalizeTaskParsedResult({ title: inputText.substring(0, 30), description: inputText, priority: 'normal' }, inputText, activeGoals);
      }

    } else if (intent === 'goal') {
      // 目标类型：不需要额外解析，直接把原始文本传给 GoalBreakdownPage
      parsed = { intentText: inputText };

    } else if (intent === 'reminder') {
      parsed = await parseReminderV2(inputText, {
        traceId,
        timeoutMs: VOICE_ANALYZE_TIMEOUT_MS
      });

    } else if (intent === 'focus') {
      const pendingTasks = await getUserPendingTasks(userId);
      try {
        parsed = await parseFocusV2(inputText, pendingTasks, {
          timeoutMs: VOICE_ANALYZE_TIMEOUT_MS
        });
      } catch (e) {
        console.error(`[voiceCreate] trace=${traceId} 番茄解析 Agent 失败:`, e.message);
        parsed = normalizeFocusParsedResult({ focusSubject: inputText.substring(0, 20), duration: 25 }, inputText, pendingTasks);
      }
    }

    console.log(`[voiceCreate] trace=${traceId} done intent=${intent} latency=${Date.now() - startedAt}ms`);
    res.json({
      success: true,
      data: {
        intent,
        confidence,
        parsed,
        traceId
      }
    });

  } catch (error) {
    console.error(`[voiceCreate] trace=${traceId} 接口异常:`, error);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// ========================
// 新接口：POST /classify — 仅意图分流（快速，目标 < 2s）
// ========================
router.post('/classify', async (req, res) => {
  let traceId = 'voice_unknown';
  const startedAt = Date.now();
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ success: false, message: '未登录' });
    }

    const { text, traceId: requestTraceId } = req.body || {};
    traceId = normalizeTraceId(requestTraceId);
    if (!text || typeof text !== 'string' || !text.trim()) {
      return res.status(400).json({
        success: false,
        message: '缺少语音文本',
        data: buildVoiceErrorData('missing_text', traceId)
      });
    }

    const rawInputText = text.trim();
    const inputText = sanitizeVoiceTextForAnalysis(rawInputText);
    console.log(`[voiceCreate:classify] trace=${traceId} user=${userId} text="${clipLogText(rawInputText)}"`);

    if (!inputText) {
      return res.json({
        success: false,
        message: '未识别到有效内容',
        data: buildVoiceErrorData('empty_analysis_text', traceId, { rawText: rawInputText })
      });
    }

    // Step 1: LLM 分流（使用快速模型）
    try {
      const intentResult = await classifyIntentWithRetry(inputText, {
        primaryTimeoutMs: VOICE_CLASSIFY_TIMEOUT_MS,
        fallbackTimeoutMs: Math.max(VOICE_PARSE_TIMEOUT_MS, VOICE_CLASSIFY_TIMEOUT_MS * 2)
      });
      const intent = intentResult?.intent;
      const confidence = intentResult?.confidence || 0;

      if (!intent || !['task', 'reminder', 'goal', 'focus'].includes(intent)) {
        return res.json({
          success: false,
          message: '无法理解您的意图，请重新描述',
          data: buildVoiceErrorData('unknown_intent', traceId, { intent: 'unknown', confidence })
        });
      }

      console.log(`[voiceCreate:classify] trace=${traceId} source=llm intent=${intent} confidence=${confidence} latency=${Date.now() - startedAt}ms`);
      res.json({
        success: true,
        data: {
          intent,
          confidence,
          title_candidate: extractQuickTitle(inputText, intent),
          source: 'llm',
          traceId
        }
      });
    } catch (e) {
      const errorCode = getAgentErrorCode(e, 'classify_timeout', 'router_failed');
      console.error(`[voiceCreate:classify] trace=${traceId} errorCode=${errorCode} LLM 失败:`, e.message);
      res.json({
        success: false,
        message: '语音理解失败，请重试',
        data: buildVoiceErrorData(errorCode, traceId)
      });
    }
  } catch (error) {
    console.error(`[voiceCreate:classify] trace=${traceId} 接口异常:`, error);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// ========================
// 新接口：POST /parse — 按意图做字段抽取（意图已确定）
// ========================
router.post('/parse', async (req, res) => {
  let traceId = 'voice_unknown';
  const startedAt = Date.now();
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ success: false, message: '未登录' });
    }

    const { text, intent, traceId: requestTraceId } = req.body || {};
    traceId = normalizeTraceId(requestTraceId);
    if (!text || typeof text !== 'string' || !text.trim()) {
      return res.status(400).json({
        success: false,
        message: '缺少语音文本',
        data: buildVoiceErrorData('missing_text', traceId)
      });
    }
    if (!intent || !['task', 'reminder', 'goal', 'focus'].includes(intent)) {
      return res.status(400).json({
        success: false,
        message: '缺少或无效的 intent 参数',
        data: buildVoiceErrorData('invalid_intent', traceId)
      });
    }

    const rawInputText = text.trim();
    const inputText = sanitizeVoiceTextForAnalysis(rawInputText);
    if (!inputText) {
      return res.json({
        success: false,
        message: '未识别到有效内容',
        data: buildVoiceErrorData('empty_analysis_text', traceId)
      });
    }

    // 检查缓存
    const cached = getCachedParse(userId, inputText, intent);
    if (cached) {
      console.log(`[voiceCreate:parse] trace=${traceId} cache=hit intent=${intent} latency=${Date.now() - startedAt}ms`);
      return res.json({ success: true, data: { intent, parsed: cached, traceId } });
    }

    console.log(`[voiceCreate:parse] trace=${traceId} user=${userId} intent=${intent} text="${clipLogText(inputText)}"`);

    let parsed = {};

    if (intent === 'task') {
      const activeGoals = await getUserActiveGoals(userId);
      const goalsContext = buildGoalsContext(activeGoals, inputText);
      try {
        parsed = await parseTaskV2(inputText, goalsContext, {
          timeoutMs: VOICE_PARSE_TIMEOUT_MS
        });
        parsed = normalizeTaskParsedResult(parsed, inputText, activeGoals);
        if (isLowQualityTaskParse(parsed, inputText)) {
          parsed = normalizeTaskParsedResult({
            title: inputText.substring(0, 30),
            description: inputText,
            priority: 'normal',
            dueDate: '',
            goalId: '',
            krId: '',
            estimatedHours: 1
          }, inputText, activeGoals);
        }
      } catch (e) {
        const errorCode = getAgentErrorCode(e, 'parse_timeout', 'task_parse_failed');
        console.error(`[voiceCreate:parse] trace=${traceId} errorCode=${errorCode} 任务解析 Agent 失败:`, e.message);
        parsed = normalizeTaskParsedResult({ title: inputText.substring(0, 30), description: inputText, priority: 'normal' }, inputText, activeGoals);
      }

    } else if (intent === 'goal') {
      parsed = { intentText: inputText };

    } else if (intent === 'reminder') {
      parsed = await parseReminderV2(inputText, {
        traceId,
        timeoutMs: VOICE_PARSE_TIMEOUT_MS
      });

    } else if (intent === 'focus') {
      const pendingTasks = await getUserPendingTasks(userId);
      try {
        parsed = await parseFocusV2(inputText, pendingTasks, {
          timeoutMs: VOICE_PARSE_TIMEOUT_MS
        });
      } catch (e) {
        const errorCode = getAgentErrorCode(e, 'parse_timeout', 'focus_parse_failed');
        console.error(`[voiceCreate:parse] trace=${traceId} errorCode=${errorCode} 番茄解析 Agent 失败:`, e.message);
        parsed = normalizeFocusParsedResult({ focusSubject: inputText.substring(0, 20), duration: 25 }, inputText, pendingTasks);
      }
    }

    // 写入缓存
    setCachedParse(userId, inputText, intent, parsed);

    console.log(`[voiceCreate:parse] trace=${traceId} done intent=${intent} latency=${Date.now() - startedAt}ms`);
    res.json({
      success: true,
      data: { intent, parsed, traceId }
    });
  } catch (error) {
    console.error(`[voiceCreate:parse] trace=${traceId} 接口异常:`, error);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

module.exports = router;
