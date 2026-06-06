import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { authService } from '../services/AuthService';
import {
  type CreditTransactionFilter,
  type CreditTransactionItem,
  creditService
} from '../services/CreditService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppChip } from '../ui/base/AppChip';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { PAGE_PADDING, SECTION_GAP, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_HERO_TITLE, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { TelemetryService, type TelemetryProperties } from '../services/TelemetryService';
import { AppErrorService } from '../services/AppErrorService';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('CreditTransactionsPage');

@Entry
@Component
struct CreditTransactionsPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State isLoading: boolean = true;
  @State isLoadingMore: boolean = false;
  @State selectedFilter: CreditTransactionFilter = 'all';
  @State transactions: CreditTransactionItem[] = [];
  @State totalEarned: number = 0;
  @State totalSpent: number = 0;
  @State totalCount: number = 0;
  @State currentPage: number = 1;
  @State totalPages: number = 1;
  @State errorText: string = '';

  private trackCreditEvent(
    eventName: string,
    properties?: TelemetryProperties
  ): void {
    TelemetryService.track(eventName, properties, 'other');
  }

  aboutToAppear(): void {
    this.trackCreditEvent('credit_transactions_page_view');
    void this.initializePage();
  }

  private async initializePage(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await authService.initialize(context);
      await this.loadTransactions(true, 'initial');
    } catch (error) {
      logger.error('CreditTransactionsPage initialize failed', error as Object);
      this.errorText = '\u79ef\u5206\u6d41\u6c34\u9875\u521d\u59cb\u5316\u5931\u8d25';
      this.isLoading = false;
    }
  }

  private async loadTransactions(reset: boolean, trigger: string = 'initial'): Promise<void> {
    if (reset) {
      this.isLoading = true;
      this.errorText = '';
    } else {
      if (!this.canLoadMore() || this.isLoadingMore) {
        return;
      }
      this.isLoadingMore = true;
    }

    try {
      const targetPage = reset ? 1 : this.currentPage + 1;
      const targetType = this.selectedFilter === 'all' ? undefined : this.selectedFilter;
      const result = await creditService.getTransactions(targetPage, 20, targetType);
      if (!result.success || !result.data) {
        this.errorText = AppErrorService.fromMessage(result.message || '获取积分流水失败', '获取积分流水失败');
        const failedProps: TelemetryProperties = {
          "trigger": trigger,
          "page": targetPage,
          "filter": this.selectedFilter,
          "hasExistingData": this.transactions.length > 0
        };
        this.trackCreditEvent('credit_transactions_load_failed', failedProps);
        if (!reset) {
          this.getUIContext().getPromptAction().showToast({ message: this.errorText });
        }
        return;
      }

      const nextTransactions = result.data.transactions || [];
      this.transactions = reset ? nextTransactions : this.transactions.concat(nextTransactions);
      this.totalEarned = result.data.totalEarned || 0;
      this.totalSpent = result.data.totalSpent || 0;
      this.currentPage = result.data.pagination.page;
      this.totalPages = Math.max(result.data.pagination.totalPages || 1, 1);
      this.totalCount = result.data.pagination.total || this.transactions.length;
      this.errorText = '';
      const loadedProps: TelemetryProperties = {
        "trigger": trigger,
        "page": this.currentPage,
        "count": nextTransactions.length,
        "totalCount": this.totalCount,
        "filter": this.selectedFilter
      };
      this.trackCreditEvent('credit_transactions_loaded', loadedProps);
    } catch (error) {
      logger.error('CreditTransactionsPage load failed', error as Object);
      this.errorText = AppErrorService.fromUnknown(error, '获取积分流水失败');
      const failedProps: TelemetryProperties = {
        "trigger": trigger,
        "filter": this.selectedFilter,
        "hasExistingData": this.transactions.length > 0
      };
      this.trackCreditEvent('credit_transactions_load_failed', failedProps);
      if (!reset) {
        this.getUIContext().getPromptAction().showToast({ message: this.errorText });
      }
    } finally {
      this.isLoading = false;
      this.isLoadingMore = false;
    }
  }

  private canLoadMore(): boolean {
    return this.currentPage < this.totalPages;
  }

  private async switchFilter(filter: CreditTransactionFilter): Promise<void> {
    if (this.selectedFilter === filter || this.isLoading || this.isLoadingMore) {
      return;
    }
    this.selectedFilter = filter;
    const filterProps: TelemetryProperties = {
      "filter": filter
    };
    this.trackCreditEvent('credit_transactions_filter_changed', filterProps);
    await this.loadTransactions(true, 'filter');
  }

  private getFilterLabel(filter: CreditTransactionFilter): string {
    switch (filter) {
      case 'earn':
        return '\u6536\u5165';
      case 'spend':
        return '\u652f\u51fa';
      default:
        return '\u5168\u90e8';
    }
  }

  private getAmountText(item: CreditTransactionItem): string {
    const prefix = item.type === 'earn' ? '+' : '-';
    return `${prefix}${Math.abs(item.amount)}`;
  }

  private getAmountColor(item: CreditTransactionItem): string {
    return item.type === 'earn' ? this.themeColors.success : this.themeColors.danger;
  }

  private getFallbackTitle(item: CreditTransactionItem): string {
    return item.type === 'earn' ? '\u79ef\u5206\u6536\u5165' : '\u79ef\u5206\u652f\u51fa';
  }

  private getSourceLabel(source?: string): string {
    switch (source) {
      case 'register_bonus':
        return '\u6ce8\u518c\u5956\u52b1';
      case 'monthly_grant':
        return '\u4f1a\u5458\u6708\u5ea6\u53d1\u653e';
      case 'purchase':
        return '\u8d2d\u4e70\u8d60\u9001';
      case 'admin_grant':
        return '\u4eba\u5de5\u8865\u53d1';
      case 'event_grant':
        return '\u6d3b\u52a8\u5956\u52b1';
      default:
        return '';
    }
  }

  private getFeatureLabel(feature?: string): string {
    switch (feature) {
      case 'ai_task':
        return 'AI \u4efb\u52a1\u8865\u5168';
      case 'voice_task':
        return '\u8bed\u97f3\u521b\u5efa';
      case 'today_plan':
        return 'AI \u4eca\u65e5\u8ba1\u5212';
      case 'reschedule':
        return 'AI \u4e00\u952e\u91cd\u6392';
      case 'goal_breakdown':
        return 'AI \u76ee\u6807\u62c6\u89e3';
      case 'ai_schedule':
        return 'AI \u65e5\u7a0b\u7f16\u6392';
      default:
        return '';
    }
  }

  private getMetaText(item: CreditTransactionItem): string {
    const categoryText = item.type === 'earn' ? this.getSourceLabel(item.source) : this.getFeatureLabel(item.feature);
    const label = categoryText.length > 0 ? categoryText : this.getFallbackTitle(item);
    return `${label} · \u4f59\u989d ${item.balanceAfter}`;
  }

  private formatDateTime(timestamp: number): string {
    const date = new Date(timestamp);
    const month = `${date.getMonth() + 1}`;
    const day = `${date.getDate()}`;
    const hour = `${date.getHours()}`.padStart(2, '0');
    const minute = `${date.getMinutes()}`.padStart(2, '0');
    return `${month}/${day} ${hour}:${minute}`;
  }

  @Builder
  private SummaryCard(title: string, value: string, color: string) {
    Column() {
      AppCard({ variant: 'soft', spacing: 6, paddingLevel: 'md' }) {
        Text(title)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
        Text(value)
          .fontSize(TYPE_HERO_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
          .width('100%')
        Text(`\u5171 ${this.totalCount} \u6761\u8bb0\u5f55`)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textMuted)
          .width('100%')
      }
    }
    .width('48%')
  }

  @Builder
  private TransactionRow(item: CreditTransactionItem) {
    AppCard({ spacing: 8 }) {
      Row() {
        Column({ space: 6 }) {
          Text(item.description && item.description.length > 0 ? item.description : this.getFallbackTitle(item))
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')
          Text(this.getMetaText(item))
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
          Text(this.formatDateTime(item.createdAt))
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textMuted)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(`${this.getAmountText(item)} \u79ef\u5206`)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getAmountColor(item))
          .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  build() {
    Scroll() {
      Column({ space: SECTION_GAP }) {
        AppPageHeader({
          title: '\u79ef\u5206\u6d41\u6c34',
          subtitle: '\u67e5\u770b\u79ef\u5206\u6536\u5165\u3001\u652f\u51fa\u548c\u4f59\u989d\u53d8\u5316',
          actionText: this.isLoading ? '' : '\u5237\u65b0',
          actionIconName: 'sync',
          onBack: () => this.getUIContext().getRouter().back(),
          onAction: () => {
            this.trackCreditEvent('credit_transactions_refresh_clicked');
            void this.loadTransactions(true, 'refresh');
          }
        })

        Column({ space: 16 }) {
          if (this.isLoading) {
            AppLoadingState({ label: '\u6b63\u5728\u52a0\u8f7d\u79ef\u5206\u660e\u7ec6...' })
          } else {
            Row() {
              this.SummaryCard('\u7d2f\u8ba1\u83b7\u5f97', `+${this.totalEarned}`, this.themeColors.success)
              this.SummaryCard('\u7d2f\u8ba1\u6d88\u8017', `-${this.totalSpent}`, this.themeColors.danger)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            Row({ space: 10 }) {
              AppChip({ label: this.getFilterLabel('all'), active: this.selectedFilter === 'all', tone: 'primary', iconName: 'wallet', tapAction: () => { void this.switchFilter('all'); } })
              AppChip({ label: this.getFilterLabel('earn'), active: this.selectedFilter === 'earn', tone: 'success', iconName: 'success', tapAction: () => { void this.switchFilter('earn'); } })
              AppChip({ label: this.getFilterLabel('spend'), active: this.selectedFilter === 'spend', tone: 'danger', iconName: 'warning', tapAction: () => { void this.switchFilter('spend'); } })
            }
            .width('100%')

            if (this.errorText.length > 0 && this.transactions.length === 0) {
              AppEmptyState({
                iconName: 'warning',
                iconTone: 'danger',
                title: '\u79ef\u5206\u6d41\u6c34\u52a0\u8f7d\u5931\u8d25',
                description: this.errorText,
                actionText: '\u91cd\u65b0\u52a0\u8f7d',
                actionIconName: 'sync',
                onAction: () => {
                  const refreshProps: TelemetryProperties = {
                    "source": 'retry'
                  };
                  this.trackCreditEvent('credit_transactions_refresh_clicked', refreshProps);
                  void this.loadTransactions(true, 'retry');
                }
              })
            } else if (this.transactions.length === 0) {
              AppEmptyState({
                iconName: 'wallet',
                iconTone: 'warning',
                title: '\u6682\u65e0\u79ef\u5206\u6d41\u6c34\u8bb0\u5f55',
                description: '\u540e\u7eed\u79ef\u5206\u5956\u52b1\u3001AI \u6d88\u8017\u548c\u4f1a\u5458\u914d\u989d\u53d8\u5316\u90fd\u4f1a\u5728\u8fd9\u91cc\u5c55\u793a\u3002'
              })
            } else {
              if (this.errorText.length > 0) {
                AppCard({ variant: 'danger', spacing: 8, paddingLevel: 'md' }) {
                  Text('\u90e8\u5206\u6570\u636e\u52a0\u8f7d\u5931\u8d25')
                    .fontSize(TYPE_BODY)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.themeColors.textPrimary)
                  Text(this.errorText)
                    .fontSize(TYPE_META)
                    .fontColor(this.themeColors.textSecondary)
                    .width('100%')
                }
              }

              ForEach(this.transactions, (item: CreditTransactionItem) => {
                this.TransactionRow(item)
              }, (item: CreditTransactionItem) => `${item._id || item.createdAt}_${item.type}_${item.amount}`)

              if (this.canLoadMore()) {
                Row() {
                  AppButton({
                    text: this.isLoadingMore ? '\u52a0\u8f7d\u4e2d...' : '\u52a0\u8f7d\u66f4\u591a',
                    variant: 'secondary',
                    iconName: 'chevron-down',
                    tapAction: () => {
                      const loadMoreProps: TelemetryProperties = {
                        "nextPage": this.currentPage + 1,
                        "filter": this.selectedFilter
                      };
                      this.trackCreditEvent('credit_transactions_load_more_clicked', loadMoreProps);
                      void this.loadTransactions(false, 'load_more');
                    },
                    loading: this.isLoadingMore
                  })
                }
                .width('100%')
              } else {
                Text('\u5df2\u663e\u793a\u5168\u90e8\u8bb0\u5f55')
                  .fontSize(TYPE_META)
                  .fontColor(this.themeColors.textMuted)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: SPACE_XS, bottom: SPACE_XS })
              }
            }
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
