const { sendError } = require('../utils/apiResponse');

const checkUser = (req, res, next) => {
  if (!req.user || !req.user.userId) {
    return sendError(res, 401, 'AUTH_USER_REQUIRED', '身份认证失败');
  }
  next();
};

module.exports = checkUser;
