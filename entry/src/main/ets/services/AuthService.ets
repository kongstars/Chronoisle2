import dataPreferences from '@ohos.data.preferences';
import { UIContext } from '@ohos.arkui.UIContext';
import AppConfig from '../Utils/AppConfig';
import { TelemetryService, type TelemetryProperties } from './TelemetryService';
import { TelemetryErrorCode } from '../models/TelemetryErrorCode';
import { HttpClient } from './HttpClient';
import { trackApiError } from './TelemetryHelper';
import { Logger } from '../Utils/Logger';
import { LightTheme } from '../theme/AppTheme';

const logger = Logger.create('AuthService');

export type AccountType = 'phone' | 'email' | 'huawei' | 'wechat' | 'qq';

export interface UserAccount {
  userId: string;
  accountType: AccountType;
  account: string;
  createdAt: number;
  nickname?: string;
  avatar?: string; // 用户头像
  displayId?: string; // 四时清单生成的展示ID
  membershipType?: 'basic' | 'premium';
  membershipPlan?: string;
  membershipProductId?: string;
  membershipExpireAt?: number;
  membershipRenewAt?: number;
  pendingMembershipPlan?: string;
  pendingMembershipProductId?: string;
  pendingMembershipEffectiveAt?: number;
  creditBalance?: number;
  totalEarned?: number;
  totalSpent?: number;
  creditFrozen?: boolean;
  isMemberActive?: boolean;
  lastGrantMonth?: string;
}
export interface CodeResult {
  success: boolean;
  message: string;
}
export interface ApiResponse<T> {
  success: boolean;
  message: string;
  data?: T;
}
export interface ProfileUpdatePayload {
  nickname?: string;
  avatar?: string;
}
interface DebugCodeResponse {
  // Previously contained debugCode
}
export interface RegisterResult {
  success: boolean;
  message: string;
  user: UserAccount | null;
}
export interface LoginResponse {
  user: UserAccount;
  token: string;
}

interface ErrorMessageResponse {
  message?: string;
}

interface CreditBalanceData {
  balance: number;
  totalEarned: number;
  totalSpent: number;
  isFrozen: boolean;
  isMemberActive: boolean;
  lastGrantMonth?: string;
}

interface RegisterLoginEnvelope {
  token?: string;
  user?: UserAccount;
  data?: RegisterLoginPayload;
}

interface RegisterLoginPayload {
  token?: string;
  user?: UserAccount;
}

interface MembershipPurchasePayload {
  membershipType: 'basic' | 'premium';
  membershipPlan?: string;
  membershipProductId?: string;
  membershipExpireAt: number;
  membershipRenewAt?: number;
  pendingMembershipPlan?: string;
  pendingMembershipProductId?: string;
  pendingMembershipEffectiveAt?: number;
}

interface MembershipUpdatePatch {
  membershipPlan?: string;
  membershipProductId?: string;
  membershipRenewAt?: number;
  pendingMembershipPlan?: string;
  pendingMembershipProductId?: string;
  pendingMembershipEffectiveAt?: number;
}

interface SendCodeRequestPayload {
  accountType: AccountType;
  account: string;
}

interface RegisterRequestPayload {
  accountType: AccountType;
  account: string;
  code: string;
  avatar: string;
}

interface LoginRequestPayload {
  accountType: AccountType;
  account: string;
  code: string;
}

interface HuaweiLoginRequestPayload {
  huaweiId: string;
}

interface MembershipPurchaseRequestPayload {
  plan: string;
}

interface SessionEventTelemetryProps {
  accountType?: string;
  method?: string;
  reason?: string;
  offlineMode?: boolean;
}

export const AVATAR_LIST: string[] = [
  'https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=cute%20cat%20cartoon%20avatar%20flat%20design&image_size=square',
  'https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=cool%20dog%20cartoon%20avatar%20flat%20design&image_size=square',
  'https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=happy%20bear%20cartoon%20avatar%20flat%20design&image_size=square',
  'https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=smart%20owl%20cartoon%20avatar%20flat%20design&image_size=square',
  'https://coresg-normal.trae.ai/api/ide/v1/text_to_image?prompt=brave%20lion%20cartoon%20avatar%20flat%20design&image_size=square'
];

const PREFERENCES_NAME = 'life_goal_auth_storage';
const CURRENT_USER_KEY = 'current_user';
const JWT_TOKEN_KEY = 'jwt_token';

