import { formatDayEventDate, startOfDay } from '../common/DayEventUtils';
import { Task, TaskPriority, TaskStatus } from '../models/Task';
import { Goal } from '../models/Goal';
import { db } from '../storage/Database';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppCard } from '../ui/base/AppCard';
import { AppChip } from '../ui/base/AppChip';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { SPACE_2XS, SPACE_LG, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { COMPACT_PAGE_PADDING } from '../foundation/tokens/PageTierTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_HERO_TITLE, TYPE_META } from '../foundation/tokens/TypographyTokens';
import { BUTTON_HEIGHT_LG, TASK_LIST_CONTENT_MAX_WIDTH, TASK_LIST_FILTER_PANEL_WIDTH, TASK_LIST_TWO_COLUMN_MIN_WIDTH } from '../foundation/tokens/PageDensityTokens';
import { BOTTOM_CONTENT_SPACER, CHECKBOX_SIZE_SM, ICON_BUTTON_SIZE_SM, TASK_DUE_LABEL_WIDTH, TASK_RAIL_WIDTH_LG, TASK_RAIL_WIDTH_SM } from '../foundation/tokens/ComponentSizeTokens';
import { RADIUS_LG, RADIUS_PILL } from '../foundation/tokens/RadiusTokens';
import { getCardShadow } from '../foundation/tokens/ElevationTokens';

@Component
struct ActionTaskCard {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop task: Task = new Task('', '', '');
  @Prop sourceText: string = '';
  @Prop goalBadgeText: string = '';
  @Prop statusLabel: string = '';
  @Prop statusTone: 'success' | 'danger' | 'warning' | 'neutral' = 'neutral';
  @Prop statusIconName: string = '';
  @Prop dueText: string = '';
  @Prop dueTextColor: string = '';
  @Prop accentColor: string = '';
  @Prop accentSurfaceColor: string = '';
  @Prop cardBackground: string = '';
  @Prop cardBorder: string = '';
  onTap?: () => void;
  @State railHeight: number = BUTTON_HEIGHT_LG;

  build() {
    Row({ space: SPACE_XS }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(TASK_RAIL_WIDTH_LG)
          .height(this.railHeight)
          .backgroundColor(this.accentSurfaceColor)
          .borderRadius(RADIUS_PILL)

        Column()
          .width(TASK_RAIL_WIDTH_SM)
          .height(this.railHeight)
          .backgroundColor(this.accentColor)
          .borderRadius(RADIUS_PILL)
      }
      .width(TASK_RAIL_WIDTH_LG)
      .height(this.railHeight)

      Text(this.task.status === TaskStatus.COMPLETED ? '\u2713' : '')
        .fontSize(TYPE_META)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.success)
        .textAlign(TextAlign.Center)
        .width(CHECKBOX_SIZE_SM)
        .height(CHECKBOX_SIZE_SM)
        .border({
          width: 1.5,
          color: this.task.status === TaskStatus.COMPLETED ? this.themeColors.success : this.themeColors.borderColor
        })
        .borderRadius(RADIUS_PILL)
        .backgroundColor(this.themeColors.surface)

        Column({ space: SPACE_2XS }) {
          Text(this.task.title)
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(this.sourceText)
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            if (this.goalBadgeText.length > 0) {
              AppStatusBadge({ text: this.goalBadgeText, tone: 'neutral', iconName: 'goal' })
            }

            if (this.statusLabel.length > 0) {
              AppStatusBadge({ text: this.statusLabel, tone: this.statusTone, iconName: this.statusIconName })
            }
          }
          .width('100%')

          Text(this.dueText)
            .fontSize(TYPE_CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.dueTextColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.End)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onAreaChange((_oldValue, newValue) => {
        const nextHeight = parseFloat(`${newValue.height}`);
        if (nextHeight > 0 && Math.abs(nextHeight - this.railHeight) > 0.5) {
          this.railHeight = nextHeight;
        }
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: SPACE_SM, right: SPACE_SM, top: SPACE_SM, bottom: SPACE_SM })
    .backgroundColor(this.cardBackground)
    .borderRadius(RADIUS_LG)
    .border({ width: 1, color: this.cardBorder })
    .shadow(getCardShadow(this.themeColors))
    .onClick(() => {
      if (this.onTap) {
        this.onTap();
      }
    })
  }
}

