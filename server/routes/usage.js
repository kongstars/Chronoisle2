const express = require('express');
const UsageRecord = require('../models/UsageRecord');
const UsageSummary = require('../models/UsageSummary');

const { getCurrentYearMonth } = require('../utils/date');

const router = express.Router();

/**
 * 更新月度汇总
 */
async function updateMonthlySummary(userId, type, amount, detail) {
  const yearMonth = getCurrentYearMonth();
  const update = {
    $inc: {},
    $set: { updatedAt: Date.now() }
  };

  if (type === 'voice') {
    update.$inc.voiceSeconds = amount;
    update.$inc.voiceCount = 1;
  } else if (type === 'token') {
    update.$inc.totalTokens = amount;
    update.$inc.tokenCount = 1;
    if (detail) {
      update.$inc.inputTokens = detail.inputTokens || 0;
      update.$inc.outputTokens = detail.outputTokens || 0;
    }
  } else if (type === 'ai_feature') {
    if (detail && detail.feature && detail.action) {
      update.$inc[`aiFeatureUsage.${detail.feature}.${detail.action}s`] = amount;
    }
  }

  await UsageSummary.findOneAndUpdate(
    { userId, yearMonth },
    update,
    { upsert: true, new: true }
  );
}

/**
 * POST /api/usage/report
 * 客户端上报用量（主要用于语音时长）
 */
router.post('/report', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { type, amount, detail } = req.body;

    if (!type || !['voice', 'token', 'ai_feature'].includes(type)) {
      return res.status(400).json({ success: false, message: '无效的用量类型' });
    }
    if (!amount || amount <= 0) {
      return res.status(400).json({ success: false, message: '用量数值无效' });
    }

    const yearMonth = getCurrentYearMonth();

    // 写入明细记录
    const record = new UsageRecord({
      userId,
      type,
      amount,
      detail: detail || {},
      yearMonth,
      createdAt: Date.now()
    });
    await record.save();

    // 更新月度汇总
    await updateMonthlySummary(userId, type, amount, detail);

    res.json({ success: true, message: '用量记录成功' });
  } catch (error) {
    console.error('用量上报错误:', error.message);
    res.status(500).json({ success: false, message: '用量记录失败' });
  }
});

/**
 * GET /api/usage/my
 * 当前用户查看自己的用量
 * Query: ?month=2026-03 (可选，默认当月)
 */
router.get('/my', async (req, res) => {
  try {
    const userId = req.user.userId;
    const month = req.query.month || getCurrentYearMonth();

    // 当月汇总
    const monthlySummary = await UsageSummary.findOne({ userId, yearMonth: month });

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

    res.json({
      success: true,
      data: {
        monthly: monthlySummary ? {
          yearMonth: monthlySummary.yearMonth,
          voiceSeconds: monthlySummary.voiceSeconds,
          totalTokens: monthlySummary.totalTokens,
          inputTokens: monthlySummary.inputTokens,
          outputTokens: monthlySummary.outputTokens,
          voiceCount: monthlySummary.voiceCount,
          tokenCount: monthlySummary.tokenCount,
          aiFeatureUsage: monthlySummary.aiFeatureUsage || {}
        } : null,
        cumulative: totalAgg[0] || {
          voiceSeconds: 0,
          totalTokens: 0,
          inputTokens: 0,
          outputTokens: 0,
          voiceCount: 0,
          tokenCount: 0
        }
      }
    });
  } catch (error) {
    console.error('用量查询错误:', error.message);
    res.status(500).json({ success: false, message: '查询失败' });
  }
});

// 导出 updateMonthlySummary 供 index.js 中 Token 自动记录使用
router.updateMonthlySummary = updateMonthlySummary;
router.getCurrentYearMonth = getCurrentYearMonth;

module.exports = router;
