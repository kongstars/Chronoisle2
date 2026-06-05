import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import type { Configuration as AbilityConfiguration } from '@ohos.app.ability.Configuration';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import EnvironmentCallback from '@ohos.app.ability.EnvironmentCallback';
import Want from '@ohos.app.ability.Want';
import commonEventManager from '@ohos.commonEventManager';
import hilog from '@ohos.hilog';
import resourceManager from '@ohos.resourceManager';
import window from '@ohos.window';
import { common } from '@kit.AbilityKit';
import { Goal } from '../models/Goal';
import { Task } from '../models/Task';
import { db, toSyncDataSet } from '../storage/Database';
import { authService } from '../services/AuthService';
import { cloudSyncService, DatabaseAdapter, SyncDataSet } from '../services/CloudSyncService';
import type { ThemeColors } from '../theme/AppTheme';
import { CURRENT_COLOR_MODE_KEY, themeService } from '../services/ThemeService';
import { dayEventReminderService } from '../services/DayEventReminderService';
import { TelemetryService } from '../services/TelemetryService';
import { iapRetryQueue } from '../services/IAPRetryQueue';
import { MembershipReminderService } from '../services/MembershipReminderService';
import { PrivacyConsentService } from '../services/PrivacyConsentService';

class EntryDatabaseAdapter implements DatabaseAdapter {
  exportData(): SyncDataSet {
    return toSyncDataSet(db.exportData());
  }

  replaceAllData(goals: Goal[], tasks: Task[]): Promise<void> {
    return db.replaceAllData(goals, tasks);
  }
}

class AppEnvironmentCallback extends EnvironmentCallback {
  private readonly onConfigUpdatedHandler: (config: AbilityConfiguration) => void;

  constructor(onConfigUpdatedHandler: (config: AbilityConfiguration) => void) {
    super();
    this.onConfigUpdatedHandler = onConfigUpdatedHandler;
  }