@Component
export struct TaskListTab {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop tasks: Task[] = [];
  @Prop goals: Goal[] = [];
  // embedded=true 时，由外层 Tab（如 ActionTab）统一提供 Header，本组件不再渲染自己的标题区。
  @Prop embedded: boolean = false;
  @State keyword: string = '';
  @State activeFilter: string = 'all';
  @State contentWidth: number = 0;
  // 快照模式：记录用户在当前视图中刚完成的任务 ID，这些任务在排序/过滤中保持原位
  @State recentlyCompletedIds: string[] = [];
  // 记录刚取消完成的任务 ID，确保在刷新前也立即显示为未完成
  @State recentlyUncompletedIds: string[] = [];
  // 快照排序：记录用户完成任务前的列表顺序，确保完成后位置不变
  private snapshotOrder: string[] = [];

  private isTaskRecentlyCompleted(taskId: string): boolean {
    return this.recentlyCompletedIds.indexOf(taskId) >= 0;
  }

  private isTaskRecentlyUncompleted(taskId: string): boolean {
    return this.recentlyUncompletedIds.indexOf(taskId) >= 0;
  }

  private getTaskDisplayStatus(task: Task): TaskStatus {
    if (this.isTaskRecentlyUncompleted(task.id)) {
      return TaskStatus.PENDING;
    }
    if (this.isTaskRecentlyCompleted(task.id)) {
      return TaskStatus.COMPLETED;
    }
    return task.status;
  }

  private isTaskDisplayCompleted(task: Task): boolean {
    return this.getTaskDisplayStatus(task) === TaskStatus.COMPLETED;
  }

  private isTaskDisplayOverdue(task: Task): boolean {
    const effectiveDueTimestamp = task.getEffectiveDueTimestamp();
    return effectiveDueTimestamp !== undefined && effectiveDueTimestamp < Date.now() && !this.isTaskDisplayCompleted(task);
  }

  private invalidateDerivedCaches(): void {
    this.filteredTasksCacheSource = null;
    this.taskCountCacheSource = null;
  }

  private addRecentlyCompletedTask(taskId: string): void {
    if (this.snapshotOrder.length === 0) {
      this.snapshotOrder = this.getFilteredTasks().map((task: Task) => task.id);
    }
    if (this.isTaskRecentlyCompleted(taskId)) {
      return;
    }
    const newIds = this.recentlyCompletedIds.slice();
    newIds.push(taskId);
    this.recentlyCompletedIds = newIds;
    this.invalidateDerivedCaches();
  }

  private removeRecentlyCompletedTask(taskId: string): void {
    const index = this.recentlyCompletedIds.indexOf(taskId);
    if (index < 0) {
      return;
    }
    const newIds = this.recentlyCompletedIds.slice();
    newIds.splice(index, 1);
    this.recentlyCompletedIds = newIds;
    if (newIds.length === 0) {
      this.snapshotOrder = [];
    }
    this.invalidateDerivedCaches();
  }

  private addRecentlyUncompletedTask(taskId: string): void {
    if (this.isTaskRecentlyUncompleted(taskId)) {
      return;
    }
    const newIds = this.recentlyUncompletedIds.slice();
    newIds.push(taskId);
    this.recentlyUncompletedIds = newIds;
    this.invalidateDerivedCaches();
  }

  private removeRecentlyUncompletedTask(taskId: string): void {
    const index = this.recentlyUncompletedIds.indexOf(taskId);
    if (index < 0) {
      return;
    }
    const newIds = this.recentlyUncompletedIds.slice();
    newIds.splice(index, 1);
    this.recentlyUncompletedIds = newIds;
    this.invalidateDerivedCaches();
  }

  private isWideLayout(): boolean {
    return this.contentWidth >= TASK_LIST_TWO_COLUMN_MIN_WIDTH;
  }

  private updateContentWidth(widthValue: Length): void {
    const nextWidth = parseFloat(`${widthValue}`);
    if (nextWidth > 0 && Math.abs(nextWidth - this.contentWidth) > 0.5) {
      this.contentWidth = nextWidth;
    }
  }

  private filteredTasksCacheSource: Task[] | null = null;
  private filteredTasksCacheKeyword: string = '';
  private filteredTasksCacheFilter: string = '';
  private filteredTasksCacheRecentCount: number = -1;
  private filteredTasksCache: Task[] = [];
  private taskCountCacheSource: Task[] | null = null;
  private pendingCountCache: number = 0;
  private importantCountCache: number = 0;
  private overdueCountCache: number = 0;
  private completedCountCache: number = 0;

