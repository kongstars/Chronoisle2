const mongoose = require('mongoose');

const planningSessionSchema = new mongoose.Schema({
  sessionId: { type: String, required: true, unique: true, index: true },
  userId:    { type: String, required: true, index: true },
  source:    { type: String, enum: ['create_goal', 'enhance_goal'], default: 'create_goal' },
  targetGoalId: { type: String, default: null },
  rawIntent: { type: String, required: true },
  stage: {
    type: String,
    enum: ['understanding', 'clarifying', 'progress', 'actions', 'review', 'saving', 'completed', 'error'],
    default: 'understanding'
  },
  status: { type: String, enum: ['active', 'paused', 'completed', 'abandoned'], default: 'active' },

  // 各阶段结构化产出（混合类型以支持灵活数据结构）
  goalDraft:      { type: mongoose.Schema.Types.Mixed, default: null },
  clarification:  { type: mongoose.Schema.Types.Mixed, default: null },
  goalAssessment: { type: mongoose.Schema.Types.Mixed, default: null },
  progressPlan:   { type: mongoose.Schema.Types.Mixed, default: null },
  actionPlan:     { type: mongoose.Schema.Types.Mixed, default: null },
  automationPlan: { type: mongoose.Schema.Types.Mixed, default: null },
  qualityReport:  { type: mongoose.Schema.Types.Mixed, default: null },
  runtimeStatus:  { type: mongoose.Schema.Types.Mixed, default: null },

  createdAt: { type: Number, default: () => Date.now() },
  updatedAt: { type: Number, default: () => Date.now() }
});

// 更新时自动刷新 updatedAt
planningSessionSchema.pre('save', function (next) {
  this.updatedAt = Date.now();
  next();
});

planningSessionSchema.pre('findOneAndUpdate', function (next) {
  this.set({ updatedAt: Date.now() });
  next();
});

planningSessionSchema.index({ sessionId: 1, userId: 1 });

module.exports = mongoose.model('PlanningSession', planningSessionSchema);