class AuthService {
  private prefs: dataPreferences.Preferences | null = null;
  private tokenCache: string | null = null;

  private trackSessionEvent(eventName: string, properties?: SessionEventTelemetryProps): void {
    TelemetryService.trackImmediate(eventName, properties as TelemetryProperties, 'session');
  }

  async initialize(context: Context): Promise<void> {
    if (!this.prefs) {
      try {
        this.prefs = await dataPreferences.getPreferences(context, PREFERENCES_NAME);
        const tokenVal = await this.prefs.get(JWT_TOKEN_KEY, '');
        this.tokenCache = tokenVal as string;
        if (this.tokenCache && this.tokenCache.startsWith('offline-') && !AppConfig.allowOfflineAuthFallback()) {
          await this.logout();
        }
      } catch (error) {
        logger.error('AuthService initialize error', error as Object);
      }
    }
  }

  async getCurrentUser(): Promise<UserAccount | null> {
    if (!this.prefs) {
      return null;
    }
    try {
      const value = await this.prefs.get(CURRENT_USER_KEY, '');
      const json = value as string;
      if (!json) {
        return null;
      }
      return JSON.parse(json) as UserAccount;
    } catch (error) {
      logger.error('AuthService getCurrentUser error', error as Object);
      return null;
    }
  }
  
  async getToken(): Promise<string | null> {
    return this.tokenCache;
  }

  getTokenSync(): string | null {
    return this.tokenCache;
  }

  async sendVerificationCode(accountType: AccountType, account: string): Promise<CodeResult> {
    const trimmed = account.trim();
    if (!this.isValidAccount(accountType, trimmed)) {
      return {
        success: false,
        message: accountType === 'phone' ? '手机号格式不正确' : '邮箱格式不正确'
      };
    }

    try {
      const payload: SendCodeRequestPayload = {
        accountType: accountType,
        account: trimmed
      };
      const result = await HttpClient.post<CodeResult>(
        '/api/auth/send-code',
        payload,
        { needAuth: false, connectTimeout: 10000, readTimeout: 10000 }
      );
      return {
        success: result.success,
        message: result.message || '请求失败'
      };
    } catch (error) {
      logger.error('发送验证码失败:', error as Object);
      trackApiError(TelemetryErrorCode.ERR_NET_TIMEOUT, error, 'auth/send-code');
      return { success: false, message: '网络请求失败，请检查连接' };
    }
  }

  async register(accountType: AccountType, account: string, code: string): Promise<RegisterResult> {
    const trimmed = account.trim();
    const randomAvatar = AVATAR_LIST[Math.floor(Math.random() * AVATAR_LIST.length)];

    try {
      const payload: RegisterRequestPayload = {
        accountType: accountType,
        account: trimmed,
        code: code,
        avatar: randomAvatar
      };
      const result = await HttpClient.post<RegisterLoginEnvelope>(
        '/api/auth/register',
        payload,
        { needAuth: false, connectTimeout: 10000, readTimeout: 10000 }
      );

      if (result.success && result.data) {
        const raw: RegisterLoginEnvelope = result.data;
        // 兼容两种格式：扁平 { token, user } 或嵌套 { data: { token, user } }
        let token: string = '';
        let user: UserAccount | null = null;
        const dataObj: RegisterLoginPayload | undefined = raw.data;
        if (dataObj && dataObj.token) {
          token = dataObj.token;
          user = dataObj.user || null;
        } else {
          token = raw.token || '';
          user = raw.user || null;
        }
        if (token && user) {
          await this.saveLoginState(user, token);
          const successProps: SessionEventTelemetryProps = {
            accountType: accountType,
            method: 'verification_code'
          };
          this.trackSessionEvent('session_register_success', successProps);
          return { success: true, message: '注册成功', user: user };
        }
        const invalidResponseProps: SessionEventTelemetryProps = {
          accountType: accountType,
          reason: 'invalid_response'
        };
        this.trackSessionEvent('session_register_failed', invalidResponseProps);
        return { success: false, message: '注册响应数据异常', user: null };
      }
      const registerFailedProps: SessionEventTelemetryProps = {
        accountType: accountType,
        reason: result.message || 'register_failed'
      };
      this.trackSessionEvent('session_register_failed', registerFailedProps);
      return { success: false, message: result.message || '账号已存在或验证码错误', user: null };
    } catch (error) {
      logger.error('注册网络请求失败:', error as Object);
      trackApiError(TelemetryErrorCode.ERR_NET_TIMEOUT, error, 'auth/register');
      const networkErrorProps: SessionEventTelemetryProps = {
        accountType: accountType,
        reason: 'network_error'
      };
      this.trackSessionEvent('session_register_failed', networkErrorProps);
      return { success: false, message: '网络请求失败', user: null };
    }
  }

