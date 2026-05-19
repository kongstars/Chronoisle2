import { formatDayEventDate, startOfDay } from '../common/DayEventUtils';
import { Task, TaskPriority, TaskStatus } from '../models/Task';
import { Goal } from '../models/Goal';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppChip } from '../ui/base/AppChip';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppIcon } from '../ui/base/AppIcon';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppSearchBar } from '../ui/base/AppSearchBar';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SPACE_2XS, SPACE_LG, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { COMPACT_PAGE_PADDING } from '../foundation/tokens/PageTierTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_META } from '../foundation/tokens/TypographyTokens';
import { ICON_SIZE_XS } from '../foundation/tokens/IconTokens';
import { BUTTON_HEIGHT_LG, BUTTON_HEIGHT_SM, TASK_LIST_CONTENT_MAX_WIDTH, TASK_LIST_FILTER_PANEL_WIDTH, TASK_LIST_TWO_COLUMN_MIN_WIDTH } from '../foundation/tokens/PageDensityTokens';
import { BOTTOM_CONTENT_SPACER, CHECKBOX_SIZE_SM, ICON_BUTTON_SIZE_SM, TASK_DUE_LABEL_WIDTH, TASK_RAIL_WIDTH_LG, TASK_RAIL_WIDTH_SM } from '../foundation/tokens/ComponentSizeTokens';
import { RADIUS_LG, RADIUS_PILL, RADIUS_XL } from '../foundation/tokens/RadiusTokens';
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
              AppStatusBadge({ text: this.goalBadgeText, tone: 'primary', iconName: 'goal' })
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
  @State keyword: string = '';
  @State activeFilter: string = 'all';
  @State selectedGoalId: string = '';
  @State goalFilterExpanded: boolean = false;
  @State contentWidth: number = 0;

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
  private filteredTasksCacheGoalId: string = '';
  private filteredTasksCache: Task[] = [];
  private taskCountCacheSource: Task[] | null = null;
  private pendingCountCache: number = 0;
  private importantCountCache: number = 0;
  private overdueCountCache: number = 0;
  private completedCountCache: number = 0;
  private goalFilterOptionsCacheSource: Goal[] | null = null;
  private goalFilterOptionsCache: Goal[] = [];

  private openReschedulePage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/ReschedulePage' });
  }

  private clearKeyword(): void {
    this.keyword = '';
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
    if (this.filteredTasksCacheSource === this.tasks &&
      this.filteredTasksCacheKeyword === query &&
      this.filteredTasksCacheFilter === this.activeFilter &&
      this.filteredTasksCacheGoalId === this.selectedGoalId) {
      return this.filteredTasksCache;
    }

    this.filteredTasksCache = this.tasks
      .filter((task: Task) => {
        if (this.selectedGoalId.length > 0 && task.goalId !== this.selectedGoalId) {
          return false;
        }
        if (this.activeFilter === 'important' && task.priority !== TaskPriority.HIGH) {
          return false;
        }
        if (this.activeFilter === 'overdue' && !task.isOverdue) {
          return false;
        }
        if (this.activeFilter === 'completed' && task.status !== TaskStatus.COMPLETED) {
          return false;
        }
        if (this.activeFilter !== 'all' && this.activeFilter !== 'completed' && task.status === TaskStatus.COMPLETED) {
          return false;
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
        if (first.status !== second.status) {
          return first.status === TaskStatus.PENDING ? -1 : 1;
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
    this.filteredTasksCacheGoalId = this.selectedGoalId;
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

  private getGoalFilterOptions(): Goal[] {
    if (this.goalFilterOptionsCacheSource === this.goals) {
      return this.goalFilterOptionsCache;
    }
    this.goalFilterOptionsCacheSource = this.goals;
    this.goalFilterOptionsCache = this.goals.slice(0, 6);
    return this.goalFilterOptionsCache;
  }

  private isActiveFilter(key: string): boolean {
    return this.activeFilter === key;
  }

  private isGoalSelected(goalId: string): boolean {
    return this.selectedGoalId === goalId;
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

  private getTaskSourceText(task: Task): string {
    if (task.reminderTitle && task.reminderTitle.trim().length > 0) {
      return `来自提醒 · ${task.reminderTitle.trim()}`;
    }
    if (task.description.trim().length > 0) {
      return task.description.trim();
    }
    if (task.goalTitle.trim().length > 0) {
      return `关联目标 · ${task.goalTitle.trim()}`;
    }
    return '未设置补充信息';
  }

  private getTaskDueText(task: Task): string {
    if (task.status === TaskStatus.COMPLETED) {
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
    if (task.status === TaskStatus.COMPLETED) {
      return '已完成';
    }
    if (task.isOverdue) {
      return '逾期';
    }
    if (task.priority === TaskPriority.HIGH) {
      return '重要';
    }
    return '';
  }

  private getTaskStatusTone(task: Task): 'success' | 'danger' | 'warning' | 'neutral' {
    if (task.status === TaskStatus.COMPLETED) {
      return 'success';
    }
    if (task.isOverdue) {
      return 'danger';
    }
    if (task.priority === TaskPriority.HIGH) {
      return 'warning';
    }
    return 'neutral';
  }

  private getTaskStatusIconName(task: Task): string {
    if (task.status === TaskStatus.COMPLETED) {
      return 'success';
    }
    if (task.isOverdue || task.priority === TaskPriority.HIGH) {
      return 'warning';
    }
    return '';
  }

  private getTaskAccentColor(task: Task): string {
    if (task.status === TaskStatus.COMPLETED) {
      return this.themeColors.success;
    }
    if (task.isOverdue) {
      return this.themeColors.danger;
    }
    return this.themeColors.warning;
  }

  private getTaskAccentSurfaceColor(task: Task): string {
    if (task.status === TaskStatus.COMPLETED) {
      return this.themeColors.successSubtle;
    }
    if (task.isOverdue) {
      return this.themeColors.dangerSubtle;
    }
    return this.themeColors.warningSubtle;
  }

  private getTaskCardBackground(task: Task): string {
    if (task.status === TaskStatus.COMPLETED) {
      return this.themeColors.surfaceSoft;
    }
    return this.themeColors.cardBackground;
  }

  private getTaskCardBorder(task: Task): string {
    if (task.isOverdue) {
      return this.themeColors.dangerSubtle;
    }
    if (task.status === TaskStatus.COMPLETED) {
      return this.themeColors.successSubtle;
    }
    return this.themeColors.borderColor;
  }

  private getTaskDueTextColor(task: Task): string {
    if (task.status === TaskStatus.COMPLETED) {
      return this.themeColors.success;
    }
    if (task.isOverdue) {
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

  private getGoalFilterSummary(): string {
    if (this.selectedGoalId.length === 0) {
      return '按目标标签筛选';
    }
    for (let i = 0; i < this.goals.length; i++) {
      if (this.goals[i].id === this.selectedGoalId) {
        return `目标 · ${this.truncateText(this.goals[i].title, 10)}`;
      }
    }
    return '按目标标签筛选';
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
    AppPageHeader({
      title: '行动清单',
      subtitle: this.getHeaderSubtitle(),
      showBack: false
    })
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
  private AllGoalsChip() {
    AppChip({
      label: '全部目标',
      tone: this.selectedGoalId.length === 0 ? 'primary' : 'neutral',
      active: this.selectedGoalId.length === 0,
      iconName: 'goal',
      tapAction: () => {
        this.selectedGoalId = '';
      }
    })
  }

  @Builder
  private GoalFilterRow() {
    Row({ space: SPACE_SM }) {
      Text(this.getGoalFilterSummary())
        .layoutWeight(1)
        .fontSize(TYPE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selectedGoalId.length > 0 ? this.themeColors.primary : this.themeColors.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      AppIcon({
        name: this.goalFilterExpanded ? 'chevron-up' : 'chevron-down',
        iconSize: ICON_SIZE_XS,
        framed: false,
        color: this.themeColors.textMuted
      })
    }
    .width('100%')
    .height(BUTTON_HEIGHT_SM)
    .padding({ left: SPACE_SM, right: SPACE_SM })
    .backgroundColor(this.themeColors.surfaceRaised)
    .borderRadius(RADIUS_XL)
    .border({ width: 1, color: this.selectedGoalId.length > 0 ? this.themeColors.primaryLight : this.themeColors.borderColor })
    .onClick(() => {
      this.goalFilterExpanded = !this.goalFilterExpanded;
    })
  }

  @Builder
  private GoalFilterChip(goal: Goal) {
    AppChip({
      label: this.truncateText(goal.title, 8),
      tone: this.isGoalSelected(goal.id) ? 'primary' : 'neutral',
      active: this.isGoalSelected(goal.id),
      iconName: 'goal',
      tapAction: () => {
        this.selectedGoalId = this.isGoalSelected(goal.id) ? '' : goal.id;
      }
    })
  }

  @Builder
  private SearchAndFilters() {
    Column({ space: SPACE_SM }) {
      AppSearchBar({
        placeholder: '搜索任务、描述或目标',
        value: this.keyword,
        editable: true,
        clearable: true,
        insetHorizontal: 0,
        onChange: (value: string) => {
          this.keyword = value;
        },
        onClear: () => {
          this.clearKeyword();
        }
      })

      Scroll() {
        Row({ space: SPACE_SM }) {
          this.FilterChip('全部', 'all', this.getAllCount())
          this.FilterChip('重要', 'important', this.getImportantCount())
          this.FilterChip('逾期', 'overdue', this.getOverdueCount())
          this.FilterChip('已完成', 'completed', this.getCompletedCount())
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      if (this.getGoalFilterOptions().length > 0) {
        this.GoalFilterRow()

        if (this.goalFilterExpanded) {
          Scroll() {
            Row({ space: SPACE_SM }) {
              this.AllGoalsChip()
              ForEach(this.getGoalFilterOptions(), (goal: Goal) => {
                this.GoalFilterChip(goal)
              }, (goal: Goal) => goal.id)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }
      }
    }
    .width('100%')
  }

  @Builder
  private RescheduleBanner() {
    AppCard({
      variant: 'danger',
      paddingLevel: 'sm',
      spacing: SPACE_SM,
      interactive: true,
      tapAction: () => {
        this.openReschedulePage();
      }
    }) {
      Row({ space: SPACE_SM }) {
        Text(`${this.getOverdueCount()} 个逾期任务待处理`)
          .layoutWeight(1)
          .fontSize(TYPE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        AppButton({
          text: '去 AI 重排',
          variant: 'secondary',
          buttonSize: 'sm',
          fullWidth: true,
          iconName: 'ai',
          tapAction: () => {
            this.openReschedulePage();
          }
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  private TaskCheckMark(task: Task) {
    Text(task.status === TaskStatus.COMPLETED ? '\u2713' : '')
      .fontSize(TYPE_META)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.themeColors.success)
      .textAlign(TextAlign.Center)
      .width(ICON_BUTTON_SIZE_SM)
      .height(ICON_BUTTON_SIZE_SM)
      .border({
        width: 1.5,
        color: task.status === TaskStatus.COMPLETED ? this.themeColors.success : this.themeColors.borderColor
      })
      .borderRadius(RADIUS_PILL)
      .backgroundColor(this.themeColors.surface)
  }

  @Builder
  private TaskCard(task: Task) {
    AppCard({
      variant: task.isOverdue ? 'danger' : (task.status === TaskStatus.COMPLETED ? 'soft' : 'base'),
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
              .fontColor(this.themeColors.textPrimary)
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

          Text(this.getTaskSourceText(task))
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            if (task.goalTitle.trim().length > 0) {
              AppStatusBadge({ text: this.getGoalBadgeText(task), tone: 'primary', iconName: 'goal' })
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

      if (this.getGoalFilterOptions().length > 0) {
        Column({ space: SPACE_XS }) {
          Text('目标筛选')
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textMuted)
            .padding({ left: SPACE_XS, bottom: SPACE_2XS })

          this.AllGoalsChip()
          ForEach(this.getGoalFilterOptions(), (goal: Goal) => {
            this.GoalFilterChip(goal)
          }, (goal: Goal) => goal.id)
        }
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
        this.PageHeader()

        if (this.isWideLayout()) {
          AppSearchBar({
            placeholder: '搜索任务、描述或目标',
            value: this.keyword,
            editable: true,
            clearable: true,
            insetHorizontal: 0,
            onChange: (value: string) => {
              this.keyword = value;
            },
            onClear: () => {
              this.clearKeyword();
            }
          })

          Row({ space: SPACE_LG }) {
            Column({ space: SPACE_SM }) {
              if (this.getOverdueCount() > 0 && this.activeFilter !== 'completed') {
                this.RescheduleBanner()
              }

              if (this.getFilteredTasks().length > 0) {
                ForEach(this.getVisibleTasks(), (task: Task) => {
                  this.TaskCard(task)
                }, (task: Task) => task.id)
              } else {
                AppEmptyState({
                  title: '当前条件下没有可显示的行动',
                  description: '可以切换筛选条件、清空关键词，或继续创建新的任务。',
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

            if (this.getOverdueCount() > 0 && this.activeFilter !== 'completed') {
              this.RescheduleBanner()
            }

            if (this.getFilteredTasks().length > 0) {
              ForEach(this.getVisibleTasks(), (task: Task) => {
                this.TaskCard(task)
              }, (task: Task) => task.id)
            } else {
              AppEmptyState({
                title: '当前条件下没有可显示的行动',
                description: '可以切换筛选条件、清空关键词，或继续创建新的任务。',
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
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .scrollBar(BarState.Off)
    .onAreaChange((_oldValue, newValue) => {
      this.updateContentWidth(newValue.width);
    })
  }
}
