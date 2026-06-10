import dataPreferences from '@ohos.data.preferences';
import { formatDayEventDate, formatDayEventTime, getDayEventOccurrenceTimeOnDate, isDayEventEnded, isDayEventSkipActive, startOfDay } from '../common/DayEventUtils';
import { DayEvent, DayEventData, DayEventType, ReminderType } from '../models/DayEvent';
import { Goal, GoalCategory, GoalData } from '../models/Goal';
import { Task, TaskData, TaskStatus } from '../models/Task';
import { CATEGORIES, CategoryInfo } from '../common/Constants';
import {
  getNextReminderOccurrenceTime,
  getReminderCompletionCandidate,
  getReminderCompletionCount,
  getReminderPeriodProgress
} from '../services/ReminderTaskService';
import { db } from '../storage/Database';
import { LightTheme, ThemeColors } from '../theme/AppTheme';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppIcon } from '../ui/base/AppIcon';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppSegmentTabs } from '../ui/base/AppSegmentTabs';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { ICON_SIZE_XS } from '../foundation/tokens/IconTokens';
import { RADIUS_LG, RADIUS_PILL } from '../foundation/tokens/RadiusTokens';
import { PAGE_PADDING, SECTION_GAP, SPACE_LG, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_HERO_TITLE, TYPE_META, TYPE_NUMERIC_LG } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('ReminderListPage');
const REMINDER_PREFERENCES_NAME: string = 'life_goal_storage';
const REMINDER_GOALS_KEY: string = 'goals';
const REMINDER_TASKS_KEY: string = 'tasks';
const REMINDER_DAY_EVENTS_KEY: string = 'dayEvents';

type ReminderFilter = 'today' | 'all' | 'paused' | 'ended';

interface ReminderDisplayItem {
  event: DayEvent;
  nextOccurrence?: number;
  isToday: boolean;
  completedToday: boolean;
  canCompleteNow: boolean;
  isEnded: boolean;
  isSkipped: boolean;
  typeText: string;
  summaryText: string;
  progressText: string;
  statusText: string;
  recentText: string;
  goalTag: string;
  pauseStateText: string;
  accentColor: string;
  categoryInfo: CategoryInfo | null;
  totalCompletedCount: number;
  periodCompletedCount: number;
  periodTargetCount: number;
  periodLabel: string;
}

interface ReminderSourceData {
  goals: Goal[];
  tasks: Task[];
  events: DayEvent[];
}

