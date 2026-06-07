import { Goal, GoalCategory, KeyResult } from '../models/Goal';
import { Task, TaskStatus } from '../models/Task';
import { DayEvent, DayEventType, getEventTypeIcon } from '../models/DayEvent';
import { formatDayEventTime, startOfDay } from '../common/DayEventUtils';
import { getNextReminderOccurrenceTime, getReminderPeriodProgress } from '../services/ReminderTaskService';
import type { SavedPlanTaskItem, SavedTodayPlan } from '../models/TodayPlan';
import type { UserAccount } from '../services/AuthService';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import type { AppTone } from '../theme/ThemeSemantics';
import { PAGE_PADDING, PANEL_GAP, SPACE_2XS, SPACE_CARD, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { COMPACT_PAGE_PADDING } from '../foundation/tokens/PageTierTokens';
import { HERO_PANEL_HEIGHT_EXPANDED, TODAY_CONTENT_MAX_WIDTH, TODAY_SIDE_PANEL_WIDTH, TODAY_TWO_COLUMN_MIN_WIDTH } from '../foundation/tokens/PageDensityTokens';
import { BOTTOM_CONTENT_SPACER, CHECKBOX_SIZE_LG, COUNTDOWN_CARD_WIDTH, PROGRESS_RING_RADIUS, PROGRESS_RING_SIZE } from '../foundation/tokens/ComponentSizeTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_HERO_TITLE, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { db } from '../storage/Database';
import { LINE_HEIGHT_TIGHT } from '../foundation/tokens/VisualTokens';
import { getCardShadow } from '../foundation/tokens/ElevationTokens';
import { RADIUS_LG, RADIUS_PILL } from '../foundation/tokens/RadiusTokens';
import { dataSyncService } from '../services/DataSyncService';
import { AppButton } from '../ui/base/AppButton';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppGoalCard } from '../ui/base/AppGoalCard';
import { AppHeroPanel } from '../ui/base/AppHeroPanel';
import { AppPanelSection } from '../ui/base/AppPanelSection';
import { AppReminderCard } from '../ui/base/AppReminderCard';
import { AppSearchBar } from '../ui/base/AppSearchBar';
import { AppTaskRow } from '../ui/base/AppTaskRow';

interface ReminderInsight {
  event: DayEvent;
  nextOccurrence?: number;
  completedToday: boolean;
  badgeText: string;
  statusText: string;
  progressText: string;
  tone: AppTone;
  isDueNow: boolean;
}

interface TaskLookupEntry {
  id: string;
  task: Task;
}

interface GoalTaskCountEntry {
  goalId: string;
  count: number;
}

@Component
export struct TodayTab {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop goals: Goal[] = [];
  @Prop tasks: Task[] = [];
  @Prop savedPlan: SavedTodayPlan | null = null;
  @Prop user: UserAccount | null = null;
  @Prop dayEvents: DayEvent[] = [];
  onShowTodayPlanDialog?: () => void;
  onOpenManualTaskSelect?: () => void;
  onCheckGoalQuotaAndNavigate?: () => void;
  onOpenSearch?: () => void;
  onOpenReminderCenter?: () => void;
  private pendingTasksCacheSource: Task[] | null = null;
  private pendingTasksCache: Task[] = [];
  private completedReminderIdsCacheSource: Task[] | null = null;
  private completedReminderIdsCacheDate: number = -1;
  private completedReminderIdsCache: Set<string> = new Set<string>();
  private reminderInsightsCacheTaskSource: Task[] | null = null;
  private reminderInsightsCacheEventSource: DayEvent[] | null = null;
  private reminderInsightsCacheDate: number = -1;
  private reminderInsightsCache: ReminderInsight[] = [];
  private taskEntriesCacheSource: Task[] | null = null;
  private taskEntriesCache: TaskLookupEntry[] = [];
  private planFocusTasksCachePlanSource: SavedTodayPlan | null = null;
  private planFocusTasksCacheTaskSource: Task[] | null = null;
  private planFocusTasksCache: SavedPlanTaskItem[] = [];
  private featuredGoalsCacheSource: Goal[] | null = null;
  private featuredGoalsCache: Goal[] = [];
  private goalPendingTaskCountCacheSource: Task[] | null = null;
  private goalPendingTaskCountCache: GoalTaskCountEntry[] = [];
  @State contentWidth: number = 0;

  private isWideLayout(): boolean {
    return this.contentWidth >= TODAY_TWO_COLUMN_MIN_WIDTH;
  }

