import { formatDayEventTime, getDayEventOccurrenceTimeOnDate, getEventsForDate, isDayEventEnded, startOfDay } from '../common/DayEventUtils';
import { DayEvent } from './DayEvent';
import { Task, TaskStatus } from './Task';

export type TodayPlanSource = 'none' | 'local' | 'cloud_pending' | 'cloud_adopted';

export interface SavedPlanTaskItem {
  id: string;
  title: string;
  type?: 'task' | 'reminder';
  goalTitle?: string;
  reminderTime?: string;
  estimatedMinutes?: number;
  completed?: boolean;
  reason?: string;
}

export interface SavedTodayPlan {
  focusTasks: SavedPlanTaskItem[];
  deferTasks: SavedPlanTaskItem[];
  summary: string;
  totalEstimatedHours?: number;
  adoptedAt?: number;
  groupedTasks?: Record<string, string[]>;
  sourceDate?: string;
  sourceGeneratedAt?: number;
  planSource?: TodayPlanSource;
}

export interface CloudPlanTaskRef {
  id: string;
  reason?: string;
}

export interface CloudTaskSnapshotItem {
  id: string;
  title?: string;
  dueDate?: string;
  isOverdue?: boolean;
  estimatedHours?: number;
  priority?: string;
  category?: string;
  isImportant?: boolean;
  isRecurring?: boolean;
}

export interface CloudPlanPayload {
  focusTasks?: CloudPlanTaskRef[];
  deferTasks?: string[];
  groupedTasks?: Record<string, string[]>;
  summary?: string;
  totalEstimatedHours?: number;
}

export function buildTodayPlanStorageDate(date: Date = new Date()): string {
  return date.toISOString().split('T')[0];
}

export function buildTodayPlanStorageKey(date: string): string {
  return `today_plan_${date}`;
}

function clonePlanTaskItem(item: SavedPlanTaskItem): SavedPlanTaskItem {
  const cloned: SavedPlanTaskItem = {
    id: item.id,
    title: item.title
  };
  if (item.type !== undefined) {
    cloned.type = item.type;
  }
  if (item.goalTitle !== undefined) {
    cloned.goalTitle = item.goalTitle;
  }
  if (item.reminderTime !== undefined) {
    cloned.reminderTime = item.reminderTime;
  }
  if (item.estimatedMinutes !== undefined) {
    cloned.estimatedMinutes = item.estimatedMinutes;
  }
  if (item.completed !== undefined) {
    cloned.completed = item.completed;
  }
  if (item.reason !== undefined) {
    cloned.reason = item.reason;
  }
  return cloned;
}

export function cloneSavedTodayPlan(plan: SavedTodayPlan): SavedTodayPlan {
  const cloned: SavedTodayPlan = {
    focusTasks: plan.focusTasks.map((item: SavedPlanTaskItem) => clonePlanTaskItem(item)),
    deferTasks: plan.deferTasks.map((item: SavedPlanTaskItem) => clonePlanTaskItem(item)),
    summary: plan.summary
  };
  if (plan.totalEstimatedHours !== undefined) {
    cloned.totalEstimatedHours = plan.totalEstimatedHours;
  }
  if (plan.adoptedAt !== undefined) {
    cloned.adoptedAt = plan.adoptedAt;
  }
  if (plan.groupedTasks !== undefined) {
    cloned.groupedTasks = plan.groupedTasks;
  }
  if (plan.sourceDate !== undefined) {
    cloned.sourceDate = plan.sourceDate;
  }
  if (plan.sourceGeneratedAt !== undefined) {
    cloned.sourceGeneratedAt = plan.sourceGeneratedAt;
  }
  if (plan.planSource !== undefined) {
    cloned.planSource = plan.planSource;
  }
  return cloned;
}

