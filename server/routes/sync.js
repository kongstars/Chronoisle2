const express = require('express');
const SyncData = require('../models/SyncData');

const router = express.Router();

const checkUser = require('../middleware/checkUser');

router.get('/data', checkUser, async (req, res) => {
  try {
    const userId = req.user.userId;
    const updatedSince = req.query.updatedSince ? Number(req.query.updatedSince) : 0;

    // 先轻量查询 updatedAt 判断是否需要全量传输
    const metaOnly = await SyncData.findOne({ userId }).select({ updatedAt: 1 });

    if (!metaOnly) {
      return res.json({
        success: true,
        data: { goals: [], tasks: [], dayEvents: [], pomodoros: [], updatedAt: 0 }
      });
    }

    // 若客户端已持有最新版本，返回空数据 + unchanged 标记，减少传输量
    if (updatedSince > 0 && metaOnly.updatedAt && metaOnly.updatedAt <= updatedSince) {
      return res.json({
        success: true,
        unchanged: true,
        data: { goals: [], tasks: [], dayEvents: [], pomodoros: [], updatedAt: metaOnly.updatedAt }
      });
    }

    // 需要全量数据时才加载所有数组
    const syncData = await SyncData.findOne({ userId });

    res.json({
      success: true,
      data: {
        goals: syncData.goals,
        tasks: syncData.tasks,
        dayEvents: syncData.dayEvents || [],
        pomodoros: syncData.pomodoros || [],
        updatedAt: syncData.updatedAt
      }
    });
  } catch (error) {
    console.error('获取同步数据失败:', error);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

router.post('/data', checkUser, async (req, res) => {
  try {
    const userId = req.user.userId;
    const { goals = [], tasks = [], dayEvents = [], pomodoros = [] } = req.body;

    let syncData = await SyncData.findOne({ userId });
    if (!syncData) {
      syncData = new SyncData({ userId });
    }

    syncData.goals = goals;
    syncData.tasks = tasks;
    syncData.dayEvents = dayEvents;
    syncData.pomodoros = pomodoros;
    syncData.updatedAt = Date.now();

    await syncData.save();

    res.json({
      success: true,
      message: '数据同步成功',
      updatedAt: syncData.updatedAt
    });
  } catch (error) {
    console.error('上传同步数据失败:', error);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

module.exports = router;
