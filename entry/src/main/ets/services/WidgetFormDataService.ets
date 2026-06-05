import common from '@ohos.app.ability.common';
import dataPreferences from '@ohos.data.preferences';
import { DayEventData, DayEventType } from '../models/DayEvent';
import { PomodoroData } from '../models/Pomodoro';
import { TaskData, TaskStatus } from '../models/Task';
import {
  CountdownWidgetData,
  DashboardWidgetData,
  FocusWidgetData,
  HabitWidgetData,
  MainWidgetData,
  MainWidgetTask,
  TodayPlanWidgetData,
  TodoWidgetData,
  VoiceWidgetData,
  WidgetCountdown,
  WidgetCountdownType,
  WidgetFocus,
  WidgetFormData,
  WidgetHabit,
  WidgetPlanTask,
  WidgetStats,
  WidgetTask,
  WidgetTodayPlan
} from '../models/WidgetData';

export enum WidgetType {
  TODO = 'widget_todo',
  HABIT = 'widget_habit',
  COUNTDOWN = 'widget_countdown',
  TODAY_PLAN = 'widget_today_plan',
  FOCUS = 'widget_focus',
  DASHBOARD = 'widget_dashboard',
  VOICE = 'widget_voice',
  MAIN = 'widget_main'
}

export type WidgetFormDataPayload =
  TodoWidgetData |
  HabitWidgetData |
  CountdownWidgetData |
  TodayPlanWidgetData |
  FocusWidgetData |
  DashboardWidgetData |
  VoiceWidgetData |
  MainWidgetData |
  WidgetFormData;

interface StoredTodayPlanTask {
  id?: string;
  taskId?: string;
  title?: string;
  taskTitle?: string;
  timeSlot?: string;
  isCompleted?: boolean;
  completed?: boolean;
}

interface StoredTodayPlan {
  title?: string;
  tasks?: StoredTodayPlanTask[];
  generatedAt?: number;
  adoptedAt?: number;
}

interface ActivePomodoroSnapshot {
  completed?: boolean;
  startTime?: number;
  duration?: number;
  taskTitle?: string;
}

export class WidgetFormDataService {
  static normalizeFormName(formName: string | undefined): string {
    if (!formName || formName.length === 0) {
      return WidgetType.VOICE;
    }
    return formName;
  }

  static buildDefaultFormData(formName: string): WidgetFormDataPayload {
    switch (formName) {
      case WidgetType.TODO:
        return new TodoWidgetData();
      case WidgetType.HABIT:
        return new HabitWidgetData();
      case WidgetType.COUNTDOWN:
        return new CountdownWidgetData();
      case WidgetType.TODAY_PLAN:
        return new TodayPlanWidgetData();
      case WidgetType.FOCUS:
        return new FocusWidgetData();
      case WidgetType.DASHBOARD:
        return new DashboardWidgetData();
      case WidgetType.MAIN:
        return new MainWidgetData();
      case WidgetType.VOICE:
      default:
        return new VoiceWidgetData();
    }
  }

  static async buildFormData(context: common.UIAbilityContext | common.ExtensionContext, formName: string): Promise<WidgetFormDataPayload> {
    const tasks: TaskData[] = await WidgetFormDataService.readTaskData(context);
    const events: DayEventData[] = await WidgetFormDataService.readDayEventData(context);
    const pomodoros: PomodoroData[] = await WidgetFormDataService.readPomodoroData(context);

    switch (formName) {
      case WidgetType.TODO:
        return WidgetFormDataService.buildTodoFormData(tasks);
      case WidgetType.HABIT:
        return WidgetFormDataService.buildHabitFormData(events, tasks);
      case WidgetType.COUNTDOWN:
        return WidgetFormDataService.buildCountdownFormData(events);
      case WidgetType.TODAY_PLAN:
        return await WidgetFormDataService.buildTodayPlanFormData(context);
      case WidgetType.FOCUS:
        return await WidgetFormDataService.buildFocusFormData(context);
      case WidgetType.DASHBOARD:
        return WidgetFormDataService.buildDashboardFormData(tasks, pomodoros);
      case WidgetType.MAIN:
        return await WidgetFormDataService.buildMainFormData(context, tasks, events, pomodoros);
      case WidgetType.VOICE:
      default:
        return new VoiceWidgetData();
    }
  }

  private static async readTaskData(context: common.UIAbilityContext | common.ExtensionContext): Promise<TaskData[]> {
    const raw: string = await WidgetFormDataService.readPreferenceString(context, 'life_goal_storage', 'tasks', '[]');
    return JSON.parse(raw) as TaskData[];
  }

  private static async readDayEventData(context: common.UIAbilityContext | common.ExtensionContext): Promise<DayEventData[]> {
    const raw: string = await WidgetFormDataService.readPreferenceString(context, 'life_goal_storage', 'dayEvents', '[]');
    return JSON.parse(raw) as DayEventData[];
  }

