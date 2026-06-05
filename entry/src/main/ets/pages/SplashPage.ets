import { isOnboardingCompleted, ONBOARDING_COMPLETED_RUNTIME_KEY, ONBOARDING_ENTRY_PAYLOAD_KEY } from './OnboardingPage';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppCard } from '../ui/base/AppCard';
import { SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_NUMERIC_LG, TYPE_PAGE_TITLE } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('SplashPage');

@Entry
@Component
struct SplashPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;

  aboutToAppear(): void {
    void this.routeFromSplash();
  }

  private async routeFromSplash(): Promise<void> {
    let nextPage: string = 'pages/OnboardingPage';
    let nextParams: Record<string, Object> | undefined = undefined;
    try {
      const routeParams = this.getUIContext().getRouter().getParams() as Record<string, Object>;
      const context = this.getUIContext().getHostContext() as Context;
      const forcedCompleted = routeParams && routeParams['forceOnboardingCompleted'] === 'true';
      const runtimeCompleted = AppStorage.get<boolean>(ONBOARDING_COMPLETED_RUNTIME_KEY) === true;
      const completed = forcedCompleted || runtimeCompleted || await isOnboardingCompleted(context);
      if (completed) {
        nextPage = 'pages/MainPage';
        const onboardingPayload = routeParams && routeParams['openGoalCreate']
          ? routeParams as Record<string, string>
          : AppStorage.get<Record<string, string>>(ONBOARDING_ENTRY_PAYLOAD_KEY);
        if (onboardingPayload && onboardingPayload['openGoalCreate'] === 'true') {
          nextParams = {
            'openGoalCreate': onboardingPayload['openGoalCreate'],
            'onboardingGoalTitle': onboardingPayload['onboardingGoalTitle'],
            'onboardingCategory': onboardingPayload['onboardingCategory'],
            'onboardingTemplate': onboardingPayload['onboardingTemplate']
          };
        }
      } else {
        nextPage = 'pages/OnboardingPage';
      }
    } catch (error) {
      logger.error('routeFromSplash failed', error as Object);
    }

    setTimeout(() => {
      try {
        if (nextParams) {
          this.navigateToPage(nextPage, nextParams);
          AppStorage.delete(ONBOARDING_ENTRY_PAYLOAD_KEY);
        } else {
          this.navigateToPage(nextPage);
        }
      } catch (routerError) {
        logger.error('replaceUrl failed', routerError as Object);
        try {
          if (nextParams) {
            this.pushToPage(nextPage, nextParams);
            AppStorage.delete(ONBOARDING_ENTRY_PAYLOAD_KEY);
          } else {
            this.pushToPage(nextPage);
          }
          return;
        } catch (pushError) {
          logger.error('pushUrl failed', pushError as Object);
        }

        if (nextPage !== 'pages/OnboardingPage') {
          const replaceErr = this.formatError(routerError as Object);
          this.getUIContext().getPromptAction().showToast({ message: `首页打开失败: ${replaceErr}` });
          try {
            this.navigateToPage('pages/OnboardingPage');
          } catch (fallbackError) {
            logger.error('fallback replaceUrl failed', fallbackError as Object);
          }
        }
      }
    }, 10);
  }

  private navigateToPage(url: string, params?: Record<string, Object>): void {
    try {
      if (params) {
        this.getUIContext().getRouter().replaceUrl({ url, params });
      } else {
        this.getUIContext().getRouter().replaceUrl({ url });
      }
    } catch (_) {}
  }

  private pushToPage(url: string, params?: Record<string, Object>): void {
    try {
      if (params) {
        this.getUIContext().getRouter().pushUrl({ url, params });
      } else {
        this.getUIContext().getRouter().pushUrl({ url });
      }
    } catch (_) {}
  }

  private formatError(error: Object): string {
    try {
      const raw = JSON.stringify(error);
      if (raw && raw !== '{}') {
        return raw;
      }
    } catch (_) {
    }
    return `${error}`;
  }

  build() {
    Column({ space: SPACE_SM }) {
      Column() {
        AppCard({ variant: 'raised', spacing: SPACE_XS, paddingLevel: 'md' }) {
          Text('四时清单')
            .fontSize(TYPE_PAGE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)

          Text('Chronoisle')
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textSecondary)

          Row({ space: SPACE_XS }) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color(this.themeColors.primary)

            Text('正在准备你的效率面板...')
              .fontSize(TYPE_BODY)
              .fontColor(this.themeColors.textSecondary)
          }
        }
      }
      .width('80%')

      Text('清晰、简洁、专注执行')
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textMuted)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.themeColors.background)
  }
}
