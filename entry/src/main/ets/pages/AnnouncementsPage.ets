import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { announcementService, type AnnouncementItem } from '../services/AnnouncementService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { TelemetryService, type TelemetryProperties } from '../services/TelemetryService';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('AnnouncementsPage');

@Entry
@Component
struct AnnouncementsPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State isLoading: boolean = true;
  @State announcements: AnnouncementItem[] = [];
  @State errorText: string = '';

  private trackAnnouncementEvent(
    eventName: string,
    properties?: TelemetryProperties
  ): void {
    TelemetryService.track(eventName, properties, 'other');
  }

  aboutToAppear(): void {
    this.trackAnnouncementEvent('announcements_page_view');
    void this.loadAnnouncements('appear');
  }

  private async loadAnnouncements(trigger: string = 'appear'): Promise<void> {
    this.isLoading = true;
    this.errorText = '';
    try {
      this.announcements = await announcementService.getActiveAnnouncements();
      const loadedProps: TelemetryProperties = {
        "trigger": trigger,
        "count": this.announcements.length
      };
      this.trackAnnouncementEvent('announcements_loaded', loadedProps);
    } catch (error) {
      logger.error('AnnouncementsPage load failed', error as Object);
      this.announcements = [];
      this.errorText = '获取公告失败';
      const failedProps: TelemetryProperties = {
        "trigger": trigger
      };
      this.trackAnnouncementEvent('announcements_load_failed', failedProps);
    } finally {
      this.isLoading = false;
    }
  }

  private formatDateTime(timestamp: number): string {
    const date = new Date(timestamp);
    const month = `${date.getMonth() + 1}`.padStart(2, '0');
    const day = `${date.getDate()}`.padStart(2, '0');
    const hour = `${date.getHours()}`.padStart(2, '0');
    const minute = `${date.getMinutes()}`.padStart(2, '0');
    return `${date.getFullYear()}-${month}-${day} ${hour}:${minute}`;
  }

  private getValidityText(item: AnnouncementItem): string {
    if (item.expiresAt === 0) {
      return '长期有效';
    }
    return `有效期至 ${this.formatDateTime(item.expiresAt)}`;
  }

  private handleUrlTap(url: string): void {
    if (!url || url.length === 0) {
      return;
    }
    const linkProps: TelemetryProperties = {
      "urlLength": url.length,
      "hasHttps": url.startsWith('https://')
    };
    this.trackAnnouncementEvent('announcements_link_tapped', linkProps);
    this.getUIContext().getPromptAction().showToast({ message: '当前版本暂不支持站内打开链接，请手动复制' });
  }

  @Builder
  private AnnouncementCard(item: AnnouncementItem) {
    AppCard({ variant: 'soft', spacing: 12, interactive: true }) {
      Row() {
              AppStatusBadge({ text: '公告', tone: 'info', iconName: 'info' })
        Blank()
        Text(this.formatDateTime(item.createdAt))
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textMuted)
      }
      .width('100%')

      Text(item.title)
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      if (item.subtitle && item.subtitle.length > 0) {
        Text(item.subtitle)
          .fontSize(TYPE_BODY)
          .lineHeight(22)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      }

      Text(this.getValidityText(item))
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      if (item.url && item.url.length > 0) {
        Text(item.url)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row({ space: SPACE_XS }) {
          AppButton({
            text: '查看链接',
            variant: 'secondary',
            buttonSize: 'sm',
            iconName: 'info',
            tapAction: () => this.handleUrlTap(item.url)
          })
        }
      }
    }
  }

  build() {
    Scroll() {
      Column({ space: SECTION_GAP }) {
        AppPageHeader({
          title: '系统公告',
          subtitle: '查看当前生效的版本更新与运营通知',
          actionText: this.isLoading ? '' : '刷新',
          actionIconName: 'sync',
          onBack: () => this.getUIContext().getRouter().back(),
          onAction: () => {
            this.trackAnnouncementEvent('announcements_refresh_clicked');
            void this.loadAnnouncements('refresh');
          }
        })

        Column({ space: 16 }) {
          if (this.isLoading) {
            AppLoadingState({ label: '正在拉取公告...' })
          } else if (this.errorText.length > 0) {
            AppCard({ variant: 'danger', spacing: 12 }) {
              Text('公告加载失败')
                .fontSize(TYPE_SECTION_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.themeColors.textPrimary)
              Text(this.errorText)
                .fontSize(TYPE_BODY)
                .fontColor(this.themeColors.textSecondary)
                .width('100%')
              Row() {
                AppButton({
                  text: '重新加载',
                  variant: 'secondary',
                  buttonSize: 'sm',
                  iconName: 'sync',
                  tapAction: () => {
                    const refreshProps: TelemetryProperties = {
                      "source": 'retry'
                    };
                    this.trackAnnouncementEvent('announcements_refresh_clicked', refreshProps);
                    void this.loadAnnouncements('retry');
                  }
                })
              }
            }
          } else if (this.announcements.length === 0) {
            AppEmptyState({
              iconName: 'info',
              iconTone: 'info',
              title: '当前没有生效中的公告',
              description: '后续版本更新、灰度通知和临时公告都会在这里展示。'
            })
          } else {
            ForEach(this.announcements, (item: AnnouncementItem) => {
              this.AnnouncementCard(item)
            }, (item: AnnouncementItem) => item.id)
          }
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: PAGE_PADDING })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .scrollBar(BarState.Off)
  }
}
