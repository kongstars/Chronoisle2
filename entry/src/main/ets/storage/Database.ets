import dataPreferences from '@ohos.data.preferences';
import { Goal } from '../models/Goal';

const PREFERENCES_NAME: string = 'life_goal_storage';
const GOALS_KEY: string = 'goals';

export class Database {
  private static instance: Database;
  private goals: Goal[] = [];
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
      const value: dataPreferences.ValueType = await this.prefs.get(GOALS_KEY, '[]');
      const goalsJson: string = value as string;
      this.goals = JSON.parse(goalsJson);
      console.info('Database initialized successfully');
    } catch (error) {
      console.error('Database initialize error:', JSON.stringify(error));
      this.goals = [];
    }
  }
  
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
  
  private async save(): Promise<void> {
    if (!this.prefs) {
      console.error('Preferences not initialized');
      return;
    }
    
    try {
      const goalsJson: string = JSON.stringify(this.goals);
      this.prefs.put(GOALS_KEY, goalsJson);
      await this.prefs.flush();
      console.info('Database saved successfully');
    } catch (error) {
      console.error('Database save error:', JSON.stringify(error));
    }
  }
}

export const db: Database = Database.getInstance();
