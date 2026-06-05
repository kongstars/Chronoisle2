import { iap } from '@kit.IAPKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import http from '@ohos.net.http';
import util from '@ohos.util';
import { authService, ApiResponse } from './AuthService';
import { TelemetryProperties } from '../services/TelemetryService';
import promptAction from '@ohos.promptAction';
import AppConfig from '../Utils/AppConfig';
import { TelemetryService } from './TelemetryService';
import { TelemetryErrorCode } from '../models/TelemetryErrorCode';

export interface IAPProduct {
  productId: string;
  price: string;
  priceCurrencyCode: string;
  productName: string;
  productDesc: string;
}

export interface PurchaseResult {
  success: boolean;
  message: string;
  membershipType?: 'basic' | 'premium';
  membershipPlan?: string;
  membershipProductId?: string;
  membershipExpireAt?: number;
  membershipRenewAt?: number;
  pendingMembershipPlan?: string;
  pendingMembershipProductId?: string;
  pendingMembershipEffectiveAt?: number;
}

interface HwProduct {
  productId?: string;
  id?: string;
  price?: string;
  priceCurrencyCode?: string;
  currency?: string;
  productName?: string;
  name?: string;
  displayName?: string;
  localizedName?: string;
  productTitle?: string;
  title?: string;
  productDesc?: string;
  desc?: string;
  description?: string;
  localizedDescription?: string;
}

interface HwPurchaseResult {
  purchaseData?: string;
  purchaseToken?: string;
  jwsPurchaseOrder?: string;
}

interface HwPurchaseDataEnvelope {
  jwsSubscriptionStatus?: string;
  jwsPurchaseOrder?: string;
  jwsPurchaseData?: string;
  signedPurchaseOrder?: string;
  signedSubscriptionStatus?: string;
}

interface HwQueryPurchaseResult {
  purchaseDataList?: string[];
}

interface HuaweiPurchasePayload {
  purchaseToken?: string;
  purchaseTokenId?: string;
  token?: string;
  subscriptionToken?: string;
  purchaseId?: string;
  purchaseOrderId?: string;
  purchaseOrderID?: string;
  orderId?: string;
  orderID?: string;
  transactionId?: string;
  payOrderId?: string;
}

export class IAPService {
  private static instance: IAPService;

  private constructor() {}

  public static getInstance(): IAPService {
    if (!IAPService.instance) {
      IAPService.instance = new IAPService();
    }
    return IAPService.instance;
  }

  /**
   * 根据商品ID判断商品类型
   * 第一版只开放自动续期会员。
   */
  private getProductType(productId: string): iap.ProductType {
    if (AppConfig.getMembershipProductIds().includes(productId)) {
      return iap.ProductType.AUTORENEWABLE;
    }
    throw new Error('未支持的自动续期会员商品');
  }

  /**
   * 检查当前环境是否支持华为应用内支付
   */
  public async checkEnvironment(context: common.UIAbilityContext): Promise<boolean> {
    try {
      await iap.queryEnvironmentStatus(context);
      return true;
    } catch (err) {
      console.error('环境检查失败:', JSON.stringify(err));
      (() => { let _p: TelemetryProperties = { 
        "code": TelemetryErrorCode.ERR_IAP_ENV_INIT_FAIL, 
        "msg": String(err).substring(0, 50),
        "path": 'iap/environment'
      }; TelemetryService.track('api_error', _p, 'other'); })();
      return false;
    }
  }

  /**
   * 查询商品列表
   * @param productIds 您的 AppGallery Connect 中配置的商品 ID 列表
   */
  public async queryProducts(context: common.UIAbilityContext, productIds: string[]): Promise<IAPProduct[]> {
    try {
      const isEnvReady = await this.checkEnvironment(context);
      if (!isEnvReady) {
        throw new Error('当前环境不支持应用内支付');
      }

      const autoRenewIds = productIds.filter((id: string) => AppConfig.getMembershipProductIds().includes(id));
      const res: IAPProduct[] = [];

      if (autoRenewIds.length > 0) {
        try {
          const param1: iap.QueryProductsParameter = {
            productType: iap.ProductType.AUTORENEWABLE,
            productIds: autoRenewIds
          };
          const result1 = await iap.queryProducts(context, param1);
          if (result1 && result1.length > 0) {
            result1.forEach((p) => {
              const productMap = JSON.parse(JSON.stringify(p)) as HwProduct;
              res.push({
                productId: productMap.productId || productMap.id || '',
                price: productMap.price || '',
                priceCurrencyCode: productMap.priceCurrencyCode || productMap.currency || '',
                productName: productMap.productName || productMap.name || productMap.displayName ||
                  productMap.localizedName || productMap.productTitle || productMap.title || '',
                productDesc: productMap.productDesc || productMap.desc || productMap.description ||
                  productMap.localizedDescription || ''
              });
            });
          }
        } catch (e) {
          console.warn('查询自动续期商品失败:', JSON.stringify(e));
        }
      }

      return res;
    } catch (err) {
      console.error('获取商品列表失败:', JSON.stringify(err));
      return [];
    }
  }

