import dataPreferences from '@ohos.data.preferences';
import util from '@ohos.util';
import { initialize as initAGConnect, JsonTypeInfo } from '@hw-agconnect/hmcore';
import { common } from '@kit.AbilityKit';

import { authService } from './AuthService';
import { TelemetryService } from './TelemetryService';
import AppConfig from '../Utils/AppConfig';
import { Logger } from '../Utils/Logger';

const ONBOARDING_PREFS_NAME: string = 'onboarding_prefs';
const ONBOARDING_COMPLETED_KEY: string = 'onboarding_completed';

const APP_VERSION_NAME: string = '1.0.0';

const logger = Logger.create('PrivacyConsent');

/**
 * 隐私同意网关服务
 *
 * 上架合规要求：用户在 Onboarding 中勾选《隐私政策》《用户协议》之前，
 * 任何 SDK 初始化、网络请求都不得发起。本服务集中托管这些"敏感初始化"，
 * 由 EntryAbility 在 onWindowStageCreate / onForeground 调用，
 * 同时由 OnboardingPage 在用户同意后立即调用。
 *
 * 设计原则：
 * - 仅初始化一次：通过 `initialized` 标志位防重入。
 * - 同意检查：必须先通过 `hasUserConsented` 确认 Onboarding 已完成。
 * - 不阻塞启动：内部捕获异常并记录日志，避免影响主流程。
 *
 * 已托管的副作用：
 * - AGConnect Core SDK 初始化（依赖应用内 agconnect-services.json）。
 * - 埋点服务 TelemetryService.init（启动定时上报）。
 * - 用户信息从服务端刷新 authService.refreshUserFromServer。
 */
export class PrivacyConsentService {
  private static initialized: boolean = false;

  /**
   * 检查用户是否已经在 Onboarding 中勾选同意。
   * 注意：这里直接读取 dataPreferences，不走 AppStorage，避免冷启动时拿不到。
   */
  static async hasUserConsented(context: Context): Promise<boolean> {
    try {
      const prefs = await dataPreferences.getPreferences(context, ONBOARDING_PREFS_NAME);
      const value = await prefs.get(ONBOARDING_COMPLETED_KEY, false);
      return value === true;
    } catch (error) {
      logger.warn('hasUserConsented read prefs failed', error as Object);
      return false;
    }
  }

  /**
   * 在用户同意后初始化所有敏感 SDK / 网络。
   * 多次调用是安全的，只在首次成功时执行实际初始化。
   */
  static async initializeAfterConsent(context: common.UIAbilityContext): Promise<void> {
    if (PrivacyConsentService.initialized) {
      return;
    }

    const consented = await PrivacyConsentService.hasUserConsented(context);
    if (!consented) {
      logger.debug('skip initialization: user has not consented yet');
      return;
    }

    PrivacyConsentService.initialized = true;
    logger.info('initializing post-consent SDKs');

    PrivacyConsentService.initAGConnect(context);

    try {
      const token = await authService.getToken();
      await TelemetryService.init(
        context,
        AppConfig.getBaseUrl(),
        token || '',
        APP_VERSION_NAME
      );
    } catch (error) {
      logger.error('TelemetryService init failed', error as Object);
    }

    try {
      await authService.refreshUserFromServer();
    } catch (error) {
      logger.error('refreshUserFromServer failed', error as Object);
    }
  }

  private static initAGConnect(context: common.UIAbilityContext): void {
    try {
      const jsonStr = context.resourceManager.getRawFileContentSync('agconnect-services.json');
      const textDecoder = new util.TextDecoder('utf-8');
      const jsonContent = textDecoder.decodeToString(jsonStr);
      const json: JsonTypeInfo = JSON.parse(jsonContent) as JsonTypeInfo;
      initAGConnect(context, json);
      logger.info('AGConnect SDK initialized after consent');
    } catch (error) {
      logger.error('AGConnect SDK init failed', error as Object);
    }
  }

  /** 仅供单元测试或登出/注销时重置状态。 */
  static resetForTesting(): void {
    PrivacyConsentService.initialized = false;
  }
}
