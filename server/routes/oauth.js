const express = require('express');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const CreditAccount = require('../models/CreditAccount');
const CreditTransaction = require('../models/CreditTransaction');
const OAuthService = require('../services/OAuthService');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || (function() { throw new Error('JWT_SECRET must be set'); })();
const REGISTER_BONUS = 50;

async function grantRegisterBonus(userId) {
  try {
    const existing = await CreditAccount.findOne({ userId });
    if (existing) return; // 已有账户不重复赠送
    const account = new CreditAccount({
      userId, balance: REGISTER_BONUS, totalEarned: REGISTER_BONUS,
      totalSpent: 0, lastGrantMonth: '', createdAt: Date.now()
    });
    await account.save();
    await new CreditTransaction({
      userId, type: 'earn', amount: REGISTER_BONUS, source: 'register_bonus',
      description: '注册赠送积分', balanceAfter: REGISTER_BONUS, createdAt: Date.now()
    }).save();
  } catch (e) {
    console.warn('OAuth赠送注册积分失败:', e.message);
  }
}
const APP_URL_SCHEME = process.env.APP_URL_SCHEME || 'sishiqingdan://';

/**
 * 获取第三方登录URL
 * GET /api/auth/oauth/url
 */
router.get('/url', (req, res) => {
  const { platform, state } = req.query;
  
  let authUrl;
  switch (platform) {
    case 'wechat':
      authUrl = OAuthService.getWeChatAuthUrl(state);
      break;
    case 'qq':
      authUrl = OAuthService.getQQAuthUrl(state);
      break;
    case 'huawei':
      authUrl = OAuthService.getHuaweiAuthUrl(state);
      break;
    default:
      return res.status(400).json({ 
        success: false, 
        message: '不支持的登录平台' 
      });
  }
  
  res.json({
    success: true,
    authUrl,
    platform
  });
});

/**
 * 微信登录回调
 * GET /api/auth/wechat/callback
 */
router.get('/wechat/callback', async (req, res) => {
  const { code, state } = req.query;
  
  if (!code) {
    return res.redirect(`${APP_URL_SCHEME}oauth_error?message=授权失败`);
  }
  
  try {
    // 1. 获取access_token
    const tokenResult = await OAuthService.getWeChatAccessToken(code);
    if (tokenResult.errcode) {
      throw new Error(`微信授权失败: ${tokenResult.errmsg}`);
    }
    
    const { access_token, openid, unionid } = tokenResult;
    
    // 2. 获取用户信息
    const userInfo = await OAuthService.getWeChatUserInfo(access_token, openid);
    
    // 3. 查找或创建用户
    let user = await User.findOne({ 
      accountType: 'wechat', 
      openId: openid 
    });
    
    if (!user) {
      const userId = `user_wechat_${openid}`;
      user = new User({
        userId,
        accountType: 'wechat',
        account: userInfo.nickname || `微信用户_${openid.substring(0, 8)}`,
        openId: openid,
        unionId: unionid,
        nickname: userInfo.nickname,
        avatar: userInfo.headimgurl || '',
        createdAt: Date.now(),
        lastLoginAt: Date.now()
      });
      await user.save();
      await grantRegisterBonus(userId);
    } else {
      // 更新最后登录时间和用户信息
      user.lastLoginAt = Date.now();
      user.nickname = userInfo.nickname || user.nickname;
      user.avatar = userInfo.headimgurl || user.avatar;
      await user.save();
    }
    
    // 4. 生成JWT
    const token = jwt.sign({ 
      userId: user.userId, 
      accountType: user.accountType,
      account: user.account,
      openId: user.openId 
    }, _JWT_SECRET, { expiresIn: '30d' });
    
    // 5. 重定向回应用
    const redirectUrl = `${APP_URL_SCHEME}oauth_success?token=${token}&userId=${user.userId}&nickname=${encodeURIComponent(user.nickname)}&avatar=${encodeURIComponent(user.avatar)}`;
    res.redirect(redirectUrl);
    
  } catch (error) {
    console.error('微信登录回调错误:', error);
    res.redirect(`${APP_URL_SCHEME}oauth_error?message=${encodeURIComponent(error.message)}`);
  }
});

/**
 * QQ登录回调
 * GET /api/auth/qq/callback
 */
