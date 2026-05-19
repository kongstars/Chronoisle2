import hilog from '@ohos.hilog';
import AppConfig from './AppConfig';

const LOG_DOMAIN: number = 0xCB01;

/**
 * 统一日志工具
 *
 * 设计原则：
 * - debug / info：仅在测试环境（非 release）通过 hilog 输出，避免线上业务日志噪音。
 * - warn / error：所有环境都输出，方便线上排查。
 * - 业务日志一律通过 Logger 调用，不再使用 console.log 散落在 UI 与服务里。
 *
 * 使用方式：
 *   const logger = new Logger('GoalDetailPage');
 *   logger.debug('addKR created', { id: kr.id });
 *   logger.error('updateGoal failed', err);
 */
export class Logger {
  private readonly tag: string;

  constructor(tag: string) {
    this.tag = tag;
  }

  static create(tag: string): Logger {
    return new Logger(tag);
  }

  debug(message: string, ...args: Object[]): void {
    if (Logger.shouldEmitDebug()) {
      hilog.debug(LOG_DOMAIN, this.tag, '%{public}s', Logger.format(message, args));
    }
  }

  info(message: string, ...args: Object[]): void {
    if (Logger.shouldEmitDebug()) {
      hilog.info(LOG_DOMAIN, this.tag, '%{public}s', Logger.format(message, args));
    }
  }

  warn(message: string, ...args: Object[]): void {
    hilog.warn(LOG_DOMAIN, this.tag, '%{public}s', Logger.format(message, args));
  }

  error(message: string, ...args: Object[]): void {
    hilog.error(LOG_DOMAIN, this.tag, '%{public}s', Logger.format(message, args));
  }

  private static shouldEmitDebug(): boolean {
    // release 构建关闭 debug/info，仅保留 warn/error
    return AppConfig.isTestEnvironment();
  }

  private static format(message: string, args: Object[]): string {
    if (!args || args.length === 0) {
      return message;
    }
    const parts: string[] = [message];
    for (let i = 0; i < args.length; i += 1) {
      parts.push(Logger.stringify(args[i]));
    }
    return parts.join(' ');
  }

  private static stringify(value: Object | undefined | null): string {
    if (value === null) return 'null';
    if (value === undefined) return 'undefined';
    if (typeof value === 'string') return value;
    if (typeof value === 'number' || typeof value === 'boolean') return String(value);
    try {
      return JSON.stringify(value);
    } catch (e) {
      return '[unserializable]';
    }
  }
}
