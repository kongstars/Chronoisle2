const mongoose = require('mongoose');

const creditAccountSchema = new mongoose.Schema({
  userId: { type: String, required: true, unique: true, index: true },
  balance: { type: Number, default: 0 },           // 当前积分余额
  totalEarned: { type: Number, default: 0 },        // 累计获得积分
  totalSpent: { type: Number, default: 0 },         // 累计消耗积分
  lastGrantMonth: { type: String, default: '' },    // 上次发放月度积分的年月 '2026-04'
  createdAt: { type: Number, default: () => Date.now() }
});

module.exports = mongoose.model('CreditAccount', creditAccountSchema);