export function syncTodayPlanTaskProgress(plan: SavedTodayPlan, tasks: Task[]): SavedTodayPlan {
  const taskMap: Record<string, Task> = {};
  tasks.forEach((task: Task) => {
    taskMap[task.id] = task;
  });

  const syncItem = (item: SavedPlanTaskItem): SavedPlanTaskItem => {
    const task = taskMap[item.id];
    const synced = clonePlanTaskItem(item);
    if (synced.type === undefined) {
      synced.type = 'task';
    }
    if (task) {
      if (!synced.title || synced.title.length === 0) {
        synced.title = task.title;
      }
      if ((!synced.goalTitle || synced.goalTitle.length === 0) && task.goalTitle.length > 0) {
        synced.goalTitle = task.goalTitle;
      }
      synced.completed = task.status === TaskStatus.COMPLETED;
    }
    return synced;
  };

  const syncedPlan: SavedTodayPlan = {
    focusTasks: plan.focusTasks.map((item: SavedPlanTaskItem) => syncItem(item)),
    deferTasks: plan.deferTasks.map((item: SavedPlanTaskItem) => syncItem(item)),
    summary: plan.summary
  };
  if (plan.totalEstimatedHours !== undefined) {
    syncedPlan.totalEstimatedHours = plan.totalEstimatedHours;
  }
  if (plan.adoptedAt !== undefined) {
    syncedPlan.adoptedAt = plan.adoptedAt;
  }
  if (plan.groupedTasks !== undefined) {
    syncedPlan.groupedTasks = plan.groupedTasks;
  }
  if (plan.sourceDate !== undefined) {
    syncedPlan.sourceDate = plan.sourceDate;
  }
  if (plan.sourceGeneratedAt !== undefined) {
    syncedPlan.sourceGeneratedAt = plan.sourceGeneratedAt;
  }
  if (plan.planSource !== undefined) {
    syncedPlan.planSource = plan.planSource;
  }
  return syncedPlan;
}

function buildReminderCompletionLookup(tasks: Task[], todayStart: number): Record<string, boolean> {
  const lookup: Record<string, boolean> = {};
  tasks.forEach((task: Task) => {
    if (task.reminderId && task.status === TaskStatus.COMPLETED && task.completedAt !== undefined &&
      startOfDay(task.completedAt) === todayStart) {
      lookup[task.reminderId] = true;
    }
  });
  return lookup;
}

function buildReminderPlanItem(event: DayEvent, completedToday: boolean, now: number): SavedPlanTaskItem {
  const item: SavedPlanTaskItem = {
    id: event.id,
    title: event.title,
    type: 'reminder',
    completed: completedToday,
    reason: '今日提醒'
  };
  if (event.goalTitle && event.goalTitle.length > 0) {
    item.goalTitle = event.goalTitle;
  }
  if (completedToday) {
    item.reminderTime = '已完成';
  } else {
    const occurrenceTime = getDayEventOccurrenceTimeOnDate(event, now);
    item.reminderTime = occurrenceTime !== undefined ? formatDayEventTime(occurrenceTime) : '今天';
  }
  return item;
}

export function injectTodayReminders(plan: SavedTodayPlan, dayEvents: DayEvent[], tasks: Task[]): SavedTodayPlan {
  const syncedPlan = syncTodayPlanTaskProgress(plan, tasks);
  const now = Date.now();
  const todayStart = startOfDay(now);
  const completedLookup = buildReminderCompletionLookup(tasks, todayStart);
  const reminderItems: SavedPlanTaskItem[] = [];
  const appendedIds: Record<string, boolean> = {};

  getEventsForDate(dayEvents, now).forEach((event: DayEvent) => {
    if (!event.isEnabled || isDayEventEnded(event, now)) {
      return;
    }
    if (appendedIds[event.id]) {
      return;
    }
    appendedIds[event.id] = true;
    reminderItems.push(buildReminderPlanItem(event, completedLookup[event.id] === true, now));
  });

  const mergedFocusTasks: SavedPlanTaskItem[] = [...reminderItems];
  syncedPlan.focusTasks.forEach((item: SavedPlanTaskItem) => {
    const normalized = clonePlanTaskItem(item);
    if (normalized.type === undefined) {
      normalized.type = 'task';
    }
    mergedFocusTasks.push(normalized);
  });

  const mergedDeferTasks: SavedPlanTaskItem[] = syncedPlan.deferTasks.map((item: SavedPlanTaskItem) => {
    const normalized = clonePlanTaskItem(item);
    if (normalized.type === undefined) {
      normalized.type = 'task';
    }
    return normalized;
  });

  const injectedPlan: SavedTodayPlan = {
    focusTasks: mergedFocusTasks,
    deferTasks: mergedDeferTasks,
    summary: syncedPlan.summary
  };
  if (syncedPlan.totalEstimatedHours !== undefined) {
    injectedPlan.totalEstimatedHours = syncedPlan.totalEstimatedHours;
  }
  if (syncedPlan.adoptedAt !== undefined) {
    injectedPlan.adoptedAt = syncedPlan.adoptedAt;
  }
  if (syncedPlan.groupedTasks !== undefined) {
    injectedPlan.groupedTasks = syncedPlan.groupedTasks;
  }
  if (syncedPlan.sourceDate !== undefined) {
    injectedPlan.sourceDate = syncedPlan.sourceDate;
  }
  if (syncedPlan.sourceGeneratedAt !== undefined) {
    injectedPlan.sourceGeneratedAt = syncedPlan.sourceGeneratedAt;
  }
  if (syncedPlan.planSource !== undefined) {
    injectedPlan.planSource = syncedPlan.planSource;
  }
  return injectedPlan;
}
