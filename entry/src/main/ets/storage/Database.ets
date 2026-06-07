import dataPreferences from '@ohos.data.preferences';

import { Goal, GoalCategory, KeyResult, GoalData, KeyResultData } from '../models/Goal';
import { Task, TaskStatus, TaskData } from '../models/Task';
import { Pomodoro, PomodoroData } from '../models/Pomodoro';
import { DayEvent, DayEventData } from '../models/DayEvent';
import type { SyncDataSet } from '../services/CloudSyncService';
import { dataSyncService } from '../services/DataSyncService';
import { getEventsForDate } from '../common/DayEventUtils';
import { Logger } from '../Utils/Logger';
import {
  createReminderAutoTask,
  autoCompleteExpirations,
  getReminderCompletionCandidate
} from '../services/ReminderTaskService';
import { widgetRefreshService } from '../services/WidgetRefreshService';
import common from '@ohos.app.ability.common';

const PREFERENCES_NAME: string = 'life_goal_storage';
const GOALS_KEY: string = 'goals';
const TASKS_KEY: string = 'tasks';
const POMODOROS_KEY: string = 'pomodoros';
const DAY_EVENTS_KEY: string = 'dayEvents';

const logger = Logger.create('Database');

export interface GoalsTasksData {
  goals: Goal[];
  tasks: Task[];
}
// 让 GoalsTasksData 和 SyncDataSet 保持一致，避免 structural typing 问题
export function toSyncDataSet(data: GoalsTasksData): SyncDataSet {
  return {
    goals: data.goals,
    tasks: data.tasks,
    dayEvents: [],
    pomodoros: []
  };
}

export class Database {
  private static instance: Database;
  private goals: Goal[] = [];
  private tasks: Task[] = [];
  private pomodoros: Pomodoro[] = [];
  private dayEvents: DayEvent[] = [];
  private prefs: dataPreferences.Preferences | null = null;
  private context: Context | null = null;
  private initialized: boolean = false;
  private dataChangeListeners: Array<() => void> = [];

  private constructor() {}

  private cloneTasks(tasks: Task[]): Task[] {
    const tasksJson: string = JSON.stringify(tasks);
    const tasksData: TaskData[] = JSON.parse(tasksJson) as TaskData[];
    return tasksData.map((task: TaskData) => Task.fromJSON(task));
  }

  private clonePomodoros(pomodoros: Pomodoro[]): Pomodoro[] {
    const pomodorosJson: string = JSON.stringify(pomodoros);
    const pomodoroData: PomodoroData[] = JSON.parse(pomodorosJson) as PomodoroData[];
    return pomodoroData.map((pomodoro: PomodoroData) => Pomodoro.fromJSON(pomodoro));
  }

  private cloneDayEvents(events: DayEvent[]): DayEvent[] {
    const eventsJson: string = JSON.stringify(events);
    const eventsData: DayEventData[] = JSON.parse(eventsJson) as DayEventData[];
    return eventsData.map((event: DayEventData) => DayEvent.fromJSON(event));
  }

  static getInstance(): Database {
    if (!Database.instance) {
      Database.instance = new Database();
    }
    return Database.instance;
  }

  onDataChanged(listener: () => void): void {
    this.dataChangeListeners.push(listener);
  }

  offDataChanged(listener: () => void): void {
    const index = this.dataChangeListeners.indexOf(listener);
    if (index !== -1) {
      this.dataChangeListeners.splice(index, 1);
    }
  }

  private notifyDataChanged(): void {
    this.dataChangeListeners.forEach(listener => {
      try {
        listener();
      } catch (error) {
        logger.error('Data change listener error', error as Object);
      }
    });
  }