  async login(accountType: AccountType, account: string, code: string): Promise<RegisterResult> {
    const trimmed = account.trim();
    try {
      const payload: LoginRequestPayload = {
        accountType: accountType,
        account: trimmed,
        code: code
      };
      const result = await HttpClient.post<LoginResponse>(
        '/api/auth/login',
        payload,
        { needAuth: false, connectTimeout: 10000, readTimeout: 10000 }
      );

      if (result.success && result.data) {
        await this.saveLoginState(result.data.user, result.data.token);
        const successProps: SessionEventTelemetryProps = {
          accountType: accountType,
          method: 'verification_code'
        };
        this.trackSessionEvent('session_login_success', successProps);
        return { success: true, message: '登录成功', user: result.data.user };
      }
      const loginFailedProps: SessionEventTelemetryProps = {
        accountType: accountType,
        method: 'verification_code',
        reason: result.message || 'login_failed'
      };
      this.trackSessionEvent('session_login_failed', loginFailedProps);
      return { success: false, message: result.message || '验证码错误或未注册', user: null };
    } catch (error) {
      logger.error('登录网络请求失败:', error as Object);
      trackApiError(TelemetryErrorCode.ERR_NET_TIMEOUT, error, 'auth/login');
      const loginNetworkErrorProps: SessionEventTelemetryProps = {
        accountType: accountType,
        method: 'verification_code',
        reason: 'network_error'
      };
      this.trackSessionEvent('session_login_failed', loginNetworkErrorProps);
      return { success: false, message: '网络请求失败', user: null };
    }
  }

  async loginOrRegister(accountType: AccountType, account: string, code: string): Promise<RegisterResult> {
    // 简化逻辑：尝试登录，如果是404则注册
    let loginRes = await this.login(accountType, account, code);
    if (!loginRes.success && loginRes.message === '账号尚未注册') {
      return await this.register(accountType, account, code);
    }
    return loginRes;
  }
  private async saveLoginState(user: UserAccount, token: string) {
    if (!this.prefs) return;
    this.tokenCache = token;
    try {
      await this.prefs.put(CURRENT_USER_KEY, JSON.stringify(user));
      await this.prefs.put(JWT_TOKEN_KEY, token);
      await this.prefs.flush();
      // 同步最新 token 给埋点 SDK
      TelemetryService.setToken(token);
    } catch (error) {
      logger.error('AuthService saveLoginState error', error as Object);
    }
  }

  async saveThirdPartyLoginState(user: UserAccount, token: string): Promise<void> {
    await this.saveLoginState(user, token);
    const loginProps: SessionEventTelemetryProps = {
      accountType: user.accountType,
      method: 'oauth',
      offlineMode: token.startsWith('offline-')
    };
    this.trackSessionEvent('session_login_success', loginProps);
  }

  async updateAvatar(avatar: string): Promise<UserAccount | null> {
    const payload: ProfileUpdatePayload = { avatar: avatar };
    return await this.updateProfile(payload);
    /*
    if (!this.prefs) return null;
    const user = await this.getCurrentUser();
    if (user) {
      user.avatar = avatar;
      try {
        await this.prefs.put(CURRENT_USER_KEY, JSON.stringify(user));
        await this.prefs.flush();
      } catch (_) {}
      // 这里可拓展: 请求远端API更新云端用户的头像信息
      return user;
    }
    return null;
    */
  }

  async updateNickname(nickname: string): Promise<UserAccount | null> {
    const payload: ProfileUpdatePayload = { nickname: nickname };
    return await this.updateProfile(payload);
    /*
    if (!this.prefs) return null;
    const user = await this.getCurrentUser();
    if (user) {
      user.account = nickname;
      await this.prefs.put(CURRENT_USER_KEY, JSON.stringify(user));
      await this.prefs.flush();
      return user;
    }
    return null;
    */
  }

