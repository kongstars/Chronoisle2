const mongoose = require('mongoose');

const usageSummarySchema = new mongoose.Schema({
  userId: { type: String, required: true },
  yearMonth: { type: String, required: true }, // '2026-03'
  voiceSeconds: { type: Number, default: 0 },
  totalTokens: { type: Number, default: 0 },
  inputTokens: { type: Number, default: 0 },
  outputTokens: { type: Number, default: 0 },
  voiceCount: { type: Number, default: 0 },   // 语音调用次数
  tokenCount: { type: Number, default: 0 },   // AI调用次数
  updatedAt: { type: Number, default: () => Date.now() },
  aiFeatureUsage: {
    ai_task: {
      triggers: { type: Number, default: 0 },
      adopts: { type: Number, default: 0 }
    },
    goal_breakdown: {
      triggers: { type: Number, default: 0 },
      adopts: { type: Number, default: 0 }
    },
    today_plan: {
      triggers: { type: Number, default: 0 },
      adopts: { type: Number, default: 0 }
    },
    reschedule: {
      triggers: { type: Number, default: 0 },
      adopts: { type: Number, default: 0 }
    }
  }
});

// 唯一复合索引
usageSummarySchema.index({ userId: 1, yearMonth: 1 }, { unique: true });

module.exports = mongoose.model('UsageSummary', usageSummarySchema);
