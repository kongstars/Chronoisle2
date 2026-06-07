import dataPreferences from '@ohos.data.preferences';
import { Goal } from '../models/Goal';
import { Task, TaskStatus } from '../models/Task';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('GoalReschedulePromptService');
const PROMPT_PREFS_NAME: string = 'goal_reschedule_prompt_prefs';
const PROMPT_STATE_KEY: string = 'goal_reschedule_prompt_state';
const GLOBAL_LAST_SHOWN_DATE_KEY: string = 'goal_reschedule_prompt_last_shown_date';
const DAY_MS: number = 24 * 60 * 60 * 1000;
const PROMPT_INTERVAL_DAYS: number[] = [3, 7, 14, 30];

interface GoalPromptState {
  shownCount: number;
  nextEligibleAt: number;
  lastShownAt?: number;
  lastDismissedAt?: number;
  lastAcceptedAt?: number;
}

type GoalPromptStateMap = Record<string, GoalPromptState>;

export interface GoalReschedulePrompt {
  goalId: string;
  goalTitle: string;
  remainingTaskCount: number;
  overdueTaskCount: number;
  stalledDays: number;
  message: string;
}

interface GoalPromptMetrics {
  remainingTaskCount: number;
  overdueTaskCount: number;
  stalledDays: number;
  earliestOverdueAt?: number;
}

export class GoalReschedulePromptService {
  private static prefs: dataPreferences.Preferences | null = null;

  public static async initialize(context: Context): Promise<void> {
    if (GoalReschedulePromptService.prefs) {
      return;
    }
    try {
      GoalReschedulePromptService.prefs = await dataPreferences.getPreferences(context, PROMPT_PREFS_NAME);
    } catch (error) {
      logger.error('GoalReschedulePromptService init failed', error as Object);
    }
  }

  public static async getPromptCandidate(
    context: Context,
    goals: Goal[],
    tasks: Task[]
  ): Promise<GoalReschedulePrompt | null> {
    await GoalReschedulePromptService.initialize(context);
    if (await GoalReschedulePromptService.wasPromptShownGloballyToday()) {
      return null;
    }
    const states = await GoalReschedulePromptService.readStateMap();
    const now = Date.now();
    let bestCandidate: GoalReschedulePrompt | null = null;
    let bestScore = -1;

    for (const goal of goals) {
      if (goal.isArchived) {
        continue;
      }

      const metrics = GoalReschedulePromptService.getGoalPromptMetrics(goal.id, goal, tasks);
      if (!metrics) {
        continue;
      }

      const promptState = states[goal.id];
      if (promptState && promptState.nextEligibleAt > now) {
        continue;
      }

      const score = metrics.overdueTaskCount * 5 + metrics.stalledDays + metrics.remainingTaskCount;
      if (score <= bestScore) {
        continue;
      }

      bestScore = score;
      bestCandidate = {
        goalId: goal.id,
        goalTitle: goal.title,
        remainingTaskCount: metrics.remainingTaskCount,
        overdueTaskCount: metrics.overdueTaskCount,
        stalledDays: metrics.stalledDays,
        message: GoalReschedulePromptService.buildPromptMessage(metrics)
      };
    }

    return bestCandidate;
  }

  public static isGoalStillEligible(goalId: string, goals: Goal[], tasks: Task[]): boolean {
    const goal = goals.find((item: Goal) => item.id === goalId);
    if (!goal || goal.isArchived) {
      return false;
    }
    return GoalReschedulePromptService.getGoalPromptMetrics(goalId, goal, tasks) !== null;
  }

  public static async markPromptShown(context: Context, goalId: string): Promise<void> {
    await GoalReschedulePromptService.initialize(context);
    const states = await GoalReschedulePromptService.readStateMap();
    const state = states[goalId] || { shownCount: 0, nextEligibleAt: 0 };
    const nextShownCount = state.shownCount + 1;
    const intervalDays = GoalReschedulePromptService.getIntervalDays(nextShownCount);
    const updatedState: GoalPromptState = {
      shownCount: nextShownCount,
      lastShownAt: Date.now(),
      nextEligibleAt: Date.now() + intervalDays * DAY_MS,
      lastDismissedAt: state.lastDismissedAt,
      lastAcceptedAt: state.lastAcceptedAt
    };
    states[goalId] = updatedState;
    await GoalReschedulePromptService.writeGlobalLastShownDate();
    await GoalReschedulePromptService.writeStateMap(states);
  }

  public static async dismissPrompt(context: Context, goalId: string): Promise<void> {
    await GoalReschedulePromptService.initialize(context);
    const states = await GoalReschedulePromptService.readStateMap();
    const state = states[goalId] || { shownCount: 0, nextEligibleAt: 0 };
    const nextEligibleAt = Math.max(state.nextEligibleAt || 0, Date.now() + 7 * DAY_MS);
    const updatedState: GoalPromptState = {
      shownCount: state.shownCount,
      lastShownAt: state.lastShownAt,
      nextEligibleAt: nextEligibleAt,
      lastDismissedAt: Date.now(),
      lastAcceptedAt: state.lastAcceptedAt
    };
    states[goalId] = updatedState;
    await GoalReschedulePromptService.writeStateMap(states);
  }

