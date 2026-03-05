import dataPreferences from '@ohos.data.preferences';
import { Goal } from '../models/Goal';
import { Task, TaskStatus } from '../models/Task';

const PREFERENCES_NAME: string = 'life_goal_storage';
const GOALS_KEY: string = 'goals';
const TASKS_KEY: string = 'tasks';

export class Database {
  private static instance: Database;
  private goals: Goal[] = [];
  private tasks: Task[] = [];
  private prefs: dataPreferences.Preferences | null = null;

  private constructor() {}

  static getInstance(): Database {
    if (!Database.instance) {
      Database.instance = new Database();
    }
    return Database.instance;
  }

  async initialize(context: Context): Promise<void> {
    try {
      this.prefs = await dataPreferences.getPreferences(context, PREFERENCES_NAME);
      const goalsValue: dataPreferences.ValueType = await this.prefs.get(GOALS_KEY, '[]');
      const tasksValue: dataPreferences.ValueType = await this.prefs.get(TASKS_KEY, '[]');
      const goalsJson: string = goalsValue as string;
      const tasksJson: string = tasksValue as string;
      
      // 解析并恢复 Goal 实例
      const goalsData = JSON.parse(goalsJson);
      this.goals = goalsData.map((g: any) => Goal.fromJSON(g));
      
      // 解析并恢复 Task 实例
      const tasksData = JSON.parse(tasksJson);
      this.tasks = tasksData.map((t: any) => Task.fromJSON(t));
      
      console.info('Database initialized successfully');
    } catch (error) {
      console.error('Database initialize error:', JSON.stringify(error));
      this.goals = [];
      this.tasks = [];
    }
  }

  // Goal 相关方法
  getAllGoals(): Goal[] {
    return this.goals;
  }

  getGoalById(goalId: string): Goal | undefined {
    return this.goals.find((g: Goal) => g.id === goalId);
  }

  async addGoal(goal: Goal): Promise<void> {
    this.goals.unshift(goal);
    await this.save();
  }

  async updateGoal(goal: Goal): Promise<void> {
    const index: number = this.goals.findIndex((g: Goal) => g.id === goal.id);
    if (index !== -1) {
      goal.updatedAt = Date.now();
      this.goals[index] = goal;
      await this.save();
    }
  }

  async deleteGoal(goalId: string): Promise<void> {
    this.goals = this.goals.filter((g: Goal) => g.id !== goalId);
    await this.save();
  }

  // Task 相关方法
  getAllTasks(): Task[] {
    return this.tasks;
  }

  getTasksByGoalId(goalId: string): Task[] {
    return this.tasks.filter((t: Task) => t.goalId === goalId);
  }

  getTaskById(taskId: string): Task | undefined {
    return this.tasks.find((t: Task) => t.id === taskId);
  }

  getPendingTasks(): Task[] {
    return this.tasks.filter((t: Task) => t.status === 'pending');
  }

  getCompletedTasks(): Task[] {
    return this.tasks.filter((t: Task) => t.status === 'completed');
  }

  async addTask(task: Task): Promise<void> {
    this.tasks.unshift(task);
    await this.save();
  }

  async updateTask(task: Task): Promise<void> {
    const index: number = this.tasks.findIndex((t: Task) => t.id === task.id);
    if (index !== -1) {
      task.updatedAt = Date.now();
      this.tasks[index] = task;
      await this.save();
    }
  }

  async deleteTask(taskId: string): Promise<void> {
    this.tasks = this.tasks.filter((t: Task) => t.id !== taskId);
    await this.save();
  }

  private async save(): Promise<void> {
    if (!this.prefs) {
      console.error('Preferences not initialized');
      return;
    }

    try {
      const goalsJson: string = JSON.stringify(this.goals);
      const tasksJson: string = JSON.stringify(this.tasks);
      this.prefs.put(GOALS_KEY, goalsJson);
      this.prefs.put(TASKS_KEY, tasksJson);
      await this.prefs.flush();
      console.info('Database saved successfully');
    } catch (error) {
      console.error('Database save error:', JSON.stringify(error));
    }
  }
}

export const db: Database = Database.getInstance();