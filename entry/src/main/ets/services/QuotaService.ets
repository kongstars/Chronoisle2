import dataPreferences from '@ohos.data.preferences';
import http from '@ohos.net.http';
import AppConfig from '../Utils/AppConfig';
import { authService, type UserAccount } from './AuthService';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('QuotaService');
export interface QuotaResult {
  allowed: boolean;
  remaining: number;
  limit: number;
}

export interface SpendResult {
  success: boolean;
  message: string;
  balance: number;
  spent: number;
  requireMembership?: boolean;
}

export interface FeatureAccessResult {
  allowed: boolean;
  message: string;
  balance: number;
  required: number;
  isMemberActive: boolean;
  requireMembership: boolean;
}

interface CreditBalanceData {
  balance?: number;
  totalEarned?: number;
  totalSpent?: number;
  isFrozen?: boolean;
  isMemberActive?: boolean;
  lastGrantMonth?: string;
}

interface AITaskUsage {
  triggers?: number;
}

interface GoalBreakdownUsage {
  triggers?: number;
}

interface TodayPlanUsage {
  triggers?: number;
}

interface RescheduleUsage {
  triggers?: number;
}

interface AIFeatureUsage {
  ai_task?: AITaskUsage;
  goal_breakdown?: GoalBreakdownUsage;
  today_plan?: TodayPlanUsage;
  reschedule?: RescheduleUsage;
}
interface MonthlyUsage {
  voiceSeconds?: number;
  aiFeatureUsage?: AIFeatureUsage;
}

interface UsageDetail {
  feature?: string;
  action?: string;
}

export class QuotaService {
  private static PREF_NAME = 'chronoisle_quota';
  private static instance: dataPreferences.Preferences | null = null;

  private static isPremiumActive(user: UserAccount | null): boolean {
    return authService.isPremiumUser(user);
  }

  private static buildLegacyFeatureAccessResult(
    feature: string,
    balance: number,
    isMemberActive: boolean,
    isFrozen: boolean
  ): FeatureAccessResult {
    const required = feature === 'voice_task' ? 1 : 1;

    if (isFrozen) {
      return {
        allowed: false,
        message: '账户积分已被冻结，请联系客服处理',
        balance,
        required,
        isMemberActive,
        requireMembership: false
      };
    }

    if (feature === 'voice_task') {
      if (isMemberActive || balance >= required) {
        return {
          allowed: true,
          message: isMemberActive ? '会员可直接使用语音创建' : '积分充足，可使用语音创建',
          balance,
          required,
          isMemberActive,
          requireMembership: false
        };
      }

      return {
        allowed: false,
        message: `积分不足，语音创建至少需要 ${required} 积分`,
        balance,
        required,
        isMemberActive,
        requireMembership: false
      };
    }

    if (!isMemberActive) {
      return {
        allowed: false,
        message: '需要有效会员才能使用此功能',
        balance,
        required,
        isMemberActive,
        requireMembership: true
      };
    }

    if (balance < required) {
      return {
        allowed: false,
        message: '积分不足',
        balance,
        required,
        isMemberActive,
        requireMembership: false
      };
    }

    return {
      allowed: true,
      message: '校验通过',
      balance,
      required,
      isMemberActive,
      requireMembership: false
    };
  }

