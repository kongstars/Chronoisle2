import { DayEvent, DayEventType, getEventTypeIcon, getEventTypeLabel } from '../models/DayEvent';
import { Task } from '../models/Task';
import { endOfDay, startOfDay } from '../common/DayEventUtils';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { type AppTone } from '../theme/ThemeSemantics';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppIcon } from '../ui/base/AppIcon';
import { AppButton } from '../ui/base/AppButton';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SPACE_2XS, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { COMPACT_PAGE_PADDING } from '../foundation/tokens/PageTierTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE, TYPE_NUMERIC_MD } from '../foundation/tokens/TypographyTokens';
import { BOTTOM_CONTENT_SPACER, BUTTON_HEIGHT_MD, DATE_CELL_CONTROL_SIZE, REMINDER_ACTION_HEIGHT, REMINDER_ACTION_WIDTH, STATUS_STRIP_HEIGHT, STATUS_STRIP_WIDTH_SM } from '../foundation/tokens/ComponentSizeTokens';
import { ICON_SIZE_LG } from '../foundation/tokens/IconTokens';
import { BUTTON_HEIGHT_LG, TODAY_SIDE_PANEL_WIDTH, TODAY_TWO_COLUMN_MIN_WIDTH } from '../foundation/tokens/PageDensityTokens';
import { RADIUS_MD, RADIUS_SM, RADIUS_XL } from '../foundation/tokens/RadiusTokens';
import { CalendarDaySummary, CalendarReminderItem, getCalendarDaySummary } from '../services/CalendarAggregationService';
import { db } from '../storage/Database';

@Component
export struct CalendarTab {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop dayEvents: DayEvent[] = [];
  @Prop tasks: Task[] = [];
  // embedded=true 时，外层（如 ActionTab）统一提供 Header，本组件不再渲染自己的标题/提醒中心按钮。
  @Prop embedded: boolean = false;
  @State selectedDate: number = startOfDay(Date.now());
  @State isMonthExpanded: boolean = false;
  @State contentWidth: number = 0;
  onOpenReminderCenter?: () => void;

  private isWideLayout(): boolean {
    return this.contentWidth >= TODAY_TWO_COLUMN_MIN_WIDTH;
  }

  private updateContentWidth(widthValue: Length): void {
    const nextWidth = parseFloat(`${widthValue}`);
    if (nextWidth > 0 && Math.abs(nextWidth - this.contentWidth) > 0.5) {
      this.contentWidth = nextWidth;
    }
  }
  private daySummaryCacheTaskSource: Task[] | null = null;
  private daySummaryCacheEventSource: DayEvent[] | null = null;
  private daySummaryCache: Map<number, CalendarDaySummary> = new Map<number, CalendarDaySummary>();
  private visibleRowsCacheSelectedDate: number = -1;
  private visibleRowsCacheExpanded: boolean = false;
  private visibleRowsCache: Date[][] = [];

