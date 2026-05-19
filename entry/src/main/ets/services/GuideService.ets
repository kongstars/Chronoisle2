import dataPreferences from '@ohos.data.preferences';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('GuideService');

const GUIDE_PREFS_NAME: string = 'guide_prefs';

export class GuideService {
  private static prefs: dataPreferences.Preferences | null = null;

  static async initialize(context: Context): Promise<void> {
    if (!GuideService.prefs) {
      try {
        GuideService.prefs = await dataPreferences.getPreferences(context, GUIDE_PREFS_NAME);
      } catch (e) {
        logger.error('GuideService init failed', e as Object);
      }
    }
  }

  // ---- Coach Marks ----

  static async isCoachMarksCompleted(): Promise<boolean> {
    if (!GuideService.prefs) return true;
    try {
      return await GuideService.prefs.get('coach_marks_completed', false) as boolean;
    } catch (e) {
      return true;
    }
  }

  static async markCoachMarksCompleted(): Promise<void> {
    if (!GuideService.prefs) return;
    try {
      await GuideService.prefs.put('coach_marks_completed', true);
      await GuideService.prefs.flush();
    } catch (e) {
      logger.error('markCoachMarksCompleted failed', e as Object);
    }
  }

  // ---- Contextual Tips ----

  static async isTipShown(tipId: string): Promise<boolean> {
    if (!GuideService.prefs) return true;
    try {
      return await GuideService.prefs.get(`tip_${tipId}_shown`, false) as boolean;
    } catch (e) {
      return true;
    }
  }

  static async markTipShown(tipId: string): Promise<void> {
    if (!GuideService.prefs) return;
    try {
      await GuideService.prefs.put(`tip_${tipId}_shown`, true);
      await GuideService.prefs.flush();
    } catch (e) {
      logger.error('markTipShown failed', e as Object);
    }
  }

  // ---- 重置引导 ----

  static async resetAllGuides(): Promise<void> {
    try {
      if (GuideService.prefs) {
        await GuideService.prefs.clear();
        await GuideService.prefs.flush();
      }
      // 同时清除 onboarding 偏好
      const context = GuideService.prefs ? undefined : undefined;
      // 由于无法获取 context，onboarding prefs 的重置需要在调用方处理
    } catch (e) {
      logger.error('resetAllGuides failed', e as Object);
    }
  }

  static async resetAllGuidesWithContext(context: Context): Promise<void> {
    try {
      // 清除 coach marks 偏好
      if (GuideService.prefs) {
        await GuideService.prefs.clear();
        await GuideService.prefs.flush();
      }
      // 清除 onboarding 偏好
      const onboardingPrefs = await dataPreferences.getPreferences(context, 'onboarding_prefs');
      await onboardingPrefs.clear();
      await onboardingPrefs.flush();
    } catch (e) {
      logger.error('resetAllGuidesWithContext failed', e as Object);
    }
  }
}
