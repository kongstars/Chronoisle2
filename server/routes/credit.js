const express = require('express');
const CreditAccount = require('../models/CreditAccount');
const CreditTransaction = require('../models/CreditTransaction');
const User = require('../models/User');

const router = express.Router();

const MONTHLY_GRANT = 500;     // 会员每月赠送积分
const REGISTER_BONUS = 50;     // 注册赠送积分

// 积分消耗价目表
const CREDIT_COSTS = {
  ai_task: 1,
  voice_task: 1,
  today_plan: 1,
  reschedule: 1,
  goal_breakdown: 5,
  ai_schedule: 1
};

const FEATURE_NAMES = {
  ai_task: 'AI补全任务',
  voice_task: '语音创建任务',
  today_plan: '今日规划',
  reschedule: '积压任务整理',
  goal_breakdown: 'AI拆解目标',
  ai_schedule: 'AI智能排程'
};

const { getCurrentYearMonth } = require('../utils/date');

function isPremiumActive(user) {
  return !!(user && user.membershipType === 'premium' && user.membershipExpireAt && user.membershipExpireAt > Date.now());
}

function buildPrecheckResult(feature, user, account) {
  const cost = CREDIT_COSTS[feature];
  const premiumActive = isPremiumActive(user);
  const balance = account ? account.balance : 0;

  if (feature === 'voice_task') {
    if (premiumActive) {
      return {
        allowed: true,
        message: '会员可直接使用语音创建',
        requireMembership: false,
        balance,
        required: cost,
        isMemberActive: true
      };
    }

    if (balance >= cost) {
      return {
        allowed: true,
        message: '积分充足，可使用语音创建',
        requireMembership: false,
        balance,
        required: cost,
        isMemberActive: false
      };
    }

    return {
      allowed: false,
      message: `积分不足，语音创建至少需要 ${cost} 积分`,
      requireMembership: false,
      balance,
      required: cost,
      isMemberActive: false
    };
  }

  if (!premiumActive) {
    return {
      allowed: false,
      message: '需要有效会员才能使用此功能',
      requireMembership: true,
      balance,
      required: cost,
      isMemberActive: false
    };
  }

  if (balance < cost) {
    return {
      allowed: false,
      message: '积分不足',
      requireMembership: false,
      balance,
      required: cost,
      isMemberActive: true
    };
  }

  return {
    allowed: true,
    message: '校验通过',
    requireMembership: false,
    balance,
    required: cost,
    isMemberActive: true
  };
}

/**
 * 检查并发放月度积分（如需要）
 * 仅在会员有效期内发放
 */
async function checkAndGrantMonthly(userId) {
  const currentMonth = getCurrentYearMonth();

  // 原子操作：仅在 lastGrantMonth 不是当月时更新，防止并发竞态双发
  const updated = await CreditAccount.findOneAndUpdate(
    { userId, lastGrantMonth: { $ne: currentMonth } },
    {
      $inc: { balance: MONTHLY_GRANT, totalEarned: MONTHLY_GRANT },
      $set: { lastGrantMonth: currentMonth }
    },
    { new: true }
  );

  // 未更新说明本月已发放或账户不存在
  if (!updated) {
    const account = await CreditAccount.findOne({ userId });
    return account;
  }

  // 检查用户是否为有效会员
  const user = await User.findOne({ userId });
  if (!user || user.membershipType !== 'premium' || !user.membershipExpireAt || user.membershipExpireAt <= Date.now()) {
    return updated;
  }

  // 写入流水
  await new CreditTransaction({
    userId,
    type: 'earn',
    amount: MONTHLY_GRANT,
    source: 'monthly_grant',
    description: `${currentMonth} 会员月度积分`,
    balanceAfter: updated.balance,
    createdAt: Date.now()
  }).save();

  return updated;
}

/**
 * GET /api/credit/balance
 * 获取当前积分余额（自动触发月度发放检查）
 */
router.get('/balance', async (req, res) => {
  try {
    const userId = req.user.userId;

    // 确保账户存在
    let account = await CreditAccount.findOne({ userId });
    if (!account) {
      account = new CreditAccount({ userId, balance: 0, totalEarned: 0, totalSpent: 0 });
      await account.save();
    }

    // 检查并发放月度积分
    account = await checkAndGrantMonthly(userId) || account;

    // 检查会员状态
    const user = await User.findOne({ userId });
    const isMemberActive = user && user.membershipType === 'premium' &&
      user.membershipExpireAt && user.membershipExpireAt > Date.now();

    // 积分永不过期，会员到期不冻结不清空
    const isFrozen = false;

    res.json({
      success: true,
      data: {
        balance: account.balance,
        totalEarned: account.totalEarned,
        totalSpent: account.totalSpent,
        isFrozen,
        isMemberActive: !!isMemberActive,
        lastGrantMonth: account.lastGrantMonth
      }
    });
  } catch (error) {
    console.error('获取积分余额失败:', error.message);
    res.status(500).json({ success: false, message: '获取积分余额失败' });
  }
});