  private static async readPomodoroData(context: common.UIAbilityContext | common.ExtensionContext): Promise<PomodoroData[]> {
    const raw: string = await WidgetFormDataService.readPreferenceString(context, 'life_goal_storage', 'pomodoros', '[]');
    return JSON.parse(raw) as PomodoroData[];
  }

  private static async readPreferenceString(context: common.UIAbilityContext | common.ExtensionContext, storageName: string, key: string, fallback: string): Promise<string> {
    try {
      const prefs = await dataPreferences.getPreferences(context, { name: storageName });
      const value = await prefs.get(key, fallback);
      return value as string;
    } catch (_) {
      return fallback;
    }
  }

  private static buildTodoFormData(tasks: TaskData[]): TodoWidgetData {
    const todayEnd = new Date();
    todayEnd.setHours(23, 59, 59, 999);

    const pendingTasks: TaskData[] = tasks
      .filter((task: TaskData) => task.status === TaskStatus.PENDING)
      .filter((task: TaskData) => {
        if (!task.dueDate) {
          return true;
        }
        return task.dueDate <= todayEnd.getTime();
      })
      .sort((left: TaskData, right: TaskData) => {
        if (left.isPinned !== right.isPinned) {
          return left.isPinned ? -1 : 1;
        }
        if (left.dueDate && right.dueDate) {
          return left.dueDate - right.dueDate;
        }
        return (right.createdAt || 0) - (left.createdAt || 0);
      })
      .slice(0, 8);

    const data: TodoWidgetData = new TodoWidgetData();
    data.tasks = pendingTasks.map((task: TaskData): WidgetTask => {
      const item: WidgetTask = new WidgetTask();
      item.id = task.id;
      item.title = task.title;
      item.goalTitle = task.goalTitle;
      item.dueDate = task.dueDate;
      item.isPinned = task.isPinned ?? false;
      item.isOverdue = task.dueDate ? task.dueDate < Date.now() : false;
      return item;
    });
    data.emptyMessage = pendingTasks.length === 0 ? '暂无待办，点击添加' : '';
    return data;
  }

  private static buildHabitFormData(events: DayEventData[], tasks: TaskData[]): HabitWidgetData {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayEnd = new Date(today);
    todayEnd.setHours(23, 59, 59, 999);

    const habitEvents: DayEventData[] = events
      .filter((event: DayEventData) => event.type === DayEventType.HABIT && event.isEnabled)
      .slice(0, 5);

    const data: HabitWidgetData = new HabitWidgetData();
    data.habits = habitEvents.map((event: DayEventData): WidgetHabit => {
      const completedToday: boolean = tasks.some((task: TaskData) => {
        return task.reminderId === event.id &&
          task.status === TaskStatus.COMPLETED &&
          task.completedAt !== undefined &&
          task.completedAt >= today.getTime() &&
          task.completedAt <= todayEnd.getTime();
      });

      const item: WidgetHabit = new WidgetHabit();
      item.id = event.id;
      item.title = event.title;
      item.isCompleted = completedToday;
      item.currentCount = completedToday ? 1 : 0;
      item.targetCount = 1;
      return item;
    });
    data.completedCount = data.habits.filter((habit: WidgetHabit) => habit.isCompleted).length;
    data.totalCount = data.habits.length;
    data.emptyMessage = data.habits.length === 0 ? '暂无习惯，点击添加' : '';
    return data;
  }

  private static buildCountdownFormData(events: DayEventData[]): CountdownWidgetData {
    const now = Date.now();
    const oneDay = 24 * 60 * 60 * 1000;
    const countdownEvents: DayEventData[] = events
      .filter((event: DayEventData) => {
        const isCountdownType = event.type === DayEventType.MILESTONE ||
          event.type === DayEventType.COUNTDOWN ||
          event.type === DayEventType.COUNTER;
        return isCountdownType && event.isEnabled && event.targetDate !== undefined;
      })
      .sort((left: DayEventData, right: DayEventData) => (left.targetDate || 0) - (right.targetDate || 0))
      .slice(0, 3);

    const data: CountdownWidgetData = new CountdownWidgetData();
    data.countdowns = countdownEvents.map((event: DayEventData): WidgetCountdown => {
      const targetDate = event.targetDate || now;
      const item: WidgetCountdown = new WidgetCountdown();
      item.id = event.id;
      item.title = event.title;
      item.targetDate = targetDate;
      item.daysRemaining = Math.ceil((targetDate - now) / oneDay);
      item.type = WidgetFormDataService.getCountdownType(event.type);
      return item;
    });
    data.emptyMessage = data.countdowns.length === 0 ? '暂无倒计时，点击添加' : '';
    return data;
  }

