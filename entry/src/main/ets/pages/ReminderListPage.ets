import { formatDayEventDate, formatDayEventTime, startOfDay } from '../common/DayEventUtils';
import { DayEvent, DayEventType, ReminderType } from '../models/DayEvent';
import { Task, TaskStatus } from '../models/Task';
import {
  getNextReminderOccurrenceTime,
  getReminderCompletionCandidate,
  getReminderPeriodProgress
} from '../services/ReminderTaskService';
import { db } from '../storage/Database';
import { LightTheme, ThemeColors } from '../theme/AppTheme';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppHeroPanel } from '../ui/base/AppHeroPanel';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppPanelSection } from '../ui/base/AppPanelSection';
import { AppSearchBar } from '../ui/base/AppSearchBar';
import { AppSegmentTabs } from '../ui/base/AppSegmentTabs';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { RADIUS_LG, RADIUS_PILL } from '../foundation/tokens/RadiusTokens';
import { SPACE_LG, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_META } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('ReminderListPage');

interface ReminderDisplayItem {
  event: DayEvent;
  nextOccurrence?: number;
  isToday: boolean;
  completedToday: boolean;
  canCompleteNow: boolean;
  typeText: string;
  summaryText: string;
  progressText: string;
  statusText: string;
  recentText: string;
  goalTag: string;
  pauseStateText: string;
  accentColor: string;
}