  private openReschedulePage(): void {
    try {
      this.getUIContext().getRouter().pushUrl({ url: 'pages/ReschedulePage' });
    } catch (_) {}
  }

  private clearKeyword(): void {
    this.keyword = '';
    this.recentlyCompletedIds = [];
    this.recentlyUncompletedIds = [];
    this.snapshotOrder = [];
    this.invalidateDerivedCaches();
  }

  private ensureTaskCountCache(): void {
    if (this.taskCountCacheSource === this.tasks) {
      return;
    }

    let pendingCount = 0;
    let importantCount = 0;
    let overdueCount = 0;
    let completedCount = 0;
    this.tasks.forEach((task: Task) => {
      if (task.status === TaskStatus.COMPLETED) {
        completedCount += 1;
      } else if (task.status === TaskStatus.PENDING) {
        pendingCount += 1;
        if (task.priority === TaskPriority.HIGH) {
          importantCount += 1;
        }
      }
      if (task.isOverdue) {
        overdueCount += 1;
      }
    });

    this.taskCountCacheSource = this.tasks;
    this.pendingCountCache = pendingCount;
    this.importantCountCache = importantCount;
    this.overdueCountCache = overdueCount;
    this.completedCountCache = completedCount;
  }

  private getFilteredTasks(): Task[] {
    const query = this.keyword.trim().toLowerCase();
    const recentCount = this.recentlyCompletedIds.length;
    if (this.filteredTasksCacheSource === this.tasks &&
      this.filteredTasksCacheKeyword === query &&
      this.filteredTasksCacheFilter === this.activeFilter &&
      this.filteredTasksCacheRecentCount === recentCount) {
      return this.filteredTasksCache;
    }

    const recentIds = this.recentlyCompletedIds;

    this.filteredTasksCache = this.tasks
      .filter((task: Task) => {
        // 刚完成的任务始终保留在列表中，不被过滤掉
        const isRecentlyCompleted = recentIds.indexOf(task.id) >= 0;

        if (this.activeFilter === 'important' && task.priority !== TaskPriority.HIGH) {
          return isRecentlyCompleted;
        }
        if (this.activeFilter === 'overdue' && !task.isOverdue) {
          return isRecentlyCompleted;
        }
        if (this.activeFilter === 'completed' && task.status !== TaskStatus.COMPLETED) {
          return false;
        }
        if (this.activeFilter !== 'all' && this.activeFilter !== 'completed' && task.status === TaskStatus.COMPLETED) {
          return isRecentlyCompleted;
        }
        if (query.length === 0) {
          return true;
        }
        const goalText = task.goalTitle ? task.goalTitle.toLowerCase() : '';
        const reminderText = task.reminderTitle ? task.reminderTitle.toLowerCase() : '';
        return task.title.toLowerCase().includes(query) ||
          task.description.toLowerCase().includes(query) ||
          goalText.includes(query) ||
          reminderText.includes(query);
      })
      .sort((first: Task, second: Task) => {
        // 如果有快照顺序，按快照顺序排列
        if (this.snapshotOrder.length > 0) {
          const firstIdx = this.snapshotOrder.indexOf(first.id);
          const secondIdx = this.snapshotOrder.indexOf(second.id);
          if (firstIdx >= 0 && secondIdx >= 0) {
            return firstIdx - secondIdx;
          }
          // 快照中存在的排前面
          if (firstIdx >= 0) {
            return -1;
          }
          if (secondIdx >= 0) {
            return 1;
          }
        }

        // 刚完成的任务在排序中视为 PENDING，保持原位
        const firstStatus = recentIds.indexOf(first.id) >= 0 ? TaskStatus.PENDING : first.status;
        const secondStatus = recentIds.indexOf(second.id) >= 0 ? TaskStatus.PENDING : second.status;

        if (firstStatus !== secondStatus) {
          return firstStatus === TaskStatus.PENDING ? -1 : 1;
        }
        if (first.isOverdue !== second.isOverdue) {
          return first.isOverdue ? -1 : 1;
        }
        if (first.priority !== second.priority) {
          return first.priority === TaskPriority.HIGH ? -1 : 1;
        }
        return (second.updatedAt || 0) - (first.updatedAt || 0);
      });
    this.filteredTasksCacheSource = this.tasks;
    this.filteredTasksCacheKeyword = query;
    this.filteredTasksCacheFilter = this.activeFilter;
    this.filteredTasksCacheRecentCount = recentCount;
    return this.filteredTasksCache;
  }

