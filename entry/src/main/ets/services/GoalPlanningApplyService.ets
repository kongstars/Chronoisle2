import {
  PlanningSession,
  ProgressTrack,
  RecurringAction,
  CountdownItem,
  ApplyResult
} from '../models/PlanningSession';
import { db } from '../storage/Database';
import { Goal, GoalCategory, KeyResult } from '../models/Goal';
import { Task, TaskPriority } from '../models/Task';
import { DayEvent, DayEventType, ReminderRule, ReminderType } from '../models/DayEvent';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('GoalPlanningApplyService');

/**
 * 负责将规划好的 PlanningSession 数据转化为本地应用的数据实体 (Goal/Task/DayEvent)
 */
export class GoalPlanningApplyService {
  public static async apply(session: PlanningSession): Promise<ApplyResult> {
    const failedParts: Array<'goal' | 'progress' | 'tasks' | 'reminders' | 'countdowns'> = [];

    try {
      if (!session.goalDraft) {
        return { success: false, message: '规划数据不完整' };
      }

      let goal: Goal | null = null;

      if (session.source === 'create_goal') {
        goal = GoalPlanningApplyService.createGoal(session);
        await db.addGoal(goal);
      } else if (session.source === 'enhance_goal' && session.targetGoalId) {
        goal = await GoalPlanningApplyService.updateExistingGoal(session);
        if (!goal) {
          goal = GoalPlanningApplyService.createGoal(session);
          await db.addGoal(goal);
        } else {
          await db.updateGoal(goal);
        }
      } else {
        return { success: false, message: '无效的会话来源配置' };
      }

      if (!goal) {
        return { success: false, message: '目标创建失败' };
      }

      const goalId = goal.id;
      const createdTaskIds: string[] = [];
      const createdReminderIds: string[] = [];

      if (session.actionPlan && session.actionPlan.oneOffTasks.length > 0) {
        try {
          for (const oneoff of session.actionPlan.oneOffTasks) {
            const task = new Task(oneoff.title, goalId, goal.title, goal.category);
            task.description = oneoff.description || '';
            task.priority = GoalPlanningApplyService.mapPriority(oneoff.priority);
            task.estimatedHours = Math.max(0.5, oneoff.estimatedHours || 0.5);
            if (oneoff.suggestedDueDate) {
              task.dueDate = oneoff.suggestedDueDate;
            }
            task.aiGenerated = true;
            await db.addTask(task);
            createdTaskIds.push(task.id);
          }
        } catch (e) {
          logger.error('GoalPlanningApplyService add tasks error', e as Object);
          failedParts.push('tasks');
        }
      }

      const reminderActions = session.automationPlan ? session.automationPlan.reminders : (session.actionPlan ? session.actionPlan.recurringActions : []);
      if (reminderActions && reminderActions.length > 0) {
        try {
          for (const recurring of reminderActions) {
            const event = GoalPlanningApplyService.createRecurringEvent(recurring, goalId, goal.title);
            if (goal.endDate) {
              event.endDate = goal.endDate;
            }
            await db.addDayEvent(event);
            createdReminderIds.push(event.id);
          }
        } catch (e) {
          logger.error('GoalPlanningApplyService add reminders error', e as Object);
          failedParts.push('reminders');
        }
      }

      const countdowns = session.automationPlan ? session.automationPlan.countdowns : (session.actionPlan ? session.actionPlan.countdowns : []);
      if (countdowns && countdowns.length > 0) {
        try {
          for (const countdown of countdowns) {
            const event = GoalPlanningApplyService.createCountdownEvent(countdown, goalId, goal.title);
            if (!event) {
              continue;
            }
            if (goal.endDate) {
              event.endDate = goal.endDate;
            }
            await db.addDayEvent(event);
            createdReminderIds.push(event.id);
          }
        } catch (e) {
          logger.error('GoalPlanningApplyService add countdowns error', e as Object);
          failedParts.push('countdowns');
        }
      }

      return {
        success: true,
        goalId: goalId,
        createdTrackTitles: (session.progressPlan?.tracks || []).map((track: ProgressTrack) => track.title),
        createdTaskIds: createdTaskIds,
        createdReminderIds: createdReminderIds,
        failedParts: failedParts.length > 0 ? failedParts : undefined
      };
    } catch (err) {
      logger.error('GoalPlanningApplyService apply error', err as Object);
      return { success: false, message: (err as Error).message };
    }
  }

  private static createGoal(session: PlanningSession): Goal {
    const draft = session.goalDraft!;
    const category = GoalPlanningApplyService.mapGoalCategory(draft.category);
    const goal = new Goal(draft.title, category, draft.description, false);

    if (draft.periodDays && draft.periodDays > 0) {
      goal.endDate = goal.startDate + (draft.periodDays * 24 * 60 * 60 * 1000);
    }

    const tracks = session.progressPlan?.tracks || [];
    tracks.forEach(track => {
      const kr = new KeyResult(track.title, track.targetValue || 1, 0);
      goal.keyResults.push(kr);
    });

    goal.updateProgress();
    return goal;
  }

