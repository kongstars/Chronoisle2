import common from '@ohos.app.ability.common';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { ThirdPartyAuthService, OAuthResult } from '../services/ThirdPartyAuthService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('ThirdPartyLoginPage');

type OAuthPlatform = 'wechat' | 'qq' | 'huawei';

interface ThirdPartyLoginParams {
  authUrl?: string;
  platform?: OAuthPlatform;
  onSuccess?: (result: OAuthResult) => void;
  onError?: (message: string) => void;
}

@Entry
@Component
struct ThirdPartyLoginPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State authUrl: string = '';
  @State platform: OAuthPlatform = 'wechat';
  @State statusText: string = '准备启动授权';
  @State detailText: string = '将使用系统浏览器打开授权页面，完成后自动返回应用。';
  @State isLaunching: boolean = false;
  @State hasLaunched: boolean = false;
  @State isCompleted: boolean = false;

  private onSuccessCallback?: (result: OAuthResult) => void;
  private onErrorCallback?: (message: string) => void;

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as ThirdPartyLoginParams;
    this.authUrl = params?.authUrl || '';
    this.platform = params?.platform || 'wechat';
    this.onSuccessCallback = params?.onSuccess;
    this.onErrorCallback = params?.onError;
    this.statusText = this.authUrl ? `准备打开${this.getPlatformName()}授权页` : '缺少授权参数';
    this.detailText = this.authUrl
      ? '授权完成后会通过应用回调地址返回，并在当前页面自动完成校验。'
      : '请从登录页重新发起第三方登录。';

    if (this.authUrl && !this.hasLaunched) {
      void this.launchOAuth();
    }
  }

  aboutToDisappear(): void {
    if (!this.isCompleted && this.onErrorCallback) {
      this.onErrorCallback('cancelled');
      this.onErrorCallback = undefined;
    }
  }

  onPageShow(): void {
    void this.consumeOAuthCallback();
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch (_) {
    }
  }

  private getPlatformName(): string {
    if (this.platform === 'qq') {
      return 'QQ';
    }
    if (this.platform === 'huawei') {
      return '华为';
    }
    return '微信';
  }

  private getStatusTone(): 'info' | 'success' | 'danger' {
    if (this.isCompleted) {
      return 'success';
    }
    if (!this.authUrl) {
      return 'danger';
    }
    return 'info';
  }

  private getProviderDescription(platform: OAuthPlatform): string {
    switch (platform) {
      case 'qq':
        return '通过服务端 OAuth 路由拉起 QQ 授权，并回调到应用完成校验。';
      case 'huawei':
        return '承接华为账号相关授权结果，并与统一登录态保持一致。';
      default:
        return '通过服务端 OAuth 路由拉起微信授权，并回调到应用完成校验。';
    }
  }

  private isCurrentPlatform(platform: OAuthPlatform): boolean {
    return this.platform === platform;
  }

  private getProviderTitle(platform: OAuthPlatform): string {
    if (platform === 'wechat') {
      return '微信登录';
    }
    if (platform === 'qq') {
      return 'QQ 登录';
    }
    return '华为账号';
  }

  private async launchOAuth(): Promise<void> {
    if (!this.authUrl || this.isLaunching || this.isCompleted) {
      return;
    }
    this.isLaunching = true;
    this.hasLaunched = true;
    this.statusText = `正在打开${this.getPlatformName()}授权页`;
    this.detailText = '如果没有自动跳转，可以稍后点击“重新打开授权页”。';

    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await context.openLink(this.authUrl);
    } catch (error) {
      logger.error('ThirdPartyLoginPage launchOAuth error', error as Object);
      this.statusText = '打开授权页失败';
      this.detailText = '当前无法拉起系统浏览器，请稍后重试。';
      this.handleOAuthError('打开授权页失败，请稍后重试');
    } finally {
      this.isLaunching = false;
    }
  }

  private async consumeOAuthCallback(): Promise<void> {
    if (this.isCompleted) {
      return;
    }
    const callbackUrl = AppStorage.get<string>('oauthCallbackUrl');
    if (!callbackUrl) {
      return;
    }
    AppStorage.delete('oauthCallbackUrl');

    this.statusText = '正在处理授权结果';
    this.detailText = callbackUrl;

    const parsed = ThirdPartyAuthService.handleUrlCallback(callbackUrl);
    if (!parsed) {
      this.handleOAuthError('未能识别授权回调结果');
      return;
    }

    if (!parsed.success || !parsed.token) {
      this.handleOAuthError(parsed.message || `${this.getPlatformName()}登录失败`);
      return;
    }

    try {
      const verified = await ThirdPartyAuthService.verifyToken(parsed.token);
      const finalResult = verified.success ? verified : parsed;
      this.handleOAuthSuccess(finalResult);
    } catch (error) {
      logger.error('ThirdPartyLoginPage verifyToken error', error as Object);
      this.handleOAuthSuccess(parsed);
    }
  }

  private handleOAuthSuccess(result: OAuthResult): void {
    this.isCompleted = true;
    this.statusText = `${this.getPlatformName()}授权成功`;
    this.detailText = result.nickname || result.userId || '已完成第三方登录校验';
    if (this.onSuccessCallback) {
      this.onSuccessCallback(result);
    }
    this.showToast(`${this.getPlatformName()}授权成功`);
    this.getUIContext().getRouter().back();
  }

  private handleOAuthError(message: string): void {
    this.statusText = `${this.getPlatformName()}授权失败`;
    this.detailText = message;
    if (this.onErrorCallback) {
      this.onErrorCallback(message);
    }
  }

  @Builder
  private HeroCard() {
    AppCard({ variant: 'accent', spacing: SPACE_SM }) {
      Row({ space: SPACE_XS }) {
        AppStatusBadge({ text: this.getPlatformName(), tone: 'primary', iconName: 'profile' })
        AppStatusBadge({
          text: this.hasLaunched ? '已发起授权' : '等待发起',
          tone: this.hasLaunched ? 'success' : 'info',
          iconName: this.hasLaunched ? 'success' : 'info'
        })
      }
      .width('100%')

      Text('第三方登录授权')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Text('授权链路会跳转到系统浏览器，完成后自动回到应用并继续登录。')
        .fontSize(TYPE_BODY)
        .lineHeight(22)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  @Builder
  private StatusCard() {
    AppCard({ variant: this.isCompleted ? 'soft' : 'base', spacing: SPACE_SM }) {
      AppStatusBadge({
        text: this.statusText,
        tone: this.getStatusTone(),
        iconName: this.getStatusTone() === 'danger' ? 'warning' : (this.isCompleted ? 'success' : 'info')
      })
      Text(this.detailText)
        .fontSize(TYPE_BODY)
        .lineHeight(22)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
      Row() {
        Text(`当前平台：${this.getPlatformName()}`)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textMuted)
        Blank()
        Text(this.authUrl ? '回调链路已配置' : '缺少授权地址')
          .fontSize(TYPE_META)
          .fontColor(this.authUrl ? this.themeColors.success : this.themeColors.danger)
      }
      .width('100%')
    }
  }

  @Builder
  private ProviderCard(platform: OAuthPlatform) {
    AppCard({ variant: this.isCurrentPlatform(platform) ? 'accent' : 'base', spacing: SPACE_SM }) {
      Row() {
        Text(this.getProviderTitle(platform))
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
        Blank()
        AppStatusBadge({
          text: this.isCurrentPlatform(platform) ? '当前通道' : '已支持',
          tone: this.isCurrentPlatform(platform) ? 'primary' : 'neutral',
          iconName: this.isCurrentPlatform(platform) ? 'profile' : 'success'
        })
      }
      .width('100%')

      Text(this.getProviderDescription(platform))
        .fontSize(TYPE_META)
        .lineHeight(20)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  @Builder
  private ActionCard() {
    AppCard({ variant: 'soft', spacing: SPACE_SM }) {
      Text('操作')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Row({ space: SPACE_SM }) {
        AppButton({
          text: this.isLaunching ? '打开中...' : '重新打开授权页',
          variant: 'primary',
          iconName: 'profile',
          disabled: !this.authUrl || this.isLaunching,
          tapAction: () => {
            void this.launchOAuth();
          }
        })
        .layoutWeight(1)

        AppButton({
          text: '返回登录页',
          variant: 'secondary',
          iconName: 'chevron-left',
          tapAction: () => {
            this.getUIContext().getRouter().replaceUrl({ url: 'pages/LoginPage' });
          }
        })
        .layoutWeight(1)
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      AppPageHeader({
        title: '第三方登录',
        subtitle: '通过服务端 OAuth 路由完成授权并回到应用。',
        onBack: () => {
          this.getUIContext().getRouter().back();
        }
      })

      Scroll() {
        Column({ space: SECTION_GAP }) {
          this.HeroCard()
          this.StatusCard()
          this.ProviderCard('wechat')
          this.ProviderCard('qq')
          this.ProviderCard('huawei')
          this.ActionCard()
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 8, bottom: PAGE_PADDING })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .backgroundColor(this.themeColors.background)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
