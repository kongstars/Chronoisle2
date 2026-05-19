const mongoose = require('mongoose');

const announcementSchema = new mongoose.Schema({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
  url: { type: String, default: '' },
  active: { type: Boolean, default: true },
  createdAt: { type: Number, default: () => Date.now() },
  expiresAt: { type: Number, default: 0 } // 0 means never expires
});

announcementSchema.index({ active: 1, expiresAt: 1, createdAt: -1 });

module.exports = mongoose.model('Announcement', announcementSchema);
