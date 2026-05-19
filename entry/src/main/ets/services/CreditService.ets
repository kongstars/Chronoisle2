import http from '@ohos.net.http';
import AppConfig from '../Utils/AppConfig';
import { type ApiResponse, authService } from './AuthService';
import { trackApiError, trackNetworkError } from './TelemetryHelper';
import { TelemetryErrorCode } from '../models/TelemetryErrorCode';
import { type TelemetryProperties } from './TelemetryService';
import { AppErrorService } from './AppErrorService';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('CreditService');

export type CreditTransactionType = 'earn' | 'spend';
export type CreditTransactionFilter = 'all' | CreditTransactionType;

export interface CreditTransactionItem {
  _id?: string;
  userId: string;
  type: CreditTransactionType;
  amount: number;
  source?: string;
  feature?: string;
  description: string;
  balanceAfter: number;
  createdAt: number;
}

export interface CreditTransactionsPagination {
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
}

export interface CreditTransactionsData {
  transactions: CreditTransactionItem[];
  totalEarned: number;
  totalSpent: number;
  pagination: CreditTransactionsPagination;
}

interface CreditTransactionsApiTelemetryProps {
  page: number;
  pageSize: number;
  hasType: boolean;
}

class CreditService {
  public async getTransactions(
    page: number = 1,
    pageSize: number = 20,
    type: CreditTransactionType | undefined = undefined
  ): Promise<ApiResponse<CreditTransactionsData>> {
    let httpRequest = http.createHttp();
    const requestPath: string = 'credit/transactions';
    try {
      const token = await authService.getToken();
      if (!token) {
        return {
          success: false,
          message: '请先登录后查看积分流水'
        };
      }

      let requestUrl = `${AppConfig.getBaseUrl()}/api/credit/transactions?page=${page}&pageSize=${pageSize}`;
      if (type) {
        requestUrl += `&type=${type}`;
      }

      const response = await httpRequest.request(requestUrl, {
        method: http.RequestMethod.GET,
        header: {
          'Authorization': `Bearer ${token}`
        },
        connectTimeout: 8000,
        readTimeout: 8000
      });

      if (response.responseCode !== 200) {
        trackNetworkError(requestPath, `HTTP ${response.responseCode}`, response.responseCode);
        return {
          success: false,
          message: AppErrorService.fromResponse(response.responseCode, String(response.result))
        };
      }

      const result = JSON.parse(response.result as string) as ApiResponse<CreditTransactionsData>;
      if (!result.success) {
        const telemetryProps: TelemetryProperties = {
          "page": page,
          "pageSize": pageSize,
          "hasType": !!type
        };
        trackApiError(
          TelemetryErrorCode.ERR_HTTP_EXCEPTION,
          result.message || 'credit transactions business failure',
          requestPath,
          telemetryProps
        );
      }
      return result;
    } catch (error) {
      logger.error('CreditService getTransactions failed', error as Object);
      trackNetworkError(requestPath, error);
      return {
        success: false,
        message: AppErrorService.fromUnknown(error, '获取积分流水失败')
      };
    } finally {
      httpRequest.destroy();
    }
  }
}

export const creditService = new CreditService();
