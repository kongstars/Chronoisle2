import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import http from '@ohos.net.http';
import util from '@ohos.util';
import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import AppConfig from '../Utils/AppConfig';
import { db, toSyncDataSet } from '../storage/Database';
import { authService, type UserAccount } from '../services/AuthService';
import { cloudSyncService, type SyncDataSet } from '../services/CloudSyncService';
import { ThirdPartyAuthService, type OAuthResult } from '../services/ThirdPartyAuthService';
import { AppErrorService } from '../services/AppErrorService';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppCard } from '../ui/base/AppCard';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';

interface HuaweiLoginData {
  token: string;
  user: UserAccount;
}

interface HuaweiLoginServerResponse {
  success: boolean;
  message?: string;
  data?: HuaweiLoginData;
  token?: string;
  user?: UserAccount;
}

interface HuaweiIdTokenProfile {
  name?: string;
  picture?: string;
  displayName?: string;
  nickName?: string;
  nickname?: string;
  avatar?: string;
  headPictureURL?: string;
}

@Entry
@Component
struct LoginPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;

  @State tip: string = '';
  @State logging: boolean = false;
  @State isAgreedPrivacy: boolean = false;

  private huaweiId: string = '';

  aboutToAppear(): void {
    const context = getContext(this);
    Promise.all([
      db.initialize(context),
      authService.initialize(context),
      cloudSyncService.initialize(context)
    ]).then(() => {});
  }

  private showToast(message: string): void {
    try {
      promptAction.showToast({ message });
    } catch (_) {
    }
  }

  private parseHuaweiIdTokenProfile(idToken: string): HuaweiIdTokenProfile | null {
    if (!idToken) {
      return null;
    }

    try {
      const segments = idToken.split('.');
      if (segments.length < 2) {
        return null;
      }
      let payload = segments[1].replace(/-/g, '+').replace(/_/g, '/');
      while (payload.length % 4 !== 0) {
        payload += '=';
      }
      const base64Helper = new util.Base64Helper();
      const payloadBytes = base64Helper.decodeSync(payload);
      const textDecoder = new util.TextDecoder('utf-8');
      const payloadJson = textDecoder.decodeToString(payloadBytes);
      return JSON.parse(payloadJson) as HuaweiIdTokenProfile;
    } catch (error) {
      console.error('parseHuaweiIdTokenProfile failed:', JSON.stringify(error));
      return null;
    }
  }

  private resolveHuaweiNickname(profile: HuaweiIdTokenProfile | null, currentAccount: string): string {
    const nickname = profile?.name || profile?.displayName || profile?.nickName || profile?.nickname || '';
    return nickname || currentAccount;
  }

  private resolveHuaweiAvatar(profile: HuaweiIdTokenProfile | null, currentAvatar: string): string {
    return profile?.picture || profile?.avatar || profile?.headPictureURL || currentAvatar;
  }

  private getTipTone(): 'danger' | 'success' {
    return this.tip.includes('成功') || this.tip.includes('已切换') || this.tip.includes('已发送') ? 'success' : 'danger';
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: SECTION_GAP }) {
          Column({ space: SPACE_SM }) {
            Image($r('app.media.startIcon'))
              .width(72)
              .height(72)
              .borderRadius(20)

            AppStatusBadge({ text: '目标驱动 · 今日执行', tone: 'info', iconName: 'today' })

            Text('欢迎使用四时清单')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)

            Text('先登录，再把目标、行动和计划收回到同一个系统里。')
              .fontSize(TYPE_BODY)
              .lineHeight(18)
              .fontColor(this.themeColors.textSecondary)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .padding({ top: 36, left: PAGE_PADDING, right: PAGE_PADDING })

          Column({ space: SECTION_GAP }) {
            this.QuickLoginCard()
            this.AgreementCard()

            if (this.tip.trim().length > 0) {
              AppCard({ variant: this.getTipTone() === 'success' ? 'soft' : 'danger', spacing: SPACE_XS }) {
                Text(this.tip)
                  .fontSize(TYPE_BODY)
                  .lineHeight(18)
                  .fontColor(this.getTipTone() === 'success' ? this.themeColors.success : this.themeColors.danger)
                  .width('100%')
              }
            }

            AppCard({ variant: 'soft', spacing: SPACE_XS }) {
              Text('短信验证码链路仍在完善，手机号登录与注册已暂时下线，个人中心当前仅保留华为账号登录。')
                .fontSize(TYPE_BODY)
                .lineHeight(18)
                .fontColor(this.themeColors.textSecondary)
                .width('100%')
            }

            Row()
              .width('100%')
              .height(24)
          }
          .width('100%')
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 24 })
        }
        .width('100%')
      }
      .backgroundColor(this.themeColors.background)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }

  @Builder
  private QuickLoginCard() {
    AppCard({ variant: 'soft', spacing: SPACE_MD }) {
      Text('华为账号登录')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)

      Text('短信验证码能力还未稳定，当前登录页只开放华为账号入口。')
        .fontSize(TYPE_BODY)
        .lineHeight(22)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Button() {
        Row({ space: 10 }) {
          Image($r('app.media.huawei_login_logo_white'))
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
          Text(this.logging ? '登录中...' : '使用华为账号登录')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textOnPrimary)
        }
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height(44)
      .backgroundColor(this.themeColors.textPrimary)
      .borderRadius(22)
      .enabled(!this.logging && this.isAgreedPrivacy)
      .opacity(this.isAgreedPrivacy ? 1 : 0.65)
      .onClick(() => {
        void this.loginWithHuaweiId();
      })

      Text(this.isAgreedPrivacy ? '已同意协议，可直接使用快捷登录' : '请先同意协议后再使用快捷登录')
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textMuted)
        .width('100%')
    }
  }

  @Builder
  private AgreementCard() {
    AppCard({ variant: 'soft', spacing: SPACE_SM }) {
      Row() {
        Checkbox()
          .select(this.isAgreedPrivacy)
          .onChange((value: boolean) => {
            this.isAgreedPrivacy = value;
          })
          .margin({ right: 8 })

        Text('我已阅读并同意')
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
        Text('《用户服务协议》')
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.primary)
          .onClick(() => {
            router.pushUrl({ url: 'pages/TermsOfServicePage' });
          })
        Text('和')
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
        Text('《隐私协议》')
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.primary)
          .onClick(() => {
            router.pushUrl({ url: 'pages/PrivacyPolicyPage' });
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  private buildOfflineUser(accountType: 'phone' | 'huawei', account: string, nickname?: string, avatar?: string): UserAccount {
    const displayName = nickname && nickname.trim().length > 0 ? nickname.trim() : account;
    return {
      userId: `${accountType}_${account}_${Date.now()}`,
      accountType: accountType,
      account: displayName,
      avatar: avatar || '',
      displayId: displayName,
      createdAt: Date.now(),
      membershipType: 'basic'
    };
  }

  private async completeOfflineLogin(user: UserAccount, tipText: string): Promise<void> {
    await authService.saveThirdPartyLoginState(user, `offline-${user.accountType}-${Date.now()}`);
    this.tip = tipText;
    this.showToast('已切换到本地登录');
    await this.handleLoginSuccess(user.userId, user.account);
  }

  private async loginWithHuaweiId(): Promise<void> {
    if (!this.isAgreedPrivacy) {
      this.tip = '请先阅读并同意用户协议和隐私协议';
      return;
    }

    this.logging = true;
    this.tip = '';
    let authorizedOpenId: string = '';
    let authorizedNickname: string = '';
    let authorizedAvatar: string = '';

    try {
      const huaweiIdProvider = new authentication.HuaweiIDProvider();
      const request = huaweiIdProvider.createAuthorizationWithHuaweiIDRequest();
      request.scopes = ['profile'];
      request.permissions = ['serviceauthcode'];
      request.state = 'huawei_login_' + Date.now();

      const controller = new authentication.AuthenticationController(getContext(this));
      const response = await controller.executeRequest(request);
      const authResponse = response as authentication.AuthorizationWithHuaweiIDResponse;
      const authCode = authResponse.data?.authorizationCode || '';
      const openID = authResponse.data?.openID || '';
      const idToken = authResponse.data?.idToken || '';
      const credentialNickName = authResponse.data?.nickName || '';
      const credentialAvatarUri = authResponse.data?.avatarUri || '';

      const huaweiProfile = this.parseHuaweiIdTokenProfile(idToken);
      const nickName = credentialNickName || this.resolveHuaweiNickname(huaweiProfile, '');
      const avatarUri = credentialAvatarUri || this.resolveHuaweiAvatar(huaweiProfile, '');
      authorizedOpenId = openID;
      authorizedNickname = nickName || '华为用户';
      authorizedAvatar = avatarUri;

      if (!authCode && !openID) {
        this.tip = '华为授权失败，未获取到授权信息';
        return;
      }

      this.huaweiId = openID;

      const httpRequest = http.createHttp();
      try {
        const baseUrl = AppConfig.getBaseUrl();
        const serverResponse = await httpRequest.request(
          `${baseUrl}/api/auth/huawei-login`,
          {
            method: http.RequestMethod.POST,
            header: { 'Content-Type': 'application/json' },
            extraData: JSON.stringify({
              huaweiId: openID,
              authCode: authCode,
              idToken: idToken,
              nickName: nickName,
              avatarUri: avatarUri
            }),
            connectTimeout: 10000,
            readTimeout: 10000
          }
        );

        if (serverResponse.responseCode === 200) {
          const result = JSON.parse(serverResponse.result as string) as HuaweiLoginServerResponse;
          const loginData = result.data ?? ((result.token && result.user) ? {
            token: result.token,
            user: result.user
          } : undefined);

          if (result.success && loginData) {
            const normalizedUser: UserAccount = {
              userId: loginData.user.userId,
              accountType: loginData.user.accountType,
              account: loginData.user.account || nickName || this.resolveHuaweiNickname(huaweiProfile, ''),
              avatar: loginData.user.avatar || avatarUri || this.resolveHuaweiAvatar(huaweiProfile, ''),
              displayId: loginData.user.displayId,
              createdAt: loginData.user.createdAt,
              membershipType: loginData.user.membershipType,
              membershipPlan: loginData.user.membershipPlan,
              membershipProductId: loginData.user.membershipProductId,
              membershipExpireAt: loginData.user.membershipExpireAt,
              membershipRenewAt: loginData.user.membershipRenewAt,
              pendingMembershipPlan: loginData.user.pendingMembershipPlan,
              pendingMembershipProductId: loginData.user.pendingMembershipProductId,
              pendingMembershipEffectiveAt: loginData.user.pendingMembershipEffectiveAt
            };
            await authService.saveThirdPartyLoginState(normalizedUser, loginData.token);
            const refreshedUser = await authService.refreshUserFromServer();
            const activeUser = refreshedUser ? refreshedUser : normalizedUser;
            this.showToast('华为账号登录成功');
            await this.handleLoginSuccess(activeUser.userId, activeUser.account);
          } else if (AppConfig.allowOfflineAuthFallback()) {
            await this.completeOfflineLogin(
              this.buildOfflineUser('huawei', openID, nickName || '华为用户', avatarUri),
              '服务端暂不可用，已切换到本地华为登录'
            );
          } else {
            this.tip = AppErrorService.fromMessage(result.message || '华为登录失败', '华为登录失败');
          }
        } else if (AppConfig.allowOfflineAuthFallback()) {
          await this.completeOfflineLogin(
            this.buildOfflineUser('huawei', openID, nickName || '华为用户', avatarUri),
            `服务端响应异常(${serverResponse.responseCode})，已切换到本地华为登录`
          );
        } else {
          this.tip = AppErrorService.fromResponse(serverResponse.responseCode, String(serverResponse.result), '华为登录失败');
        }
      } finally {
        httpRequest.destroy();
      }
    } catch (error) {
      const bizError = error as BusinessError;
      const errorCode = bizError.code || 0;
      const errorMsg = bizError.message || '未知错误';
      console.error(`HuaweiLogin failed: code=${errorCode}, msg=${errorMsg}, detail=${JSON.stringify(bizError)}`);

      if (errorCode === 1001500001) {
        this.tip = '';
      } else if (errorCode === 1001502003) {
        this.tip = '华为登录配置错误，请检查 AGC 后台配置和签名信息';
      } else if (errorCode === 1001502014) {
        this.tip = '华为登录权限不足，请检查授权 scope 配置';
      } else if (AppConfig.allowOfflineAuthFallback() && authorizedOpenId.length > 0 &&
        (errorCode === 2300007 || errorMsg.includes('Failed to connect to the server'))) {
        await this.completeOfflineLogin(
          this.buildOfflineUser('huawei', authorizedOpenId, authorizedNickname, authorizedAvatar),
          '服务端连接失败，已切换到本地华为登录'
        );
      } else {
        this.tip = errorCode > 0 ? `${errorCode}: 华为登录失败` : AppErrorService.fromMessage(errorMsg, '华为登录失败');
      }
    } finally {
      this.logging = false;
    }
  }

  private async loginWithWeChat(): Promise<void> {
    if (!this.isAgreedPrivacy) {
      this.showToast('请先同意用户协议和隐私协议');
      return;
    }

    this.logging = true;
    const result = await ThirdPartyAuthService.startOAuthLogin('wechat');

    if (result.success && result.token) {
      await this.saveThirdPartyLoginState(result, 'wechat');
      const refreshedUser = await authService.refreshUserFromServer();
      this.showToast('微信登录成功');
      await this.handleLoginSuccess(
        refreshedUser?.userId || result.userId || '',
        refreshedUser?.account || result.nickname || 'wechat_user'
      );
    } else {
      this.showToast(AppErrorService.fromMessage(result.message || '微信登录失败', '微信登录失败'));
    }

    this.logging = false;
  }

  private async loginWithQQ(): Promise<void> {
    if (!this.isAgreedPrivacy) {
      this.showToast('请先同意用户协议和隐私协议');
      return;
    }

    this.logging = true;
    const result = await ThirdPartyAuthService.startOAuthLogin('qq');

    if (result.success && result.token) {
      await this.saveThirdPartyLoginState(result, 'qq');
      const refreshedUser = await authService.refreshUserFromServer();
      this.showToast('QQ 登录成功');
      await this.handleLoginSuccess(
        refreshedUser?.userId || result.userId || '',
        refreshedUser?.account || result.nickname || 'qq_user'
      );
    } else {
      this.showToast(AppErrorService.fromMessage(result.message || 'QQ 登录失败', 'QQ 登录失败'));
    }

    this.logging = false;
  }

  private async saveThirdPartyLoginState(result: OAuthResult, platform: 'wechat' | 'qq' | 'huawei'): Promise<void> {
    const platformNames: Record<string, string> = { 'wechat': '微信', 'qq': 'QQ', 'huawei': '华为' };
    const user: UserAccount = {
      userId: result.userId || '',
      accountType: platform,
      account: result.nickname || `${platformNames[platform] || platform}用户`,
      avatar: result.avatar || '',
      createdAt: Date.now()
    };

    await authService.saveThirdPartyLoginState(user, result.token || '');
  }

  private async handleLoginSuccess(userId: string, account: string): Promise<void> {
    try {
      const refreshedUser = await authService.refreshUserFromServer();
      const activeUserId = refreshedUser?.userId || userId;
      const activeAccount = refreshedUser?.account || account;
      const localData: SyncDataSet = toSyncDataSet(db.exportData());
      const hasHistory = await cloudSyncService.hasCloudHistory();

      if (hasHistory) {
        const cloudData: SyncDataSet = await cloudSyncService.fetchCloudData();
        const mergedData: SyncDataSet = cloudSyncService.mergeData(localData, cloudData);
        await db.replaceAllData(mergedData.goals, mergedData.tasks);
        await cloudSyncService.uploadData(mergedData);
      } else {
        await cloudSyncService.uploadData(localData);
      }

      console.info(`LoginPage automatic sync completed for account: ${activeAccount}`);
      setTimeout(() => {
        router.replaceUrl({
          url: 'pages/MainPage',
          params: { userId: activeUserId }
        });
      }, 500);
    } catch (error) {
      console.error('handleLoginSuccess failed:', JSON.stringify(error));
      setTimeout(() => {
        router.replaceUrl({
          url: 'pages/MainPage',
          params: { userId: userId }
        });
      }, 500);
    }
  }
}