  private updateContentWidth(widthValue: Length): void {
    const nextWidth = parseFloat(`${widthValue}`);
    if (nextWidth > 0 && Math.abs(nextWidth - this.contentWidth) > 0.5) {
      this.contentWidth = nextWidth;
    }
  }

  private getDisplayName(): string {
    if (this.user && this.user.nickname && this.user.nickname.trim().length > 0) {
      return this.user.nickname;
    }
    if (this.user && this.user.account && this.user.account.trim().length > 0) {
      return this.user.account;
    }
    if (this.user && this.user.displayId && this.user.displayId.trim().length > 0) {
      return this.user.displayId;
    }
    return '现在就开始';
  }

  private getGreeting(): string {
    const hour = new Date().getHours();
    if (hour < 5) {
      return '夜深了';
    }
    if (hour < 11) {
      return '早安';
    }
    if (hour < 14) {
      return '中午好';
    }
    if (hour < 18) {
      return '下午好';
    }
    return '晚安';
  }

  private getDateSummary(): string {
    const now = new Date();
    const weekDays: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `${now.getFullYear()}年${now.getMonth() + 1}月${now.getDate()}日 ${weekDays[now.getDay()]}`;
  }

  private getPendingTasks(): Task[] {
    if (this.pendingTasksCacheSource === this.tasks) {
      return this.pendingTasksCache;
    }

    this.pendingTasksCache = this.tasks
      .filter((task: Task) => task.status === TaskStatus.PENDING)
      .sort((first: Task, second: Task) => {
        if (first.isOverdue !== second.isOverdue) {
          return first.isOverdue ? -1 : 1;
        }
        if (first.isImportant !== second.isImportant) {
          return first.isImportant ? -1 : 1;
        }
        return (first.dueDate || Number.MAX_SAFE_INTEGER) - (second.dueDate || Number.MAX_SAFE_INTEGER);
      });
    this.pendingTasksCacheSource = this.tasks;
    return this.pendingTasksCache;
  }

  private getImportantPendingCount(): number {
    return this.getPendingTasks().filter((task: Task) => task.isImportant).length;
  }

  private getOverduePendingCount(): number {
    return this.getPendingTasks().filter((task: Task) => task.isOverdue).length;
  }

  private getCompletedReminderTodaySet(): Set<string> {
    const today = startOfDay(Date.now());
    if (this.completedReminderIdsCacheSource === this.tasks && this.completedReminderIdsCacheDate === today) {
      return this.completedReminderIdsCache;
    }

    const completedReminderIds = new Set<string>();
    this.tasks.forEach((task: Task) => {
      if (!task.reminderId || task.status !== TaskStatus.COMPLETED || task.completedAt === undefined) {
        return;
      }
      if (startOfDay(task.completedAt) === today) {
        completedReminderIds.add(task.reminderId);
      }
    });

    this.completedReminderIdsCacheSource = this.tasks;
    this.completedReminderIdsCacheDate = today;
    this.completedReminderIdsCache = completedReminderIds;
    return this.completedReminderIdsCache;
  }

  private hasCompletedReminderToday(eventId: string): boolean {
    return this.getCompletedReminderTodaySet().has(eventId);
  }

  private getReminderTone(event: DayEvent): AppTone {
    switch (event.type) {
      case DayEventType.HABIT:
        return 'success';
      case DayEventType.MILESTONE:
        return 'warning';
      case DayEventType.COUNTER:
        return 'info';
      default:
        return 'primary';
    }
  }

  private getReminderBadge(event: DayEvent): string {
    switch (event.type) {
      case DayEventType.HABIT:
        return '习惯';
      case DayEventType.MILESTONE:
        return '重要日子';
      case DayEventType.COUNTER:
        return '纪念';
      default:
        return '提醒';
    }
  }