  private async updateProfile(profile: ProfileUpdatePayload): Promise<UserAccount | null> {
    const token = await this.getToken();
    if (!token || !this.prefs || token.startsWith('offline-')) return null;

    try {
      const result = await HttpClient.post<UserAccount>(
        '/api/auth/profile',
        profile,
        { connectTimeout: 8000, readTimeout: 8000 }
      );

      if (result.success && result.data) {
        const updatedUser: UserAccount = {
          userId: result.data.userId,
          accountType: result.data.accountType,
          account: result.data.account,
          createdAt: result.data.createdAt,
          nickname: result.data.nickname,
          avatar: result.data.avatar,
          displayId: result.data.displayId,
          membershipType: result.data.membershipType,
          membershipPlan: result.data.membershipPlan,
          membershipProductId: result.data.membershipProductId,
          membershipExpireAt: result.data.membershipExpireAt,
          membershipRenewAt: result.data.membershipRenewAt,
          pendingMembershipPlan: result.data.pendingMembershipPlan,
          pendingMembershipProductId: result.data.pendingMembershipProductId,
          pendingMembershipEffectiveAt: result.data.pendingMembershipEffectiveAt
        };
        await this.prefs.put(CURRENT_USER_KEY, JSON.stringify(updatedUser));
        await this.prefs.flush();
        const refreshedUser = await this.refreshUserFromServer();
        return refreshedUser ? refreshedUser : updatedUser;
      }
      return null;
    } catch (error) {
      logger.error('updateProfile failed', error as Object);
      return null;
    }
  }

  /**
   * 更新本地缓存的会员状态
   * 在购买会员成功后调用，确保即时更新
   */
  async updateMembership(
    membershipType: 'basic' | 'premium',
    membershipExpireAt: number,
    patch?: MembershipUpdatePatch
  ): Promise<UserAccount | null> {
    if (!this.prefs) return null;
    const user = await this.getCurrentUser();
    if (user) {
      user.membershipType = membershipType;
      user.membershipExpireAt = membershipExpireAt;
      if (patch) {
        user.membershipPlan = patch.membershipPlan;
        user.membershipProductId = patch.membershipProductId;
        user.membershipRenewAt = patch.membershipRenewAt;
        user.pendingMembershipPlan = patch.pendingMembershipPlan;
        user.pendingMembershipProductId = patch.pendingMembershipProductId;
        user.pendingMembershipEffectiveAt = patch.pendingMembershipEffectiveAt;
      }
      try {
        await this.prefs.put(CURRENT_USER_KEY, JSON.stringify(user));
        await this.prefs.flush();
      } catch (_) {}
      return user;
    }
    return null;
  }

