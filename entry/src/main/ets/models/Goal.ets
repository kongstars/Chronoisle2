// 目标分类枚举（4 大生活维度）
export enum GoalCategory {
  HEALTH = '健康',
  LEARNING = '成长',
  FINANCE = '理财',
  FUN = '快乐'
}

// 关键结果模型
export class KeyResult {
  id: string;
  title: string;
  targetValue: number;
  initialValue: number;
  currentValue: number;
  progress: number;
  completed: boolean;
  createdAt: number;

  constructor(title: string, targetValue: number = 100, initialValue: number = 0) {
    this.id = this.generateId();
    this.title = title;
    this.targetValue = targetValue;
    this.initialValue = initialValue;
    this.currentValue = initialValue;
    this.progress = 0;
    this.completed = false;
    this.createdAt = Date.now();
  }

  private generateId(): string {
    return 'kr_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }

  calculateProgress(): number {
    const denominator = this.targetValue - this.initialValue;
    if (denominator === 0) {
      return 0;
    }
    const numerator = this.currentValue - this.initialValue;
    const rawProgress = Math.abs(numerator / denominator) * 100;
    const targetDiff = Math.abs(this.targetValue - this.currentValue);
    const initialDiff = Math.abs(denominator);
    if (targetDiff > initialDiff) {
      return -Math.round(rawProgress);
    }
    return Math.round(rawProgress);
  }

  updateProgress(): void {
    this.progress = this.calculateProgress();
    this.completed = this.progress >= 100;
  }
}

// 关键结果纯数据接口（用于序列化）
export interface KeyResultData {
  id: string;
  title: string;
  targetValue: number;
  initialValue: number;
  currentValue: number;
  progress: number;
  completed: boolean;
  createdAt: number;
}

// 目标纯数据接口（用于序列化）
export interface GoalData {
  id: string;
  title: string;
  description: string;
  category: GoalCategory;
  keyResults: KeyResultData[];
  progress: number;
  startDate: number;
  endDate: number;
  createdAt: number;
  updatedAt: number;
  completedAt?: number;
  isPriority: boolean;
  isArchived?: boolean;
  archivedAt?: number;
}

// 目标模型
export class Goal {
  id: string;
  title: string;
  description: string;
  category: GoalCategory;
  keyResults: KeyResult[];
  progress: number;
  startDate: number;
  endDate: number;
  createdAt: number;
  updatedAt: number;
  completedAt?: number;
  isPriority: boolean;
  isArchived: boolean;
  archivedAt?: number;
  
  constructor(title: string, category: GoalCategory, description: string = '', isPriority: boolean = false) {
    this.id = this.generateId();
    this.title = title;
    this.description = description;
    this.category = category;
    this.keyResults = [];
    this.progress = 0;
    this.startDate = Date.now();
    this.endDate = Date.now() + 90 * 24 * 60 * 60 * 1000; // 默认 90 天
    this.createdAt = Date.now();
    this.updatedAt = Date.now();
    this.completedAt = undefined;
    this.isPriority = isPriority;
    this.isArchived = false;
    this.archivedAt = undefined;
  }
  
  private generateId(): string {
    return 'goal_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }
  
  calculateProgress(): number {
    if (this.keyResults.length === 0) {
      return 0;
    }
    const validKeyResults = this.keyResults.filter((kr: KeyResult) => kr.progress >= 0);
    if (validKeyResults.length === 0) {
      return 0;
    }
    const total: number = validKeyResults.reduce((sum: number, kr: KeyResult) => sum + kr.progress, 0);
    return Math.round(total / validKeyResults.length);
  }

  addKeyResult(title: string, targetValue: number = 100, initialValue: number = 0): KeyResult {
    const kr: KeyResult = new KeyResult(title, targetValue, initialValue);
    this.keyResults.push(kr);
    this.updateProgress();
    return kr;
  }
  
  updateProgress(): void {
    this.progress = this.calculateProgress();
    this.updatedAt = Date.now();
    if (this.progress >= 100) {
      if (!this.completedAt) {
        this.completedAt = this.updatedAt;
      }
    } else {
      this.completedAt = undefined;
    }
  }
  
  removeKeyResult(krId: string): void {
    this.keyResults = this.keyResults.filter((kr: KeyResult) => kr.id !== krId);
    this.updateProgress();
  }
  
  // 从 JSON 恢复为 Goal 实例（解决反序列化后方法丢失的问题）
  static fromJSON(json: GoalData): Goal {
    const goal: Goal = new Goal(json.title, json.category, json.description, json.isPriority ?? false);
    goal.id = json.id;
    goal.keyResults = json.keyResults ? json.keyResults.map((kr: KeyResultData) => {
      const keyResult: KeyResult = new KeyResult(kr.title, kr.targetValue ?? 100, kr.initialValue ?? 0);
      keyResult.id = kr.id;
      keyResult.currentValue = kr.currentValue ?? kr.initialValue ?? 0;
      keyResult.progress = kr.progress;
      keyResult.completed = kr.completed;
      keyResult.createdAt = kr.createdAt;
      return keyResult;
    }) : [];
    goal.progress = json.progress;
    goal.startDate = json.startDate;
    goal.endDate = json.endDate;
    goal.createdAt = json.createdAt;
    goal.updatedAt = json.updatedAt;
    goal.completedAt = json.completedAt;
    goal.isPriority = json.isPriority ?? false;
    goal.isArchived = json.isArchived ?? false;
    goal.archivedAt = json.archivedAt;
    return goal;
  }
}