@Entry
@Component
struct ReminderListPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State isLoading: boolean = true;
  @State loadError: string = '';
  @State activeItems: ReminderDisplayItem[] = [];
  @State pausedItems: ReminderDisplayItem[] = [];
  @State keyword: string = '';
  @State displayMode: string = 'focus';

  aboutToAppear(): void {
    void this.loadItems();
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch (_) {
    }
  }

  private getTypeText(event: DayEvent): string {
    switch (event.type) {
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
    if (event.type === DayEventType.MILESTONE && event.targetDate) {
      return `关键日期 · ${formatDayEventDate(event.targetDate)}`;
    }
    if (event.reminderRules.length === 0) {
      return '还没有配置提醒规则';
    }

    const rule = event.reminderRules[0];
    switch (rule.type) {
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
    if (!event.isEnabled) {
      return '当前处于长期暂停状态';
    }
    if (event.skipOnceUntil !== undefined && event.skipOnceUntil >= Date.now()) {
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

  private buildStatusText(event: DayEvent, nextOccurrence: number | undefined, completedToday: boolean): string {
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

  private buildItem(event: DayEvent, tasks: Task[]): ReminderDisplayItem {
    const nextOccurrence = getNextReminderOccurrenceTime(event, tasks, Date.now());
    const todayStart = startOfDay(Date.now());
    const completedToday = this.hasCompletedToday(tasks, event.id);
    return {
      event,
      nextOccurrence,
      isToday: nextOccurrence !== undefined && startOfDay(nextOccurrence) === todayStart,
      completedToday,
      canCompleteNow: getReminderCompletionCandidate(event, tasks, Date.now()) !== null,
      typeText: this.getTypeText(event),
      summaryText: this.buildRuleSummary(event),
      progressText: this.buildProgressText(event, tasks),
      statusText: this.buildStatusText(event, nextOccurrence, completedToday),
      recentText: this.buildRecentText(tasks, event),
      goalTag: event.goalTitle || '',
      pauseStateText: this.buildPauseStateText(event),
      accentColor: this.buildAccentColor(event)
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
    this.activeItems = events
      .filter((event: DayEvent) => event.isEnabled)
      .map((event: DayEvent) => this.buildItem(event, tasks))
      .sort((first: ReminderDisplayItem, second: ReminderDisplayItem) => this.compareActiveItems(first, second));
    this.pausedItems = events
      .filter((event: DayEvent) => !event.isEnabled)
      .map((event: DayEvent) => this.buildItem(event, tasks))
      .sort((first: ReminderDisplayItem, second: ReminderDisplayItem) => {
        return (second.event.updatedAt || second.event.createdAt) - (first.event.updatedAt || first.event.createdAt);
      });
  }

  private refreshItemsFromDb(): void {
    this.rebuildItems(db.getAllDayEvents(), db.getAllTasks());
  }

  private async loadItems(): Promise<void> {
    this.isLoading = true;
    this.loadError = '';
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await db.initialize(context as Context);
      this.refreshItemsFromDb();
    } catch (error) {
      logger.error('ReminderListPage load error', error as Object);
      this.activeItems = [];
      this.pausedItems = [];
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
    this.refreshItemsFromDb();
    this.showToast('已跳过 1 次');
  }

  private async pauseIndefinitely(item: ReminderDisplayItem): Promise<void> {
    await db.pauseDayEventIndefinitely(item.event.id);
    this.refreshItemsFromDb();
    this.showToast('已长期暂停');
  }

  private async completeReminder(item: ReminderDisplayItem): Promise<void> {
    const success = await db.completeDayEventOccurrence(item.event.id, Date.now());
    this.showToast(success ? '已标记本次完成' : '当前没有可完成的提醒');
    this.refreshItemsFromDb();
  }

  private async resumeReminder(item: ReminderDisplayItem): Promise<void> {
    await db.resumeDayEvent(item.event.id);
    this.refreshItemsFromDb();
    this.showToast('已恢复提醒');
  }

  private openPauseDialog(item: ReminderDisplayItem): void {
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
          value: '长期暂停',
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

  private openReminderCreate(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DayEventCreatePage' });
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
    return !item.event.isEnabled || (item.event.skipOnceUntil !== undefined && item.event.skipOnceUntil >= Date.now());
  }

  private matchesKeyword(item: ReminderDisplayItem): boolean {
    const query = this.keyword.trim().toLowerCase();
    if (query.length === 0) {
      return true;
    }
    return item.event.title.toLowerCase().includes(query) ||
      item.goalTag.toLowerCase().includes(query) ||
      item.typeText.toLowerCase().includes(query) ||
      item.summaryText.toLowerCase().includes(query);
  }

  private getFilteredItems(items: ReminderDisplayItem[]): ReminderDisplayItem[] {
    return items.filter((item: ReminderDisplayItem) => this.matchesKeyword(item));
  }

  private getFocusItems(): ReminderDisplayItem[] {
    const filtered = this.getFilteredItems(this.activeItems);
    const focusItems = filtered.filter((item: ReminderDisplayItem) => item.isToday || item.completedToday);
    return focusItems.length > 0 ? focusItems : filtered.slice(0, 4);
  }

  private getDisplayedItems(): ReminderDisplayItem[] {
    if (this.displayMode === 'paused') {
      return this.getFilteredItems(this.pausedItems);
    }
    if (this.displayMode === 'all') {
      return this.getFilteredItems(this.activeItems);
    }
    return this.getFocusItems();
  }

  private getDisplayedTitle(): string {
    if (this.displayMode === 'paused') {
      return '已暂停的提醒';
    }
    if (this.displayMode === 'all') {
      return '全部进行中的提醒';
    }
    return '今天优先处理';
  }

  private getDisplayedSubtitle(): string {
    if (this.displayMode === 'paused') {
      return '恢复后会继续自动生成对应的打卡任务和提醒。';
    }
    if (this.displayMode === 'all') {
      return '按下一次触发时间排序，方便你逐条查看和调整。';
    }
    return '优先显示今天要完成和今天刚完成的提醒，适合快速处理。';
  }

  private getTodayPendingCount(): number {
    return this.activeItems.filter((item: ReminderDisplayItem) => item.isToday && !item.completedToday).length;
  }

  private getTodayCompletedCount(): number {
    return this.activeItems.filter((item: ReminderDisplayItem) => item.completedToday).length;
  }

  private getDueNowCount(): number {
    return this.activeItems.filter((item: ReminderDisplayItem) => item.canCompleteNow && !item.completedToday).length;
  }

  private getHeroTitle(): string {
    if (this.displayMode === 'paused') {
      return '暂停中的提醒，也应该有清晰的恢复入口';
    }
    return '把今天的打卡、习惯和关键日期放到同一处处理';
  }

  private getHeroDescription(): string {
    if (this.displayMode === 'paused') {
      return '这里会集中列出你主动暂停或临时跳过的提醒，方便你随时恢复，不会丢掉节奏。';
    }
    return '系统会先把今天要处理的提醒排在前面。你可以直接打卡、跳过一次、长期暂停或查看详情。';
  }

  private getHeroSummary(): string {
    return `待处理 ${this.getTodayPendingCount()} · 可立即处理 ${this.getDueNowCount()} · 已暂停 ${this.pausedItems.length}`;
  }

  private getDisplayModeIndex(): number {
    switch (this.displayMode) {
      case 'all':
        return 1;
      case 'paused':
        return 2;
      default:
        return 0;
    }
  }

  private setDisplayMode(index: number): void {
    switch (index) {
      case 1:
        this.displayMode = 'all';
        return;
      case 2:
        this.displayMode = 'paused';
        return;
      default:
        this.displayMode = 'focus';
    }
  }

  private getStatusTone(item: ReminderDisplayItem): 'neutral' | 'primary' | 'success' | 'warning' {
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
  private StatCard(label: string, value: string, hint: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textMuted)
        .width('100%')

      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Text(hint)
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textMuted)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding(SPACE_MD)
    .backgroundColor(this.themeColors.surfaceRaised)
    .borderRadius(RADIUS_LG)
  }

  @Builder
  private HeroCard() {
    AppHeroPanel({
      eyebrow: '提醒中心',
      title: this.getHeroTitle(),
      description: this.getHeroDescription(),
      tone: 'info'
    }) {
      Column({ space: SPACE_SM }) {
        Text(this.getHeroSummary())
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')

        Row({ space: SPACE_SM }) {
          this.StatCard('待处理', `${this.getTodayPendingCount()}`, '今天还需要完成')
          this.StatCard('已完成', `${this.getTodayCompletedCount()}`, '今天已经处理')
          this.StatCard('已暂停', `${this.pausedItems.length}`, '跳过或长期暂停')
        }
        .width('100%')
      }
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
  private SearchBar() {
    Column({ space: SPACE_SM }) {
      AppSearchBar({
        placeholder: '搜索提醒、习惯或关联目标',
        badgeText: 'AI',
        value: this.keyword,
        editable: true,
        clearable: true,
        insetHorizontal: 0,
        onChange: (value: string) => {
          this.keyword = value;
        }
      })

      Row() {
        AppButton({
          text: '新建提醒',
          variant: 'primary',
          buttonSize: 'sm',
          iconName: 'reminder',
          tapAction: () => {
            this.openReminderCreate();
          }
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
  }

  @Builder
  private ActionButton(item: ReminderDisplayItem) {
    AppButton({
      text: this.canResume(item) ? '恢复' : '暂停',
      variant: 'secondary',
      buttonSize: 'sm',
      iconName: this.canResume(item) ? 'success' : 'warning',
      tapAction: () => {
        if (this.canResume(item)) {
          void this.resumeReminder(item);
          return;
        }
        this.openPauseDialog(item);
      }
    })
  }

  @Builder
  private CompleteButton(item: ReminderDisplayItem) {
    AppButton({
      text: item.completedToday ? '今日已完成' : '标记本次完成',
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
  private ItemRow(item: ReminderDisplayItem) {
    AppCard({
      spacing: SPACE_SM,
      paddingLevel: 'md',
      interactive: true,
      tapAction: () => {
        this.openReminderDetail(item);
      }
    }) {
      Row({ space: SPACE_SM }) {
        Text(this.getTypeBadgeText(item.event))
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(item.accentColor)
          .width(28)
          .height(28)
          .textAlign(TextAlign.Center)
          .backgroundColor(this.themeColors.surfaceSoft)
          .borderRadius(RADIUS_PILL)

        Column({ space: 4 }) {
          Text(item.event.title)
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(item.typeText)
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        AppStatusBadge({
          text: this.getStatusBadgeText(item),
          tone: this.getStatusTone(item),
          iconName: this.getStatusIconName(item)
        })
      }
      .width('100%')

      Text(item.statusText)
        .fontSize(TYPE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Text(item.summaryText)
        .fontSize(TYPE_BODY)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        if (item.goalTag.length > 0) {
          AppStatusBadge({ text: item.goalTag, tone: 'info', iconName: 'goal' })
        }
        AppStatusBadge({ text: item.progressText, tone: 'neutral', iconName: 'progress' })
      }
      .width('100%')

      Text(item.recentText)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      if (item.pauseStateText.length > 0) {
        Text(item.pauseStateText)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.warning)
          .width('100%')
      }

      Row({ space: SPACE_SM }) {
        this.CompleteButton(item)
        this.ActionButton(item)
      }
      .width('100%')
    }
  }

  @Builder
  private EmptyStateCard() {
    AppEmptyState({
      title: this.displayMode === 'paused' ? '还没有暂停中的提醒' : '这里还没有提醒',
      description: this.displayMode === 'paused'
        ? '恢复后的提醒会重新回到执行列表，之后你可以继续按节奏处理。'
        : '先创建一个新的提醒、习惯或关键日期，系统会自动整理到这里。',
      actionText: this.displayMode === 'paused' ? '' : '立即创建提醒',
      actionIconName: 'reminder',
      iconName: this.displayMode === 'paused' ? 'warning' : 'reminder',
      iconTone: this.displayMode === 'paused' ? 'warning' : 'primary',
      onAction: () => {
        this.openReminderCreate();
      }
    })
  }

  build() {
    Column({ space: SPACE_MD }) {
      AppPageHeader({
        title: '提醒中心',
        subtitle: '统一查看今天要处理、已完成和已暂停的提醒',
        onBack: () => {
          this.getUIContext().getRouter().back();
        }
      })

      if (this.isLoading) {
        Column({ space: SPACE_MD }) {
          this.HeroCard()
          AppLoadingState({ label: '正在整理提醒状态...' })
        }
        .width('100%')
        .padding({ left: SPACE_LG, right: SPACE_LG })
      } else {
        Scroll() {
          Column({ space: SPACE_LG }) {
            this.HeroCard()
            this.SearchBar()

            AppSegmentTabs({
              tabs: [
                `今日重点 ${this.getFocusItems().length}`,
                `全部进行中 ${this.getFilteredItems(this.activeItems).length}`,
                `已暂停 ${this.getFilteredItems(this.pausedItems).length}`
              ],
              selectedIndex: this.getDisplayModeIndex(),
              onSelect: (index: number) => {
                this.setDisplayMode(index);
              }
            })

            if (this.loadError.length > 0) {
              this.ErrorBanner()
            }

            AppPanelSection({
              title: this.getDisplayedTitle(),
              subtitle: this.getDisplayedSubtitle()
            }) {
              if (this.getDisplayedItems().length === 0) {
                this.EmptyStateCard()
              } else {
                Column({ space: SPACE_SM }) {
                  ForEach(this.getDisplayedItems(), (item: ReminderDisplayItem) => {
                    this.ItemRow(item)
                  }, (item: ReminderDisplayItem) => `${this.displayMode}_${item.event.id}`)
                }
                .width('100%')
              }
            }

            Blank().height(12)
          }
          .width('100%')
          .padding({ left: SPACE_LG, right: SPACE_LG, bottom: SPACE_LG })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
