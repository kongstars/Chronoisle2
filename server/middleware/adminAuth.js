const jwt = require('jsonwebtoken');

const ADMIN_JWT_SECRET = process.env.ADMIN_JWT_SECRET || 'chronoisle-admin-secret-2026';

/**
 * 管理员身份验证中间件
 */
function adminAuthenticate(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: '未登录，请先登录管理后台' });
  }

  const token = authHeader.substring(7);
  try {
    const decoded = jwt.verify(token, ADMIN_JWT_SECRET);
    if (decoded.role !== 'admin') {
      return res.status(403).json({ success: false, message: '无管理员权限' });
    }
    req.admin = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: '管理员Token无效或已过期' });
  }
}

/**
 * 生成管理员JWT
 */
function generateAdminToken(username) {
  return jwt.sign(
    { username, role: 'admin' },
    ADMIN_JWT_SECRET,
    { expiresIn: '7d' }
  );
}

module.exports = { adminAuthenticate, generateAdminToken };
