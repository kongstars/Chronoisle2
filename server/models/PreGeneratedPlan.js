const mongoose = require('mongoose');

const preGeneratedPlanSchema = new mongoose.Schema({
  userId: { type: String, required: true, index: true },
  date: { type: String, required: true },   // "2026-04-06"
  planData: { type: Object, default: {} },  // { focusTasks, deferTasks, summary, totalEstimatedHours, groupedTasks }
  adoptedPlanData: { type: Object, default: {} }, // 采纳并在此后更新的计划数据
  taskSnapshot: { type: Array, default: [] }, // 生成时的待办快照
  generatedAt: { type: Number, default: () => Date.now() },
  status: { type: String, default: 'pending', enum: ['pending', 'adopted', 'rejected'] }
});

// 每个用户每天只有一个计划
preGeneratedPlanSchema.index({ userId: 1, date: 1 }, { unique: true });

module.exports = mongoose.model('PreGeneratedPlan', preGeneratedPlanSchema);