  private static async updateExistingGoal(session: PlanningSession): Promise<Goal | null> {
    const existingGoal = db.getGoalById(session.targetGoalId || '');
    if (!existingGoal) return null;

    const draft = session.goalDraft;
    if (draft) {
      existingGoal.title = draft.title;
      existingGoal.description = draft.description;
      existingGoal.category = GoalPlanningApplyService.mapGoalCategory(draft.category);
      if (draft.periodDays && draft.periodDays > 0) {
        existingGoal.endDate = existingGoal.startDate + (draft.periodDays * 24 * 60 * 60 * 1000);
      }
    }

    const tracks = session.progressPlan?.tracks || [];
    tracks.forEach(track => {
      if (!existingGoal.keyResults.some((kr: KeyResult) => kr.title === track.title)) {
        const kr = new KeyResult(track.title, track.targetValue || 1, 0);
        existingGoal.keyResults.push(kr);
      }
    });

    existingGoal.updateProgress();
    return existingGoal;
  }

  private static mapGoalCategory(rawCategory?: string | null): GoalCategory {
    const cat = (rawCategory || '').toUpperCase();
    if (cat === 'HEALTH') return GoalCategory.HEALTH;
    if (cat === 'FINANCE') return GoalCategory.FINANCE;
    if (cat === 'FUN') return GoalCategory.FUN;
    return GoalCategory.LEARNING;
  }

  private static mapPriority(rawParam: string | undefined): TaskPriority {
    if (rawParam === 'high') return TaskPriority.HIGH;
    if (rawParam === 'low') return TaskPriority.LOW;
    return TaskPriority.NORMAL;
  }

  private static createRecurringEvent(action: RecurringAction, goalId: string, goalTitle: string): DayEvent {
    const event = new DayEvent(action.title, DayEventType.HABIT, GoalPlanningApplyService.startOfToday());
    event.goalId = goalId;
    event.goalTitle = goalTitle;

    if (action.rule === 'weekly') {
      const rawWeekdays = action.weekdays && action.weekdays.length > 0
        ? action.weekdays
        : GoalPlanningApplyService.parseWeekdays(action.timeParams || []);
      const resolvedDays = rawWeekdays.length > 0 ? rawWeekdays : [1];
      resolvedDays.forEach((weekday: number) => {
        event.addReminderRule({
          id: '',
          type: ReminderType.PERIODIC_WEEKLY,
          weekday: weekday,
          hour: 9,
          minute: 0
        } as ReminderRule);
      });
      return event;
    }

    if (action.rule === 'monthly') {
      event.addReminderRule({
        id: '',
        type: ReminderType.PERIODIC_MONTHLY,
        dayOfMonth: GoalPlanningApplyService.parseDayOfMonth(action.timeParams || []),
        hour: 9,
        minute: 0
      } as ReminderRule);
      return event;
    }

    event.addReminderRule({
      id: '',
      type: ReminderType.HABIT_DAILY,
      hour: 9,
      minute: 0
    } as ReminderRule);
    return event;
  }

  private static createCountdownEvent(item: CountdownItem, goalId: string, goalTitle: string): DayEvent | null {
    const targetDate = new Date(item.targetDate).getTime();
    if (isNaN(targetDate)) {
      return null;
    }

    const event = new DayEvent(item.title, DayEventType.COUNTDOWN, GoalPlanningApplyService.startOfToday());
    event.targetDate = targetDate;
    event.goalId = goalId;
    event.goalTitle = goalTitle;
    event.addReminderRule({
      id: '',
      type: ReminderType.COUNTER_DATE,
      targetDate: targetDate,
      hour: 9,
      minute: 0
    } as ReminderRule);
    return event;
  }

  private static parseWeekdays(timeParams: Array<string | number>): number[] {
    return timeParams
      .map((item: string | number) => typeof item === 'number' ? item : parseInt(item, 10))
      .map((value: number) => value === 7 ? 0 : value)
      .filter((value: number) => !isNaN(value) && value >= 0 && value <= 6);
  }

  private static parseDayOfMonth(timeParams: Array<string | number>): number {
    if (!timeParams || timeParams.length === 0) {
      return 1;
    }
    const value = typeof timeParams[0] === 'number' ? timeParams[0] : parseInt(timeParams[0], 10);
    if (isNaN(value) || value < 1 || value > 31) {
      return 1;
    }
    return value;
  }

  private static startOfToday(): number {
    const date = new Date();
    date.setHours(0, 0, 0, 0);
    return date.getTime();
  }
}