  private getTodayReminderInsights(): ReminderInsight[] {
    const today = startOfDay(Date.now());
    if (this.reminderInsightsCacheTaskSource === this.tasks &&
      this.reminderInsightsCacheEventSource === this.dayEvents &&
      this.reminderInsightsCacheDate === today) {
      return this.reminderInsightsCache;
    }

    const result: ReminderInsight[] = [];

    this.dayEvents
      .filter((event: DayEvent) => event.isEnabled && event.type !== DayEventType.COUNTDOWN)
      .forEach((event: DayEvent) => {
        const nextOccurrence = getNextReminderOccurrenceTime(event, this.tasks, today);
        const completedToday = this.hasCompletedReminderToday(event.id);
        const scheduledToday = nextOccurrence !== undefined && startOfDay(nextOccurrence) === today;
        if (!scheduledToday && !completedToday) {
          return;
        }

        const progress = getReminderPeriodProgress(event, this.tasks, Date.now());
        const progressText = progress
          ? `${progress.label} ${progress.completed}/${progress.target}`
          : (event.goalTitle && event.goalTitle.length > 0 ? `关联 ${event.goalTitle}` : this.getReminderBadge(event));
        let statusText = '今日待办';
        if (completedToday) {
          statusText = '今天已完成';
        } else if (nextOccurrence !== undefined) {
          statusText = nextOccurrence <= Date.now()
            ? '现在处理'
            : `今天 ${formatDayEventTime(nextOccurrence)}`;
        }

        result.push({
          event,
          nextOccurrence,
          completedToday,
          badgeText: this.getReminderBadge(event),
          statusText,
          progressText,
          tone: this.getReminderTone(event),
          isDueNow: !completedToday && nextOccurrence !== undefined && nextOccurrence <= Date.now()
        });
      });

    this.reminderInsightsCache = result
      .sort((first: ReminderInsight, second: ReminderInsight) => {
        if (first.completedToday !== second.completedToday) {
          return first.completedToday ? 1 : -1;
        }
        if (first.isDueNow !== second.isDueNow) {
          return first.isDueNow ? -1 : 1;
        }
        const firstOccurrence = first.nextOccurrence || Number.MAX_SAFE_INTEGER;
        const secondOccurrence = second.nextOccurrence || Number.MAX_SAFE_INTEGER;
        if (firstOccurrence !== secondOccurrence) {
          return firstOccurrence - secondOccurrence;
        }
        return (second.event.updatedAt || second.event.createdAt) - (first.event.updatedAt || first.event.createdAt);
      });
    this.reminderInsightsCacheTaskSource = this.tasks;
    this.reminderInsightsCacheEventSource = this.dayEvents;
    this.reminderInsightsCacheDate = today;
    return this.reminderInsightsCache;
  }

  private getReminderAccentColor(tone: AppTone): string {
    switch (tone) {
      case 'success':
        return this.themeColors.success;
      case 'warning':
        return this.themeColors.warning;
      case 'info':
        return this.themeColors.info;
      case 'danger':
        return this.themeColors.danger;
      default:
        return this.themeColors.primary;
    }
  }

  private getReminderSoftColor(tone: AppTone): string {
    switch (tone) {
      case 'success':
        return this.themeColors.successSubtle;
      case 'warning':
        return this.themeColors.warningSubtle;
      case 'info':
        return this.themeColors.infoSubtle;
      case 'danger':
        return this.themeColors.dangerSubtle;
      default:
        return this.themeColors.primarySubtle;
    }
  }

  private getReminderMetaText(item: ReminderInsight): string {
    if (item.completedToday) {
      return '今日已完成';
    }
    return item.statusText;
  }

  private getPrimaryCountdown(): DayEvent | null {
    const countdowns = this.dayEvents
      .filter((event: DayEvent) => event.isEnabled && event.type === DayEventType.COUNTDOWN && event.targetDate !== undefined)
      .sort((first: DayEvent, second: DayEvent) => (first.targetDate || Number.MAX_SAFE_INTEGER) - (second.targetDate || Number.MAX_SAFE_INTEGER));
    return countdowns.length > 0 ? countdowns[0] : null;
  }

  private getCountdownDiffDays(event: DayEvent): number {
    if (event.targetDate === undefined) {
      return 0;
    }
    const today = startOfDay(Date.now());
    const target = startOfDay(event.targetDate);
    return Math.round((target - today) / (24 * 60 * 60 * 1000));
  }

  private getCountdownRemainingText(event: DayEvent): string {
    const diffDays = this.getCountdownDiffDays(event);
    if (diffDays === 0) {
      return '今天';
    }
    if (diffDays > 0) {
      return `${diffDays}天后`;
    }
    return `${Math.abs(diffDays)}天前`;
  }

  private getPlanPrimaryActionLabel(): string {
    return this.savedPlan ? '查看计划' : '生成计划';
  }