  /**
   * 唤起支付并向阿里云后端发送 jws 校验
   * @param productId 商品ID
   * @returns 成功则返回后端返回的会员类型
   */
  public async purchase(context: common.UIAbilityContext, productId: string): Promise<PurchaseResult> {
    try {
      // 1. 发起拉起收银台意图
      const param: iap.PurchaseParameter = {
        productType: this.getProductType(productId),
        productId: productId
      };

      // 华为原生支付组件将弹框
      const result = await iap.createPurchase(context, param);
      const purchaseResultMap = JSON.parse(JSON.stringify(result)) as HwPurchaseResult;
      const purchaseData = purchaseResultMap.purchaseData || purchaseResultMap.jwsPurchaseOrder || '';
      const jwsStr = this.extractSignedPurchaseData(purchaseData);
      
      if (!jwsStr) {
        return { success: false, message: '支付完成但未返回签名订单，请稍后刷新会员状态' } as PurchaseResult;
      }

      promptAction.showToast({ message: '支付完成，正在验证订单...' });

      // 2. 将 token 上报至阿里云后端进行最终核销发货
      const token = await authService.getToken();
      if (!token) {
        return { success: false, message: '请先登录账号' } as PurchaseResult;
      }

      const checkUrl = AppConfig.getBaseUrl() + '/api/iap/verifyOrder';
      
      // 因为 IAPService 是底层逻辑，这里我们简单借用 AuthService 的 HTTP 工具方法来发送 POST。但为了防耦合，使用原生 fetch 或者 axios。
      // 为简便，这里直接复用现成网络请求思路。此 demo 中假设可以直接引入 http client。
      // 因为四时清单已经封装了 authService 的底层调用，我们直接使用原生 http
      
      const verifyResult = await this.sendVerifyRequest(checkUrl, jwsStr, token, productId, purchaseData);
      if (verifyResult.success) {
        await this.finishPurchaseIfPossible(context, purchaseData);
      }
      return verifyResult;

    } catch (err) {
      console.error('购买失败:', JSON.stringify(err));
      (() => { let _p: TelemetryProperties = { 
        "code": TelemetryErrorCode.ERR_IAP_PURCHASE_FAIL, 
        "msg": String(err).substring(0, 50),
        "path": 'iap/purchase'
      }; TelemetryService.track('api_error', _p, 'other'); })();
      const bizError = err as BusinessError;
      if (bizError.code === 1001860051) {
        return await this.restoreMembershipFromHuawei(context, '检测到当前华为账号已有订阅，已尝试同步会员状态');
      }
      return { success: false, message: this.getPurchaseErrorMessage(bizError) } as PurchaseResult;
    }
  }