router.get('/qq/callback', async (req, res) => {
  const { code, state } = req.query;
  
  if (!code) {
    return res.redirect(`${APP_URL_SCHEME}oauth_error?message=授权失败`);
  }
  
  try {
    // 1. 获取access_token
    const tokenResult = await OAuthService.getQQAccessToken(code);
    if (tokenResult.error) {
      throw new Error(`QQ授权失败: ${tokenResult.error_description}`);
    }
    
    const accessToken = tokenResult.access_token;
    
    // 2. 获取openId
    const openIdResult = await OAuthService.getQQOpenId(accessToken);
    const openId = openIdResult.openid;
    
    // 3. 获取用户信息
    const userInfo = await OAuthService.getQQUserInfo(accessToken, openId);
    if (userInfo.ret !== 0) {
      throw new Error(`获取QQ用户信息失败: ${userInfo.msg}`);
    }
    
    // 4. 查找或创建用户
    let user = await User.findOne({ 
      accountType: 'qq', 
      openId: openId 
    });
    
    if (!user) {
      const userId = `user_qq_${openId}`;
      user = new User({
        userId,
        accountType: 'qq',
        account: userInfo.nickname || `QQ用户_${openId.substring(0, 8)}`,
        openId: openId,
        nickname: userInfo.nickname,
        avatar: userInfo.figureurl_qq_2 || userInfo.figureurl_qq_1 || '',
        createdAt: Date.now(),
        lastLoginAt: Date.now()
      });
      await user.save();
      await grantRegisterBonus(userId);
    } else {
      // 更新最后登录时间和用户信息
      user.lastLoginAt = Date.now();
      user.nickname = userInfo.nickname || user.nickname;
      user.avatar = userInfo.figureurl_qq_2 || userInfo.figureurl_qq_1 || user.avatar;
      await user.save();
    }
    
    // 5. 生成JWT
    const token = jwt.sign({ 
      userId: user.userId, 
      accountType: user.accountType,
      account: user.account,
      openId: user.openId 
    }, _JWT_SECRET, { expiresIn: '30d' });
    
    // 6. 重定向回应用
    const redirectUrl = `${APP_URL_SCHEME}oauth_success?token=${token}&userId=${user.userId}&nickname=${encodeURIComponent(user.nickname)}&avatar=${encodeURIComponent(user.avatar)}`;
    res.redirect(redirectUrl);
    
  } catch (error) {
    console.error('QQ登录回调错误:', error);
    res.redirect(`${APP_URL_SCHEME}oauth_error?message=${encodeURIComponent(error.message)}`);
  }
});

/**
 * 华为登录回调
 * GET /api/auth/oauth/huawei/callback
 */
router.get('/huawei/callback', async (req, res) => {
  const { code, state } = req.query;
  
  if (!code) {
    return res.redirect(`${APP_URL_SCHEME}oauth_error?message=${encodeURIComponent('华为授权失败')}`);
  }
  
  try {
    // 1. 用授权码换取 access_token
    const tokenResult = await OAuthService.getHuaweiAccessToken(code);
    if (tokenResult.error) {
      throw new Error(`华为授权失败: ${tokenResult.error_description || tokenResult.error}`);
    }
    
    const { access_token, open_id } = tokenResult;
    
    // 2. 获取用户信息
    let nickname = '';
    let avatar = '';
    let openId = open_id || '';
    
    try {
      const userInfo = await OAuthService.getHuaweiUserInfo(access_token);
      nickname = userInfo.displayName || userInfo.nickName || '';
      avatar = userInfo.headPictureURL || '';
      if (!openId && userInfo.openID) {
        openId = userInfo.openID;
      }
    } catch (userInfoErr) {
      console.warn('获取华为用户详情失败，使用基础信息:', userInfoErr.message);
    }
    
    if (!openId) {
      throw new Error('无法获取华为用户标识');
    }
    
    // 3. 查找或创建用户
    let user = await User.findOne({ 
      accountType: 'huawei', 
      openId: openId 
    });
    
    if (!user) {
      const userId = `user_huawei_${openId.substring(0, 16)}`;
      user = new User({
        userId,
        accountType: 'huawei',
        account: nickname || `华为用户_${openId.substring(0, 8)}`,
        openId: openId,
        nickname: nickname,
        avatar: avatar,
        createdAt: Date.now(),
        lastLoginAt: Date.now()
      });
      await user.save();
      await grantRegisterBonus(userId);
    } else {
      user.lastLoginAt = Date.now();
      if (nickname) user.nickname = nickname;
      if (avatar) user.avatar = avatar;
      await user.save();
    }
    
    // 4. 生成JWT
    const token = jwt.sign({ 
      userId: user.userId, 
      accountType: user.accountType,
      account: user.account,
      openId: user.openId 
    }, _JWT_SECRET, { expiresIn: '30d' });
    
    // 5. 重定向回应用
    const redirectUrl = `${APP_URL_SCHEME}oauth_success?token=${token}&userId=${user.userId}&nickname=${encodeURIComponent(user.nickname || user.account)}&avatar=${encodeURIComponent(user.avatar || '')}`;
    res.redirect(redirectUrl);
    
  } catch (error) {
    console.error('华为登录回调错误:', error);
    res.redirect(`${APP_URL_SCHEME}oauth_error?message=${encodeURIComponent(error.message)}`);
  }
});

/**
 * 第三方登录状态检查
 * POST /api/auth/oauth/verify
 */
router.post('/verify', async (req, res) => {
  const { token } = req.body;
  
  if (!token) {
    return res.status(400).json({
      success: false,
      message: '缺少token参数'
    });
  }
  
  try {
    const decoded = jwt.verify(token, _JWT_SECRET);
    const user = await User.findOne({ userId: decoded.userId });
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: '用户不存在'
      });
    }
    
    res.json({
      success: true,
      user: {
        userId: user.userId,
        accountType: user.accountType,
        account: user.account,
        nickname: user.nickname,
        avatar: user.avatar,
        createdAt: user.createdAt
      },
      token
    });
    
  } catch (error) {
    console.error('Token验证失败:', error);
    res.status(401).json({
      success: false,
      message: 'Token无效或已过期'
    });
  }
});

module.exports = router;
