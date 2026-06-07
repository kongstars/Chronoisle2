const path = require('path');
const fs = require('fs');

const envFile = process.env.NODE_ENV === 'production' ? '.env.production' : '.env.development';
const envPath = path.resolve(__dirname, envFile);

// 只有当特定环境文件存在时且需要覆盖时才指定 path
if (fs.existsSync(envPath)) {
  console.log(`正在从 ${envPath} 强制覆盖加载环境变量...`);
  require('dotenv').config({ path: envPath, override: true });
} else {
  require('dotenv').config({ override: true });
}
const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const mongoose = require('mongoose');

const authRoutes = require('./routes/auth');
const syncRoutes = require('./routes/sync');
const oauthRoutes = require('./routes/oauth');
const usageRoutes = require('./routes/usage');
const adminRoutes = require('./routes/admin');
const announcementRoutes = require('./routes/announcement');
const subscriptionRoutes = require('./routes/subscription');
const iapRoutes = require('./routes/iap');
const planRoutes = require('./routes/plan');
const telemetryRoutes = require('./routes/telemetry');
const creditRoutes = require('./routes/credit');
const agentRescheduleRoutes = require('./routes/agentReschedule');
const PlanScheduler = require('./services/PlanScheduler');
const UsageRecord = require('./models/UsageRecord');
const UsageSummary = require('./models/UsageSummary');
const { attachTraceId, sendError } = require('./utils/apiResponse');
const { createChatCompletion, getDeepSeekModel } = require('./utils/deepseekClient');

const app = express();
const PORT = process.env.PORT || 3000;
const JSON_BODY_LIMIT = process.env.JSON_BODY_LIMIT || '2mb';
const DEFAULT_MONGODB_URI = process.env.NODE_ENV === 'production'
  ? 'mongodb://127.0.0.1:27017/sishiqingdan_prod'
  : 'mongodb://127.0.0.1:27017/chronoisle_prod';
const MONGODB_URI = process.env.MONGODB_URI || DEFAULT_MONGODB_URI;

function maskMongoUri(uri) {
  const value = String(uri || '');
  return value.replace(/\/\/([^:/]+):([^@/]+)@/, '//$1:***@');
}

function buildAllowedOrigins() {
  const raw = String(process.env.CORS_ORIGIN || '').trim();
  const defaultOrigins = process.env.NODE_ENV === 'production'
    ? [
        'https://sishiqingdan.cn',
        'https://www.sishiqingdan.cn',
        'https://api.sishiqingdan.cn',
        'https://test-api.sishiqingdan.cn'
      ]
    : ['http://localhost:8080', 'http://127.0.0.1:8080', 'http://localhost:3000', 'http://127.0.0.1:3000'];
  if (!raw) {
    return defaultOrigins;
  }
  return Array.from(new Set([
    ...defaultOrigins,
    ...raw.split(',').map(item => item.trim()).filter(Boolean)
  ]));
}

const allowedOrigins = buildAllowedOrigins();

// #region debug-point A:ai-403-report
function reportDebugEvent(hypothesisId, location, msg, data = {}, req) {
  try {
    const envText = fs.readFileSync(path.resolve(__dirname, '../.dbg/ai-403-repeat.env'), 'utf8');
    const debugUrl = envText.match(/DEBUG_SERVER_URL=(.+)/)?.[1] || 'http://127.0.0.1:7777/event';
    const sessionId = envText.match(/DEBUG_SESSION_ID=(.+)/)?.[1] || 'ai-403-repeat';
    fetch(debugUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        sessionId,
        runId: 'pre-fix',
        hypothesisId,
        location,
        msg,
        data,
        traceId: req?.traceId || '',
        ts: Date.now()
      })
    }).catch(() => {});
  } catch (_) {}
}
// #endregion

mongoose.connect(MONGODB_URI, {
  maxPoolSize: 50,
  minPoolSize: 5,
  serverSelectionTimeoutMS: 5000,
  connectTimeoutMS: 10000,
  socketTimeoutMS: 45000,
  family: 4
}).then(() => {
  console.log(`MongoDB 连接成功 [${maskMongoUri(MONGODB_URI)}]`);
}).catch(err => {
  console.error('MongoDB 连接失败:', err.message);
});

// trust proxy — 部署在 Nginx 后时正确获取客户端 IP
if (process.env.NODE_ENV === 'production') {
  app.set('trust proxy', 1);
}