  onConfigurationUpdated(config: AbilityConfiguration): void {
    this.onConfigUpdatedHandler(config);
  }
}

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private themeListener: ((colors: ThemeColors) => void) | null = null;
  private sleepModeSubscriber: commonEventManager.CommonEventSubscriber | null = null;
  private themeRefreshVersion: number = 0;
  private environmentCallbackId: number = -1;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    // AGConnect、埋点、refreshUser 等会触发网络请求的 SDK 不在 onCreate 立即执行，
    // 改由 PrivacyConsentService 在用户同意隐私政策后再初始化（合规要求）。
    this.handleIncomingWant(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', 'Ability onNewWant, target: %{public}s', want.parameters?.target as string);
    this.handleIncomingWant(want);
  }

  onDestroy(): void {
    this.unregisterEnvironmentCallback();
    this.unregisterSleepModeSubscriber();
    if (this.themeListener) {
      themeService.unsubscribe(this.themeListener);
      this.themeListener = null;
    }
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    let windowClass: window.Window;
    try {
      windowClass = windowStage.getMainWindowSync();
      this.mainWindow = windowClass;
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Failed to get main window: %{public}s', JSON.stringify(err));
      return;
    }

    Promise.all([
      db.initialize(this.context),
      authService.initialize(this.context),
      cloudSyncService.initialize(this.context),
      themeService.initialize(this.context),
      dayEventReminderService.initialize(this.context)
    ]).then(async () => {
      iapRetryQueue.initialize(this.context as common.UIAbilityContext);

      // 仅在用户同意隐私政策后初始化埋点 / AGConnect / 拉取用户信息
      await PrivacyConsentService.initializeAfterConsent(this.context as common.UIAbilityContext);

      this.registerEnvironmentCallback();
      await this.registerSleepModeSubscriber();
      await this.refreshThemeFromSystem(this.context.config.colorMode as ConfigurationConstant.ColorMode | undefined);
      this.scheduleDeferredThemeRefresh();

      let initialPage = 'pages/SplashPage';

      try {
        windowStage.loadContent(initialPage, (err: Error) => {
          if (err) {
            hilog.error(0x0000, 'testTag', 'Failed to load content: %{public}s', err.message);
            return;
          }
          hilog.info(0x0000, 'testTag', 'Succeeded in loading content: %{public}s', initialPage);
        });
      } catch (err) {
        hilog.error(0x0000, 'testTag', 'Failed to load content: %{public}s', JSON.stringify(err));
      }

      this.applyWindowTheme(themeService.getThemeColors());
      if (!this.themeListener) {
        this.themeListener = (colors: ThemeColors) => {
          this.applyWindowTheme(colors);
        };
        themeService.subscribe(this.themeListener);
      }
    });
  }

  onConfigurationUpdate(newConfig: AbilityConfiguration): void {
    if (themeService.isSyncingProgrammaticColorMode()) {
      return;
    }

    void this.refreshThemeFromSystem(newConfig?.colorMode as ConfigurationConstant.ColorMode | undefined);
  }

  onWindowStageDestroy(): void {
    this.mainWindow = null;
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  async onForeground(): Promise<void> {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');

    try {
      await Promise.all([
        db.initialize(this.context),
        authService.initialize(this.context),
        cloudSyncService.initialize(this.context)
      ]);

      // 同意前不做任何网络请求 / SDK 初始化。
      const consented = await PrivacyConsentService.hasUserConsented(this.context);
      if (!consented) {
        await this.refreshThemeFromSystem(this.context.config.colorMode as ConfigurationConstant.ColorMode | undefined);
        return;
      }

      await PrivacyConsentService.initializeAfterConsent(this.context as common.UIAbilityContext);

      const user = await authService.getCurrentUser();
      if (user) {
        hilog.info(0x0000, 'testTag', 'Starting auto-sync for user: %{public}s', user.userId);
        const dbAdapter: DatabaseAdapter = new EntryDatabaseAdapter();
        await cloudSyncService.sync(dbAdapter);
        hilog.info(0x0000, 'testTag', 'Auto-sync completed successfully');
      }

      await this.refreshThemeFromSystem(this.context.config.colorMode as ConfigurationConstant.ColorMode | undefined);
      void iapRetryQueue.processQueue();

      const membershipUser = await authService.getCurrentUser();
      if (membershipUser) {
        const expiryMsg = await MembershipReminderService.checkExpiryOnLaunch(
          this.context,
          membershipUser.membershipType,
          membershipUser.membershipExpireAt
        );
        if (expiryMsg) {
          // 用主窗口的 UIContext 替代 deprecated 的全局 promptAction.showToast。
          try {
            this.mainWindow?.getUIContext().getPromptAction().showToast({ message: expiryMsg, duration: 3000 });
          } catch (toastErr) {
            hilog.warn(0x0000, 'testTag', 'show expiry toast failed: %{public}s', JSON.stringify(toastErr));
          }
        }
      }

      TelemetryService.trackImmediate('session_start', undefined, 'session');
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Auto-sync failed: %{public}s', JSON.stringify(err));
    }
  }

  onBackground(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
    void TelemetryService.flush();
  }

  private handleIncomingWant(want: Want): void {
    if (want.parameters?.target === 'voiceCreate') {
      AppStorage.setOrCreate('widgetLaunchTarget', 'voiceCreate');
    } else {
      AppStorage.setOrCreate('widgetLaunchTarget', '');
    }

    if (want.uri && (want.uri.startsWith('sishiqingdan://oauth_success') || want.uri.startsWith('sishiqingdan://oauth_error'))) {
      AppStorage.setOrCreate('oauthCallbackUrl', want.uri);
      hilog.info(0x0000, 'testTag', 'Received OAuth callback uri: %{public}s', want.uri);
    }
  }

  private async refreshThemeFromSystem(colorMode?: ConfigurationConstant.ColorMode): Promise<void> {
    const refreshVersion = ++this.themeRefreshVersion;
    const resolvedColorMode = await this.resolveSystemColorMode(colorMode);
    if (refreshVersion !== this.themeRefreshVersion) {
      return;
    }

    themeService.refreshSystemTheme(resolvedColorMode);
    this.applyWindowTheme(themeService.getThemeColors());
  }

  private async resolveSystemColorMode(colorMode?: ConfigurationConstant.ColorMode): Promise<ConfigurationConstant.ColorMode | undefined> {
    try {
      const config = await this.context.resourceManager.getConfiguration();
      if (config.colorMode === resourceManager.ColorMode.DARK) {
        hilog.info(0x0000, 'testTag', 'Theme sync resolved by resourceManager: dark');
        return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      }

      if (config.colorMode === resourceManager.ColorMode.LIGHT) {
        hilog.info(0x0000, 'testTag', 'Theme sync resolved by resourceManager: light');
        return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
      }
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Failed to read resourceManager configuration: %{public}s', JSON.stringify(err));
    }

    const storedColorMode = AppStorage.get<ConfigurationConstant.ColorMode>(CURRENT_COLOR_MODE_KEY);
    if (storedColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ||
      storedColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      hilog.info(0x0000, 'testTag', 'Theme sync resolved by AppStorage colorMode: %{public}d', Number(storedColorMode));
      return storedColorMode;
    }

    if (colorMode !== undefined) {
      hilog.info(0x0000, 'testTag', 'Theme sync fallback to callback colorMode: %{public}d', Number(colorMode));
      return colorMode;
    }

    const contextColorMode = this.context.config.colorMode as ConfigurationConstant.ColorMode | undefined;
    hilog.info(0x0000, 'testTag', 'Theme sync fallback to context colorMode: %{public}d', Number(contextColorMode));
    return contextColorMode;
  }

  private async registerSleepModeSubscriber(): Promise<void> {
    if (this.sleepModeSubscriber) {
      return;
    }

    try {
      const subscriber = await commonEventManager.createSubscriber({
        events: [
          commonEventManager.Support.COMMON_EVENT_ENTER_FORCE_SLEEP,
          commonEventManager.Support.COMMON_EVENT_EXIT_FORCE_SLEEP,
          commonEventManager.Support.COMMON_EVENT_ENTER_HIBERNATE,
          commonEventManager.Support.COMMON_EVENT_EXIT_HIBERNATE
        ]
      });

      commonEventManager.subscribe(subscriber, (err, data) => {
        if (err) {
          hilog.error(0x0000, 'testTag', 'Sleep mode subscribe callback error: %{public}s', JSON.stringify(err));
          return;
        }

        hilog.info(0x0000, 'testTag', 'Received sleep mode event: %{public}s', data?.event || '');
        void this.refreshThemeFromSystem();
        setTimeout(() => {
          void this.refreshThemeFromSystem();
        }, 300);
      });

      this.sleepModeSubscriber = subscriber;
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Failed to register sleep mode subscriber: %{public}s', JSON.stringify(err));
    }
  }

  private registerEnvironmentCallback(): void {
    if (this.environmentCallbackId !== -1) {
      return;
    }

    try {
      const applicationContext = this.context.getApplicationContext();
      const callback = new AppEnvironmentCallback((config: AbilityConfiguration): void => {
        hilog.info(0x0000, 'testTag', 'Received application environment update');
        if (themeService.isSyncingProgrammaticColorMode()) {
          return;
        }

        void this.refreshThemeFromSystem(config?.colorMode as ConfigurationConstant.ColorMode | undefined);
      });
      this.environmentCallbackId = applicationContext.on('environment', callback);
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Failed to register environment callback: %{public}s', JSON.stringify(err));
    }
  }

  private unregisterEnvironmentCallback(): void {
    if (this.environmentCallbackId === -1) {
      return;
    }

    const callbackId = this.environmentCallbackId;
    this.environmentCallbackId = -1;

    try {
      void this.context.getApplicationContext().off('environment', callbackId).catch((err: Error) => {
        hilog.error(0x0000, 'testTag', 'Failed to unregister environment callback: %{public}s', JSON.stringify(err));
      });
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Unregister environment callback error: %{public}s', JSON.stringify(err));
    }
  }

  private unregisterSleepModeSubscriber(): void {
    if (!this.sleepModeSubscriber) {
      return;
    }

    const subscriber = this.sleepModeSubscriber;
    this.sleepModeSubscriber = null;

    try {
      commonEventManager.unsubscribe(subscriber, (err) => {
        if (err) {
          hilog.error(0x0000, 'testTag', 'Failed to unregister sleep mode subscriber: %{public}s', JSON.stringify(err));
        }
      });
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Unregister sleep mode subscriber error: %{public}s', JSON.stringify(err));
    }
  }

  private applyWindowTheme(colors: ThemeColors): void {
    if (!this.mainWindow) {
      return;
    }

    try {
      const isDarkTheme = themeService.isDarkThemeActive();
      this.mainWindow.setWindowBackgroundColor(colors.background);
      const sysBarProps: window.SystemBarProperties = {
        statusBarColor: colors.background,
        navigationBarColor: colors.background,
        statusBarContentColor: colors.textPrimary,
        navigationBarContentColor: colors.textPrimary
      };
      this.mainWindow.setWindowSystemBarProperties(sysBarProps);
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Failed to apply window theme: %{public}s', JSON.stringify(err));
    }
  }

  private scheduleDeferredThemeRefresh(): void {
    setTimeout(() => {
      void this.refreshThemeFromSystem();
    }, 400);
  }
}
