import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { authService, UserAccount } from '../services/AuthService';
import { iapService, IAPProduct } from '../services/IAPService';
import { common } from '@kit.AbilityKit';
import { TelemetryService, type TelemetryProperties } from '../services/TelemetryService';
import AppConfig from '../Utils/AppConfig';
import { AppErrorService } from '../services/AppErrorService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_HERO_TITLE, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('MembershipPage');

@Entry
@Component
struct MembershipPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State user: UserAccount | null = null;
  @State isLoading: boolean = true;
  @State isPurchasing: boolean = false;
  @State currentProductId: string = '';
  @State products: IAPProduct[] = [];

  aboutToAppear(): void {
    TelemetryService.trackImmediate('membership_page_view', undefined, 'membership');
    void this.loadPageData();
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch (_) {
    }
  }

  private async loadPageData(): Promise<void> {
    this.isLoading = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await authService.initialize(context);
      const refreshedUser = await authService.refreshUserFromServer();
      this.user = refreshedUser ? refreshedUser : await authService.getCurrentUser();

      if (AppConfig.useMockMembershipPurchase()) {
        this.products = this.buildMockProducts();
      } else {
        this.products = await iapService.queryProducts(
          context as common.UIAbilityContext,
          AppConfig.getMembershipProductIds()
        );
      }
    } catch (error) {
      logger.error('MembershipPage load error', error as Object);
      this.user = await authService.getCurrentUser();
      this.products = [];
    } finally {
      this.isLoading = false;
    }
  }

  private isPremiumActive(): boolean {
    return authService.isPremiumUser(this.user);
  }

  private getCurrentProductId(): string {
    if (!this.isPremiumActive()) {
      return '';
    }
    if (this.user?.membershipProductId) {
      return this.user.membershipProductId;
    }
    if (this.user?.membershipPlan === 'yearly_continuous') {
      return 'vip_yearly_continuous';
    }
    if (this.user?.membershipPlan === 'monthly_continuous') {
      return 'vip_monthly_continuous';
    }
    return '';
  }

  private getPendingProductId(): string {
    if (!this.isPremiumActive()) {
      return '';
    }
    return this.user?.pendingMembershipProductId || '';
  }

  private getProductPlanText(productId: string): string {
    if (productId === 'vip_yearly_continuous') {
      return '连续包年';
    }
    if (productId === 'vip_monthly_continuous') {
      return '连续包月';
    }
    return '高级会员';
  }

  private getCurrentPlanText(): string {
    const productId = this.getCurrentProductId();
    return this.getProductPlanText(productId);
  }

  private getMembershipTitle(): string {
    return this.isPremiumActive() ? `已开通${this.getCurrentPlanText()}` : '升级为高级会员';
  }

  private getMembershipDescription(): string {
    if (!this.user) {
      return '登录后可查看会员积分权益、当前余额和购买选项。';
    }
    if (this.isPremiumActive()) {
      const pendingProductId = this.getPendingProductId();
      if (pendingProductId) {
        return `${this.getPendingSwitchDaysText()}后更换为${this.getProductPlanText(pendingProductId)}。系统会按月赠送积分，AI 功能按实际使用扣减积分。`;
      }
      return '系统会按月赠送积分，AI 功能按实际使用扣减积分，订阅续费状态以华为账号为准。';
    }
    return '开通后每月赠送 500 积分，AI 功能按实际使用扣减积分，余额可持续累计。';
  }

  private getRenewTimeText(): string {
    const renewAt = this.user?.membershipRenewAt || this.user?.membershipExpireAt || 0;
    if (!renewAt) {
      return this.isPremiumActive() ? '待同步' : '尚未开通';
    }
    const date = new Date(renewAt);
    const year = date.getFullYear();
    const month = `${date.getMonth() + 1}`.padStart(2, '0');
    const day = `${date.getDate()}`.padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  private getCreditBalanceText(): string {
    return `${this.user?.creditBalance || 0} 积分`;
  }

  private getMonthlyGrantHint(): string {
    if (!this.user) {
      return '登录后可查看会员积分发放状态。';
    }
    if (!this.isPremiumActive()) {
      return '开通高级会员后，系统每月自动发放 500 积分。';
    }
    return this.user?.lastGrantMonth
      ? `本月积分已发放，最近一次发放月份：${this.user.lastGrantMonth}`
      : '订阅生效期间，系统会在当月自动发放 500 积分。';
  }

  private sortProducts(products: IAPProduct[]): IAPProduct[] {
    return [...products].sort((first: IAPProduct, second: IAPProduct) => {
      const weight = (productId: string): number => {
        if (productId.includes('yearly_continuous')) return 1;
        if (productId.includes('monthly_continuous')) return 2;
        if (productId.includes('yearly')) return 3;
        return 4;
      };
      return weight(first.productId) - weight(second.productId);
    });
  }

  private getProductTag(productId: string): string {
    if (productId.includes('yearly')) {
      return '年卡自动续期';
    }
    return '月卡自动续期';
  }

  private getProductDisplayName(product: IAPProduct): string {
    const productName = product.productName.trim();
    if (productName && productName !== product.productId) {
      return productName;
    }
    if (product.productId === 'vip_yearly_continuous') {
      return '高级会员年卡';
    }
    if (product.productId === 'vip_monthly_continuous') {
      return '高级会员月卡';
    }
    return product.productId;
  }

  private getProductDisplayDesc(product: IAPProduct): string {
    if (product.productDesc.trim()) {
      return product.productDesc;
    }
    if (product.productId === 'vip_yearly_continuous') {
      return '连续包年，开通全部会员权益，订阅生效期间每月赠送 500 积分。';
    }
    if (product.productId === 'vip_monthly_continuous') {
      return '自动包月会员，开通全部会员权益，每月赠送 500 积分。';
    }
    return '开通高级会员权益';
  }

  private getTelemetryPlan(productId: string): string {
    return productId.includes('yearly') ? 'yearly' : 'monthly';
  }

  private buildMockProducts(): IAPProduct[] {
    return [
      {
        productId: 'vip_yearly_continuous',
        price: '198',
        priceCurrencyCode: 'CNY',
        productName: '测试高级会员年卡',
        productDesc: '用于联调环境的模拟会员购买。'
      },
      {
        productId: 'vip_monthly_continuous',
        price: '25',
        priceCurrencyCode: 'CNY',
        productName: '测试高级会员月卡',
        productDesc: '用于联调环境的模拟会员购买。'
      }
    ];
  }

  private getMockPlan(productId: string): string {
    if (productId.includes('yearly')) {
      return productId.includes('continuous') ? 'yearly_continuous' : 'yearly';
    }
    return productId.includes('continuous') ? 'monthly_continuous' : 'monthly';
  }

  private isProductOpened(productId: string): boolean {
    if (!this.isPremiumActive()) {
      return false;
    }
    const pendingProductId = this.getPendingProductId();
    return pendingProductId ? pendingProductId === productId : this.getCurrentProductId() === productId;
  }

  private isDowngradeToMonthly(productId: string): boolean {
    return this.isPremiumActive() &&
      this.getCurrentProductId() === 'vip_yearly_continuous' &&
      productId === 'vip_monthly_continuous';
  }

  private getProductActionText(productId: string): string {
    if (this.isProductOpened(productId)) {
      return '已开通';
    }
    if (this.isPurchasing && this.currentProductId === productId) {
      return '处理中...';
    }
    if (this.isDowngradeToMonthly(productId)) {
      return '暂不支持';
    }
    return this.isPremiumActive() ? '切换' : '立即开通';
  }

  private getProductCardVariant(productId: string): 'premium' | 'raised' | 'soft' {
    if (this.isProductOpened(productId) || this.getPendingProductId() === productId) {
      return 'premium';
    }
    if (productId.includes('yearly')) {
      return 'raised';
    }
    return 'soft';
  }

  private getProductBadgeTone(productId: string): 'premium' | 'primary' | 'neutral' {
    if (this.isProductOpened(productId) || this.getPendingProductId() === productId) {
      return 'premium';
    }
    if (productId.includes('yearly')) {
      return 'primary';
    }
    return 'neutral';
  }

  private getProductPriceColor(productId: string): string {
    if (this.isProductOpened(productId) || this.getPendingProductId() === productId) {
      return this.themeColors.premiumText;
    }
    if (productId.includes('yearly')) {
      return this.themeColors.primary;
    }
    return this.themeColors.textPrimary;
  }

  private getProductMetaColor(productId: string): string {
    if (this.isProductOpened(productId) || this.getPendingProductId() === productId) {
      return this.themeColors.premiumText;
    }
    return this.themeColors.textMuted;
  }

  private getProductActionVariant(productId: string): 'premium' | 'secondary' {
    if (this.isProductOpened(productId)) {
      return 'secondary';
    }
    return 'premium';
  }

  private getPendingSwitchDaysText(): string {
    const effectiveAt = this.getCurrentSubscriptionEndAt();
    if (!effectiveAt) {
      return '续费时';
    }
    const days = Math.max(0, Math.ceil((effectiveAt - Date.now()) / (24 * 60 * 60 * 1000)));
    return days <= 0 ? '今天' : `${days}天`;
  }

  private getCurrentSubscriptionEndAt(): number {
    return this.user?.pendingMembershipEffectiveAt || this.user?.membershipRenewAt ||
      this.user?.membershipExpireAt || 0;
  }

  private getProductPendingHint(productId: string): string {
    if (!this.isPremiumActive() || this.getPendingProductId() !== productId) {
      return '';
    }
    return `${this.getPendingSwitchDaysText()}后更换为${this.getProductPlanText(productId)}`;
  }

  private getProductLimitHint(productId: string): string {
    if (!this.isDowngradeToMonthly(productId)) {
      return '';
    }
    return '当前连续包年有效期内暂不支持切换为连续包月，可在华为订阅管理中取消续费，到期后再开通包月。';
  }

  private isProductActionDisabled(productId: string): boolean {
    return this.isProductOpened(productId) || this.isDowngradeToMonthly(productId);
  }

  private isSwitchingProduct(productId: string): boolean {
    return this.isPremiumActive() && !this.isProductOpened(productId);
  }

  private async confirmSwitchProduct(productId: string): Promise<boolean> {
    const currentPlan = this.getCurrentPlanText();
    const targetPlan = this.getProductPlanText(productId);
    const switchTime = this.getPendingSwitchDaysText();
    const message = this.getCurrentProductId() === 'vip_monthly_continuous' && productId === 'vip_yearly_continuous'
      ? `您当前已开通${currentPlan}，切换为${targetPlan}后将立即生效，原订阅将由华为处理。是否继续？`
      : `您当前已经订阅${currentPlan}，是否切换为${targetPlan}？您切换订阅后，将在当前订阅到期（${switchTime}）后自动切换订阅。`;
    const dialogResult = await this.getUIContext().getPromptAction().showDialog({
      title: '切换订阅',
      message,
      buttons: [
        { text: '取消', color: this.themeColors.textSecondary },
        { text: '确认切换', color: this.themeColors.primary }
      ]
    });
    return dialogResult.index === 1;
  }

  private async handlePurchase(productId: string): Promise<void> {
    if (this.isPurchasing || this.isProductOpened(productId)) {
      return;
    }
    const context = this.getUIContext().getHostContext() as Context;
    await authService.initialize(context);
    const currentUser = await authService.getCurrentUser();
    if (!currentUser) {
      this.showToast('请先登录后再开通会员');
      return;
    }
    if (this.isDowngradeToMonthly(productId)) {
      this.showToast('当前连续包年有效期内暂不支持切换为连续包月');
      return;
    }
    if (this.isSwitchingProduct(productId)) {
      const confirmed = await this.confirmSwitchProduct(productId);
      if (!confirmed) {
        return;
      }
    }

    this.isPurchasing = true;
    this.currentProductId = productId;
    try {
      (() => {
        let purchaseProps: TelemetryProperties = {
          "plan": this.getTelemetryPlan(productId),
          "productId": productId
        };
        TelemetryService.trackImmediate('membership_purchase_attempt', purchaseProps, 'membership');
      })();

      if (AppConfig.useMockMembershipPurchase()) {
        const updatedUser = await authService.purchaseMembership(this.getMockPlan(productId));
        if (updatedUser) {
          this.user = updatedUser;
          this.showToast('测试环境会员状态已更新');
          await this.loadPageData();
        } else {
          this.showToast('模拟会员购买失败');
        }
      } else {
        const result = await iapService.purchase(context as common.UIAbilityContext, productId);
        this.showToast(AppErrorService.fromMessage(result.message, '购买失败，请稍后重试'));
        if (result.success) {
          await this.loadPageData();
        }
      }
    } catch (error) {
      logger.error('Membership purchase error', error as Object);
      this.showToast(AppErrorService.fromUnknown(error, '购买失败，请稍后重试'));
    } finally {
      this.isPurchasing = false;
      this.currentProductId = '';
    }
  }

  private async handleRestorePurchase(): Promise<void> {
    if (this.isPurchasing || AppConfig.useMockMembershipPurchase()) {
      return;
    }
    const context = this.getUIContext().getHostContext() as Context;
    await authService.initialize(context);
    const currentUser = await authService.getCurrentUser();
    if (!currentUser) {
      this.showToast('请先登录后再同步订阅');
      return;
    }

    this.isPurchasing = true;
    this.currentProductId = 'restore_purchase';
    try {
      const result = await iapService.restoreMembershipFromHuawei(context as common.UIAbilityContext);
      this.showToast(AppErrorService.fromMessage(result.message, '同步订阅失败，请稍后重试'));
      if (result.success) {
        await this.loadPageData();
      }
    } catch (error) {
      logger.error('Membership restore purchase error', error as Object);
      this.showToast(AppErrorService.fromUnknown(error, '同步订阅失败，请稍后重试'));
    } finally {
      this.isPurchasing = false;
      this.currentProductId = '';
    }
  }

  @Builder
  private BenefitRow(title: string, description: string) {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')
        Text(description)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
          .lineHeight(18)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  private CreditCostRow(title: string, costText: string) {
    Row() {
      Text(title)
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.textPrimary)
        .layoutWeight(1)

      Text(costText)
        .fontSize(TYPE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.primary)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  private ProductCard(product: IAPProduct) {
    AppCard({ spacing: 10, variant: this.getProductCardVariant(product.productId) }) {
      Row() {
        Text(this.getProductDisplayName(product))
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .layoutWeight(1)
        AppStatusBadge({ text: this.getProductTag(product.productId), tone: this.getProductBadgeTone(product.productId), iconName: 'wallet' })
      }
      .width('100%')

      Text(this.getProductDisplayDesc(product))
        .fontSize(TYPE_META)
        .lineHeight(18)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Row() {
        Row({ space: 6 }) {
          Text(product.price || '--')
            .fontSize(TYPE_HERO_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getProductPriceColor(product.productId))
          if (product.priceCurrencyCode) {
            Text(product.priceCurrencyCode)
              .fontSize(TYPE_META)
              .fontColor(this.getProductMetaColor(product.productId))
              .margin({ top: 8 })
          }
        }
        .alignItems(VerticalAlign.Bottom)

        Blank()

        AppButton({
          text: this.getProductActionText(product.productId),
          variant: this.getProductActionVariant(product.productId),
          buttonSize: 'sm',
          iconName: 'wallet',
          loading: this.isPurchasing && this.currentProductId === product.productId,
          disabled: this.isProductActionDisabled(product.productId),
          tapAction: () => { void this.handlePurchase(product.productId); }
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      if (this.getProductPendingHint(product.productId).length > 0) {
        Text(this.getProductPendingHint(product.productId))
          .fontSize(TYPE_META)
          .lineHeight(18)
          .fontColor(this.getProductCardVariant(product.productId) === 'premium' ? this.themeColors.premiumText : this.themeColors.primary)
          .width('100%')
          .textAlign(TextAlign.End)
      }

      if (this.getProductLimitHint(product.productId).length > 0) {
        Text(this.getProductLimitHint(product.productId))
          .fontSize(TYPE_META)
          .lineHeight(18)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
          .textAlign(TextAlign.End)
      }
    }
  }

  build() {
    Column({ space: 0 }) {
      AppPageHeader({
        title: '会员中心',
        subtitle: '查看积分权益和开通选项',
        actionText: this.isLoading ? '' : '刷新',
        actionIconName: 'sync',
        onBack: () => this.getUIContext().getRouter().back(),
        onAction: () => { void this.loadPageData(); }
      })

      if (this.isLoading) {
        Column() {
          AppLoadingState({ label: '正在加载会员信息...' })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 8, bottom: PAGE_PADDING })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
      } else {
        Scroll() {
          Column({ space: SECTION_GAP }) {
            AppCard({ variant: 'premium', spacing: 12 }) {
              Row() {
                Column({ space: 8 }) {
                  Text(this.getMembershipTitle())
                    .fontSize(TYPE_HERO_TITLE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.themeColors.premiumText)
                    .width('100%')
                  Text(this.getMembershipDescription())
                    .fontSize(TYPE_BODY)
                    .lineHeight(18)
                    .fontColor(this.themeColors.premiumText)
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')

              Row() {
                AppStatusBadge({
                  text: this.isPremiumActive() ? '已开通' : '未开通',
                  tone: this.isPremiumActive() ? 'premium' : 'warning',
                  iconName: this.isPremiumActive() ? 'success' : 'warning'
                })
                Blank()
                Text(`自动续费时间: ${this.getRenewTimeText()}`)
                  .fontSize(TYPE_META)
                  .fontColor(this.themeColors.premiumText)
              }
              .width('100%')

              Row() {
                Text('当前积分')
                  .fontSize(TYPE_META)
                  .fontColor(this.themeColors.premiumText)
                Blank()
                Text(this.getCreditBalanceText())
                  .fontSize(TYPE_BODY)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.themeColors.premiumText)
              }
              .width('100%')

              if (!this.isPremiumActive() && !AppConfig.useMockMembershipPurchase()) {
                Column({ space: 6 }) {
                  AppButton({
                    text: this.isPurchasing && this.currentProductId === 'restore_purchase' ? '同步中...' : '同步已购订阅',
                    variant: 'secondary',
                    buttonSize: 'sm',
                    iconName: 'sync',
                    loading: this.isPurchasing && this.currentProductId === 'restore_purchase',
                    tapAction: () => { void this.handleRestorePurchase(); }
                  })
                    .width('100%')

                  Text('如果华为提示已拥有商品，请先同步订阅状态。')
                    .fontSize(TYPE_META)
                    .fontColor(this.themeColors.premiumText)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                }
                .width('100%')
              }
            }

            AppCard({ spacing: 10, variant: 'raised' }) {
              Text('会员权益')
                .fontSize(TYPE_SECTION_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.themeColors.textPrimary)
                .width('100%')

              this.BenefitRow('每月赠送 500 积分', '订阅生效期间，系统会按月自动发放 500 积分到当前账户。')
              this.BenefitRow('积分持续累计', '已发放积分不会因为会员到期而清零，可继续用于后续 AI 功能消耗。')
              this.BenefitRow('发放状态可追踪', this.getMonthlyGrantHint())

              Text('积分消耗说明')
                .fontSize(TYPE_SECTION_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.themeColors.textPrimary)
                .width('100%')
                .margin({ top: 8 })

              this.CreditCostRow('AI 补全任务', '1 积分 / 次')
              this.CreditCostRow('语音创建任务', '1 积分 / 次')
              this.CreditCostRow('今日规划', '1 积分 / 次')
              this.CreditCostRow('积压任务整理', '1 积分 / 次')
              this.CreditCostRow('AI 拆解目标', '5 积分 / 次')
              this.CreditCostRow('AI 智能排程', '1 积分 / 次')

              Text('实际扣费以服务端实时规则为准，积分流水可在“我的-积分流水”中查询。')
                .fontSize(TYPE_META)
                .lineHeight(18)
                .fontColor(this.themeColors.textSecondary)
                .width('100%')
            }

            AppCard({ spacing: 10 }) {
              Text('开通选项')
                .fontSize(TYPE_SECTION_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.themeColors.textPrimary)
                .width('100%')

              if (this.products.length === 0) {
                Text('当前未查询到可购买商品，请确认设备环境支持华为应用内支付。')
                  .fontSize(TYPE_BODY)
                  .lineHeight(20)
                  .fontColor(this.themeColors.textSecondary)
                  .width('100%')
              } else {
                ForEach(this.sortProducts(this.products), (product: IAPProduct) => {
                  this.ProductCard(product)
                }, (product: IAPProduct) => product.productId)
              }
            }
          }
          .width('100%')
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: PAGE_PADDING })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