// 中间件
app.use(attachTraceId);
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  if (process.env.NODE_ENV === 'production') {
    res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  }
  next();
});
app.use(cors({
  origin(origin, callback) {
    if (!origin) {
      return callback(null, true);
    }
    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    // #region debug-point B:cors-denied
    reportDebugEvent('B', 'server/index.js:cors-origin', '[DEBUG] CORS origin denied', { origin, allowedOrigins }, undefined);
    // #endregion
    return callback(new Error('CORS origin denied'));
  },
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Goal-Planning-Visitor-Id', 'X-Trace-Id'],
  optionsSuccessStatus: 204
}));
app.use(express.json({ limit: JSON_BODY_LIMIT }));

// 托管管理后台与官网公开静态文件 (如隐私协议)
app.use('/admin', (req, res, next) => {
  res.setHeader('Cache-Control', 'no-store');
  next();
}, express.static(path.join(__dirname, 'admin')));
app.use(express.static(path.join(__dirname, 'public')));

// 健康检查端点
app.get('/health', (req, res) => {
  const dbState = mongoose.connection.readyState;
  const dbStates = { 0: 'disconnected', 1: 'connected', 2: 'connecting', 3: 'disconnecting' };
  const healthy = dbState === 1;
  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'degraded',
    database: dbStates[dbState] || 'unknown',
    timestamp: new Date().toISOString()
  });
});

// Token缓存
let tokenCache = {
  token: null,
  expiresAt: null,
  appKey: null
};

const Core = require('@alicloud/pop-core');

// 生成阿里云Token
async function generateAliyunToken() {
  const accessKeyId = process.env.ALIBABA_CLOUD_ACCESS_KEY_ID;
  const accessKeySecret = process.env.ALIBABA_CLOUD_ACCESS_KEY_SECRET;
  const region = process.env.ALIBABA_CLOUD_REGION || 'cn-shanghai';
  const appKey = process.env.ALIBABA_CLOUD_SPEECH_APP_KEY;

  if (!accessKeyId || !accessKeySecret) {
    throw new Error('阿里云凭证未配置，请检查环境变量');
  }

  const client = new Core({
    accessKeyId: accessKeyId,
    accessKeySecret: accessKeySecret,
    endpoint: `https://nls-meta.${region}.aliyuncs.com`,
    apiVersion: '2019-02-28'
  });

  try {
    const result = await client.request('CreateToken', {}, {
      method: 'POST'
    });
    
    if (result && result.Token && result.Token.Id) {
      const token = result.Token.Id;
      const expireTime = result.Token.ExpireTime; // 这是一个十位数的Unix时间戳(秒)
      
      return {
        token,
        appKey,
        expiresIn: 86400,
        expiresAt: expireTime * 1000,
        region
      };
    } else {
      throw new Error('阿里云Token生成响应格式错误');
    }
  } catch (error) {
    console.error('阿里云Token生成失败:', error.message);
    throw new Error(`Token生成失败: ${error.message}`);
  }
}

// 获取Token（带缓存）
async function getTokenWithCache() {
  const now = Date.now();
  
  // 检查缓存是否有效（提前5分钟刷新）
  if (tokenCache.token && tokenCache.expiresAt && 
      tokenCache.expiresAt > now + 300000) {
    return tokenCache;
  }
  
  // 生成新Token
  try {
    const tokenData = await generateAliyunToken();
    tokenCache = {
      token: tokenData.token,
      appKey: tokenData.appKey,
      expiresAt: tokenData.expiresAt,
      region: tokenData.region
    };
    
    console.log('Token刷新成功，有效期至:', new Date(tokenData.expiresAt).toLocaleString());
    return tokenCache;
  } catch (error) {
    // 如果刷新失败但缓存还有效，返回缓存
    if (tokenCache.token && tokenCache.expiresAt && tokenCache.expiresAt > now) {
      console.warn('Token刷新失败，使用缓存Token');
      return tokenCache;
    }
    throw error;
  }
}

