const jwt = require('jsonwebtoken');

function getAdminJwtSecret() {
  const secret = String(process.env.ADMIN_JWT_SECRET || '').trim();
  if (!secret) {
    throw new Error('ADMIN_JWT_SECRET_NOT_CONFIGURED');
  }
  return secret;
}

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
    const decoded = jwt.verify(token, getAdminJwtSecret());
    if (decoded.role !== 'admin') {
      return res.status(403).json({ success: false, message: '无管理员权限' });
    }
    req.admin = decoded;
    next();
  } catch (err) {
    if (err && err.message === 'ADMIN_JWT_SECRET_NOT_CONFIGURED') {
      return res.status(503).json({ success: false, message: '管理后台未完成安全配置' });
    }
    return res.status(401).json({ success: false, message: '管理员Token无效或已过期' });
  }
}

/**
 * 生成管理员JWT
 */
function generateAdminToken(username) {
  return jwt.sign(
    { username, role: 'admin' },
    getAdminJwtSecret(),
    { expiresIn: '7d' }
  );
}

module.exports = { adminAuthenticate, generateAdminToken };
