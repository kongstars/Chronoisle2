import { Task, TaskStatus } from './Task';

export type TodayPlanSource = 'none' | 'local' | 'cloud_pending' | 'cloud_adopted';

export interface SavedPlanTaskItem {
  id: string;
  title: string;
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
    if (task) {
      if (!synced.title || synced.title.length === 0) {
        synced.title = task.title;
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