  private readonly weekdayLabels: string[] = ['一', '二', '三', '四', '五', '六', '日'];

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch (_) {}
  }

  private toDateKey(timestamp: number): string {
    const date = new Date(timestamp);
    const month = `${date.getMonth() + 1}`.padStart(2, '0');
    const day = `${date.getDate()}`.padStart(2, '0');
    return `${date.getFullYear()}-${month}-${day}`;
  }

  private formatSelectedDate(): string {
    const date = new Date(this.selectedDate);
    return `${date.getMonth() + 1}月${date.getDate()}日`;
  }

  private getHeaderTitle(): string {
    const selected = new Date(this.selectedDate);
    return `${selected.getFullYear()}年${selected.getMonth() + 1}月`;
  }

  private getDaySummary(timestamp: number): CalendarDaySummary {
    if (this.daySummaryCacheTaskSource !== this.tasks || this.daySummaryCacheEventSource !== this.dayEvents) {
      this.daySummaryCacheTaskSource = this.tasks;
      this.daySummaryCacheEventSource = this.dayEvents;
      this.daySummaryCache.clear();
    }

    const day = startOfDay(timestamp);
    const cached = this.daySummaryCache.get(day);
    if (cached) {
      return cached;
    }

    const summary = getCalendarDaySummary(this.dayEvents, this.tasks, day);
    this.daySummaryCache.set(day, summary);
    return summary;
  }

  private getSelectedDaySummary(): CalendarDaySummary {
    return this.getDaySummary(this.selectedDate);
  }

  private isDateSelected(date: Date): boolean {
    return this.toDateKey(date.getTime()) === this.toDateKey(this.selectedDate);
  }

  private isToday(date: Date): boolean {
    return this.toDateKey(date.getTime()) === this.toDateKey(Date.now());
  }

  private isDateInCurrentMonth(date: Date): boolean {
    const selected = new Date(this.selectedDate);
    return date.getFullYear() === selected.getFullYear() && date.getMonth() === selected.getMonth();
  }

  private getMonthDates(): Date[] {
    const selected = new Date(this.selectedDate);
    const firstDay = new Date(selected.getFullYear(), selected.getMonth(), 1);
    const firstWeekday = firstDay.getDay() === 0 ? 7 : firstDay.getDay();
    const startOffset = firstWeekday - 1;
    const lastDay = new Date(selected.getFullYear(), selected.getMonth() + 1, 0);
    const lastWeekday = lastDay.getDay() === 0 ? 7 : lastDay.getDay();
    const endOffset = 7 - lastWeekday;
    const total = startOffset + lastDay.getDate() + endOffset;
    const result: Date[] = [];
    for (let index = 0; index < total; index++) {
      result.push(new Date(selected.getFullYear(), selected.getMonth(), index - startOffset + 1));
    }
    return result;
  }

  private getWeekDates(): Date[] {
    const selected = new Date(this.selectedDate);
    const weekday = selected.getDay();
    const offset = weekday === 0 ? 6 : weekday - 1;
    const start = new Date(selected.getFullYear(), selected.getMonth(), selected.getDate() - offset);
    const result: Date[] = [];
    for (let index = 0; index < 7; index++) {
      result.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + index));
    }
    return result;
  }

  private getVisibleRows(): Date[][] {
    if (this.visibleRowsCacheSelectedDate === this.selectedDate && this.visibleRowsCacheExpanded === this.isMonthExpanded) {
      return this.visibleRowsCache;
    }

    const source = this.isMonthExpanded ? this.getMonthDates() : this.getWeekDates();
    const rows: Date[][] = [];
    for (let index = 0; index < source.length; index += 7) {
      rows.push(source.slice(index, index + 7));
    }

    this.visibleRowsCacheSelectedDate = this.selectedDate;
    this.visibleRowsCacheExpanded = this.isMonthExpanded;
    this.visibleRowsCache = rows;
    return this.visibleRowsCache;
  }

  private getSelectedReminderItems(): CalendarReminderItem[] {
    return this.getSelectedDaySummary().reminders;
  }

  private completingEventId: string = '';

  private async completeEvent(item: CalendarReminderItem): Promise<void> {
    const key = `${item.event.id}_${item.occurrenceTime}`;
    if (this.completingEventId === key) return; // 防抖
    this.completingEventId = key;
    const success = await db.completeDayEventOccurrence(item.event.id, item.occurrenceTime);
    this.showToast(success ? '已打卡' : '操作失败');
    if (this.dayEvents.length > 0) {
      this.daySummaryCache.clear();
    }
    this.completingEventId = '';
  }

  private getSelectedTasks(): Task[] {
    return this.getSelectedDaySummary().tasks;
  }

  private getSelectedSummaryText(): string {
    return `${this.getSelectedReminderItems().length} 条提醒 · ${this.getSelectedTasks().length} 个行动`;
  }

  private getCalendarHeaderSubtitle(): string {
    const selected = new Date(this.selectedDate);
    return this.isToday(selected) ? '今天' : `${selected.getMonth() + 1}月${selected.getDate()}日`;
  }

  private getSummaryStatus(summary: CalendarDaySummary): string {
    if (summary.hasOverdueTask || summary.loadLevel >= 2) {
      return 'busy';
    }
    if (summary.actionableCount > 0) {
      return 'moderate';
    }
    return 'idle';
  }

  private getSelectedStatus(): string {
    return this.getSummaryStatus(this.getSelectedDaySummary());
  }

  private getStatusAccentColor(status: string): string {
    if (status === 'busy') {
      return this.themeColors.danger;
    }
    if (status === 'moderate') {
      return this.themeColors.primary;
    }
    return this.themeColors.success;
  }

  private getLoadLevelForDate(date: Date): number {
    return this.getDaySummary(date.getTime()).loadLevel;
  }

  private getDateCellBackground(date: Date): string {
    if (this.isDateSelected(date)) {
      return this.themeColors.primary;
    }
    if (this.isToday(date)) {
      return this.themeColors.surfaceRaised;
    }
    return this.getDateCellBackgroundByLoadLevel(date);
  }

  private getDateCellBorderWidth(date: Date): number {
    if (this.isDateSelected(date)) {
      return 0;
    }
    if (this.isToday(date)) {
      return 2;
    }
    return 1;
  }

  private getDateCellBorderColor(date: Date): string {
    if (this.isDateSelected(date)) {
      return this.themeColors.primary;
    }
    if (this.isToday(date)) {
      return this.themeColors.primary;
    }
    return this.themeColors.divider;
  }

  // 获取日期格子背景色（基于负荷等级）
  private getDateCellBackgroundByLoadLevel(date: Date): string {
    const loadLevel = this.getLoadLevelForDate(date);

    if (this.isDateSelected(date)) {
      return this.themeColors.primary;
    }

    if (this.isToday(date)) {
      return this.themeColors.surfaceRaised;
    }

    // 根据负荷等级给予微妙的背景色提示
    if (loadLevel >= 3) {
      return this.themeColors.dangerSubtle;
    }
    if (loadLevel >= 2) {
      return this.themeColors.warningSubtle;
    }
    if (loadLevel >= 1) {
      return this.themeColors.infoSubtle;
    }
    return this.themeColors.surface;
  }

  private getDateCellGap(): number {
    return SPACE_XS;
  }

  private getDateCellHeight(): number {
    return BUTTON_HEIGHT_LG;
  }

  private getMonthDateBadgeColor(date: Date): string {
    if (this.isDateSelected(date)) {
      return this.themeColors.textOnPrimary;
    }
    if (this.isToday(date)) {
      return this.themeColors.primary;
    }
    return this.isDateInCurrentMonth(date) ? this.themeColors.textPrimary : this.themeColors.textMuted;
  }

  private getReminderMeta(item: CalendarReminderItem): string {
    const parts: string[] = [];
    if (item.event.goalTitle && item.event.goalTitle.trim().length > 0) {
      parts.push(item.event.goalTitle);
    } else {
      parts.push(getEventTypeLabel(item.event.type));
    }
    if (item.progressText.length > 0) {
      parts.push(item.progressText);
    }
    return parts.join(' · ');
  }

  private getReminderStatusTone(item: CalendarReminderItem): AppTone {
    if (item.state === 'completed' || item.state === 'target_met') {
      return 'success';
    }
    if (item.isLate) {
      return 'danger';
    }
    return item.isCountTarget ? 'info' : this.getEventTone(item.event.type);
  }

  private getReminderStatusIconName(item: CalendarReminderItem): string {
    if (item.state === 'completed' || item.state === 'target_met') {
      return 'success';
    }
    if (item.isLate) {
      return 'warning';
    }
    return getEventTypeIcon(item.event.type);
  }

  private isReminderCompleted(item: CalendarReminderItem): boolean {
    return item.state === 'completed' || item.state === 'target_met';
  }

  private canCompleteReminder(item: CalendarReminderItem): boolean {
    return !this.isReminderCompleted(item) && item.occurrenceTime <= endOfDay(Date.now());
  }

  private getReminderDisplayStatus(item: CalendarReminderItem): string {
    if (item.state === 'completed' || item.completedCountOnDate > 0) {
      return '今日已打卡';
    }
    if (item.statusText.length > 0) {
      return item.statusText;
    }
    return item.isCountTarget ? '待打卡' : '待处理';
  }

  private getTaskMeta(task: Task): string {
    if (task.goalTitle && task.goalTitle.length > 0) {
      return task.goalTitle;
    }
    if (task.deadline && task.deadline.length > 0) {
      return task.deadline;
    }
    return '未关联目标';
  }

  private getTaskDaysUntilDue(task: Task): number {
    if (task.dueDate === undefined) {
      return Number.MAX_SAFE_INTEGER;
    }
    return Math.floor((startOfDay(task.dueDate) - startOfDay(Date.now())) / (24 * 60 * 60 * 1000));
  }

  private getTaskUrgencyColor(task: Task): string {
    const daysUntilDue = this.getTaskDaysUntilDue(task);
    if (task.isOverdue || daysUntilDue <= 0) {
      return this.themeColors.danger;
    }
    if (daysUntilDue <= 2) {
      return this.themeColors.warning;
    }
    return this.themeColors.success;
  }

  private getTaskUrgencyText(task: Task): string {
    const daysUntilDue = this.getTaskDaysUntilDue(task);
    if (task.isOverdue || daysUntilDue < 0) {
      return '逾期';
    }
    if (daysUntilDue === 0) {
      return '今日';
    }
    if (daysUntilDue <= 2) {
      return `${daysUntilDue}天内`;
    }
    return '未到期';
  }

  private getTaskUrgencyTone(task: Task): AppTone {
    const daysUntilDue = this.getTaskDaysUntilDue(task);
    if (task.isOverdue || daysUntilDue <= 0) {
      return 'danger';
    }
    if (daysUntilDue <= 2) {
      return 'warning';
    }
    return 'success';
  }

  private getTaskUrgencyIconName(task: Task): string {
    const daysUntilDue = this.getTaskDaysUntilDue(task);
    if (task.isOverdue || daysUntilDue <= 2) {
      return 'warning';
    }
    return 'success';
  }

  private getEventTone(type: DayEventType): AppTone {
    switch (type) {
      case DayEventType.HABIT:
        return 'success';
      case DayEventType.MILESTONE:
        return 'warning';
      case DayEventType.COUNTER:
        return 'premium';
      case DayEventType.COUNTDOWN:
        return 'danger';
      default:
        return 'primary';
    }
  }

  private movePeriod(step: number): void {
    const selected = new Date(this.selectedDate);
    if (this.isMonthExpanded) {
      this.selectedDate = startOfDay(new Date(selected.getFullYear(), selected.getMonth() + step, 1).getTime());
      return;
    }
    selected.setDate(selected.getDate() + step * 7);
    this.selectedDate = startOfDay(selected.getTime());
  }

  private getCalendarExpandActionText(): string {
    return this.isMonthExpanded ? '收起到本周' : '展开全月';
  }

  private toggleMonthExpanded(): void {
    this.isMonthExpanded = !this.isMonthExpanded;
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
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/DayEventDetailPage',
        params: { eventId }
      });
    } catch (_) {}
  }

  @Builder
  private PeriodNavButton(direction: 'prev' | 'next', action: () => void) {
    AppButton({
      text: '',
      iconName: direction === 'prev' ? 'chevron-left' : 'chevron-right',
      variant: 'secondary',
      buttonSize: 'sm',
      tapAction: () => { action(); }
    })
      .width(DATE_CELL_CONTROL_SIZE)
  }

  @Builder
  private CalendarExpandHandle() {
    Column({ space: SPACE_2XS }) {
      Row()
        .width(BUTTON_HEIGHT_LG)
        .height(SPACE_2XS)
        .backgroundColor(this.themeColors.primaryLight)
        .borderRadius(2)
        .opacity(this.isMonthExpanded ? 0.5 : 0.9)

      Text(this.getCalendarExpandActionText())
        .fontSize(TYPE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.primary)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: SPACE_2XS, bottom: SPACE_2XS })
    .onClick(() => {
      this.toggleMonthExpanded();
    })
  }

  @Builder
  private WeekdayHeader() {
    Row({ space: SPACE_2XS }) {
      ForEach(this.weekdayLabels, (label: string) => {
        Text(label)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(TYPE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textMuted)
      }, (label: string) => label)
    }
    .width('100%')
  }

  @Builder
  private DateCell(date: Date) {
    Column({ space: this.getDateCellGap() }) {
      Text(`${date.getDate()}`)
        .width('100%')
        .textAlign(TextAlign.Center)
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getMonthDateBadgeColor(date))
        .opacity(this.isDateInCurrentMonth(date) || this.isDateSelected(date) ? 1 : 0.5)
    }
    .layoutWeight(1)
    .height(this.getDateCellHeight())
    .justifyContent(FlexAlign.Center)
    .padding({ left: SPACE_XS, right: SPACE_XS, top: SPACE_XS, bottom: SPACE_XS })
    .backgroundColor(this.getDateCellBackground(date))
    .borderRadius(RADIUS_MD)
    .border({
      width: this.getDateCellBorderWidth(date),
      color: this.getDateCellBorderColor(date)
    })
    .opacity(this.isDateInCurrentMonth(date) || this.isDateSelected(date) ? 1 : 0.6)
    .onClick(() => {
      this.selectedDate = startOfDay(date.getTime());
    })
  }

  @Builder
  private ReminderRow(item: CalendarReminderItem) {
    Row({ space: SPACE_SM }) {
      Column() {
      }
      .width(STATUS_STRIP_WIDTH_SM)
      .height(STATUS_STRIP_HEIGHT)
      .backgroundColor(this.getStatusAccentColor(this.isReminderCompleted(item) ? 'idle' : this.getSelectedStatus()))
      .borderRadius(RADIUS_SM)

      Column({ space: SPACE_XS }) {
        Text(item.event.title)
          .width('100%')
          .textAlign(TextAlign.Start)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.getReminderMeta(item))
          .width('100%')
          .textAlign(TextAlign.Start)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.canCompleteReminder(item)) {
        Button('打卡')
          .width(REMINDER_ACTION_WIDTH)
          .height(REMINDER_ACTION_HEIGHT)
          .fontSize(TYPE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textOnPrimary)
          .backgroundColor(this.themeColors.primary)
          .padding({ left: 0, right: 0, top: 0, bottom: 0 })
          .borderRadius(RADIUS_SM)
          .onClick(() => {
            void this.completeEvent(item);
          })
      } else {
        AppStatusBadge({
          text: this.getReminderDisplayStatus(item),
          tone: this.getReminderStatusTone(item),
          iconName: this.getReminderStatusIconName(item)
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: SPACE_SM, right: SPACE_SM, top: SPACE_XS, bottom: SPACE_XS })
    .backgroundColor(this.themeColors.surface)
    .borderRadius(RADIUS_MD)
    .border({ width: 1, color: this.themeColors.borderColor })
    .onClick(() => {
      this.openReminderDetail(item.event.id);
    })
  }

  @Builder
  private TaskRow(task: Task) {
    Row({ space: SPACE_SM }) {
      Column() {
      }
      .width(STATUS_STRIP_WIDTH_SM)
      .height(STATUS_STRIP_HEIGHT)
      .backgroundColor(this.getTaskUrgencyColor(task))
      .borderRadius(RADIUS_SM)

      Column({ space: SPACE_XS }) {
        Text(task.title)
          .width('100%')
          .textAlign(TextAlign.Start)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.getTaskMeta(task))
          .width('100%')
          .textAlign(TextAlign.Start)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      AppStatusBadge({
        text: this.getTaskUrgencyText(task),
        tone: this.getTaskUrgencyTone(task),
        iconName: this.getTaskUrgencyIconName(task)
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: SPACE_SM, right: SPACE_SM, top: SPACE_XS, bottom: SPACE_XS })
    .backgroundColor(this.themeColors.surface)
    .borderRadius(RADIUS_MD)
    .border({ width: 1, color: this.themeColors.borderColor })
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/TaskDetailPage',
        params: { taskId: task.id }
      });
    })
  }

  @Builder
  private CalendarPanel() {
    AppCard({ variant: 'base', spacing: SPACE_SM, paddingLevel: 'md' }) {
      Column({ space: SPACE_SM }) {
        Row() {
          this.PeriodNavButton('prev', () => { this.movePeriod(-1); })

          Column({ space: SPACE_2XS }) {
            Text(this.getHeaderTitle())
              .fontSize(TYPE_NUMERIC_MD)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
              .textAlign(TextAlign.Center)
              .width('100%')

            Text(this.isToday(new Date(this.selectedDate)) ? '已定位今天' : '点击回到今天')
              .fontSize(TYPE_META)
              .fontColor(this.themeColors.primary)
              .onClick(() => { this.selectedDate = startOfDay(Date.now()); })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          this.PeriodNavButton('next', () => { this.movePeriod(1); })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        this.WeekdayHeader()

        Column({ space: SPACE_XS }) {
          ForEach(this.getVisibleRows(), (row: Date[], rowIndex: number) => {
            Row({ space: SPACE_XS }) {
              ForEach(row, (date: Date) => {
                this.DateCell(date)
              }, (date: Date) => `${rowIndex}_${date.getTime()}`)
            }
            .width('100%')
          }, (row: Date[], _rowIndex: number) => `${this.selectedDate}_${row[0].getTime()}_${row[row.length - 1].getTime()}`)
        }
        .width('100%')

        this.CalendarExpandHandle()
      }
    }
  }

  @Builder
  private DayContentList() {
    if (this.getSelectedReminderItems().length === 0 && this.getSelectedTasks().length === 0) {
      AppEmptyState({
        title: '这一天还没有提醒或待办',
        description: '可以先去提醒中心补充提醒，或者直接从其他页面安排任务。',
        actionText: '打开提醒中心',
        actionIconName: 'reminder',
        iconName: 'calendar',
        iconTone: 'info',
        onAction: () => { this.openReminderCenter(); }
      })
    } else {
      Column({ space: SPACE_SM }) {
        // 当日摘要
        Text(`${this.formatSelectedDate()} · ${this.getSelectedSummaryText()}`)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')

        if (this.getSelectedReminderItems().length > 0) {
          Column({ space: SPACE_SM }) {
            ForEach(this.getSelectedReminderItems(), (item: CalendarReminderItem) => {
              this.ReminderRow(item)
            }, (item: CalendarReminderItem) => `${item.event.id}_${item.occurrenceTime}_${item.state}`)
          }
          .width('100%')
        }

        if (this.getSelectedTasks().length > 0) {
          Column({ space: SPACE_SM }) {
            ForEach(this.getSelectedTasks(), (task: Task) => {
              this.TaskRow(task)
            }, (task: Task) => task.id)
          }
          .width('100%')
        }
      }
      .width('100%')
    }
  }

  build() {
    Column({ space: SPACE_MD }) {
      // Tab 页标题区（与今日页风格一致）
      if (!this.embedded) {
        Row() {
          Column({ space: 2 }) {
            Text('目标')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
            Text(this.getCalendarHeaderSubtitle())
              .fontSize(14)
              .fontColor(this.themeColors.textSecondary)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          AppButton({
            text: '提醒中心',
            variant: 'secondary',
            buttonSize: 'sm',
            iconName: 'reminder',
            tapAction: () => { this.openReminderCenter(); }
          })
        }
        .width('100%')
        .padding({ left: COMPACT_PAGE_PADDING, right: COMPACT_PAGE_PADDING, top: 8, bottom: 4 })
      }

      if (this.isWideLayout()) {
        Row({ space: SPACE_MD }) {
          Column({ space: SPACE_MD }) {
            this.CalendarPanel()
          }
          .width(TODAY_SIDE_PANEL_WIDTH)

          Scroll() {
            Column({ space: SPACE_MD }) {
              this.DayContentList()
              Blank().height(BOTTOM_CONTENT_SPACER)
            }
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .align(Alignment.TopStart)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .padding({ left: COMPACT_PAGE_PADDING, right: COMPACT_PAGE_PADDING, bottom: 0 })
      } else {
        Scroll() {
          Column({ space: SPACE_MD }) {
            this.CalendarPanel()
            this.DayContentList()
            Blank().height(BOTTOM_CONTENT_SPACER)
          }
          .width('100%')
          .padding({ left: COMPACT_PAGE_PADDING, right: COMPACT_PAGE_PADDING, bottom: 0 })
        }
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .onAreaChange((_oldValue, newValue) => {
      this.updateContentWidth(newValue.width);
    })
  }

}
