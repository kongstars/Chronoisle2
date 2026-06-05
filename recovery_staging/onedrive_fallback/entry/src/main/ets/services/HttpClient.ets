import http from '@ohos.net.http';
import { authService } from './AuthService';
import AppConfig from '../Utils/AppConfig';
import { AppErrorService } from './AppErrorService';

export interface HttpRequestOptions {
  method?: http.RequestMethod;
  header?: Record<string, string>;
  extraData?: string;
  connectTimeout?: number;
  readTimeout?: number;
  needAuth?: boolean;
}

export interface HttpSimpleOptions {
  header?: Record<string, string>;
  connectTimeout?: number;
  readTimeout?: number;
  needAuth?: boolean;
}

export interface HttpResponse<T> {
  success: boolean;
  message: string;
  data?: T;
}

interface ParsedResponse<T> {
  success?: boolean;
  message?: string;
  data?: T;
}

export class HttpClient {
  private static readonly DEFAULT_CONNECT_TIMEOUT: number = 8000;
  private static readonly DEFAULT_READ_TIMEOUT: number = 8000;

  static async get<T>(path: string, options?: HttpSimpleOptions): Promise<HttpResponse<T>> {
    const requestOptions: HttpRequestOptions = HttpClient.buildRequestOptions(
      http.RequestMethod.GET,
      undefined,
      options
    );
    return HttpClient.request<T>(path, requestOptions);
  }

  static async post<T>(path: string, data?: Object, options?: HttpSimpleOptions): Promise<HttpResponse<T>> {
    const extraData: string | undefined = data ? JSON.stringify(data) : undefined;
    const requestOptions: HttpRequestOptions = HttpClient.buildRequestOptions(
      http.RequestMethod.POST,
      extraData,
      options
    );
    return HttpClient.request<T>(path, requestOptions);
  }

  static async put<T>(path: string, data?: Object, options?: HttpSimpleOptions): Promise<HttpResponse<T>> {
    const extraData: string | undefined = data ? JSON.stringify(data) : undefined;
    const requestOptions: HttpRequestOptions = HttpClient.buildRequestOptions(
      http.RequestMethod.PUT,
      extraData,
      options
    );
    return HttpClient.request<T>(path, requestOptions);
  }

  static async delete<T>(path: string, options?: HttpSimpleOptions): Promise<HttpResponse<T>> {
    const requestOptions: HttpRequestOptions = HttpClient.buildRequestOptions(
      http.RequestMethod.DELETE,
      undefined,
      options
    );
    return HttpClient.request<T>(path, requestOptions);
  }

  static async request<T>(path: string, options?: HttpRequestOptions): Promise<HttpResponse<T>> {
    const finalOptions: HttpRequestOptions = options || {};
    const method: http.RequestMethod = finalOptions.method || http.RequestMethod.GET;
    const customHeader: Record<string, string> = finalOptions.header || {};
    const extraData: string | undefined = finalOptions.extraData;
    const connectTimeout: number = finalOptions.connectTimeout || HttpClient.DEFAULT_CONNECT_TIMEOUT;
    const readTimeout: number = finalOptions.readTimeout || HttpClient.DEFAULT_READ_TIMEOUT;
    const needAuth: boolean = finalOptions.needAuth !== false;

    let request: http.HttpRequest | null = null;

    try {
      const fullUrl: string = path.startsWith('http') ? path : `${AppConfig.getBaseUrl()}${path}`;
      const header: Record<string, string> = HttpClient.buildHeader(customHeader, needAuth);
      request = http.createHttp();

      const response = await request.request(fullUrl, {
        method: method,
        header: header,
        extraData: extraData,
        connectTimeout: connectTimeout,
        readTimeout: readTimeout
      });

      return HttpClient.handleResponse<T>(response);
    } catch (error) {
      console.error(`HTTP request failed for ${path}:`, JSON.stringify(error));
      return {
        success: false,
        message: AppErrorService.fromUnknown(error, '网络请求失败')
      };
    } finally {
      if (request) {
        try {
          request.destroy();
        } catch (destroyError) {
          console.warn('Failed to destroy http request:', JSON.stringify(destroyError));
        }
      }
    }
  }

  private static buildRequestOptions(
    method: http.RequestMethod,
    extraData?: string,
    options?: HttpSimpleOptions
  ): HttpRequestOptions {
    const source: HttpSimpleOptions = options || {};
    const requestOptions: HttpRequestOptions = {
      method: method,
      connectTimeout: source.connectTimeout || HttpClient.DEFAULT_CONNECT_TIMEOUT,
      readTimeout: source.readTimeout || HttpClient.DEFAULT_READ_TIMEOUT,
      needAuth: source.needAuth !== false
    };

    if (source.header) {
      requestOptions.header = source.header;
    }
    if (extraData !== undefined) {
      requestOptions.extraData = extraData;
    }

    return requestOptions;
  }

  private static buildHeader(
    customHeader: Record<string, string>,
    needAuth: boolean
  ): Record<string, string> {
    const header: Record<string, string> = {
      'Content-Type': 'application/json'
    };

    const headerKeys: string[] = Object.keys(customHeader);
    for (let i = 0; i < headerKeys.length; i += 1) {
      const key: string = headerKeys[i];
      header[key] = customHeader[key];
    }

    if (needAuth) {
      const token: string | null = authService.getTokenSync();
      if (token && !token.startsWith('offline-')) {
        header['Authorization'] = `Bearer ${token}`;
      }
    }

    return header;
  }

  private static handleResponse<T>(response: http.HttpResponse): HttpResponse<T> {
    const responseCode: number = response.responseCode;
    const responseBody: string = response.result as string;

    if (responseCode === 200 || responseCode === 201) {
      try {
        const parsed: ParsedResponse<T> = JSON.parse(responseBody) as ParsedResponse<T>;
        return {
          success: parsed.success === undefined ? true : !!parsed.success,
          message: parsed.message || 'Success',
          data: parsed.data
        };
      } catch (error) {
        console.warn('Failed to parse success response:', JSON.stringify(error));
        return {
          success: false,
          message: AppErrorService.fromMessage('JSON Parse Error', '服务响应异常'),
          data: undefined
        };
      }
    }

    return {
      success: false,
      message: AppErrorService.fromResponse(responseCode, responseBody)
    };
  }
}