  public async restoreMembershipFromHuawei(
    context: common.UIAbilityContext,
    successMessage: string = '已同步华为订阅，会员状态已更新'
  ): Promise<PurchaseResult> {
    try {
      const token = await authService.getToken();
      if (!token) {
        return { success: false, message: '请先登录账号' } as PurchaseResult;
      }

      const currentPurchaseDataList = await this.queryHuaweiPurchaseDataList(
        context,
        iap.PurchaseQueryType.CURRENT_ENTITLEMENT
      );
      const unfinishedPurchaseDataList = await this.queryHuaweiPurchaseDataList(
        context,
        iap.PurchaseQueryType.UNFINISHED
      );
      const purchaseDataList = this.mergePurchaseDataList(currentPurchaseDataList, unfinishedPurchaseDataList);

      if (purchaseDataList.length === 0) {
        return { success: false, message: '没有查询到当前华为账号的有效订阅' } as PurchaseResult;
      }

      let lastMessage = '订阅同步失败，请稍后重试';
      const checkUrl = AppConfig.getBaseUrl() + '/api/iap/verifyOrder';
      for (let index = 0; index < purchaseDataList.length; index += 1) {
        const purchaseData = purchaseDataList[index];
        if (!purchaseData) {
          continue;
        }
        const jwsStr = this.extractSignedPurchaseData(purchaseData);
        if (!jwsStr) {
          lastMessage = '订阅凭证缺少签名订单，请稍后重试';
          continue;
        }
        const verifyResult = await this.sendVerifyRequest(checkUrl, jwsStr, token, undefined, purchaseData);
        if (verifyResult.success) {
          await this.finishPurchaseIfPossible(context, purchaseData);
          return {
            success: true,
            message: successMessage,
            membershipType: verifyResult.membershipType,
            membershipPlan: verifyResult.membershipPlan,
            membershipProductId: verifyResult.membershipProductId,
            membershipExpireAt: verifyResult.membershipExpireAt,
            membershipRenewAt: verifyResult.membershipRenewAt,
            pendingMembershipPlan: verifyResult.pendingMembershipPlan,
            pendingMembershipProductId: verifyResult.pendingMembershipProductId,
            pendingMembershipEffectiveAt: verifyResult.pendingMembershipEffectiveAt
          } as PurchaseResult;
        }
        lastMessage = verifyResult.message || lastMessage;
      }

      return { success: false, message: lastMessage } as PurchaseResult;
    } catch (error) {
      console.error('同步华为订阅失败:', JSON.stringify(error));
      return { success: false, message: '同步华为订阅失败，请稍后重试' } as PurchaseResult;
    }
  }

  private async queryHuaweiPurchaseDataList(
    context: common.UIAbilityContext,
    queryType: iap.PurchaseQueryType
  ): Promise<string[]> {
    try {
      const queryResult = await iap.queryPurchases(context, {
        productType: iap.ProductType.AUTORENEWABLE,
        queryType
      });
      const queryMap = JSON.parse(JSON.stringify(queryResult)) as HwQueryPurchaseResult;
      return queryMap.purchaseDataList || [];
    } catch (error) {
      console.warn('查询华为订阅列表失败:', JSON.stringify(error));
      return [];
    }
  }

  private mergePurchaseDataList(primary: string[], secondary: string[]): string[] {
    const seen: Record<string, boolean> = {};
    const result: string[] = [];
    const append = (items: string[]) => {
      items.forEach((item: string) => {
        if (item && !seen[item]) {
          seen[item] = true;
          result.push(item);
        }
      });
    };
    append(primary);
    append(secondary);
    return result;
  }

  private getPurchaseErrorMessage(error: BusinessError): string {
    switch (error.code) {
      case 1001860000:
        return '已取消购买';
      case 1001860004:
        return '操作太频繁，请稍后再试';
      case 1001860005:
        return '支付网络异常，请稍后重试';
      case 1001860050:
        return '请先登录华为账号后再购买';
      case 1001860054:
        return '当前华为账号所在地区暂不支持应用内支付';
      case 1001860056:
        return '当前华为账号暂不能完成购买';
      default:
        return error.message || '购买未完成，请稍后重试';
    }
  }

  private isCompactJws(value: string): boolean {
    return value.split('.').length === 3;
  }

  private extractSignedPurchaseData(purchaseData: string): string {
    const text = (purchaseData || '').trim();
    if (!text) {
      return '';
    }
    if (this.isCompactJws(text)) {
      return text;
    }

    try {
      const envelope = JSON.parse(text) as HwPurchaseDataEnvelope;
      const signed = envelope.jwsSubscriptionStatus || envelope.jwsPurchaseOrder ||
        envelope.jwsPurchaseData || envelope.signedPurchaseOrder || envelope.signedSubscriptionStatus || '';
      return this.isCompactJws(signed) ? signed : '';
    } catch (_) {
      return '';
    }
  }

  private decodePurchasePayload(purchaseData: string): HuaweiPurchasePayload | null {
    if (!purchaseData) {
      return null;
    }
    try {
      const signedPurchaseData = this.extractSignedPurchaseData(purchaseData);
      const segments = signedPurchaseData.split('.');
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
      return JSON.parse(textDecoder.decodeToString(payloadBytes)) as HuaweiPurchasePayload;
    } catch (error) {
      console.warn('解析华为购买凭证失败:', JSON.stringify(error));
      return null;
    }
  }

