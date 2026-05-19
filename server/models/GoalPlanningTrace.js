const mongoose = require('mongoose');

const goalPlanningTraceSchema = new mongoose.Schema({
  sessionId: { type: String, required: true, index: true },
  userId: { type: String, required: true, index: true },
  traceType: { type: String, enum: ['step', 'agent'], required: true, index: true },
  stepName: { type: String, required: true, index: true },
  stage: { type: String, default: '' },
  source: { type: String, enum: ['create_goal', 'enhance_goal', 'unknown'], default: 'unknown' },
  status: { type: String, enum: ['success', 'failed', 'partial'], default: 'success', index: true },
  agentKey: { type: String, default: '', index: true },
  model: { type: String, default: '', index: true },
  durationMs: { type: Number, default: 0 },
  fallbackUsed: { type: Boolean, default: false },
  requestPreview: { type: String, default: '' },
  responsePreview: { type: String, default: '' },
  payload: { type: mongoose.Schema.Types.Mixed, default: null },
  metrics: { type: mongoose.Schema.Types.Mixed, default: {} },
  errorMessage: { type: String, default: '' },
  createdAt: { type: Number, default: () => Date.now(), index: true }
});

goalPlanningTraceSchema.index({ sessionId: 1, createdAt: -1 });
goalPlanningTraceSchema.index({ userId: 1, createdAt: -1 });
goalPlanningTraceSchema.index({ traceType: 1, stepName: 1, createdAt: -1 });
goalPlanningTraceSchema.index({ agentKey: 1, createdAt: -1 });

module.exports = mongoose.model('GoalPlanningTrace', goalPlanningTraceSchema);
