const mongoose = require('mongoose');

const iapEventSchema = new mongoose.Schema({
  provider: { type: String, enum: ['huawei'], default: 'huawei', index: true },
  idempotencyKey: { type: String, required: true, unique: true },
  eventId: { type: String, default: '', index: true },
  eventType: { type: String, default: '', index: true },
  environment: {
    type: String,
    enum: ['sandbox', 'production', 'unknown'],
    default: 'unknown',
    index: true
  },
  orderId: { type: String, default: '', index: true },
  purchaseToken: { type: String, default: '', index: true },
  productId: { type: String, default: '', index: true },
  userId: { type: String, default: '', index: true },
  processingStatus: {
    type: String,
    enum: ['received', 'processed', 'ignored', 'needs_manual_review', 'failed'],
    default: 'received',
    index: true
  },
  message: { type: String, default: '' },
  error: { type: String, default: '' },
  rawPayload: { type: mongoose.Schema.Types.Mixed, default: null },
  decodedPayload: { type: mongoose.Schema.Types.Mixed, default: null },
  receivedAt: { type: Number, default: () => Date.now() },
  processedAt: { type: Number, default: 0 },
  updatedAt: { type: Number, default: () => Date.now() }
});

iapEventSchema.index({ userId: 1, receivedAt: -1 });
iapEventSchema.index({ processingStatus: 1, receivedAt: -1 });

iapEventSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model('IapEvent', iapEventSchema);