  /**
   * 从服务器拉取最新的用户信息并更新本地缓存
   * 用于确保管理后台修改会员状态后能即时反映
   *
   * 主要功能：
   * 1. 验证token有效性，处理离线模式
   * 2. 从服务器获取完整的用户信息（/api/auth/me）
   * 3. 处理认证失败情况（token失效时自动登出）
   * 4. 额外获取积分余额信息（/api/credit/balance）
   * 5. 合并用户基本信息和积分信息
   * 6. 更新本地Preferences缓存
   *
   * 使用场景：
   * - App启动时自动刷新
   * - 购买会员成功后刷新状态
   * - 后台管理修改用户状态后同步
   *
   * @returns 更新后的用户信息，失败时返回null
   */
  async refreshUserFromServer(): Promise<UserAccount | null> {
    const token = await this.getToken();
    if (!token || !this.prefs) return null;

    // 处理离线模式token：如果配置不允许离线兜底，则强制登出
    if (token.startsWith('offline-')) {
      if (!AppConfig.allowOfflineAuthFallback()) {
        await this.logout();
      }
      return null;
    }

    try {
      // 获取用户信息
      const userResult = await HttpClient.get<UserAccount>(
        '/api/auth/me',
        { connectTimeout: 8000, readTimeout: 8000 }
      );

      if (!userResult.success || !userResult.data) {
        // 如果是认证失败，清理登录状态
        if (userResult.message?.includes('认证失败')) {
          logger.warn('User deleted or token invalid, forcing logout');
          trackApiError(TelemetryErrorCode.ERR_AUTH_TOKEN_EXPIRED, 'auth/me failed', 'auth/me');
          await this.logout();
        }
        return null;
      }

      const serverUser: UserAccount = {
        userId: userResult.data.userId,
        accountType: userResult.data.accountType,
        account: userResult.data.account,
        createdAt: userResult.data.createdAt,
        nickname: userResult.data.nickname,
        avatar: userResult.data.avatar,
        displayId: userResult.data.displayId,
        membershipType: userResult.data.membershipType,
        membershipPlan: userResult.data.membershipPlan,
        membershipProductId: userResult.data.membershipProductId,
        membershipExpireAt: userResult.data.membershipExpireAt,
        membershipRenewAt: userResult.data.membershipRenewAt,
        pendingMembershipPlan: userResult.data.pendingMembershipPlan,
        pendingMembershipProductId: userResult.data.pendingMembershipProductId,
        pendingMembershipEffectiveAt: userResult.data.pendingMembershipEffectiveAt,
        creditBalance: userResult.data.creditBalance,
        totalEarned: userResult.data.totalEarned,
        totalSpent: userResult.data.totalSpent,
        creditFrozen: userResult.data.creditFrozen,
        isMemberActive: userResult.data.isMemberActive,
        lastGrantMonth: userResult.data.lastGrantMonth
      };

      // 获取积分余额
      try {
        const creditResult = await HttpClient.get<CreditBalanceData>(
          '/api/credit/balance',
          { connectTimeout: 8000, readTimeout: 8000 }
        );

        if (creditResult.success && creditResult.data) {
          serverUser.creditBalance = creditResult.data.balance;
          serverUser.totalEarned = creditResult.data.totalEarned;
          serverUser.totalSpent = creditResult.data.totalSpent;
          serverUser.creditFrozen = creditResult.data.isFrozen;
          serverUser.isMemberActive = creditResult.data.isMemberActive;
          serverUser.lastGrantMonth = creditResult.data.lastGrantMonth;
        }
      } catch (creditError) {
        logger.warn('refresh credit balance failed', creditError as Object);
      }

      // 用服务器数据更新本地缓存
      await this.prefs.put(CURRENT_USER_KEY, JSON.stringify(serverUser));
      await this.prefs.flush();
      return serverUser;
    } catch (error) {
      logger.warn('refreshUserFromServer failed', error as Object);
      trackApiError(TelemetryErrorCode.ERR_NET_TIMEOUT, error, 'auth/me');
      return null;
    }
  }

  /**
   * 检查用户是否为有效的高级会员
   *
   * 判断条件：
   * 1. 用户对象必须存在 (user !== null)
   * 2. 会员类型必须是 'premium'
   * 3. 会员必须未过期：
   *    - 如果没有设置过期时间 (membershipExpireAt 不存在)
   *    - 或者过期时间在未来 (membershipExpireAt > 当前时间)
   *
   * @param user 用户账户信息，可能为null
   * @returns 如果满足所有条件返回true，否则返回false
   */
  isPremiumUser(user: UserAccount | null): boolean {
    return !!(
      user &&
      user.membershipType === 'premium' &&
      (!user.membershipExpireAt || user.membershipExpireAt > Date.now())
    );
  }

  /**
   * 检查登录状态。如未登录会用 UIContext 弹「请先登录」对话框，并在用户点击「去登录」时跳转登录页。
   *
   * @param uiContext 必传：从调用方 `this.getUIContext()` 传入。在 ArkTS NEXT 中，service
   *                  层不能直接访问全局 router/promptAction（已 deprecated），必须由 UI 层提供 context。
   */
  async checkLoginWithPrompt(uiContext: UIContext): Promise<boolean> {
    const user = await this.getCurrentUser();
    if (user) {
      return true;
    }

    try {
      const dialogResult = await uiContext.getPromptAction().showDialog({
        title: '请先登录',
        message: 'AI 专属功能需要登录后才能使用，以便为您提供更精准的个性化服务并记录使用数据。',
        buttons: [
          { text: '稍后再说', color: LightTheme.textMuted },
          { text: '去登录', color: LightTheme.primary }
        ]
      });
      if (dialogResult.index === 1) {
        uiContext.getRouter().pushUrl({ url: 'pages/LoginPage' });
      }
    } catch (error) {
      logger.warn('checkLoginWithPrompt show dialog failed', error as Object);
    }
    return false;
  }

