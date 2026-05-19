import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { Goal, GoalCategory, KeyResult } from '../models/Goal';
import { Task, TaskStatus } from '../models/Task';
import { db } from '../storage/Database';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppGoalCard } from '../ui/base/AppGoalCard';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppPanelSection } from '../ui/base/AppPanelSection';
import { PAGE_PADDING, SECTION_GAP, SPACE_MD } from '../foundation/tokens/SpacingTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('ActiveGoalsPage');

@Entry
@Component
struct ActiveGoalsPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State isLoading: boolean = true;
  @State goals: Goal[] = [];
  @State tasks: Task[] = [];

  private dataChangeListener: () => void = () => {
    void this.loadGoals();
  };

  aboutToAppear(): void {
    db.onDataChanged(this.dataChangeListener);
    void this.loadGoals();
  }

  aboutToDisappear(): void {
    db.offDataChanged(this.dataChangeListener);
  }

  onPageShow(): void {
    void this.loadGoals();
  }

  private async loadGoals(): Promise<void> {
    this.isLoading = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await db.initialize(context);
      this.goals = db.getActiveGoals()
        .sort((first: Goal, second: Goal) => {
          if (first.isPriority !== second.isPriority) {
            return first.isPriority ? -1 : 1;
          }
          if (first.progress !== second.progress) {
            return second.progress - first.progress;
          }
          return (second.updatedAt || second.createdAt) - (first.updatedAt || first.createdAt);
        });
      this.tasks = db.getAllTasks();
    } catch (error) {
      logger.error('ActiveGoalsPage load error', error as Object);
      this.goals = [];
      this.tasks = [];
    } finally {
      this.isLoading = false;
    }
  }

  private getCategoryOrder(): GoalCategory[] {
    return [GoalCategory.HEALTH, GoalCategory.LEARNING, GoalCategory.FINANCE, GoalCategory.FUN];
  }

  private getCategoryGoals(category: GoalCategory): Goal[] {
    return this.goals.filter((goal: Goal) => goal.category === category);
  }

  private getCategoryLabel(category: GoalCategory): string {
    return category as string;
  }

  private getCategorySubtitle(category: GoalCategory): string {
    const goals = this.getCategoryGoals(category);
    const pendingCount = goals.reduce((sum: number, goal: Goal) => sum + this.getGoalTaskCount(goal), 0);
    return `${goals.length} 个目标 · ${pendingCount} 件待办行动`;
  }

  private getGoalTaskCount(goal: Goal): number {
    return this.tasks.filter((task: Task) => task.goalId === goal.id && task.status === TaskStatus.PENDING).length;
  }

  private getVisibleKeyResults(goal: Goal): KeyResult[] {
    if (!goal.keyResults || goal.keyResults.length === 0) {
      return [];
    }
    return goal.keyResults
      .slice()
      .sort((first: KeyResult, second: KeyResult) => {
        const firstDone = first.progress >= 100 ? 1 : 0;
        const secondDone = second.progress >= 100 ? 1 : 0;
        if (firstDone !== secondDone) {
          return firstDone - secondDone;
        }
        return first.progress - second.progress;
      })
      .slice(0, 3);
  }

  private getGoalKeyResultSummaries(goal: Goal): string[] {
    return this.getVisibleKeyResults(goal).map((keyResult: KeyResult) => {
      return `${keyResult.title} ${keyResult.currentValue}/${keyResult.targetValue}`;
    });
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

  @Builder
  private GoalCard(goal: Goal) {
    AppGoalCard({
      badgeText: this.getCategoryLabel(goal.category),
      title: goal.title,
      progressText: `今天还有 ${this.getGoalTaskCount(goal)} 件行动`,
      percentText: `${Math.min(100, Math.max(0, goal.progress))}%`,
      keyResults: this.getGoalKeyResultSummaries(goal),
      accentColor: this.getGoalMetricColor(goal),
      badgeTextColor: this.getGoalTagTextColor(goal),
      badgeBackgroundColor: this.getGoalTagBackground(goal),
      tapAction: () => {
        this.getUIContext().getRouter().pushUrl({
          url: 'pages/GoalDetailPage',
          params: { goalId: goal.id }
        });
      }
    })
  }

  @Builder
  private CategorySection(category: GoalCategory) {
    AppPanelSection({
      title: this.getCategoryLabel(category),
      subtitle: this.getCategorySubtitle(category),
      insetHorizontal: 0
    }) {
      Column({ space: SPACE_MD }) {
        ForEach(this.getCategoryGoals(category), (goal: Goal) => {
          this.GoalCard(goal)
        }, (goal: Goal) => goal.id)
      }
      .width('100%')
    }
  }

  build() {
    Scroll() {
      Column({ space: SECTION_GAP }) {
        AppPageHeader({
          title: '正在推进的目标',
          subtitle: `共 ${this.goals.length} 个目标，按类型分组`,
          actionText: this.isLoading ? '' : '刷新',
          actionIconName: 'sync',
          onBack: () => this.getUIContext().getRouter().back(),
          onAction: () => {
            void this.loadGoals();
          }
        })

        Column({ space: SECTION_GAP }) {
          if (this.isLoading) {
            AppLoadingState({ label: '正在整理目标列表...' })
          } else if (this.goals.length === 0) {
            AppEmptyState({
              iconName: 'goal',
              iconTone: 'primary',
              title: '当前还没有正在推进的目标',
              description: '先创建目标，再补充关键结果和行动，目标面板会自动显示推进状态。'
            })
          } else {
            ForEach(this.getCategoryOrder(), (category: GoalCategory) => {
              if (this.getCategoryGoals(category).length > 0) {
                this.CategorySection(category)
              }
            }, (category: GoalCategory) => category)
          }
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: PAGE_PADDING + 24 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .scrollBar(BarState.Off)
  }
}