// Token接口
app.get('/api/speech/token', async (req, res) => {
  try {
    const tokenData = await getTokenWithCache();
    
    res.json({
      success: true,
      data: {
        token: tokenData.token,
        appKey: tokenData.appKey,
        expiresIn: Math.floor((tokenData.expiresAt - Date.now()) / 1000),
        region: tokenData.region,
        timestamp: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('Token接口错误:', error.message);
    res.status(500).json({
      success: false,
      error: error.message,
      message: '语音服务Token获取失败'
    });
  }
});

const jwt = require('jsonwebtoken');
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  if (process.env.NODE_ENV === 'production') {
    console.error('FATAL: JWT_SECRET must be set in production environment');
    process.exit(1);
  }
  console.warn('WARNING: JWT_SECRET not set, using insecure default for development only');
}
const _JWT_SECRET = JWT_SECRET || 'chronoisle-dev-insecure-key-do-not-use-in-production';

// 身份验证中间件
function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    // #region debug-point C:auth-missing
    reportDebugEvent('C', 'server/index.js:authenticate-missing', '[DEBUG] Missing bearer token', {
      path: req.originalUrl || req.url,
      method: req.method,
      host: req.headers.host || '',
      origin: req.headers.origin || '',
      hasAuthorization: !!authHeader
    }, req);
    // #endregion
    return sendError(res, 401, 'AUTH_REQUIRED', '请求未携带Token，请先登录');
  }
  
  const token = authHeader.substring(7);
  try {
    const decoded = jwt.verify(token, _JWT_SECRET);
    req.user = decoded; // 挂载解码后的用户信息
    next();
  } catch(err) {
    // #region debug-point D:auth-invalid
    reportDebugEvent('D', 'server/index.js:authenticate-invalid', '[DEBUG] Bearer token invalid', {
      path: req.originalUrl || req.url,
      method: req.method,
      host: req.headers.host || '',
      origin: req.headers.origin || '',
      error: err && err.message ? err.message : 'unknown'
    }, req);
    // #endregion
    return sendError(res, 401, 'AUTH_TOKEN_INVALID', 'Token无效或已过期');
  }
}

function authenticateGoalPlanning(req, res, next) {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authenticate(req, res, next);
  }

  const visitorId = String(req.headers['x-goal-planning-visitor-id'] || '').trim();
  const isOnboardingStart = req.path === '/start' && req.body?.onboarding === true && req.body?.source === 'create_goal';
  const isAnonymousContinuation = !!visitorId && req.path !== '/start';

  if (isOnboardingStart || isAnonymousContinuation) {
    return next();
  }

  return authenticate(req, res, next);
}

// 挂载新的账号与同步路由
app.use('/api/auth', authRoutes);
// 第三方登录路由
app.use('/api/auth/oauth', oauthRoutes);
// Sync路由中使用了/data, checkUser其实就是在路由内校验了，但我们可以把解析放在这里
app.use('/api/sync', authenticate, syncRoutes);
// 模拟会员购买
app.use('/api/subscription', authenticate, subscriptionRoutes);
// 用量统计路由（需用户登录）
app.use('/api/usage', authenticate, usageRoutes);
// 积分系统路由（需用户登录）
app.use('/api/credit', authenticate, creditRoutes);
// 管理后台路由（有独立鉴权）
app.use('/api/admin', adminRoutes);
app.use('/api/announcements', announcementRoutes);
// 埋点路由（客户端上报需用户登录；管理查询有独立鉴权）
app.use('/api/telemetry', (req, res, next) => {
  if (req.path.startsWith('/admin')) {
    return next();
  }
  return authenticate(req, res, next);
}, telemetryRoutes);
// 华为应用内支付路由：用户主动校验订单需要登录，华为服务器事件通知不走用户 JWT。
app.use('/api/iap', (req, res, next) => {
  if (req.path === '/huawei/notify') {
    return next();
  }
  return authenticate(req, res, next);
}, iapRoutes);
// AI计划预生成路由
// #region debug-point E:cloud-entry
app.use(['/api/credit', '/api/plan', '/api/goal-planning', '/api/voice-create', '/api/agent'], (req, _res, next) => {
  reportDebugEvent('E', 'server/index.js:cloud-entry', '[DEBUG] Cloud capability request entry', {
    path: req.originalUrl || req.url,
    method: req.method,
    host: req.headers.host || '',
    origin: req.headers.origin || '',
    referer: req.headers.referer || '',
    userAgent: req.headers['user-agent'] || ''
  }, req);
  next();
});
// #endregion
app.use('/api/plan', authenticate, planRoutes);

// AI 目标规划工作台路由
const goalPlanningRoutes = require('./routes/goalPlanning');
app.use('/api/goal-planning', authenticateGoalPlanning, goalPlanningRoutes);

// 语音智能创建路由
const voiceCreateRoutes = require('./routes/voiceCreate');
app.use('/api/voice-create', authenticate, voiceCreateRoutes);


// --- AI 接口限流防刷保护 ---
const agentRateLimitCache = new Map();
const AGENT_RATE_LIMIT_WINDOW = 60000; // 1分钟
const AGENT_RATE_LIMIT_MAX = 10; // 1分钟最多10次调用
const AGENT_RATE_LIMIT_MESSAGE = '你的请求太频繁啦，请休息一分钟后再试。';

