export interface NormalizedTaskDraft {
  title: string;
  dueDate: string;
  dueTime: string;
}

interface ParsedDueDateTime {
  dueDate: string;
  dueTime: string;
}

const RELATIVE_DATE_REGEX: RegExp = /(今天|明天|后天|今晚|今早|今晨|本周[一二三四五六日天]|这周[一二三四五六日天]|下周[一二三四五六日天]|周[一二三四五六日天]|星期[一二三四五六日天])/g;
const EXPLICIT_DATE_REGEX: RegExp = /(\d{4}[\/-]\d{1,2}[\/-]\d{1,2})|(\d{1,2}月\d{1,2}[日号]?)/g;
const TIME_OF_DAY_REGEX: RegExp = /(凌晨|清晨|早上|上午|中午|下午|晚上|今晚|夜里|夜间|夜晚)/g;
const CLOCK_TIME_REGEX: RegExp = /(\d{1,2})\s*[:：]\s*(\d{1,2})|(\d{1,2})\s*点半|(\d{1,2})\s*点(\d{1,2})?分?/g;

function padTwo(value: number): string {
  return value.toString().padStart(2, '0');
}

function formatDateValue(date: Date): string {
  return `${date.getFullYear()}-${padTwo(date.getMonth() + 1)}-${padTwo(date.getDate())}`;
}

function createDate(year: number, month: number, day: number): Date {
  return new Date(year, month - 1, day, 0, 0, 0, 0);
}

function buildDateFromText(sourceText: string, baseDate: Date): string {
  const text = sourceText.trim();
  if (!text) {
    return '';
  }

  const fullDateMatch = text.match(/(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})/);
  if (fullDateMatch) {
    const parsed = createDate(Number(fullDateMatch[1]), Number(fullDateMatch[2]), Number(fullDateMatch[3]));
    return isNaN(parsed.getTime()) ? '' : formatDateValue(parsed);
  }

  const monthDayMatch = text.match(/(\d{1,2})月(\d{1,2})[日号]?/);
  if (monthDayMatch) {
    let year: number = baseDate.getFullYear();
    let parsed = createDate(year, Number(monthDayMatch[1]), Number(monthDayMatch[2]));
    const today = createDate(baseDate.getFullYear(), baseDate.getMonth() + 1, baseDate.getDate());
    if (parsed.getTime() < today.getTime()) {
      year += 1;
      parsed = createDate(year, Number(monthDayMatch[1]), Number(monthDayMatch[2]));
    }
    return isNaN(parsed.getTime()) ? '' : formatDateValue(parsed);
  }

  if (text.includes('今天')) {
    return formatDateValue(baseDate);
  }
  if (text.includes('明天')) {
    const next = new Date(baseDate.getTime());
    next.setDate(next.getDate() + 1);
    return formatDateValue(next);
  }
  if (text.includes('后天')) {
    const next = new Date(baseDate.getTime());
    next.setDate(next.getDate() + 2);
    return formatDateValue(next);
  }

  const weekdayMap: Record<string, number> = {
    '日': 0,
    '天': 0,
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6
  };

  const nextWeekMatch = text.match(/下周([一二三四五六日天])/);
  if (nextWeekMatch) {
    const targetWeekday = weekdayMap[nextWeekMatch[1]];
    const todayWeekday = baseDate.getDay();
    let delta = targetWeekday - todayWeekday;
    if (delta <= 0) {
      delta += 7;
    }
    delta += 7;
    const next = new Date(baseDate.getTime());
    next.setDate(next.getDate() + delta);
    return formatDateValue(next);
  }

  const currentWeekMatch = text.match(/(?:本周|这周|周|星期)([一二三四五六日天])/);
  if (currentWeekMatch) {
    const targetWeekday = weekdayMap[currentWeekMatch[1]];
    const todayWeekday = baseDate.getDay();
    let delta = targetWeekday - todayWeekday;
    if (/周|星期/.test(currentWeekMatch[0]) && !/(本周|这周)/.test(currentWeekMatch[0]) && delta < 0) {
      delta += 7;
    }
    const next = new Date(baseDate.getTime());
    next.setDate(next.getDate() + delta);
    return formatDateValue(next);
  }

  return '';
}

