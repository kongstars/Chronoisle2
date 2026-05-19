
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
  setGoals(goals: Goal[]): void {
    // 直接赋值，因为Goal和Task是引用类型
    this.goals = goals;
    this.notifyListeners();
  }
  setTasks(tasks: Task[]): void {
    // 直接赋值，因为Goal和Task是引用类型
    this.tasks = tasks;
    this.notifyListeners();
  }
  getGoals(): Goal[] {
    // 直接返回原数组，因为ArkTS不支持对象展开
    return this.goals;
  }
  getTasks(): Task[] {
    // 直接返回原数组，因为ArkTS不支持对象展开
    return this.tasks;
  }
  updateGoal(updatedGoal: Goal): void {
    const index = this.goals.findIndex(g => g.id === updatedGoal.id);
    
    // 创建新数组以确保触发响应式更新
    const newGoals = this.goals.slice();
    
    if (index !== -1) {
      // 目标已存在：直接赋值
      newGoals[index] = updatedGoal;
    } else {
      // 目标不存在：添加它
      newGoals.push(updatedGoal);
    }
    
    this.goals = newGoals;
    this.notifyListeners();
  }
  updateTask(updatedTask: Task): void {
    const index = this.tasks.findIndex(t => t.id === updatedTask.id);
    
    // 创建新数组以确保触发响应式更新
    const newTasks = this.tasks.slice();
    
    if (index !== -1) {
      // 任务已存在：直接赋值
      newTasks[index] = updatedTask;
    } else {
      // 任务不存在：添加它
      newTasks.push(updatedTask);
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