function agentRateLimiter(req, res, next) {
  if (req.method === 'GET' && String(req.originalUrl || '').startsWith('/api/agent/reschedule/status/')) {
    return next();
  }

  // 复用 authenticate 中间件已解码的 userId，避免重复 JWT 验证
  let identifier = (req.user && req.user.userId) ? req.user.userId : req.ip;
  
  const now = Date.now();
  const record = agentRateLimitCache.get(identifier);

  if (!record || now - record.firstRequest > AGENT_RATE_LIMIT_WINDOW) {
    agentRateLimitCache.set(identifier, { count: 1, firstRequest: now });
    return next();
  }

  if (record.count >= AGENT_RATE_LIMIT_MAX) {
    console.warn(`[拦截] 用户/IP ${identifier} 触发大模型保护限流`);
    if (String(req.originalUrl || '').startsWith('/api/agent/reschedule')) {
      return res.status(200).json({
        success: false,
        message: AGENT_RATE_LIMIT_MESSAGE
      });
    }

    // 返回优雅的降级 JSON，确保前端不会红屏崩溃
    return res.status(200).json({
       success: true,
       output: {
         text: JSON.stringify({ errorMsg: AGENT_RATE_LIMIT_MESSAGE })
       }
    });
  }

  record.count += 1;
  next();
}

// 定时清理限流缓存
setInterval(() => {
  const now = Date.now();
  for (const [key, record] of agentRateLimitCache.entries()) {
    if (now - record.firstRequest > AGENT_RATE_LIMIT_WINDOW) {
      agentRateLimitCache.delete(key);
    }
  }
}, 60000);

// 百炼智能体中转接口 (加入限流中间件)
app.use('/api/agent/reschedule', authenticate, agentRateLimiter, agentRescheduleRoutes({
  UsageRecord,
  usageRoutes
}));

app.post('/api/agent/completion', authenticate, agentRateLimiter, async (req, res) => {
  try {
    const { input, session_id, app_id, model } = req.body;
    const prompt = typeof input?.prompt === 'string' ? input.prompt : '';
    if (!prompt) {
      return res.status(400).json({ success: false, message: '缺少有效的 prompt' });
    }

    const resolvedModel = getDeepSeekModel(model || process.env.AGENT_COMPLETION_MODEL || process.env.DEEPSEEK_MODEL || 'deepseek-v4-pro');
    console.log(`正在转发请求至 DeepSeek model=${resolvedModel}${app_id ? ` legacy_app_id=${app_id}` : ''}${session_id ? ` session_id=${session_id}` : ''}`);

    const completion = await createChatCompletion({
      model: resolvedModel,
      timeoutMs: 120000,
      temperature: 0.2,
      messages: [
        {
          role: 'system',
          content: '你是四时清单的 AI 助手。只输出用户所要求的结果，不要附加额外解释。'
        },
        {
          role: 'user',
          content: prompt
        }
      ]
    });

    const content = completion.content || '';
    const usage = completion.data?.usage || {};
    const responsePayload = {
      success: true,
      output: {
        text: content,
        choices: [
          {
            message: {
              content
            }
          }
        ]
      },
      usage: {
        models: [
          {
            input_tokens: usage.prompt_tokens || usage.input_tokens || 0,
            output_tokens: usage.completion_tokens || usage.output_tokens || 0,
            model_id: completion.data?.model || resolvedModel
          }
        ]
      },
      session_id: session_id || ''
    };

    res.json(responsePayload);

    // === 自动记录 Token 用量 ===
    try {
      const usageData = responsePayload.usage;
      const modelUsage = usageData?.models?.[0];
      const authHeader = req.headers.authorization;
      if (modelUsage && authHeader && authHeader.startsWith('Bearer ')) {
        const userToken = authHeader.substring(7);
        const decoded = jwt.verify(userToken, _JWT_SECRET);
        const userId = decoded.userId;
        if (userId) {
          const inputTokens = modelUsage.input_tokens || 0;
          const outputTokens = modelUsage.output_tokens || 0;
          const totalTokens = inputTokens + outputTokens;
          const modelId = modelUsage.model_id || '';
          const yearMonth = usageRoutes.getCurrentYearMonth();

          console.log(`[Token用量] 用户${userId}: input=${inputTokens}, output=${outputTokens}, total=${totalTokens}, model=${modelId}`);

          const record = new UsageRecord({
            userId,
            type: 'token',
            amount: totalTokens,
            detail: { inputTokens, outputTokens, model: modelId },
            yearMonth,
            createdAt: Date.now()
          });
          record.save().catch(e => console.error('Token用量记录失败:', e.message));
          usageRoutes.updateMonthlySummary(userId, 'token', totalTokens, { inputTokens, outputTokens })
            .catch(e => console.error('Token月度汇总更新失败:', e.message));
        }
      }
    } catch (usageErr) {
      // 用量记录失败不影响正常响应
      console.warn('Token用量自动记录异常:', usageErr.message);
    }
  } catch (error) {
    if (error.response) {
      const status = error.response.status;
      const data = error.response.data || {};
      console.error('DeepSeek Agent API HTTP请求报错:', status, data);

      // 捕获欠费/并发限制等错误 (兜底降级处理)
      if (status === 402 || status === 429 || 
          (data.code && (data.code.includes('QuotaExceeded') || data.code.includes('Throttling') || data.code.includes('OutOfBalance') || data.code.includes('Forbidden')))) {
        console.warn('[高危阻断] DeepSeek 限流或额度异常，启动优雅降级兜底响应');
        return res.status(200).json({  
          success: true, 
          output: {
            text: JSON.stringify({ errorMsg: '云端AI额度已暂时耗尽或服务拥挤，正在维护中，请稍后再试或自行管理。' })
          }
        });
      }

      res.status(status).json({
        success: false,
        error: data,
        message: 'DeepSeek 接口模型拒绝或发生业务错误'
      });
    } else {
      console.error('DeepSeek Agent API 网络或超时报错:', error.message);
      res.status(504).json({
        success: false,
        error: error.message,
        message: 'DeepSeek 接口网络超时或未能响应'
      });
    }
  }
});

