const express = require('express');
const TelemetryEvent = require('../models/TelemetryEvent');
const User = require('../models/User');
const { adminAuthenticate } = require('../middleware/adminAuth');

const router = express.Router();

function clampInt(value, fallback, min, max) {
  const parsed = parseInt(String(value || fallback), 10);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return Math.min(Math.max(parsed, min), max);
}

function escapeRegex(value) {
  return String(value || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function buildSafeContainsRegex(value) {
  const normalized = String(value || '').trim().slice(0, 64);
  if (!normalized) {
    return null;
  }
  return new RegExp(escapeRegex(normalized), 'i');
}

// ============================================================
// 客户端上报接口（需用户登录，由 index.js 的 authenticate 中间件保护）
// ============================================================

/**
 * POST /api/telemetry/event
 * 单条事件上报
 */
router.post('/event', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { eventName, eventCategory, properties, platform, appVersion, sessionId } = req.body;

    if (!eventName || !eventCategory) {
      return res.status(400).json({ success: false, message: '缺少必要字段' });
    }

    await TelemetryEvent.create({
      userId,
      eventName,
      eventCategory: eventCategory || 'other',
      properties: properties || {},
      platform: platform || 'harmonyos',
      appVersion: appVersion || '',
      sessionId: sessionId || '',
      createdAt: Date.now()
    });

    // 同时更新用户的最后活跃时间和版本信息
    const updateFields = { lastActiveAt: Date.now() };
    if (appVersion) updateFields.appVersion = appVersion;

    await User.updateOne({ userId }, { $set: updateFields });

    res.json({ success: true });
  } catch (error) {
    console.error('埋点上报错误(单条):', error.message);
    res.status(500).json({ success: false, message: '上报失败' });
  }
});

/**
 * POST /api/telemetry/batch
 * 批量事件上报（最多 50 条，App 进入后台时调用）
 */
router.post('/batch', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { events, appVersion } = req.body;

    if (!Array.isArray(events) || events.length === 0) {
      return res.status(400).json({ success: false, message: '事件列表为空' });
    }

    // 限制单次上报数量，防止恶意请求
    const safeEvents = events.slice(0, 50);

    const docs = safeEvents
      .filter(e => e.eventName && e.eventCategory)
      .map(e => ({
        userId,
        eventName: e.eventName,
        eventCategory: e.eventCategory || 'other',
        properties: e.properties || {},
        platform: e.platform || 'harmonyos',
        appVersion: e.appVersion || appVersion || '',
        sessionId: e.sessionId || '',
        createdAt: e.createdAt || Date.now()
      }));

    if (docs.length > 0) {
      await TelemetryEvent.insertMany(docs, { ordered: false }); // ordered:false 跳过单条错误继续插入
    }

    // 更新用户活跃时间
    const updateFields = { lastActiveAt: Date.now() };
    if (appVersion) updateFields.appVersion = appVersion;
    await User.updateOne({ userId }, { $set: updateFields });

    res.json({ success: true, accepted: docs.length });
  } catch (error) {
    console.error('埋点批量上报错误:', error.message);
    res.status(500).json({ success: false, message: '批量上报失败' });
  }
});

// ============================================================
// 管理后台查询接口（需 adminAuthenticate 中间件）
// ============================================================
router.use(adminAuthenticate);

/**
 * GET /api/telemetry/admin/top-events
 * 全局 Top N 事件统计
 * Query: ?days=7&limit=20&category=ai
 */
router.get('/admin/top-events', async (req, res) => {
  try {
    const days = clampInt(req.query.days, 7, 1, 90);
    const limit = clampInt(req.query.limit, 20, 1, 100);
    const category = req.query.category || '';

    const since = Date.now() - days * 24 * 60 * 60 * 1000;
    const match = { createdAt: { $gte: since } };
    if (category) match.eventCategory = category;

    const results = await TelemetryEvent.aggregate([
      { $match: match },
      { $group: { _id: '$eventName', count: { $sum: 1 }, uniqueUsers: { $addToSet: '$userId' } } },
      { $project: { eventName: '$_id', count: 1, uniqueUsers: { $size: '$uniqueUsers' } } },
      { $sort: { count: -1 } },
      { $limit: limit }
    ]);

    res.json({ success: true, data: results, days });
  } catch (error) {
    console.error('Top事件查询错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

/**
 * GET /api/telemetry/admin/events
 * 事件流查询（按用户/时间/类型筛选）
 * Query: ?userId=xxx&eventName=xxx&category=ai&days=7&page=1&limit=30
 */
router.get('/admin/events', async (req, res) => {
  try {
    const { userId, eventName, category } = req.query;
    const days = clampInt(req.query.days, 7, 1, 90);
    const page = clampInt(req.query.page, 1, 1, 100000);
    const limit = clampInt(req.query.limit, 30, 1, 100);
    const skip = (page - 1) * limit;
    const eventNameRegex = buildSafeContainsRegex(eventName);

    const since = Date.now() - days * 24 * 60 * 60 * 1000;
    const match = { createdAt: { $gte: since } };
    if (userId) match.userId = userId;
    if (eventNameRegex) match.eventName = eventNameRegex;
    if (category) match.eventCategory = category;

    const [events, total] = await Promise.all([
      TelemetryEvent.find(match).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      TelemetryEvent.countDocuments(match)
    ]);

    res.json({
      success: true,
      data: { events, pagination: { page, limit, total, totalPages: Math.ceil(total / limit) } }
    });
  } catch (error) {
    console.error('事件流查询错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

/**
 * GET /api/telemetry/admin/daily-trend
 * 每日事件量趋势（最近 N 天，按事件分类统计）
 * Query: ?days=14
 */
router.get('/admin/daily-trend', async (req, res) => {
  try {
    const days = clampInt(req.query.days, 14, 1, 90);
    const since = Date.now() - days * 24 * 60 * 60 * 1000;

    const results = await TelemetryEvent.aggregate([
      { $match: { createdAt: { $gte: since } } },
      {
        $group: {
          _id: {
            date: {
              $dateToString: {
                format: '%Y-%m-%d',
                date: { $toDate: '$createdAt' },
                timezone: '+08:00'
              }
            },
            category: '$eventCategory'
          },
          count: { $sum: 1 }
        }
      },
      { $sort: { '_id.date': 1 } }
    ]);

    // 重组为 { date: { category: count } } 格式
    const grouped = {};
    results.forEach(r => {
      const { date, category } = r._id;
      if (!grouped[date]) grouped[date] = {};
      grouped[date][category] = r.count;
    });

    const trend = Object.entries(grouped).map(([date, categories]) => ({ date, ...categories }));

    res.json({ success: true, data: trend });
  } catch (error) {
    console.error('每日趋势查询错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

/**
 * GET /api/telemetry/admin/user/:userId
 * 指定用户的近期行为时间线
 * Query: ?limit=30
 */
router.get('/admin/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = clampInt(req.query.limit, 30, 1, 100);

    const events = await TelemetryEvent.find({ userId })
      .sort({ createdAt: -1 })
      .limit(limit)
      .lean();

    // 统计该用户各事件类型的总次数
    const stats = await TelemetryEvent.aggregate([
      { $match: { userId } },
      { $group: { _id: '$eventName', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 10 }
    ]);

    res.json({ success: true, data: { events, stats } });
  } catch (error) {
    console.error('用户行为时间线查询错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

module.exports = router;
