export enum DayEventType {
  SINGLE = 'single',
  PERIODIC = 'periodic',
  HABIT = 'habit',
  MILESTONE = 'milestone',
  COUNTER = 'counter',
  COUNTDOWN = 'countdown'
}

export enum ReminderType {
  SINGLE_AT = 'single_at',
  PERIODIC_DAILY = 'periodic_daily',
  PERIODIC_WEEKLY = 'periodic_weekly',
  PERIODIC_MONTHLY = 'periodic_monthly',
  PERIODIC_MONTHLY_LAST_DAY = 'periodic_monthly_last_day',
  PERIODIC_INTERVAL = 'periodic_interval',
  HABIT_DAILY = 'habit_daily',
  HABIT_WEEKLY_TARGET = 'habit_weekly_target',
  HABIT_MONTHLY_TARGET = 'habit_monthly_target',
  MILESTONE_LEAD = 'milestone_lead',
  COUNTER_INTERVAL = 'counter_interval',
  COUNTER_DATE = 'counter_date'
}

export enum CounterUnit {
  DAY = 'day',
  MONTH = 'month',
  YEAR = 'year'
}

export interface ReminderRule {
  id?: string;
  type: ReminderType;
  hour?: number;
  minute?: number;
  weekday?: number;
  dayOfMonth?: number;
  lastDayOffset?: number;
  intervalDays?: number;
  leadDays?: number;
  targetDate?: number;
  offsetValue?: number;
  offsetUnit?: CounterUnit;
  targetCount?: number;
  timesPerPeriod?: number;
}

export interface DayEventData {
  id: string;
  title: string;
  description?: string;
  type: DayEventType;
  startDate: number;
  endDate?: number;
  targetDate?: number;
  counterStartDate?: number;
  goalId?: string;
  goalTitle?: string;
  krId?: string;
  krTitle?: string;
  reminderRules: ReminderRule[];
  isEnabled: boolean;
  skipOnceUntil?: number;
  isCompleted: boolean;
  linkedTaskId?: string;
  linkedTaskTitle?: string;
  updatedAt: number;
  createdAt: number;
}

export class DayEvent implements DayEventData {
  id: string = 'event_' + Date.now() + '_' + Math.random().toString(36).slice(2, 8);
  title: string;
  description?: string = '';
  type: DayEventType;
  startDate: number;
  endDate?: number = undefined;
  targetDate?: number = undefined;
  counterStartDate?: number = undefined;
  goalId?: string = undefined;
  goalTitle?: string = undefined;
  krId?: string = undefined;
  krTitle?: string = undefined;
  reminderRules: ReminderRule[] = [];
  isEnabled: boolean = true;
  skipOnceUntil?: number = undefined;
  isCompleted: boolean = false;
  linkedTaskId?: string = undefined;
  linkedTaskTitle?: string = undefined;
  updatedAt: number = Date.now();
  createdAt: number = Date.now();

  constructor(title: string, type: DayEventType = DayEventType.PERIODIC, startDate: number = Date.now()) {
    this.title = title;
    this.type = type;
    this.startDate = startDate;
  }

  addReminderRule(rule: ReminderRule): void {
    this.reminderRules = [...this.reminderRules, rule];
    this.updatedAt = Date.now();
  }

  toJSON(): DayEventData {
    return {
      id: this.id,
      title: this.title,
      description: this.description,
      type: this.type,
      startDate: this.startDate,
      endDate: this.endDate,
      targetDate: this.targetDate,
      counterStartDate: this.counterStartDate,
      goalId: this.goalId,
      goalTitle: this.goalTitle,
      krId: this.krId,
      krTitle: this.krTitle,
      reminderRules: this.reminderRules,
      isEnabled: this.isEnabled,
      skipOnceUntil: this.skipOnceUntil,
      isCompleted: this.isCompleted,
      linkedTaskId: this.linkedTaskId,
      linkedTaskTitle: this.linkedTaskTitle,
      updatedAt: this.updatedAt,
      createdAt: this.createdAt
    };
  }

  static fromJSON(data: DayEventData): DayEvent {
    const event = new DayEvent(data.title, data.type, data.startDate);
    event.id = data.id;
    event.description = data.description;
    event.endDate = data.endDate;
    event.targetDate = data.targetDate;
    event.counterStartDate = data.counterStartDate;
    event.goalId = data.goalId;
    event.goalTitle = data.goalTitle;
    event.krId = data.krId;
    event.krTitle = data.krTitle;
    event.reminderRules = data.reminderRules || [];
    // 兼容旧版本提醒数据：缺少布尔字段时按“启用且未完成”处理，避免被提醒中心过滤掉
    event.isEnabled = data.isEnabled ?? true;
    event.skipOnceUntil = data.skipOnceUntil;
    event.isCompleted = data.isCompleted ?? false;
    event.linkedTaskId = data.linkedTaskId;
    event.linkedTaskTitle = data.linkedTaskTitle;
    event.updatedAt = data.updatedAt ?? Date.now();
    event.createdAt = data.createdAt ?? event.updatedAt;
    return event;
  }
}

export function getEventTypeIcon(type: DayEventType): string {
  switch (type) {
    case DayEventType.SINGLE:
      return 'reminder';
    case DayEventType.HABIT:
      return 'habit';
    case DayEventType.MILESTONE:
      return 'milestone';
    case DayEventType.COUNTER:
      return 'counter';
    case DayEventType.COUNTDOWN:
      return 'countdown';
    default:
      return 'reminder';
  }
}

export function getEventTypeLabel(type: DayEventType): string {
  switch (type) {
    case DayEventType.SINGLE:
      return '单次提醒';
    case DayEventType.HABIT:
      return '习惯';
    case DayEventType.MILESTONE:
      return '重要日子';
    case DayEventType.COUNTER:
      return '纪念日';
    case DayEventType.COUNTDOWN:
      return '倒计时';
    default:
      return '周期提醒';
  }
}
