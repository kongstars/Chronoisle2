import { common } from '@kit.AbilityKit';
import dataPreferences from '@ohos.data.preferences';
import http from '@ohos.net.http';
import { authService, ApiResponse } from './AuthService';
import AppConfig from '../Utils/AppConfig';
import { TelemetryService } from './TelemetryService';
import { TelemetryErrorCode } from '../models/TelemetryErrorCode';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('IAPRetryQueue');

const PREFS_NAME = 'iap_retry_queue';
const PREFS_KEY_QUEUE = 'pending_orders';

interface PendingVerification {
  orderId: string;
  jwsPurchaseOrder: string;
  productId?: string;
  purchaseData?: string;
  createdAt: number;
  retryCount: number;
  nextRetryAt: number;
  lastError: string;
}

interface VerifyResult {
  success: boolean;
  message: string;
  membershipType?: string;
  membershipPlan?: string;
  membershipProductId?: string;
  membershipExpireAt?: number;
  membershipRenewAt?: number;
  pendingMembershipPlan?: string;
  pendingMembershipProductId?: string;
  pendingMembershipEffectiveAt?: number;
}

const RETRY_INTERVALS = [5 * 60 * 1000, 30 * 60 * 1000, 2 * 60 * 60 * 1000];
const MAX_RETRY_COUNT = 3;

export class IAPRetryQueue {
  private static instance: IAPRetryQueue;
  private context: common.UIAbilityContext | null = null;

  private constructor() {}

  static getInstance(): IAPRetryQueue {
    if (!IAPRetryQueue.instance) {
      IAPRetryQueue.instance = new IAPRetryQueue();
    }
    return IAPRetryQueue.instance;
  }

  initialize(context: common.UIAbilityContext): void {
    this.context = context;
  }

  async addToQueue(order: PendingVerification): Promise<void> {
    if (!this.context) {
      return;
    }

    try {
      const prefs = await dataPreferences.getPreferences(this.context, PREFS_NAME);
      const raw = prefs.getSync(PREFS_KEY_QUEUE, '[]') as string;
      const queue: PendingVerification[] = JSON.parse(raw);

      const existing = queue.findIndex((o) => o.orderId === order.orderId);
      if (existing >= 0) {
        queue[existing] = order;
      } else {
        queue.push(order);
      }

      await prefs.put(PREFS_KEY_QUEUE, JSON.stringify(queue));
      await prefs.flush();
    } catch (e) {
      logger.error('[IAPRetryQueue] addToQueue failed', e as Object);
    }
  }

  async processQueue(): Promise<void> {
    if (!this.context) {
      return;
    }

    let queue: PendingVerification[];
    try {
      const prefs = await dataPreferences.getPreferences(this.context, PREFS_NAME);
      const raw = prefs.getSync(PREFS_KEY_QUEUE, '[]') as string;
      queue = JSON.parse(raw);
    } catch (e) {
      logger.error('[IAPRetryQueue] read queue failed', e as Object);
      return;
    }

    if (!Array.isArray(queue) || queue.length === 0) {
      return;
    }

    const token = await authService.getToken();
    if (!token) {
      return;
    }

    const now = Date.now();
    const remaining: PendingVerification[] = [];
    let dirty = false;

    for (const order of queue) {
      if (order.retryCount >= MAX_RETRY_COUNT) {
        continue;
      }

      if (order.nextRetryAt > now) {
        remaining.push(order);
        continue;
      }

      const result = await this.verifyOrder(token, order);
      if (result.success) {
        await authService.updateMembership(
          (result.membershipType as 'basic' | 'premium') || 'premium',
          result.membershipExpireAt || 0,
          {
            membershipPlan: result.membershipPlan || '',
            membershipProductId: result.membershipProductId || '',
            membershipRenewAt: result.membershipRenewAt || 0,
            pendingMembershipPlan: result.pendingMembershipPlan || '',
            pendingMembershipProductId: result.pendingMembershipProductId || '',
            pendingMembershipEffectiveAt: result.pendingMembershipEffectiveAt || 0
          }
        );
        dirty = true;
        continue;
      }

      const nextRetryCount = order.retryCount + 1;
      if (nextRetryCount < MAX_RETRY_COUNT) {
        const retryOrder: PendingVerification = {
          orderId: order.orderId,
          jwsPurchaseOrder: order.jwsPurchaseOrder,
          productId: order.productId,
          purchaseData: order.purchaseData,
          createdAt: order.createdAt,
          retryCount: nextRetryCount,
          nextRetryAt: now + RETRY_INTERVALS[nextRetryCount],
          lastError: result.message
        };
        remaining.push(retryOrder);
      }
      dirty = true;
    }

    if (dirty) {
      try {
        const prefs = await dataPreferences.getPreferences(this.context, PREFS_NAME);
        await prefs.put(PREFS_KEY_QUEUE, JSON.stringify(remaining));
        await prefs.flush();
      } catch (e) {
        logger.error('[IAPRetryQueue] save queue failed', e as Object);
      }
    }
  }

