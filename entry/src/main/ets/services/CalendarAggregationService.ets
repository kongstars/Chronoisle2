import { endOfDay, getDayEventOccurrenceTimeOnDate, startOfDay } from '../common/DayEventUtils';
import { DayEvent, ReminderRule, ReminderType } from '../models/DayEvent';
import { Task, TaskStatus } from '../models/Task';
import { getReminderPeriodProgress } from './ReminderTaskService';

export type CalendarReminderState = 'pending' | 'completed' | 'target_met';

export interface CalendarReminderItem {
  event: DayEvent;
  occurrenceTime: number;
  state: CalendarReminderState;
  statusText: string;
  progressText: string;
  completedCountOnDate: number;
  isCountTarget: boolean;
  isLate: boolean;
}

export interface CalendarDaySummary {
  date: number;
  reminders: CalendarReminderItem[];
  pendingReminders: CalendarReminderItem[];
  completedReminders: CalendarReminderItem[];
  tasks: Task[];
  reminderCount: number;
  pendingReminderCount: number;
  completedReminderCount: number;
  taskCount: number;
  actionableCount: number;
  totalCount: number;
  hasOverdueTask: boolean;
  isConflict: boolean;
  loadLevel: number;
}

function toDateKey(timestamp: number): string {
  const date = new Date(timestamp);
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');
  return `${date.getFullYear()}-${month}-${day}`;
}

function getCountTargetRule(event: DayEvent): ReminderRule | undefined {
  return event.reminderRules.find((rule: ReminderRule) => {
    return rule.type === ReminderType.HABIT_WEEKLY_TARGET || rule.type === ReminderType.HABIT_MONTHLY_TARGET;
  });
}

function getRuleTimeForDate(timestamp: number, rule?: ReminderRule): number {
  const date = new Date(startOfDay(timestamp));
  date.setHours(rule?.hour ?? 9, rule?.minute ?? 0, 0, 0);
  return date.getTime();
}

function getCompletedReminderTasksForDate(tasks: Task[], eventId: string, timestamp: number): Task[] {
  const day = startOfDay(timestamp);
  return tasks.filter((task: Task) => {
    if (task.reminderId !== eventId || task.status !== TaskStatus.COMPLETED) {
      return false;
    }

    if (task.completedAt !== undefined && startOfDay(task.completedAt) === day) {
      return true;
    }

    return task.reminderOccurrenceTime !== undefined && startOfDay(task.reminderOccurrenceTime) === day;
  });
}

function isPendingOccurrenceLate(occurrenceTime: number, state: CalendarReminderState): boolean {
  return state === 'pending' && occurrenceTime <= Date.now();
}

function isCountTargetAvailableOnDate(event: DayEvent, tasks: Task[], timestamp: number): boolean {
  const day = startOfDay(timestamp);
  if (!event.isEnabled || day < startOfDay(event.startDate)) {
    return false;
  }
  if (event.endDate !== undefined && day > endOfDay(event.endDate)) {
    return false;
  }
  const progress = getReminderPeriodProgress(event, tasks, endOfDay(day));
  if (!progress) {
    return false;
  }
  return progress.completed < progress.target;
}

function getCountTargetItem(event: DayEvent, tasks: Task[], timestamp: number, completedCountOnDate: number): CalendarReminderItem | null {
  const day = startOfDay(timestamp);
  const countTargetRule = getCountTargetRule(event);
  if (!countTargetRule) {
    return null;
  }

  const progress = getReminderPeriodProgress(event, tasks, endOfDay(day));
  const progressText = progress ? `${progress.label} ${progress.completed}/${progress.target}` : '';
  const isTargetReached = progress ? progress.completed >= progress.target : false;

  if (!isTargetReached && completedCountOnDate === 0 && !isCountTargetAvailableOnDate(event, tasks, day)) {
    return null;
  }

  let state: CalendarReminderState = 'pending';
  let statusText = '待打卡';
  if (isTargetReached) {
    state = 'target_met';
    statusText = progress ? `${progress.label}达标` : '已达标';
  } else if (completedCountOnDate > 0) {
    state = 'completed';
    statusText = '今日已打卡';
  }

  const occurrenceTime = getRuleTimeForDate(day, countTargetRule);

  return {
    event,
    occurrenceTime,
    state,
    statusText,
    progressText,
    completedCountOnDate,
    isCountTarget: true,
    isLate: isPendingOccurrenceLate(occurrenceTime, state)
  };
}