  private getPendingCount(): number {
    this.ensureTaskCountCache();
    return this.pendingCountCache;
  }

  private getAllCount(): number {
    return this.tasks.length;
  }

  private getImportantCount(): number {
    this.ensureTaskCountCache();
    return this.importantCountCache;
  }

  private getOverdueCount(): number {
    this.ensureTaskCountCache();
    return this.overdueCountCache;
  }

  private getCompletedCount(): number {
    this.ensureTaskCountCache();
    return this.completedCountCache;
  }

  private isActiveFilter(key: string): boolean {
    return this.activeFilter === key;
  }

  private getAIFeatureLabel(): string {
    return this.getOverdueCount() > 0 ? 'AI 重排' : 'AI 整理';
  }

  private getHeaderSubtitle(): string {
    return `待办 ${this.getPendingCount()} 项`;
  }

  private getVisibleTasks(): Task[] {
    return this.getFilteredTasks();
  }

  private truncateText(value: string, maxLength: number): string {
    const text = value.trim();
    if (text.length <= maxLength) {
      return text;
    }
    return `${text.slice(0, maxLength)}...`;
  }

  private formatRelativeDate(timestamp: number, timeText?: string): string {
    const today = startOfDay(Date.now());
    const targetDay = startOfDay(timestamp);
    if (targetDay === today) {
      return timeText ? `今天 ${timeText}` : '今天';
    }
    if (targetDay === today + 86400000) {
      return timeText ? `明天 ${timeText}` : '明天';
    }
    const dateText = formatDayEventDate(timestamp);
    return timeText ? `${dateText} ${timeText}` : dateText;
  }

  private getTaskDueText(task: Task): string {
    if (this.isTaskDisplayCompleted(task)) {
      if (task.completedAt !== undefined) {
        const completedDay = startOfDay(task.completedAt);
        const today = startOfDay(Date.now());
        return completedDay === today ? '今天完成' : `${formatDayEventDate(task.completedAt)} 完成`;
      }
      return '已完成';
    }
    if (task.isOverdue) {
      return '已逾期';
    }
    if (task.dueDate !== undefined) {
      return this.formatRelativeDate(task.dueDate, task.dueTime);
    }
    return '未安排';
  }

  private getTaskStatusLabel(task: Task): string {
    if (this.isTaskDisplayCompleted(task)) {
      return '已完成';
    }
    if (this.isTaskDisplayOverdue(task)) {
      return '逾期';
    }
    if (task.priority === TaskPriority.HIGH) {
      return '重要';
    }
    return '';
  }

  private getTaskStatusTone(task: Task): 'success' | 'danger' | 'warning' | 'neutral' {
    if (this.isTaskDisplayCompleted(task)) {
      return 'success';
    }
    if (this.isTaskDisplayOverdue(task)) {
      return 'danger';
    }
    if (task.priority === TaskPriority.HIGH) {
      return 'warning';
    }
    return 'neutral';
  }

  private getTaskStatusIconName(task: Task): string {
    if (this.isTaskDisplayCompleted(task)) {
      return 'success';
    }
    if (this.isTaskDisplayOverdue(task) || task.priority === TaskPriority.HIGH) {
      return 'warning';
    }
    return '';
  }

  private getTaskAccentColor(task: Task): string {
    if (this.isTaskDisplayCompleted(task)) {
      return this.themeColors.success;
    }
    if (this.isTaskDisplayOverdue(task)) {
      return this.themeColors.danger;
    }
    return this.themeColors.warning;
  }

  private getTaskAccentSurfaceColor(task: Task): string {
    if (this.isTaskDisplayCompleted(task)) {
      return this.themeColors.successSubtle;
    }
    if (this.isTaskDisplayOverdue(task)) {
      return this.themeColors.dangerSubtle;
    }
    return this.themeColors.warningSubtle;
  }

  private getTaskCardBackground(task: Task): string {
    if (this.isTaskDisplayCompleted(task)) {
      return this.themeColors.surfaceSoft;
    }
    return this.themeColors.cardBackground;
  }

