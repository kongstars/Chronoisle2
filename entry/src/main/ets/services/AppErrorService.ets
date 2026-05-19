interface ErrorEnvelope {
  message?: string;
  msg?: string;
  error?: string | ErrorEnvelope;
}

interface ErrorLike {
  message?: string;
  code?: number | string;
  name?: string;
}

export class AppErrorService {
  private static readonly NETWORK_ERROR_CODE: number = 900;
  private static readonly PARSE_ERROR_CODE: number = 902;
  private static readonly DEFAULT_ERROR_CODE: number = 904;

  static fromResponse(statusCode: number, responseBody?: string, fallback: string = '操作失败，请稍后重试'): string {
    const parsedMessage = AppErrorService.extractServerMessage(responseBody || '');
    if (parsedMessage.length > 0 && !AppErrorService.isTechnicalMessage(parsedMessage)) {
      return AppErrorService.withCode(statusCode, parsedMessage);
    }
    return AppErrorService.fromStatusCode(statusCode, fallback);
  }

  static fromUnknown(error: Error | Object | string | null | undefined, fallback: string = '操作失败，请稍后重试'): string {
    if (error === null || error === undefined) {
      return AppErrorService.withCode(AppErrorService.DEFAULT_ERROR_CODE, fallback);
    }

    if (typeof error === 'string') {
      return AppErrorService.fromMessage(error, fallback);
    }

    const like = error as ErrorLike;
    if (like.message && like.message.length > 0) {
      return AppErrorService.fromMessage(like.message, fallback);
    }

    if (like.code !== undefined) {
      const codeText = `${like.code}`;
      return `${codeText}: ${fallback}`;
    }

    return AppErrorService.fromMessage(JSON.stringify(error), fallback);
  }

  static fromMessage(message: string, fallback: string = '操作失败，请稍后重试'): string {
    const raw = (message || '').trim();
    if (raw.length === 0) {
      return AppErrorService.withCode(AppErrorService.DEFAULT_ERROR_CODE, fallback);
    }

    const statusCode = AppErrorService.extractHttpStatus(raw);
    if (statusCode > 0) {
      return AppErrorService.fromStatusCode(statusCode, fallback);
    }

    if (AppErrorService.isTimeoutMessage(raw)) {
      return AppErrorService.fromStatusCode(504, fallback);
    }

    if (AppErrorService.isNetworkMessage(raw)) {
      return AppErrorService.withCode(AppErrorService.NETWORK_ERROR_CODE, '网络连接失败');
    }

    const cleaned = AppErrorService.compact(AppErrorService.stripHtml(raw));
    if (cleaned.length === 0) {
      return AppErrorService.withCode(AppErrorService.DEFAULT_ERROR_CODE, fallback);
    }

    if (AppErrorService.isTechnicalMessage(cleaned)) {
      if (cleaned.indexOf('JSON') >= 0 || cleaned.indexOf('Parse') >= 0 || cleaned.indexOf('Unexpected token') >= 0) {
        return AppErrorService.withCode(AppErrorService.PARSE_ERROR_CODE, '服务响应异常');
      }
      return AppErrorService.withCode(AppErrorService.DEFAULT_ERROR_CODE, fallback);
    }

    if (cleaned.length > 80) {
      return AppErrorService.withCode(AppErrorService.DEFAULT_ERROR_CODE, fallback);
    }

    return cleaned;
  }

  static isTechnicalMessage(message: string): boolean {
    const raw = message || '';
    const lower = raw.toLowerCase();
    return raw.indexOf('<html') >= 0 ||
      raw.indexOf('</') >= 0 ||
      lower.indexOf('gateway time-out') >= 0 ||
      lower.indexOf('gateway timeout') >= 0 ||
      lower.indexOf('nginx') >= 0 ||
      lower.indexOf('http ') >= 0 ||
      lower.indexOf('network error') >= 0 ||
      lower.indexOf('parse error') >= 0 ||
      lower.indexOf('unexpected token') >= 0 ||
      lower.indexOf('syntaxerror') >= 0 ||
      lower.indexOf('typeerror') >= 0 ||
      lower.indexOf('referenceerror') >= 0 ||
      lower.indexOf('stack') >= 0 ||
      lower.indexOf('trace') >= 0 ||
      lower.indexOf('econn') >= 0 ||
      lower.indexOf('etimedout') >= 0 ||
      lower.indexOf('failed to fetch') >= 0 ||
      lower.indexOf('xmlhttprequest') >= 0;
  }