  private static getCountdownType(type: DayEventType): WidgetCountdownType {
    if (type === DayEventType.MILESTONE) {
      return 'milestone';
    }
    if (type === DayEventType.COUNTER) {
      return 'anniversary';
    }
    return 'countdown';
  }

  private static async buildTodayPlanFormData(context: common.UIAbilityContext | common.ExtensionContext): Promise<TodayPlanWidgetData> {
    const pendingPlanJson: string = await WidgetFormDataService.readPreferenceString(context, 'chronoisle_settings', 'pending_today_plan', '{}');
    const adoptedPlanJson: string = await WidgetFormDataService.readPreferenceString(context, 'chronoisle_settings', 'adopted_today_plan', '{}');
    const pendingPlan: StoredTodayPlan | null = WidgetFormDataService.parseTodayPlan(pendingPlanJson);
    const adoptedPlan: StoredTodayPlan | null = WidgetFormDataService.parseTodayPlan(adoptedPlanJson);

    let sourcePlan: StoredTodayPlan | null = null;
    let isAdopted = false;
    if (pendingPlan !== null && pendingPlan.tasks !== undefined && pendingPlan.tasks.length > 0) {
      sourcePlan = pendingPlan;
    } else if (adoptedPlan !== null && adoptedPlan.tasks !== undefined && adoptedPlan.tasks.length > 0) {
      sourcePlan = adoptedPlan;
      isAdopted = true;
    }

    const data: TodayPlanWidgetData = new TodayPlanWidgetData();
    if (sourcePlan === null || sourcePlan.tasks === undefined) {
      data.emptyMessage = '暂无 AI 计划，点击生成';
      return data;
    }

    const plan: WidgetTodayPlan = new WidgetTodayPlan();
    plan.title = sourcePlan.title || '今日计划';
    plan.generatedAt = sourcePlan.generatedAt || sourcePlan.adoptedAt || 0;
    plan.isAdopted = isAdopted;
    plan.tasks = sourcePlan.tasks.slice(0, 5).map((task: StoredTodayPlanTask): WidgetPlanTask => {
      const item: WidgetPlanTask = new WidgetPlanTask();
      item.id = task.id || task.taskId || '';
      item.title = task.title || task.taskTitle || '';
      item.timeSlot = task.timeSlot;
      item.isCompleted = task.isCompleted || task.completed || false;
      return item;
    });

    data.plan = plan;
    data.emptyMessage = '';
    return data;
  }

  private static parseTodayPlan(raw: string): StoredTodayPlan | null {
    try {
      return JSON.parse(raw) as StoredTodayPlan;
    } catch (error) {
      return null;
    }
  }

  private static async buildFocusFormData(context: common.UIAbilityContext | common.ExtensionContext): Promise<FocusWidgetData> {
    try {
      const prefs = await dataPreferences.getPreferences(context, { name: 'chronoisle_settings' });
      const focusMinutesToday = await prefs.get('focus_minutes_today', 0) as number;
      const activePomodoroJson = await prefs.get('active_pomodoro', '{}') as string;
      const activePomodoro: ActivePomodoroSnapshot | null = WidgetFormDataService.parseActivePomodoro(activePomodoroJson);

    const focus: WidgetFocus = new WidgetFocus();
    focus.totalFocusMinutes = focusMinutesToday || 0;

    if (activePomodoro !== null && !activePomodoro.completed && activePomodoro.startTime !== undefined) {
      const duration = activePomodoro.duration || 25;
      const endTime = activePomodoro.startTime + duration * 60 * 1000;
      const remainingSeconds = Math.max(0, Math.floor((endTime - Date.now()) / 1000));
      if (remainingSeconds > 0) {
        focus.isFocusing = true;
        focus.remainingSeconds = remainingSeconds;
        focus.currentTask = activePomodoro.taskTitle || '专注中...';
      }
    }

    const data: FocusWidgetData = new FocusWidgetData();
    data.focus = focus;
    data.emptyMessage = !focus.isFocusing && focus.totalFocusMinutes === 0 ? '点击开始专注' : '';
    return data;
    } catch (_) {
      const data: FocusWidgetData = new FocusWidgetData();
      const focus: WidgetFocus = new WidgetFocus();
      data.focus = focus;
      data.emptyMessage = '数据加载失败';
      return data;
    }
  }

  private static parseActivePomodoro(raw: string): ActivePomodoroSnapshot | null {
    try {
      return JSON.parse(raw) as ActivePomodoroSnapshot;
    } catch (error) {
      return null;
    }
  }

