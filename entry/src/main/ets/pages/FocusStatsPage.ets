import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { db } from '../storage/Database';
import { Pomodoro } from '../models/Pomodoro';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppHeroPanel } from '../ui/base/AppHeroPanel';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppPanelSection } from '../ui/base/AppPanelSection';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { SPACE_LG, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_NUMERIC_MD } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('FocusStatsPage');

interface FocusTaskStat {
  taskId: string;
  taskTitle: string;
  count: number;
  minutes: number;
}

interface DailyFocusStat {
  date: string;
  count: number;
  minutes: number;
}

@Entry
@Component
struct FocusStatsPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State isLoading: boolean = true;
  @State pomodoros: Pomodoro[] = [];
  private focusSummaryCacheSource: Pomodoro[] | null = null;
  private totalMinutesCache: number = 0;
  private totalCountCache: number = 0;
  private averageMinutesCache: string = '0';
  private currentStreakCache: number = 0;
  private topTasksCache: FocusTaskStat[] = [];
  private dailyStatsCache: DailyFocusStat[] = [];

  aboutToAppear(): void {
    void this.loadPomodoros();
  }

  private async loadPomodoros(): Promise<void> {
    this.isLoading = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await db.initialize(context as Context);
      this.pomodoros = db.getAllPomodoros().filter((item: Pomodoro) => item.completed);
    } catch (error) {
      logger.error('FocusStatsPage load error', error as Object);
      this.pomodoros = [];
    } finally {
      this.isLoading = false;
    }
  }

  private ensureFocusSummaryCache(): void {
    if (this.focusSummaryCacheSource === this.pomodoros) {
      return;
    }

    const totalMinutes = this.pomodoros.reduce((sum: number, item: Pomodoro) => sum + item.actualDuration, 0);
    const totalCount = this.pomodoros.length;

    const streakMap = new Map<string, number>();
    const taskStatMap = new Map<string, FocusTaskStat>();
    const dailyStatMap = new Map<string, DailyFocusStat>();

    this.pomodoros.forEach((item: Pomodoro) => {
      const dateKey = this.formatDate(item.createdAt);
      streakMap.set(dateKey, (streakMap.get(dateKey) || 0) + 1);

      const taskStat = taskStatMap.get(item.taskId) || {
        taskId: item.taskId,
        taskTitle: item.taskTitle,
        count: 0,
        minutes: 0
      };
      taskStat.count += 1;
      taskStat.minutes += item.actualDuration;
      taskStatMap.set(item.taskId, taskStat);

      const dailyStat = dailyStatMap.get(dateKey) || { date: dateKey, count: 0, minutes: 0 };
      dailyStat.count += 1;
      dailyStat.minutes += item.actualDuration;
      dailyStatMap.set(dateKey, dailyStat);
    });

    let streak = 0;
    const cursor = new Date();
    while (true) {
      const key = this.formatDate(cursor.getTime());
      if (!streakMap.has(key)) {
        break;
      }
      streak += 1;
      cursor.setDate(cursor.getDate() - 1);
    }

    this.focusSummaryCacheSource = this.pomodoros;
    this.totalMinutesCache = totalMinutes;
    this.totalCountCache = totalCount;
    this.averageMinutesCache = totalCount === 0 ? '0' : (totalMinutes / totalCount).toFixed(1);
    this.currentStreakCache = streak;
    this.topTasksCache = Array.from(taskStatMap.values())
      .sort((first: FocusTaskStat, second: FocusTaskStat) => second.minutes - first.minutes)
      .slice(0, 6);
    this.dailyStatsCache = Array.from(dailyStatMap.values())
      .sort((first: DailyFocusStat, second: DailyFocusStat) => first.date.localeCompare(second.date))
      .slice(-7);
  }

  private getTotalMinutes(): number {
    this.ensureFocusSummaryCache();
    return this.totalMinutesCache;
  }

  private getTotalCount(): number {
    this.ensureFocusSummaryCache();
    return this.totalCountCache;
  }

  private getAverageMinutes(): string {
    this.ensureFocusSummaryCache();
    return this.averageMinutesCache;
  }

  private getCurrentStreak(): number {
    this.ensureFocusSummaryCache();
    return this.currentStreakCache;
  }

  private getTopTasks(): FocusTaskStat[] {
    this.ensureFocusSummaryCache();
    return this.topTasksCache;
  }

  private getDailyStats(): DailyFocusStat[] {
    this.ensureFocusSummaryCache();
    return this.dailyStatsCache;
  }

  private formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = `${date.getMonth() + 1}`.padStart(2, '0');
    const day = `${date.getDate()}`.padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  private getHeroDescription(): string {
    if (this.pomodoros.length === 0) {
      return '完成一次番茄钟后，这里会开始累计你的专注时长、连续天数和高频任务。';
    }
    return `累计专注 ${this.getTotalMinutes()} 分钟，共完成 ${this.getTotalCount()} 次番茄钟，平均每次 ${this.getAverageMinutes()} 分钟。`;
  }

  @Builder
  private MetricCard(title: string, value: string, note: string, tone: 'primary' | 'success' | 'warning' | 'neutral' = 'neutral') {
    Column() {
      AppCard({ variant: 'soft', spacing: SPACE_XS, paddingLevel: 'md' }) {
        Text(title)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')

        Text(value)
          .fontSize(TYPE_NUMERIC_MD)
          .fontWeight(FontWeight.Bold)
          .fontColor(
            tone === 'primary'
              ? this.themeColors.primary
              : tone === 'success'
                ? this.themeColors.success
                : tone === 'warning'
                  ? this.themeColors.warning
                  : this.themeColors.textPrimary
          )
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(note)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textMuted)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private TaskRow(item: FocusTaskStat, isLast: boolean) {
    Row({ space: SPACE_SM }) {
      Column({ space: 2 }) {
        Text(item.taskTitle)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(`完成 ${item.count} 次`)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      AppStatusBadge({ text: `${item.minutes} 分钟`, tone: 'primary', iconName: 'focus' })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: isLast ? 0 : 1 }, color: this.themeColors.divider })
  }

  @Builder
  private DayRow(item: DailyFocusStat, isLast: boolean) {
    Row({ space: SPACE_SM }) {
      Text(item.date)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .layoutWeight(1)

      Text(`${item.count} 次`)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textPrimary)

      AppStatusBadge({ text: `${item.minutes} 分钟`, tone: 'success', iconName: 'success' })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: isLast ? 0 : 1 }, color: this.themeColors.divider })
  }

  build() {
    Column({ space: SPACE_SM }) {
      AppPageHeader({
        title: '专注统计',
        subtitle: '查看你的专注投入和高频任务',
        onBack: () => {
          this.getUIContext().getRouter().back();
        }
      })

      if (this.isLoading) {
        Column({ space: SPACE_SM }) {
          AppHeroPanel({
            eyebrow: '专注面板',
            title: '正在整理专注记录',
            description: '会统计完成次数、连续天数和最近 7 天的专注投入。',
            tone: 'info'
          }) {
          }

          AppLoadingState({ label: '正在加载专注数据...' })
        }
        .width('100%')
        .padding({ left: SPACE_LG, right: SPACE_LG })
      } else {
        Scroll() {
          Column({ space: SPACE_LG }) {
            AppHeroPanel({
              eyebrow: '专注面板',
              title: '本阶段专注概览',
              description: this.getHeroDescription(),
              tone: 'info'
            }) {
              Row({ space: SPACE_SM }) {
                this.MetricCard('累计专注', `${this.getTotalMinutes()} 分钟`, '所有已完成番茄钟', 'primary')
                this.MetricCard('专注次数', `${this.getTotalCount()} 次`, `平均 ${this.getAverageMinutes()} 分钟/次`, 'success')
              }
              .width('100%')

              Row({ space: SPACE_SM }) {
                this.MetricCard('连续天数', `${this.getCurrentStreak()} 天`, '按每日是否有专注记录计算', 'warning')
                this.MetricCard('高频任务', `${this.getTopTasks().length} 个`, '最近专注投入最多的任务', 'neutral')
              }
              .width('100%')
            }

            AppPanelSection({
              title: '任务投入排行',
              subtitle: '按累计专注分钟数排序'
            }) {
              if (this.getTopTasks().length === 0) {
                AppEmptyState({
                  title: '还没有已完成的番茄记录',
                  description: '开始一次番茄钟后，这里会自动累计到对应任务。',
                  iconName: 'focus',
                  iconTone: 'info'
                })
              } else {
                AppCard({ spacing: 0, paddingLevel: 'md' }) {
                  Column() {
                    ForEach(this.getTopTasks(), (item: FocusTaskStat, index: number) => {
                      this.TaskRow(item, index === this.getTopTasks().length - 1)
                    })
                  }
                  .width('100%')
                }
              }
            }

            AppPanelSection({
              title: '近 7 天趋势',
              subtitle: '观察近一周的专注次数和分钟数'
            }) {
              if (this.getDailyStats().length === 0) {
                AppEmptyState({
                  title: '最近 7 天没有可展示的专注数据',
                  description: '完成至少一次番茄钟后，这里会自动生成趋势。',
                  iconName: 'calendar',
                  iconTone: 'info'
                })
              } else {
                AppCard({ spacing: 0, paddingLevel: 'md' }) {
                  Column() {
                    ForEach(this.getDailyStats(), (item: DailyFocusStat, index: number) => {
                      this.DayRow(item, index === this.getDailyStats().length - 1)
                    })
                  }
                  .width('100%')
                }
              }
            }

            Blank().height(10)
          }
          .width('100%')
          .padding({ left: SPACE_LG, right: SPACE_LG, bottom: SPACE_LG })
        }
        .align(Alignment.Top)
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
