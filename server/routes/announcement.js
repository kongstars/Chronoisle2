const express = require('express');
const router = express.Router();
const Announcement = require('../models/Announcement');

// 获取当前生效的公告
router.get('/active', async (req, res) => {
  try {
    const now = Date.now();
    const activeAnnouncements = await Announcement.find({
      active: true,
      $or: [
        { expiresAt: 0 },
        { expiresAt: { $gt: now } }
      ]
    }).sort({ createdAt: -1 }).limit(20).select({ title: 1, subtitle: 1, url: 1, active: 1, createdAt: 1, expiresAt: 1 });

    res.json({
      success: true,
      data: activeAnnouncements.map(a => ({
        id: a._id.toString(),
        title: a.title,
        subtitle: a.subtitle,
        url: a.url,
        active: a.active,
        createdAt: a.createdAt,
        expiresAt: a.expiresAt
      }))
    });
  } catch (error) {
    console.error('Fetch active announcements error:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch announcements' });
  }
});

module.exports = router;