  private getPlanDescription(): string {
    if (this.savedPlan && this.savedPlan.summary && this.savedPlan.summary.length > 0) {
      const trimmed = this.savedPlan.summary.trim();
      if (trimmed.length <= 50) {
        return trimmed;
      }
    }
    return `系统会结合优先级、逾期风险和估时，生成今天更适合执行的安排。`;
  }

  private hasAdoptedPlanContent(): boolean {
    return !!this.savedPlan &&
      this.savedPlan.planSource !== 'cloud_pending' &&
      this.savedPlan.focusTasks.length > 0;
  }

  private getTaskEntries(): TaskLookupEntry[] {
    if (this.taskEntriesCacheSource === this.tasks) {
      return this.taskEntriesCache;
    }

    this.taskEntriesCache = this.tasks.map((task: Task) => ({
      id: task.id,
      task
    }));
    this.taskEntriesCacheSource = this.tasks;
    return this.taskEntriesCache;
  }

  private findTaskById(taskId: string): Task | undefined {
    const entry = this.getTaskEntries().find((item: TaskLookupEntry) => item.id === taskId);
    return entry ? entry.task : undefined;
  }

  private getPlanFocusTasks(): SavedPlanTaskItem[] {
    if (!this.savedPlan) {
      return [];
    }
    if (this.planFocusTasksCachePlanSource === this.savedPlan && this.planFocusTasksCacheTaskSource === this.tasks) {
      return this.planFocusTasksCache;
    }
    const orderEntries = this.savedPlan.focusTasks.map((item: SavedPlanTaskItem, index: number) => ({
      id: item.id,
      order: index
    }));
    const getTaskOrder = (taskId: string): number => {
      const entry = orderEntries.find((item: { id: string; order: number }) => item.id === taskId);
      return entry ? entry.order : 0;
    };
    this.planFocusTasksCache = this.savedPlan.focusTasks
      .slice()
      .sort((first: SavedPlanTaskItem, second: SavedPlanTaskItem) => {
        const firstCompleted = this.findTaskById(first.id)?.status === TaskStatus.COMPLETED || !!first.completed;
        const secondCompleted = this.findTaskById(second.id)?.status === TaskStatus.COMPLETED || !!second.completed;
        if (firstCompleted !== secondCompleted) {
          return firstCompleted ? 1 : -1;
        }
        return getTaskOrder(first.id) - getTaskOrder(second.id);
      });
    this.planFocusTasksCachePlanSource = this.savedPlan;
    this.planFocusTasksCacheTaskSource = this.tasks;
    return this.planFocusTasksCache;
  }

  private isPlanTaskCompleted(item: SavedPlanTaskItem): boolean {
    const task = this.findTaskById(item.id);
    if (task) {
      return task.status === TaskStatus.COMPLETED;
    }
    return !!item.completed;
  }

  private getCompletedPlanTaskCount(): number {
    return this.getPlanFocusTasks().filter((item: SavedPlanTaskItem) => this.isPlanTaskCompleted(item)).length;
  }

  private getPlanProgressPercent(): number {
    const total = this.getPlanFocusTasks().length;
    if (total <= 0) {
      return 0;
    }
    return Math.round((this.getCompletedPlanTaskCount() / total) * 100);
  }

  private formatPlanHours(): string {
    if (!this.savedPlan || this.savedPlan.totalEstimatedHours === undefined) {
      return '--';
    }
    const hours = this.savedPlan.totalEstimatedHours;
    return Number.isInteger(hours) ? `${hours}h` : `${hours.toFixed(1)}h`;
  }

  private getPlanTaskMeta(item: SavedPlanTaskItem): string {
    const task = this.findTaskById(item.id);
    if (item.reason && item.reason.trim().length > 0) {
      return item.reason.trim();
    }
    if (task && task.goalTitle && task.goalTitle.trim().length > 0) {
      return task.goalTitle;
    }
    if (item.estimatedMinutes && item.estimatedMinutes > 0) {
      return `预计 ${item.estimatedMinutes} 分钟`;
    }
    return '已加入今日计划';
  }