router.post('/precheck', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { feature } = req.body;

    if (!feature || !CREDIT_COSTS[feature]) {
      return res.status(400).json({ success: false, message: '无效的功能类型' });
    }

    let account = await CreditAccount.findOne({ userId });
    if (!account) {
      account = new CreditAccount({ userId, balance: 0, totalEarned: 0, totalSpent: 0 });
      await account.save();
    }

    account = await checkAndGrantMonthly(userId) || account;
    const user = await User.findOne({ userId });
    const result = buildPrecheckResult(feature, user, account);

    return res.json({
      success: true,
      message: result.message,
      data: result
    });
  } catch (error) {
    console.error('积分预校验失败:', error.message);
    return res.status(500).json({ success: false, message: '积分预校验失败' });
  }
});

/**
 * POST /api/credit/spend
 * 扣减积分
 * body: { feature: 'ai_task' | 'voice_task' | ... }
 */
router.post('/spend', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { feature, idempotencyKey } = req.body;

    if (!feature || !CREDIT_COSTS[feature]) {
      return res.status(400).json({ success: false, message: '无效的功能类型' });
    }

    // 幂等检查：如果客户端传了 idempotencyKey，检查是否已处理过
    if (idempotencyKey) {
      const existing = await CreditTransaction.findOne({ idempotencyKey });
      if (existing) {
        const account = await CreditAccount.findOne({ userId });
        return res.json({
          success: true,
          message: '扣费成功（幂等）',
          data: {
            spent: existing.amount,
            balance: account ? account.balance : 0,
            feature: existing.feature
          }
        });
      }
    }

    let account = await CreditAccount.findOne({ userId });
    if (!account) {
      account = new CreditAccount({ userId, balance: 0, totalEarned: 0, totalSpent: 0 });
      await account.save();
    }

    account = await checkAndGrantMonthly(userId) || account;
    const cost = CREDIT_COSTS[feature];
    const user = await User.findOne({ userId });
    const precheck = buildPrecheckResult(feature, user, account);
    if (!precheck.allowed) {
      return res.json({
        success: false,
        message: precheck.message,
        data: {
          requireMembership: precheck.requireMembership,
          balance: precheck.balance,
          required: precheck.required
        }
      });
    }

    // 检查余额
    // 检查余额
    if (account.balance < cost) {
      return res.json({
        success: false,
        message: '积分不足',
        data: { balance: account.balance, required: cost }
      });
    }

    // 扣减积分
    account.balance -= cost;
    account.totalSpent += cost;
    await account.save();

    // 写入消耗流水（带幂等键）
    const txData = {
      userId,
      type: 'spend',
      amount: cost,
      feature,
      description: FEATURE_NAMES[feature] || feature,
      balanceAfter: account.balance,
      createdAt: Date.now()
    };
    if (idempotencyKey) {
      txData.idempotencyKey = idempotencyKey;
    }
    await new CreditTransaction(txData).save();

    res.json({
      success: true,
      message: '扣费成功',
      data: {
        spent: cost,
        balance: account.balance,
        feature
      }
    });
  } catch (error) {
    console.error('积分扣减失败:', error.message);
    res.status(500).json({ success: false, message: '积分扣减失败' });
  }
});

/**
 * GET /api/credit/transactions
 * 查询积分流水
 * Query: ?page=1&pageSize=20&type=earn|spend
 */
router.get('/transactions', async (req, res) => {
  try {
    const userId = req.user.userId;
    const page = parseInt(req.query.page) || 1;
    const pageSize = Math.min(parseInt(req.query.pageSize) || 20, 50);
    const type = req.query.type; // 'earn' | 'spend' | undefined (全部)

    const filter = { userId };
    if (type && ['earn', 'spend'].includes(type)) {
      filter.type = type;
    }

    const total = await CreditTransaction.countDocuments(filter);
    const transactions = await CreditTransaction.find(filter)
      .sort({ createdAt: -1 })
      .skip((page - 1) * pageSize)
      .limit(pageSize)
      .lean();

    const account = await CreditAccount.findOne({ userId });

    res.json({
      success: true,
      data: {
        transactions,
        totalEarned: account ? account.totalEarned : 0,
        totalSpent: account ? account.totalSpent : 0,
        pagination: {
          page,
          pageSize,
          total,
          totalPages: Math.ceil(total / pageSize)
        }
      }
    });
  } catch (error) {
    console.error('查询积分流水失败:', error.message);
    res.status(500).json({ success: false, message: '查询积分流水失败' });
  }
});

// 导出常量和工具函数供其他模块使用
router.MONTHLY_GRANT = MONTHLY_GRANT;
router.REGISTER_BONUS = REGISTER_BONUS;
router.CREDIT_COSTS = CREDIT_COSTS;
router.checkAndGrantMonthly = checkAndGrantMonthly;

module.exports = router;