  async getPendingOrders(): Promise<PendingVerification[]> {
    if (!this.context) {
      return [];
    }

    try {
      const prefs = await dataPreferences.getPreferences(this.context, PREFS_NAME);
      const raw = prefs.getSync(PREFS_KEY_QUEUE, '[]') as string;
      return JSON.parse(raw);
    } catch (e) {
      logger.error('[IAPRetryQueue] getPendingOrders failed', e as Object);
      return [];
    }
  }

  private async verifyOrder(token: string, order: PendingVerification): Promise<VerifyResult> {
    const req = http.createHttp();
    try {
      const checkUrl = AppConfig.getBaseUrl() + '/api/iap/verifyOrder';

      interface VerifyBody {
        jwsPurchaseOrder: string;
        productId?: string;
        purchaseData?: string;
      }

      const body: VerifyBody = { jwsPurchaseOrder: order.jwsPurchaseOrder };
      if (order.productId && order.productId.length > 0) {
        body.productId = order.productId;
      }
      if (order.purchaseData && order.purchaseData.length > 0) {
        body.purchaseData = order.purchaseData;
      }

      const response = await req.request(checkUrl, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        extraData: JSON.stringify(body),
        connectTimeout: 10000,
        readTimeout: 10000
      });

      req.destroy();

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as ApiResponse<Record<string, Object>>;
        if (result.success) {
          const data = result.data;
          return {
            success: true,
            message: result.message || '重试验证成功',
            membershipType: data?.['membershipType'] as string,
            membershipPlan: data?.['membershipPlan'] as string || '',
            membershipProductId: data?.['membershipProductId'] as string || '',
            membershipExpireAt: data?.['membershipExpireAt'] as number || 0,
            membershipRenewAt: data?.['membershipRenewAt'] as number || 0,
            pendingMembershipPlan: data?.['pendingMembershipPlan'] as string || '',
            pendingMembershipProductId: data?.['pendingMembershipProductId'] as string || '',
            pendingMembershipEffectiveAt: data?.['pendingMembershipEffectiveAt'] as number || 0
          };
        }
        return { success: false, message: result.message || '重试验证失败' };
      }

      return { success: false, message: `服务器错误: ${response.responseCode}` };
    } catch (e) {
      logger.error('[IAPRetryQueue] verifyOrder failed', e as Object);
      req.destroy();
      TelemetryService.track('api_error', {
        "code": TelemetryErrorCode.ERR_IAP_VERIFY_FAIL,
        "msg": String(e).substring(0, 50),
        "path": 'iap/retryVerify'
      }, 'other');
      return { success: false, message: '网络请求失败' };
    }
  }
}

export const iapRetryQueue = IAPRetryQueue.getInstance();