function getDirectReminderItem(event: DayEvent, timestamp: number, occurrenceTime: number, completedCountOnDate: number): CalendarReminderItem {
  const state: CalendarReminderState = completedCountOnDate > 0 ? 'completed' : 'pending';
  return {
    event,
    occurrenceTime,
    state,
    statusText: completedCountOnDate > 0 ? '今日已打卡' : '待处理',
    progressText: '',
    completedCountOnDate,
    isCountTarget: false,
    isLate: isPendingOccurrenceLate(occurrenceTime, state)
  };
}

function getLoadLevel(actionableCount: number, hasOverdueTask: boolean, isConflict: boolean): number {
  if (actionableCount <= 0) {
    return 0;
  }
  if (hasOverdueTask || isConflict || actionableCount >= 8) {
    return 3;
  }
  if (actionableCount >= 5) {
    return 2;
  }
  return 1;
}

function getReminderStateOrder(state: CalendarReminderState): number {
  switch (state) {
    case 'pending':
      return 0;
    case 'target_met':
    case 'completed':
      return 1;
    default:
      return 2;
  }
}

export function getCalendarReminderItemsForDate(dayEvents: DayEvent[], tasks: Task[], timestamp: number): CalendarReminderItem[] {
  const day = startOfDay(timestamp);
  const items: CalendarReminderItem[] = [];

  dayEvents.forEach((event: DayEvent) => {
    if (!event.isEnabled) {
      return;
    }

    const completedTasksOnDate = getCompletedReminderTasksForDate(tasks, event.id, day);
    const completedCountOnDate = completedTasksOnDate.length;
    const directOccurrence = getDayEventOccurrenceTimeOnDate(event, day);
    if (directOccurrence !== undefined) {
      items.push(getDirectReminderItem(event, day, directOccurrence, completedCountOnDate));
      return;
    }

    const countTargetItem = getCountTargetItem(event, tasks, day, completedCountOnDate);
    if (countTargetItem) {
      items.push(countTargetItem);
    }
  });

  items.sort((first: CalendarReminderItem, second: CalendarReminderItem) => {
    const firstOrder = getReminderStateOrder(first.state);
    const secondOrder = getReminderStateOrder(second.state);
    if (firstOrder !== secondOrder) {
      return firstOrder - secondOrder;
    }
    if (first.occurrenceTime !== second.occurrenceTime) {
      return first.occurrenceTime - second.occurrenceTime;
    }
    return first.event.title.localeCompare(second.event.title);
  });

  return items;
}

export function getCalendarTasksForDate(tasks: Task[], timestamp: number): Task[] {
  const key = toDateKey(timestamp);
  return tasks
    .filter((task: Task) => {
      return task.dueDate !== undefined &&
        task.status !== TaskStatus.COMPLETED &&
        toDateKey(task.dueDate) === key;
    })
    .sort((first: Task, second: Task) => {
      const firstDue = first.dueDate || Number.MAX_SAFE_INTEGER;
      const secondDue = second.dueDate || Number.MAX_SAFE_INTEGER;
      if (firstDue !== secondDue) {
        return firstDue - secondDue;
      }
      return first.title.localeCompare(second.title);
    });
}

export function getCalendarDaySummary(dayEvents: DayEvent[], tasks: Task[], timestamp: number): CalendarDaySummary {
  const reminders = getCalendarReminderItemsForDate(dayEvents, tasks, timestamp);
  const dayTasks = getCalendarTasksForDate(tasks, timestamp);
  const pendingReminders = reminders.filter((item: CalendarReminderItem) => item.state === 'pending');
  const completedReminders = reminders.filter((item: CalendarReminderItem) => item.state !== 'pending');
  const pendingReminderCount = pendingReminders.length;
  const completedReminderCount = completedReminders.length;
  const taskCount = dayTasks.length;
  const actionableCount = pendingReminderCount + taskCount;
  const hasOverdueTask = dayTasks.some((task: Task) => task.isOverdue);
  const isConflict = pendingReminderCount > 0 && taskCount > 0 && (actionableCount >= 3 || hasOverdueTask);

  return {
    date: startOfDay(timestamp),
    reminders,
    pendingReminders,
    completedReminders,
    tasks: dayTasks,
    reminderCount: reminders.length,
    pendingReminderCount,
    completedReminderCount,
    taskCount,
    actionableCount,
    totalCount: reminders.length + taskCount,
    hasOverdueTask,
    isConflict,
    loadLevel: getLoadLevel(actionableCount, hasOverdueTask, isConflict)
  };
}
