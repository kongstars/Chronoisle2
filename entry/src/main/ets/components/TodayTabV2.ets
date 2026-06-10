/**
 * TodayTab V2 — 首页重构样板
 *
 * 设计方向：清新简洁 · 轻科技感 · 结构清晰 · 呼吸感
 *
 * 布局结构：
 * 1. 问候区（纯文字 + 日期，左对齐）
 * 2. 快速操作栏（4 个圆形图标按钮）
 * 3. 今日计划卡片（核心区域，最大视觉权重）
 * 4. 今日提醒（横向滚动小卡片）
 * 5. 目标统计（一行摘要，可跳转目标页）
 * 6. 逾期提示（仅在有逾期任务时显示）
 */

import { Goal, GoalCategory } from '../models/Goal';
import { Task, TaskStatus } from '../models/Task';
import { DayEvent, DayEventType } from '../models/DayEvent';
import { getDayEventOccurrenceTimeOnDate, getEventsForDate, isDayEventEnded, startOfDay } from '../common/DayEventUtils';
import { CATEGORIES, CategoryInfo } from '../common/Constants';
import type { SavedPlanTaskItem, SavedTodayPlan } from '../models/TodayPlan';
import type { UserAccount } from '../services/AuthService';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { db } from '../storage/Database';
import { dataSyncService } from '../services/DataSyncService';
import { AppIcon } from '../ui/base/AppIcon';
import { PAGE_PADDING, SPACE_CARD, SPACE_MD, SPACE_SM, SPACE_XS, SPACE_2XS } from '../foundation/tokens/SpacingTokens';
import { RADIUS_LG, RADIUS_MD, RADIUS_SM } from '../foundation/tokens/RadiusTokens';
import { TYPE_HERO_TITLE, TYPE_SECTION_TITLE, TYPE_BODY, TYPE_CAPTION, TYPE_META } from '../foundation/tokens/TypographyTokens';
import { BORDER_DEFAULT } from '../foundation/tokens/BorderTokens';

// ========== 设计 Token（V2 规范） ==========
const V2_QUICK_ACTION_SIZE: number = 44;

// ========== 接口 ==========

interface QuickAction {
  icon: string;
  label: string;
  action: () => void;
}

interface ReminderSnapshot {
  id: string;
  title: string;
  typeLabel: string;
  timeText: string;
  isDueNow: boolean;
  completedToday: boolean;
}

@Component
export struct TodayTabV2 {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop goals: Goal[] = [];
  @Prop tasks: Task[] = [];
  @Prop savedPlan: SavedTodayPlan | null = null;
  @Prop user: UserAccount | null = null;
  @Prop dayEvents: DayEvent[] = [];

  // 回调
  onCreateTask?: () => void;
  onCreateGoal?: () => void;
  onCreateReminder?: () => void;
  onStartFocus?: () => void;
  onOpenSearch?: () => void;
  onOpenTodayPlan?: () => void;
  onOpenGoalDetail?: (goalId: string) => void;
  onOpenGoalsTab?: () => void;
  onOpenReschedule?: () => void;
  onOpenReminderCenter?: () => void;
  onToggleTaskComplete?: (task: Task) => void;
  onOpenTaskDetail?: (taskId: string) => void;
  onCompleteReminder?: (eventId: string) => void;

  // ========== 数据计算 ==========

  private getGreeting(): string {
    const hour = new Date().getHours();
    if (hour < 6) return '夜深了，早点休息';
    if (hour < 9) return '早上好';
    if (hour < 12) return '上午好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    if (hour < 22) return '晚上好';
    return '夜深了';
  }