  private static buildDashboardFormData(tasks: TaskData[], pomodoros: PomodoroData[]): DashboardWidgetData {
    const now = Date.now();
    const todayStart = new Date(now);
    todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date(todayStart);
    todayEnd.setHours(23, 59, 59, 999);
    const weekStart = new Date(todayStart);
    weekStart.setDate(weekStart.getDate() - weekStart.getDay());

    const todayTasks: TaskData[] = tasks.filter((task: TaskData) => {
      if (!task.dueDate) {
        return false;
      }
      return task.dueDate >= todayStart.getTime() && task.dueDate <= todayEnd.getTime();
    });
    const todayCompletedTasks: TaskData[] = todayTasks.filter((task: TaskData) => task.status === TaskStatus.COMPLETED);
    const todayPomodoros: PomodoroData[] = pomodoros.filter((pomodoro: PomodoroData) => {
      return pomodoro.createdAt >= todayStart.getTime() && pomodoro.completed;
    });
    const weekPomodoros: PomodoroData[] = pomodoros.filter((pomodoro: PomodoroData) => {
      return pomodoro.createdAt >= weekStart.getTime() && pomodoro.completed;
    });

    const stats: WidgetStats = new WidgetStats();
    stats.focusMinutesToday = todayPomodoros.reduce((sum: number, pomodoro: PomodoroData) => sum + (pomodoro.duration || 0), 0);
    stats.tasksCompletedToday = todayCompletedTasks.length;
    stats.tasksTotalToday = todayTasks.length;
    stats.weekFocusMinutes = weekPomodoros.reduce((sum: number, pomodoro: PomodoroData) => sum + (pomodoro.duration || 0), 0);
    stats.weekTasksCompleted = tasks.filter((task: TaskData) => {
      return task.completedAt !== undefined &&
        task.completedAt >= weekStart.getTime() &&
        task.status === TaskStatus.COMPLETED;
    }).length;
    stats.currentStreak = WidgetFormDataService.calculateCurrentStreak(tasks, now);

    const data: DashboardWidgetData = new DashboardWidgetData();
    data.stats = stats;
    return data;
  }

  private static calculateCurrentStreak(tasks: TaskData[], now: number): number {
    const completedDates = new Set<string>();
    tasks
      .filter((task: TaskData) => task.status === TaskStatus.COMPLETED && task.completedAt !== undefined)
      .forEach((task: TaskData) => {
        const completedAt = task.completedAt || 0;
        const date = new Date(completedAt);
        completedDates.add(`${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`);
      });

    let streak = 0;
    for (let index = 0; index < 365; index++) {
      const date = new Date(now - index * 24 * 60 * 60 * 1000);
      const dateKey = `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`;
      if (completedDates.has(dateKey)) {
        streak++;
      } else if (index > 0) {
        break;
      }
    }
    return streak;
  }

  private static async buildMainFormData(
    context: common.UIAbilityContext | common.ExtensionContext,
    tasks: TaskData[],
    events: DayEventData[],
    pomodoros: PomodoroData[]
  ): Promise<MainWidgetData> {
    const data: MainWidgetData = new MainWidgetData();

    // AI 今日计划
    const pendingPlanJson = await WidgetFormDataService.readPreferenceString(context, 'chronoisle_settings', 'pending_today_plan', '{}');
    const adoptedPlanJson = await WidgetFormDataService.readPreferenceString(context, 'chronoisle_settings', 'adopted_today_plan', '{}');

    let planData: StoredTodayPlan | null = null;
    try { planData = JSON.parse(pendingPlanJson); } catch {}
    if (!planData || !planData.tasks || planData.tasks.length === 0) {
      try { planData = JSON.parse(adoptedPlanJson); } catch {}
    }

    if (planData && planData.tasks && planData.tasks.length > 0) {
      const completedTasks = planData.tasks.filter((t: StoredTodayPlanTask) => t.isCompleted || false);
      data.planSummary = `${planData.tasks.length} 项任务 · ${completedTasks.length} 已完成`;
      data.planTaskCount = planData.tasks.length;
      data.isPlanAdopted = !!planData.adoptedAt;

      // AI 计划任务列表
      data.tasks = planData.tasks.slice(0, 4).map((t: StoredTodayPlanTask): MainWidgetTask => {
        const item: MainWidgetTask = new MainWidgetTask();
        item.id = t.id || t.taskId || '';
        item.title = t.title || t.taskTitle || '';
        item.isCompleted = t.isCompleted || t.completed || false;
        item.isOverdue = false;
        return item;
      });
    } else {
      data.planSummary = '点击生成今日计划';
      data.planTaskCount = 0;
      data.isPlanAdopted = false;
      data.tasks = [];
    }

    // 刷新时间
    const nowDate = new Date();
    data.refreshTime = `${nowDate.getHours().toString().padStart(2, '0')}:${nowDate.getMinutes().toString().padStart(2, '0')}`;

    return data;
  }
}
