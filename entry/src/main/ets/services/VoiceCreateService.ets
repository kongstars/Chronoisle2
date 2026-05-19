import http from '@ohos.net.http';
import AppConfig from '../Utils/AppConfig';
import { authService } from './AuthService';
import { trackAIError, trackAuthError, trackNetworkError } from './TelemetryHelper';
import { TelemetryErrorCode } from '../models/TelemetryErrorCode';
import { AppErrorService } from './AppErrorService';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('VoiceCreateService');

export interface VoiceCreateTaskData {
  title?: string;
  description?: string;
  priority?: string;
  dueDate?: string;
  goalId?: string;
  krId?: string;
  estimatedHours?: number;
}

export interface VoiceCreateFocusData {
  focusSubject?: string;
  duration?: number;
  matchedTaskId?: string;
  matchedTaskTitle?: string;
}

export interface VoiceCreateGoalData {
  intentText?: string;
}

export type VoiceReminderEventType = 'periodic' | 'habit' | 'milestone' | 'counter' | 'countdown';
export type VoicePeriodicMode = 'daily' | 'weekly' | 'monthly' | 'interval';
export type VoiceHabitMode = 'daily' | 'weekly' | 'monthly';
export type VoiceCounterMode = 'interval' | 'date';
export type VoiceCounterUnit = 'day' | 'month' | 'year';

export interface VoiceCreateReminderData {
  title?: string;
  rawText?: string;
  eventType?: VoiceReminderEventType;
  periodicMode?: VoicePeriodicMode;
  habitMode?: VoiceHabitMode;
  counterMode?: VoiceCounterMode;
  startDate?: string;
  endDate?: string;
  hasEndDate?: boolean;
  targetDate?: string;
  hour?: number;
  minute?: number;
  weekday?: number;
  dayOfMonth?: number;
  intervalDays?: number;
  timesPerPeriod?: number;
  leadDays?: number;
  offsetValue?: number;
  offsetUnit?: VoiceCounterUnit;
}

export interface VoiceCreateParsed {
  // task fields
  title?: string;
  description?: string;
  priority?: string;
  dueDate?: string;
  goalId?: string;
  krId?: string;
  estimatedHours?: number;
  // focus fields
  focusSubject?: string;
  duration?: number;
  matchedTaskId?: string;
  matchedTaskTitle?: string;
  // goal fields
  intentText?: string;
  // reminder fields
  rawText?: string;
  eventType?: VoiceReminderEventType;
  periodicMode?: VoicePeriodicMode;
  habitMode?: VoiceHabitMode;
  counterMode?: VoiceCounterMode;
  startDate?: string;
  endDate?: string;
  hasEndDate?: boolean;
  targetDate?: string;
  hour?: number;
  minute?: number;
  weekday?: number;
  dayOfMonth?: number;
  intervalDays?: number;
  timesPerPeriod?: number;
  leadDays?: number;
  offsetValue?: number;
  offsetUnit?: VoiceCounterUnit;
}

export interface VoiceCreateResult {
  success: boolean;
  message?: string;
  intent?: string;
  confidence?: number;
  parsed?: VoiceCreateParsed;
}

interface VoiceCreateResponseData {
  intent?: string;
  confidence?: number;
  parsed?: VoiceCreateParsed;
  error?: string;
}

interface VoiceCreateResponse {
  success: boolean;
  message?: string;
  data?: VoiceCreateResponseData;
}

export class VoiceCreateService {
  /**
   * 调用服务端 /api/voice-create/analyze 进行意图分流和结构化解析
   */
  public static async analyze(text: string): Promise<VoiceCreateResult> {
    const requestPath: string = 'voice-create/analyze';
    try {
      const token = await authService.getToken();
      if (!token || token.startsWith('offline-')) {
        return { success: false, message: '请先登录后使用语音创建' };
      }

      const httpRequest = http.createHttp();
      interface AnalyzeBody { text: string; }
      const body: AnalyzeBody = { text };

      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/voice-create/analyze`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`
          },
          extraData: JSON.stringify(body),
          connectTimeout: 10000,
          readTimeout: 60000
        }
      );
      httpRequest.destroy();

      if (response.responseCode === 200) {
        let result: VoiceCreateResponse;
        try {
          result = JSON.parse(response.result as string) as VoiceCreateResponse;
        } catch (error) {
          trackAIError(requestPath, error, TelemetryErrorCode.ERR_AI_JSON_PARSE_FAIL);
          return {
            success: false,
            message: '语音理解失败'
          };
        }

        if (result.success && result.data) {
          return {
            success: true,
            intent: result.data.intent || 'unknown',
            confidence: result.data.confidence || 0,
            parsed: result.data.parsed
          };
        }
        trackAIError(
          requestPath,
          result.message || result.data?.error || 'voice analyze business failure',
          TelemetryErrorCode.ERR_AI_INVALID_STRUCTURE
        );
        return {
          success: false,
          message: result.message || '语音理解失败'
        };
      }

      if (response.responseCode === 401) {
        trackAuthError(requestPath, 'voice analyze unauthorized');
        return { success: false, message: '登录已过期，请重新登录' };
      }

      trackNetworkError(requestPath, `HTTP ${response.responseCode}`, response.responseCode);
      return { success: false, message: AppErrorService.fromResponse(response.responseCode, String(response.result)) };
    } catch (e) {
      logger.error('[VoiceCreateService] analyze failed', e as Object);
      trackNetworkError(requestPath, e);
      return { success: false, message: AppErrorService.fromUnknown(e, '网络异常，请检查网络后重试') };
    }
  }
}
