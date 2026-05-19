const express = require('express');
const User = require('../models/User');
const UsageRecord = require('../models/UsageRecord');
const UsageSummary = require('../models/UsageSummary');
const SyncData = require('../models/SyncData');
const CreditAccount = require('../models/CreditAccount');
const CreditTransaction = require('../models/CreditTransaction');
const { adminAuthenticate, generateAdminToken } = require('../middleware/adminAuth');

const router = express.Router();

/**
 * POST /api/admin/login
 * 管理员登录
 */
router.post('/login', (req, res) => {
  const { username, password } = req.body;
  const adminUser = process.env.ADMIN_USERNAME || 'admin';
  const adminPass = process.env.ADMIN_PASSWORD;

  if (!adminPass) {
    return res.status(500).json({ success: false, message: '系统未配置管理员密码' });
  }

  if (username !== adminUser || password !== adminPass) {
    return res.status(401).json({ success: false, message: '用户名或密码错误' });
  }

  const token = generateAdminToken(username);
  res.json({ success: true, token, message: '登录成功' });
});

// 以下所有路由均需管理员身份
router.use(adminAuthenticate);

/**
 * GET /api/admin/users
 * 用户列表（分页 + 搜索）
 */
router.get('/users', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const search = req.query.search || '';
    const skip = (page - 1) * limit;

    const query = {};
    if (search) {
      query.$or = [
        { account: { $regex: search, $options: 'i' } },
        { nickname: { $regex: search, $options: 'i' } },
        { displayId: { $regex: search, $options: 'i' } },
        { userId: { $regex: search, $options: 'i' } }
      ];
    }
    if (req.query.membershipType && req.query.membershipType !== 'all') {
      query.membershipType = req.query.membershipType;
    }
    if (req.query.accountType && req.query.accountType !== 'all') {
      query.accountType = req.query.accountType;
    }

    const [users, total] = await Promise.all([
      User.find(query).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      User.countDocuments(query)
    ]);

    // 批量查询积分余额
    const userIds = users.map(u => u.userId);
    const creditAccounts = await CreditAccount.find({ userId: { $in: userIds } }).lean();
    const creditMap = {};
    creditAccounts.forEach(c => creditMap[c.userId] = c.balance);
    
    // 缝合积分余额
    const enrichedUsers = users.map(u => ({ ...u, creditBalance: creditMap[u.userId] || 0 }));

    res.json({
      success: true,
      data: {
        users: enrichedUsers,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    console.error('查询用户列表错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

/**
 * GET /api/admin/users/:userId
 * 单个用户详情 + 用量摘要
 */
router.get('/users/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await User.findOne({ userId }).lean();
    if (!user) {
      return res.status(404).json({ success: false, message: '用户不存在' });
    }

    // 最近6个月的月度汇总
    const summaries = await UsageSummary.find({ userId })
      .sort({ yearMonth: -1 })
      .limit(12)
      .lean();

    // 累计汇总
    const totalAgg = await UsageSummary.aggregate([
      { $match: { userId } },
      {
        $group: {
          _id: null,
          voiceSeconds: { $sum: '$voiceSeconds' },
          totalTokens: { $sum: '$totalTokens' },
          inputTokens: { $sum: '$inputTokens' },
          outputTokens: { $sum: '$outputTokens' },
          voiceCount: { $sum: '$voiceCount' },
          tokenCount: { $sum: '$tokenCount' }
        }
      }
    ]);

    // 获取积分账户
    let creditAccount = await CreditAccount.findOne({ userId }).lean();
    if (!creditAccount) {
      creditAccount = { balance: 0, totalEarned: 0, totalConsumed: 0 };
    }

    res.json({
      success: true,
      data: {
        user,
        monthlySummaries: summaries,
        cumulative: totalAgg[0] || {
          voiceSeconds: 0, totalTokens: 0, inputTokens: 0,
          outputTokens: 0, voiceCount: 0, tokenCount: 0
        },
        creditAccount
      }
    });
  } catch (error) {
    console.error('查询用户详情错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

/**
 * GET /api/admin/users/:userId/sync-data-stats
 * 获取某用户的 SyncData 规模
 */
router.get('/users/:userId/sync-data-stats', async (req, res) => {
  try {
    const { userId } = req.params;
    const syncData = await SyncData.findOne({ userId }).lean();
    if (!syncData) {
      return res.json({ success: true, data: { goals: 0, tasks: 0 } });
    }
    res.json({
      success: true,
      data: {
        goals: syncData.goals ? syncData.goals.length : 0,
        tasks: syncData.tasks ? syncData.tasks.length : 0
      }
    });
  } catch (err) {
    console.error('获取SyncData统计错误:', err.message);
    res.status(500).json({ success: false, message: '获取明细失败' });
  }
});

/**
 * GET /api/admin/usage/overview
 * 全局用量概览
 */
router.get('/usage/overview', async (req, res) => {
  try {
    const now = new Date();
    const currentMonth = `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}`;

    const [totalUsers, thisMonthUsers, premiumUsers] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({
        createdAt: { $gte: new Date(now.getFullYear(), now.getMonth(), 1).getTime() }
      }),
      User.countDocuments({ membershipType: 'premium', membershipExpireAt: { $gt: now.getTime() } })
    ]);

    // 全局累计
    const totalAgg = await UsageSummary.aggregate([
      {
        $group: {
          _id: null,
          voiceSeconds: { $sum: '$voiceSeconds' },
          totalTokens: { $sum: '$totalTokens' },
          voiceCount: { $sum: '$voiceCount' },
          tokenCount: { $sum: '$tokenCount' }
        }
      }
    ]);

    // 本月
    const monthAgg = await UsageSummary.aggregate([
      { $match: { yearMonth: currentMonth } },
      {
        $group: {
          _id: null,
          voiceSeconds: { $sum: '$voiceSeconds' },
          totalTokens: { $sum: '$totalTokens' },
          voiceCount: { $sum: '$voiceCount' },
          tokenCount: { $sum: '$tokenCount' },
          activeUsers: { $sum: 1 }
        }
      }
    ]);

    res.json({
      success: true,
      data: {
        totalUsers,
        thisMonthNewUsers: thisMonthUsers,
        premiumUsers,
        currentMonth,
        cumulative: totalAgg[0] || { voiceSeconds: 0, totalTokens: 0, voiceCount: 0, tokenCount: 0 },
        monthly: monthAgg[0] || { voiceSeconds: 0, totalTokens: 0, voiceCount: 0, tokenCount: 0, activeUsers: 0 }
      }
    });
  } catch (error) {
    console.error('全局概览查询错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

/**
 * GET /api/admin/usage/ai-features
 * 全局 AI 功能细分大盘
 */
router.get('/usage/ai-features', async (req, res) => {
  try {
    const agg = await UsageSummary.aggregate([
      {
        $group: {
          _id: null,
          taskTriggers: { $sum: '$aiFeatureUsage.ai_task.triggers' },
          taskAdopts: { $sum: '$aiFeatureUsage.ai_task.adopts' },
          goalTriggers: { $sum: '$aiFeatureUsage.goal_breakdown.triggers' },
          goalAdopts: { $sum: '$aiFeatureUsage.goal_breakdown.adopts' },
          planTriggers: { $sum: '$aiFeatureUsage.today_plan.triggers' },
          planAdopts: { $sum: '$aiFeatureUsage.today_plan.adopts' },
          rescheduleTriggers: { $sum: '$aiFeatureUsage.reschedule.triggers' },
          rescheduleAdopts: { $sum: '$aiFeatureUsage.reschedule.adopts' }
        }
      }
    ]);
    res.json({ success: true, data: agg[0] || {} });
  } catch (err) {
    console.error('AI大盘查询错误:', err.message);
    res.status(500).json({ success: false, message: '查询AI细分失败' });
  }
});

/**
 * GET /api/admin/usage/monthly
 * 按月度统计报表
 * Query: ?months=6 (最近N个月，默认6)
 */
router.get('/usage/monthly', async (req, res) => {
  try {
    const months = parseInt(req.query.months) || 6;

    const results = await UsageSummary.aggregate([
      {
        $group: {
          _id: '$yearMonth',
          voiceSeconds: { $sum: '$voiceSeconds' },
          totalTokens: { $sum: '$totalTokens' },
          inputTokens: { $sum: '$inputTokens' },
          outputTokens: { $sum: '$outputTokens' },
          voiceCount: { $sum: '$voiceCount' },
          tokenCount: { $sum: '$tokenCount' },
          activeUsers: { $sum: 1 }
        }
      },
      { $sort: { _id: -1 } },
      { $limit: months }
    ]);

    res.json({
      success: true,
      data: results.map(r => ({
        yearMonth: r._id,
        voiceSeconds: r.voiceSeconds,
        totalTokens: r.totalTokens,
        inputTokens: r.inputTokens,
        outputTokens: r.outputTokens,
        voiceCount: r.voiceCount,
        tokenCount: r.tokenCount,
        activeUsers: r.activeUsers
      })).reverse()
    });
  } catch (error) {
    console.error('月度报表查询错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

/**
 * GET /api/admin/usage/user/:userId
 * 指定用户的用量明细
 * Query: ?month=2026-03&page=1&limit=20
 */
router.get('/usage/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const month = req.query.month || '';
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const skip = (page - 1) * limit;

    const query = { userId };
    if (month) {
      query.yearMonth = month;
    }

    const [records, total] = await Promise.all([
      UsageRecord.find(query).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      UsageRecord.countDocuments(query)
    ]);

    res.json({
      success: true,
      data: {
        records,
        pagination: { page, limit, total, totalPages: Math.ceil(total / limit) }
      }
    });
  } catch (error) {
    console.error('用户用量明细查询错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

/**
 * GET /api/admin/usage/ranking
 * 用量排行榜
 * Query: ?month=2026-03&type=voice|token&limit=20
 */
router.get('/usage/ranking', async (req, res) => {
  try {
    const month = req.query.month || '';
    const type = req.query.type || 'voice'; // voice or token
    const limit = parseInt(req.query.limit) || 20;

    const matchStage = {};
    if (month) {
      matchStage.yearMonth = month;
    }

    const sortField = type === 'voice' ? 'voiceSeconds' : 'totalTokens';
    const countField = type === 'voice' ? 'voiceCount' : 'tokenCount';

    const results = await UsageSummary.aggregate([
      { $match: matchStage },
      {
        $group: {
          _id: '$userId',
          amount: { $sum: `$${sortField}` },
          count: { $sum: `$${countField}` }
        }
      },
      { $sort: { amount: -1 } },
      { $limit: limit }
    ]);

    // 关联用户信息
    const userIds = results.map(r => r._id);
    const users = await User.find({ userId: { $in: userIds } }).lean();
    const userMap = {};
    users.forEach(u => { userMap[u.userId] = u; });

    res.json({
      success: true,
      data: results.map(r => ({
        userId: r._id,
        amount: r.amount,
        count: r.count,
        user: userMap[r._id] || null
      }))
    });
  } catch (error) {
    console.error('用量排行榜查询错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

/**
 * POST /api/admin/users/:userId/membership
 * 修改用户会员时长
 * Body: { action: 'add_days', value: 30 }
 */
router.post('/users/:userId/membership', async (req, res) => {
  try {
    const { userId } = req.params;
    const { action, value } = req.body;

    if (action !== 'add_days' || typeof value !== 'number') {
      return res.status(400).json({ success: false, message: '无效的参数' });
    }

    const user = await User.findOne({ userId });
    if (!user) {
      return res.status(404).json({ success: false, message: '用户不存在' });
    }

    const now = Date.now();
    let currentExpireAt = user.membershipExpireAt || 0;

    // 如果目前已经是过期状态，从今天开始算起；否则在原有基础上累加
    if (currentExpireAt < now) {
      currentExpireAt = now;
    }

    let newExpireAt = currentExpireAt + value * 24 * 60 * 60 * 1000;

    // 判断新的过期时间是否有效
    if (newExpireAt > now) {
      user.membershipType = 'premium';
      user.membershipExpireAt = newExpireAt;
    } else {
      user.membershipType = 'basic';
      user.membershipExpireAt = 0;
    }

    await user.save();

    res.json({
      success: true,
      data: {
        userId: user.userId,
        membershipType: user.membershipType,
        membershipExpireAt: user.membershipExpireAt
      },
      message: value >= 0 ? `已为用户增加 ${value} 天会员有效时长` : `已为用户扣除 ${Math.abs(value)} 天会员有效时长`
    });
  } catch (error) {
    console.error('修改会员状态错误:', error.message);
    res.status(500).json({ success: false, message: '修改会员状态失败' });
  }
});

/**
 * POST /api/admin/users/:userId/credits
 * 为用户增减积分（管理后台专用）
 */
router.post('/users/:userId/credits', async (req, res) => {
  try {
    const { userId } = req.params;
    const { action, amount, reason } = req.body;
    
    if (!['add', 'deduct'].includes(action) || typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({ success: false, message: '无效的参数' });
    }

    const user = await User.findOne({ userId });
    if (!user) {
      return res.status(404).json({ success: false, message: '用户不存在' });
    }

    let account = await CreditAccount.findOne({ userId });
    if (!account) {
      account = new CreditAccount({ userId, balance: 0 });
    }

    let actualChange = amount;
    
    if (action === 'add') {
      account.balance += amount;
      account.totalEarned += amount;
    } else if (action === 'deduct') {
      if (account.balance < amount) {
        return res.status(400).json({ success: false, message: '用户积分余额不足' });
      }
      account.balance -= amount;
      account.totalConsumed += amount;
      actualChange = -amount;
    }

    await account.save();

    // 记录流水
    const tx = new CreditTransaction({
      userId,
      amount: Math.abs(actualChange),
      balanceAfter: account.balance,
      type: action === 'add' ? 'earn' : 'spend',
      source: 'admin_grant',
      description: reason || (action === 'add' ? '管理员充值' : '管理员扣除')
    });
    await tx.save();

    res.json({
      success: true,
      message: action === 'add' ? `已为用户增加 ${amount} 积分` : `已为用户扣除 ${amount} 积分`,
      data: {
        balance: account.balance
      }
    });
  } catch (error) {
    console.error('管理员增减积分失败:', error.message);
    res.status(500).json({ success: false, message: '操作失败' });
  }
});

/**
 * GET /api/admin/users/:userId/credit-transactions
 * 获取用户的积分变更流水
 */
router.get('/users/:userId/credit-transactions', async (req, res) => {
  try {
    const { userId } = req.params;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const [transactions, total] = await Promise.all([
      CreditTransaction.find({ userId }).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      CreditTransaction.countDocuments({ userId })
    ]);

    res.json({
      success: true,
      data: {
        transactions,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    console.error('获取积分流水失败:', error.message);
    res.status(500).json({ success: false, message: '查询账单失败' });
  }
});

/**
 * GET /api/admin/stats/credits
 * 积分大盘概览
 */
router.get('/stats/credits', async (req, res) => {
  try {
    // 汇总当前全站总积分持仓、历史总发放、历史总消耗
    const agg = await CreditAccount.aggregate([
      {
        $group: {
          _id: null,
          totalBalance: { $sum: '$balance' },
          totalEarned: { $sum: '$totalEarned' },
          totalConsumed: { $sum: '$totalConsumed' }
        }
      }
    ]);
    
    // 统计今日发放
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayAgg = await CreditTransaction.aggregate([
      { $match: { createdAt: { $gte: today }, amount: { $gt: 0 } } },
      { $group: { _id: null, todayIssued: { $sum: '$amount' } } }
    ]);
    
    // 统计本月消耗
    const thisMonthStart = new Date();
    thisMonthStart.setDate(1);
    thisMonthStart.setHours(0, 0, 0, 0);
    const monthAgg = await CreditTransaction.aggregate([
      { $match: { createdAt: { $gte: thisMonthStart }, amount: { $lt: 0 } } },
      { $group: { _id: null, monthConsumed: { $sum: '$amount' } } }
    ]);

    const stats = agg[0] || { totalBalance: 0, totalEarned: 0, totalConsumed: 0 };
    stats.todayIssued = todayAgg[0]?.todayIssued || 0;
    stats.monthConsumed = Math.abs(monthAgg[0]?.monthConsumed || 0);

    res.json({ success: true, data: stats });
  } catch (error) {
    console.error('积分大盘概览错误:', error.message);
    res.status(500).json({ success: false, message: '查询大盘失败' });
  }
});

/**
 * GET /api/admin/stats/overview
 * 增强版仪表盘概览（包含留存估算、增长率等）
 */
router.get('/stats/overview', async (req, res) => {
  try {
    const now = Date.now();
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const yesterday = new Date(today); yesterday.setDate(today.getDate() - 1);
    const last7Days = new Date(today); last7Days.setDate(today.getDate() - 7);
    const last30Days = new Date(today); last30Days.setDate(today.getDate() - 30);
    const prevMonth = new Date(); prevMonth.setMonth(prevMonth.getMonth() - 1, 1); prevMonth.setHours(0, 0, 0, 0);
    const prevMonthEnd = new Date(); prevMonthEnd.setDate(0); prevMonthEnd.setHours(23, 59, 59, 999);
    const thisMonthStart = new Date(); thisMonthStart.setDate(1); thisMonthStart.setHours(0, 0, 0, 0);

    const [
      totalUsers, activeMembers, expiredMembers,
      todayNew, last7New, last30New, prevMonthNew, thisMonthNew
    ] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({ membershipType: 'premium', membershipExpireAt: { $gt: now } }),
      User.countDocuments({ membershipType: 'premium', membershipExpireAt: { $lte: now, $gt: 0 } }),
      User.countDocuments({ createdAt: { $gte: today.getTime() } }),
      User.countDocuments({ createdAt: { $gte: last7Days.getTime() } }),
      User.countDocuments({ createdAt: { $gte: last30Days.getTime() } }),
      User.countDocuments({ createdAt: { $gte: prevMonth.getTime(), $lte: prevMonthEnd.getTime() } }),
      User.countDocuments({ createdAt: { $gte: thisMonthStart.getTime() } })
    ]);

    const totalMembers = activeMembers + expiredMembers;
    const conversionRate = totalUsers > 0 ? ((totalMembers / totalUsers) * 100).toFixed(1) : '0.0';
    const activeRate = totalUsers > 0 ? ((activeMembers / totalUsers) * 100).toFixed(1) : '0.0';

    res.json({
      success: true,
      data: {
        users: { total: totalUsers, todayNew, last7New, last30New, thisMonthNew, prevMonthNew },
        membership: {
          activeMembers, expiredMembers, totalEver: totalMembers,
          conversionRate: parseFloat(conversionRate),
          activeRate: parseFloat(activeRate)
        }
      }
    });
  } catch (error) {
    console.error('增强概览查询错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

/**
 * GET /api/admin/revenue/monthly
 * 月度付费统计（按月统计新增付费用户、当前在有效期内的会员）
 * 基于 membershipExpireAt 反推：到期时间在某月之后 = 该月期间有有效会籍
 * Query: ?months=12
 */
router.get('/revenue/monthly', async (req, res) => {
  try {
    const months = parseInt(req.query.months) || 12;
    const now = new Date();
    const rows = [];

    for (let i = months - 1; i >= 0; i--) {
      const start = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const end = new Date(now.getFullYear(), now.getMonth() - i + 1, 0, 23, 59, 59, 999);
      const label = `${start.getFullYear()}-${String(start.getMonth() + 1).padStart(2, '0')}`;

      const [newUsers, membersAtPeak] = await Promise.all([
        // 该月新注册用户数
        User.countDocuments({ createdAt: { $gte: start.getTime(), $lte: end.getTime() } }),
        // 该月曾经持有有效会员的用户（到期时间 >= 月初 且 加入时间 <= 月末）
        User.countDocuments({
          membershipExpireAt: { $gte: start.getTime() },
          membershipType: 'premium'
        })
      ]);

      // 新增付费用户：本月注册且拥有会员记录的近似值
      const newPaidUsers = await User.countDocuments({
        createdAt: { $gte: start.getTime(), $lte: end.getTime() },
        membershipType: 'premium'
      });

      rows.push({ yearMonth: label, newUsers, membersAtPeak, newPaidUsers });
    }

    res.json({ success: true, data: rows });
  } catch (error) {
    console.error('月度付费统计错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

/**
 * GET /api/admin/revenue/users
 * 付费用户列表（可排序、筛选状态）
 * Query: ?status=active|expired|all&page=1&limit=20&search=
 */
router.get('/revenue/users', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const status = req.query.status || 'active'; // active/expired/all
    const search = req.query.search || '';
    const skip = (page - 1) * limit;
    const now = Date.now();

    const query = { membershipType: 'premium' };
    if (status === 'active') query.membershipExpireAt = { $gt: now };
    if (status === 'expired') query.membershipExpireAt = { $lte: now };
    if (search) {
      query.$or = [
        { account: { $regex: search, $options: 'i' } },
        { nickname: { $regex: search, $options: 'i' } },
        { displayId: { $regex: search, $options: 'i' } }
      ];
    }

    const [users, total] = await Promise.all([
      User.find(query)
        .sort({ membershipExpireAt: status === 'expired' ? -1 : 1 })
        .skip(skip).limit(limit).lean(),
      User.countDocuments(query)
    ]);

    // 计算会员剩余天数
    const enriched = users.map(u => ({
      ...u,
      remainingDays: u.membershipExpireAt > now
        ? Math.ceil((u.membershipExpireAt - now) / (24 * 60 * 60 * 1000))
        : 0,
      isActive: u.membershipExpireAt > now
    }));

    res.json({
      success: true,
      data: {
        users: enriched,
        pagination: { page, limit, total, totalPages: Math.ceil(total / limit) }
      }
    });
  } catch (error) {
    console.error('付费用户列表查询错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

/**
 * GET /api/admin/revenue/expiring
 * 即将到期的会员（7天内到期，用于预警）
 * Query: ?days=7
 */
router.get('/revenue/expiring', async (req, res) => {
  try {
    const days = parseInt(req.query.days) || 7;
    const now = Date.now();
    const deadline = now + days * 24 * 60 * 60 * 1000;

    const users = await User.find({
      membershipType: 'premium',
      membershipExpireAt: { $gt: now, $lte: deadline }
    }).sort({ membershipExpireAt: 1 }).limit(50).lean();

    res.json({
      success: true,
      data: users.map(u => ({
        userId: u.userId, displayId: u.displayId,
        nickname: u.nickname, account: u.account,
        membershipExpireAt: u.membershipExpireAt,
        remainingDays: Math.ceil((u.membershipExpireAt - now) / (24 * 60 * 60 * 1000))
      }))
    });
  } catch (error) {
    console.error('即将到期查询错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

module.exports = router;

