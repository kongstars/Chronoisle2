import { CounterUnit, DayEvent, DayEventType, ReminderRule, ReminderType } from '../models/DayEvent';

export function startOfDay(timestamp: number): number {
  const date = new Date(timestamp);
  date.setHours(0, 0, 0, 0);
  return date.getTime();
}

export function endOfDay(timestamp: number): number {
  const date = new Date(timestamp);
  date.setHours(23, 59, 59, 999);
  return date.getTime();
}

export function addDays(timestamp: number, days: number): number {
  return timestamp + days * 24 * 60 * 60 * 1000;
}

export function addMonths(timestamp: number, months: number): number {
  const date = new Date(timestamp);
  date.setMonth(date.getMonth() + months);
  return date.getTime();
}

export function addYears(timestamp: number, years: number): number {
  const date = new Date(timestamp);
  date.setFullYear(date.getFullYear() + years);
  return date.getTime();
}

export function formatDayEventDate(timestamp: number): string {
  const date = new Date(timestamp);
  const y = date.getFullYear();
  const m = `${date.getMonth() + 1}`.padStart(2, '0');
  const d = `${date.getDate()}`.padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function formatDayEventTime(hourOrTimestamp: number, minute?: number): string {
  let h: string;
  let m: string;
  if (minute !== undefined) {
    h = `${hourOrTimestamp}`.padStart(2, '0');
    m = `${minute}`.padStart(2, '0');
    return `${h}:${m}`;
  }
  const date = new Date(hourOrTimestamp);
  h = `${date.getHours()}`.padStart(2, '0');
  m = `${date.getMinutes()}`.padStart(2, '0');
  return `${h}:${m}`;
}

export function getCounterTargetDate(event: DayEvent, rule: ReminderRule): number {
  const base = event.counterStartDate || event.startDate;
  const value = rule.offsetValue || 1;
  switch (rule.offsetUnit) {
    case CounterUnit.YEAR:
      return addYears(base, value);
    case CounterUnit.MONTH:
      return addMonths(base, value);
    default:
      return addDays(base, value);
  }
}

export function getReminderSummary(rule: ReminderRule): string {
  switch (rule.type) {
    case ReminderType.HABIT_WEEKLY_TARGET:
      return `每周目标 ${rule.targetCount || 1} 次`;
    case ReminderType.HABIT_MONTHLY_TARGET:
      return `每月目标 ${rule.targetCount || 1} 次`;
    case ReminderType.MILESTONE_LEAD:
      return `提前 ${rule.leadDays || 0} 天提醒`;
    default:
      return '提醒';
  }
}

function getReminderRuleTime(timestamp: number, rule: ReminderRule): number {
  const date = new Date(startOfDay(timestamp));
  date.setHours(rule.hour ?? 9, rule.minute ?? 0, 0, 0);
  return date.getTime();
}

function getMonthLastDayDate(timestamp: number, lastDayOffset?: number): number {
  const date = new Date(startOfDay(timestamp));
  const daysInMonth = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
  const offset = Math.max(1, lastDayOffset ?? 1);
  return Math.max(1, daysInMonth - offset + 1);
}

export function matchesReminderRuleOnDate(event: DayEvent, rule: ReminderRule, timestamp: number): boolean {
  const current = startOfDay(timestamp);
  if (event.endDate !== undefined && current > endOfDay(event.endDate)) {
    return false;
  }
  if (current < startOfDay(event.startDate)) {
    return false;
  }
  switch (rule.type) {
    case ReminderType.PERIODIC_DAILY:
    case ReminderType.HABIT_DAILY:
      return true;
    case ReminderType.PERIODIC_WEEKLY:
      return new Date(current).getDay() === (rule.weekday ?? 1);
    case ReminderType.PERIODIC_MONTHLY:
      return new Date(current).getDate() === Math.max(1, rule.dayOfMonth ?? 1);
    case ReminderType.PERIODIC_MONTHLY_LAST_DAY:
      return new Date(current).getDate() === getMonthLastDayDate(current, rule.lastDayOffset);
    case ReminderType.PERIODIC_INTERVAL: {
      const intervalDays = Math.max(1, rule.intervalDays ?? 1);
      const diffDays = Math.floor((current - startOfDay(event.startDate)) / (24 * 60 * 60 * 1000));
      return diffDays >= 0 && diffDays % intervalDays === 0;
    }
    case ReminderType.MILESTONE_LEAD:
      if (!event.targetDate) return false;
      return startOfDay(addDays(event.targetDate, -(rule.leadDays || 0))) === current;
    case ReminderType.COUNTER_DATE:
      return startOfDay(rule.targetDate || event.targetDate || 0) === current;
    case ReminderType.COUNTER_INTERVAL:
      return startOfDay(getCounterTargetDate(event, rule)) === current;
    default:
      return false;
  }
}

export function getReminderRuleOccurrenceTimeOnDate(event: DayEvent, rule: ReminderRule, timestamp: number): number | undefined {
  if (!matchesReminderRuleOnDate(event, rule, timestamp)) {
    return undefined;
  }

  switch (rule.type) {
    case ReminderType.MILESTONE_LEAD:
      return event.targetDate !== undefined
        ? getReminderRuleTime(addDays(event.targetDate, -(rule.leadDays || 0)), rule)
        : undefined;
    case ReminderType.COUNTER_DATE: {
      const targetDate = rule.targetDate || event.targetDate;
      return targetDate !== undefined ? getReminderRuleTime(targetDate, rule) : undefined;
    }
    case ReminderType.COUNTER_INTERVAL:
      return getReminderRuleTime(getCounterTargetDate(event, rule), rule);
    default:
      return getReminderRuleTime(timestamp, rule);
  }
}

export function getDayEventOccurrenceTimeOnDate(event: DayEvent, timestamp: number): number | undefined {
  const day = startOfDay(timestamp);
  const occurrences: number[] = [];

  if (event.targetDate !== undefined && startOfDay(event.targetDate) === day) {
    occurrences.push(event.targetDate);
  }

  if (startOfDay(event.startDate) === day) {
    occurrences.push(event.startDate);
  }

  event.reminderRules.forEach((rule: ReminderRule) => {
    const occurrence = getReminderRuleOccurrenceTimeOnDate(event, rule, timestamp);
    if (occurrence !== undefined) {
      occurrences.push(occurrence);
    }
  });

  if (occurrences.length === 0) {
    return undefined;
  }

  occurrences.sort((first: number, second: number) => first - second);
  return occurrences[0];
}

export function getEventsForDate(events: DayEvent[], timestamp: number): DayEvent[] {
  const day = startOfDay(timestamp);
  return events.filter((event: DayEvent) => {
    if (startOfDay(event.startDate) === day) {
      return true;
    }
    if (event.targetDate !== undefined && startOfDay(event.targetDate) === day) {
      return true;
    }
    return event.reminderRules.some((rule: ReminderRule) => matchesReminderRuleOnDate(event, rule, timestamp));
  });
}

export function getDayEventListSummary(events: DayEvent[] | DayEvent): string {
  if (!Array.isArray(events)) {
    return events.reminderRules.length > 0 ? `共 ${events.reminderRules.length} 条规则` : '暂无规则';
  }
  if (events.length === 0) {
    return '暂无提醒';
  }
  return `共 ${events.length} 项提醒`;
}

export function getDayEventMetricText(event: DayEvent): string {
  if (event.type === DayEventType.COUNTDOWN && event.targetDate) {
    return `目标日 ${formatDayEventDate(event.targetDate)}`;
  }
  if (event.type === DayEventType.COUNTER) {
    return `起始于 ${formatDayEventDate(event.counterStartDate || event.startDate)}`;
  }
  return formatDayEventDate(event.startDate);
}

export function isDayEventEnded(event: DayEvent, now: number = Date.now()): boolean {
  return event.endDate !== undefined && now > event.endDate;
}
