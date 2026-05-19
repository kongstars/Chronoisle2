const mongoose = require('mongoose');

const iapOrderSchema = new mongoose.Schema({
  provider: { type: String, enum: ['huawei'], default: 'huawei', index: true },
  providerOrderKey: { type: String, required: true, unique: true },
  orderId: { type: String, default: '', index: true },
  purchaseToken: { type: String, default: '', index: true },
  originalOrderId: { type: String, default: '', index: true },
  subscriptionId: { type: String, default: '', index: true },
  userId: { type: String, required: true, index: true },
  productId: { type: String, required: true, index: true },
  productType: { type: String, enum: ['auto_renewable'], default: 'auto_renewable' },
  plan: {
    type: String,
    enum: ['monthly_continuous', 'yearly_continuous'],
    required: true
  },
  environment: {
    type: String,
    enum: ['sandbox', 'production', 'unknown'],
    default: 'unknown',
    index: true
  },
  status: {
    type: String,
    enum: ['purchased', 'renewed', 'active', 'canceled', 'refunded', 'expired', 'failed', 'unknown'],
    default: 'purchased',
    index: true
  },
  purchaseState: { type: mongoose.Schema.Types.Mixed, default: null },
  eventType: { type: String, default: '' },
  periodStartAt: { type: Number, default: 0 },
  periodEndAt: { type: Number, default: 0, index: true },
  fulfilledAt: { type: Number, default: 0 },
  canceledAt: { type: Number, default: 0 },
  refundedAt: { type: Number, default: 0 },
  expiredAt: { type: Number, default: 0 },
  lastEventAt: { type: Number, default: () => Date.now() },
  jwsHash: { type: String, default: '', index: true },
  rawPurchaseData: { type: mongoose.Schema.Types.Mixed, default: null },
  rawNotificationData: { type: mongoose.Schema.Types.Mixed, default: null },
  createdAt: { type: Number, default: () => Date.now() },
  updatedAt: { type: Number, default: () => Date.now() }
});

iapOrderSchema.index({ userId: 1, periodEndAt: -1 });
iapOrderSchema.index({ provider: 1, orderId: 1 });
iapOrderSchema.index({ provider: 1, purchaseToken: 1 });

iapOrderSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model('IapOrder', iapOrderSchema);