  private getTaskCardBorder(task: Task): string {
    if (this.isTaskDisplayOverdue(task)) {
      return this.themeColors.dangerSubtle;
    }
    if (this.isTaskDisplayCompleted(task)) {
      return this.themeColors.successSubtle;
    }
    return this.themeColors.borderColor;
  }

  private getTaskDueTextColor(task: Task): string {
    if (this.isTaskDisplayCompleted(task)) {
      return this.themeColors.success;
    }
    if (this.isTaskDisplayOverdue(task)) {
      return this.themeColors.danger;
    }
    if (task.dueDate === undefined) {
      return this.themeColors.textMuted;
    }
    return this.themeColors.textSecondary;
  }

  private getGoalBadgeText(task: Task): string {
    return this.truncateText(task.goalTitle, 10);
  }

  private chipBackground(active: boolean): string {
    return active ? this.themeColors.primary : this.themeColors.surfaceRaised;
  }

  private chipBorder(active: boolean): string {
    return active ? this.themeColors.primary : this.themeColors.borderColor;
  }

  private chipText(active: boolean): string {
    return active ? this.themeColors.textOnPrimary : this.themeColors.textSecondary;
  }

  @Builder
  private PageHeader() {
    Column({ space: 2 }) {
      Text('行动')
        .fontSize(TYPE_HERO_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
      Text(this.getHeaderSubtitle())
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: COMPACT_PAGE_PADDING, right: COMPACT_PAGE_PADDING, top: 8, bottom: 4 })
  }

  @Builder
  private FilterChip(label: string, key: string, count: number) {
    AppChip({
      label: `${label} ${count}`,
      tone: this.isActiveFilter(key) ? 'primary' : 'neutral',
      active: this.isActiveFilter(key),
      iconName: this.getFilterIconName(key),
      tapAction: () => {
        this.activeFilter = key;
        // 切换筛选时清除快照，让新视图按正常排序显示
        this.recentlyCompletedIds = [];
        this.snapshotOrder = [];
      }
    })
  }

  private getFilterIconName(key: string): string {
    if (key === 'important') {
      return 'warning';
    }
    if (key === 'overdue') {
      return 'reminder';
    }
    if (key === 'completed') {
      return 'success';
    }
    return 'task';
  }

