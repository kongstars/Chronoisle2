// 目标分类枚举（8 大生活维度）
export enum GoalCategory {
  CAREER = '事业',
  HEALTH = '健康',
  LEARNING = '学习',
  FINANCE = '理财',
  SOCIAL = '社交',
  FAMILY = '家庭',
  GROWTH = '成长',
  FUN = '娱乐'
}

// 关键结果模型
export class KeyResult {
  id: string;
  title: string;
  progress: number;
  completed: boolean;
  createdAt: number;
  
  constructor(title: string) {
    this.id = this.generateId();
    this.title = title;
    this.progress = 0;
    this.completed = false;
    this.createdAt = Date.now();
  }
  
  private generateId(): string {
    return 'kr_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }
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
  
  constructor(title: string, category: GoalCategory, description: string = '') {
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
  }
  
  private generateId(): string {
    return 'goal_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }
  
  calculateProgress(): number {
    if (this.keyResults.length === 0) {
      return 0;
    }
    const total: number = this.keyResults.reduce((sum: number, kr: KeyResult) => sum + kr.progress, 0);
    return Math.round(total / this.keyResults.length);
  }
  
  addKeyResult(title: string): KeyResult {
    const kr: KeyResult = new KeyResult(title);
    this.keyResults.push(kr);
    this.updateProgress();
    return kr;
  }
  
  updateProgress(): void {
    this.progress = this.calculateProgress();
    this.updatedAt = Date.now();
  }
  
  removeKeyResult(krId: string): void {
    this.keyResults = this.keyResults.filter((kr: KeyResult) => kr.id !== krId);
    this.updateProgress();
  }
  
  // 从 JSON 恢复为 Goal 实例（解决反序列化后方法丢失的问题）
  static fromJSON(json: any): Goal {
    const goal = new Goal(json.title, json.category, json.description);
    goal.id = json.id;
    goal.keyResults = json.keyResults ? json.keyResults.map((kr: any) => {
      const keyResult = new KeyResult(kr.title);
      keyResult.id = kr.id;
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
    return goal;
  }
}