  private static async checkFeatureAccessLegacy(feature: string, token: string): Promise<FeatureAccessResult> {
    const currentUser = await authService.getCurrentUser();
    const cachedBalance = currentUser?.creditBalance || 0;
    const cachedFrozen = currentUser?.creditFrozen === true;
    const cachedMemberActive = currentUser?.isMemberActive === true || QuotaService.isPremiumActive(currentUser || null);

    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/credit/balance`,
        {
          method: http.RequestMethod.GET,
          header: {
            'Authorization': `Bearer ${token}`
          },
          connectTimeout: 8000,
          readTimeout: 8000
        }
      );
      httpRequest.destroy();

      if (response.responseCode === 200) {
        interface CreditBalanceResponse {
          success: boolean;
          message?: string;
          data?: CreditBalanceData;
        }

        const result: CreditBalanceResponse = JSON.parse(response.result as string);
        const data = result.data;
        const balance = data?.balance ?? cachedBalance;
        const isFrozen = data?.isFrozen === true;
        const isMemberActive = data?.isMemberActive === true || cachedMemberActive;
        return QuotaService.buildLegacyFeatureAccessResult(feature, balance, isMemberActive, isFrozen);
      }
    } catch (e) {
      logger.warn('checkFeatureAccessLegacy balance failed', e as Object);
    }

    return QuotaService.buildLegacyFeatureAccessResult(feature, cachedBalance, cachedMemberActive, cachedFrozen);
  }

  private static async getPreferences(context: Context): Promise<dataPreferences.Preferences> {
    try {
      if (!QuotaService.instance) {
        QuotaService.instance = await dataPreferences.getPreferences(context, QuotaService.PREF_NAME);
      }
      return QuotaService.instance;
    } catch (_) {
      throw new Error('Failed to get preferences');
    }
  }

  private static getMonthKey(): string {
    const now = new Date();
    return `${now.getFullYear()}_${now.getMonth() + 1}`;
  }

  private static async reportUsageToServer(type: string, amount: number, detail?: object): Promise<boolean> {
    try {
      const token = await authService.getToken();
      if (!token) return false;
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/usage/report`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          },
          extraData: JSON.stringify({ type, amount, detail }),
          connectTimeout: 5000,
          readTimeout: 5000
        }
      );
      httpRequest.destroy();
      return response.responseCode === 200;
    } catch (e) {
      logger.error('Failed to report usage', e as Object);
      return false;
    }
  }

  /**
   * 调用服务端 /api/credit/spend 真实扣除积分
   * AI/语音功能每次调用前都应先调此方法
   */
  public static async spendCredit(feature: string, idempotencyKey?: string): Promise<SpendResult> {
    try {
      const token = await authService.getToken();
      if (!token || token.startsWith('offline-')) {
        return { success: false, message: '未登录或离线状态', balance: 0, spent: 0 };
      }
      const httpRequest = http.createHttp();
      interface SpendBody { feature: string; idempotencyKey?: string; }
      const body: SpendBody = { feature };
      if (idempotencyKey) {
        body.idempotencyKey = idempotencyKey;
      }
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/credit/spend`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          },
          extraData: JSON.stringify(body),
          connectTimeout: 8000,
          readTimeout: 8000
        }
      );
      httpRequest.destroy();
      if (response.responseCode === 200) {
        interface SpendResponseData { spent?: number; balance?: number; requireMembership?: boolean; }
        interface SpendResponse { success: boolean; message: string; data?: SpendResponseData; }
        const result: SpendResponse = JSON.parse(response.result as string);
        return {
          success: result.success,
          message: result.message || '',
          balance: result.data?.balance || 0,
          spent: result.data?.spent || 0,
          requireMembership: result.data?.requireMembership
        };
      }
      return { success: false, message: '服务器错误', balance: 0, spent: 0 };
    } catch (e) {
      logger.error('spendCredit failed', e as Object);
      return { success: false, message: '网络异常', balance: 0, spent: 0 };
    }
  }

  public static async checkFeatureAccess(feature: string): Promise<FeatureAccessResult> {
    try {
      const token = await authService.getToken();
      if (!token || token.startsWith('offline-')) {
        return {
          allowed: false,
          message: '请先登录后再使用该功能',
          balance: 0,
          required: 1,
          isMemberActive: false,
          requireMembership: false
        };
      }

      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/credit/precheck`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          },
          extraData: JSON.stringify({ feature }),
          connectTimeout: 8000,
          readTimeout: 8000
        }
      );
      httpRequest.destroy();

      if (response.responseCode === 200) {
        interface AccessResponseData {
          allowed?: boolean;
          message?: string;
          balance?: number;
          required?: number;
          isMemberActive?: boolean;
          requireMembership?: boolean;
        }
        interface AccessResponse {
          success: boolean;
          message?: string;
          data?: AccessResponseData;
        }

        const result: AccessResponse = JSON.parse(response.result as string);
        const data = result.data;
        return {
          allowed: !!data?.allowed,
          message: data?.message || result.message || '当前暂不可用',
          balance: data?.balance || 0,
          required: data?.required || 1,
          isMemberActive: !!data?.isMemberActive,
          requireMembership: !!data?.requireMembership
        };
      }

      return await QuotaService.checkFeatureAccessLegacy(feature, token);
    } catch (e) {
      logger.error('checkFeatureAccess failed', e as Object);
      const token = await authService.getToken();
      if (token && !token.startsWith('offline-')) {
        return await QuotaService.checkFeatureAccessLegacy(feature, token);
      }
      return {
        allowed: false,
        message: '网络异常，请稍后重试',
        balance: 0,
        required: 1,
        isMemberActive: false,
        requireMembership: false
      };
    }
  }

  public static async checkVoiceCreateAccess(): Promise<FeatureAccessResult> {
    return QuotaService.checkFeatureAccess('voice_task');
  }

  public static async syncWithCloud(context: Context): Promise<void> {
    try {
      const token = await authService.getToken();
      if (!token) return;
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/usage/my`,
        {
          method: http.RequestMethod.GET,
          header: { 'Authorization': `Bearer ${token}` },
          connectTimeout: 5000,
          readTimeout: 5000
        }
      );
      httpRequest.destroy();
      if (response.responseCode === 200) {
        interface UsageData { monthly: MonthlyUsage | null; }
        interface UsageResponse { success: boolean; data: UsageData; }
        
        const resObj: UsageResponse = JSON.parse(response.result as string);
        if (resObj.success && resObj.data) {
          const m = resObj.data.monthly;
          const prefs = await QuotaService.getPreferences(context);
          const monthKey = QuotaService.getMonthKey();
          
          const voiceSeconds = m ? (m.voiceSeconds || 0) : 0;
          await prefs.put(`voice_dur_${monthKey}`, voiceSeconds);
          
          const aiTask = m?.aiFeatureUsage?.ai_task?.triggers || 0;
          await prefs.put(`ai_task_${monthKey}`, aiTask);

          const goalBreakdown = m?.aiFeatureUsage?.goal_breakdown?.triggers || 0;
          await prefs.put('ai_goal_breakdown', goalBreakdown);

          const todayPlan = m?.aiFeatureUsage?.today_plan?.triggers || 0;
          await prefs.put(`ai_today_plan_${monthKey}`, todayPlan);

          const reschedule = m?.aiFeatureUsage?.reschedule?.triggers || 0;
          await prefs.put(`ai_reschedule_${monthKey}`, reschedule);

          await prefs.flush();
        }
      }
    } catch (e) {
      logger.error('Failed to sync quota with cloud', e as Object);
    }
  }

  public static async incrementAITaskCount(context: Context): Promise<SpendResult> {
    const spendResult = await QuotaService.spendCredit('ai_task');
    if (spendResult.success) {
      try {
        const prefs = await QuotaService.getPreferences(context);
        const key = `ai_task_${QuotaService.getMonthKey()}`;
        const count = await prefs.get(key, 0) as number;
        await prefs.put(key, count + 1);
        await prefs.flush();
      } catch (_) {}
      QuotaService.reportUsageToServer('ai_feature', 1, { feature: 'ai_task', action: 'trigger' } as UsageDetail);
    }
    return spendResult;
  }

  public static async getAITaskCount(context: Context): Promise<number> {
    try {
      const prefs = await QuotaService.getPreferences(context);
      const key = `ai_task_${QuotaService.getMonthKey()}`;
      return await prefs.get(key, 0) as number;
    } catch (_) {
      return 0;
    }
  }

  // --- 高阶 AI 独立配额 ---
  public static async incrementGoalBreakdownCount(context: Context): Promise<SpendResult> {
    const spendResult = await QuotaService.spendCredit('goal_breakdown');
    if (spendResult.success) {
      try {
        const prefs = await QuotaService.getPreferences(context);
        const count = await prefs.get('ai_goal_breakdown', 0) as number;
        await prefs.put('ai_goal_breakdown', count + 1);
        await prefs.flush();
      } catch (_) {}
      QuotaService.reportUsageToServer('ai_feature', 1, { feature: 'goal_breakdown', action: 'trigger' } as UsageDetail);
    }
    return spendResult;
  }

  public static async checkGoalBreakdownQuota(context: Context): Promise<QuotaResult> {
    try {
      const user = await authService.getCurrentUser();
      const isPremium = authService.isPremiumUser(user);
      const limit = isPremium ? 999999 : 3;
      const prefs = await QuotaService.getPreferences(context);
      const count = await prefs.get('ai_goal_breakdown', 0) as number;
      return { allowed: count < limit, remaining: Math.max(0, limit - count), limit };
    } catch (_) {
      return { allowed: false, remaining: 0, limit: 0 };
    }
  }

  public static async incrementTodayPlanCount(context: Context): Promise<SpendResult> {
    const spendResult = await QuotaService.spendCredit('today_plan');
    if (spendResult.success) {
      try {
        const prefs = await QuotaService.getPreferences(context);
        const key = `ai_today_plan_${QuotaService.getMonthKey()}`;
        const count = await prefs.get(key, 0) as number;
        await prefs.put(key, count + 1);
        await prefs.flush();
      } catch (_) {}
      QuotaService.reportUsageToServer('ai_feature', 1, { feature: 'today_plan', action: 'trigger' } as UsageDetail);
    }
    return spendResult;
  }
  public static async checkTodayPlanQuota(context: Context): Promise<QuotaResult> {
    try {
      const user = await authService.getCurrentUser();
      const isPremium = authService.isPremiumUser(user);
      const limit = isPremium ? 999999 : 5;
      const prefs = await QuotaService.getPreferences(context);
      const key = `ai_today_plan_${QuotaService.getMonthKey()}`;
      const count = await prefs.get(key, 0) as number;
      return { allowed: count < limit, remaining: Math.max(0, limit - count), limit };
    } catch (_) {
      return { allowed: false, remaining: 0, limit: 0 };
    }
  }

  public static async incrementRescheduleCount(context: Context): Promise<SpendResult> {
    const spendResult = await QuotaService.spendCredit('reschedule');
    if (spendResult.success) {
      try {
        const prefs = await QuotaService.getPreferences(context);
        const key = `ai_reschedule_${QuotaService.getMonthKey()}`;
        const count = await prefs.get(key, 0) as number;
        await prefs.put(key, count + 1);
        await prefs.flush();
      } catch (_) {}
      QuotaService.reportUsageToServer('ai_feature', 1, { feature: 'reschedule', action: 'trigger' } as UsageDetail);
    }
    return spendResult;
  }
  public static async checkRescheduleQuota(context: Context): Promise<QuotaResult> {
    try {
      const user = await authService.getCurrentUser();
      const isPremium = authService.isPremiumUser(user);
      const limit = isPremium ? 999999 : 5;
      const prefs = await QuotaService.getPreferences(context);
      const key = `ai_reschedule_${QuotaService.getMonthKey()}`;
      const count = await prefs.get(key, 0) as number;
      return { allowed: count < limit, remaining: Math.max(0, limit - count), limit };
    } catch (_) {
      return { allowed: false, remaining: 0, limit: 0 };
    }
  }
  // ----------------------

  public static async incrementVoiceDuration(context: Context, seconds: number): Promise<SpendResult> {
    const spendResult = await QuotaService.spendCredit('voice_task');
    if (spendResult.success) {
      try {
        const prefs = await QuotaService.getPreferences(context);
        const key = `voice_dur_${QuotaService.getMonthKey()}`;
        const currentDur = await prefs.get(key, 0) as number;
        await prefs.put(key, currentDur + seconds);
        await prefs.flush();
      } catch (_) {}
      QuotaService.reportUsageToServer('voice', seconds, {} as UsageDetail);
    }
    return spendResult;
  }

  public static async getVoiceDuration(context: Context): Promise<number> {
    try {
      const prefs = await QuotaService.getPreferences(context);
      const key = `voice_dur_${QuotaService.getMonthKey()}`;
      return await prefs.get(key, 0) as number;
    } catch (_) {
      return 0;
    }
  }
  public static async checkAITaskQuota(context: Context): Promise<QuotaResult> {
    const user = await authService.getCurrentUser();
    const isPremium = authService.isPremiumUser(user);
    const limit = isPremium ? 300 : 20;
    const count = await QuotaService.getAITaskCount(context);
    return {
      allowed: count < limit,
      remaining: Math.max(0, limit - count),
      limit
    };
  }

  public static async checkVoiceQuota(context: Context): Promise<QuotaResult> {
    const user = await authService.getCurrentUser();
    const isPremium = authService.isPremiumUser(user);
    const limitSec = isPremium ? 120 * 60 : 0;
    const currentSec = await QuotaService.getVoiceDuration(context);
    return {
      allowed: currentSec < limitSec,
      remaining: Math.max(0, limitSec - currentSec),
      limit: limitSec
    };
  }

  /**
   * 重置免费会员的所有本地配额计数器
   * 在用户从 basic 升级为 premium 时调用
   */
  public static async resetFreeQuotas(context: Context): Promise<void> {
    try {
      const prefs = await QuotaService.getPreferences(context);
      const monthKey = QuotaService.getMonthKey();
      await prefs.delete(`ai_task_${monthKey}`);
      await prefs.delete('ai_goal_breakdown');
      await prefs.delete(`ai_today_plan_${monthKey}`);
      await prefs.delete(`ai_reschedule_${monthKey}`);
      await prefs.delete(`voice_dur_${monthKey}`);
      await prefs.flush();
    } catch (_) {}
  }

  /**
   * 通用 Premium 功能检查
   * 用于番茄轮次、白噪音、专注统计等高级功能的权限判断
   */
  public static async checkPremiumFeature(context: Context): Promise<QuotaResult> {
    const user = await authService.getCurrentUser();
    const isPremium = authService.isPremiumUser(user);
    const result: QuotaResult = { allowed: !!isPremium, remaining: isPremium ? 999 : 0, limit: 999 };
    return result;
  }

  /**
   * 检查目标创建配额
   * 免费用户最多创建 5 个进行中的目标，高级会员无限制
   * @param activeGoalCount 当前活跃目标数量（由调用方传入，避免循环依赖）
   */
  public static async checkGoalQuota(context: Context, activeGoalCount: number): Promise<QuotaResult> {
    const user = await authService.getCurrentUser();
    const isPremium = authService.isPremiumUser(user);
    const FREE_MAX_GOALS = 5;
    const limit = isPremium ? 999999 : FREE_MAX_GOALS;
    return {
      allowed: activeGoalCount < limit,
      remaining: Math.max(0, limit - activeGoalCount),
      limit
    };
  }
}
