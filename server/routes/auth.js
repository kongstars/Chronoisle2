const express = require('express');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const IapOrder = require('../models/IapOrder');
const CreditAccount = require('../models/CreditAccount');
const CreditTransaction = require('../models/CreditTransaction');
const OAuthService = require('../services/OAuthService');

const router = express.Router();

const JWT_SECRET = process.env.JWT_SECRET || (function() { throw new Error('JWT_SECRET must be set'); })();

function buildUserPayload(user) {
  return {
    userId: user.userId,
    accountType: user.accountType,
    account: user.account,
    nickname: user.nickname || '',
    avatar: user.avatar,
    displayId: user.displayId,
    createdAt: user.createdAt,
    membershipType: user.membershipType || 'basic',
    membershipPlan: user.membershipPlan || '',
    membershipProductId: user.membershipProductId || '',
    membershipExpireAt: user.membershipExpireAt || 0,
    membershipRenewAt: user.membershipRenewAt || user.membershipExpireAt || 0,
    pendingMembershipPlan: user.pendingMembershipPlan || '',
    pendingMembershipProductId: user.pendingMembershipProductId || '',
    pendingMembershipEffectiveAt: user.pendingMembershipEffectiveAt || 0
  };
}
const REGISTER_BONUS = 50;  // 注册赠送积分

function getMembershipPlanByProductId(productId) {
  if (productId === 'vip_yearly_continuous') return 'yearly_continuous';
  if (productId === 'vip_monthly_continuous') return 'monthly_continuous';
  return '';
}

async function backfillMembershipSubscriptionFields(user) {
  if (!user || user.membershipType !== 'premium') return user;
  if (user.membershipPlan && user.membershipProductId && user.membershipRenewAt) return user;

  const now = Date.now();
  const activeOrder = await IapOrder.findOne({
    userId: user.userId,
    provider: 'huawei',
    productId: { $in: ['vip_monthly_continuous', 'vip_yearly_continuous'] },
    status: { $in: ['purchased', 'renewed', 'active', 'canceled'] },
    periodEndAt: { $gt: now }
  }).sort({ periodEndAt: -1 });

  if (!activeOrder) return user;

  user.membershipPlan = getMembershipPlanByProductId(activeOrder.productId);
  user.membershipProductId = activeOrder.productId;
  user.membershipExpireAt = activeOrder.periodEndAt;
  user.membershipRenewAt = activeOrder.periodEndAt;
  user.pendingMembershipPlan = '';
  user.pendingMembershipProductId = '';
  user.pendingMembershipEffectiveAt = 0;
  await user.save();
  return user;
}

/**
 * 为新注册用户创建积分账户并赠送注册积分
 */
async function grantRegisterBonus(userId) {
  try {
    const account = new CreditAccount({
      userId,
      balance: REGISTER_BONUS,
      totalEarned: REGISTER_BONUS,
      totalSpent: 0,
      lastGrantMonth: '',
      createdAt: Date.now()
    });
    await account.save();

    await new CreditTransaction({
      userId,
      type: 'earn',
      amount: REGISTER_BONUS,
      source: 'register_bonus',
      description: '注册赠送积分',
      balanceAfter: REGISTER_BONUS,
      createdAt: Date.now()
    }).save();

    console.log(`已为用户 ${userId} 赠送 ${REGISTER_BONUS} 注册积分`);
  } catch (e) {
    console.warn('赠送注册积分失败(不影响注册):', e.message);
  }
}

// 验证码内存缓存（模拟发送验证码，生产环境应通过短信/邮件服务真实下发）
const verificationCodes = new Map();

function parseHuaweiIdToken(idToken) {
  if (!idToken) {
    return {};
  }
  try {
    const segments = idToken.split('.');
    if (segments.length < 2) {
      return {};
    }
    const payload = segments[1].replace(/-/g, '+').replace(/_/g, '/');
    return JSON.parse(Buffer.from(payload, 'base64').toString('utf8'));
  } catch (error) {
    return {};
  }
}

router.post('/send-code', (req, res) => {
  const { accountType, account } = req.body;
  
  if (!account) {
    return res.status(400).json({ success: false, message: '账号不可为空' });
  }

  // 始终固定验证码为 123456 用于跑测试流程
  const code = '123456';
  const expiresAt = Date.now() + 5 * 60 * 1000;
  
  verificationCodes.set(`${accountType}:${account}`, { code, expiresAt });
  
  res.json({
    success: true,
    message: '验证码已发送'
  });
});

