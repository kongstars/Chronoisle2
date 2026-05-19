require('dotenv').config({ path: '../.env.development' });
const mongoose = require('mongoose');
const Announcement = require('../models/Announcement');

async function sendAnnouncement() {
  await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/chronoisle');
  console.log('Connected to DB');

  const args = process.argv.slice(2);
  const title = args[0] || '系统重要更新公告';
  const subtitle = args[1] || '点击查看最新功能和活动详情';
  const url = args[2] || 'https://chronoisle.com/releases';

  const newAnnounce = new Announcement({
    title,
    subtitle,
    url,
    active: true
  });

  await newAnnounce.save();
  console.log('Successfully created announcement:', newAnnounce);
  
  process.exit(0);
}

sendAnnouncement().catch(console.error);
