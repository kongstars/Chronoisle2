const mongoose = require('mongoose');

const usageRecordSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  type: { type: String, required: true, enum: ['voice', 'token', 'ai_feature'] },
  amount: { type: Number, required: true }, // voice=秒, token=总token数, ai_feature=1
  detail: {
    inputTokens: { type: Number, default: 0 },
    outputTokens: { type: Number, default: 0 },
    model: { type: String, default: '' },
    duration: { type: Number, default: 0 } // 语音时长(秒)
  },
  yearMonth: { type: String, required: true, index: true }, // '2026-03'
  createdAt: { type: Number, default: () => Date.now() }
});

usageRecordSchema.index({ userId: 1, yearMonth: 1, createdAt: -1 });

// 复合索引，便于按用户+月份查询
usageRecordSchema.index({ userId: 1, yearMonth: 1 });
usageRecordSchema.index({ userId: 1, type: 1, yearMonth: 1 });

module.exports = mongoose.model('UsageRecord', usageRecordSchema);