  async initialize(context: Context): Promise<void> {
    this.context = context;
    if (this.initialized && this.prefs !== null) {
      logger.debug('already initialized, skipping');
      return;
    }
    
    try {
      this.prefs = await dataPreferences.getPreferences(context, PREFERENCES_NAME);
      const goalsValue: dataPreferences.ValueType = await this.prefs.get(GOALS_KEY, '[]');
      const tasksValue: dataPreferences.ValueType = await this.prefs.get(TASKS_KEY, '[]');
      const pomodorosValue: dataPreferences.ValueType = await this.prefs.get(POMODOROS_KEY, '[]');
      const dayEventsValue: dataPreferences.ValueType = await this.prefs.get(DAY_EVENTS_KEY, '[]');
      const goalsJson: string = goalsValue as string;
      const tasksJson: string = tasksValue as string;
      const pomodorosJson: string = pomodorosValue as string;
      const dayEventsJson: string = dayEventsValue as string;
      const goalsParse: Object = JSON.parse(goalsJson);
      const goalsData: GoalData[] = goalsParse as GoalData[];
      logger.debug('initialize: loaded', goalsData.length, 'goals from storage');
      goalsData.forEach((goalData: GoalData, index: number) => {
        logger.debug(`  Goal[${index}]: id=${goalData.id}, keyResults=${goalData.keyResults?.length || 0}`);
      });
      this.goals = goalsData.map((g: GoalData) => Goal.fromJSON(g));
      const tasksParse: Object = JSON.parse(tasksJson);
      const tasksData: TaskData[] = tasksParse as TaskData[];
      this.tasks = tasksData.map((t: TaskData) => Task.fromJSON(t));
      const pomodorosParse: Object = JSON.parse(pomodorosJson);
      const pomodorosData: PomodoroData[] = pomodorosParse as PomodoroData[];
      this.pomodoros = pomodorosData.map((p: PomodoroData) => Pomodoro.fromJSON(p));
      const dayEventsParse: Object = JSON.parse(dayEventsJson);
      const dayEventsData: DayEventData[] = dayEventsParse as DayEventData[];
      this.dayEvents = dayEventsData.map((d: DayEventData) => DayEvent.fromJSON(d));
      
      this.initialized = true;
      await this.syncReminderAutoTasks();
      logger.info('Database initialized successfully');
      
      // 同步数据到全局状态
      dataSyncService.setGoals(this.goals);
      dataSyncService.setTasks(this.tasks);
    } catch (error) {
      logger.error('Database initialize error', error as Object);
      this.goals = [];
      this.tasks = [];
      this.pomodoros = [];
      this.dayEvents = [];
    }
  }

  isInitialized(): boolean {
    return this.initialized;
  }

  getAllGoals(): Goal[] {
    // 返回深拷贝，避免外部直接修改内部数据
    const goalsJson = JSON.stringify(this.goals);
    const goalsData: GoalData[] = JSON.parse(goalsJson);
    return goalsData.map((g: GoalData) => Goal.fromJSON(g));
  }

  getActiveGoals(): Goal[] {
    return this.getAllGoals().filter((goal: Goal) => !goal.isArchived);
  }

  getArchivedGoals(): Goal[] {
    return this.getAllGoals().filter((goal: Goal) => goal.isArchived);
  }

  getAllTasks(): Task[] {
    // 返回深拷贝，避免外部直接修改内部数据
    const tasksJson = JSON.stringify(this.tasks);
    const tasksData: TaskData[] = JSON.parse(tasksJson);
    return tasksData.map((t: TaskData) => Task.fromJSON(t));
  }

  getGoalById(goalId: string): Goal | undefined {
    const goal = this.goals.find((g: Goal) => g.id === goalId);
    if (goal) {
      // 返回深拷贝
      const goalJson = JSON.stringify(goal);
      const goalData: GoalData = JSON.parse(goalJson);
      return Goal.fromJSON(goalData);
    }
    return undefined;
  }

  getTaskById(taskId: string): Task | undefined {
    const task = this.tasks.find((t: Task) => t.id === taskId);
    if (task) {
      // 返回深拷贝
      const taskJson = JSON.stringify(task);
      const taskData: TaskData = JSON.parse(taskJson);
      return Task.fromJSON(taskData);
    }
    return undefined;
  }

  async addGoal(goal: Goal): Promise<void> {
    logger.debug('addGoal:', goal.id, 'keyResults:', goal.keyResults?.length || 0, 'progress:', goal.progress);
    this.goals.unshift(goal);
    await this.save();
  }

  async updateGoal(goal: Goal): Promise<void> {
    logger.debug('updateGoal:', goal.id, 'keyResults:', goal.keyResults?.length || 0, 'progress:', goal.progress);
    const index: number = this.goals.findIndex((g: Goal) => g.id === goal.id);
    if (index !== -1) {
      goal.updatedAt = Date.now();
      this.goals[index] = goal;
      const reminderLinksChanged = this.syncDayEventGoalLinks(goal);
      await this.save();
      if (reminderLinksChanged) {
        await this.saveDayEvents();
      }
    } else {
      logger.warn('updateGoal: goal not found', goal.id);
    }
  }

