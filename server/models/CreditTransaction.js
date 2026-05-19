const mongoose = require('mongoose');

const creditTransactionSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  type: { type: String, required: true, enum: ['earn', 'spend'] },   // 充值/消耗
  amount: { type: Number, required: true },                           // 积分数量(正数)
  source: {
    type: String,
    enum: ['register_bonus', 'monthly_grant', 'purchase', 'admin_grant', 'event_grant'],
    default: undefined
  },
  feature: {
    type: String,
    enum: ['ai_task', 'voice_task', 'today_plan', 'reschedule', 'goal_breakdown', 'ai_schedule'],
    default: undefined
  },
  description: { type: String, default: '' },       // 可读描述
  balanceAfter: { type: Number, required: true },    // 变动后余额
  idempotencyKey: { type: String, default: undefined },   // 幂等键（防止网络重试重复扣费）
  createdAt: { type: Number, default: () => Date.now() }
});

// 复合索引：按用户+时间倒序查询流水
creditTransactionSchema.index({ userId: 1, createdAt: -1 });
// 按类型筛选
creditTransactionSchema.index({ userId: 1, type: 1, createdAt: -1 });
// 幂等键唯一索引（sparse：仅对有值的文档生效）
creditTransactionSchema.index({ idempotencyKey: 1 }, { unique: true, sparse: true });

module.exports = mongoose.model('CreditTransaction', creditTransactionSchema);