  private static fromStatusCode(statusCode: number, fallback: string): string {
    if (statusCode === 0) {
      return AppErrorService.withCode(AppErrorService.NETWORK_ERROR_CODE, '网络连接失败');
    }
    if (statusCode === 400) {
      return '400: 请求参数有误';
    }
    if (statusCode === 401) {
      return '401: 登录已过期，请重新登录';
    }
    if (statusCode === 403) {
      return '403: 当前账号无权执行此操作';
    }
    if (statusCode === 404) {
      return '404: 服务不存在或已下线';
    }
    if (statusCode === 408) {
      return '408: 请求超时';
    }
    if (statusCode === 409) {
      return '409: 数据状态冲突，请刷新后重试';
    }
    if (statusCode === 422) {
      return '422: 信息不完整，请检查后重试';
    }
    if (statusCode === 429) {
      return '429: 请求过于频繁，请稍后再试';
    }
    if (statusCode === 500) {
      return '500: 系统繁忙，请稍后重试';
    }
    if (statusCode === 502) {
      return '502: 网关异常，请稍后重试';
    }
    if (statusCode === 503) {
      return '503: 服务暂不可用';
    }
    if (statusCode === 504) {
      return '504: 系统超时';
    }
    if (statusCode >= 500) {
      return `${statusCode}: 系统繁忙，请稍后重试`;
    }
    if (statusCode >= 400) {
      return `${statusCode}: 请求处理失败`;
    }
    return AppErrorService.withCode(AppErrorService.DEFAULT_ERROR_CODE, fallback);
  }

  private static withCode(statusCode: number, message: string): string {
    return `${statusCode}: ${message}`;
  }

  private static extractServerMessage(body: string): string {
    const raw = (body || '').trim();
    if (raw.length === 0 || raw.indexOf('<') >= 0) {
      return '';
    }

    try {
      const parsed = JSON.parse(raw) as ErrorEnvelope;
      if (parsed.message && parsed.message.length > 0) {
        return parsed.message;
      }
      if (parsed.msg && parsed.msg.length > 0) {
        return parsed.msg;
      }
      if (typeof parsed.error === 'string') {
        return parsed.error;
      }
      if (parsed.error && parsed.error.message) {
        return parsed.error.message;
      }
    } catch (_error) {
      return '';
    }
    return '';
  }

  private static extractHttpStatus(message: string): number {
    const raw = message || '';
    const httpMatch = raw.match(/(?:HTTP|http|status|code|状态码|错误码)[^0-9]{0,12}([1-5][0-9][0-9])/);
    if (httpMatch && httpMatch.length > 1) {
      return Number(httpMatch[1]);
    }

    const titleMatch = raw.match(/([1-5][0-9][0-9])\s+(?:Gateway|Bad Gateway|Service|Internal|Not Found|Unauthorized|Forbidden|Too Many)/i);
    if (titleMatch && titleMatch.length > 1) {
      return Number(titleMatch[1]);
    }

    const plainMatch = raw.match(/\b([1-5][0-9][0-9])\b/);
    if (plainMatch && plainMatch.length > 1 && AppErrorService.isTechnicalMessage(raw)) {
      return Number(plainMatch[1]);
    }
    return 0;
  }

  private static isTimeoutMessage(message: string): boolean {
    const lower = message.toLowerCase();
    return lower.indexOf('timeout') >= 0 ||
      lower.indexOf('time-out') >= 0 ||
      message.indexOf('超时') >= 0 ||
      lower.indexOf('timed out') >= 0;
  }

  private static isNetworkMessage(message: string): boolean {
    const lower = message.toLowerCase();
    return lower.indexOf('network') >= 0 ||
      lower.indexOf('connect') >= 0 ||
      lower.indexOf('econn') >= 0 ||
      message.indexOf('网络') >= 0 ||
      message.indexOf('连接') >= 0;
  }

  private static stripHtml(message: string): string {
    return message.replace(/<[^>]*>/g, ' ');
  }

  private static compact(message: string): string {
    return message.replace(/\s+/g, ' ').trim();
  }
}
