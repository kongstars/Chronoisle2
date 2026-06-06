const express = require('express');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const User = require('../models/User');
const CreditAccount = require('../models/CreditAccount');
const CreditTransaction = require('../models/CreditTransaction');
const OAuthService = require('../services/OAuthService');

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('JWT_SECRET must be set');
  }
  console.warn('WARNING: JWT_SECRET not set, using insecure default for development only');
}
const _JWT_SECRET = JWT_SECRET || 'chronoisle-dev-insecure-key-do-not-use-in-production';
const REGISTER_BONUS = 50;
const OAUTH_STATE_TTL_MS = 10 * 60 * 1000;

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
const APP_URL_SCHEME = /^[a-z][a-z0-9+.-]*:\/\//i.test(String(process.env.APP_URL_SCHEME || '').trim())
  ? String(process.env.APP_URL_SCHEME || '').trim()
  : 'sishiqingdan://';

function getOAuthStateSecret() {
  const secret = String(process.env.OAUTH_STATE_SECRET || _JWT_SECRET || '').trim();
  if (!secret) {
    throw new Error('OAUTH_STATE_SECRET_NOT_CONFIGURED');
  }
  return secret;
}

function toBase64Url(input) {
  return Buffer.from(input).toString('base64url');
}

function fromBase64Url(input) {
  return Buffer.from(String(input || ''), 'base64url').toString('utf8');
}

function signOAuthState(payload) {
  return crypto.createHmac('sha256', getOAuthStateSecret()).update(payload).digest('base64url');
}

function createOAuthState(platform) {
  const payload = JSON.stringify({
    platform,
    nonce: crypto.randomBytes(12).toString('hex'),
    ts: Date.now()
  });
  return `${toBase64Url(payload)}.${signOAuthState(payload)}`;
}

function verifyOAuthState(state, expectedPlatform) {
  const raw = String(state || '').trim();
  const [payloadPart, signaturePart] = raw.split('.');
  if (!payloadPart || !signaturePart) {
    return false;
  }

  let payloadText = '';
  try {
    payloadText = fromBase64Url(payloadPart);
  } catch (error) {
    return false;
  }

  const expectedSignature = signOAuthState(payloadText);
  const signatureBuffer = Buffer.from(signaturePart);
  const expectedBuffer = Buffer.from(expectedSignature);
  if (signatureBuffer.length !== expectedBuffer.length || !crypto.timingSafeEqual(signatureBuffer, expectedBuffer)) {
    return false;
  }

  try {
    const payload = JSON.parse(payloadText);
    const ts = Number(payload?.ts || 0);
    return payload?.platform === expectedPlatform && Number.isFinite(ts) && (Date.now() - ts) <= OAUTH_STATE_TTL_MS;
  } catch (error) {
    return false;
  }
}

function redirectAppSuccess(res, payload) {
  const fragment = new URLSearchParams({
    token: String(payload.token || ''),
    userId: String(payload.userId || ''),
    nickname: String(payload.nickname || ''),
    avatar: String(payload.avatar || '')
  }).toString();
  return res.redirect(`${APP_URL_SCHEME}oauth_success#${fragment}`);
}

function redirectAppError(res, message) {
  const fragment = new URLSearchParams({
    message: String(message || '登录失败')
  }).toString();
  return res.redirect(`${APP_URL_SCHEME}oauth_error#${fragment}`);
}

/**
 * 获取第三方登录URL
 * GET /api/auth/oauth/url
 */
router.get('/url', (req, res) => {
  const platform = String(req.query.platform || '').trim();
  const state = createOAuthState(platform);
  
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
    return redirectAppError(res, '授权失败');
  }

  if (!verifyOAuthState(state, 'wechat')) {
    return redirectAppError(res, '授权状态无效，请重新发起登录');
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
    return redirectAppSuccess(res, {
      token,
      userId: user.userId,
      nickname: user.nickname,
      avatar: user.avatar
    });
    
  } catch (error) {
    console.error('微信登录回调错误:', error);
    return redirectAppError(res, error.message);
  }
});

/**
 * QQ登录回调
 * GET /api/auth/qq/callback
 */
router.get('/qq/callback', async (req, res) => {
  const { code, state } = req.query;
  
  if (!code) {
    return redirectAppError(res, '授权失败');
  }

  if (!verifyOAuthState(state, 'qq')) {
    return redirectAppError(res, '授权状态无效，请重新发起登录');
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
    return redirectAppSuccess(res, {
      token,
      userId: user.userId,
      nickname: user.nickname,
      avatar: user.avatar
    });
    
  } catch (error) {
    console.error('QQ登录回调错误:', error);
    return redirectAppError(res, error.message);
  }
});

/**
 * 华为登录回调
 * GET /api/auth/oauth/huawei/callback
 */
router.get('/huawei/callback', async (req, res) => {
  const { code, state } = req.query;
  
  if (!code) {
    return redirectAppError(res, '华为授权失败');
  }

  if (!verifyOAuthState(state, 'huawei')) {
    return redirectAppError(res, '授权状态无效，请重新发起登录');
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
    return redirectAppSuccess(res, {
      token,
      userId: user.userId,
      nickname: user.nickname || user.account,
      avatar: user.avatar || ''
    });
    
  } catch (error) {
    console.error('华为登录回调错误:', error);
    return redirectAppError(res, error.message);
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