  private openTaskDetail(taskId: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/TaskDetailPage', params: { taskId } });
    } catch (_) {}
  }

  private async togglePlanTaskCompletion(taskId: string): Promise<void> {
    const task = this.findTaskById(taskId);
    if (!task) {
      return;
    }
    const willComplete = task.status !== TaskStatus.COMPLETED;
    const updatedTask = await db.setTaskCompletion(task.id, willComplete);
    if (updatedTask) {
      dataSyncService.updateTask(updatedTask);
    }
  }

  private getFeaturedGoals(): Goal[] {
    if (this.featuredGoalsCacheSource === this.goals) {
      return this.featuredGoalsCache;
    }

    this.featuredGoalsCache = this.goals
      .filter((goal: Goal) => !goal.isArchived)
      .sort((first: Goal, second: Goal) => {
        if (first.isPriority !== second.isPriority) {
          return first.isPriority ? -1 : 1;
        }
        if (first.progress !== second.progress) {
          return second.progress - first.progress;
        }
        return (second.updatedAt || second.createdAt) - (first.updatedAt || first.createdAt);
      });
    this.featuredGoalsCacheSource = this.goals;
    return this.featuredGoalsCache;
  }

  private getVisibleGoals(): Goal[] {
    const goals = this.getFeaturedGoals();
    return goals.slice(0, 3);
  }

  private getGoalTaskCount(goal: Goal): number {
    if (this.goalPendingTaskCountCacheSource !== this.tasks) {
      this.goalPendingTaskCountCache = [];
      this.tasks.forEach((task: Task) => {
        if (task.status !== TaskStatus.PENDING || !task.goalId) {
          return;
        }
        const entry = this.goalPendingTaskCountCache.find((item: GoalTaskCountEntry) => item.goalId === task.goalId);
        if (entry) {
          entry.count += 1;
          return;
        }
        this.goalPendingTaskCountCache.push({
          goalId: task.goalId,
          count: 1
        });
      });
      this.goalPendingTaskCountCacheSource = this.tasks;
    }
    const entry = this.goalPendingTaskCountCache.find((item: GoalTaskCountEntry) => item.goalId === goal.id);
    return entry ? entry.count : 0;
  }

  private getVisibleKeyResults(goal: Goal): KeyResult[] {
    if (!goal.keyResults || goal.keyResults.length === 0) {
      return [];
    }
    return goal.keyResults
      .slice()
      .sort((first: KeyResult, second: KeyResult) => {
        const firstPending = first.progress < 100 ? 0 : 1;
        const secondPending = second.progress < 100 ? 0 : 1;
        if (firstPending !== secondPending) {
          return firstPending - secondPending;
        }
        return first.progress - second.progress;
      })
      .slice(0, 3);
  }

  private getGoalTagBackground(goal: Goal): string {
    switch (goal.category) {
      case GoalCategory.HEALTH:
        return this.themeColors.successSubtle;
      case GoalCategory.LEARNING:
        return this.themeColors.primarySubtle;
      case GoalCategory.FINANCE:
        return this.themeColors.warningSubtle;
      case GoalCategory.FUN:
        return this.themeColors.premiumSurface;
      default:
        return this.themeColors.primarySubtle;
    }
  }

  private getGoalTagTextColor(goal: Goal): string {
    switch (goal.category) {
      case GoalCategory.HEALTH:
        return this.themeColors.success;
      case GoalCategory.LEARNING:
        return this.themeColors.primary;
      case GoalCategory.FINANCE:
        return this.themeColors.warning;
      case GoalCategory.FUN:
        return this.themeColors.premiumText;
      default:
        return this.themeColors.primary;
    }
  }

  private getGoalMetricColor(goal: Goal): string {
    switch (goal.category) {
      case GoalCategory.HEALTH:
        return this.themeColors.success;
      case GoalCategory.LEARNING:
        return this.themeColors.primary;
      case GoalCategory.FINANCE:
        return this.themeColors.warning;
      case GoalCategory.FUN:
        return this.themeColors.primaryLight;
      default:
        return this.themeColors.primary;
    }
  }

  private getGoalBadgeText(goal: Goal): string {
    return goal.category as string;
  }

  private getGoalKeyResultSummaries(goal: Goal): string[] {
    const items = this.getVisibleKeyResults(goal).map((keyResult: KeyResult) => {
      return `${keyResult.title} ${keyResult.currentValue}/${keyResult.targetValue}`;
    });
    if (items.length > 0) {
      return items;
    }
    return ['先补一个关键结果，首页才能更清楚地显示推进状态'];
  }

  private openSearch(): void {
    if (this.onOpenSearch) {
      this.onOpenSearch();
      return;
    }
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/SearchPage' });
    } catch (_) {}
  }

  private openActiveGoalsPage(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ActiveGoalsPage' });
    } catch (_) {}
  }

  private openReminderCenter(): void {
    if (this.onOpenReminderCenter) {
      this.onOpenReminderCenter();
      return;
    }
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ReminderListPage' });
    } catch (_) {}
  }

  private openReminderDetail(eventId: string): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/DayEventDetailPage', params: { eventId } });
    } catch (_) {}
  }

  @Builder
  private HeaderCountdownCard(event: DayEvent) {
    Column({ space: SPACE_XS }) {
      Text(event.title)
        .fontSize(TYPE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.getCountdownRemainingText(event))
        .fontSize(TYPE_HERO_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(COUNTDOWN_CARD_WIDTH)
    .padding({ left: SPACE_CARD, right: SPACE_CARD, top: SPACE_SM, bottom: SPACE_SM })
    .backgroundColor(this.themeColors.surface)
    .borderRadius(RADIUS_LG)
    .border({ width: 1, color: this.themeColors.borderColor })
    .shadow(getCardShadow(this.themeColors))
  }

  @Builder
  private TopHero() {
    Row({ space: SPACE_MD }) {
      Column({ space: SPACE_XS }) {
        Text(`${this.getGreeting()}，${this.getDisplayName()}`)
          .fontSize(TYPE_HERO_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.getDateSummary())
          .fontSize(TYPE_CAPTION)
          .lineHeight(LINE_HEIGHT_TIGHT)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.getPrimaryCountdown()) {
        this.HeaderCountdownCard(this.getPrimaryCountdown() as DayEvent)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private SearchBar() {
    AppSearchBar({
      placeholder: '搜索任务、目标或提醒',
      badgeText: 'AI',
      insetHorizontal: 0,
      tapAction: () => {
        this.openSearch();
      }
    })
  }

  @Builder
  private ReminderCard(item: ReminderInsight) {
    AppReminderCard({
      title: item.event.title,
      subtitle: this.getReminderMetaText(item),
      meta: item.progressText,
      tone: item.tone,
      iconName: getEventTypeIcon(item.event.type),
      tapAction: () => {
        this.openReminderDetail(item.event.id);
      }
    })
  }

  @Builder
  private ReminderSection() {
    AppPanelSection({
      title: '今日提醒',
      subtitle: `${this.getTodayReminderInsights().length} 条`,
      actionText: '查看全部',
      actionIconName: 'chevron-right',
      insetHorizontal: 0,
      onAction: () => {
        this.openReminderCenter();
      }
    }) {
      if (this.getTodayReminderInsights().length > 0) {
        Scroll() {
          Row({ space: SPACE_SM }) {
            ForEach(this.getTodayReminderInsights().slice(0, 6), (item: ReminderInsight) => {
              this.ReminderCard(item);
            }, (item: ReminderInsight) => item.event.id)
          }
          .padding({ right: SPACE_MD })
        }
        .align(Alignment.Top)
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      } else {
        AppEmptyState({
          title: '\u4eca\u5929\u6ca1\u6709\u9700\u8981\u5904\u7406\u7684\u63d0\u9192',
          description: '\u53ef\u4ee5\u7ee7\u7eed\u63a8\u8fdb\u4eca\u65e5\u8ba1\u5212\uff0c\u6216\u8005\u53bb\u63d0\u9192\u4e2d\u5fc3\u8865\u5145\u65b0\u7684\u4e60\u60ef\u4e0e\u63d0\u9192\u3002',
          iconName: 'reminder',
          iconTone: 'info'
        })
      }
    }
  }

  @Builder
  private MiniStatBox(label: string, value: string, valueColor: string) {
    Column({ space: SPACE_XS }) {
      Text(label)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Text(value)
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ left: SPACE_SM, right: SPACE_SM, top: SPACE_XS, bottom: SPACE_XS })
    .backgroundColor(this.themeColors.surface)
    .borderRadius(RADIUS_LG)
  }

  @Builder
  private PrimaryActionButton(text: string, background: string, color: string, borderColor: string, iconName: string,
    action: () => void) {
    Row() {
      AppButton({
        text,
        variant: background === this.themeColors.primary ? 'primary' : 'secondary',
        buttonSize: 'md',
        fullWidth: true,
        iconName,
        tapAction: action
      })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private PlanProgressCircle() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(PROGRESS_RING_SIZE)
        .height(PROGRESS_RING_SIZE)
        .borderRadius(PROGRESS_RING_RADIUS)
        .border({ width: 4, color: this.themeColors.divider })
        .backgroundColor(this.themeColors.surface)

      Text(`${this.getPlanProgressPercent()}%`)
        .fontSize(TYPE_META)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
    }
  }

  @Builder
  private PlanTaskCheckbox(item: SavedPlanTaskItem) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(CHECKBOX_SIZE_LG)
        .height(CHECKBOX_SIZE_LG)
        .border({
          width: 1.5,
          color: this.isPlanTaskCompleted(item) ? this.themeColors.success : this.themeColors.borderColor
        })
        .borderRadius(RADIUS_PILL)
        .backgroundColor(this.themeColors.surface)
      if (this.isPlanTaskCompleted(item)) {
        AppIcon({ name: 'success', iconSize: 14, framed: false, color: this.themeColors.success, useSystemSymbol: false })
      }
    }
      .width(CHECKBOX_SIZE_LG)
      .height(CHECKBOX_SIZE_LG)
      .onClick(() => {
        void this.togglePlanTaskCompletion(item.id);
      })
  }

  @Builder
  private PlanTaskRow(item: SavedPlanTaskItem) {
    AppTaskRow({
      title: item.title,
      subtitle: this.getPlanTaskMeta(item),
      completed: this.isPlanTaskCompleted(item),
      embedded: false,
      onToggle: () => {
        void this.togglePlanTaskCompletion(item.id);
      },
      onOpen: () => {
        this.openTaskDetail(item.id);
      }
    })
  }

  @Builder
  private AdoptedPlanHeroCard() {
    Stack({ alignContent: Alignment.TopEnd }) {
      AppHeroPanel({
        eyebrow: '今日计划',
        title: '今日计划',
        description: `聚焦中 ${this.getCompletedPlanTaskCount()}/${this.getPlanFocusTasks().length}`,
        tone: 'primary',
        minHeight: HERO_PANEL_HEIGHT_EXPANDED
      }) {
        Column({ space: SPACE_XS }) {
          ForEach(this.getPlanFocusTasks(), (item: SavedPlanTaskItem) => {
            this.PlanTaskRow(item)
          }, (item: SavedPlanTaskItem) => item.id)
        }
        .width('100%')

        Row({ space: SPACE_MD }) {
          Text(`预计 ${this.formatPlanHours()}`)
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
        }
        .width('100%')

        Row({ space: SPACE_SM }) {
          this.PrimaryActionButton(
            '手动',
            this.themeColors.surface,
            this.themeColors.textPrimary,
            this.themeColors.borderColor,
            'task',
            () => {
              if (this.onOpenManualTaskSelect) {
                this.onOpenManualTaskSelect();
              } else {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/TaskSelectPage' });
              }
            }
          )

          this.PrimaryActionButton(
            '重新规划',
            this.themeColors.surface,
            this.themeColors.primary,
            this.themeColors.primaryLight,
            'ai',
            () => {
              if (this.onShowTodayPlanDialog) {
                this.onShowTodayPlanDialog();
              } else {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/TodayPlanPage' });
              }
            }
          )
        }
        .width('100%')
        .padding({ left: SPACE_2XS, right: SPACE_2XS })
        .alignItems(VerticalAlign.Center)
      }

      Row() {
        this.PlanProgressCircle()
      }
      .padding({ top: SPACE_CARD, right: SPACE_CARD })
    }
    .width('100%')
  }

  @Builder
  private LegacyPlanHeroCard() {
    AppHeroPanel({
      eyebrow: '今日计划',
      title: '让 AI 帮你安排今天',
      description: this.getPlanDescription(),
      tone: 'primary'
    }) {
      Row({ space: SPACE_SM }) {
        this.MiniStatBox('待办', `${this.getPendingTasks().length}`, this.themeColors.primary)
        this.MiniStatBox('重点', `${this.getImportantPendingCount()}`, this.themeColors.warning)
        this.MiniStatBox('逾期', `${this.getOverduePendingCount()}`, this.themeColors.danger)
      }
      .width('100%')

      Row({ space: SPACE_SM }) {
        this.PrimaryActionButton(
          this.getPlanPrimaryActionLabel(),
          this.themeColors.primary,
          this.themeColors.textOnPrimary,
          this.themeColors.primary,
          'ai',
          () => {
            if (this.onShowTodayPlanDialog) {
              this.onShowTodayPlanDialog();
            } else {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/TodayPlanPage' });
            }
          }
        )
        this.PrimaryActionButton(
          '手动组装',
          this.themeColors.surface,
          this.themeColors.textPrimary,
          this.themeColors.borderColor,
          'task',
          () => {
            if (this.onOpenManualTaskSelect) {
              this.onOpenManualTaskSelect();
            } else {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/TaskSelectPage' });
            }
          }
        )
      }
      .width('100%')
      .padding({ left: SPACE_2XS, right: SPACE_2XS })
    }
  }

  @Builder
  private PlanHeroCard() {
    if (this.hasAdoptedPlanContent()) {
      this.AdoptedPlanHeroCard()
    } else {
      this.LegacyPlanHeroCard()
    }
  }

  @Builder
  private GoalCard(goal: Goal) {
    AppGoalCard({
      badgeText: this.getGoalBadgeText(goal),
      title: goal.title,
      progressText: `今天还有 ${this.getGoalTaskCount(goal)} 件行动`,
      percentText: `${Math.min(100, Math.max(0, goal.progress))}%`,
      keyResults: this.getGoalKeyResultSummaries(goal),
      accentColor: this.getGoalMetricColor(goal),
      badgeTextColor: this.getGoalTagTextColor(goal),
      badgeBackgroundColor: this.getGoalTagBackground(goal),
      tapAction: () => {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/GoalDetailPage', params: { goalId: goal.id } });
      }
    })
  }

  @Builder
  private EmptyGoalCard() {
    AppEmptyState({
      title: '还没有正在推进的目标',
      description: '先建立一个目标，再把任务和提醒挂到它下面，首页会更像一张真正的执行面板。',
      actionText: '创建目标',
      actionIconName: 'goal',
      iconName: 'goal',
      iconTone: 'primary',
      onAction: () => {
        if (this.onCheckGoalQuotaAndNavigate) {
          this.onCheckGoalQuotaAndNavigate();
        }
      }
    })
  }

  @Builder
  private GoalsSection() {
    AppPanelSection({
      title: '\u6b63\u5728\u63a8\u8fdb\u7684\u76ee\u6807',
      subtitle: `${this.getFeaturedGoals().length} \u4e2a`,
      actionText: this.getFeaturedGoals().length > 3 ? '\u67e5\u770b\u5168\u90e8' : '',
      actionIconName: 'chevron-right',
      insetHorizontal: 0,
      onAction: this.getFeaturedGoals().length > 3
        ? () => {
          this.openActiveGoalsPage();
        }
        : undefined
    }) {
      if (this.getFeaturedGoals().length > 0) {
        ForEach(this.getVisibleGoals(), (goal: Goal) => {
          this.GoalCard(goal);
        }, (goal: Goal) => goal.id)
      } else {
        this.EmptyGoalCard()
      }
    }
  }

  build() {
    Scroll() {
      Column({ space: PANEL_GAP }) {
        this.TopHero()
        this.SearchBar()
        if (this.isWideLayout()) {
          Row({ space: PANEL_GAP }) {
            Column({ space: PANEL_GAP }) {
              this.PlanHeroCard()
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Column({ space: PANEL_GAP }) {
              this.ReminderSection()
              this.GoalsSection()
            }
            .width(TODAY_SIDE_PANEL_WIDTH)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        } else {
        this.ReminderSection()
        this.PlanHeroCard()

        AppPanelSection({
          title: '正在推进的目标',
          subtitle: `${this.getFeaturedGoals().length} 个`,
          actionText: this.getFeaturedGoals().length > 3 ? '查看全部' : '',
          actionIconName: 'chevron-right',
          insetHorizontal: 0,
          onAction: this.getFeaturedGoals().length > 3
            ? () => {
              this.openActiveGoalsPage();
            }
            : undefined
        }) {
          if (this.getFeaturedGoals().length > 0) {
            ForEach(this.getVisibleGoals(), (goal: Goal) => {
              this.GoalCard(goal);
            }, (goal: Goal) => goal.id)
          } else {
            this.EmptyGoalCard()
          }
        }
        }

        Blank().height(SPACE_XS)
      }
      .width('100%')
      .constraintSize({ maxWidth: TODAY_CONTENT_MAX_WIDTH })
      .alignSelf(ItemAlign.Center)
      .padding({ left: COMPACT_PAGE_PADDING, right: COMPACT_PAGE_PADDING, top: COMPACT_PAGE_PADDING, bottom: COMPACT_PAGE_PADDING + BOTTOM_CONTENT_SPACER })
    }
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .backgroundColor(this.themeColors.background)
    .onAreaChange((_oldValue, newValue) => {
      this.updateContentWidth(newValue.width);
    })
  }
}