  async deleteGoal(goalId: string): Promise<void> {
    const relatedTaskIds: string[] = this.tasks
      .filter((task: Task) => task.goalId === goalId)
      .map((task: Task) => task.id);

    this.goals = this.goals.filter((g: Goal) => g.id !== goalId);
    this.tasks = this.tasks.filter((task: Task) => task.goalId !== goalId);
    this.pomodoros = this.pomodoros.filter((pomodoro: Pomodoro) => !relatedTaskIds.includes(pomodoro.taskId));
    const reminderLinksChanged = this.clearDayEventGoalLinks(goalId);
    await this.save();
    await this.savePomodoros();
    if (reminderLinksChanged) {
      await this.saveDayEvents();
    }
  }

  exportData(): GoalsTasksData {
    const goalsJson: string = JSON.stringify(this.goals);
    const tasksJson: string = JSON.stringify(this.tasks);
    const goalDataList: GoalData[] = JSON.parse(goalsJson) as GoalData[];
    const taskDataList: TaskData[] = JSON.parse(tasksJson) as TaskData[];
    const goalCopies: Goal[] = goalDataList.map((g: GoalData) => Goal.fromJSON(g));
    const taskCopies: Task[] = taskDataList.map((t: TaskData) => Task.fromJSON(t));
    return {
      goals: goalCopies,
      tasks: taskCopies
    };
  }

  async replaceAllData(goals: Goal[], tasks: Task[], dayEvents?: DayEvent[], pomodoros?: Pomodoro[]): Promise<void> {
    const goalsJson: string = JSON.stringify(goals);
    const tasksJson: string = JSON.stringify(tasks);
    const goalDataList: GoalData[] = JSON.parse(goalsJson) as GoalData[];
    const taskDataList: TaskData[] = JSON.parse(tasksJson) as TaskData[];
    this.goals = goalDataList.map((g: GoalData) => Goal.fromJSON(g));
    this.tasks = taskDataList.map((t: TaskData) => Task.fromJSON(t));
    
    if (dayEvents) {
      const dayEventsJson: string = JSON.stringify(dayEvents);
      const dayEventDataList: DayEventData[] = JSON.parse(dayEventsJson) as DayEventData[];
      this.dayEvents = dayEventDataList.map((d: DayEventData) => DayEvent.fromJSON(d));
      await this.saveDayEvents();
    }
    
    if (pomodoros) {
      const pomodorosJson: string = JSON.stringify(pomodoros);
      const pomodoroDataList: PomodoroData[] = JSON.parse(pomodorosJson) as PomodoroData[];
      this.pomodoros = pomodoroDataList.map((p: PomodoroData) => Pomodoro.fromJSON(p));
      await this.savePomodoros();
    }
    
    await this.save();
  }

  getTasksByGoalId(goalId: string): Task[] {
    return this.cloneTasks(this.tasks.filter((t: Task) => t.goalId === goalId));
  }

  getPendingTasks(): Task[] {
    return this.cloneTasks(this.tasks.filter((t: Task) => t.status === TaskStatus.PENDING));
  }

  getCompletedTasks(): Task[] {
    return this.cloneTasks(this.tasks.filter((t: Task) => t.status === TaskStatus.COMPLETED));
  }

  getTasksByReminderId(reminderId: string): Task[] {
    const matchedTasks = this.tasks.filter((task: Task) => task.reminderId === reminderId);
    const tasksJson: string = JSON.stringify(matchedTasks);
    const tasksData: TaskData[] = JSON.parse(tasksJson) as TaskData[];
    return tasksData.map((task: TaskData) => Task.fromJSON(task));
  }

  async addTask(task: Task): Promise<void> {
    this.tasks.unshift(task);
    await this.save();
    if (task.reminderId) {
      await this.syncReminderAutoTasks(Date.now(), task.reminderId);
    }
  }

