// Widget 数据模型

// 任务数据（用于待办卡片）
export class WidgetTask {
  id: string = '';
  title: string = '';
  goalTitle?: string = undefined;
  dueDate?: number = undefined;
  isPinned: boolean = false;
  isOverdue: boolean = false;
}

// 习惯数据（用于习惯卡片）
export class WidgetHabit {
  id: string = '';
  title: string = '';
  isCompleted: boolean = false;
  currentCount: number = 0;
  targetCount: number = 1;
}

// 倒计时数据（用于倒计时卡片）
export type WidgetCountdownType = 'milestone' | 'countdown' | 'anniversary' | 'reminder';

export class WidgetCountdown {
  id: string = '';
  title: string = '';
  targetDate: number = 0;
  daysRemaining: number = 0;
  type: WidgetCountdownType = 'countdown';
}

// AI 今日计划数据
export class WidgetTodayPlan {
  title: string = '今日计划';
  tasks: WidgetPlanTask[] = [];
  generatedAt?: number = undefined;
  isAdopted: boolean = false;
}

export class WidgetPlanTask {
  id: string = '';
  title: string = '';
  timeSlot?: string = undefined;
  isCompleted: boolean = false;
}

// 专注数据
export class WidgetFocus {
  currentTask?: string = undefined;
  isFocusing: boolean = false;
  remainingSeconds: number = 0;
  totalFocusMinutes: number = 0;
}

// 统计数据
export class WidgetStats {
  focusMinutesToday: number = 0;
  tasksCompletedToday: number = 0;
  tasksTotalToday: number = 0;
  habitCompletedToday: number = 0;
  habitTotalToday: number = 0;
  weekFocusMinutes: number = 0;
  weekTasksCompleted: number = 0;
  currentStreak: number = 0;
}

// Main Widget 专用数据类型
export class MainWidgetTask {
  id: string = '';
  title: string = '';
  isCompleted: boolean = false;
  isOverdue: boolean = false;
}

export class MainWidgetCountdown {
  title: string = '';
  daysRemaining: number = 0;
}

// 表单数据类型
export class TodoWidgetData {
  tasks: WidgetTask[] = [];
  emptyMessage: string = '暂无待办，点击添加任务';
}

export class HabitWidgetData {
  habits: WidgetHabit[] = [];
  completedCount: number = 0;
  totalCount: number = 0;
  emptyMessage: string = '暂无习惯，点击添加';
}

export class CountdownWidgetData {
  countdowns: WidgetCountdown[] = [];
  emptyMessage: string = '暂无倒计时，点击添加';
}

export class TodayPlanWidgetData {
  plan: WidgetTodayPlan | null = null;
  emptyMessage: string = '暂无 AI 计划，点击生成';
}

export class FocusWidgetData {
  focus: WidgetFocus = new WidgetFocus();
  emptyMessage: string = '点击开始专注';
}

export class DashboardWidgetData {
  stats: WidgetStats = new WidgetStats();
}

export class VoiceWidgetData {
  promptText: string = '点击语音创建';
  isListening: boolean = false;
}

export class MainWidgetData {
  // AI 今日计划
  planSummary: string = '无计划';
  planTaskCount: number = 0;
  isPlanAdopted: boolean = false;

  // AI 今日计划任务
  tasks: MainWidgetTask[] = [];

  // 习惯打卡
  habitCompleted: number = 0;
  habitTotal: number = 0;

  // 倒计时
  countdownTitle: string = '';
  countdownDays: number = 0;

  // 专注状态
  isFocusing: boolean = false;
  focusRemainingMinutes: number = 0;

  // 其他
  refreshTime: string = '';
}

export class WidgetFormData extends TodoWidgetData {}
