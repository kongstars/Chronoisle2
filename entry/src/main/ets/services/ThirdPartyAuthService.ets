import { TelemetryProperties } from '../services/TelemetryService';
import http from '@ohos.net.http';
import { UIContext } from '@ohos.arkui.UIContext';
import AppConfig from '../Utils/AppConfig';
import { TelemetryService } from './TelemetryService';
import { TelemetryErrorCode } from '../models/TelemetryErrorCode';
import { AppErrorService } from './AppErrorService';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('ThirdPartyAuthService');

interface OAuthUrlResponse {
  success: boolean;
  authUrl: string;
  platform: string;
  message?: string;
}
interface UserInfo {
  userId?: string;
  nickname?: string;
  avatar?: string;
}
interface VerifyTokenResponse {
  success: boolean;
  token?: string;
  user?: UserInfo;
  message?: string;
}
export interface OAuthResult {
  success: boolean;
  token?: string;
  userId?: string;
  nickname?: string;
  avatar?: string;
  message?: string;
}

export class ThirdPartyAuthService {
  private static readonly BASE_PATH = '/api/auth/oauth';
  
  /**
   * 启动第三方登录
   *
   * @param platform 第三方平台
   * @param uiContext 调用方传入的 UIContext，用于跳转 WebView 授权页
   */
  static async startOAuthLogin(platform: 'wechat' | 'qq', uiContext: UIContext): Promise<OAuthResult> {
    try {
      // 1. 获取授权URL
      const authUrlResponse = await ThirdPartyAuthService.getAuthUrl(platform);
      if (!authUrlResponse.success || !authUrlResponse.authUrl) {
        return {
          success: false,
          message: authUrlResponse.message || '获取登录地址失败'
        };
      }
      
      // 2. 打开WebView进行授权
      const result = await ThirdPartyAuthService.openWebViewForAuth(authUrlResponse.authUrl, platform, uiContext);
      return result;
      
    } catch (error) {
      logger.error('${platform}登录失败:', error as Object);
      return {
        success: false,
        message: AppErrorService.fromUnknown(error, '第三方登录失败')
      };
    }
  }
  
  /**
   * 获取授权URL
   */
  private static async getAuthUrl(platform: string): Promise<OAuthUrlResponse> {
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}${ThirdPartyAuthService.BASE_PATH}/url?platform=${platform}`,
        {
          method: http.RequestMethod.GET,
          header: {
            'Accept': 'application/json'
          },
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );
      
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as OAuthUrlResponse;
      } else {
        return {
          success: false,
          authUrl: '',
          platform,
          message: AppErrorService.fromResponse(response.responseCode, String(response.result))
        };
      }
    } catch (error) {
      (() => { let _p: TelemetryProperties = { 
        "code": TelemetryErrorCode.ERR_NET_TIMEOUT, 
        "msg": String(error).substring(0, 50),
        "path": 'oauth/url'
      }; TelemetryService.track('api_error', _p, 'other'); })();
      return {
        success: false,
        authUrl: '',
        platform,
        message: AppErrorService.fromUnknown(error, '获取登录地址失败')
      };
    }
  }
  
  /**
   * 打开WebView进行授权
   */
  private static async openWebViewForAuth(authUrl: string, platform: string, uiContext: UIContext): Promise<OAuthResult> {
    return new Promise((resolve) => {
      // 创建WebView页面进行授权
      uiContext.getRouter().pushUrl({
        url: 'pages/ThirdPartyLoginPage',
        params: {
          authUrl,
          platform,
          onSuccess: (result: OAuthResult) => {
            resolve(result);
          },
          onError: (error: string) => {
            resolve({
              success: false,
              message: error
            });
          }
        }
      });
    });
  }
  
  /**
   * 验证Token
   */
  static async verifyToken(token: string): Promise<OAuthResult> {
    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(
        `${AppConfig.getBaseUrl()}${ThirdPartyAuthService.BASE_PATH}/verify`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          },
          extraData: JSON.stringify({ token }),
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );
      if (response.responseCode === 200) {
        const result: VerifyTokenResponse = JSON.parse(response.result as string);
        return {
          success: result.success,
          token: result.token,
          userId: result.user?.userId,
          nickname: result.user?.nickname,
          avatar: result.user?.avatar,
          message: result.message
        };
      } else {
        return {
          success: false,
          message: AppErrorService.fromResponse(response.responseCode, String(response.result))
        };
      }
    } catch (error) {
      (() => { let _p: TelemetryProperties = { 
        "code": TelemetryErrorCode.ERR_NET_TIMEOUT, 
        "msg": String(error).substring(0, 50),
        "path": 'oauth/verify'
      }; TelemetryService.track('api_error', _p, 'other'); })();
      return {
        success: false,
        message: AppErrorService.fromUnknown(error, '第三方登录验证失败')
      };
    }
  }
  
  /**
   * 处理自定义URL Scheme回调
   */
  static handleUrlCallback(url: string): OAuthResult | null {
    try {
      // 手动解析URL，因为ArkTS可能不支持URL类
      const urlParts = url.split('://');
      if (urlParts.length < 2) {
        return null;
      }
      
      const urlBody = urlParts.slice(1).join('://');
      const hostAndRest = urlBody.split('/');
      const hostPart = hostAndRest[0] || '';
      const fragmentString = urlBody.includes('#') ? (urlBody.split('#')[1] || '') : '';
      const queryString = urlBody.includes('?') ? (urlBody.split('?')[1] || '').split('#')[0] : '';
      const paramString = fragmentString || queryString;
      const host = hostPart.split('?')[0].split('#')[0];
      const params: Record<string, string> = {};
      paramString.split('&').forEach(param => {
        const parts = param.split('=');
        const key = parts[0];
        const value = parts[1];
        if (key && value) {
          params[key] = decodeURIComponent(value);
        }
      });
      
      if (host === 'oauth_success') {
        const token = params['token'] || '';
        const userId = params['userId'] || '';
        const nickname = params['nickname'] || '';
        const avatar = params['avatar'] || '';
        
        return {
          success: true,
          token,
          userId,
          nickname,
          avatar,
          message: '登录成功'
        };
      } else if (host === 'oauth_error') {
        const message = params['message'] || '登录失败';
        return {
          success: false,
          message
        };
      }
      
      return null;
    } catch (error) {
      logger.error('处理URL回调失败:', error as Object);
      return null;
    }
  }
}

// 默认导出单例
