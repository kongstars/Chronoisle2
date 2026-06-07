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
// 获取用户活跃目标列表（用于 Agent 上下文）
// ========================
async function getUserGoalsContext(userId) {
  try {
    const syncData = await SyncData.findOne({ userId });
    if (!syncData || !syncData.goals || syncData.goals.length === 0) {
      return '当前用户无活跃目标。';
    }

    const activeGoals = syncData.goals.filter(g => !g.isArchived);
    if (activeGoals.length === 0) {
      return '当前用户无活跃目标。';
    }

    let ctx = '以下是当前用户的活跃目标及关键结果列表（请精准匹配ID，若无关请留空）：\n';
    activeGoals.forEach(goal => {
      ctx += `- [目标 ID: ${goal.id}] 名称: ${goal.title}\n`;
      if (goal.keyResults && goal.keyResults.length > 0) {
        goal.keyResults.forEach(kr => {
          ctx += `    - [KR ID: ${kr.id}] KR标题: ${kr.title}\n`;
        });
      }
    });
    return ctx;
  } catch (e) {
    console.error('[voiceCreate] 获取用户目标失败:', e.message);
    return '当前用户无活跃目标。';
  }
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
      goalTitle: t.goalTitle || ''
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

function detectIntentByRules(text) {
  const normalized = String(text || '').trim();
  if (!normalized) {
    return '';
  }

  if (/(开始)?专注|番茄|pomodoro|计时|工作\d+分钟/i.test(normalized)) {
    return 'focus';
  }

  if (/(提醒|叫我|闹钟|倒计时|纪念日|打卡|每[天周月年]|距离.*还有)/i.test(normalized)) {
    return 'reminder';
  }

  if (/(目标|计划|长期|阶段|坚持|养成|提升|减肥|考研|考公|学习.*达到|今年想|今年要)/i.test(normalized)) {
    return 'goal';
  }

  return '';
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
// Agent 1: 意图分流 Router
// ========================
const ROUTER_SYSTEM_PROMPT = `你是四时清单的语音创建智能助手。用户通过语音输入了一段话，你需要判断用户的意图属于以下四种之一：

1. "goal" — 用户描述的是一个长期目标、宏观愿景、需要拆解的规划（如"考研"、"减肥20斤"、"学好英语"、"今年存10万"）
2. "reminder" — 用户描述的是习惯打卡、周期提醒、倒计时、纪念日（如"每天晚上9点提醒我吃药"、"距离考试还有30天"、"每周一三五跑步"）
3. "task" — 用户描述的是一个具体的、单次可完成的待办事项（如"明天提交报告"、"买牛奶"、"给老师发邮件"）
4. "focus" — 用户想立即开始专注/番茄钟（如"专注写论文30分钟"、"开始工作"、"番茄钟背单词"）

强制输出纯 JSON，不要任何解释：
{
  "intent": "task | reminder | goal | focus",
  "confidence": 0.95,
  "reasoning": "简短一句话说明判断理由"
}`;

async function routeIntent(text) {
  return await callAgent(ROUTER_SYSTEM_PROMPT, `用户语音输入：${text}`, {
    model: VOICE_CLASSIFY_MODEL,
    timeoutMs: VOICE_CLASSIFY_TIMEOUT_MS,
    traceLabel: 'voiceCreate.routeIntent'
  });
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
const ROUTER_SYSTEM_PROMPT_V2 = `You are the voice-create classifier for a productivity app.
Classify the user's voice input into exactly one intent:
1. "goal": a long-term objective, plan, or direction.
2. "reminder": a reminder, recurring reminder, countdown, anniversary, or routine check-in.
3. "task": a specific actionable to-do that can be completed once.
4. "focus": an immediate focus session or pomodoro request.

Return pure JSON only:
{
  "intent": "task | reminder | goal | focus",
  "confidence": 0.95,
  "reasoning": "short reason"
}`;

async function routeIntentV2(text, options = {}) {
  return await callAgent(ROUTER_SYSTEM_PROMPT_V2, buildVoiceInputPrompt(text), {
    model: options.model || VOICE_CLASSIFY_MODEL,
    timeoutMs: options.timeoutMs || VOICE_CLASSIFY_TIMEOUT_MS,
    traceLabel: options.traceLabel || 'voiceCreate.routeIntentV2'
  });
}

async function parseTaskV2(text, goalsContext, options = {}) {
  const currentTime = new Date().toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' });
  const systemPrompt = `You extract a structured task from the user's voice input for a productivity app.
${buildCurrentTimeContext(currentTime)}
${goalsContext}

Return pure JSON only:
{
  "title": "concise task title within 20 Chinese characters",
  "description": "brief helpful description",
  "priority": "high | normal | low",
  "dueDate": "YYYY-MM-DD HH:mm:ss or empty string",
  "goalId": "matched goal ID or empty string",
  "krId": "matched key result ID or empty string",
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
    pendingTasks.slice(0, 20).forEach(t => {
      taskListStr += `- [ID: ${t.id}] ${t.title}${t.goalTitle ? ` (Goal: ${t.goalTitle})` : ''}\\n`;
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

  return await callAgent(systemPrompt, buildVoiceInputPrompt(text), {
    model: options.model || VOICE_PARSE_MODEL,
    timeoutMs: options.timeoutMs || VOICE_PARSE_TIMEOUT_MS,
    traceLabel: options.traceLabel || 'voiceCreate.parseFocusV2'
  });
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
  return ['periodic', 'habit', 'milestone', 'counter', 'countdown'].includes(value);
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
    fallback.eventType = 'milestone';
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
- "periodic": periodic reminder with periodicMode = daily | weekly | monthly | interval
- "habit": habit reminder with habitMode = daily | weekly | monthly
- "milestone": one important date, targetDate required
- "counter": a milestone counted from startDate, with counterMode = interval | date
- "countdown": targetDate required

Return pure JSON only:
{
  "title": "short reminder title",
  "eventType": "periodic | habit | milestone | counter | countdown",
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
- If the user says multiple weekdays like "每周一三五跑步", use habit weekly and set timesPerPeriod to the count.
- If the user says "距离考试还有30天", use countdown and calculate targetDate.
- If the user gives a specific date like "5月20日提醒我...", use milestone unless the text clearly means an anniversary counter.
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
    return normalized
      .replace(/^(请|帮我|麻烦|记得|我要|我想|需要|去|来)/, '')
      .replace(/[，。！？、,.!?；;：:]+$/, '')
      .trim()
      .substring(0, 30);
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

    // Step 1: 意图分流
    let intentResult;
    try {
      const ruleIntent = detectIntentByRules(inputText);
      if (ruleIntent) {
        intentResult = {
          intent: ruleIntent,
          confidence: 0.99,
          reasoning: 'rule_based'
        };
      } else {
        intentResult = await routeIntentV2(inputText, {
          timeoutMs: VOICE_CLASSIFY_TIMEOUT_MS
        });
      }
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
      const goalsContext = await getUserGoalsContext(userId);
      try {
        parsed = await parseTaskV2(inputText, goalsContext, {
          timeoutMs: VOICE_ANALYZE_TIMEOUT_MS
        });
        if (isLowQualityTaskParse(parsed, inputText)) {
          parsed = {
            title: inputText.substring(0, 30),
            description: inputText,
            priority: 'normal',
            dueDate: '',
            goalId: '',
            krId: '',
            estimatedHours: 1
          };
        }
      } catch (e) {
        console.error(`[voiceCreate] trace=${traceId} 任务解析 Agent 失败:`, e.message);
        // fallback：用原始文本作为标题
        parsed = { title: inputText.substring(0, 30), description: inputText, priority: 'normal' };
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
        parsed = { focusSubject: inputText.substring(0, 20), duration: 25 };
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

    // Step 1: 规则前置快速分流（跳过 LLM）
    const ruleIntent = detectIntentByRules(inputText);
    if (ruleIntent) {
      console.log(`[voiceCreate:classify] trace=${traceId} source=rule intent=${ruleIntent} latency=${Date.now() - startedAt}ms`);
      return res.json({
        success: true,
        data: {
          intent: ruleIntent,
          confidence: 0.99,
          title_candidate: extractQuickTitle(inputText, ruleIntent),
          source: 'rule',
          traceId
        }
      });
    }

    // Step 2: LLM 分流（使用快速模型）
    try {
      const intentResult = await routeIntentV2(inputText, {
        timeoutMs: VOICE_CLASSIFY_TIMEOUT_MS
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
      const goalsContext = await getUserGoalsContext(userId);
      try {
        parsed = await parseTaskV2(inputText, goalsContext, {
          timeoutMs: VOICE_PARSE_TIMEOUT_MS
        });
        if (isLowQualityTaskParse(parsed, inputText)) {
          parsed = {
            title: inputText.substring(0, 30),
            description: inputText,
            priority: 'normal',
            dueDate: '',
            goalId: '',
            krId: '',
            estimatedHours: 1
          };
        }
      } catch (e) {
        const errorCode = getAgentErrorCode(e, 'parse_timeout', 'task_parse_failed');
        console.error(`[voiceCreate:parse] trace=${traceId} errorCode=${errorCode} 任务解析 Agent 失败:`, e.message);
        parsed = { title: inputText.substring(0, 30), description: inputText, priority: 'normal' };
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
        parsed = { focusSubject: inputText.substring(0, 20), duration: 25 };
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