// 受保护的路由示例（如果需要）
app.get('/api/speech/token/protected', authenticate, async (req, res) => {
  try {
    const tokenData = await getTokenWithCache();
    res.json({ success: true, data: tokenData });
  } catch (error) {
    sendError(res, 500, 'SPEECH_TOKEN_FETCH_FAILED', '语音服务Token获取失败', {
      error: error.message
    });
  }
});

// 错误处理中间件
app.use((err, req, res, next) => {
  if (err && err.message === 'CORS origin denied') {
    // #region debug-point B:cors-response
    reportDebugEvent('B', 'server/index.js:error-handler', '[DEBUG] Returning 403 for CORS denial', {
      path: req.originalUrl || req.url,
      method: req.method,
      host: req.headers.host || '',
      origin: req.headers.origin || ''
    }, req);
    // #endregion
    return sendError(res, 403, 'CORS_ORIGIN_DENIED', '当前来源未被服务器允许访问');
  }

  if (err && (err.type === 'entity.too.large' || err.status === 413)) {
    console.warn(`请求体过大: ${req.method} ${req.originalUrl} limit=${JSON_BODY_LIMIT}`);
    return sendError(res, 413, 'REQUEST_TOO_LARGE', '需要重排的任务内容过多，请先减少超长描述或稍后重试', {
      error: '请求内容过大'
    });
  }

  console.error('服务器错误:', err.stack);
  sendError(res, 500, 'INTERNAL_SERVER_ERROR', '服务暂时不可用', {
    error: process.env.NODE_ENV === 'development' ? err.message : '服务器内部错误'
  });
});

// 404处理
app.use((req, res) => {
  sendError(res, 404, 'ROUTE_NOT_FOUND', '请检查API路径', {
    error: '未找到请求的资源'
  });
});

// 启动服务器
app.listen(PORT, () => {
  console.log(`语音Token服务器运行在端口 ${PORT}`);
  console.log(`环境: ${process.env.NODE_ENV || 'development'}`);
  console.log(`健康检查: http://localhost:${PORT}/health`);
  console.log(`Token接口: http://localhost:${PORT}/api/speech/token`);
  
  // 检查环境变量
  if (!process.env.ALIBABA_CLOUD_ACCESS_KEY_ID) {
    console.warn('警告: ALIBABA_CLOUD_ACCESS_KEY_ID 未设置');
  }
  if (!process.env.ALIBABA_CLOUD_ACCESS_KEY_SECRET) {
    console.warn('警告: ALIBABA_CLOUD_ACCESS_KEY_SECRET 未设置');
  }
  if (!process.env.ALIBABA_CLOUD_SPEECH_APP_KEY) {
    console.warn('警告: ALIBABA_CLOUD_SPEECH_APP_KEY 未设置');
  }

  // 启动AI计划预生成定时任务
  try {
    const scheduler = new PlanScheduler();
    scheduler.start();
  } catch (err) {
    console.error('PlanScheduler 启动失败:', err.message);
  }
});

module.exports = app;
