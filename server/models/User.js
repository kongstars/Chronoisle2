const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  userId: { type: String, required: true, unique: true },
  accountType: { 
    type: String, 
    required: true, 
    enum: ['phone', 'email', 'huawei', 'wechat', 'qq'] 
  },
  account: { type: String, required: true },
  openId: { type: String },  // 第三方平台唯一ID
  unionId: { type: String }, // 微信unionId（跨应用唯一）
  nickname: { type: String }, // 用户昵称
  avatar: { type: String, default: '' },
  displayId: { type: String, unique: true, sparse: true },
  membershipType: { type: String, enum: ['basic', 'premium'], default: 'basic' },
  membershipPlan: { type: String, enum: ['', 'monthly_continuous', 'yearly_continuous'], default: '' },
  membershipProductId: { type: String, default: '' },
  membershipExpireAt: { type: Number, default: 0 },
  membershipRenewAt: { type: Number, default: 0 },
  pendingMembershipPlan: { type: String, enum: ['', 'monthly_continuous', 'yearly_continuous'], default: '' },
  pendingMembershipProductId: { type: String, default: '' },
  pendingMembershipEffectiveAt: { type: Number, default: 0 },
  createdAt:       { type: Number, default: () => Date.now() },
  lastLoginAt:     { type: Number, default: () => Date.now() },
  lastActiveAt:    { type: Number, default: () => Date.now() },   // 最后活跃时间(任意行为)
  totalLoginCount: { type: Number, default: 0 },          // 累计登录次数
  appVersion:      { type: String, default: '' },         // 最后使用的客户端版本
  deviceInfo: {                                           // 首次注册时的设备信息
    model:     { type: String, default: '' },             // 设备型号
    osVersion: { type: String, default: '' },             // 系统版本
    platform:  { type: String, default: 'harmonyos' }     // 平台
  }
});

// 复合索引，确保同一平台同一用户唯一
userSchema.index({ accountType: 1, openId: 1 }, { unique: true });
// 性能索引 — 会员查询、登录、管理后台
userSchema.index({ membershipType: 1, membershipExpireAt: 1 });
userSchema.index({ accountType: 1, account: 1 });
userSchema.index({ createdAt: -1 });
userSchema.index({ displayId: 1 });

// 自动生成8位数字显示ID
userSchema.pre('save', function(next) {
  if (!this.displayId) {
    this.displayId = Math.floor(10000000 + Math.random() * 90000000).toString();
  }
  next();
});

module.exports = mongoose.model('User', userSchema);
