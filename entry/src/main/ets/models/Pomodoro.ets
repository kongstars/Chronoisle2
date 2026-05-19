export interface PomodoroData {
  id: string;
  taskId: string;
  taskTitle: string;
  duration: number;
  startTime: number;
  endTime?: number;
  completed: boolean;
  createdAt: number;
  roundIndex?: number;
  totalRounds?: number;
  breakDuration?: number;
}

export class Pomodoro {
  id: string;
  taskId: string;
  taskTitle: string;
  duration: number;
  startTime: number;
  endTime?: number;
  completed: boolean;
  createdAt: number;
  roundIndex: number;
  totalRounds: number;
  breakDuration: number;

  constructor(taskId: string, taskTitle: string, duration: number) {
    this.id = this.generateId();
    this.taskId = taskId;
    this.taskTitle = taskTitle;
    this.duration = duration;
    this.startTime = Date.now();
    this.endTime = undefined;
    this.completed = false;
    this.createdAt = Date.now();
    this.roundIndex = 1;
    this.totalRounds = 1;
    this.breakDuration = 5;
  }

  private generateId(): string {
    return 'pomodoro_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
  }

  complete(): void {
    this.endTime = Date.now();
    this.completed = true;
  }

  get actualDuration(): number {
    if (this.endTime) {
      return Math.round((this.endTime - this.startTime) / 60000);
    }
    return this.duration;
  }

  static fromJSON(json: PomodoroData): Pomodoro {
    const pomodoro = new Pomodoro(json.taskId, json.taskTitle, json.duration);
    pomodoro.id = json.id;
    pomodoro.startTime = json.startTime;
    pomodoro.endTime = json.endTime;
    pomodoro.completed = json.completed;
    pomodoro.createdAt = json.createdAt;
    pomodoro.roundIndex = json.roundIndex || 1;
    pomodoro.totalRounds = json.totalRounds || 1;
    pomodoro.breakDuration = json.breakDuration || 5;
    return pomodoro;
  }
}