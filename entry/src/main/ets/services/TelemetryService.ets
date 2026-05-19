/**
 * TelemetryService - 用户行为埋点 SDK
 *
 * 设计原则：
 * - 事件驱动上报（App 进入后台、队列满 20 条时批量发送）
 * - 兜底：最长 5 分钟上报一次
 * - 付费相关事件即时单独上报，不进队列
 * - 所有上报失败均静默处理，绝不影响主流程
 *
 * 使用方式（一行代码）：
 *   TelemetryService.track('task_created', { priority: 'high' });
 *   TelemetryService.trackImmediate('membership_purchase_attempt', { plan: 'yearly' });
 *   TelemetryService.flush(); // 手动上报（App进后台时调用）
 */

import { preferences } from '@kit.ArkData';
import { http } from '@kit.NetworkKit';
import { common } from '@kit.AbilityKit';

export type TelemetryCategory = 'session' | 'task' | 'goal' | 'ai' | 'membership' | 'search' | 'voice' | 'other';
export type TelemetryProperties = Record<string, string | number | boolean>;

interface TelemetryEventData {
  eventName: string;
  eventCategory: TelemetryCategory;
  properties?: TelemetryProperties;
  platform?: string;
  appVersion?: string;
  sessionId?: string;
  createdAt?: number;
}

// ===== 常量 =====
const QUEUE_MAX_SIZE = 20;              // 队列满时触发上报
const FLUSH_INTERVAL_MS = 5 * 60 * 1000; // 兜底：5分钟上报一次
const PREFS_QUEUE_KEY = 'telemetry_queue';

// ===== 即时上报的事件名（高价值，不进队列）=====
const IMMEDIATE_EVENTS = new Set<string>([
  'membership_purchase_attempt',
  'membership_page_view',
  'session_start'
]);

class TelemetryServiceClass {
  private static instance: TelemetryServiceClass;

  private queue: TelemetryEventData[] = [];
  private sessionId: string = '';
  private token: string = '';
  private apiBase: string = '';
  private appVersion: string = '';
  private flushTimer: number = -1;
  private context: common.UIAbilityContext | undefined = undefined;

  private constructor() {}

  static getInstance(): TelemetryServiceClass {
    if (!TelemetryServiceClass.instance) {
      TelemetryServiceClass.instance = new TelemetryServiceClass();
    }
    return TelemetryServiceClass.instance;
  }

  /**
   * 初始化 SDK（在 onCreate 中调用一次）
   */
  async init(
    context: common.UIAbilityContext,
    apiBase: string,
    token: string,
    appVersion: string
  ): Promise<void> {
    this.context = context;
    this.apiBase = apiBase;
    this.token = token;
    this.appVersion = appVersion;
    this.sessionId = `${Date.now()}-${Math.random().toString(36).substring(2, 8)}`;

    // 恢复上次未上报的队列
    await this.restoreQueue();

    // 启动兜底定时上报（5分钟）
    this.startFlushTimer();
  }

  /**
   * 更新用户 Token（登录/注销时调用）
   */
  setToken(token: string): void {
    this.token = token;
    if (!token) {
      this.queue = [];
    }
  }

  /**
   * 普通埋点（进队列，批量上报）
   */
  track(
    eventName: string,
    properties?: TelemetryProperties,
    category?: TelemetryCategory
  ): void {
    if (!this.token || !this.apiBase) return;

    const inferredCategory = category || this.inferCategory(eventName);

    // 高价值事件走即时通道
    if (IMMEDIATE_EVENTS.has(eventName)) {
      this.trackImmediate(eventName, properties, inferredCategory);
      return;
    }

    const event: TelemetryEventData = {
      eventName,
      eventCategory: inferredCategory,
      properties: properties || {},
      platform: 'harmonyos',
      appVersion: this.appVersion,
      sessionId: this.sessionId,
      createdAt: Date.now()
    };

    this.queue.push(event);

    // 队列满时立即上报
    if (this.queue.length >= QUEUE_MAX_SIZE) {
      this.flush();
    } else {
      this.saveQueue(); // 异步持久化，防止 App 强杀丢失
    }
  }

  /**
   * 即时上报（高优先级事件，不进队列）
   */
  trackImmediate(
    eventName: string,
    properties?: TelemetryProperties,
    category?: TelemetryCategory
  ): void {
    if (!this.token || !this.apiBase) return;

    const event: TelemetryEventData = {
      eventName,
      eventCategory: category || this.inferCategory(eventName),
      properties: properties || {},
      platform: 'harmonyos',
      appVersion: this.appVersion,
      sessionId: this.sessionId,
      createdAt: Date.now()
    };

    this.sendSingle(event).catch(() => {
      // 失败静默处理，降级进队列等下次上报
      this.queue.push(event);
    });
  }