function buildTimeFromText(sourceText: string): string {
  const text = sourceText.trim();
  if (!text) {
    return '';
  }

  let match = text.match(/(\d{1,2})\s*[:：]\s*(\d{1,2})/);
  if (match) {
    let hour = Number(match[1]);
    const minute = Number(match[2]);
    if (/(下午|晚上|今晚|夜里|夜间|夜晚)/.test(text) && hour < 12) {
      hour += 12;
    } else if (/(中午)/.test(text) && hour < 11) {
      hour += 12;
    } else if (/(凌晨)/.test(text) && hour === 12) {
      hour = 0;
    }
    return `${padTwo(Math.max(0, Math.min(23, hour)))}:${padTwo(Math.max(0, Math.min(59, minute)))}`;
  }

  match = text.match(/(\d{1,2})\s*点半/);
  if (match) {
    let hour = Number(match[1]);
    if (/(下午|晚上|今晚|夜里|夜间|夜晚)/.test(text) && hour < 12) {
      hour += 12;
    } else if (/(中午)/.test(text) && hour < 11) {
      hour += 12;
    }
    return `${padTwo(Math.max(0, Math.min(23, hour)))}:30`;
  }

  match = text.match(/(\d{1,2})\s*点(\d{1,2})?分?/);
  if (match) {
    let hour = Number(match[1]);
    const minute = match[2] ? Number(match[2]) : 0;
    if (/(下午|晚上|今晚|夜里|夜间|夜晚)/.test(text) && hour < 12) {
      hour += 12;
    } else if (/(中午)/.test(text) && hour < 11) {
      hour += 12;
    } else if (/(凌晨)/.test(text) && hour === 12) {
      hour = 0;
    }
    return `${padTwo(Math.max(0, Math.min(23, hour)))}:${padTwo(Math.max(0, Math.min(59, minute)))}`;
  }

  return '';
}

function parseProvidedDueDateTime(dueDate: string, dueTime: string): ParsedDueDateTime {
  const normalizedDueDate = dueDate.trim();
  const normalizedDueTime = dueTime.trim();
  if (!normalizedDueDate) {
    return { dueDate: '', dueTime: normalizedDueTime };
  }

  const parsed = new Date(normalizedDueDate.replace(/-/g, '/'));
  if (isNaN(parsed.getTime())) {
    return { dueDate: normalizedDueDate, dueTime: normalizedDueTime };
  }

  let resolvedTime = normalizedDueTime;
  const timeMatch = normalizedDueDate.match(/(\d{1,2}):(\d{2})/);
  if (!resolvedTime && timeMatch) {
    resolvedTime = `${padTwo(Number(timeMatch[1]))}:${padTwo(Number(timeMatch[2]))}`;
  }

  return {
    dueDate: formatDateValue(parsed),
    dueTime: resolvedTime
  };
}

function stripTaskTemporalInfo(text: string): string {
  return text
    .replace(RELATIVE_DATE_REGEX, ' ')
    .replace(EXPLICIT_DATE_REGEX, ' ')
    .replace(TIME_OF_DAY_REGEX, ' ')
    .replace(CLOCK_TIME_REGEX, ' ')
    .replace(/(?:前|之前|当天|那天|时候|左右|前后)/g, ' ')
    .replace(/^[\s,，。.!！?？:：;；、-]+/, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function cleanTaskTitle(title: string, fallbackSource: string): string {
  let cleaned = stripTaskTemporalInfo(title)
    .replace(/^(请|帮我|麻烦|记得|需要|我要|我想|准备|打算|计划|安排|要)\s*/, '')
    .replace(/[，。！？、,.!?；;：:]+$/, '')
    .trim();

  if (!cleaned) {
    cleaned = stripTaskTemporalInfo(fallbackSource)
      .replace(/^(请|帮我|麻烦|记得|需要|我要|我想|准备|打算|计划|安排|要)\s*/, '')
      .replace(/[，。！？、,.!?；;：:]+$/, '')
      .trim();
  }

  if (!cleaned) {
    cleaned = title.trim() || fallbackSource.trim();
  }

  return cleaned.substring(0, 30);
}

export function normalizeTaskDraft(title: string, sourceText?: string, dueDate?: string, dueTime?: string): NormalizedTaskDraft {
  const normalizedSource = (sourceText || title || '').trim();
  const baseDate = new Date();
  const inferredDate = buildDateFromText(normalizedSource, baseDate);
  const inferredTime = buildTimeFromText(normalizedSource);
  const providedDue = parseProvidedDueDateTime(dueDate || '', dueTime || '');

  return {
    title: cleanTaskTitle(title || normalizedSource, normalizedSource),
    dueDate: inferredDate || providedDue.dueDate,
    dueTime: inferredDate ? inferredTime : providedDue.dueTime
  };
}