@Entry
@Component
struct ReminderListPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State isLoading: boolean = true;
  @State loadError: string = '';
  @State activeItems: ReminderDisplayItem[] = [];
  @State pausedItems: ReminderDisplayItem[] = [];
  @State endedItems: ReminderDisplayItem[] = [];
  @State filter: ReminderFilter = 'all';
  @State refreshTick: number = 0;
  private goals: Goal[] = [];

  aboutToAppear(): void {
    void this.loadItems();
  }

  onPageShow(): void {
    if (!this.isLoading) {
      void this.refreshItemsFromStorage();
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch (_) {
    }
  }

  private parseGoals(json: string): Goal[] {
    try {
      const parsed: Object = JSON.parse(json);
      const data: GoalData[] = parsed as GoalData[];
      return data.map((item: GoalData) => Goal.fromJSON(item));
    } catch (error) {
      logger.error('ReminderListPage parseGoals error', error as Object);
      return [];
    }
  }

  private parseTasks(json: string): Task[] {
    try {
      const parsed: Object = JSON.parse(json);
      const data: TaskData[] = parsed as TaskData[];
      return data.map((item: TaskData) => Task.fromJSON(item));
    } catch (error) {
      logger.error('ReminderListPage parseTasks error', error as Object);
      return [];
    }
  }

  private parseDayEvents(json: string): DayEvent[] {
    try {
      const parsed: Object = JSON.parse(json);
      const data: DayEventData[] = parsed as DayEventData[];
      return data.map((item: DayEventData) => DayEvent.fromJSON(item));
    } catch (error) {
      logger.error('ReminderListPage parseDayEvents error', error as Object);
      return [];
    }
  }

  private async readReminderSourceData(): Promise<ReminderSourceData> {
    const context = this.getUIContext().getHostContext() as Context;
    const prefs = await dataPreferences.getPreferences(context, REMINDER_PREFERENCES_NAME);
    const goalsValue: dataPreferences.ValueType = await prefs.get(REMINDER_GOALS_KEY, '[]');
    const tasksValue: dataPreferences.ValueType = await prefs.get(REMINDER_TASKS_KEY, '[]');
    const dayEventsValue: dataPreferences.ValueType = await prefs.get(REMINDER_DAY_EVENTS_KEY, '[]');
    const goals = this.parseGoals(String(goalsValue));
    const tasks = this.parseTasks(String(tasksValue));
    const events = this.parseDayEvents(String(dayEventsValue));
    logger.info(`ReminderListPage readReminderSourceData - goals: ${goals.length}, tasks: ${tasks.length}, events: ${events.length}`);
    const sourceData: ReminderSourceData = {
      goals,
      tasks,
      events
    };
    return sourceData;
  }

  private getTypeText(event: DayEvent): string {
    switch (event.type) {
      case DayEventType.SINGLE:
        return '单次提醒';
      case DayEventType.HABIT:
        return '习惯养成';
      case DayEventType.COUNTDOWN:
        return '倒计时';
      case DayEventType.MILESTONE:
        return '重要日子';
      case DayEventType.COUNTER:
        return '纪念日';
      default:
        return '周期提醒';
    }
  }

  private getTypeBadgeText(event: DayEvent): string {
    switch (event.type) {
      case DayEventType.SINGLE:
        return '单';
      case DayEventType.HABIT:
        return '习';
      case DayEventType.COUNTDOWN:
        return '倒';
      case DayEventType.MILESTONE:
        return '重';
      case DayEventType.COUNTER:
        return '纪';
      default:
        return '提';
    }
  }

  private buildRuleSummary(event: DayEvent): string {
    if (event.type === DayEventType.COUNTDOWN && event.targetDate) {
      return `目标日期 · ${formatDayEventDate(event.targetDate)}`;
    }
    if (event.type === DayEventType.SINGLE && event.targetDate) {
      const rule = event.reminderRules[0];
      return `提醒时间 · ${formatDayEventDate(event.targetDate)} ${formatDayEventTime(rule?.hour ?? 9, rule?.minute ?? 0)}`;
    }
    if (event.type === DayEventType.MILESTONE && event.targetDate) {
      return `关键日期 · ${formatDayEventDate(event.targetDate)}`;
    }
    if (event.reminderRules.length === 0) {
      return '还没有配置提醒规则';
    }

    const rule = event.reminderRules[0];
    switch (rule.type) {
      case ReminderType.SINGLE_AT:
        return `${formatDayEventDate(event.targetDate || event.startDate)} ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      case ReminderType.HABIT_DAILY:
      case ReminderType.PERIODIC_DAILY:
        return `每天 ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      case ReminderType.PERIODIC_WEEKLY: {
        const weekLabels: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
        return `每${weekLabels[rule.weekday ?? 1]} ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      }
      case ReminderType.PERIODIC_MONTHLY:
        return `每月 ${rule.dayOfMonth ?? 1} 日 ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      case ReminderType.PERIODIC_MONTHLY_LAST_DAY:
        return `每月最后 ${rule.lastDayOffset ?? 0} 天 ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      case ReminderType.PERIODIC_INTERVAL:
        return `每 ${rule.intervalDays ?? 1} 天 ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      case ReminderType.HABIT_WEEKLY_TARGET:
        return `每周目标 ${rule.timesPerPeriod ?? rule.targetCount ?? 1} 次`;
      case ReminderType.HABIT_MONTHLY_TARGET:
        return `每月目标 ${rule.timesPerPeriod ?? rule.targetCount ?? 1} 次`;
      case ReminderType.MILESTONE_LEAD:
        return `提前 ${rule.leadDays ?? 0} 天提醒`;
      case ReminderType.COUNTER_INTERVAL:
      case ReminderType.COUNTER_DATE:
        return '按关键节点提醒';
      default:
        return '提醒规则';
    }
  }

  private buildAccentColor(event: DayEvent): string {
    switch (event.type) {
      case DayEventType.SINGLE:
        return this.themeColors.primary;
      case DayEventType.HABIT:
        return this.themeColors.success;
      case DayEventType.MILESTONE:
        return this.themeColors.warning;
      case DayEventType.COUNTER:
        return this.themeColors.premium;
      case DayEventType.COUNTDOWN:
        return this.themeColors.danger;
      default:
        return this.themeColors.primary;
    }
  }

  private hasCompletedToday(tasks: Task[], eventId: string): boolean {
    const today = startOfDay(Date.now());
    return tasks.some((task: Task) => {
      return task.reminderId === eventId &&
        task.status === TaskStatus.COMPLETED &&
        task.completedAt !== undefined &&
        startOfDay(task.completedAt) === today;
    });
  }

  private formatRelativeDateTime(timestamp?: number): string {
    if (timestamp === undefined) {
      return '暂无执行记录';
    }
    const today = startOfDay(Date.now());
    const targetDay = startOfDay(timestamp);
    const timeText = formatDayEventTime(timestamp);
    if (targetDay === today) {
      return `今天 ${timeText}`;
    }
    if (targetDay === today + 86400000) {
      return `明天 ${timeText}`;
    }
    return `${formatDayEventDate(timestamp)} ${timeText}`;
  }

  private buildRecentText(tasks: Task[], event: DayEvent): string {
    const matchedTasks = tasks
      .filter((task: Task) => task.reminderId === event.id && task.reminderOccurrenceTime !== undefined)
      .sort((first: Task, second: Task) => (second.reminderOccurrenceTime || 0) - (first.reminderOccurrenceTime || 0));
    const latestTime = matchedTasks[0]?.reminderOccurrenceTime;
    return `最近执行 · ${this.formatRelativeDateTime(latestTime)}`;
  }

  private buildPauseStateText(event: DayEvent): string {
    if (event.isCompleted) {
      return '已结束，不再继续提醒';
    }
    if (!event.isEnabled) {
      return '当前处于长期暂停状态';
    }
    if (isDayEventSkipActive(event, Date.now()) && event.skipOnceUntil !== undefined) {
      return `已跳过一次，直到 ${this.formatRelativeDateTime(event.skipOnceUntil)}`;
    }
    return '';
  }

  private buildProgressText(event: DayEvent, tasks: Task[]): string {
    const progress = getReminderPeriodProgress(event, tasks, Date.now());
    if (progress) {
      return `${progress.label} ${progress.completed}/${progress.target}`;
    }
    if (event.goalTitle && event.goalTitle.length > 0) {
      return `关联目标 · ${event.goalTitle}`;
    }
    return this.getTypeText(event);
  }

  private buildStatusText(event: DayEvent, nextOccurrence: number | undefined, completedToday: boolean, isEnded: boolean): string {
    if (isEnded) {
      return '已结束';
    }
    if (!event.isEnabled) {
      return '当前已暂停';
    }
    if (completedToday) {
      return '今天已完成';
    }
    if (nextOccurrence !== undefined) {
      if (startOfDay(nextOccurrence) === startOfDay(Date.now())) {
        return nextOccurrence <= Date.now()
          ? '现在可以打卡'
          : `今天 ${formatDayEventTime(nextOccurrence)}`;
      }
      return `下一次 · ${this.formatRelativeDateTime(nextOccurrence)}`;
    }
    return '等待下一次提醒';
  }

  private isItemEnded(event: DayEvent): boolean {
    return event.isCompleted || isDayEventEnded(event);
  }

  private getCategoryInfoForEvent(event: DayEvent): CategoryInfo | null {
    if (!event.goalId) {
      return null;
    }
    const goal = this.goals.find((g: Goal) => g.id === event.goalId);
    if (!goal) {
      return null;
    }
    const category = goal.category as GoalCategory;
    return CATEGORIES.find((c: CategoryInfo) => c.value === category) || null;
  }

  private buildItem(event: DayEvent, tasks: Task[]): ReminderDisplayItem {
    const now = Date.now();
    const todayStart = startOfDay(now);
    const nextOccurrence = getNextReminderOccurrenceTime(event, tasks, now);
    const completedToday = this.hasCompletedToday(tasks, event.id);
    const isEnded = this.isItemEnded(event);

    const todayOccurrence = getDayEventOccurrenceTimeOnDate(event, now);
    const isToday = (todayOccurrence !== undefined) ||
      (nextOccurrence !== undefined && startOfDay(nextOccurrence) === todayStart) ||
      completedToday;

    const isSkipped = isDayEventSkipActive(event, now);
    const totalCompletedCount = getReminderCompletionCount(tasks, event.id);
    const periodProgress = getReminderPeriodProgress(event, tasks, now);

    return {
      event,
      nextOccurrence,
      isToday,
      completedToday,
      canCompleteNow: getReminderCompletionCandidate(event, tasks, now) !== null,
      isEnded,
      isSkipped,
      typeText: this.getTypeText(event),
      summaryText: this.buildRuleSummary(event),
      progressText: this.buildProgressText(event, tasks),
      statusText: this.buildStatusText(event, nextOccurrence, completedToday, isEnded),
      recentText: this.buildRecentText(tasks, event),
      goalTag: event.goalTitle || '',
      pauseStateText: this.buildPauseStateText(event),
      accentColor: this.buildAccentColor(event),
      categoryInfo: this.getCategoryInfoForEvent(event),
      totalCompletedCount,
      periodCompletedCount: periodProgress?.completed ?? 0,
      periodTargetCount: periodProgress?.target ?? 0,
      periodLabel: periodProgress?.label ?? ''
    };
  }

  private compareActiveItems(first: ReminderDisplayItem, second: ReminderDisplayItem): number {
    const firstPriority = first.isToday ? 0 : (first.completedToday ? 1 : 2);
    const secondPriority = second.isToday ? 0 : (second.completedToday ? 1 : 2);
    if (firstPriority !== secondPriority) {
      return firstPriority - secondPriority;
    }
    if (first.nextOccurrence === undefined && second.nextOccurrence !== undefined) {
      return 1;
    }
    if (first.nextOccurrence !== undefined && second.nextOccurrence === undefined) {
      return -1;
    }
    if (first.nextOccurrence !== undefined && second.nextOccurrence !== undefined && first.nextOccurrence !== second.nextOccurrence) {
      return first.nextOccurrence - second.nextOccurrence;
    }
    return (second.event.updatedAt || second.event.createdAt) - (first.event.updatedAt || first.event.createdAt);
  }

  private rebuildItems(events: DayEvent[], tasks: Task[]): void {
    const built: ReminderDisplayItem[] = [];
    let failCount = 0;
    events.forEach((event: DayEvent) => {
      try {
        built.push(this.buildItem(event, tasks));
      } catch (error) {
        failCount++;
        logger.error(`ReminderListPage buildItem failed: ${event.id}`, error as Object);
      }
    });
    logger.info(`ReminderListPage rebuildItems - total: ${events.length}, built: ${built.length}, failed: ${failCount}`);
    this.endedItems = built
      .filter((item: ReminderDisplayItem) => item.isEnded)
      .sort((first: ReminderDisplayItem, second: ReminderDisplayItem) => {
        return (second.event.updatedAt || second.event.createdAt) - (first.event.updatedAt || first.event.createdAt);
      });
    const notEnded = built.filter((item: ReminderDisplayItem) => !item.isEnded);
    this.activeItems = notEnded
      .filter((item: ReminderDisplayItem) => item.event.isEnabled)
      .sort((first: ReminderDisplayItem, second: ReminderDisplayItem) => this.compareActiveItems(first, second));
    this.pausedItems = notEnded
      .filter((item: ReminderDisplayItem) => !item.event.isEnabled)
      .sort((first: ReminderDisplayItem, second: ReminderDisplayItem) => {
        return (second.event.updatedAt || second.event.createdAt) - (first.event.updatedAt || first.event.createdAt);
      });
    logger.info(`ReminderListPage rebuildItems result - active: ${this.activeItems.length}, paused: ${this.pausedItems.length}, ended: ${this.endedItems.length}`);
  }

  private async refreshItemsFromStorage(): Promise<void> {
    const source = await this.readReminderSourceData();
    this.goals = source.goals;
    this.rebuildItems(source.events, source.tasks);
    this.refreshTick++;
  }

  private async loadItems(): Promise<void> {
    this.isLoading = true;
    this.loadError = '';
    try {
      await this.refreshItemsFromStorage();
    } catch (error) {
      logger.error('ReminderListPage load error', error as Object);
      this.activeItems = [];
      this.pausedItems = [];
      this.endedItems = [];
      this.loadError = '提醒加载失败，请稍后重试。';
    } finally {
      this.isLoading = false;
    }
  }

  private async pauseOnce(item: ReminderDisplayItem): Promise<void> {
    if (item.nextOccurrence === undefined) {
      this.showToast('当前没有可跳过的下一次提醒');
      return;
    }
    await db.pauseDayEventOnce(item.event.id, item.nextOccurrence);
    await this.refreshItemsFromStorage();
    this.showToast('已跳过 1 次');
  }

  private async pauseIndefinitely(item: ReminderDisplayItem): Promise<void> {
    await db.pauseDayEventIndefinitely(item.event.id);
    await this.refreshItemsFromStorage();
    this.showToast('已长期暂停');
  }

  private async completeReminder(item: ReminderDisplayItem): Promise<void> {
    const success = await db.completeDayEventOccurrence(item.event.id, Date.now());
    this.showToast(success ? '已标记本次完成' : '当前没有可完成的提醒');
    await this.refreshItemsFromStorage();
  }

  private async resumeReminder(item: ReminderDisplayItem): Promise<void> {
    await db.resumeDayEvent(item.event.id);
    await this.refreshItemsFromStorage();
    this.showToast('已恢复提醒');
  }

  private async endReminder(item: ReminderDisplayItem): Promise<void> {
    await db.endDayEvent(item.event.id);
    await this.refreshItemsFromStorage();
    this.showToast('已结束这条提醒');
  }

  private isSingleReminder(item: ReminderDisplayItem): boolean {
    return item.event.type === DayEventType.SINGLE;
  }

  private openPauseDialog(item: ReminderDisplayItem): void {
    if (this.isSingleReminder(item)) {
      this.getUIContext().showAlertDialog({
        title: '结束提醒',
        message: `单次提醒“${item.event.title}”不支持跳过一次，你可以直接完成或结束它。`,
        buttons: [
          {
            value: '结束',
            action: () => {
              void this.endReminder(item);
            }
          },
          {
            value: '取消',
            action: () => {}
          }
        ]
      });
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '暂停提醒',
      message: `你想如何暂停“${item.event.title}”？`,
      buttons: [
        {
          value: '跳过一次',
          action: () => {
            void this.pauseOnce(item);
          }
        },
        {
          value: '无限暂停',
          action: () => {
            void this.pauseIndefinitely(item);
          }
        },
        {
          value: '取消',
          action: () => {}
        }
      ]
    });
  }

  private openEndDialog(item: ReminderDisplayItem): void {
    this.getUIContext().showAlertDialog({
      title: '结束提醒',
      message: `结束后将不再提醒“${item.event.title}”，你可以稍后从已结束列表中恢复。`,
      buttons: [
        {
          value: '取消',
          action: () => {}
        },
        {
          value: '结束',
          action: () => {
            void this.endReminder(item);
          }
        }
      ]
    });
  }

  private openReminderCreate(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DayEventCreatePage' });
  }

  private openSearchPage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SearchPage', params: { scope: 'reminder' } });
  }

  private openReminderDetail(item: ReminderDisplayItem): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/DayEventDetailPage',
      params: {
        eventId: item.event.id
      }
    });
  }

  private canResume(item: ReminderDisplayItem): boolean {
    return !item.event.isEnabled || isDayEventSkipActive(item.event, Date.now());
  }

  private getTodayItems(): ReminderDisplayItem[] {
    return this.activeItems.filter((item: ReminderDisplayItem) => item.isToday || item.completedToday);
  }

  private getDisplayedItems(): ReminderDisplayItem[] {
    if (this.filter === 'paused') {
      return this.pausedItems;
    }
    if (this.filter === 'ended') {
      return this.endedItems;
    }
    if (this.filter === 'all') {
      return this.activeItems;
    }
    return this.getTodayItems();
  }

  private getTodayPendingCount(): number {
    return this.activeItems.filter((item: ReminderDisplayItem) => item.isToday && !item.completedToday).length;
  }

  private getFilterIndex(): number {
    switch (this.filter) {
      case 'today':
        return 0;
      case 'all':
        return 1;
      case 'paused':
        return 2;
      case 'ended':
        return 3;
      default:
        return 1;
    }
  }

  private setFilterByIndex(index: number): void {
    switch (index) {
      case 1:
        this.filter = 'all';
        return;
      case 2:
        this.filter = 'paused';
        return;
      case 3:
        this.filter = 'ended';
        return;
      default:
        this.filter = 'today';
    }
  }

  private getStatusTone(item: ReminderDisplayItem): 'neutral' | 'primary' | 'success' | 'warning' {
    if (item.isEnded) {
      return 'neutral';
    }
    if (item.completedToday) {
      return 'success';
    }
    if (this.canResume(item)) {
      return 'warning';
    }
    if (item.isToday) {
      return 'primary';
    }
    return 'neutral';
  }

  private getStatusBadgeText(item: ReminderDisplayItem): string {
    if (item.isEnded) {
      return '已结束';
    }
    if (item.completedToday) {
      return '今日已完成';
    }
    if (this.canResume(item)) {
      return '已暂停';
    }
    if (item.isToday) {
      return '今日重点';
    }
    return '进行中';
  }

  private getStatusIconName(item: ReminderDisplayItem): string {
    if (item.isEnded) {
      return 'archive';
    }
    if (item.completedToday) {
      return 'success';
    }
    if (this.canResume(item)) {
      return 'warning';
    }
    if (item.isToday) {
      return 'reminder';
    }
    return 'info';
  }

  @Builder
  private SummaryCard() {
    AppCard({ variant: 'soft', spacing: SPACE_XS, paddingLevel: 'md' }) {
      Text('你的重要提醒都在这里')
        .fontSize(TYPE_HERO_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Text('系统会根据优先级自动排序，你可以按实际情况完成、暂停或结束每个提醒。')
        .fontSize(TYPE_META)
        .lineHeight(20)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  @Builder
  private ErrorBanner() {
    AppCard({ variant: 'danger', spacing: SPACE_SM, paddingLevel: 'md' }) {
      Text('提醒加载失败')
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.danger)

      Text(this.loadError)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Row() {
        AppButton({
          text: '重试',
          variant: 'secondary',
          buttonSize: 'sm',
          iconName: 'warning',
          tapAction: () => {
            void this.loadItems();
          }
        })
      }
    }
  }

  @Builder
  private ActionButton(item: ReminderDisplayItem) {
    AppButton({
      text: this.canResume(item) ? '恢复' : (this.isSingleReminder(item) ? '结束' : '暂停'),
      variant: 'secondary',
      buttonSize: 'sm',
      iconName: this.canResume(item) ? 'success' : (this.isSingleReminder(item) ? 'archive' : 'warning'),
      tapAction: () => {
        if (this.canResume(item)) {
          void this.resumeReminder(item);
          return;
        }
        if (this.isSingleReminder(item)) {
          this.openEndDialog(item);
          return;
        }
        this.openPauseDialog(item);
      }
    })
  }

  @Builder
  private CompleteButton(item: ReminderDisplayItem) {
    AppButton({
      text: item.completedToday ? (this.isSingleReminder(item) ? '已完成' : '今日已完成') : (this.isSingleReminder(item) ? '完成' : '标记本次完成'),
      variant: 'primary',
      buttonSize: 'sm',
      iconName: 'success',
      disabled: !item.canCompleteNow || item.completedToday,
      tapAction: () => {
        void this.completeReminder(item);
      }
    })
  }

  @Builder
  private EndButton(item: ReminderDisplayItem) {
    AppButton({
      text: '结束',
      variant: 'ghost',
      buttonSize: 'sm',
      iconName: 'archive',
      tapAction: () => {
        this.openEndDialog(item);
      }
    })
  }

  @Builder
  private RestoreButton(item: ReminderDisplayItem) {
    AppButton({
      text: '恢复',
      variant: 'secondary',
      buttonSize: 'sm',
      iconName: 'success',
      tapAction: () => {
        void this.resumeReminder(item);
      }
    })
  }

  @Builder
  private CategoryTag(item: ReminderDisplayItem) {
    if (item.categoryInfo !== null) {
      Text(item.categoryInfo.label)
        .fontSize(TYPE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(item.categoryInfo.color)
        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
        .backgroundColor(this.themeColors.surfaceSoft)
        .borderRadius(4)
    }
  }

  @Builder
  private ItemRow(item: ReminderDisplayItem) {
    AppCard({
      spacing: SPACE_XS,
      paddingLevel: 'md',
      interactive: true,
      tapAction: () => {
        this.openReminderDetail(item);
      }
    }) {
      // 标题行：分类标签 + 标题 + 状态徽章
      Row({ space: SPACE_XS }) {
        this.CategoryTag(item)

        Text(item.event.title)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        AppStatusBadge({
          text: this.getStatusBadgeText(item),
          tone: this.getStatusTone(item),
          iconName: this.getStatusIconName(item)
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 次信息行：类型 · 规则
      Text(`${item.typeText} 路 ${item.summaryText}`)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 状态文案：下次触发 / 现在可打卡 / 已暂停等
      Text(item.statusText)
        .fontSize(TYPE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      // 进度统计：完成次数 · 当前周期进度 · 是否跳过
      Row({ space: SPACE_SM }) {
        Text(`完成 ${item.totalCompletedCount}`)
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textSecondary)

        if (item.periodTargetCount > 0) {
          Text('路')
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textMuted)
          Text(`${item.periodLabel} ${item.periodCompletedCount}/${item.periodTargetCount}`)
            .fontSize(TYPE_CAPTION)
            .fontColor(item.periodCompletedCount >= item.periodTargetCount ? this.themeColors.success : this.themeColors.primary)
            .fontWeight(FontWeight.Medium)
        }

        if (item.isSkipped) {
          Text('路')
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textMuted)
          Text('已跳过 1 次')
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.warning)
        }
      }
      .width('100%')

      // 操作按钮区
      if (item.isEnded) {
        Row({ space: SPACE_SM }) {
          this.RestoreButton(item)
        }
        .width('100%')
      } else {
        Row({ space: SPACE_SM }) {
          this.CompleteButton(item)
          this.ActionButton(item)
          if (!this.isSingleReminder(item)) {
            this.EndButton(item)
          }
        }
        .width('100%')
      }
    }
  }

  @Builder
  private EmptyStateCard() {
    AppCard({ variant: 'soft', spacing: SPACE_XS, paddingLevel: 'sm' }) {
      AppIcon({
        name: this.filter === 'paused' ? 'warning' : (this.filter === 'ended' ? 'archive' : 'reminder'),
        iconSize: 32,
        tone: this.filter === 'paused' ? 'warning' : (this.filter === 'ended' ? 'neutral' : 'primary')
      })
      Text(this.filter === 'paused'
        ? '还没有暂停中的提醒'
        : (this.filter === 'ended' ? '还没有已结束的提醒' : '这里还没有提醒'))
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
      Text(this.filter === 'paused'
        ? '恢复后的提醒会重新回到执行列表，之后你可以继续按节奏处理。'
        : (this.filter === 'ended'
          ? '完成的关键日子或主动结束的提醒会归档到这里，方便回看。'
          : '点击底部“新建提醒”按钮，开始记录你的第一条提醒。'))
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  build() {
    Column() {
      AppPageHeader({
        title: '提醒中心',
        subtitle: '统一查看今天要处理、已完成、已暂停和已结束的提醒',
        actionIconName: 'search',
        onBack: () => {
          this.getUIContext().getRouter().back();
        },
        onAction: () => {
          this.openSearchPage();
        }
      })

      if (this.isLoading) {
        Column({ space: SPACE_MD }) {
          AppLoadingState({ label: '正在整理提醒状态...' })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING })
      } else {
        Scroll() {
          Column({ space: SECTION_GAP }) {
            AppSegmentTabs({
              tabs: [
                `今日 ${this.getTodayItems().length}`,
                `全部 ${this.activeItems.length}`,
                `暂停 ${this.pausedItems.length}`,
                `已结束 ${this.endedItems.length}`
              ],
              selectedIndex: this.getFilterIndex(),
              onSelect: (index: number) => {
                this.setFilterByIndex(index);
              }
            })

            if (this.loadError.length > 0) {
              this.ErrorBanner()
            }

            if (this.getDisplayedItems().length === 0) {
              this.EmptyStateCard()
            } else {
              Column({ space: SPACE_SM }) {
                ForEach(this.getDisplayedItems(), (item: ReminderDisplayItem) => {
                  this.ItemRow(item)
                }, (item: ReminderDisplayItem) => `${this.refreshTick}_${this.filter}_${item.event.id}`)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: SPACE_SM, bottom: PAGE_PADDING + 80 })
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)
        .scrollBar(BarState.Off)

        // 固定底部按钮
        Column() {
          AppButton({
            text: '新建提醒',
            variant: 'primary',
            fullWidth: true,
            iconName: 'reminder',
            tapAction: () => {
              this.openReminderCreate();
            }
          })
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: SPACE_SM, bottom: SPACE_LG })
        .backgroundColor(this.themeColors.surface)
        .border({ width: { top: 1 }, color: this.themeColors.borderColor })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