  async updateTask(task: Task): Promise<void> {
    const index: number = this.tasks.findIndex((t: Task) => t.id === task.id);
    if (index !== -1) {
      const previousTask = Task.fromJSON(JSON.parse(JSON.stringify(this.tasks[index])) as TaskData);
      task.updatedAt = Date.now();
      this.tasks[index] = task;
      await this.save();
      await this.syncReminderAfterTaskMutation(previousTask, task);
    }
  }

  async deleteTask(taskId: string): Promise<void> {
    const task = this.tasks.find((item: Task) => item.id === taskId);
    this.tasks = this.tasks.filter((t: Task) => t.id !== taskId);
    await this.save();
    if (task?.reminderId) {
      await this.syncReminderAutoTasks(Date.now(), task.reminderId);
    }
  }

  async setTaskCompletion(taskId: string, completed: boolean): Promise<Task | null> {
    const index: number = this.tasks.findIndex((task: Task) => task.id === taskId);
    if (index === -1) {
      return null;
    }

    const currentTask = Task.fromJSON(JSON.parse(JSON.stringify(this.tasks[index])) as TaskData);
    const wasCompleted = currentTask.status === TaskStatus.COMPLETED;
    if (wasCompleted === completed) {
      return currentTask;
    }

    if (completed) {
      currentTask.complete();
    } else {
      currentTask.uncomplete();
      if (currentTask.reminderId && currentTask.isReminderAutoGenerated && currentTask.reminderOccurrenceTime !== undefined) {
        this.removeFuturePendingAutoTasks(currentTask.reminderId, currentTask.reminderOccurrenceTime);
      }
    }

    this.tasks[index] = currentTask;
    await this.save();

    if (currentTask.reminderId) {
      await this.syncReminderAutoTasks(Date.now(), currentTask.reminderId);
    }

    return Task.fromJSON(JSON.parse(JSON.stringify(currentTask)) as TaskData);
  }

  async addPomodoro(pomodoro: Pomodoro): Promise<void> {
    this.pomodoros.unshift(pomodoro);
    await this.savePomodoros();
  }

  async updatePomodoro(pomodoro: Pomodoro): Promise<void> {
    const index: number = this.pomodoros.findIndex((p: Pomodoro) => p.id === pomodoro.id);
    if (index !== -1) {
      this.pomodoros[index] = pomodoro;
      await this.savePomodoros();
    }
  }

  getCompletedPomodorosByTaskId(taskId: string): Pomodoro[] {
    return this.clonePomodoros(this.pomodoros.filter((p: Pomodoro) => p.taskId === taskId && p.completed));
  }

  getPomodorosByTaskId(taskId: string): Pomodoro[] {
    return this.clonePomodoros(this.pomodoros.filter((p: Pomodoro) => p.taskId === taskId));
  }

  getAllPomodoros(): Pomodoro[] {
    return this.clonePomodoros(this.pomodoros);
  }

  getAllDayEvents(): DayEvent[] {
    const eventsJson: string = JSON.stringify(this.dayEvents);
    const eventsData: DayEventData[] = JSON.parse(eventsJson) as DayEventData[];
    return eventsData.map((event: DayEventData) => DayEvent.fromJSON(event));
  }

  getDayEventById(id: string): DayEvent | undefined {
    const event = this.dayEvents.find((item: DayEvent) => item.id === id);
    if (!event) {
      return undefined;
    }

    const eventJson: string = JSON.stringify(event);
    const eventData: DayEventData = JSON.parse(eventJson) as DayEventData;
    return DayEvent.fromJSON(eventData);
  }

  getDayEventsByGoalId(goalId: string): DayEvent[] {
    const matchedEvents = this.dayEvents.filter((event: DayEvent) => event.goalId === goalId);
    const eventsJson: string = JSON.stringify(matchedEvents);
    const eventsData: DayEventData[] = JSON.parse(eventsJson) as DayEventData[];
    return eventsData.map((event: DayEventData) => DayEvent.fromJSON(event));
  }

  getDayEventsByKrId(krId: string): DayEvent[] {
    const matchedEvents = this.dayEvents.filter((event: DayEvent) => event.krId === krId);
    const eventsJson: string = JSON.stringify(matchedEvents);
    const eventsData: DayEventData[] = JSON.parse(eventsJson) as DayEventData[];
    return eventsData.map((event: DayEventData) => DayEvent.fromJSON(event));
  }