  private getDateText(): string {
    const now = new Date();
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${now.getMonth() + 1}月${now.getDate()}日 ${weekdays[now.getDay()]}`;
  }

  private getDisplayName(): string {
    if (this.user?.nickname) return this.user.nickname;
    if (this.user?.account) return this.user.account;
    return '';
  }

  private getPendingTasks(): Task[] {
    return this.tasks.filter((t: Task) => t.status === TaskStatus.PENDING);
  }

  private getOverdueTasks(): Task[] {
    const now = Date.now();
    return this.getPendingTasks().filter((t: Task) => {
      return t.dueDate !== undefined && t.dueDate < now;
    });
  }

  private getDayProgressPercent(): number {
    const now = new Date();
    const minutesPassed = now.getHours() * 60 + now.getMinutes();
    return Math.round((minutesPassed / 1440) * 100);
  }

  private getCompletedTodayCount(): number {
    const todayStart = startOfDay(Date.now());
    return this.tasks.filter((t: Task) => {
      return t.status === TaskStatus.COMPLETED && t.completedAt !== undefined && startOfDay(t.completedAt) === todayStart;
    }).length;
  }

  private getPlanFocusTasks(): SavedPlanTaskItem[] {
    if (!this.savedPlan || !this.savedPlan.focusTasks) return [];
    return this.savedPlan.focusTasks;
  }

  private hasActionableTodayPlan(): boolean {
    return this.getPlanFocusTasks().some((item: SavedPlanTaskItem) => item.type !== 'reminder');
  }

  private getActionablePlanTaskCount(): number {
    return this.getPlanFocusTasks().filter((item: SavedPlanTaskItem) => item.type !== 'reminder').length;
  }

  private getPlanFocusTasksDisplay(): SavedPlanTaskItem[] {
    return this.getPlanFocusTasks().slice(0, 7);
  }

  private getActiveGoals(): Goal[] {
    return this.goals.filter((g: Goal) => !g.isArchived && (g.progress || 0) < 100);
  }

  private getPriorityGoalsThisWeek(): Goal[] {
    return this.getActiveGoals().filter((g: Goal) => g.isPriority);
  }

  private getNearlyCompletedGoals(): Goal[] {
    return this.getActiveGoals().filter((g: Goal) => (g.progress || 0) >= 80);
  }

  private getTodayReminders(): ReminderSnapshot[] {
    const now = Date.now();
    const todayStart = startOfDay(now);

    // 收集今天已完成的提醒 id
    const completedIds = new Set<string>();
    this.tasks.forEach((t: Task) => {
      if (t.reminderId && t.status === TaskStatus.COMPLETED && t.completedAt && startOfDay(t.completedAt) === todayStart) {
        completedIds.add(t.reminderId);
      }
    });

    // 直接查"今天有触发的事件"
    const todayEvents = getEventsForDate(this.dayEvents, now);

    const results: ReminderSnapshot[] = [];

    todayEvents.forEach((event: DayEvent) => {
      // 跳过已结束/已暂停的
      if (event.isCompleted) return;
      if (!event.isEnabled) return;
      if (isDayEventEnded(event, now)) return;

      const occurrenceTime = getDayEventOccurrenceTimeOnDate(event, now);
      const completedToday = completedIds.has(event.id);

      let timeText: string;
      let isDueNow = false;
      if (completedToday) {
        timeText = '已完成';
      } else if (occurrenceTime !== undefined) {
        isDueNow = occurrenceTime <= now;
        const date = new Date(occurrenceTime);
        timeText = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
      } else {
        timeText = '今天';
      }

      results.push({
        id: event.id,
        title: event.title,
        typeLabel: this.getDayEventTypeLabel(event),
        timeText,
        isDueNow,
        completedToday
      });
    });

    // 还要把今天虽然没"触发"但今天已被打卡完成的事件加进来（习惯计数型可能不在 today 列表）
    completedIds.forEach((eventId: string) => {
      if (results.some((r: ReminderSnapshot) => r.id === eventId)) return;
      const event = this.dayEvents.find((e: DayEvent) => e.id === eventId);
      if (!event) return;
      results.push({
        id: event.id,
        title: event.title,
        typeLabel: this.getDayEventTypeLabel(event),
        timeText: '已完成',
        isDueNow: false,
        completedToday: true
      });
    });

    return results.sort((a: ReminderSnapshot, b: ReminderSnapshot) => {
      if (a.completedToday && !b.completedToday) return 1;
      if (!a.completedToday && b.completedToday) return -1;
      if (a.isDueNow && !b.isDueNow) return -1;
      if (!a.isDueNow && b.isDueNow) return 1;
      return 0;
    }).slice(0, 8);
  }

  private getDayEventTypeLabel(event: DayEvent): string {
    switch (event.type) {
      case DayEventType.SINGLE: return '单次';
      case DayEventType.HABIT: return '习惯';
      case DayEventType.PERIODIC: return '周期';
      case DayEventType.COUNTDOWN: return '倒计时';
      case DayEventType.MILESTONE: return '里程碑';
      case DayEventType.COUNTER: return '计数';
      default: return '提醒';
    }
  }

  private getReminderStatusText(item: ReminderSnapshot): string {
    if (item.completedToday) {
      return '今天已完成';
    }
    if (item.isDueNow) {
      return '需要尽快处理';
    }
    return '今天待处理';
  }

  private getReminderStatusColor(item: ReminderSnapshot): string {
    if (item.completedToday) {
      return this.themeColors.success;
    }
    if (item.isDueNow) {
      return this.themeColors.danger;
    }
    return this.themeColors.textSecondary;
  }

  private getQuickActions(): QuickAction[] {
    return [
      { icon: 'task', label: '新建任务', action: () => { if (this.onCreateTask) this.onCreateTask(); } },
      { icon: 'goal', label: '新建目标', action: () => { if (this.onCreateGoal) this.onCreateGoal(); } },
      { icon: 'reminder', label: '新建提醒', action: () => { if (this.onCreateReminder) this.onCreateReminder(); } },
      { icon: 'focus', label: '开始专注', action: () => { if (this.onStartFocus) this.onStartFocus(); } }
    ];
  }

  private getQuickActionIconSize(item: QuickAction): number {
    return item.label === '开始专注' ? 22 : 26;
  }

  // ========== UI Builders ==========

  @Builder
  private GreetingSection() {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(`${this.getGreeting()}${this.getDisplayName() ? '，' + this.getDisplayName() : ''}`)
            .fontSize(TYPE_HERO_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.getDateText())
            .fontSize(TYPE_BODY)
            .fontColor(this.themeColors.textSecondary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 搜索图标
        Stack({ alignContent: Alignment.Center }) {
          Row()
            .width(40)
            .height(40)
            .backgroundColor(this.themeColors.surfaceSoft)
            .borderRadius(20)

          AppIcon({ name: 'search', iconSize: 22, framed: false, color: this.themeColors.textSecondary })
        }
        .width(40)
        .height(40)
        .onClick(() => {
          if (this.onOpenSearch) this.onOpenSearch();
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private QuickActionsBar() {
    Row({ space: 0 }) {
      ForEach(this.getQuickActions(), (item: QuickAction) => {
        Column({ space: 4 }) {
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(V2_QUICK_ACTION_SIZE)
              .height(V2_QUICK_ACTION_SIZE)
              .backgroundColor(this.themeColors.primarySubtle)
              .borderRadius(V2_QUICK_ACTION_SIZE / 2)
              .border({ width: 1, color: this.themeColors.primaryLight })

            AppIcon({
              name: item.icon,
              iconSize: this.getQuickActionIconSize(item),
              framed: false,
              color: this.themeColors.primary
            })
          }
          .width(V2_QUICK_ACTION_SIZE)
          .height(V2_QUICK_ACTION_SIZE)

          Text(item.label)
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textSecondary)
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          item.action();
        })
      }, (item: QuickAction) => item.label)
    }
    .width('100%')
  }

  @Builder
  private PlanCard() {
    Column({ space: 8 }) {
      // 标题行
      Row() {
        Column({ space: 2 }) {
          Text('今日计划')
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
          Text(this.hasActionableTodayPlan() ? '把今天最重要的事收在一张焦点卡里' : '先收拢今天的重点，再开始推进')
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textSecondary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.hasActionableTodayPlan()) {
          Text(`${this.getActionablePlanTaskCount()} 项`)
            .fontSize(TYPE_CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.primary)
            .padding({ left: 7, right: 7, top: 2, bottom: 2 })
            .backgroundColor(this.themeColors.surfaceRaised)
            .border({ width: 1, color: this.themeColors.primaryLight })
            .borderRadius(10)
        }
      }
      .width('100%')

      if (!this.hasActionableTodayPlan()) {
        Column({ space: 6 }) {
          Text('还没有今日计划')
            .fontSize(TYPE_BODY)
            .fontColor(this.themeColors.textSecondary)
          Text('点击生成 AI 计划，或手动选择今天要做的事')
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textMuted)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .alignItems(HorizontalAlign.Start)
      } else {
        Column({ space: 0 }) {
          ForEach(this.getPlanFocusTasksDisplay(), (item: SavedPlanTaskItem) => {
            this.PlanTaskRow(item)
          }, (item: SavedPlanTaskItem) => `${item.id}_${item.completed}`)
        }
        .width('100%')

        if (this.getPlanFocusTasks().length > 7) {
          Text(`还有 ${this.getPlanFocusTasks().length - 7} 项`)
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textMuted)
            .width('100%')
        }
      }

      // 底部操作
      Row({ space: 8 }) {
        Text(this.hasActionableTodayPlan() ? '查看完整计划' : '生成 AI 计划')
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.primary)
          .onClick(() => {
            if (this.onOpenTodayPlan) this.onOpenTodayPlan();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(SPACE_MD)
    .backgroundColor(this.themeColors.announcementSurface)
    .borderRadius(RADIUS_LG)
    .border({ width: BORDER_DEFAULT, color: this.themeColors.primaryLight })
    .shadow({ radius: 8, color: this.themeColors.cardShadow, offsetX: 0, offsetY: 2 })
  }

  @Builder
  private PlanTaskRow(item: SavedPlanTaskItem) {
    Row({ space: 10 }) {
      // 完成状态圆圈（点击切换完成状态）
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(22)
          .height(22)
          .borderRadius(11)
          .border({ width: item.completed ? 0 : 1.5, color: item.completed ? 'transparent' : (item.type === 'reminder' ? this.themeColors.primary : this.themeColors.borderColor) })
          .backgroundColor(item.completed ? this.themeColors.successSubtle : 'transparent')

        if (item.completed) {
          AppIcon({ name: 'success', iconSize: 14, framed: false, color: this.themeColors.success })
        } else if (item.type === 'reminder') {
          AppIcon({ name: 'reminder', iconSize: 12, framed: false, color: this.themeColors.primary })
        }
      }
      .width(32)
      .height(32)
      .onClick(() => {
        if (item.type === 'reminder') {
          // 提醒类型：调用打卡回调
          if (this.onCompleteReminder) this.onCompleteReminder(item.id);
        } else {
          // 任务类型：切换完成状态
          const task = this.tasks.find((t: Task) => t.id === item.id);
          if (task && this.onToggleTaskComplete) {
            this.onToggleTaskComplete(task);
          }
        }
      })

      // 内容区
      Column({ space: 6 }) {
        Row({ space: 6 }) {
          if (item.type !== 'reminder' && this.getTaskCategory(item.id) !== null) {
            Text(this.getTaskCategory(item.id)!.label)
              .fontSize(TYPE_META)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getTaskCategory(item.id)!.color)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(this.themeColors.surfaceSoft)
              .borderRadius(4)
          }

          if (item.type === 'reminder') {
            Text('提醒')
              .fontSize(TYPE_META)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColors.primary)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(this.themeColors.primarySubtle)
              .borderRadius(4)
          }
        }
        .width('100%')

        Text(item.title)
          .fontSize(TYPE_BODY)
          .fontColor(item.completed ? this.themeColors.textMuted : this.themeColors.textPrimary)
          .decoration({ type: item.completed ? TextDecorationType.LineThrough : TextDecorationType.None })
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .onClick(() => {
            if (item.type !== 'reminder' && this.onOpenTaskDetail) this.onOpenTaskDetail(item.id);
          })

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          if (item.goalTitle && item.goalTitle.length > 0) {
            Text(item.goalTitle)
              .fontSize(TYPE_CAPTION)
              .fontColor(this.themeColors.textMuted)
              .margin({ right: 8, bottom: 4 })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (item.reminderTime && item.reminderTime.length > 0) {
            Text(item.reminderTime)
              .fontSize(TYPE_CAPTION)
              .fontColor(this.themeColors.textSecondary)
              .margin({ right: 8, bottom: 4 })
          }
          if (item.estimatedMinutes && !item.completed) {
            Text(this.formatEstimatedHours(item.estimatedMinutes))
              .fontSize(TYPE_CAPTION)
              .fontColor(this.themeColors.textMuted)
              .margin({ right: 8, bottom: 4 })
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Top)
  }

  private formatEstimatedHours(minutes: number): string {
    const hours = minutes / 60;
    if (hours >= 1) {
      // 整数小时不显示小数
      return Number.isInteger(hours) ? `${hours}h` : `${hours.toFixed(1)}h`;
    }
    // 小于 1 小时，显示一位小数
    return `${hours.toFixed(1)}h`;
  }

  private getTaskCategory(taskId: string): CategoryInfo | null {
    const task = this.tasks.find((t: Task) => t.id === taskId);
    if (!task || !task.category) {
      return null;
    }
    const found = CATEGORIES.find((c: CategoryInfo) => c.value === task.category);
    return found || null;
  }

  @Builder
  private RemindersSection() {
    Column({ space: 8 }) {
      Row() {
        Text('今日提醒')
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .layoutWeight(1)

        Text('全部')
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.primary)
          .onClick(() => {
            if (this.onOpenReminderCenter) this.onOpenReminderCenter();
          })
      }
      .width('100%')

      if (this.getTodayReminders().length === 0) {
        Text('今天没有待处理的提醒')
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textMuted)
          .padding({ top: 4, bottom: 4 })
      } else {
        Column({ space: 8 }) {
          ForEach(this.getTodayReminders(), (item: ReminderSnapshot) => {
            this.ReminderRow(item)
          }, (item: ReminderSnapshot) => `${item.id}_${item.completedToday}`)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private ReminderRow(item: ReminderSnapshot) {
    Column({ space: 8 }) {
      Text(item.title)
        .fontSize(TYPE_BODY)
        .fontColor(item.completedToday ? this.themeColors.textMuted : this.themeColors.textPrimary)
        .decoration({ type: item.completedToday ? TextDecorationType.LineThrough : TextDecorationType.None })
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        Text(item.typeLabel)
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.primary)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(this.themeColors.primarySubtle)
          .borderRadius(4)
          .margin({ right: 8, bottom: 4 })

        Text(item.timeText)
          .fontSize(TYPE_CAPTION)
          .fontColor(item.completedToday ? this.themeColors.success : (item.isDueNow ? this.themeColors.danger : this.themeColors.textSecondary))
          .margin({ right: 8, bottom: 4 })

        Text(this.getReminderStatusText(item))
          .fontSize(TYPE_CAPTION)
          .fontColor(this.getReminderStatusColor(item))
          .margin({ right: 8, bottom: 4 })
      }
      .width('100%')

      Row() {
        if (!item.completedToday) {
          Text('标记完成')
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.primary)
            .fontWeight(FontWeight.Medium)
            .padding({ left: 8, right: 8, top: 5, bottom: 5 })
            .borderRadius(6)
            .backgroundColor(this.themeColors.primarySubtle)
            .onClick(() => {
              if (this.onCompleteReminder) this.onCompleteReminder(item.id);
            })
        } else {
          Row({ space: 4 }) {
            AppIcon({ name: 'success', iconSize: 14, framed: false, color: this.themeColors.success })
            Text('已完成')
              .fontSize(TYPE_CAPTION)
              .fontColor(this.themeColors.success)
          }
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(this.themeColors.surfaceRaised)
    .borderRadius(RADIUS_MD)
    .border({ width: BORDER_DEFAULT, color: this.themeColors.borderColor })
  }

  @Builder
  private GoalsSection() {
    Row({ space: SPACE_SM }) {
      Text('目标')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)

      Text(`进行中 ${this.getActiveGoals().length}`)
        .fontSize(TYPE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.primary)

      Text('|')
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textMuted)

      Text(`本周优先 ${this.getPriorityGoalsThisWeek().length}`)
        .fontSize(TYPE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.textSecondary)

      Text('|')
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textMuted)

      Text(`即将完成 ${this.getNearlyCompletedGoals().length}`)
        .fontSize(TYPE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.success)

      Blank()

      AppIcon({ name: 'chevron-right', iconSize: 14, framed: false, color: this.themeColors.textMuted })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.themeColors.surface)
    .borderRadius(RADIUS_LG)
    .shadow({ radius: 6, color: this.themeColors.cardShadow, offsetX: 0, offsetY: 2 })
    .onClick(() => {
      if (this.onOpenGoalsTab) this.onOpenGoalsTab();
    })
  }

  @Builder
  private OverdueAlert() {
    if (this.getOverdueTasks().length > 0) {
      Row({ space: 8 }) {
        AppIcon({ name: 'warning', iconSize: 16, framed: false, color: this.themeColors.danger })

        Column({ space: 1 }) {
          Text(`${this.getOverdueTasks().length} 项任务已逾期`)
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.danger)

          Text('点击查看 AI 重排建议')
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textSecondary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        AppIcon({ name: 'chevron-right', iconSize: 14, framed: false, color: this.themeColors.textMuted })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .backgroundColor(this.themeColors.riskSurface)
      .borderRadius(RADIUS_MD)
      .border({ width: BORDER_DEFAULT, color: this.themeColors.borderColor })
      .onClick(() => {
        if (this.onOpenReschedule) this.onOpenReschedule();
      })
    }
  }

  // ========== 主 Build ==========

  build() {
    Scroll() {
      Column({ space: SPACE_MD }) {
        this.GreetingSection()
        this.QuickActionsBar()
        this.OverdueAlert()
        this.PlanCard()
        this.RemindersSection()
        this.GoalsSection()

        // 底部安全区
        Blank().height(50)
      }
      .width('100%')
      .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 8, bottom: 10 })
    }
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
