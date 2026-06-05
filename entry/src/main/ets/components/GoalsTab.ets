/**
 * GoalsTab — 目标 Tab
 *
 * 顶部 Header（标题 + 新建）
 * Hero 卡（焦点目标，展示进度环 / 关键结果 / 今日待办）
 * 段切换（进行中 / 已完成 / 全部）
 * 分类列表（健康 / 成长 / 理财 / 快乐）
 *
 * 复用 AppGoalCard 卡片样式；与 ActiveGoalsPage 等价能力但作为 Tab 而非独立页。
 */

import { Goal, GoalCategory, KeyResult } from '../models/Goal';
import { Task, TaskStatus } from '../models/Task';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppGoalCard } from '../ui/base/AppGoalCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppIcon } from '../ui/base/AppIcon';
import { AppSegmentTabs } from '../ui/base/AppSegmentTabs';
import { COMPACT_PAGE_PADDING } from '../foundation/tokens/PageTierTokens';
import { RADIUS_LG, RADIUS_PILL, RADIUS_SM } from '../foundation/tokens/RadiusTokens';
import { SPACE_2XS, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import {
  TYPE_BODY,
  TYPE_CAPTION,
  TYPE_META,
  TYPE_NUMERIC_MD,
  TYPE_SECTION_TITLE
} from '../foundation/tokens/TypographyTokens';
import { BOTTOM_CONTENT_SPACER } from '../foundation/tokens/ComponentSizeTokens';
import { BORDER_DEFAULT } from '../foundation/tokens/BorderTokens';
import { getCardShadow, getRaisedCardShadow } from '../foundation/tokens/ElevationTokens';

@Component
export struct GoalsTab {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop goals: Goal[] = [];
  @Prop tasks: Task[] = [];

  // 0 进行中  1 已完成  2 全部
  @State statusIndex: number = 0;

  onCreate?: () => void;
  onOpenGoalDetail?: (goalId: string) => void;

  // ========== 数据 ==========

  private getActiveGoals(): Goal[] {
    return this.goals.filter((g: Goal) => !g.isArchived);
  }

  private getCompletedGoals(): Goal[] {
    return this.goals.filter((g: Goal) => g.isArchived);
  }

  private getAllGoals(): Goal[] {
    return this.goals;
  }

  private getDisplayGoals(): Goal[] {
    if (this.statusIndex === 1) {
      return this.getCompletedGoals();
    }
    if (this.statusIndex === 2) {
      return this.getAllGoals();
    }
    return this.getActiveGoals();
  }

  private sortByPriority(items: Goal[]): Goal[] {
    return items.slice().sort((first: Goal, second: Goal) => {
      if (first.isPriority !== second.isPriority) {
        return first.isPriority ? -1 : 1;
      }
      if (first.progress !== second.progress) {
        return second.progress - first.progress;
      }
      return (second.updatedAt || second.createdAt) - (first.updatedAt || first.createdAt);
    });
  }

  private getCategoryOrder(): GoalCategory[] {
    return [GoalCategory.HEALTH, GoalCategory.LEARNING, GoalCategory.FINANCE, GoalCategory.FUN];
  }

  private getCategoryGoals(category: GoalCategory): Goal[] {
    return this.sortByPriority(this.getDisplayGoals().filter((g: Goal) => g.category === category));
  }

  // 分类列表展示用：进行中模式下，把焦点目标从分类列表里去掉，避免重复显示
  private getCategoryGoalsForDisplay(category: GoalCategory): Goal[] {
    const focusGoal = this.statusIndex === 0 ? this.getFocusGoal() : null;
    const items = this.getCategoryGoals(category);
    if (focusGoal === null) {
      return items;
    }
    return items.filter((g: Goal) => g.id !== focusGoal!.id);
  }

  private getFocusGoal(): Goal | null {
    const sorted = this.sortByPriority(this.getActiveGoals());
    return sorted.length > 0 ? sorted[0] : null;
  }

  private getGoalTaskCount(goal: Goal): number {
    return this.tasks.filter((task: Task) => task.goalId === goal.id && task.status === TaskStatus.PENDING).length;
  }

  private getGoalKeyResultSummaries(goal: Goal): string[] {
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
      .slice(0, 3)
      .map((kr: KeyResult) => `${kr.title} ${kr.currentValue}/${kr.targetValue}`);
  }

  private getCompletedTodayCount(): number {
    return this.getActiveGoals().filter((g: Goal) => g.progress >= 100).length;
  }

  private getThisWeekProgressText(): string {
    const active = this.getActiveGoals();
    if (active.length === 0) {
      return '0%';
    }
    const totalProgress = active.reduce((sum: number, goal: Goal) => sum + Math.max(0, Math.min(100, goal.progress || 0)), 0);
    const avg = Math.round(totalProgress / active.length);
    return `${avg}%`;
  }

  private getCategoryLabel(category: GoalCategory): string {
    return category as string;
  }

  private getCategoryIconName(category: GoalCategory): string {
    switch (category) {
      case GoalCategory.HEALTH:
        return 'health';
      case GoalCategory.LEARNING:
        return 'growth';
      case GoalCategory.FINANCE:
        return 'finance';
      case GoalCategory.FUN:
        return 'joy';
      default:
        return 'goal';
    }
  }

  private getCategoryAccent(category: GoalCategory): string {
    switch (category) {
      case GoalCategory.HEALTH:
        return this.themeColors.success;
      case GoalCategory.LEARNING:
        return this.themeColors.primary;
      case GoalCategory.FINANCE:
        return this.themeColors.warning;
      case GoalCategory.FUN:
        return this.themeColors.premium;
      default:
        return this.themeColors.primary;
    }
  }

  private getCategoryBadgeBackground(category: GoalCategory): string {
    switch (category) {
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

  private getCategoryBadgeTextColor(category: GoalCategory): string {
    switch (category) {
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

  private getStatusTabs(): string[] {
    return [
      `进行中 ${this.getActiveGoals().length}`,
      `已完成 ${this.getCompletedGoals().length}`,
      `全部 ${this.goals.length}`
    ];
  }

  private getDisplayHeaderSubtitle(): string {
    const total = this.getDisplayGoals().length;
    if (this.statusIndex === 1) {
      return `共 ${total} 个已完成`;
    }
    if (this.statusIndex === 2) {
      return `共 ${total} 个目标`;
    }
    return `推进中 ${total} · 平均完成度 ${this.getThisWeekProgressText()}`;
  }

  // ========== Builders ==========

  @Builder
  private HeaderActionButton(iconName: string, onTap: () => void) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(40)
        .height(40)
        .backgroundColor(this.themeColors.primarySubtle)
        .borderRadius(20)

      AppIcon({
        name: iconName,
        iconSize: 22,
        framed: false,
        color: this.themeColors.primary
      })
    }
    .width(40)
    .height(40)
    .onClick(() => { onTap(); })
  }

  @Builder
  private Header() {
    Row({ space: SPACE_SM }) {
      Column({ space: 2 }) {
        Text('目标')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
        Text(this.getDisplayHeaderSubtitle())
          .fontSize(14)
          .fontColor(this.themeColors.textSecondary)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      this.HeaderActionButton('plus', () => {
        if (this.onCreate) {
          this.onCreate();
        }
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: COMPACT_PAGE_PADDING, right: COMPACT_PAGE_PADDING, top: 8, bottom: 4 })
  }

  @Builder
  private FocusHero(goal: Goal) {
    Column({ space: SPACE_SM }) {
      Row({ space: SPACE_SM }) {
        // 分类徽章
        Row({ space: SPACE_2XS }) {
          AppIcon({
            name: this.getCategoryIconName(goal.category),
            iconSize: 12,
            framed: false,
            color: this.getCategoryBadgeTextColor(goal.category)
          })
          Text(this.getCategoryLabel(goal.category))
            .fontSize(TYPE_CAPTION)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getCategoryBadgeTextColor(goal.category))
        }
        .padding({ left: SPACE_XS, right: SPACE_XS, top: 2, bottom: 2 })
        .backgroundColor(this.getCategoryBadgeBackground(goal.category))
        .borderRadius(RADIUS_SM)

        if (goal.isPriority) {
          Row({ space: SPACE_2XS }) {
            AppIcon({
              name: 'star-fill',
              iconSize: 12,
              framed: false,
              color: this.themeColors.warning
            })
            Text('焦点')
              .fontSize(TYPE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColors.warning)
          }
          .padding({ left: SPACE_XS, right: SPACE_XS, top: 2, bottom: 2 })
          .backgroundColor(this.themeColors.warningSubtle)
          .borderRadius(RADIUS_SM)
        }

        Blank()

        Text('本周焦点')
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textMuted)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: SPACE_MD }) {
        Column({ space: 2 }) {
          Text(goal.title)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(`今天还有 ${this.getGoalTaskCount(goal)} 件行动`)
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 进度数值
        Column({ space: 0 }) {
          Text(`${Math.min(100, Math.max(0, goal.progress || 0))}%`)
            .fontSize(TYPE_NUMERIC_MD)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getCategoryAccent(goal.category))
          Text('完成度')
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textMuted)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 进度条
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(6)
          .backgroundColor(this.themeColors.surfaceSoft)
          .borderRadius(3)

        Row()
          .width(`${Math.min(100, Math.max(0, goal.progress || 0))}%`)
          .height(6)
          .backgroundColor(this.getCategoryAccent(goal.category))
          .borderRadius(3)
      }
      .width('100%')

      // 关键结果（最多 3 条）
      if (this.getGoalKeyResultSummaries(goal).length > 0) {
        Column({ space: SPACE_2XS }) {
          ForEach(this.getGoalKeyResultSummaries(goal), (item: string) => {
            Row({ space: SPACE_XS }) {
              Circle()
                .width(5)
                .height(5)
                .fill(this.getCategoryAccent(goal.category))
              Text(item)
                .fontSize(TYPE_BODY)
                .fontColor(this.themeColors.textPrimary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
          })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(SPACE_MD)
    .backgroundColor(this.themeColors.cardBackground)
    .borderRadius(RADIUS_LG)
    .border({ width: BORDER_DEFAULT, color: this.getCategoryAccent(goal.category) })
    .shadow(getCardShadow(this.themeColors))
    .onClick(() => {
      if (this.onOpenGoalDetail) {
        this.onOpenGoalDetail(goal.id);
      }
    })
  }

  @Builder
  private CategorySectionHeader(category: GoalCategory, count: number) {
    Row({ space: SPACE_XS }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(20)
          .height(20)
          .backgroundColor(this.getCategoryBadgeBackground(category))
          .borderRadius(RADIUS_PILL)
        AppIcon({
          name: this.getCategoryIconName(category),
          iconSize: 12,
          framed: false,
          color: this.getCategoryBadgeTextColor(category)
        })
      }
      .width(20)
      .height(20)

      Text(this.getCategoryLabel(category))
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)

      Text(`${count}`)
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textMuted)
        .padding({ left: SPACE_2XS })

      Blank()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: SPACE_XS, bottom: SPACE_2XS })
  }

  @Builder
  private GoalCardItem(goal: Goal) {
    AppGoalCard({
      badgeText: this.getCategoryLabel(goal.category),
      title: goal.title,
      progressText: goal.isArchived
        ? '已完成'
        : `今天还有 ${this.getGoalTaskCount(goal)} 件行动`,
      percentText: `${Math.min(100, Math.max(0, goal.progress || 0))}%`,
      keyResults: this.getGoalKeyResultSummaries(goal),
      accentColor: this.getCategoryAccent(goal.category),
      badgeTextColor: this.getCategoryBadgeTextColor(goal.category),
      badgeBackgroundColor: this.getCategoryBadgeBackground(goal.category),
      tapAction: () => {
        if (this.onOpenGoalDetail) {
          this.onOpenGoalDetail(goal.id);
        }
      }
    })
  }

  @Builder
  private CategorySection(category: GoalCategory) {
    if (this.getCategoryGoalsForDisplay(category).length > 0) {
      Column({ space: SPACE_SM }) {
        this.CategorySectionHeader(category, this.getCategoryGoalsForDisplay(category).length)
        Column({ space: SPACE_SM }) {
          ForEach(this.getCategoryGoalsForDisplay(category), (goal: Goal) => {
            this.GoalCardItem(goal)
          }, (goal: Goal) => goal.id)
        }
        .width('100%')
      }
      .width('100%')
    }
  }

  @Builder
  private EmptyState() {
    AppEmptyState({
      iconName: 'goal',
      iconTone: 'primary',
      title: this.statusIndex === 1 ? '还没有完成的目标' : '当前还没有目标',
      description: this.statusIndex === 1
        ? '把进行中的目标推进到 100% 后，会自动归档显示在这里。'
        : '先创建一个目标，再补充关键结果和行动，目标看板会自动跟进进度。',
      actionText: this.statusIndex === 1 ? '' : '新建目标',
      actionIconName: 'plus',
      onAction: () => {
        if (this.onCreate) {
          this.onCreate();
        }
      }
    })
  }

  build() {
    Column() {
      this.Header()

      Scroll() {
        Column({ space: SPACE_MD }) {
          // Hero（仅在"进行中"且有焦点目标时显示）
          if (this.statusIndex === 0 && this.getFocusGoal() !== null) {
            this.FocusHero(this.getFocusGoal()!)
          }

          // 状态切换
          AppSegmentTabs({
            tabs: this.getStatusTabs(),
            selectedIndex: this.statusIndex,
            onSelect: (index: number) => {
              this.statusIndex = index;
            }
          })

          if (this.getDisplayGoals().length === 0) {
            this.EmptyState()
          } else {
            // 分类列表
            ForEach(this.getCategoryOrder(), (category: GoalCategory) => {
              this.CategorySection(category)
            }, (category: GoalCategory) => category)
          }

          Blank().height(BOTTOM_CONTENT_SPACER)
        }
        .width('100%')
        .padding({ left: COMPACT_PAGE_PADDING, right: COMPACT_PAGE_PADDING, top: SPACE_XS })
      }
      .align(Alignment.Top)
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
