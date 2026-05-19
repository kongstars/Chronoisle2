
import http from '@ohos.net.http';
import AppConfig from '../Utils/AppConfig';
import { AppErrorService } from './AppErrorService';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('TokenService');

/**
 * 语音Token服务
 * 从后端服务器获取阿里云语音服务的动态Token
 * 
 * 安全说明：AccessKey不应存储在客户端，应通过服务端中转
 */

interface ApiResponse<T> {
  success: boolean;
  message: string;
  data?: T;
}
export interface TokenResponse {
  token: string;
  appKey: string;
  expiresIn: number;
}
interface TokenCache {
  token: string;
  appKey: string;
  expiresAt: number;
}
interface CacheStatus {
  hasCache: boolean;
  expiresIn: number | null;
}

interface HealthStatus {
  status: string;
}

export class TokenService {
  // Token缓存
  private static tokenCache: TokenCache | null = null;
  // 配置服务器地址 (为兼容保留，但内部不再使用硬编码变量)
  static setServerUrl(url: string): void {
    logger.debug(`Token服务地址使用统一配置，传入的 ${url} 被忽略`);
  }
  
  // 获取服务器地址
  static getServerUrl(): string {
    return AppConfig.getBaseUrl();
  }
  
  /**
   * 从服务器获取语音服务Token
   * @returns Promise包含token和appKey
   */
  static async getSpeechToken(): Promise<TokenResponse> {
    // 检查缓存是否有效（提前5分钟过期），并且必须保证缓存中确实有合法的appKey！
    const now = Date.now();
    if (TokenService.tokenCache && TokenService.tokenCache.expiresAt > now + 300000 && TokenService.tokenCache.appKey) {
      logger.debug('使用缓存的Token');
      return {
        token: TokenService.tokenCache.token,
        appKey: TokenService.tokenCache.appKey
      } as TokenResponse;
    }
    TokenService.tokenCache = null; // 清空无效的旧缓存，准备重新向服务器请求
    
    try {
      logger.debug(`请求Token: ${AppConfig.getBaseUrl()}/api/speech/token`);
      
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/api/speech/token`,
        {
          method: http.RequestMethod.GET,
          header: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          connectTimeout: 10000, // 10秒连接超时
          readTimeout: 10000     // 10秒读取超时
        }
      );
      // 检查响应状态
      if (response.responseCode === 200) {
        const result: ApiResponse<TokenResponse> = JSON.parse(response.result as string);
        if (result.success && result.data) {
          const token = result.data.token;
          const appKey = result.data.appKey;
          const expiresIn = result.data.expiresIn;
          
          if (!appKey || appKey === 'undefined' || appKey.trim() === '') {
            throw new Error(`服务器未配置或未正确返回 AppKey，请检查服务端的对应环境变量`);
          }

          // 更新缓存
          TokenService.tokenCache = {
            token,
            appKey,
            expiresAt: now + (expiresIn * 1000)
          } as TokenCache;
          logger.debug(`Token获取成功，有效期: ${expiresIn}秒`);
          return { token, appKey } as TokenResponse;
        } else {
          throw new Error(`服务器返回错误: ${result.message || '未知错误'}`);
        }
      } else {
        throw new Error(AppErrorService.fromResponse(response.responseCode, String(response.result)));
      }
    } catch (error) {
      logger.error('获取语音Token失败', error as Object);
      // 如果缓存还有效，尝试使用缓存
      if (TokenService.tokenCache && TokenService.tokenCache.expiresAt > now) {
        logger.warn('网络请求失败，尝试使用缓存Token');
        return {
          token: TokenService.tokenCache.token,
          appKey: TokenService.tokenCache.appKey
        } as TokenResponse;
      }
      
      throw new Error(AppErrorService.fromUnknown(error, '语音服务 Token 获取失败'));
    }
  }
  
  /**
   * 清除Token缓存
   */
  static clearCache(): void {
    TokenService.tokenCache = null;
    logger.debug('Token缓存已清除');
  }
  
  /**
   * 检查Token缓存状态
   * @returns 缓存状态信息
   */
  static getCacheStatus(): CacheStatus {
    if (!TokenService.tokenCache) {
      return { hasCache: false, expiresIn: null } as CacheStatus;
    }
    
    const now = Date.now();
    const expiresIn = Math.max(0, Math.floor((TokenService.tokenCache.expiresAt - now) / 1000));
    
    return {
      hasCache: expiresIn > 0,
      expiresIn: expiresIn > 0 ? expiresIn : null
    } as CacheStatus;
  }
  
  /**
   * 测试服务器连接
   */
  static async testConnection(): Promise<boolean> {
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}/health`,
        {
          method: http.RequestMethod.GET,
          connectTimeout: 5000,
          readTimeout: 5000
        }
      );
      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as HealthStatus;
        return result.status === 'ok';
      }
      return false;
    } catch (error) {
      logger.error('服务器连接测试失败:', error as Object);
      return false;
    }
  }
  
  /**
   * 预加载Token（在应用启动时调用）
   */
  static async preloadToken(): Promise<boolean> {
    try {
      await TokenService.getSpeechToken();
      return true;
    } catch (error) {
      logger.warn('Token预加载失败:', error as Object);
      return false;
    }
  }
}

// 默认导出单例
