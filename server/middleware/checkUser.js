const checkUser = (req, res, next) => {
  if (!req.user || !req.user.userId) {
    return res.status(401).json({ success: false, message: '身份认证失败' });
  }
  next();
};

module.exports = checkUser;
