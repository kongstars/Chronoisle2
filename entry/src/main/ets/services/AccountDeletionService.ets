import { HttpClient } from './HttpClient';
import { authService } from './AuthService';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('AccountDeletionService');

/**
 * 申请注销结果。
 *
 * 服务端实现策略（待 D 阶段确认）：
 * - 立即调用 POST /api/auth/account/delete，将账号置为 pending_deletion 状态。
 * - 同步停止订阅自动续费、停发月度积分。
 * - 7-15 天宽限期内可登录撤销注销；超时后清理或匿名化业务数据。
 *
 * 客户端职责：
 * - 二次确认弹窗。
 * - 调用接口、提示用户。
 * - 成功后清理本地登录态，并跳转登录页。
 */
export interface AccountDeletionResult {
  success: boolean;
  message: string;
  /** 服务端返回的预计完成清理日期（ISO 字符串），用于 UI 展示。 */
  scheduledFinalizeAt?: string;
}

interface DeletionResponse {
  scheduledFinalizeAt?: string;
}

interface DeletionRequestPayload {
  reason?: string;
  confirmation: string;
}

export class AccountDeletionService {
  private static readonly CONFIRMATION_TOKEN: string = 'CONFIRM_DELETE_ACCOUNT';

  /**
   * 提交注销申请。
   *
   * @param reason 用户填写的原因，可选。
   */
  static async submitDeletion(reason: string): Promise<AccountDeletionResult> {
    const token = await authService.getToken();
    if (!token) {
      return { success: false, message: '请先登录后再操作' };
    }
    if (token.startsWith('offline-')) {
      return { success: false, message: '当前为离线模式，无法注销账号，请先恢复联网登录' };
    }

    try {
      const payload: DeletionRequestPayload = {
        reason: reason && reason.trim().length > 0 ? reason.trim() : undefined,
        confirmation: AccountDeletionService.CONFIRMATION_TOKEN
      };

      const response = await HttpClient.post<DeletionResponse>(
        '/api/auth/account/delete',
        payload,
        { connectTimeout: 10000, readTimeout: 10000 }
      );

      if (!response.success) {
        return {
          success: false,
          message: response.message || '注销申请提交失败，请稍后重试'
        };
      }

      // 服务端确认后清理本地登录态，避免缓存继续显示已注销账号
      await authService.logout();

      return {
        success: true,
        message: '注销申请已提交',
        scheduledFinalizeAt: response.data?.scheduledFinalizeAt
      };
    } catch (error) {
      logger.error('submitDeletion failed', error as Object);
      return {
        success: false,
        message: '网络异常，请检查网络后重试'
      };
    }
  }
}