  @Builder
  private SearchAndFilters() {
    Column({ space: SPACE_SM }) {
      Scroll() {
        Row({ space: SPACE_SM }) {
          this.FilterChip('全部', 'all', this.getAllCount())
          this.FilterChip('重要', 'important', this.getImportantCount())
          this.FilterChip('逾期', 'overdue', this.getOverdueCount())
          this.FilterChip('已完成', 'completed', this.getCompletedCount())
        }
      }
      .align(Alignment.Top)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private TaskCheckMark(task: Task) {
    Text(this.isTaskDisplayCompleted(task) ? '\u2713' : '')
      .fontSize(TYPE_META)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.themeColors.success)
      .textAlign(TextAlign.Center)
      .width(ICON_BUTTON_SIZE_SM)
      .height(ICON_BUTTON_SIZE_SM)
      .border({
        width: 1.5,
        color: this.isTaskDisplayCompleted(task) ? this.themeColors.success : this.themeColors.borderColor
      })
      .borderRadius(RADIUS_PILL)
      .backgroundColor(this.themeColors.surface)
      .onClick(() => {
        const isCompleting = !this.isTaskDisplayCompleted(task);
        if (isCompleting) {
          this.addRecentlyCompletedTask(task.id);
        } else {
          this.removeRecentlyCompletedTask(task.id);
        }
        // 清除缓存以强制重新计算
        this.filteredTasksCacheSource = null;
        void (async () => {
          try {
            await db.setTaskCompletion(task.id, isCompleting);
          } catch (_error) {
            if (isCompleting) {
              this.removeRecentlyCompletedTask(task.id);
            } else {
              this.addRecentlyCompletedTask(task.id);
            }
            this.filteredTasksCacheSource = null;
          }
        })();
      })
  }

  @Builder
  private TaskCard(task: Task) {
    AppCard({
      variant: this.isTaskDisplayOverdue(task) ? 'danger' : (this.isTaskDisplayCompleted(task) ? 'soft' : 'base'),
      paddingLevel: 'sm',
      spacing: SPACE_SM,
      interactive: true,
      tapAction: () => {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/TaskDetailPage', params: { taskId: task.id } });
      }
    }) {
      Row({ space: SPACE_SM }) {
        this.TaskCheckMark(task)

        Column({ space: SPACE_XS }) {
          Row({ space: SPACE_SM }) {
            Text(task.title)
              .layoutWeight(1)
              .fontSize(TYPE_BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isTaskDisplayCompleted(task) ? this.themeColors.textSecondary : this.themeColors.textPrimary)
              .decoration({ type: this.isTaskDisplayCompleted(task) ? TextDecorationType.LineThrough : TextDecorationType.None, color: this.themeColors.textMuted })
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.getTaskDueText(task))
              .fontSize(TYPE_META)
              .fontColor(this.getTaskDueTextColor(task))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width(TASK_DUE_LABEL_WIDTH)
              .textAlign(TextAlign.End)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          if (task.goalTitle.trim().length > 0 || this.getTaskStatusLabel(task).length > 0) {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              if (task.goalTitle.trim().length > 0) {
                AppStatusBadge({ text: this.getGoalBadgeText(task), tone: 'neutral', iconName: 'goal' })
              }

              if (this.getTaskStatusLabel(task).length > 0) {
                AppStatusBadge({
                  text: this.getTaskStatusLabel(task),
                  tone: this.getTaskStatusTone(task),
                  iconName: this.getTaskStatusIconName(task)
                })
              }
            }
            .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  @Builder
  private FilterSidebar() {
    Column({ space: SPACE_MD }) {
      Column({ space: SPACE_XS }) {
        Text('状态筛选')
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textMuted)
          .padding({ left: SPACE_XS, bottom: SPACE_2XS })

        this.FilterChip('全部', 'all', this.getAllCount())
        this.FilterChip('重要', 'important', this.getImportantCount())
        this.FilterChip('逾期', 'overdue', this.getOverdueCount())
        this.FilterChip('已完成', 'completed', this.getCompletedCount())
      }
    }
    .width(TASK_LIST_FILTER_PANEL_WIDTH)
    .padding({ top: SPACE_SM, left: SPACE_MD, right: SPACE_MD, bottom: SPACE_MD })
    .backgroundColor(this.themeColors.surfaceSoft)
    .borderRadius(RADIUS_LG)
  }

  build() {
    Scroll() {
      Column({ space: SPACE_SM }) {
        if (!this.embedded) {
          this.PageHeader()
        }

        if (this.isWideLayout()) {

          Row({ space: SPACE_LG }) {
            Column({ space: SPACE_SM }) {
              if (this.getFilteredTasks().length > 0) {
                ForEach(this.getVisibleTasks(), (task: Task) => {
                  this.TaskCard(task)
                }, (task: Task) => `${task.id}_${task.status}_${task.updatedAt}`)
              } else {
                AppEmptyState({
                  title: '当前条件下没有可显示的行动',
                  description: '可以切换筛选条件，或继续创建新的任务。',
                  actionText: `去 ${this.getAIFeatureLabel()}`,
                  actionIconName: 'ai',
                  iconName: 'task',
                  iconTone: 'primary',
                  onAction: () => {
                    this.openReschedulePage();
                  }
                })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            this.FilterSidebar()
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        } else {
          Column({ space: SPACE_SM }) {
            this.SearchAndFilters()

            if (this.getFilteredTasks().length > 0) {
              ForEach(this.getVisibleTasks(), (task: Task) => {
                this.TaskCard(task)
              }, (task: Task) => `${task.id}_${task.status}_${task.updatedAt}`)
            } else {
              AppEmptyState({
                title: '当前条件下没有可显示的行动',
                description: '可以切换筛选条件，或继续创建新的任务。',
                actionText: `去 ${this.getAIFeatureLabel()}`,
                actionIconName: 'ai',
                iconName: 'task',
                iconTone: 'primary',
                onAction: () => {
                  this.openReschedulePage();
                }
              })
            }
          }
          .width('100%')
        }

        Blank().height(BOTTOM_CONTENT_SPACER)
      }
      .width('100%')
      .constraintSize({ maxWidth: TASK_LIST_CONTENT_MAX_WIDTH })
      .alignSelf(ItemAlign.Center)
      .padding({ left: COMPACT_PAGE_PADDING, right: COMPACT_PAGE_PADDING })
    }
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .scrollBar(BarState.Off)
    .onAreaChange((_oldValue, newValue) => {
      this.updateContentWidth(newValue.width);
    })
  }
}
