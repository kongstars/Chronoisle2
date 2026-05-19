import http from '@ohos.net.http';
import { Goal } from '../models/Goal';
import { db } from '../storage/Database';
import { authService, UserAccount } from '../services/AuthService';
import { themeService } from '../services/ThemeService';
import { ThemeMode, ThemeColors, LightTheme } from '../theme/AppTheme';
import AppConfig from '../Utils/AppConfig';
import { TelemetryService } from '../services/TelemetryService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppChip } from '../ui/base/AppChip';
import { AppListRow } from '../ui/base/AppListRow';
import { AppPanelSection } from '../ui/base/AppPanelSection';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, PANEL_GAP, SECTION_GAP, SPACE_2XS, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_HERO_TITLE, TYPE_META, TYPE_NUMERIC_LG, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { BOTTOM_CONTENT_SPACER, AVATAR_RADIUS_MD, AVATAR_SIZE_MD } from '../foundation/tokens/ComponentSizeTokens';
import { LINE_HEIGHT_BODY, LINE_HEIGHT_TIGHT } from '../foundation/tokens/VisualTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('MeTab');

@Component
export struct MeTab {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @StorageLink('themeMode') currentThemeMode: ThemeMode = ThemeMode.SYSTEM;
  @Prop user: UserAccount | null = null;
  @State localUser: UserAccount | null = null;
  @State archivedGoalCount: number = 0;
  @State creditBalance: number = 0;
  @State creditFrozen: boolean = false;

  aboutToAppear(): void {
    void this.initializeData();
  }