  getDayEventsByDate(date: number): DayEvent[] {
    const matchedEvents = getEventsForDate(this.dayEvents, date);
    const eventsJson: string = JSON.stringify(matchedEvents);
    const eventsData: DayEventData[] = JSON.parse(eventsJson) as DayEventData[];
    return eventsData.map((event: DayEventData) => DayEvent.fromJSON(event));
  }

  getDayEventsByType(type: string): DayEvent[] {
    return this.cloneDayEvents(this.dayEvents.filter((d: DayEvent) => d.type === type));
  }

  async addDayEvent(event: DayEvent): Promise<void> {
    this.dayEvents.unshift(event);
    await this.saveDayEvents();
    await this.syncReminderAutoTasks(Date.now(), event.id);
  }

  async updateDayEvent(event: DayEvent): Promise<void> {
    const index: number = this.dayEvents.findIndex((d: DayEvent) => d.id === event.id);
    if (index !== -1) {
      event.updatedAt = Date.now();
      this.dayEvents[index] = event;
      await this.saveDayEvents();
      await this.syncReminderAutoTasks(Date.now(), event.id);
    }
  }
  async deleteDayEvent(id: string): Promise<void> {
    this.dayEvents = this.dayEvents.filter((d: DayEvent) => d.id !== id);
    this.tasks = this.tasks
      .filter((task: Task) => !(task.reminderId === id && task.isReminderAutoGenerated))
      .map((task: Task) => {
        if (task.reminderId !== id) {
          return task;
        }
        const updatedTask = Task.fromJSON(JSON.parse(JSON.stringify(task)) as TaskData);
        updatedTask.reminderId = undefined;
        updatedTask.reminderTitle = undefined;
        updatedTask.isReminderAutoGenerated = false;
        updatedTask.reminderOccurrenceTime = undefined;
        return updatedTask;
      });
    await this.saveDayEvents();
    await this.save();
  }

  async pauseDayEventOnce(eventId: string, nextOccurrence: number): Promise<void> {
    const event = this.dayEvents.find((d: DayEvent) => d.id === eventId);
    if (event) {
      event.skipOnceUntil = nextOccurrence + 24 * 60 * 60 * 1000; // 暂停到下一次提醒后一天
      event.updatedAt = Date.now();
      await this.saveDayEvents();
      await this.syncReminderAutoTasks(Date.now(), eventId);
    }
  }

  async pauseDayEventIndefinitely(eventId: string): Promise<void> {
    const event = this.dayEvents.find((d: DayEvent) => d.id === eventId);
    if (event) {
      event.isEnabled = false;
      event.updatedAt = Date.now();
      await this.saveDayEvents();
      await this.syncReminderAutoTasks(Date.now(), eventId);
    }
  }

  async resumeDayEvent(eventId: string): Promise<void> {
    const event = this.dayEvents.find((d: DayEvent) => d.id === eventId);
    if (event) {
      event.isEnabled = true;
      event.isCompleted = false;
      event.skipOnceUntil = undefined;
      event.updatedAt = Date.now();
      await this.saveDayEvents();
      await this.syncReminderAutoTasks(Date.now(), eventId);
    }
  }

  async endDayEvent(eventId: string): Promise<void> {
    const event = this.dayEvents.find((d: DayEvent) => d.id === eventId);
    if (event) {
      event.isCompleted = true;
      event.isEnabled = false;
      event.updatedAt = Date.now();
      await this.saveDayEvents();
      await this.syncReminderAutoTasks(Date.now(), eventId);
    }
  }

  async completeDayEventOccurrence(eventId: string, referenceTime: number = Date.now()): Promise<boolean> {
    const event = this.dayEvents.find((item: DayEvent) => item.id === eventId);
    if (!event) {
      return false;
    }

    const candidate = getReminderCompletionCandidate(event, this.tasks, referenceTime);
    if (!candidate) {
      return false;
    }

    // 如果已有关联的 pending auto task（历史遗留），直接完成它
    let task = candidate.task;
    if (task) {
      if (task.status !== TaskStatus.COMPLETED) {
        task.complete();
        if (candidate.occurrenceTime) {
          task.reminderOccurrenceTime = candidate.occurrenceTime;
        }
      }
      await this.save();
      await this.syncReminderAutoTasks(referenceTime, eventId);
      return true;
    }

    // 新逻辑：创建一条已完成的记录任务（仅用于完成追踪，不再创建 pending 任务）
    const occurrenceTime = candidate.occurrenceTime || referenceTime;
    const completionTask = createReminderAutoTask(event, {
      occurrenceTime,
      dueDate: occurrenceTime,
      summary: '本次提醒'
    });
    completionTask.complete();
    this.tasks.unshift(completionTask);

    await this.save();
    await this.syncReminderAutoTasks(referenceTime, eventId);
    return true;
  }