  /**
   * 批量刷新队列（App 进入后台时调用）
   */
  async flush(): Promise<void> {
    if (this.queue.length === 0 || !this.token || !this.apiBase) return;

    const batch = [...this.queue];
    this.queue = [];
    await this.saveQueue(); // 清空持久化

    try {
      const request = http.createHttp();
      await request.request(
        `${this.apiBase}/api/telemetry/batch`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.token}`
          },
          extraData: JSON.stringify({ events: batch, appVersion: this.appVersion }),
          connectTimeout: 8000,
          readTimeout: 8000
        }
      );
      request.destroy();
    } catch {
      // 上报失败：把队列里的事件取回（最多保留 QUEUE_MAX_SIZE 条）
      this.queue = [...batch.slice(-QUEUE_MAX_SIZE), ...this.queue].slice(-QUEUE_MAX_SIZE);
      await this.saveQueue();
    }
  }

  // ===================== 私有方法 =====================

  private async sendSingle(event: TelemetryEventData): Promise<void> {
    const request = http.createHttp();
    await request.request(
      `${this.apiBase}/api/telemetry/event`,
      {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.token}`
        },
        extraData: JSON.stringify(event),
        connectTimeout: 6000,
        readTimeout: 6000
      }
    );
    request.destroy();
  }

  private startFlushTimer(): void {
    if (this.flushTimer !== -1) clearInterval(this.flushTimer);
    this.flushTimer = setInterval(() => {
      this.flush().catch(() => {});
    }, FLUSH_INTERVAL_MS);
  }

  private inferCategory(eventName: string): TelemetryCategory {
    if (eventName.startsWith('session_')) return 'session';
    if (eventName.startsWith('task_')) return 'task';
    if (eventName.startsWith('voice_')) return 'voice';
    if (eventName.startsWith('goal_')) return 'goal';
    if (eventName.startsWith('ai_')) return 'ai';
    if (eventName.startsWith('membership_')) return 'membership';
    if (eventName.startsWith('search_')) return 'search';
    return 'other';
  }

  private async saveQueue(): Promise<void> {
    if (!this.context) return;
    try {
      const prefs = await preferences.getPreferences(this.context, 'telemetry');
      await prefs.put(PREFS_QUEUE_KEY, JSON.stringify(this.queue));
      await prefs.flush();
    } catch {
      // 持久化失败静默
    }
  }

  private async restoreQueue(): Promise<void> {
    if (!this.context) return;
    try {
      const prefs = await preferences.getPreferences(this.context, 'telemetry');
      const raw = prefs.getSync(PREFS_QUEUE_KEY, '[]') as string;
      const saved = JSON.parse(raw) as TelemetryEventData[];
      if (Array.isArray(saved) && saved.length > 0) {
        this.queue = saved.slice(-QUEUE_MAX_SIZE);
        // 有上次未发的事件，立刻尝试上报
        this.flush().catch(() => {});
      }
    } catch {
      // 恢复失败静默
    }
  }
}

// ===== 导出单例 =====
export const TelemetryService = TelemetryServiceClass.getInstance();

// ===== 已定义埋点事件清单（便于后续扩展参考）=====
/**
 * 已规划的标准埋点事件名（在对应功能模块中调用 TelemetryService.track(...)）：
 *
 * 【会话类 session】
 *   session_start              - App 打开/前台恢复（即时）
 *
 * 【任务类 task】
 *   task_created               - 创建任务成功 { priority, hasGoal, inputMethod: 'voice'|'text' }
 *   task_completed             - 任务打勾完成 { isToday }
 *   task_deleted               - 删除任务
 *   voice_input_started        - 开始语音录入
 *   voice_input_completed      - 语音录入完成 { durationSeconds, charCount }
 *   voice_input_cancelled      - 语音主动取消
 *
 * 【目标类 goal】
 *   goal_created               - 创建目标 { quarter }
 *   goal_archived              - 归档目标
 *
 * 【AI 类 ai】
 *   ai_plan_triggered          - 点击生成今日计划 { taskCount }
 *   ai_plan_adopted            - 采纳 AI 计划
 *   ai_plan_dismissed          - 取消 AI 计划
 *   ai_reschedule_triggered    - 触发智能重排 { overdueCount }
 *   ai_reschedule_adopted      - 采纳重排结果 { adoptedCount }
 *   ai_goal_breakdown_triggered - 触发目标拆解
 *   ai_goal_breakdown_adopted   - 采纳目标拆解
 *
 * 【会员类 membership（即时）】
 *   membership_page_view       - 进入会员页（即时）
 *   membership_purchase_attempt- 点击购买按钮（即时）{ plan: 'monthly'|'yearly' }
 *
 * 【搜索类 search】
 *   search_performed           - 执行搜索 { resultCount }
 */