  public static async acceptPrompt(context: Context, goalId: string): Promise<void> {
    await GoalReschedulePromptService.initialize(context);
    const states = await GoalReschedulePromptService.readStateMap();
    const state = states[goalId] || { shownCount: 0, nextEligibleAt: 0 };
    const updatedState: GoalPromptState = {
      shownCount: state.shownCount,
      lastShownAt: state.lastShownAt,
      nextEligibleAt: Date.now() + 30 * DAY_MS,
      lastDismissedAt: state.lastDismissedAt,
      lastAcceptedAt: Date.now()
    };
    states[goalId] = updatedState;
    await GoalReschedulePromptService.writeStateMap(states);
  }

  private static buildPromptMessage(metrics: GoalPromptMetrics): string {
    if (metrics.overdueTaskCount >= 5) {
      return `这个目标还有 ${metrics.remainingTaskCount} 个剩余任务停留在旧计划里，可以试试重排这个目标。`;
    }
    if (metrics.stalledDays >= 14) {
      return `这个目标已经停了 ${metrics.stalledDays} 天，不用从头来过，把剩余计划重新接上就好。`;
    }
    return `这个目标似乎停了一段时间，要不要重新安排剩余计划？`;
  }

  private static getGoalPromptMetrics(goalId: string, goal: Goal, tasks: Task[]): GoalPromptMetrics | null {
    const goalTasks = tasks.filter((task: Task) => task.goalId === goalId);
    const pendingTasks = goalTasks.filter((task: Task) => task.status === TaskStatus.PENDING && task.dueDate !== undefined && !task.isReminderAutoGenerated);
    if (pendingTasks.length < 3) {
      return null;
    }

    const now = Date.now();
    const overdueTasks = pendingTasks.filter((task: Task) => task.isOverdue);
    const completedTasks = goalTasks.filter((task: Task) => task.status === TaskStatus.COMPLETED && task.completedAt !== undefined);
    const lastCompletedAt = completedTasks.reduce((latest: number, task: Task) => {
      const completedAt = task.completedAt || 0;
      return completedAt > latest ? completedAt : latest;
    }, 0);
    const baseline = lastCompletedAt > 0 ? lastCompletedAt : (goal.updatedAt || goal.createdAt);
    const stalledDays = Math.max(0, Math.floor((now - baseline) / DAY_MS));
    const earliestOverdueAt = overdueTasks.length > 0
      ? overdueTasks.reduce((earliest: number, task: Task) => {
        const dueDate = task.dueDate || now;
        return dueDate < earliest ? dueDate : earliest;
      }, overdueTasks[0].dueDate || now)
      : undefined;

    const isLikelyStalled = overdueTasks.length >= 2 && stalledDays >= 5;
    const isBacklogHeavy = overdueTasks.length >= 4;
    if (!isLikelyStalled && !isBacklogHeavy) {
      return null;
    }

    return {
      remainingTaskCount: pendingTasks.length,
      overdueTaskCount: overdueTasks.length,
      stalledDays,
      earliestOverdueAt
    };
  }

  private static getIntervalDays(nextShownCount: number): number {
    const index = Math.max(0, Math.min(PROMPT_INTERVAL_DAYS.length - 1, nextShownCount - 1));
    return PROMPT_INTERVAL_DAYS[index];
  }

  private static async readStateMap(): Promise<GoalPromptStateMap> {
    if (!GoalReschedulePromptService.prefs) {
      return {};
    }
    try {
      const raw = await GoalReschedulePromptService.prefs.get(PROMPT_STATE_KEY, '{}') as string;
      return JSON.parse(raw) as GoalPromptStateMap;
    } catch (error) {
      logger.warn('GoalReschedulePromptService read state failed', error as Object);
      return {};
    }
  }

  private static async writeStateMap(stateMap: GoalPromptStateMap): Promise<void> {
    if (!GoalReschedulePromptService.prefs) {
      return;
    }
    try {
      await GoalReschedulePromptService.prefs.put(PROMPT_STATE_KEY, JSON.stringify(stateMap));
      await GoalReschedulePromptService.prefs.flush();
    } catch (error) {
      logger.warn('GoalReschedulePromptService write state failed', error as Object);
    }
  }

  private static async wasPromptShownGloballyToday(): Promise<boolean> {
    if (!GoalReschedulePromptService.prefs) {
      return false;
    }
    try {
      const lastShownDate = await GoalReschedulePromptService.prefs.get(GLOBAL_LAST_SHOWN_DATE_KEY, '') as string;
      return lastShownDate === GoalReschedulePromptService.getTodayKey();
    } catch (error) {
      logger.warn('GoalReschedulePromptService read global last shown failed', error as Object);
      return false;
    }
  }

  private static async writeGlobalLastShownDate(): Promise<void> {
    if (!GoalReschedulePromptService.prefs) {
      return;
    }
    try {
      await GoalReschedulePromptService.prefs.put(GLOBAL_LAST_SHOWN_DATE_KEY, GoalReschedulePromptService.getTodayKey());
      await GoalReschedulePromptService.prefs.flush();
    } catch (error) {
      logger.warn('GoalReschedulePromptService write global last shown failed', error as Object);
    }
  }

  private static getTodayKey(): string {
    return new Date().toISOString().split('T')[0];
  }
}