  async logout(): Promise<void> {
    if (!this.prefs) {
      return;
    }
    const hadToken = !!this.tokenCache;
    const offlineMode = !!this.tokenCache && this.tokenCache.startsWith('offline-');
    if (hadToken) {
      const logoutProps: SessionEventTelemetryProps = {
        offlineMode: offlineMode
      };
      this.trackSessionEvent('session_logout', logoutProps);
    }
    this.tokenCache = null;
    // 登出时清空埋点 SDK 的 token
    TelemetryService.setToken('');
    try {
      await this.prefs.delete(CURRENT_USER_KEY);
      await this.prefs.delete(JWT_TOKEN_KEY);
      await this.prefs.flush();
    } catch (error) {
      logger.error('AuthService logout error', error as Object);
    }
  }

  async loginWithHuaweiId(huaweiId: string): Promise<RegisterResult> {
    try {
      const payload: HuaweiLoginRequestPayload = {
        huaweiId: huaweiId
      };
      const result = await HttpClient.post<LoginResponse>(
        '/api/auth/huawei-login',
        payload,
        { needAuth: false, connectTimeout: 10000, readTimeout: 10000 }
      );

      if (result.success && result.data) {
        await this.saveLoginState(result.data.user, result.data.token);
        const huaweiLoginSuccessProps: SessionEventTelemetryProps = {
          accountType: 'huawei',
          method: 'native_huawei'
        };
        this.trackSessionEvent('session_login_success', huaweiLoginSuccessProps);
        return { success: true, message: '华为账号登录成功', user: result.data.user };
      }
      const huaweiLoginFailedProps: SessionEventTelemetryProps = {
        accountType: 'huawei',
        method: 'native_huawei',
        reason: result.message || 'huawei_login_failed'
      };
      this.trackSessionEvent('session_login_failed', huaweiLoginFailedProps);
      return { success: false, message: result.message || '华为账号登录失败', user: null };
    } catch (error) {
      logger.error('华为账号登录网络请求失败:', error as Object);
      trackApiError(TelemetryErrorCode.ERR_AUTH_HW_OAUTH_FAIL, error, 'auth/huawei-login');
      const huaweiLoginNetworkErrorProps: SessionEventTelemetryProps = {
        accountType: 'huawei',
        method: 'native_huawei',
        reason: 'network_error'
      };
      this.trackSessionEvent('session_login_failed', huaweiLoginNetworkErrorProps);
      return { success: false, message: '网络请求失败', user: null };
    }
  }

  async purchaseMembership(plan: string): Promise<UserAccount | null> {
    const token = await this.getToken();
    if (!token || !this.prefs) return null;

    try {
      const payload: MembershipPurchaseRequestPayload = {
        plan: plan
      };
      const result = await HttpClient.post<MembershipPurchasePayload>(
        '/api/subscription/buy',
        payload,
        { connectTimeout: 10000, readTimeout: 10000 }
      );

      if (result.success && result.data) {
        const data: MembershipPurchasePayload = result.data;
        const user = await this.getCurrentUser();
        if (user) {
          user.membershipType = data.membershipType;
          user.membershipPlan = data.membershipPlan;
          user.membershipProductId = data.membershipProductId;
          user.membershipExpireAt = data.membershipExpireAt;
          user.membershipRenewAt = data.membershipRenewAt;
          user.pendingMembershipPlan = data.pendingMembershipPlan;
          user.pendingMembershipProductId = data.pendingMembershipProductId;
          user.pendingMembershipEffectiveAt = data.pendingMembershipEffectiveAt;
          await this.prefs.put(CURRENT_USER_KEY, JSON.stringify(user));
          await this.prefs.flush();
          const refreshedUser = await this.refreshUserFromServer();
          return refreshedUser ? refreshedUser : user;
        }
      }
      return null;
    } catch (error) {
      logger.error('purchaseMembership network error:', error as Object);
      trackApiError(TelemetryErrorCode.ERR_NET_TIMEOUT, error, 'subscription/buy');
      return null;
    }
  }

  private isValidAccount(accountType: AccountType, account: string): boolean {
    if (accountType === 'phone') {
      return /^1\d{10}$/.test(account);
    }
    if (accountType === 'email') {
      return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(account);
    }
    return account.length > 0;
  }
}

export const authService = new AuthService();