  async unlinkDayEventsFromKeyResult(goalId: string, krId: string): Promise<void> {
    const changed = this.clearDayEventKeyResultLinks(goalId, krId);
    if (!changed) {
      return;
    }

    await this.saveDayEvents();
  }

  private async syncReminderAfterTaskMutation(previousTask: Task, nextTask: Task): Promise<void> {
    const affectedReminderIds: string[] = [];
    if (previousTask.reminderId && !affectedReminderIds.includes(previousTask.reminderId)) {
      affectedReminderIds.push(previousTask.reminderId);
    }
    if (nextTask.reminderId && !affectedReminderIds.includes(nextTask.reminderId)) {
      affectedReminderIds.push(nextTask.reminderId);
    }

    let removedFutureTasks = false;
    if (previousTask.status === TaskStatus.COMPLETED &&
      nextTask.status !== TaskStatus.COMPLETED &&
      previousTask.reminderId &&
      previousTask.isReminderAutoGenerated &&
      previousTask.reminderOccurrenceTime !== undefined) {
      removedFutureTasks = this.removeFuturePendingAutoTasks(previousTask.reminderId, previousTask.reminderOccurrenceTime);
    }

    if (removedFutureTasks) {
      await this.save();
    }

    for (const reminderId of affectedReminderIds) {
      await this.syncReminderAutoTasks(Date.now(), reminderId);
    }
  }

  private removeFuturePendingAutoTasks(reminderId: string, occurrenceTime: number): boolean {
    const nextTasks = this.tasks.filter((task: Task) => {
      if (task.reminderId !== reminderId || !this.isReminderGeneratedPendingTask(task)) {
        return true;
      }
      return (task.reminderOccurrenceTime || 0) <= occurrenceTime;
    });

    if (nextTasks.length === this.tasks.length) {
      return false;
    }

    this.tasks = nextTasks;
    return true;
  }

  async syncReminderAutoTasks(referenceTime: number = Date.now(), eventId?: string): Promise<void> {
    const targetEvents = eventId
      ? this.dayEvents.filter((event: DayEvent) => event.id === eventId)
      : this.dayEvents;

    let changed = false;

    for (const event of targetEvents) {
      changed = this.syncReminderLinkedTaskTitles(event) || changed;

      // 清理所有 pending 的自动任务（不再自动创建新的）
      const pendingAutoTasks = this.tasks
        .filter((task: Task) => task.reminderId === event.id && this.isReminderGeneratedPendingTask(task));

      if (pendingAutoTasks.length > 0) {
        const beforeCount = this.tasks.length;
        this.tasks = this.tasks.filter((task: Task) => {
          return !(task.reminderId === event.id && this.isReminderGeneratedPendingTask(task));
        });
        changed = changed || beforeCount !== this.tasks.length;
      }
    }

    if (changed) {
      await this.save();
    }

    const eventChanged = autoCompleteExpirations(this.dayEvents, this.tasks);
    if (eventChanged) {
      await this.saveDayEvents();
    }
  }

  private syncReminderLinkedTaskTitles(event: DayEvent): boolean {
    let changed = false;
    this.tasks.forEach((task: Task) => {
      if (task.reminderId !== event.id) {
        return;
      }

      if (task.reminderTitle !== event.title) {
        task.reminderTitle = event.title;
        changed = true;
      }
      
      if (task.isReminderAutoGenerated) {
        if (task.goalId !== (event.goalId || '')) {
          task.goalId = event.goalId || '';
          changed = true;
        }
        if (task.goalTitle !== (event.goalTitle || '')) {
          task.goalTitle = event.goalTitle || '';
          changed = true;
        }
        if (task.krId !== event.krId) {
          task.krId = event.krId;
          changed = true;
        }
        if (task.krTitle !== event.krTitle) {
          task.krTitle = event.krTitle;
          changed = true;
        }
      }

      if (changed) {
        task.updatedAt = Date.now();
      }
    });
    return changed;
  }

