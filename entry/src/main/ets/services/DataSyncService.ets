
import { Goal, GoalData, KeyResult, KeyResultData } from '../models/Goal';
import { Task, TaskData } from '../models/Task';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('DataSyncService');

export class DataSyncService {
  private static instance: DataSyncService;
  private goals: Goal[] = [];
  private tasks: Task[] = [];
  private listeners: Array<() => void> = [];

  private constructor() {}

  static getInstance(): DataSyncService {
    if (!DataSyncService.instance) {
      DataSyncService.instance = new DataSyncService();
    }
    return DataSyncService.instance;
  }

  private cloneGoal(goal: Goal): Goal {
    return Goal.fromJSON(JSON.parse(JSON.stringify(goal)) as GoalData);
  }

  private cloneTask(task: Task): Task {
    return Task.fromJSON(JSON.parse(JSON.stringify(task)) as TaskData);
  }

  private cloneGoals(goals: Goal[]): Goal[] {
    return goals.map((goal: Goal) => this.cloneGoal(goal));
  }

  private cloneTasks(tasks: Task[]): Task[] {
    return tasks.map((task: Task) => this.cloneTask(task));
  }

  setGoals(goals: Goal[]): void {
    this.goals = this.cloneGoals(goals);
    this.notifyListeners();
  }
  setTasks(tasks: Task[]): void {
    this.tasks = this.cloneTasks(tasks);
    this.notifyListeners();
  }
  getGoals(): Goal[] {
    return this.cloneGoals(this.goals);
  }
  getTasks(): Task[] {
    return this.cloneTasks(this.tasks);
  }
  updateGoal(updatedGoal: Goal): void {
    const index = this.goals.findIndex(g => g.id === updatedGoal.id);
    const goalCopy = this.cloneGoal(updatedGoal);
    
    // 创建新数组以确保触发响应式更新
    const newGoals = this.goals.slice();
    
    if (index !== -1) {
      // 目标已存在：直接赋值
      newGoals[index] = goalCopy;
    } else {
      // 目标不存在：添加它
      newGoals.push(goalCopy);
    }
    
    this.goals = newGoals;
    this.notifyListeners();
  }
  updateTask(updatedTask: Task): void {
    const index = this.tasks.findIndex(t => t.id === updatedTask.id);
    const taskCopy = this.cloneTask(updatedTask);
    
    // 创建新数组以确保触发响应式更新
    const newTasks = this.tasks.slice();
    
    if (index !== -1) {
      // 任务已存在：直接赋值
      newTasks[index] = taskCopy;
    } else {
      // 任务不存在：添加它
      newTasks.push(taskCopy);
    }
    
    this.tasks = newTasks;
    this.notifyListeners();
  }

  addListener(listener: () => void): void {
    this.listeners.push(listener);
  }

  removeListener(listener: () => void): void {
    const index = this.listeners.indexOf(listener);
    if (index !== -1) {
      this.listeners.splice(index, 1);
    } else {
      logger.warn('DataSyncService.removeListener: listener not found');
    }
  }

  private notifyListeners(): void {
    this.listeners.forEach((listener) => {
      try {
        listener();
      } catch (error) {
        logger.error('DataSyncService listener error', error as Object);
      }
    });
  }
}

export const dataSyncService = DataSyncService.getInstance();
