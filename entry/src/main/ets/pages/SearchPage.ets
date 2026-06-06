import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { db } from '../storage/Database';
import { Goal } from '../models/Goal';
import { Task, TaskStatus } from '../models/Task';
import { DayEvent, DayEventType, getEventTypeIcon } from '../models/DayEvent';
import { getDayEventMetricText } from '../common/DayEventUtils';
import { TelemetryService, type TelemetryProperties } from '../services/TelemetryService';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
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

@Entry
@Component
struct SearchPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State keyword: string = '';
  @State goals: Goal[] = [];
  @State tasks: Task[] = [];
  @State events: DayEvent[] = [];
  @State isLoading: boolean = true;
  private hasLoadedEntryParams: boolean = false;
  private lastTrackedQuery: string = '';
  private filteredGoalsCacheSource: Goal[] | null = null;
  private filteredGoalsCacheQuery: string = '';
  private filteredGoalsCache: Goal[] = [];
  private filteredEventsCacheSource: DayEvent[] | null = null;
  private filteredEventsCacheQuery: string = '';
  private filteredEventsCache: DayEvent[] = [];
  private filteredTasksCacheSource: Task[] | null = null;
  private filteredTasksCacheQuery: string = '';
  private filteredTasksCache: Task[] = [];

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
    } catch (error) {
      logger.error('SearchPage load error', error as Object);
      this.goals = [];
      this.tasks = [];
      this.events = [];
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

  private getFilteredGoals(): Goal[] {
    const query = this.getQuery();
    if (this.filteredGoalsCacheSource === this.goals && this.filteredGoalsCacheQuery === query) {
      return this.filteredGoalsCache;
    }
    if (!query) {
      this.filteredGoalsCache = this.goals.slice(0, 6);
      this.filteredGoalsCacheSource = this.goals;
      this.filteredGoalsCacheQuery = query;
      return this.filteredGoalsCache;
    }
    this.filteredGoalsCache = this.goals.filter((goal: Goal) => {
      return this.containsQuery(goal.title, query) ||
        this.containsQuery(goal.description, query) ||
        this.containsQuery(goal.category as string, query);
    });
    this.filteredGoalsCacheSource = this.goals;
    this.filteredGoalsCacheQuery = query;
    return this.filteredGoalsCache;
  }

  private getFilteredEvents(): DayEvent[] {
    const query = this.getQuery();
    if (this.filteredEventsCacheSource === this.events && this.filteredEventsCacheQuery === query) {
      return this.filteredEventsCache;
    }
    if (!query) {
      this.filteredEventsCache = this.events.slice(0, 6);
      this.filteredEventsCacheSource = this.events;
      this.filteredEventsCacheQuery = query;
      return this.filteredEventsCache;
    }
    this.filteredEventsCache = this.events.filter((event: DayEvent) => {
      return this.containsQuery(event.title, query) || this.containsQuery(event.goalTitle, query);
    });
    this.filteredEventsCacheSource = this.events;
    this.filteredEventsCacheQuery = query;
    return this.filteredEventsCache;
  }

  private getFilteredTasks(): Task[] {
    const query = this.getQuery();
    if (this.filteredTasksCacheSource === this.tasks && this.filteredTasksCacheQuery === query) {
      return this.filteredTasksCache;
    }
    if (!query) {
      this.filteredTasksCache = this.tasks.slice(0, 10);
      this.filteredTasksCacheSource = this.tasks;
      this.filteredTasksCacheQuery = query;
      return this.filteredTasksCache;
    }
    this.filteredTasksCache = this.tasks.filter((task: Task) => {
      return this.containsQuery(task.title, query) ||
        this.containsQuery(task.description, query) ||
        this.containsQuery(task.goalTitle, query);
    });
    this.filteredTasksCacheSource = this.tasks;
    this.filteredTasksCacheQuery = query;
    return this.filteredTasksCache;
  }

  private getTotalResultCount(): number {
    return this.getFilteredGoals().length + this.getFilteredEvents().length + this.getFilteredTasks().length;
  }

  private getGoalStatusText(goal: Goal): string {
    return goal.progress >= 100 ? '已完成' : '进行中';
  }

  private getTaskGoalText(task: Task): string {
    return task.goalTitle && task.goalTitle.length > 0 ? task.goalTitle : '未关联目标';
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

  private getEventTypeText(event: DayEvent): string {
    switch (event.type) {
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
      "resultCount": this.getTotalResultCount()
    };
    TelemetryService.track('search_performed', searchProps, 'search');
  }

  private openGoal(goal: Goal): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/GoalDetailPage', params: { goalId: goal.id } });
  }

  private openTask(task: Task): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/TaskDetailPage', params: { taskId: task.id } });
  }

  private openEvent(event: DayEvent): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/DayEventListPage',
      params: { eventId: event.id, keyword: event.title }
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
  private TaskCard(task: Task) {
    AppCard({ variant: task.isOverdue ? 'danger' : 'base', spacing: SPACE_SM, interactive: true, tapAction: () => { this.openTask(task); } }) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        AppStatusBadge({ text: this.getTaskGoalText(task), tone: 'neutral', iconName: 'goal' })
        AppStatusBadge({
          text: this.getTaskStatusText(task),
          tone: this.getTaskTone(task),
          iconName: this.getTaskStatusIconName(task)
        })
      }
      .width('100%')

      Text(task.title)
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (task.description.trim().length > 0) {
        Text(task.description)
          .fontSize(TYPE_BODY)
          .lineHeight(22)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      Text(task.deadline && task.deadline.length > 0 ? task.deadline : '未设置日期')
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textMuted)
        .width('100%')
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
        Scroll() {
          Column({ space: SECTION_GAP }) {
            if (this.getTotalResultCount() === 0) {
              AppEmptyState({
                title: this.keyword.trim().length > 0 ? '没有找到匹配内容' : '还没有可搜索的内容',
                description: this.keyword.trim().length > 0
                  ? '换一个更短的关键词，或者直接搜索目标标题、任务标题、提醒名称。'
                  : '先创建一些目标、提醒或任务，之后就可以从这里快速定位和跳转。',
                actionText: this.keyword.trim().length > 0 ? '清空关键词' : '',
                actionIconName: 'search',
                iconName: 'search',
                iconTone: 'info',
                onAction: () => {
                  this.clearKeyword();
                }
              })
            } else {
              if (this.getFilteredGoals().length > 0) {
                Column({ space: SPACE_SM }) {
                  this.SectionHeader('目标', this.getFilteredGoals().length)
                  ForEach(this.getFilteredGoals(), (goal: Goal) => {
                    this.GoalCard(goal);
                  }, (goal: Goal) => goal.id)
                }
                .width('100%')
              }

              if (this.getFilteredEvents().length > 0) {
                Column({ space: SPACE_SM }) {
                  this.SectionHeader('提醒', this.getFilteredEvents().length)
                  ForEach(this.getFilteredEvents(), (event: DayEvent) => {
                    this.EventCard(event);
                  }, (event: DayEvent) => event.id)
                }
                .width('100%')
              }

              if (this.getFilteredTasks().length > 0) {
                Column({ space: SPACE_SM }) {
                  this.SectionHeader('任务', this.getFilteredTasks().length)
                  ForEach(this.getFilteredTasks(), (task: Task) => {
                    this.TaskCard(task);
                  }, (task: Task) => task.id)
                }
                .width('100%')
              }
            }
          }
          .width('100%')
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 8, bottom: PAGE_PADDING + 16 })
        }
        .scrollBar(BarState.Off)
        .backgroundColor(this.themeColors.background)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
