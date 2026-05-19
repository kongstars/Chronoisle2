import http from '@ohos.net.http';
import AppConfig from '../Utils/AppConfig';
import { authService } from './AuthService';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('UsageService');

interface UsageDetail {
  duration?: number;
  feature?: string;
  action?: 'trigger' | 'adopt';
}

interface UsageReportBody {
  type: string;
  amount: number;
  detail: UsageDetail;
}

/**
 * 用量上报服务
 * 负责将语音时长等使用量数据上报到服务器
 */
export class UsageService {
  /**
   * 上报语音使用时长
   * @param durationSeconds 语音识别时长（秒）
   */
  static async reportVoiceUsage(durationSeconds: number): Promise<void> {
    if (durationSeconds <= 0) {
      return;
    }

    try {
      const token = await authService.getToken();
      if (!token) {
        logger.warn('未登录，跳过语音用量上报');
        return;
      }

      const httpRequest = http.createHttp();
      const headerObj: Record<string, string> = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      };

      const reportBody: UsageReportBody = {
        type: 'voice',
        amount: Math.round(durationSeconds),
        detail: {
          duration: Math.round(durationSeconds)
        } as UsageDetail
      };

      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/usage/report`,
        {
          method: http.RequestMethod.POST,
          header: headerObj,
          extraData: JSON.stringify(reportBody),
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );

      if (response.responseCode === 200) {
        logger.debug(`语音用量上报成功: ${durationSeconds}秒`);
      } else {
        logger.warn(`语音用量上报失败, HTTP ${response.responseCode}`);
      }
      httpRequest.destroy();
    } catch (error) {
      logger.error('语音用量上报异常', error as Object);
    }
  }

  /**
   * 上报 AI 高阶功能数据埋点
   * @param feature 模块标识，例如 'goal_breakdown', 'today_plan', 'reschedule'
   * @param action 行为分类，'trigger'（触发生成）或 'adopt'（采纳并保存）
   */
  static async reportAIFeatureUsage(feature: string, action: 'trigger' | 'adopt'): Promise<void> {
    try {
      const token = await authService.getToken();
      if (!token) {
        return;
      }

      const httpRequest = http.createHttp();
      const headerObj: Record<string, string> = {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      };

      const reportBody: Record<string, Object> = {};
      reportBody['type'] = 'ai_feature';
      reportBody['amount'] = 1;
      const detailObj: Record<string, string> = {};
      detailObj['feature'] = feature;
      detailObj['action'] = action;
      reportBody['detail'] = detailObj;

      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/usage/report`,
        {
          method: http.RequestMethod.POST,
          header: headerObj,
          extraData: JSON.stringify(reportBody),
          connectTimeout: 5000,
          readTimeout: 5000
        }
      );

      if (response.responseCode === 200) {
        logger.debug(`AI ${feature} ${action} 上报`);
      }
      httpRequest.destroy();
    } catch (error) {
      logger.error('AI 埋点异常', error as Object);
    }
  }
}

