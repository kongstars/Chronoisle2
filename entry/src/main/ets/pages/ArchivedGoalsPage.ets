import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { db } from '../storage/Database';
import { Goal } from '../models/Goal';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('ArchivedGoalsPage');

@Entry
@Component
struct ArchivedGoalsPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State isLoading: boolean = true;
  @State archivedGoals: Goal[] = [];

  aboutToAppear(): void {
    void this.loadGoals();
  }

  private async loadGoals(): Promise<void> {
    this.isLoading = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await db.initialize(context);
      this.archivedGoals = db.getAllGoals()
        .filter((goal: Goal) => goal.isArchived)
        .sort((first: Goal, second: Goal) => (second.archivedAt || second.updatedAt) - (first.archivedAt || first.updatedAt));
    } catch (error) {
      logger.error('ArchivedGoalsPage load error', error as Object);
      this.archivedGoals = [];
    } finally {
      this.isLoading = false;
    }
  }

  private formatDate(timestamp?: number): string {
    if (!timestamp) {
      return '未知时间';
    }
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = `${date.getMonth() + 1}`.padStart(2, '0');
    const day = `${date.getDate()}`.padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  @Builder
  private GoalCard(goal: Goal) {
    AppCard({
      spacing: 10,
      interactive: true,
      tapAction: () => this.getUIContext().getRouter().pushUrl({ url: 'pages/GoalDetailPage', params: { goalId: goal.id } })
    }) {
      Row() {
        Text(goal.title)
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${goal.progress}%`)
          .fontSize(TYPE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.primary)
      }
      .width('100%')

      Text(goal.description || '暂无描述')
        .fontSize(TYPE_BODY)
        .lineHeight(20)
        .fontColor(this.themeColors.textSecondary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row() {
            AppStatusBadge({ text: goal.category as string, tone: 'primary', iconName: 'goal' })
        Blank()
        Text(`归档于 ${this.formatDate(goal.archivedAt)}`)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textMuted)
      }
      .width('100%')
    }
  }

  build() {
    Scroll() {
      Column({ space: SECTION_GAP }) {
        AppPageHeader({
          title: '已归档目标',
          subtitle: `共 ${this.archivedGoals.length} 个目标`,
          actionText: this.isLoading ? '' : '刷新',
          actionIconName: 'sync',
          onBack: () => this.getUIContext().getRouter().back(),
          onAction: () => { void this.loadGoals(); }
        })

        Column({ space: 16 }) {
          if (this.isLoading) {
            AppLoadingState({ label: '正在整理归档目标...' })
          } else if (this.archivedGoals.length === 0) {
            AppEmptyState({
              iconName: 'archive',
              iconTone: 'info',
              title: '当前还没有已归档目标',
              description: '当目标完成或暂时下线时，可以进入归档，后续仍可回看历史记录。'
            })
          } else {
            ForEach(this.archivedGoals, (goal: Goal) => {
              this.GoalCard(goal)
            }, (goal: Goal) => goal.id)
          }
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: PAGE_PADDING })
      }
      .width('100%')
    }
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .scrollBar(BarState.Off)
  }
}
