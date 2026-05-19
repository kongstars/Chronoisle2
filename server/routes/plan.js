const express = require('express');
const PreGeneratedPlan = require('../models/PreGeneratedPlan');
const { getShanghaiDateString } = require('../utils/date');

const router = express.Router();

const checkUser = require('../middleware/checkUser');

/**
 * GET /api/plan/today
 * 获取当日预生成的计划
 */
router.get('/today', checkUser, async (req, res) => {
  try {
    const userId = req.user.userId;
    const today = getShanghaiDateString();

    const plan = await PreGeneratedPlan.findOne({
      userId,
      date: today,
      status: 'pending'
    });

    if (!plan) {
      return res.json({ success: false, message: '今日暂无预生成计划' });
    }

    res.json({
      success: true,
      data: {
        planData: plan.planData,
        taskSnapshot: plan.taskSnapshot,
        generatedAt: plan.generatedAt,
        date: plan.date
      }
    });
  } catch (error) {
    console.error('获取预生成计划失败:', error);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

/**
 * POST /api/plan/save
 * 采纳或更新今日计划，将其保存到云端
 */
router.post('/save', checkUser, async (req, res) => {
  try {
    const userId = req.user.userId;
    const today = getShanghaiDateString();
    const { adoptedPlanData } = req.body;

    const plan = await PreGeneratedPlan.findOneAndUpdate(
      { userId, date: today },
      { 
        $set: { 
          status: 'adopted',
          adoptedPlanData: adoptedPlanData || {}
        } 
      },
      { new: true, upsert: true }
    );

    res.json({ success: true, message: '今日计划已保存到云端' });
  } catch (error) {
    console.error('保存计划失败:', error);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

/**
 * GET /api/plan/adopted
 * 获取当日已采纳的计划
 */
router.get('/adopted', checkUser, async (req, res) => {
  try {
    const userId = req.user.userId;
    const today = getShanghaiDateString();

    const plan = await PreGeneratedPlan.findOne({
      userId,
      date: today,
      status: 'adopted'
    });

    if (!plan || !plan.adoptedPlanData) {
      return res.json({ success: false, message: '今日暂无已采纳计划' });
    }

    res.json({
      success: true,
      data: {
        adoptedPlanData: plan.adoptedPlanData,
        date: plan.date,
        adoptedAt: plan.generatedAt || Date.now()
      }
    });
  } catch (error) {
    console.error('获取已采纳计划失败:', error);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

// 移除原有的 /adopt 仅标记状态的接口，用 /save 取代

module.exports = router;
