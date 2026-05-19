/**
 * AIFillState — 语音/AI 创建场景的字段填入状态管理
 *
 * 设计目标：
 * 1. 统一管理"哪些字段是 AI 填入的"，让 UI 层能标记高亮。
 * 2. 用户手动修改某字段后，该字段的 AI 标记自动消失（保护用户编辑）。
 * 3. AI 重新解析时，不覆盖用户已手动修改的字段。
 * 4. 提供统一的 banner 状态（parsing / filled / failed / hidden）。
 *
 * 使用方式（页面接入示例）：
 *
 *   @State aiFill: AIFillState = new AIFillState();
 *
 *   // AI 解析开始
 *   this.aiFill.startParsing();
 *
 *   // AI 解析完成，标记哪些字段被填入
 *   this.aiFill.markFilled(['title', 'dueDate', 'priority']);
 *
 *   // 用户手动修改了 title
 *   this.aiFill.markUserEdited('title');
 *
 *   // AI 重新解析时，检查是否可以覆盖
 *   if (this.aiFill.canOverwrite('title')) { ... }
 *
 *   // UI 判断某字段是否由 AI 填入（用于高亮）
 *   if (this.aiFill.isFieldFilled('dueDate')) { ... }
 *
 *   // 用户点击"隐藏提示"
 *   this.aiFill.dismiss();
 */

/**
 * Banner 展示状态
 */
export type AIFillBannerStatus = 'idle' | 'parsing' | 'filled' | 'failed' | 'hidden';

/**
 * 单个字段的填入记录
 */
export interface AIFieldRecord {
  /** 字段名（如 'title', 'dueDate', 'priority', 'goalId' 等） */
  fieldName: string;
  /** 是否由 AI 填入 */
  filledByAI: boolean;
  /** 用户是否已手动修改（一旦为 true，AI 不再覆盖） */
  userEdited: boolean;
  /** AI 填入的原始值（用于判断用户是否真的改了） */
  originalValue?: string;
}

/**
 * AI 填入状态管理器
 *
 * 每个创建页实例化一个 AIFillState，管理该页面所有字段的 AI 填入状态。
 * 设计为纯数据类，不依赖 ArkUI 装饰器，页面通过 @State 持有并触发 UI 刷新。
 */
export class AIFillState {
  /** 当前 banner 状态 */
  bannerStatus: AIFillBannerStatus = 'idle';

  /** 各字段的填入记录 */
  private fields: Map<string, AIFieldRecord> = new Map();

  /** 最近一次 AI 解析的 traceId（用于遥测关联） */
  traceId: string = '';

  /** 错误信息（failed 状态时展示） */
  errorMessage: string = '';

  // ========== 生命周期方法 ==========

  /**
   * AI 解析开始。
   * 切换 banner 到 parsing 状态。
   */
  startParsing(traceId?: string): void {
    this.bannerStatus = 'parsing';
    this.errorMessage = '';
    if (traceId) {
      this.traceId = traceId;
    }
  }

  /**
   * AI 解析完成，标记哪些字段被填入。
   *
   * @param fieldNames 被 AI 填入的字段名列表
   * @param originalValues 可选：每个字段的原始填入值，用于后续判断用户是否真的修改了
   */
  markFilled(fieldNames: string[], originalValues?: Record<string, string>): void {
    this.bannerStatus = fieldNames.length > 0 ? 'filled' : 'idle';
    for (const name of fieldNames) {
      const existing = this.fields.get(name);
      // 如果用户已经手动编辑过该字段，不再标记为 AI 填入
      if (existing && existing.userEdited) {
        continue;
      }
      const record: AIFieldRecord = {
        fieldName: name,
        filledByAI: true,
        userEdited: false,
        originalValue: originalValues ? originalValues[name] : undefined
      };
      this.fields.set(name, record);
    }
  }

  /**
   * AI 解析失败。
   */
  markFailed(errorMessage: string): void {
    this.bannerStatus = 'failed';
    this.errorMessage = errorMessage;
  }

  /**
   * 用户手动修改了某字段。
   * 该字段的 AI 标记消失，后续 AI 重新解析不会覆盖。
   */
  markUserEdited(fieldName: string): void {
    const existing = this.fields.get(fieldName);
    if (existing) {
      existing.userEdited = true;
      existing.filledByAI = false;
    } else {
      this.fields.set(fieldName, {
        fieldName,
        filledByAI: false,
        userEdited: true
      });
    }
  }

  /**
   * 用户点击"隐藏提示"。
   * Banner 消失，但字段记录保留（用于后续判断）。
   */
  dismiss(): void {
    this.bannerStatus = 'hidden';
  }

  /**
   * 重置所有状态（页面离开或重新开始时调用）。
   */
  reset(): void {
    this.bannerStatus = 'idle';
    this.fields.clear();
    this.traceId = '';
    this.errorMessage = '';
  }

  // ========== 查询方法 ==========

  /**
   * 某字段是否由 AI 填入且用户未修改（用于 UI 高亮）。
   */
  isFieldFilled(fieldName: string): boolean {
    const record = this.fields.get(fieldName);
    return !!record && record.filledByAI && !record.userEdited;
  }

  /**
   * AI 重新解析时，是否可以覆盖某字段。
   * 规则：用户未手动编辑过的字段可以覆盖。
   */
  canOverwrite(fieldName: string): boolean {
    const record = this.fields.get(fieldName);
    if (!record) {
      return true; // 从未被 AI 填入也未被用户编辑，可以填入
    }
    return !record.userEdited;
  }

  /**
   * 获取所有被 AI 填入且用户未修改的字段名列表。
   */
  getFilledFieldNames(): string[] {
    const result: string[] = [];
    this.fields.forEach((record: AIFieldRecord) => {
      if (record.filledByAI && !record.userEdited) {
        result.push(record.fieldName);
      }
    });
    return result;
  }

  /**
   * 获取所有被用户手动编辑过的字段名列表。
   */
  getUserEditedFieldNames(): string[] {
    const result: string[] = [];
    this.fields.forEach((record: AIFieldRecord) => {
      if (record.userEdited) {
        result.push(record.fieldName);
      }
    });
    return result;
  }

  /**
   * 是否有任何字段被 AI 填入（用于决定是否显示 banner）。
   */
  hasAnyFill(): boolean {
    let found = false;
    this.fields.forEach((record: AIFieldRecord) => {
      if (record.filledByAI && !record.userEdited) {
        found = true;
      }
    });
    return found;
  }

  /**
   * Banner 是否应该展示。
   */
  shouldShowBanner(): boolean {
    return this.bannerStatus === 'parsing' ||
      this.bannerStatus === 'filled' ||
      this.bannerStatus === 'failed';
  }

  /**
   * 获取 banner 展示文案。
   */
  getBannerTitle(): string {
    switch (this.bannerStatus) {
      case 'parsing':
        return 'AI 正在解析语音内容...';
      case 'filled': {
        const count = this.getFilledFieldNames().length;
        return `AI 已填入 ${count} 个字段`;
      }
      case 'failed':
        return this.errorMessage || 'AI 解析失败';
      default:
        return '';
    }
  }

  /**
   * 获取与 AppAIFillBanner 组件兼容的 status prop。
   */
  getBannerComponentStatus(): 'parsing' | 'filled' | 'failed' {
    if (this.bannerStatus === 'parsing') {
      return 'parsing';
    }
    if (this.bannerStatus === 'failed') {
      return 'failed';
    }
    return 'filled';
  }
}
