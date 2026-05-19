import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { db } from '../storage/Database';
import { DayEvent, getEventTypeLabel } from '../models/DayEvent';
import { getDayEventMetricText } from '../common/DayEventUtils';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP } from '../foundation/tokens/SpacingTokens';
import { TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('DayEventListPage');

interface DayEventListPageParams {
  eventId?: string;
  keyword?: string;
}

@Entry
@Component
struct DayEventListPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State isLoading: boolean = true;
  @State events: DayEvent[] = [];
  @State titleText: string = '提醒列表';
  @State subtitleText: string = '';
  private targetEventId: string = '';
  private keyword: string = '';

  aboutToAppear(): void {
    this.loadEntryParams();
    this.loadEvents();
  }

  private loadEntryParams(): void {
    const params = this.getUIContext().getRouter().getParams() as DayEventListPageParams;
    this.targetEventId = params?.eventId || '';
    this.keyword = (params?.keyword || '').trim().toLowerCase();
  }

  private async loadEvents(): Promise<void> {
    this.isLoading = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await db.initialize(context as Context);
      let allEvents = db.getAllDayEvents().sort((a: DayEvent, b: DayEvent) => (b.updatedAt || b.createdAt) - (a.updatedAt || a.createdAt));
      if (this.targetEventId.length > 0) {
        allEvents = allEvents.filter((event: DayEvent) => event.id === this.targetEventId);
        this.titleText = '提醒结果';
      } else if (this.keyword.length > 0) {
        allEvents = allEvents.filter((event: DayEvent) => {
          return event.title.toLowerCase().includes(this.keyword) ||
            (event.description || '').toLowerCase().includes(this.keyword) ||
            (event.goalTitle || '').toLowerCase().includes(this.keyword);
        });
        this.titleText = '提醒结果';
      } else {
        this.titleText = '提醒列表';
      }
      this.events = allEvents;
      this.subtitleText = `共 ${this.events.length} 项`;
    } catch (error) {
      logger.error('DayEventListPage load error', error as Object);
      this.events = [];
      this.subtitleText = '共 0 项';
    } finally {
      this.isLoading = false;
    }
  }

  private getEventStatusText(event: DayEvent): string {
    if (event.isCompleted) {
      return '已完成';
    }
    return event.isEnabled ? '进行中' : '已停用';
  }

  private getEventStatusTone(event: DayEvent): 'success' | 'primary' | 'info' {
    if (event.isCompleted) {
      return 'success';
    }
    return event.isEnabled ? 'primary' : 'info';
  }

  private openCreatePage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DayEventCreatePage' });
  }

  @Builder
  private EventRow(event: DayEvent) {
    AppCard({ spacing: 10, paddingLevel: 'md' }) {
      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text(event.title)
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(getEventTypeLabel(event.type))
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        AppStatusBadge({
          text: this.getEventStatusText(event),
          tone: this.getEventStatusTone(event),
          iconName: this.getEventStatusTone(event) === 'success' ? 'success' : 'reminder'
        })
      }
      .width('100%')

      Text(getDayEventMetricText(event))
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  build() {
    Column({ space: SECTION_GAP }) {
      AppPageHeader({
        title: this.titleText,
        subtitle: this.subtitleText,
        onBack: () => {
          this.getUIContext().getRouter().back();
        }
      })

      if (this.isLoading) {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(36)
            .height(36)
            .color(this.themeColors.primary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Row() {
              AppButton({
                text: '新建提醒',
                variant: 'primary',
                iconName: 'reminder',
                tapAction: () => {
                  this.openCreatePage();
                }
              })
            }
            .width('100%')

            if (this.events.length === 0) {
              AppEmptyState({
                iconName: 'reminder',
                iconTone: 'primary',
                title: '还没有提醒项目',
                description: '先创建一个提醒、习惯或关键日期，系统会把它整理到这里。',
                actionText: '立即创建提醒',
                actionIconName: 'reminder',
                onAction: () => {
                  this.openCreatePage();
                }
              })
            } else {
              ForEach(this.events, (event: DayEvent) => {
                this.EventRow(event)
              }, (event: DayEvent) => event.id)
            }

            Blank().height(20)
          }
          .width('100%')
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 12 })
        }
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