  private isReminderGeneratedPendingTask(task: Task): boolean {
    if (task.status === TaskStatus.COMPLETED || !task.reminderId) {
      return false;
    }
    if (task.isReminderAutoGenerated || task.reminderOccurrenceTime !== undefined) {
      return true;
    }
    return (task.description || '').startsWith('来自提醒：');
  }

  private syncDayEventGoalLinks(goal: Goal): boolean {
    let changed = false;
    this.dayEvents.forEach((event: DayEvent) => {
      if (event.goalId !== goal.id) {
        return;
      }

      if (event.goalTitle !== goal.title) {
        event.goalTitle = goal.title;
        event.updatedAt = Date.now();
        changed = true;
      }

      if (!event.krId) {
        return;
      }

      const linkedKr = goal.keyResults.find((kr: KeyResult) => kr.id === event.krId);
      if (!linkedKr) {
        event.krId = undefined;
        event.krTitle = undefined;
        event.updatedAt = Date.now();
        changed = true;
        return;
      }

      if (event.krTitle !== linkedKr.title) {
        event.krTitle = linkedKr.title;
        event.updatedAt = Date.now();
        changed = true;
      }
    });
    return changed;
  }

  private clearDayEventGoalLinks(goalId: string): boolean {
    let changed = false;
    this.dayEvents.forEach((event: DayEvent) => {
      if (event.goalId !== goalId) {
        return;
      }

      event.goalId = undefined;
      event.goalTitle = undefined;
      event.krId = undefined;
      event.krTitle = undefined;
      event.updatedAt = Date.now();
      changed = true;
    });
    return changed;
  }

  private clearDayEventKeyResultLinks(goalId: string, krId: string): boolean {
    let changed = false;
    this.dayEvents.forEach((event: DayEvent) => {
      if (event.goalId !== goalId || event.krId !== krId) {
        return;
      }

      event.krId = undefined;
      event.krTitle = undefined;
      event.updatedAt = Date.now();
      changed = true;
    });
    return changed;
  }

  private async saveDayEvents(): Promise<void> {
    if (!this.prefs) {
      logger.error('Preferences not initialized');
      return;
    }

    try {
      const dayEventsJson: string = JSON.stringify(this.dayEvents);
      this.prefs.put(DAY_EVENTS_KEY, dayEventsJson);
      await this.prefs.flush();
      logger.debug('DayEvents saved successfully');
      this.notifyDataChanged();
    } catch (error) {
      logger.error('DayEvents save error', error as Object);
    }
  }

  private async savePomodoros(): Promise<void> {
    if (!this.prefs) {
      logger.error('Preferences not initialized');
      return;
    }

    try {
      const pomodorosJson: string = JSON.stringify(this.pomodoros);
      this.prefs.put(POMODOROS_KEY, pomodorosJson);
      await this.prefs.flush();
      logger.debug('Pomodoros saved successfully');
    } catch (error) {
      logger.error('Pomodoros save error', error as Object);
    }
  }

  private async save(): Promise<void> {
    if (!this.prefs) {
      logger.error('Preferences not initialized');
      return;
    }

    try {
      logger.debug('save:', this.goals.length, 'goals,', this.tasks.length, 'tasks');
      this.goals.forEach((goal: Goal, index: number) => {
        logger.debug(`  Goal[${index}]: id=${goal.id}, keyResults=${goal.keyResults?.length || 0}, progress=${goal.progress}`);
      });
      const goalsJson: string = JSON.stringify(this.goals);
      const tasksJson: string = JSON.stringify(this.tasks);
      this.prefs.put(GOALS_KEY, goalsJson);
      this.prefs.put(TASKS_KEY, tasksJson);
      await this.prefs.flush();
      logger.debug('Database saved successfully');
      
      // 同步数据到全局状态
      dataSyncService.setGoals(this.goals);
      dataSyncService.setTasks(this.tasks);

      if (this.context) {
        widgetRefreshService.refreshAllWidgets();
      }
      
      this.notifyDataChanged();
    } catch (error) {
      logger.error('Database save error', error as Object);
    }
  }
}

export const db: Database = Database.getInstance();
