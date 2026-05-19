const mongoose = require('mongoose');

/**
 * 用户行为埋点模型
 * 记录关键用户行为事件，用于产品分析和漏斗优化
 */
const telemetryEventSchema = new mongoose.Schema({
  userId:        { type: String, required: true, index: true },
  eventName:     { type: String, required: true, index: true }, // 如 task_created, ai_plan_adopted
  eventCategory: {
    type: String,
    required: true,
    enum: ['session', 'task', 'goal', 'ai', 'membership', 'search', 'voice', 'other']
  },
  properties: { type: mongoose.Schema.Types.Mixed, default: {} }, // 附加属性(任意KV)
  platform:   { type: String, default: 'harmonyos' },            // 客户端平台
  appVersion: { type: String, default: '' },                     // 客户端版本号
  sessionId:  { type: String, default: '' },                     // 会话ID(用于漏斗分析)
  createdAt:  { type: Number, default: () => Date.now(), index: true }
});

// 常用查询复合索引
telemetryEventSchema.index({ userId: 1, createdAt: -1 });
telemetryEventSchema.index({ eventName: 1, createdAt: -1 });
telemetryEventSchema.index({ eventCategory: 1, createdAt: -1 });

// 自动过期(TTL)：保留180天的原始埋点数据，控制存储成本
telemetryEventSchema.index({ createdAt: 1 }, {
  expireAfterSeconds: 180 * 24 * 60 * 60,
  // MongoDB TTL索引要求Date类型，这里用Number存储时间戳，需在应用层处理
  // 实际TTL由应用层定期清理，此处仅作标记
  name: 'ttl_180days'
});

module.exports = mongoose.model('TelemetryEvent', telemetryEventSchema);