router.post('/register', async (req, res) => {
  const { accountType, account, code, avatar } = req.body;
  
  const record = verificationCodes.get(`${accountType}:${account}`);
  if (!record || record.code !== code || record.expiresAt < Date.now()) {
    return res.status(400).json({ success: false, message: '验证码无效或已过期' });
  }

  try {
    const existingUser = await User.findOne({ accountType, account });
    if (existingUser) {
      return res.status(400).json({ success: false, message: '账号已被注册' });
    }

    const userId = `user_${accountType}_${account.replace(/[^a-zA-Z0-9]/g, '_')}`;
    const newUser = new User({
      userId,
      accountType,
      account,
      avatar: avatar || ''
    });

    await newUser.save();
    verificationCodes.delete(`${accountType}:${account}`);

    // 赠送注册积分
    await grantRegisterBonus(userId);

    const token = jwt.sign({ userId, accountType, account }, _JWT_SECRET, { expiresIn: '30d' });

    res.json({
      success: true,
      message: '注册成功',
      token,
      user: buildUserPayload(newUser)
    });
  } catch (error) {
    console.error('注册错误:', error);
    res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

router.post('/login', async (req, res) => {
  const { accountType, account, code } = req.body;

  const record = verificationCodes.get(`${accountType}:${account}`);
  if (!record || record.code !== code || record.expiresAt < Date.now()) {
    return res.status(400).json({ success: false, message: '验证码无效或已过期' });
  }

  try {
    const user = await User.findOne({ accountType, account });
    if (!user) {
      return res.status(404).json({ success: false, message: '账号尚未注册' });
    }

    if (!user.displayId) {
      user.displayId = Math.floor(10000000 + Math.random() * 90000000).toString();
      await user.save();
    }

    verificationCodes.delete(`${accountType}:${account}`);
    
    const token = jwt.sign({ userId: user.userId, accountType: user.accountType, account: user.account }, _JWT_SECRET, { expiresIn: '30d' });

    res.json({
      success: true,
      message: '登录成功',
      data: {
        token,
        user: buildUserPayload(user)
      }
    });
  } catch (error) {
     console.error('登录错误:', error);
     res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

router.post('/huawei-login', async (req, res) => {
  const { huaweiId, authCode, idToken, nickName, avatarUri } = req.body;
  if (!huaweiId && !authCode) {
    return res.status(400).json({ success: false, message: '缺少必要参数：huaweiId 或 authCode' });
  }

  try {
    let openId = huaweiId || '';
    let nickname = nickName || '';
    let avatar = avatarUri || '';
    const idTokenPayload = parseHuaweiIdToken(idToken);
    
    // 从 idToken 中尝试提取更稳定的标识符
    if (idTokenPayload && idTokenPayload.sub) {
      openId = idTokenPayload.sub; // sub 是稳定的用户标识符
    }
    
    if (!nickname) {
      nickname = idTokenPayload.name || idTokenPayload.displayName || idTokenPayload.nickName || idTokenPayload.nickname || '';
    }
    if (!avatar) {
      avatar = idTokenPayload.picture || idTokenPayload.avatar || idTokenPayload.headPictureURL || '';
    }

    // 如果有 authCode，优先通过 OAuth 服务获取准确的用户信息
    if (authCode) {
      try {
        const tokenResult = await OAuthService.getHuaweiAccessToken(authCode);
        if (!tokenResult.error) {
          const accessToken = tokenResult.access_token || '';
          // 优先使用 OAuth 返回的 open_id，这是最稳定的标识符
          openId = tokenResult.open_id || tokenResult.sub || openId;
          if (accessToken) {
            const userInfo = await OAuthService.getHuaweiUserInfo(accessToken);
            nickname = userInfo.displayName || userInfo.nickName || nickname;
            avatar = userInfo.headPictureURL || avatar;
            openId = userInfo.openID || userInfo.sub || openId;
          }
        }
      } catch (error) {
        console.warn('华为用户资料同步失败:', error.message);
      }
    }

    if (!openId) {
      return res.status(400).json({ success: false, message: '无法获取用户标识符' });
    }

    // 使用 openId 作为主要查找条件，因为这是复合唯一索引的一部分
    let user = await User.findOne({
      accountType: 'huawei',
      openId: openId
    });
    
    // 如果通过 openId 找不到，尝试通过 huaweiId 查找（向后兼容）
    if (!user && huaweiId) {
      user = await User.findOne({
        accountType: 'huawei',
        $or: [
          { openId: huaweiId },
          { userId: `user_huawei_${huaweiId.replace(/[^a-zA-Z0-9]/g, '_')}` }
        ]
      });
      
      // 如果找到用户但 openId 不同，更新 openId 字段
      if (user && user.openId !== openId) {
        user.openId = openId;
        await user.save();
      }
    }

    const userId = user ? user.userId : `user_huawei_${openId.replace(/[^a-zA-Z0-9]/g, '_')}`;
    
    if (!user) {
      user = new User({
        userId,
        accountType: 'huawei',
        account: nickname || `华为用户_${openId.substring(0, 8)}`,
        openId: openId,
        nickname: nickname,
        avatar: avatar
      });
      await user.save();
      // 新注册用户赠送积分
      await grantRegisterBonus(userId);
    } else {
      user.lastLoginAt = Date.now();
      if (nickname && nickname !== user.nickname) {
        user.nickname = nickname;
      }
      if (avatar && avatar !== user.avatar) {
        user.avatar = avatar;
      }
      await user.save();
    }
    
    const token = jwt.sign({ userId: user.userId, accountType: user.accountType, account: user.account, openId: user.openId }, _JWT_SECRET, { expiresIn: '30d' });

    res.json({
      success: true,
      message: '登录成功',
      data: {
        token,
        user: buildUserPayload(user)
      }
    });
  } catch (error) {
     console.error('华为登录错误:', error);
     res.status(500).json({ success: false, message: '服务器内部错误' });
  }
});

/**
 * GET /api/auth/me
 * 获取当前登录用户的最新信息（从数据库读取，确保后台修改能即时反映）
 * 需要 Bearer Token
 */
router.get('/me', async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: '请先登录' });
  }

  try {
    const token = authHeader.substring(7);
    const decoded = jwt.verify(token, _JWT_SECRET);
    const userId = decoded.userId;

    const user = await User.findOne({ userId });
    if (!user) {
      return res.status(404).json({ success: false, message: '用户不存在' });
    }
    await backfillMembershipSubscriptionFields(user);

    res.json({
      success: true,
      data: buildUserPayload(user)
    });
  } catch (error) {
    console.error('获取用户信息失败:', error.message);
    res.status(401).json({ success: false, message: 'Token无效或已过期' });
  }
});

router.post('/profile', async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, message: 'Please sign in first' });
  }

  try {
    const token = authHeader.substring(7);
    const decoded = jwt.verify(token, _JWT_SECRET);
    const user = await User.findOne({ userId: decoded.userId });
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const { nickname, avatar } = req.body || {};
    let hasUpdate = false;

    if (typeof nickname === 'string') {
      const trimmedNickname = nickname.trim();
      if (!trimmedNickname) {
        return res.status(400).json({ success: false, message: 'Nickname cannot be empty' });
      }
      if (trimmedNickname.length > 24) {
        return res.status(400).json({ success: false, message: 'Nickname must be 24 characters or fewer' });
      }
      user.nickname = trimmedNickname;
      hasUpdate = true;
    }

    if (typeof avatar === 'string') {
      const trimmedAvatar = avatar.trim();
      if (trimmedAvatar.length > 1024) {
        return res.status(400).json({ success: false, message: 'Avatar URL is too long' });
      }
      user.avatar = trimmedAvatar;
      hasUpdate = true;
    }

    if (!hasUpdate) {
      return res.status(400).json({ success: false, message: 'No profile fields to update' });
    }

    user.lastActiveAt = Date.now();
    await user.save();

    res.json({
      success: true,
      message: 'Profile updated',
      data: buildUserPayload(user)
    });
  } catch (error) {
    console.error('Profile update failed:', error.message);
    res.status(401).json({ success: false, message: 'Token invalid or expired' });
  }
});

module.exports = router;
