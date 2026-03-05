// 任务状态枚举
export enum TaskStatus {
  PENDING = 'pending',
  COMPLETED = 'completed'
}

// 任务模型
export class Task {
  id: string;
  title: string;
  description: string;
  goalId: string;
  goalTitle: string;
  krId?: string;
  krTitle?: string;
  dueDate?: number;
  status: TaskStatus;
  createdAt: number;
  completedAt?: number;
  updatedAt: number;

  constructor(title: string, goalId: string, goalTitle: string) {
    this.id = this.generateId();
    this.title = title;
    this.description = '';
    this.goalId = goalId;
    this.goalTitle = goalTitle;
    this.krId = undefined;
    this.krTitle = undefined;
    this.dueDate = undefined;
    this.status = TaskStatus.PENDING;
    this.createdAt = Date.now();
    this.completedAt = undefined;
    this.updatedAt = Date.now();
  }

  private generateId(): string {
    return 'task_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }

  complete(): void {
    this.status = TaskStatus.COMPLETED;
    this.completedAt = Date.now();
    this.updatedAt = Date.now();
  }

  uncomplete(): void {
    this.status = TaskStatus.PENDING;
    this.completedAt = undefined;
    this.updatedAt = Date.now();
  }
  
  // 计算是否逾期
  get isOverdue(): boolean {
    return this.dueDate !== undefined && this.dueDate < Date.now() && this.status !== TaskStatus.COMPLETED;
  }
  
  // 从 JSON 恢复为 Task 实例（解决反序列化后方法丢失的问题）
  static fromJSON(json: any): Task {
    const task = new Task(json.title, json.goalId, json.goalTitle);
    task.id = json.id;
    task.description = json.description;
    task.krId = json.krId;
    task.krTitle = json.krTitle;
    task.dueDate = json.dueDate;
    task.status = json.status;
    task.createdAt = json.createdAt;
    task.completedAt = json.completedAt;
    task.updatedAt = json.updatedAt;
    return task;
  }
}