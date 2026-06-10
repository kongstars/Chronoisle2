import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { db } from '../storage/Database';
import { Goal } from '../models/Goal';
import { Task, TaskStatus } from '../models/Task';
import { DayEvent, DayEventType, getEventTypeIcon } from '../models/DayEvent';
import { getDayEventMetricText } from '../common/DayEventUtils';
import { TelemetryService, type TelemetryProperties } from '../services/TelemetryService';
import { AppCard } from '../ui/base/AppCard';
import { AppIcon } from '../ui/base/AppIcon';
import { AppButton } from '../ui/base/AppButton';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { RADIUS_PILL } from '../foundation/tokens/RadiusTokens';
import { TYPE_BODY, TYPE_META, TYPE_PAGE_TITLE, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { ICON_SIZE_SM } from '../foundation/tokens/IconTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('SearchPage');

interface SearchPageParams {
  keyword?: string;
}

interface RenderableTaskEntry {
  renderKey: string;
  taskId: string;
  title: string;
  subtitle: string;
  deadlineText: string;
  deadlineColor: string;
  isOverdue: boolean;
}

interface SearchListRow {
  rowKey: string;
  rowType: 'header' | 'goal' | 'event' | 'task';
  title?: string;
  count?: number;
  goal?: Goal;
  event?: DayEvent;
  taskEntry?: RenderableTaskEntry;
}

@Entry
@Component
struct SearchPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State keyword: string = '';
  @State goals: Goal[] = [];
  @State tasks: Task[] = [];
  @State events: DayEvent[] = [];
  @State filteredGoals: Goal[] = [];
  @State filteredEvents: DayEvent[] = [];
  @State filteredTaskEntries: RenderableTaskEntry[] = [];
  @State resultRows: SearchListRow[] = [];
  @State totalResultCount: number = 0;
  @State isLoading: boolean = true;
  private hasLoadedEntryParams: boolean = false;
  private lastTrackedQuery: string = '';

  aboutToAppear(): void {
    this.applyEntryParams();
    void this.loadData();
  }

  private applyEntryParams(): void {
    if (this.hasLoadedEntryParams) {
      return;
    }
    this.hasLoadedEntryParams = true;
    const params = this.getUIContext().getRouter().getParams() as SearchPageParams;
    if (params && params.keyword) {
      this.keyword = params.keyword;
    }
  }

  private async loadData(): Promise<void> {
    this.isLoading = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await db.initialize(context);
      this.goals = db.getAllGoals()
        .filter((goal: Goal) => !goal.isArchived)
        .sort((first: Goal, second: Goal) => (second.updatedAt || second.createdAt) - (first.updatedAt || first.createdAt));
      this.tasks = db.getAllTasks()
        .sort((first: Task, second: Task) => (second.updatedAt || second.createdAt) - (first.updatedAt || first.createdAt));
      this.events = db.getAllDayEvents()
        .sort((first: DayEvent, second: DayEvent) => (second.updatedAt || second.createdAt) - (first.updatedAt || first.createdAt));
      this.refreshResults();
    } catch (error) {
      logger.error('SearchPage load error', error as Object);
      this.goals = [];
      this.tasks = [];
      this.events = [];
      this.refreshResults();
    } finally {
      this.isLoading = false;
      this.trackSearchIfNeeded();
    }
  }

  private normalize(value: string | undefined): string {
    return (value || '').trim().toLowerCase();
  }

  private containsQuery(value: string | undefined, query: string): boolean {
    return this.normalize(value).includes(query);
  }

  private getQuery(): string {
    return this.normalize(this.keyword);
  }

  private hasQuery(): boolean {
    return this.getQuery().length > 0;
  }

  private buildFilteredGoals(query: string): Goal[] {
    if (!query) {
      return [];
    }
    return this.goals.filter((goal: Goal) => {
      return this.containsQuery(goal.title, query) ||
        this.containsQuery(goal.description, query) ||
        this.containsQuery(goal.category as string, query);
    });
  }

  private buildFilteredEvents(query: string): DayEvent[] {
    if (!query) {
      return [];
    }
    return this.events.filter((event: DayEvent) => {
      return this.containsQuery(event.title, query) || this.containsQuery(event.goalTitle, query);
    });
  }

  private dedupeTasksById(tasks: Task[]): Task[] {
    const seenTaskIds: Set<string> = new Set();
    const uniqueTasks: Task[] = [];
    tasks.forEach((task: Task) => {
      if (seenTaskIds.has(task.id)) {
        return;
      }
      seenTaskIds.add(task.id);
      uniqueTasks.push(task);
    });
    return uniqueTasks;
  }

  private buildFilteredTasks(query: string): Task[] {
    if (!query) {
      return [];
    }
    const matchedTasks = this.tasks.filter((task: Task) => {
      return this.containsQuery(task.title, query) ||
        this.containsQuery(task.description, query) ||
        this.containsQuery(task.goalTitle, query);
    });
    return this.dedupeTasksById(matchedTasks);
  }

  private canRenderTask(task: Task): boolean {
    try {
      const title = task.title || '';
      const goalText = this.getTaskGoalText(task);
      const description = this.getTaskDescriptionText(task);
      const statusText = this.getTaskStatusText(task);
      const tone = this.getTaskTone(task);
      const iconName = this.getTaskStatusIconName(task);
      const deadlineText = task.deadline && task.deadline.length > 0 ? task.deadline : '未设置日期';
      return title.length >= 0 &&
        goalText.length >= 0 &&
        description.length >= 0 &&
        statusText.length >= 0 &&
        tone.length >= 0 &&
        iconName.length >= 0 &&
        deadlineText.length >= 0;
    } catch (error) {
      logger.warn('SearchPage skip invalid task', error as Object);
      return false;
    }
  }

  private buildRenderableTaskEntries(tasks: Task[]): RenderableTaskEntry[] {
    return tasks.filter((task: Task) => this.canRenderTask(task)).map((task: Task, index: number) => {
      const entry: RenderableTaskEntry = {
        renderKey: `${task.id}_${task.status}_${task.updatedAt}_${index}`,
        taskId: task.id,
        title: task.title || '',
        subtitle: this.getTaskRowSubtitle(task),
        deadlineText: task.deadline && task.deadline.length > 0 ? task.deadline : '未设置日期',
        deadlineColor: this.getTaskTrailingColor(task),
        isOverdue: task.isOverdue
      };
      return entry;
    });
  }

  private buildResultRows(goals: Goal[], events: DayEvent[], taskEntries: RenderableTaskEntry[], totalResultCount: number): SearchListRow[] {
    const rows: SearchListRow[] = [];

    if (totalResultCount === 0) {
      return rows;
    }

    if (goals.length > 0) {
      rows.push({ rowKey: `header_goals_${goals.length}`, rowType: 'header', title: '目标', count: goals.length });
      goals.forEach((goal: Goal) => {
        rows.push({ rowKey: `goal_${goal.id}`, rowType: 'goal', goal });
      });
    }

    if (events.length > 0) {
      rows.push({ rowKey: `header_events_${events.length}`, rowType: 'header', title: '提醒', count: events.length });
      events.forEach((event: DayEvent) => {
        rows.push({ rowKey: `event_${event.id}`, rowType: 'event', event });
      });
    }

    if (taskEntries.length > 0) {
      rows.push({ rowKey: `header_tasks_${taskEntries.length}`, rowType: 'header', title: '任务', count: taskEntries.length });
      taskEntries.forEach((taskEntry: RenderableTaskEntry) => {
        rows.push({ rowKey: `task_${taskEntry.renderKey}`, rowType: 'task', taskEntry });
      });
    }

    return rows;
  }

  private refreshResults(): void {
    const query = this.getQuery();
    const nextGoals = this.buildFilteredGoals(query);
    const nextEvents = this.buildFilteredEvents(query);
    const nextTasks = this.buildFilteredTasks(query);
    const nextTaskEntries = this.buildRenderableTaskEntries(nextTasks);
    const nextTotalResultCount = nextGoals.length + nextEvents.length + nextTaskEntries.length;

    this.filteredGoals = nextGoals;
    this.filteredEvents = nextEvents;
    this.filteredTaskEntries = nextTaskEntries;
    this.totalResultCount = nextTotalResultCount;
    this.resultRows = this.buildResultRows(nextGoals, nextEvents, nextTaskEntries, nextTotalResultCount);
  }

  private getGoalStatusText(goal: Goal): string {
    return goal.progress >= 100 ? '已完成' : '进行中';
  }

  private getTaskGoalText(task: Task): string {
    return task.goalTitle && task.goalTitle.length > 0 ? task.goalTitle : '未关联目标';
  }

  private getTaskDescriptionText(task: Task): string {
    return (task.description || '').trim();
  }

  private getTaskStatusText(task: Task): string {
    if (task.status === TaskStatus.COMPLETED) {
      return '已完成';
    }
    if (task.isOverdue) {
      return '已逾期';
    }
    return '待处理';
  }

  private getTaskTone(task: Task): 'success' | 'warning' | 'neutral' {
    if (task.status === TaskStatus.COMPLETED) {
      return 'success';
    }
    if (task.isOverdue) {
      return 'warning';
    }
    return 'neutral';
  }

  private getTaskStatusIconName(task: Task): string {
    if (task.status === TaskStatus.COMPLETED) {
      return 'success';
    }
    if (task.isOverdue) {
      return 'warning';
    }
    return 'task';
  }

  private getTaskRowSubtitle(task: Task): string {
    const parts: string[] = [];
    const goalText = this.getTaskGoalText(task);
    const description = this.getTaskDescriptionText(task);
    if (goalText.length > 0) {
      parts.push(goalText);
    }
    if (description.length > 0) {
      parts.push(description);
    }
    return parts.join(' · ');
  }

  private getTaskTrailingColor(task: Task): string {
    if (task.status === TaskStatus.COMPLETED) {
      return this.themeColors.success;
    }
    if (task.isOverdue) {
      return this.themeColors.warning;
    }
    return this.themeColors.textMuted;
  }

  private getTaskIndicatorColor(task: Task): string {
    if (task.status === TaskStatus.COMPLETED) {
      return this.themeColors.success;
    }
    if (task.isOverdue) {
      return this.themeColors.warning;
    }
    return this.themeColors.primary;
  }

  private getEventTypeText(event: DayEvent): string {
    switch (event.type) {
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
        return '提醒';
    }
  }

  private clearKeyword(): void {
    this.keyword = '';
    this.lastTrackedQuery = '';
    this.refreshResults();
  }

  private trackSearchIfNeeded(): void {
    if (this.isLoading) {
      return;
    }
    const query = this.getQuery();
    if (!query || query === this.lastTrackedQuery) {
      return;
    }
    this.lastTrackedQuery = query;
    const searchProps: TelemetryProperties = {
      "resultCount": this.totalResultCount
    };
    TelemetryService.track('search_performed', searchProps, 'search');
  }

  private openGoal(goal: Goal): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/GoalDetailPage', params: { goalId: goal.id } });
  }

  private openTaskById(taskId: string): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/TaskDetailPage', params: { taskId } });
  }

  private openEvent(event: DayEvent): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/DayEventDetailPage',
      params: { eventId: event.id }
    });
  }

  @Builder
  private SearchHeader() {
    Column({ space: SPACE_SM }) {
      Row({ space: SPACE_SM }) {
        AppButton({
          text: '',
          iconName: 'chevron-left',
          variant: 'secondary',
          buttonSize: 'sm',
          tapAction: () => {
            this.getUIContext().getRouter().back();
          }
        })
          .width(38)

        Text('搜索')
          .fontSize(TYPE_PAGE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .layoutWeight(1)
      }
      .width('100%')

      Row({ space: 10 }) {
        AppIcon({
          name: 'search',
          iconSize: ICON_SIZE_SM,
          framed: false,
          color: this.themeColors.textMuted
        })

        TextInput({ placeholder: '搜索目标、提醒和任务', text: this.keyword })
          .layoutWeight(1)
          .height(40)
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textPrimary)
          .backgroundColor(Color.Transparent)
          .placeholderColor(this.themeColors.textMuted)
          .padding({ left: 0, right: 0, top: 0, bottom: 0 })
          .onChange((value: string) => {
            this.keyword = value;
            this.refreshResults();
            this.trackSearchIfNeeded();
          })

        if (this.keyword.trim().length > 0) {
          Stack({ alignContent: Alignment.Center }) {
            AppIcon({
              name: 'close',
              iconSize: ICON_SIZE_SM,
              framed: false,
              color: this.themeColors.textMuted
            })
          }
          .width(28)
          .height(28)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.clearKeyword();
          })
        }
      }
      .width('100%')
      .height(48)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 14, right: 10 })
      .backgroundColor(this.themeColors.surfaceSoft)
      .borderRadius(RADIUS_PILL)
      .border({ width: 1, color: this.themeColors.borderColor })
    }
    .width('100%')
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: PAGE_PADDING, bottom: 4 })
  }

  @Builder
  private SectionHeader(title: string, count: number) {
    Row() {
      Text(title)
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
      Blank()
      AppStatusBadge({ text: `${count}`, tone: 'neutral', iconName: 'search' })
    }
    .width('100%')
  }

  @Builder
  private GoalCard(goal: Goal) {
    AppCard({ variant: 'base', spacing: SPACE_SM, interactive: true, tapAction: () => { this.openGoal(goal); } }) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        AppStatusBadge({ text: goal.category as string, tone: 'primary', iconName: 'goal' })
        AppStatusBadge({
          text: this.getGoalStatusText(goal),
          tone: goal.progress >= 100 ? 'success' : 'neutral',
          iconName: goal.progress >= 100 ? 'success' : 'progress'
        })
      }
      .width('100%')

      Text(goal.title)
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(goal.description && goal.description.length > 0 ? goal.description : '暂无目标说明')
        .fontSize(TYPE_BODY)
        .lineHeight(18)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(`当前进度 ${Math.max(0, Math.min(100, goal.progress))}%`)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textMuted)
    }
  }

  @Builder
  private EventCard(event: DayEvent) {
    AppCard({ variant: 'base', spacing: SPACE_SM, interactive: true, tapAction: () => { this.openEvent(event); } }) {
      Row({ space: SPACE_SM }) {
        AppIcon({ name: getEventTypeIcon(event.type), iconSize: 28 })

        Column({ space: SPACE_XS }) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            AppStatusBadge({ text: this.getEventTypeText(event), tone: 'info', iconName: getEventTypeIcon(event.type) })
            if (event.goalTitle && event.goalTitle.length > 0) {
              AppStatusBadge({ text: event.goalTitle, tone: 'neutral', iconName: 'goal' })
            }
          }
          .width('100%')

          Text(event.title)
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(getDayEventMetricText(event))
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
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
  private TaskCard(taskEntry: RenderableTaskEntry) {
    AppCard({
      variant: taskEntry.isOverdue ? 'danger' : 'base',
      spacing: SPACE_SM,
      interactive: true,
      tapAction: () => {
        this.openTaskById(taskEntry.taskId);
      }
    }) {
      Row({ space: SPACE_SM }) {
        Column()
          .width(4)
          .height(54)
          .borderRadius(RADIUS_PILL)
          .backgroundColor(taskEntry.isOverdue ? this.themeColors.warning : this.themeColors.primary)

        Column({ space: SPACE_XS }) {
          Text(taskEntry.title && taskEntry.title.length > 0 ? taskEntry.title : '未命名任务')
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (taskEntry.subtitle.length > 0) {
            Text(taskEntry.subtitle)
              .fontSize(TYPE_META)
              .fontColor(this.themeColors.textSecondary)
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          Text(taskEntry.deadlineText)
            .fontSize(TYPE_META)
            .fontColor(taskEntry.deadlineColor)
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
  private ResultListRow(row: SearchListRow) {
    if (row.rowType === 'header') {
      this.SectionHeader(row.title || '', row.count || 0)
    } else if (row.rowType === 'goal' && row.goal) {
      this.GoalCard(row.goal)
    } else if (row.rowType === 'event' && row.event) {
      this.EventCard(row.event)
    } else if (row.rowType === 'task' && row.taskEntry) {
      this.TaskCard(row.taskEntry)
    } else {
      Row().width('100%').height(0)
    }
  }

  build() {
    Column({ space: 0 }) {
      this.SearchHeader()

      if (this.isLoading) {
        Column() {
          AppLoadingState({ label: '正在整理搜索结果' })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 8, bottom: PAGE_PADDING })
        .backgroundColor(this.themeColors.background)
      } else {
        List({ space: SPACE_SM }) {
          ForEach(this.resultRows, (row: SearchListRow) => {
            ListItem() {
              this.ResultListRow(row)
            }
          }, (row: SearchListRow) => row.rowKey)
        }
        .width('100%')
        .layoutWeight(1)
        .listDirection(Axis.Vertical)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 8, bottom: PAGE_PADDING + 32 })
        .backgroundColor(this.themeColors.background)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