  private async initializeData(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await db.initialize(context);
      await authService.initialize(context);
      await themeService.initialize(context);
      await authService.refreshUserFromServer();
      this.currentThemeMode = themeService.getThemeMode();
      await this.loadUserData();
      await this.loadCreditBalance();
      this.loadArchivedGoalCount();
    } catch (error) {
      logger.error('MeTab initializeData failed', error as Object);
    }
  }

  private async loadUserData(): Promise<void> {
    this.localUser = this.user;
    const freshUser = await authService.getCurrentUser();
    if (freshUser) {
      this.localUser = freshUser;
    }
  }

  private loadArchivedGoalCount(): void {
    const allGoals: Goal[] = db.getAllGoals();
    this.archivedGoalCount = allGoals.filter((goal: Goal) => goal.isArchived).length;
  }

  private getCurrentUser(): UserAccount | null {
    return this.localUser || this.user;
  }

  private isPremiumActive(): boolean {
    const currentUser = this.getCurrentUser();
    return authService.isPremiumUser(currentUser);
  }

  private getDisplayName(): string {
    const currentUser = this.getCurrentUser();
    if (currentUser?.nickname && currentUser.nickname.trim().length > 0) {
      return currentUser.nickname;
    }
    if (currentUser?.account && currentUser.account.trim().length > 0) {
      return currentUser.account;
    }
    if (currentUser?.displayId && currentUser.displayId.trim().length > 0) {
      return currentUser.displayId;
    }
    return '未登录';
  }

  private getDisplayId(): string {
    const currentUser = this.getCurrentUser();
    if (!currentUser) {
      return '--';
    }
    if (currentUser.displayId && currentUser.displayId.trim().length > 0) {
      return currentUser.displayId;
    }
    return currentUser.userId.length > 8 ? currentUser.userId.substring(0, 8) : currentUser.userId;
  }

  private getAccountSummary(): string {
    const currentUser = this.getCurrentUser();
    if (!currentUser) {
      return '登录后可查看完整账号与权益信息';
    }
    if (currentUser.account && currentUser.account.trim().length > 0) {
      return currentUser.account;
    }
    return `ID: ${this.getDisplayId()}`;
  }

  private getMembershipTitle(): string {
    if (!this.isPremiumActive()) {
      return '基础版';
    }
    const currentUser = this.getCurrentUser();
    if (currentUser?.membershipProductId === 'vip_yearly_continuous' ||
      currentUser?.membershipPlan === 'yearly_continuous') {
      return '已开通连续包年';
    }
    if (currentUser?.membershipProductId === 'vip_monthly_continuous' ||
      currentUser?.membershipPlan === 'monthly_continuous') {
      return '已开通连续包月';
    }
    return '高级会员已生效';
  }

  private getMembershipButtonText(): string {
    return this.isPremiumActive() ? '查看权益' : '开通会员';
  }

  private getRenewTimeText(): string {
    const currentUser = this.getCurrentUser();
    const renewAt = currentUser?.membershipRenewAt || currentUser?.membershipExpireAt || 0;
    if (!renewAt) {
      return this.isPremiumActive() ? '待同步' : '续费时间按购买结果更新';
    }
    const renewDate = new Date(renewAt);
    return `${renewDate.getFullYear()}-${`${renewDate.getMonth() + 1}`.padStart(2, '0')}-${`${renewDate.getDate()}`.padStart(2, '0')}`;
  }

  private getMembershipDescription(): string {
    if (this.isPremiumActive()) {
      return `自动续费时间 ${this.getRenewTimeText()}`;
    }
    return '开通后可获得更高 AI 配额和更完整统计能力';
  }

  private async loadCreditBalance(): Promise<void> {
    try {
      const token = await authService.getToken();
      if (!token) {
        this.creditBalance = 0;
        this.creditFrozen = false;
        return;
      }

      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/credit/balance`,
        {
          method: http.RequestMethod.GET,
          header: { 'Authorization': `Bearer ${token}` },
          connectTimeout: 8000,
          readTimeout: 8000
        }
      );
      httpRequest.destroy();
      if (response.responseCode === 200) {
        const raw = JSON.parse(response.result as string) as Record<string, Object>;
        const success = raw['success'] as boolean;
        if (success) {
          const data = raw['data'] as Record<string, Object>;
          this.creditBalance = (data['balance'] as number) || 0;
          this.creditFrozen = (data['isFrozen'] as boolean) || false;
        }
      }
    } catch (error) {
      logger.warn('MeTab loadCreditBalance failed, using fallback', error as Object);
      const fallbackUser = this.getCurrentUser();
      if (fallbackUser && typeof fallbackUser.creditBalance === 'number') {
        this.creditBalance = fallbackUser.creditBalance;
      }
    }
  }

  private getAvatarSource(): ResourceStr | string {
    const currentUser = this.getCurrentUser();
    if (currentUser?.avatar && currentUser.avatar.length > 0) {
      return currentUser.avatar;
    }
    return $r('app.media.startIcon');
  }

  private isThemeSelected(mode: ThemeMode): boolean {
    return this.currentThemeMode === mode;
  }

  private async switchTheme(mode: ThemeMode): Promise<void> {
    if (this.currentThemeMode === mode) {
      return;
    }
    this.currentThemeMode = mode;
    await themeService.setThemeMode(mode);
    this.getUIContext().getPromptAction().showToast({ message: '主题已切换' });
  }

  private openMembershipPage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/MembershipPage' });
  }

  private openCreditTransactionsPage(): void {
    TelemetryService.track('credit_transactions_entry_clicked', undefined, 'other');
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CreditTransactionsPage' });
  }

  private openStatsPage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/StatsHubPage' });
  }

  private openArchivedGoals(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/ArchivedGoalsPage' });
  }

  private openHelpPage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/HelpPage' });
  }

  private openAboutPage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/AboutPage' });
  }

  private openLoginPage(): void {
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
  }

  private async handleLogout(): Promise<void> {
    await authService.logout();
    this.localUser = null;
    this.getUIContext().getPromptAction().showToast({ message: '已退出登录' });
    this.openLoginPage();
  }

  @Builder
  private ProfileCard() {
    AppCard({ variant: 'raised', spacing: SPACE_MD, paddingLevel: 'md' }) {
      Row({ space: SPACE_MD }) {
        Image(this.getAvatarSource())
          .width(AVATAR_SIZE_MD)
          .height(AVATAR_SIZE_MD)
          .borderRadius(AVATAR_RADIUS_MD)
          .backgroundColor(this.themeColors.surfaceSoft)

        Column({ space: SPACE_XS }) {
          Row({ space: SPACE_SM }) {
            Text(this.getDisplayName())
              .fontSize(TYPE_HERO_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
              .layoutWeight(1)

            if (this.isPremiumActive()) {
              AppStatusBadge({ text: '会员中', tone: 'premium', iconName: 'wallet' })
            }
          }
          .width('100%')

          Text(this.getAccountSummary())
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(`ID: ${this.getDisplayId()}`)
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textMuted)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
  }

  @Builder
  private MembershipCard() {
    AppCard({ variant: 'premium', spacing: SPACE_SM, paddingLevel: 'md' }) {
      Column({ space: SPACE_XS }) {
        Text(this.getMembershipTitle())
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.premiumText)
          .width('100%')

        Text(this.getMembershipDescription())
          .fontSize(TYPE_META)
          .lineHeight(LINE_HEIGHT_TIGHT)
          .fontColor(this.themeColors.premiumText)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row() {
        Column({ space: SPACE_2XS }) {
          Text('当前积分余额')
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.premiumText)

          Row() {
            Text(`${this.creditBalance}`)
              .fontSize(TYPE_NUMERIC_LG)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.premiumText)

            Text('分')
              .fontSize(TYPE_META)
              .fontColor(this.themeColors.premiumText)
              .margin({ left: SPACE_2XS, top: SPACE_SM })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        AppButton({
          text: this.getMembershipButtonText(),
          variant: 'premium',
          buttonSize: 'sm',
          iconName: 'wallet',
          tapAction: () => this.openMembershipPage()
        })
      }
      .width('100%')

      if (this.creditFrozen) {
        Text('积分账户当前处于冻结状态，请联系支持处理。')
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.danger)
          .width('100%')
      }
    }
  }

  @Builder
  private SyncAndDataCard() {
    AppCard({ spacing: 0, paddingLevel: 'md' }) {
        AppListRow({
          leadingIcon: 'stats',
          title: '查看统计',
          subtitle: '查看目标、任务与专注统计',
        trailingText: '',
        showDivider: true,
        tapAction: () => this.openStatsPage()
      })
        AppListRow({
          leadingIcon: 'wallet',
          title: '积分流水',
          subtitle: this.creditFrozen ? '当前积分账户处于冻结状态' : `当前余额 ${this.creditBalance} 分`,
        trailingText: '明细',
        tone: 'primary',
        showDivider: true,
        tapAction: () => this.openCreditTransactionsPage()
      })
        AppListRow({
          leadingIcon: 'archive',
          title: '已归档目标',
          subtitle: '回看已经完成或暂时下线的目标',
        trailingText: `${this.archivedGoalCount} 个`,
        showDivider: false,
        tapAction: () => this.openArchivedGoals()
      })
    }
  }

  @Builder
  private ThemeCard() {
    AppCard({ spacing: SPACE_MD, paddingLevel: 'md' }) {
      Row({ space: SPACE_SM }) {
        AppChip({
          label: '浅色',
          active: this.isThemeSelected(ThemeMode.LIGHT),
          tone: 'primary',
          iconName: 'today',
          tapAction: () => { void this.switchTheme(ThemeMode.LIGHT); }
        })
        AppChip({
          label: '深色',
          active: this.isThemeSelected(ThemeMode.DARK),
          tone: 'primary',
          iconName: 'focus',
          tapAction: () => { void this.switchTheme(ThemeMode.DARK); }
        })
        AppChip({
          label: '跟随系统',
          active: this.isThemeSelected(ThemeMode.SYSTEM),
          tone: 'primary',
          iconName: 'gear',
          tapAction: () => { void this.switchTheme(ThemeMode.SYSTEM); }
        })
      }
      .width('100%')
    }
  }

  @Builder
  private MoreCard() {
    AppCard({ spacing: 0, paddingLevel: 'md' }) {
        AppListRow({
          leadingIcon: 'help',
          title: '帮助中心',
          subtitle: '查看引导和常见问题',
        trailingText: '使用说明',
        showDivider: true,
        tapAction: () => this.openHelpPage()
      })
        AppListRow({
          leadingIcon: 'info',
          title: '关于我们',
          subtitle: '查看应用定位和恢复进度',
        trailingText: '应用信息',
        showDivider: false,
        tapAction: () => this.openAboutPage()
      })
    }
  }

  @Builder
  private LoggedInView() {
    Column({ space: SECTION_GAP }) {
      AppPanelSection({
        title: '账户',
        subtitle: '账号与身份信息',
        insetHorizontal: 0
      }) {
        this.ProfileCard()
      }

      AppPanelSection({
        title: '权益',
        subtitle: '会员与积分概览',
        insetHorizontal: 0
      }) {
        this.MembershipCard()
      }

      AppPanelSection({
        title: '数据中心',
        subtitle: '统计、积分和归档内容',
        insetHorizontal: 0
      }) {
        this.SyncAndDataCard()
      }

      AppPanelSection({
        title: '主题偏好',
        subtitle: '浅色、深色和跟随系统',
        insetHorizontal: 0
      }) {
        this.ThemeCard()
      }

      AppPanelSection({
        title: '更多',
        subtitle: '帮助与应用信息',
        insetHorizontal: 0
      }) {
        this.MoreCard()
      }

      Row() {
        AppButton({
          text: '退出登录',
          variant: 'danger',
          fullWidth: true,
          iconName: 'warning',
          tapAction: () => { void this.handleLogout(); }
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
  }

  @Builder
  private NotLoggedView() {
    Column({ space: SECTION_GAP }) {
      AppPanelSection({
        title: '账户',
        subtitle: '登录后查看会员状态、积分和完整设置',
        insetHorizontal: 0
      }) {
        AppCard({ spacing: SPACE_MD, paddingLevel: 'md' }) {
          Text('登录后可查看会员状态、积分余额和完整设置入口。')
            .fontSize(TYPE_META)
            .lineHeight(LINE_HEIGHT_BODY)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')

          Row() {
            AppButton({
              text: '去登录',
              variant: 'primary',
              fullWidth: true,
              iconName: 'profile',
              tapAction: () => this.openLoginPage()
            })
          }
          .width('100%')
        }
      }

      AppPanelSection({
        title: '主题偏好',
        subtitle: '浅色、深色和跟随系统',
        insetHorizontal: 0
      }) {
        this.ThemeCard()
      }

      AppPanelSection({
        title: '更多',
        subtitle: '帮助与应用信息',
        insetHorizontal: 0
      }) {
        this.MoreCard()
      }
    }
    .width('100%')
  }

  build() {
    Scroll() {
      Column({ space: SECTION_GAP }) {
        AppPageHeader({
          title: '我的',
          subtitle: '账户、权益、同步和帮助入口',
          showBack: false
        })

        Column({ space: SECTION_GAP }) {
          if (this.getCurrentUser()) {
            this.LoggedInView()
          } else {
            this.NotLoggedView()
          }
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: PAGE_PADDING + BOTTOM_CONTENT_SPACER })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .scrollBar(BarState.Off)
  }
}
