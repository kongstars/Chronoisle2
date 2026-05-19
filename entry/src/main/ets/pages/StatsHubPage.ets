import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { db } from '../storage/Database';
import { authService } from '../services/AuthService';
import {
  statsService,
  StatsData,
  TimeRange,
  CategoryStat,
  DailyStat,
  GoalFocusItem
} from '../services/StatsService';
import { Goal } from '../models/Goal';
import { Task } from '../models/Task';
import { Pomodoro } from '../models/Pomodoro';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppHeroPanel } from '../ui/base/AppHeroPanel';
import { AppIcon } from '../ui/base/AppIcon';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppPanelSection } from '../ui/base/AppPanelSection';
import { AppSegmentTabs } from '../ui/base/AppSegmentTabs';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { SPACE_CARD, SPACE_LG, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_META, TYPE_NUMERIC_MD, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { STATS_CONTENT_MAX_WIDTH, STATS_GRID_BREAKPOINT_LG, STATS_GRID_BREAKPOINT_MD } from '../foundation/tokens/PageDensityTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('StatsHubPage');

@Entry
@Component
struct StatsHubPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State isLoading: boolean = true;
  @State contentWidth: number = 0;
  @State selectedRange: TimeRange = TimeRange.WEEK;
  @State stats: StatsData | null = null;
  private baseGoals: Goal[] = [];
  private baseTasks: Task[] = [];
  private basePomodoros: Pomodoro[] = [];
  private hasLoadedBaseData: boolean = false;

  aboutToAppear(): void {
    void this.loadStats();
  }

  private async loadStats(): Promise<void> {
    this.isLoading = true;
    try {
      await this.ensureBaseDataLoaded();
      this.stats = await statsService.calculateStats(this.baseGoals, this.baseTasks, this.basePomodoros, this.selectedRange);
    } catch (error) {
      logger.error('StatsHubPage loadStats failed', error as Object);
      this.stats = null;
    } finally {
      this.isLoading = false;
    }
  }

  private async ensureBaseDataLoaded(): Promise<void> {
    if (this.hasLoadedBaseData) {
      return;
    }

    const context = this.getUIContext().getHostContext() as Context;
    await db.initialize(context);
    await authService.initialize(context);
    this.baseGoals = db.getAllGoals();
    this.baseTasks = db.getAllTasks();
    this.basePomodoros = db.getAllPomodoros();
    this.hasLoadedBaseData = true;
  }

  private async switchRange(range: TimeRange): Promise<void> {
    if (this.selectedRange === range || this.isLoading) {
      return;
    }
    this.selectedRange = range;
    await this.loadStats();
  }

  private getGoalRateText(): string {
    return this.stats ? `${this.stats.completedGoals}/${this.stats.totalGoals}` : '--';
  }

  private getTaskRateText(): string {
    return this.stats ? `${this.stats.completedTasks}/${this.stats.totalTasks}` : '--';
  }

  private getFocusText(): string {
    return this.stats ? `${this.stats.focusStats.totalMinutes} 分钟` : '--';
  }

  private getFocusCountText(): string {
    return this.stats ? `${this.stats.focusStats.totalCount} 次` : '--';
  }

  private getCategoryStats(): CategoryStat[] {
    return this.stats ? this.stats.categoryStats : [];
  }

  private getDailyStats(): DailyStat[] {
    if (!this.stats) {
      return [];
    }
    return this.stats.dailyStats.slice(-7);
  }

  private getGoalFocusItems(): GoalFocusItem[] {
    if (!this.stats) {
      return [];
    }
    return this.stats.focusStats.goalDistribution.slice(0, 6);
  }

  private getRangeIndex(): number {
    switch (this.selectedRange) {
      case TimeRange.MONTH:
        return 1;
      case TimeRange.YEAR:
        return 2;
      default:
        return 0;
    }
  }

  private handleRangeChange(index: number): void {
    switch (index) {
      case 1:
        void this.switchRange(TimeRange.MONTH);
        return;
      case 2:
        void this.switchRange(TimeRange.YEAR);
        return;
      default:
        void this.switchRange(TimeRange.WEEK);
    }
  }

  private getRangeLabel(): string {
    switch (this.selectedRange) {
      case TimeRange.MONTH:
        return '近 30 天';
      case TimeRange.YEAR:
        return '近 1 年';
      default:
        return '近 7 天';
    }
  }

  private getHeroDescription(): string {
    if (!this.stats) {
      return '汇总目标完成、任务推进与专注投入，帮助你快速判断当前执行节奏。';
    }
    return `当前范围内完成目标 ${this.stats.completedGoals} 个，完成任务 ${this.stats.completedTasks} 个，累计专注 ${this.stats.focusStats.totalMinutes} 分钟。`;
  }

  private updateContentWidth(widthValue: Length): void {
    const nextWidth = parseFloat(`${widthValue}`);
    if (nextWidth > 0 && Math.abs(nextWidth - this.contentWidth) > 0.5) {
      this.contentWidth = nextWidth;
    }
  }

  @Builder
  private MetricTilesGrid() {
    if (this.contentWidth >= STATS_GRID_BREAKPOINT_LG) {
      Row({ space: SPACE_SM }) {
        this.MetricTile('目标完成率', `${this.stats ? this.stats.goalCompletionRate : 0}%`, this.getGoalRateText(), 'primary')
        this.MetricTile('任务完成率', `${this.stats ? this.stats.taskCompletionRate : 0}%`, this.getTaskRateText(), 'success')
        this.MetricTile('专注时长', this.getFocusText(), '累计投入', 'neutral')
        this.MetricTile('番茄次数', this.getFocusCountText(), '已完成轮次', 'warning')
      }
      .width('100%')
    } else if (this.contentWidth >= STATS_GRID_BREAKPOINT_MD) {
      Column({ space: SPACE_SM }) {
        Row({ space: SPACE_SM }) {
          this.MetricTile('目标完成率', `${this.stats ? this.stats.goalCompletionRate : 0}%`, this.getGoalRateText(), 'primary')
          this.MetricTile('任务完成率', `${this.stats ? this.stats.taskCompletionRate : 0}%`, this.getTaskRateText(), 'success')
        }
        .width('100%')

        Row({ space: SPACE_SM }) {
          this.MetricTile('专注时长', this.getFocusText(), '累计投入', 'neutral')
          this.MetricTile('番茄次数', this.getFocusCountText(), '已完成轮次', 'warning')
        }
        .width('100%')
      }
      .width('100%')
    } else {
      Column({ space: SPACE_SM }) {
        Row({ space: SPACE_SM }) {
          this.MetricTile('目标完成率', `${this.stats ? this.stats.goalCompletionRate : 0}%`, this.getGoalRateText(), 'primary')
        }
        .width('100%')

        Row({ space: SPACE_SM }) {
          this.MetricTile('任务完成率', `${this.stats ? this.stats.taskCompletionRate : 0}%`, this.getTaskRateText(), 'success')
        }
        .width('100%')

        Row({ space: SPACE_SM }) {
          this.MetricTile('专注时长', this.getFocusText(), '累计投入', 'neutral')
        }
        .width('100%')

        Row({ space: SPACE_SM }) {
          this.MetricTile('番茄次数', this.getFocusCountText(), '已完成轮次', 'warning')
        }
        .width('100%')
      }
      .width('100%')
    }
  }

  @Builder
  private MetricTile(title: string, value: string, note: string, tone: 'neutral' | 'primary' | 'success' | 'warning' = 'neutral') {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Text(value)
        .fontSize(TYPE_NUMERIC_MD)
        .fontWeight(FontWeight.Bold)
        .fontColor(tone === 'primary'
          ? this.themeColors.primary
          : tone === 'success'
            ? this.themeColors.success
            : tone === 'warning'
              ? this.themeColors.warning
              : this.themeColors.textPrimary)
        .width('100%')

      Text(note)
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textMuted)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
    .padding(SPACE_MD)
    .backgroundColor(this.themeColors.surfaceSoft)
    .borderRadius(14)
  }

  @Builder
  private CategoryRow(item: CategoryStat) {
    AppCard({ spacing: SPACE_XS, paddingLevel: 'md' }) {
      Row({ space: SPACE_SM }) {
        AppIcon({ name: item.icon, iconSize: 24 })
        Text(item.categoryName)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .layoutWeight(1)

        AppStatusBadge({
          text: `${item.completionRate}%`,
          tone: item.completionRate >= 80 ? 'success' : item.completionRate >= 50 ? 'primary' : 'warning',
          iconName: item.completionRate >= 80 ? 'success' : item.completionRate >= 50 ? 'progress' : 'warning'
        })
      }
      .width('100%')

      Text(`目标 ${item.completedGoals}/${item.totalGoals} · 任务 ${item.completedTasks}/${item.totalTasks}`)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  @Builder
  private DailyRow(item: DailyStat, isLast: boolean) {
    Row({ space: SPACE_SM }) {
      Text(item.date)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .layoutWeight(1)

      Text(`任务 ${item.completedTasks}`)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textPrimary)

      Text(`目标 ${item.completedGoals}`)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.primary)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: isLast ? 0 : 1 }, color: this.themeColors.divider })
  }

  @Builder
  private FocusGoalRow(item: GoalFocusItem, isLast: boolean) {
    Row({ space: SPACE_SM }) {
      Column({ space: 2 }) {
        Text(item.goalTitle)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(`专注 ${item.count} 次`)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(`${item.minutes} 分钟`)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.primary)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: isLast ? 0 : 1 }, color: this.themeColors.divider })
  }

  build() {
    Column({ space: SPACE_MD }) {
      AppPageHeader({
        title: '统计中心',
        subtitle: '查看目标、任务和专注投入的阶段表现',
        onBack: () => {
          this.getUIContext().getRouter().back();
        }
      })

      if (this.isLoading) {
        Column({ space: SPACE_MD }) {
          AppHeroPanel({
            eyebrow: this.getRangeLabel(),
            title: '正在整理你的执行数据',
            description: '会汇总目标、任务和专注记录，生成当前时间范围内的进度概览。',
            tone: 'info'
          }) {
          }

          AppLoadingState({ label: '正在计算统计数据...' })
        }
        .width('100%')
        .padding({ left: SPACE_LG, right: SPACE_LG })
      } else {
        Scroll() {
          Column({ space: SPACE_LG }) {
            AppHeroPanel({
              eyebrow: this.getRangeLabel(),
              title: '执行概览',
              description: this.getHeroDescription(),
              tone: 'info'
            }) {
              Column({ space: SPACE_SM }) {
                if (this.stats && this.stats.isFallbackFromPremium) {
                  Row() {
                    AppStatusBadge({ text: '基础版统计范围已自动收敛', tone: 'warning', iconName: 'warning' })
                  }
                }

                this.MetricTilesGrid()
              }
              .width('100%')
            }

            AppSegmentTabs({
              tabs: ['近7天', '近30天', '近1年'],
              selectedIndex: this.getRangeIndex(),
              onSelect: (index: number) => {
                this.handleRangeChange(index);
              }
            })

            AppPanelSection({
              title: '分类表现',
              subtitle: '不同目标分类下的推进效率'
            }) {
              if (this.getCategoryStats().length === 0) {
                AppEmptyState({
                  title: '当前范围内还没有分类数据',
                  description: '继续记录目标和任务完成情况，统计中心会自动在这里汇总。',
                  iconName: 'stats',
                  iconTone: 'primary'
                })
              } else {
                Column({ space: SPACE_SM }) {
                  ForEach(this.getCategoryStats(), (item: CategoryStat) => {
                    this.CategoryRow(item)
                  }, (item: CategoryStat) => item.category as string)
                }
                .width('100%')
              }
            }

            AppPanelSection({
              title: '最近 7 天趋势',
              subtitle: '观察日常完成量的波动情况'
            }) {
              if (this.getDailyStats().length === 0) {
                AppEmptyState({
                  title: '暂时没有趋势数据',
                  description: '当目标、任务产生更多完成记录后，这里会出现连续趋势。',
                  iconName: 'stats',
                  iconTone: 'info'
                })
              } else {
                AppCard({ spacing: 0, paddingLevel: 'md' }) {
                  Column() {
                    ForEach(this.getDailyStats(), (item: DailyStat, index: number) => {
                      this.DailyRow(item, index === this.getDailyStats().length - 1)
                    })
                  }
                  .width('100%')
                }
              }
            }

            AppPanelSection({
              title: '专注投入分布',
              subtitle: '哪些目标占用了更多专注时间'
            }) {
              if (this.getGoalFocusItems().length === 0) {
                AppEmptyState({
                  title: '当前范围内还没有专注记录',
                  description: '开始番茄钟后，系统会把专注时长自动归集到对应目标。',
                  iconName: 'focus',
                  iconTone: 'info'
                })
              } else {
                AppCard({ spacing: 0, paddingLevel: 'md' }) {
                  Column() {
                    ForEach(this.getGoalFocusItems(), (item: GoalFocusItem, index: number) => {
                      this.FocusGoalRow(item, index === this.getGoalFocusItems().length - 1)
                    })
                  }
                  .width('100%')
                }
              }
            }

            Blank().height(12)
          }
          .width('100%')
          .constraintSize({ maxWidth: STATS_CONTENT_MAX_WIDTH })
          .alignSelf(ItemAlign.Center)
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
    .onAreaChange((_oldValue, newValue) => {
      this.updateContentWidth(newValue.width);
    })
  }
}
