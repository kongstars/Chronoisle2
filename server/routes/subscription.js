const express = require('express');
const User = require('../models/User');
const UsageSummary = require('../models/UsageSummary');
const CreditAccount = require('../models/CreditAccount');
const CreditTransaction = require('../models/CreditTransaction');

const router = express.Router();

const MONTHLY_GRANT = 500;

/**
 * 购买会员后发放月度积分
 */
async function grantMonthlyCredits(userId) {
  try {
    const now = new Date();
    const currentMonth = `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}`;

    let account = await CreditAccount.findOne({ userId });
    if (!account) {
      account = new CreditAccount({
        userId, balance: 0, totalEarned: 0, totalSpent: 0,
        lastGrantMonth: '', createdAt: Date.now()
      });
    }

    // 本月已发放则跳过
    if (account.lastGrantMonth === currentMonth) return;

    account.balance += MONTHLY_GRANT;
    account.totalEarned += MONTHLY_GRANT;
    account.lastGrantMonth = currentMonth;
    await account.save();

    await new CreditTransaction({
      userId, type: 'earn', amount: MONTHLY_GRANT,
      source: 'monthly_grant',
      description: `${currentMonth} 会员月度积分`,
      balanceAfter: account.balance, createdAt: Date.now()
    }).save();

    console.log(`已为用户 ${userId} 发放 ${MONTHLY_GRANT} 月度积分`);
  } catch (e) {
    console.warn('发放月度积分失败(不影响购买):', e.message);
  }
}

const checkUser = require('../middleware/checkUser');

/**
 * 模拟购买会员（此处仅为演示，实际应接入支付平台回调）
 * POST /api/subscription/buy
 * body: { plan: 'monthly' | 'monthly_continuous' | 'yearly' | 'yearly_continuous' }
 */
router.post('/buy', checkUser, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { plan } = req.body;

    const user = await User.findOne({ userId });
    if (!user) {
      return res.status(404).json({ success: false, message: '用户不存在' });
    }

    const now = Date.now();
    // 如果当前已经是高级会员且未过期，则在现有到期时间上累加；否则从现在开始算
    const currentExpireAt = (user.membershipType === 'premium' && user.membershipExpireAt > now) 
      ? user.membershipExpireAt 
      : now;

    let durationMs = 0;
    
    // 简单粗暴按 30 天算一个月，365 天算一年
    const ONE_MONTH = 30 * 24 * 60 * 60 * 1000;
    const ONE_YEAR = 365 * 24 * 60 * 60 * 1000;

    switch (plan) {
      case 'monthly':
      case 'monthly_continuous':
        durationMs = ONE_MONTH;
        user.membershipPlan = 'monthly_continuous';
        user.membershipProductId = 'vip_monthly_continuous';
        break;
      case 'yearly':
      case 'yearly_continuous':
        durationMs = ONE_YEAR;
        user.membershipPlan = 'yearly_continuous';
        user.membershipProductId = 'vip_yearly_continuous';
        break;
      default:
        return res.status(400).json({ success: false, message: '未知的会员套餐' });
    }

    user.membershipType = 'premium';
    user.membershipExpireAt = currentExpireAt + durationMs;
    user.membershipRenewAt = user.membershipExpireAt;
    user.pendingMembershipPlan = '';
    user.pendingMembershipProductId = '';
    user.pendingMembershipEffectiveAt = 0;

    await user.save();

    // 发放月度积分
    await grantMonthlyCredits(userId);

    // 重置当月用量统计
    try {
      const now = new Date();
      const yearMonth = `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}`;
      await UsageSummary.findOneAndUpdate(
        { userId, yearMonth },
        { $set: { voiceSeconds: 0, totalTokens: 0, inputTokens: 0, outputTokens: 0, voiceCount: 0, tokenCount: 0, updatedAt: Date.now() } },
        { upsert: false }
      );
    } catch (resetErr) {
      console.warn('重置用量统计失败(不影响购买):', resetErr.message);
    }

    res.json({
      success: true,
      message: '购买成功',
      data: {
        membershipType: user.membershipType,
        membershipPlan: user.membershipPlan,
        membershipProductId: user.membershipProductId,
        membershipExpireAt: user.membershipExpireAt,
        membershipRenewAt: user.membershipRenewAt,
        pendingMembershipPlan: user.pendingMembershipPlan,
        pendingMembershipProductId: user.pendingMembershipProductId,
        pendingMembershipEffectiveAt: user.pendingMembershipEffectiveAt
      }
    });

  } catch (error) {
    console.error('购买会员失败:', error);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

module.exports = router;