  private async finishPurchaseIfPossible(context: common.UIAbilityContext, purchaseData: string): Promise<void> {
    const payload = this.decodePurchasePayload(purchaseData);
    const purchaseToken = payload?.purchaseToken || payload?.purchaseTokenId || payload?.token ||
      payload?.subscriptionToken || payload?.purchaseId || '';
    const purchaseOrderId = payload?.purchaseOrderId || payload?.purchaseOrderID || payload?.orderId ||
      payload?.orderID || payload?.transactionId || payload?.payOrderId || '';

    if (!purchaseToken || !purchaseOrderId) {
      return;
    }

    try {
      await iap.finishPurchase(context, {
        productType: iap.ProductType.AUTORENEWABLE,
        purchaseToken,
        purchaseOrderId
      });
    } catch (error) {
      const bizError = error as BusinessError;
      if (bizError.code !== 1001860053) {
        console.warn('确认华为订单发货失败:', JSON.stringify(error));
      }
    }
  }

  private async sendVerifyRequest(url: string, jwsPurchaseOrder: string, token: string, productId?: string, purchaseData?: string): Promise<PurchaseResult> {
     const req = http.createHttp();

     try {
       interface VerifyBody {
         jwsPurchaseOrder: string;
         productId?: string;
         purchaseData?: string;
       }
       const body: VerifyBody = { jwsPurchaseOrder };
       if (productId && productId.length > 0) {
         body.productId = productId;
       }
       if (purchaseData && purchaseData.length > 0) {
         body.purchaseData = purchaseData;
       }
       const response = await req.request(url, {
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
         let result = JSON.parse(response.result as string) as ApiResponse<Record<string, Object>>;
         if (result.success) {
           // 从后端返回的数据中提取会员信息
           const data = result.data;
           let membershipType: 'basic' | 'premium' = 'premium';
           let membershipPlan: string = '';
           let membershipProductId: string = '';
           let membershipExpireAt: number = 0;
           let membershipRenewAt: number = 0;
           let pendingMembershipPlan: string = '';
           let pendingMembershipProductId: string = '';
           let pendingMembershipEffectiveAt: number = 0;
           if (data) {
             membershipType = (data['membershipType'] as string === 'premium') ? 'premium' : 'basic';
             membershipPlan = data['membershipPlan'] as string || '';
             membershipProductId = data['membershipProductId'] as string || '';
             membershipExpireAt = data['membershipExpireAt'] as number || 0;
             membershipRenewAt = data['membershipRenewAt'] as number || membershipExpireAt;
             pendingMembershipPlan = data['pendingMembershipPlan'] as string || '';
             pendingMembershipProductId = data['pendingMembershipProductId'] as string || '';
             pendingMembershipEffectiveAt = data['pendingMembershipEffectiveAt'] as number || 0;
           }

           // 更新本地用户缓存
           await authService.updateMembership(membershipType, membershipExpireAt, {
             membershipPlan,
             membershipProductId,
             membershipRenewAt,
             pendingMembershipPlan,
             pendingMembershipProductId,
             pendingMembershipEffectiveAt
           });

           return {
             success: true,
             message: result.message || '开通成功',
             membershipType: membershipType,
             membershipPlan: membershipPlan,
             membershipProductId: membershipProductId,
             membershipExpireAt: membershipExpireAt,
             membershipRenewAt: membershipRenewAt,
             pendingMembershipPlan: pendingMembershipPlan,
             pendingMembershipProductId: pendingMembershipProductId,
             pendingMembershipEffectiveAt: pendingMembershipEffectiveAt
           } as PurchaseResult;
         } else {
           return { success: false, message: result.message || '验证失败' } as PurchaseResult;
         }
       } else {
         try {
           const result = JSON.parse(response.result as string) as ApiResponse<Record<string, Object>>;
           return { success: false, message: result.message || '订单验证失败，请稍后重试' } as PurchaseResult;
         } catch (_) {
           return { success: false, message: '订单验证失败，请稍后重试' } as PurchaseResult;
         }
       }
     } catch (e) {
       console.error('请求后端验证失败', e);
       req.destroy();
       (() => { let _p: TelemetryProperties = { 
         "code": TelemetryErrorCode.ERR_IAP_VERIFY_FAIL, 
         "msg": String(e).substring(0, 50),
         "path": 'iap/verifyOrder'
       }; TelemetryService.track('api_error', _p, 'other'); })();
       return { success: false, message: '网络请求失败' } as PurchaseResult;
     }
  }
}

export const iapService = IAPService.getInstance();
