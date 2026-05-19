const crypto = require('crypto');
const fs = require('fs');
const axios = require('axios');
const jwt = require('jsonwebtoken');

const User = require('../models/User');
const UsageSummary = require('../models/UsageSummary');
const CreditAccount = require('../models/CreditAccount');
const CreditTransaction = require('../models/CreditTransaction');
const IapOrder = require('../models/IapOrder');
const IapEvent = require('../models/IapEvent');

const ONE_DAY = 24 * 60 * 60 * 1000;
const PRODUCT_CONFIG = Object.freeze({
  vip_monthly_continuous: {
    plan: 'monthly_continuous',
    durationMs: 30 * ONE_DAY
  },
  vip_yearly_continuous: {
    plan: 'yearly_continuous',
    durationMs: 365 * ONE_DAY
  }
});
const MONTHLY_GRANT = 500;
const SUPPORTED_JWS_ALGORITHMS = ['RS256', 'RS384', 'RS512', 'PS256', 'PS384', 'PS512', 'ES256', 'ES384', 'ES512'];
const HUAWEI_IAP_ROOT_URL = process.env.HUAWEI_IAP_ROOT_URL || 'https://iap.cloud.huawei.com';

class HuaweiIapError extends Error {
  constructor(message, statusCode = 400) {
    super(message);
    this.name = 'HuaweiIapError';
    this.statusCode = statusCode;
  }
}

function getSupportedProductIds() {
  return Object.keys(PRODUCT_CONFIG);
}

function hashValue(value) {
  return crypto.createHash('sha256').update(String(value || '')).digest('hex');
}

function stringifyForHash(value) {
  try {
    return JSON.stringify(value || {});
  } catch (_) {
    return String(value || '');
  }
}

function hashHex(value) {
  return crypto.createHash('sha256').update(String(value || ''), 'utf8').digest('hex');
}

function normalizePublicKey(rawKey) {
  const normalized = String(rawKey || '').trim().replace(/\\n/g, '\n');
  if (!normalized) {
    throw new HuaweiIapError('服务器支付验签公钥未配置', 500);
  }
  if (normalized.includes('BEGIN PUBLIC KEY') || normalized.includes('BEGIN CERTIFICATE')) {
    return normalized;
  }
  const lines = normalized.replace(/\s+/g, '').match(/.{1,64}/g) || [];
  return `-----BEGIN PUBLIC KEY-----\n${lines.join('\n')}\n-----END PUBLIC KEY-----`;
}

function buildPemBlock(base64Content, header, footer) {
  const normalized = String(base64Content || '').replace(/\s+/g, '');
  if (!normalized) {
    return '';
  }
  const lines = normalized.match(/.{1,64}/g) || [];
  return `-----BEGIN ${header}-----\n${lines.join('\n')}\n-----END ${footer}-----`;
}

function decodeBase64UrlJson(segment) {
  try {
    let normalized = String(segment || '').replace(/-/g, '+').replace(/_/g, '/');
    while (normalized.length % 4 !== 0) {
      normalized += '=';
    }
    const text = Buffer.from(normalized, 'base64').toString('utf8');
    return {
      text,
      json: JSON.parse(text)
    };
  } catch (error) {
    return {
      text: '',
      json: null,
      error: error.message || String(error)
    };
  }
}

function getJwsHeaderDiagnostics(jws) {
  const text = normalizeText(jws);
  const segments = text ? text.split('.') : [];
  if (segments.length !== 3) {
    return { present: !!text, compact: false, segmentCount: segments.length };
  }

  const headerDecoded = decodeBase64UrlJson(segments[0]);
  const payloadDecoded = decodeBase64UrlJson(segments[1]);

  try {
    const decoded = jwt.decode(text, { complete: true });
    const header = decoded?.header || headerDecoded.json || {};
    const x5cCount = Array.isArray(header.x5c) ? header.x5c.length : 0;
    return {
      present: true,
      compact: true,
      segmentCount: segments.length,
      alg: header.alg || '',
      kid: header.kid || '',
      typ: header.typ || '',
      x5cCount,
      hasX5c: x5cCount > 0,
      hasJwk: !!header.jwk,
      jwkKty: header.jwk?.kty || '',
      headerKeys: headerDecoded.json ? Object.keys(headerDecoded.json).slice(0, 20) : [],
      headerParseError: headerDecoded.error || '',
      headerHash: hashValue(segments[0]).slice(0, 16),
      payloadKeys: payloadDecoded.json && typeof payloadDecoded.json === 'object'
        ? Object.keys(payloadDecoded.json).slice(0, 30)
        : [],
      payloadParseError: payloadDecoded.error || '',
      hasEnvPublicKey: !!normalizeText(process.env.HUAWEI_IAP_PUBLIC_KEY)
    };
  } catch (error) {
    return {
      present: true,
      compact: true,
      segmentCount: segments.length,
      headerKeys: headerDecoded.json ? Object.keys(headerDecoded.json).slice(0, 20) : [],
      headerParseError: headerDecoded.error || '',
      payloadKeys: payloadDecoded.json && typeof payloadDecoded.json === 'object'
        ? Object.keys(payloadDecoded.json).slice(0, 30)
        : [],
      payloadParseError: payloadDecoded.error || '',
      decodeError: error.message || String(error)
    };
  }
}

function decodeJwsPayloadWithoutVerification(jws) {
  const text = normalizeText(jws);
  const segments = text ? text.split('.') : [];
  if (segments.length !== 3) {
    throw new HuaweiIapError('支付凭证格式不正确');
  }

  const payloadDecoded = decodeBase64UrlJson(segments[1]);
  if (!payloadDecoded.json || typeof payloadDecoded.json !== 'object') {
    throw new HuaweiIapError('支付凭证内容解析失败');
  }
  return unwrapHuaweiPayload(payloadDecoded.json);
}

function getVerificationKeyFromJws(jws) {
  const decoded = jwt.decode(jws, { complete: true });
  const header = decoded?.header || {};

  if (Array.isArray(header.x5c) && header.x5c.length > 0) {
    const certPem = buildPemBlock(header.x5c[0], 'CERTIFICATE', 'CERTIFICATE');
    if (certPem) {
      return certPem;
    }
  }

  if (header.jwk && typeof header.jwk === 'object') {
    try {
      return crypto.createPublicKey({ key: header.jwk, format: 'jwk' }).export({ type: 'spki', format: 'pem' });
    } catch (error) {
      console.warn('从 JWS 头部 JWK 构造公钥失败:', error.message);
    }
  }

  return normalizePublicKey(process.env.HUAWEI_IAP_PUBLIC_KEY);
}

function parseMaybeJson(value) {
  if (!value) return null;
  if (typeof value === 'object') return value;
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
  try {
    return JSON.parse(trimmed);
  } catch (_) {
    return null;
  }
}

function isCompactJws(value) {
  const text = normalizeText(value);
  return text.split('.').length === 3;
}

function extractSignedPurchaseJws(value) {
  const text = normalizeText(value);
  if (!text) return '';
  if (isCompactJws(text)) return text;

  const parsed = parseMaybeJson(text);
  if (!parsed || typeof parsed !== 'object') return '';

  return normalizeText(
    parsed.jwsSubscriptionStatus ||
    parsed.jwsPurchaseOrder ||
    parsed.jwsPurchaseData ||
    parsed.signedPurchaseOrder ||
    parsed.signedSubscriptionStatus
  );
}

function unwrapHuaweiPayload(decoded) {
  const merged = {};
  const candidates = [decoded];

  for (const key of ['data', 'payload', 'purchaseData', 'notificationData', 'order', 'purchaseOrder']) {
    const parsed = parseMaybeJson(decoded?.[key]);
    if (parsed) candidates.push(parsed);
    if (decoded?.[key] && typeof decoded[key] === 'object') candidates.push(decoded[key]);
  }

  for (const item of candidates) {
    if (item && typeof item === 'object' && !Array.isArray(item)) {
      Object.assign(merged, item);
    }
  }

  normalizeSubscriptionPayload(merged);
  return merged;
}

function mergePlainObject(target, source) {
  if (!source || typeof source !== 'object' || Array.isArray(source)) return;
  Object.assign(target, source);
}

function normalizeSubscriptionPayload(payload) {
  const status = payload.lastSubscriptionStatus || payload.subscriptionStatus || payload.subStatus;
  mergePlainObject(payload, status);

  const renewalInfo = status?.renewalInfo || payload.renewalInfo;
  const lastPurchaseOrder = status?.lastPurchaseOrder || payload.lastPurchaseOrder || payload.purchaseOrder;
  mergePlainObject(payload, renewalInfo);
  mergePlainObject(payload, lastPurchaseOrder);

  if (!payload.productId) {
    payload.productId = renewalInfo?.productId || renewalInfo?.productNo || lastPurchaseOrder?.productId || lastPurchaseOrder?.productNo;
  }
  if (!payload.orderId) {
    payload.orderId = lastPurchaseOrder?.orderId || lastPurchaseOrder?.purchaseOrderId || lastPurchaseOrder?.orderNo;
  }
  if (!payload.purchaseToken) {
    payload.purchaseToken = status?.purchaseToken || lastPurchaseOrder?.purchaseToken || lastPurchaseOrder?.purchaseTokenId;
  }
  if (!payload.expirationTime) {
    payload.expirationTime = status?.expirationTime || status?.expiryTime || status?.expiresTime || status?.validUntil ||
      lastPurchaseOrder?.expirationTime || lastPurchaseOrder?.expiryTime || lastPurchaseOrder?.expiresTime;
  }
  if (!payload.purchaseTime) {
    payload.purchaseTime = lastPurchaseOrder?.purchaseTime || lastPurchaseOrder?.paidTime || lastPurchaseOrder?.createTime ||
      status?.startTime || status?.periodStartAt;
  }
}

function verifyJws(jws) {
  const verificationKey = getVerificationKeyFromJws(jws);
  const decoded = jwt.verify(jws, verificationKey, { algorithms: SUPPORTED_JWS_ALGORITHMS });
  return unwrapHuaweiPayload(decoded);
}

function hasHuaweiServerApiConfig() {
  return !!(
    normalizeText(process.env.HUAWEI_IAP_ISSUER_ID) &&
    normalizeText(process.env.HUAWEI_IAP_KEY_ID) &&
    normalizeText(process.env.HUAWEI_IAP_PRIVATE_KEY_PATH) &&
    normalizeText(process.env.HUAWEI_IAP_APP_ID)
  );
}

function shouldUseHuaweiServerApi() {
  const flag = normalizeText(process.env.HUAWEI_IAP_USE_SERVER_API).toLowerCase();
  if (['0', 'false', 'off', 'no'].includes(flag)) return false;
  return hasHuaweiServerApiConfig();
}

function loadHuaweiPrivateKey() {
  const privateKeyPath = normalizeText(process.env.HUAWEI_IAP_PRIVATE_KEY_PATH);
  if (!privateKeyPath) {
    throw new HuaweiIapError('华为IAP服务端密钥路径未配置', 500);
  }
  try {
    return fs.readFileSync(privateKeyPath, 'utf8');
  } catch (error) {
    throw new HuaweiIapError(`华为IAP服务端密钥读取失败: ${error.message}`, 500);
  }
}

function createHuaweiServerApiToken(bodyText) {
  const now = Math.floor(Date.now() / 1000);
  const header = {
    alg: 'ES256',
    typ: 'JWT',
    kid: normalizeText(process.env.HUAWEI_IAP_KEY_ID)
  };
  const payload = {
    iss: normalizeText(process.env.HUAWEI_IAP_ISSUER_ID),
    aud: 'iap-v1',
    iat: now,
    exp: now + 300,
    aid: normalizeText(process.env.HUAWEI_IAP_APP_ID),
    digest: hashHex(bodyText)
  };

  if (!header.kid || !payload.iss || !payload.aid) {
    throw new HuaweiIapError('华为IAP服务端API JWT配置不完整', 500);
  }

  return jwt.sign(payload, loadHuaweiPrivateKey(), {
    algorithm: 'ES256',
    header
  });
}

async function queryHuaweiSubscriptionStatus(preliminaryPayload) {
  const purchaseToken = extractPurchaseToken(preliminaryPayload);
  const purchaseOrderId = extractOrderId(preliminaryPayload);
  if (!purchaseToken || !purchaseOrderId) {
    throw new HuaweiIapError('订阅状态查询缺少purchaseToken或purchaseOrderId');
  }

  const body = { purchaseToken, purchaseOrderId };
  const bodyText = JSON.stringify(body);
  const token = createHuaweiServerApiToken(bodyText);
  const url = `${HUAWEI_IAP_ROOT_URL.replace(/\/$/, '')}/subscription/harmony/v1/application/subscription/status/query`;

  let response;
  try {
    response = await axios.post(url, bodyText, {
      timeout: Number(process.env.HUAWEI_IAP_API_TIMEOUT_MS || 15000),
      headers: {
        'Content-Type': 'application/json;charset=UTF-8',
        'Accept': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      validateStatus: () => true
    });
  } catch (error) {
    throw new HuaweiIapError(`华为订阅状态查询请求失败: ${error.message}`, 502);
  }

  const data = response.data || {};
  if (response.status < 200 || response.status >= 300) {
    throw new HuaweiIapError(`华为订阅状态查询HTTP失败: ${response.status}`, 502);
  }
  if (String(data.responseCode || '') !== '0') {
    throw new HuaweiIapError(`华为订阅状态查询失败: ${data.responseCode || 'UNKNOWN'} ${data.responseMessage || ''}`.trim(), 502);
  }
  if (!data.jwsSubGroupStatus) {
    throw new HuaweiIapError('华为订阅状态查询未返回订阅状态JWS', 502);
  }

  return {
    payload: verifyJws(data.jwsSubGroupStatus),
    signedJws: data.jwsSubGroupStatus,
    rawHashSource: data.jwsSubGroupStatus
  };
}

async function resolvePurchasePayload(options) {
  if (options.purchaseData && typeof options.purchaseData === 'object') {
    if (!options.trustedDecodedPayload) {
      throw new HuaweiIapError('支付凭证缺少签名订单');
    }
    return {
      payload: unwrapHuaweiPayload(options.purchaseData),
      signedJws: '',
      rawHashSource: stringifyForHash(options.purchaseData)
    };
  }

  const candidates = [
    options.jwsPurchaseOrder,
    options.purchaseData
  ];

  for (const candidate of candidates) {
    const signedJws = extractSignedPurchaseJws(candidate);
    if (signedJws) {
      if (shouldUseHuaweiServerApi()) {
        const preliminaryPayload = decodeJwsPayloadWithoutVerification(signedJws);
        try {
          return await queryHuaweiSubscriptionStatus(preliminaryPayload);
        } catch (error) {
          if (normalizeText(process.env.HUAWEI_IAP_SERVER_API_REQUIRED).toLowerCase() === 'true') {
            throw error;
          }
          console.warn('Huawei IAP server API verification failed, fallback to local JWS verification:', error.message);
        }
      }
      return {
        payload: verifyJws(signedJws),
        signedJws,
        rawHashSource: signedJws
      };
    }
  }

  throw new HuaweiIapError('支付凭证缺少签名订单');
}

function getIapRequestDiagnostics(options = {}) {
  const purchaseData = options.purchaseData;
  const purchaseDataJws = typeof purchaseData === 'string' ? extractSignedPurchaseJws(purchaseData) : '';
  return {
    hasJwsPurchaseOrder: !!normalizeText(options.jwsPurchaseOrder),
    jwsPurchaseOrderHeader: getJwsHeaderDiagnostics(options.jwsPurchaseOrder),
    hasPurchaseData: purchaseData !== undefined && purchaseData !== null && purchaseData !== '',
    purchaseDataType: Array.isArray(purchaseData) ? 'array' : typeof purchaseData,
    purchaseDataJwsHeader: getJwsHeaderDiagnostics(purchaseDataJws),
    hasClientProductId: !!normalizeText(options.clientProductId),
    hasEnvPublicKey: !!normalizeText(process.env.HUAWEI_IAP_PUBLIC_KEY),
    hasEnvPrivateKeyPath: !!normalizeText(process.env.HUAWEI_IAP_PRIVATE_KEY_PATH),
    hasEnvKeyId: !!normalizeText(process.env.HUAWEI_IAP_KEY_ID),
    hasEnvIssuerId: !!normalizeText(process.env.HUAWEI_IAP_ISSUER_ID),
    hasEnvAppId: !!normalizeText(process.env.HUAWEI_IAP_APP_ID),
    useServerApi: shouldUseHuaweiServerApi()
  };
}

function pickFirst(source, keys) {
  if (!source) return undefined;
  for (const key of keys) {
    const value = source[key];
    if (value !== undefined && value !== null && String(value).trim() !== '') {
      return value;
    }
  }
  return undefined;
}

function normalizeText(value) {
  return String(value === undefined || value === null ? '' : value).trim();
}

function normalizeEnvironment(value) {
  const text = normalizeText(value).toLowerCase();
  if (['sandbox', 'test', 'testing', '0'].includes(text)) return 'sandbox';
  if (['production', 'prod', 'release', '1'].includes(text)) return 'production';
  return 'unknown';
}

function toMillis(value) {
  if (value === undefined || value === null || value === '') return 0;
  if (typeof value === 'number') {
    if (value > 1000000000000) return value;
    if (value > 1000000000) return value * 1000;
    return 0;
  }
  const text = String(value).trim();
  if (/^\d+$/.test(text)) {
    const numeric = Number(text);
    if (numeric > 1000000000000) return numeric;
    if (numeric > 1000000000) return numeric * 1000;
  }
  const parsed = Date.parse(text);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function extractProductId(payload, fallbackProductId = '') {
  return normalizeText(pickFirst(payload, [
    'productId',
    'productID',
    'productNo',
    'subscriptionProductId',
    'renewalProductId',
    'basePlanProductId'
  ]) || fallbackProductId);
}

function extractOrderId(payload) {
  return normalizeText(pickFirst(payload, [
    'orderId',
    'orderID',
    'purchaseOrderId',
    'purchaseOrderID',
    'transactionId',
    'transactionID',
    'orderNo',
    'payOrderId'
  ]));
}

function extractPurchaseToken(payload) {
  return normalizeText(pickFirst(payload, [
    'purchaseToken',
    'purchaseTokenId',
    'token',
    'subscriptionToken',
    'purchaseId'
  ]));
}

function extractOriginalOrderId(payload) {
  return normalizeText(pickFirst(payload, [
    'originalOrderId',
    'originalOrderID',
    'originalPurchaseOrderId',
    'originalTransactionId'
  ]));
}

function extractSubscriptionId(payload) {
  return normalizeText(pickFirst(payload, [
    'subscriptionId',
    'subscriptionID',
    'subscriptionPurchaseId',
    'subscriptionNo'
  ]));
}

function extractEventId(payload) {
  return normalizeText(pickFirst(payload, [
    'eventId',
    'eventID',
    'notificationId',
    'notificationID',
    'noticeId',
    'requestId'
  ]));
}

function extractEventType(payload) {
  return normalizeText(pickFirst(payload, [
    'eventType',
    'notificationType',
    'type',
    'subType',
    'status',
    'subscriptionStatus',
    'orderStatus'
  ]));
}

function extractPurchaseState(payload) {
  return pickFirst(payload, [
    'purchaseState',
    'purchaseStatus',
    'orderState',
    'orderStatus',
    'payState',
    'status'
  ]);
}

function buildPurchaseStateSummary(payload) {
  const status = normalizeText(payload?.status);
  const finishStatus = normalizeText(payload?.finishStatus);
  const expiresAt = extractExpireAt(payload);
  const productId = extractProductId(payload);
  return {
    status,
    finishStatus,
    expiresAt,
    expiresInMs: expiresAt ? expiresAt - Date.now() : 0,
    productId,
    pendingProductId: extractPendingProductId(payload, productId),
    hasPurchaseToken: !!extractPurchaseToken(payload),
    hasOrderId: !!extractOrderId(payload)
  };
}

function getPlanByProductId(productId) {
  return PRODUCT_CONFIG[productId]?.plan || '';
}

function extractPendingProductId(payload, currentProductId) {
  const renewalInfo = payload?.renewalInfo || payload?.lastSubscriptionStatus?.renewalInfo || {};
  const nextRenewPeriodPayload = payload?.nextRenewPeriodPayload || renewalInfo?.nextRenewPeriodPayload || {};
  const productId = normalizeText(pickFirst({
    nextRenewPeriodProductId: payload?.nextRenewPeriodProductId,
    nextRenewPeriodProductNo: payload?.nextRenewPeriodProductNo,
    nextProductId: payload?.nextProductId,
    nextProductNo: payload?.nextProductNo,
    pendingProductId: payload?.pendingProductId,
    renewalProductId: payload?.renewalProductId,
    renewalInfoProductId: renewalInfo?.productId,
    renewalInfoProductNo: renewalInfo?.productNo,
    renewalInfoRenewalProductId: renewalInfo?.renewalProductId,
    nextPayloadProductId: nextRenewPeriodPayload?.productId,
    nextPayloadProductNo: nextRenewPeriodPayload?.productNo
  }, [
    'nextRenewPeriodProductId',
    'nextRenewPeriodProductNo',
    'nextProductId',
    'nextProductNo',
    'pendingProductId',
    'renewalProductId',
    'renewalInfoProductId',
    'renewalInfoProductNo',
    'renewalInfoRenewalProductId',
    'nextPayloadProductId',
    'nextPayloadProductNo'
  ]));

  if (!productId || productId === currentProductId || !PRODUCT_CONFIG[productId]) {
    return '';
  }
  return productId;
}

function extractPendingEffectiveAt(payload, fallback) {
  const renewalInfo = payload?.renewalInfo || payload?.lastSubscriptionStatus?.renewalInfo || {};
  const nextRenewPeriodPayload = payload?.nextRenewPeriodPayload || renewalInfo?.nextRenewPeriodPayload || {};
  return toMillis(pickFirst({
    renewalTime: payload?.renewalTime,
    nextRenewTime: payload?.nextRenewTime,
    nextChargeTime: payload?.nextChargeTime,
    effectiveTime: payload?.effectiveTime,
    renewalInfoRenewalTime: renewalInfo?.renewalTime,
    renewalInfoNextChargeTime: renewalInfo?.nextChargeTime,
    nextPayloadEffectiveTime: nextRenewPeriodPayload?.effectiveTime,
    nextPayloadStartTime: nextRenewPeriodPayload?.startTime
  }, [
    'renewalTime',
    'nextRenewTime',
    'nextChargeTime',
    'effectiveTime',
    'renewalInfoRenewalTime',
    'renewalInfoNextChargeTime',
    'nextPayloadEffectiveTime',
    'nextPayloadStartTime'
  ])) || fallback;
}

function applyUserMembership(user, product, productId, renewAt, payload) {
  user.membershipType = 'premium';
  user.membershipPlan = product.plan;
  user.membershipProductId = productId;
  user.membershipExpireAt = renewAt;
  user.membershipRenewAt = renewAt;

  const pendingProductId = extractPendingProductId(payload, productId);
  if (pendingProductId) {
    user.pendingMembershipPlan = getPlanByProductId(pendingProductId);
    user.pendingMembershipProductId = pendingProductId;
    user.pendingMembershipEffectiveAt = extractPendingEffectiveAt(payload, renewAt);
  } else {
    user.pendingMembershipPlan = '';
    user.pendingMembershipProductId = '';
    user.pendingMembershipEffectiveAt = 0;
  }
}

function extractStartAt(payload, fallback = 0) {
  return toMillis(pickFirst(payload, [
    'purchaseTime',
    'purchaseTimeMillis',
    'startTime',
    'periodStartAt',
    'createTime',
    'paidTime'
  ])) || fallback;
}

function extractExpireAt(payload) {
  return toMillis(pickFirst(payload, [
    'expirationTime',
    'expirationTimeMillis',
    'expiryTime',
    'expiryTimeMillis',
    'expireTime',
    'expireTimeMillis',
    'subscriptionExpireTime',
    'subscriptionExpireTimeMillis',
    'periodEndAt',
    'endTime',
    'expiresTime',
    'validUntil'
  ]));
}

function getProviderOrderKey(orderId, jwsHash) {
  if (orderId) return `huawei:order:${orderId}`;
  return `huawei:jws:${jwsHash}`;
}

function hasFutureEntitlement(payload) {
  const expiresAt = extractExpireAt(payload);
  return !!expiresAt && expiresAt > Date.now();
}

function isSuccessfulPurchaseState(state, payload) {
  if (state === undefined || state === null || state === '') return true;
  const text = normalizeText(state).toUpperCase();
  if (['0', '1', 'PURCHASED', 'PURCHASE_SUCCESS', 'SUCCESS', 'PAID', 'ACTIVE', 'SUBSCRIBED', 'RENEWING'].includes(text)) {
    return true;
  }
  if (['2', '3', 'CANCELED', 'CANCELLED', 'NON_RENEWING', 'IN_GRACE_PERIOD', 'IN_BILLING_RETRY'].includes(text)) {
    return hasFutureEntitlement(payload);
  }
  return false;
}

function isRefundState(state, payload) {
  const text = normalizeText(state).toUpperCase();
  if (['REFUNDED', 'REFUND', 'REVOKED'].includes(text)) {
    return true;
  }
  return text === '2' && !hasFutureEntitlement(payload);
}

function classifyLifecycleEvent(payload) {
  const purchaseState = extractPurchaseState(payload);
  const hasPurchaseState = purchaseState !== undefined && purchaseState !== null && purchaseState !== '';
  const eventText = `${extractEventType(payload)} ${purchaseState || ''}`.toUpperCase();
  if (/REFUND|REFUN|REVOKE|CHARGEBACK/.test(eventText) || isRefundState(purchaseState, payload)) {
    return 'refund';
  }
  if (/EXPIRE|EXPIRATION|EXPIRED/.test(eventText)) {
    return 'expired';
  }
  if (/CANCEL|UNSUBSCRIBE|NON_RENEW|NONRENEW|STOP/.test(eventText)) {
    return 'canceled';
  }
  if (/RENEW|PURCHASE|PAID|SUCCESS|ACTIVE/.test(eventText) || (hasPurchaseState && isSuccessfulPurchaseState(purchaseState, payload))) {
    return 'purchased';
  }
  return 'unknown';
}

async function grantMonthlyCredits(userId) {
  const now = new Date();
  const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  const idempotencyKey = `monthly_grant:${userId}:${currentMonth}`;

  let account = await CreditAccount.findOne({ userId });
  if (!account) {
    account = new CreditAccount({
      userId,
      balance: 0,
      totalEarned: 0,
      totalSpent: 0,
      lastGrantMonth: '',
      createdAt: Date.now()
    });
  }

  if (account.lastGrantMonth === currentMonth) {
    return account;
  }

  account.balance += MONTHLY_GRANT;
  account.totalEarned += MONTHLY_GRANT;
  account.lastGrantMonth = currentMonth;
  await account.save();

  try {
    await new CreditTransaction({
      userId,
      type: 'earn',
      amount: MONTHLY_GRANT,
      source: 'monthly_grant',
      description: `${currentMonth} 会员月度积分`,
      balanceAfter: account.balance,
      idempotencyKey,
      createdAt: Date.now()
    }).save();
  } catch (error) {
    if (!String(error.message || '').includes('duplicate key')) {
      throw error;
    }
  }

  return account;
}

async function resetCurrentUsage(userId) {
  const nowDate = new Date();
  const yearMonth = `${nowDate.getFullYear()}-${String(nowDate.getMonth() + 1).padStart(2, '0')}`;
  await UsageSummary.findOneAndUpdate(
    { userId, yearMonth },
    {
      $set: {
        voiceSeconds: 0,
        totalTokens: 0,
        inputTokens: 0,
        outputTokens: 0,
        voiceCount: 0,
        tokenCount: 0,
        updatedAt: Date.now()
      }
    },
    { upsert: false }
  );
}

async function createOrLoadOrder(orderData) {
  const existing = await IapOrder.findOne({ providerOrderKey: orderData.providerOrderKey });
  if (existing) return existing;

  try {
    return await new IapOrder(orderData).save();
  } catch (error) {
    if (String(error.message || '').includes('duplicate key')) {
      const duplicate = await IapOrder.findOne({ providerOrderKey: orderData.providerOrderKey });
      if (duplicate) return duplicate;
    }
    throw error;
  }
}

async function fulfillPurchase(options) {
  const userId = normalizeText(options.userId);
  const purchasePayload = await resolvePurchasePayload(options);
  const payload = purchasePayload.payload;
  const jwsHash = hashValue(purchasePayload.rawHashSource || stringifyForHash(payload));
  const clientProductId = normalizeText(options.clientProductId);
  const productId = extractProductId(payload, clientProductId);
  const product = PRODUCT_CONFIG[productId];

  if (!userId) {
    throw new HuaweiIapError('缺少用户身份，无法发货', 401);
  }
  if (!product) {
    throw new HuaweiIapError('商品ID未登记或不属于自动续期会员');
  }
  if (clientProductId && !PRODUCT_CONFIG[clientProductId]) {
    throw new HuaweiIapError('客户端商品ID未登记或不属于自动续期会员');
  }
  if (clientProductId && clientProductId !== productId && extractPendingProductId(payload, productId) !== clientProductId) {
    throw new HuaweiIapError('客户端商品ID与支付凭证不一致');
  }

  const purchaseState = extractPurchaseState(payload);
  if (!isSuccessfulPurchaseState(purchaseState, payload)) {
    console.warn('Huawei IAP purchase state is not active:', buildPurchaseStateSummary(payload));
    throw new HuaweiIapError(`订单未处于生效状态(status=${normalizeText(purchaseState) || 'EMPTY'})`);
  }

  const user = await User.findOne({ userId });
  if (!user) {
    throw new HuaweiIapError('用户不存在', 404);
  }

  const now = Date.now();
  const orderId = extractOrderId(payload);
  const purchaseToken = extractPurchaseToken(payload);
  const originalOrderId = extractOriginalOrderId(payload);
  const subscriptionId = extractSubscriptionId(payload);
  const eventType = options.eventType || extractEventType(payload);
  const providerOrderKey = getProviderOrderKey(orderId, jwsHash);
  const periodStartAt = extractStartAt(payload, now);
  const currentExpireAt = (user.membershipType === 'premium' && user.membershipExpireAt > now)
    ? user.membershipExpireAt
    : now;
  const periodEndAt = extractExpireAt(payload) || currentExpireAt + product.durationMs;

  const order = await createOrLoadOrder({
    provider: 'huawei',
    providerOrderKey,
    orderId,
    purchaseToken,
    originalOrderId,
    subscriptionId,
    userId,
    productId,
    productType: 'auto_renewable',
    plan: product.plan,
    environment: normalizeEnvironment(pickFirst(payload, ['environment', 'env', 'sandbox'])),
    status: eventType && /renew/i.test(eventType) ? 'renewed' : 'purchased',
    purchaseState,
    eventType,
    periodStartAt,
    periodEndAt,
    jwsHash,
    rawPurchaseData: payload,
    rawNotificationData: options.rawNotificationData || null,
    lastEventAt: now
  });

  if (order.fulfilledAt > 0) {
    applyUserMembership(user, product, productId, Math.max(order.periodEndAt || 0, periodEndAt), payload);
    await user.save();
    return {
      alreadyProcessed: true,
      user,
      order
    };
  }

  applyUserMembership(user, product, productId, periodEndAt, payload);
  await user.save();

  order.status = eventType && /renew/i.test(eventType) ? 'renewed' : 'purchased';
  order.periodStartAt = order.periodStartAt || periodStartAt;
  order.periodEndAt = Math.max(order.periodEndAt || 0, periodEndAt);
  order.fulfilledAt = now;
  order.lastEventAt = now;
  order.rawPurchaseData = payload;
  if (options.rawNotificationData) {
    order.rawNotificationData = options.rawNotificationData;
  }
  await order.save();

  try {
    await grantMonthlyCredits(userId);
  } catch (error) {
    console.warn('IAP 发放会员月度积分失败(不影响发货):', error.message);
  }

  try {
    await resetCurrentUsage(userId);
  } catch (error) {
    console.warn('IAP 重置用量统计失败(不影响发货):', error.message);
  }

  return {
    alreadyProcessed: false,
    user,
    order
  };
}

async function findRelatedOrder(payload) {
  const orderId = extractOrderId(payload);
  const purchaseToken = extractPurchaseToken(payload);
  const originalOrderId = extractOriginalOrderId(payload);
  const subscriptionId = extractSubscriptionId(payload);
  const queries = [];

  if (orderId) queries.push({ provider: 'huawei', orderId });
  if (originalOrderId) queries.push({ provider: 'huawei', originalOrderId });
  if (purchaseToken) queries.push({ provider: 'huawei', purchaseToken });
  if (subscriptionId) queries.push({ provider: 'huawei', subscriptionId });
  if (queries.length === 0) return null;

  return IapOrder.findOne({ $or: queries }).sort({ periodEndAt: -1, lastEventAt: -1 });
}

async function recalculateUserMembership(userId) {
  const user = await User.findOne({ userId });
  if (!user) return null;

  const now = Date.now();
  const activeOrder = await IapOrder.findOne({
    userId,
    provider: 'huawei',
    productId: { $in: getSupportedProductIds() },
    status: { $in: ['purchased', 'renewed', 'active', 'canceled'] },
    periodEndAt: { $gt: now }
  }).sort({ periodEndAt: -1 });

  if (activeOrder) {
    const product = PRODUCT_CONFIG[activeOrder.productId];
    if (product) {
      applyUserMembership(user, product, activeOrder.productId, activeOrder.periodEndAt, activeOrder.rawPurchaseData);
    } else {
      user.membershipType = 'premium';
      user.membershipExpireAt = activeOrder.periodEndAt;
      user.membershipRenewAt = activeOrder.periodEndAt;
      user.pendingMembershipPlan = '';
      user.pendingMembershipProductId = '';
      user.pendingMembershipEffectiveAt = 0;
    }
  } else {
    user.membershipType = 'basic';
    user.membershipPlan = '';
    user.membershipProductId = '';
    user.membershipExpireAt = 0;
    user.membershipRenewAt = 0;
    user.pendingMembershipPlan = '';
    user.pendingMembershipProductId = '';
    user.pendingMembershipEffectiveAt = 0;
  }

  await user.save();
  return user;
}

async function createOrLoadEvent(eventData) {
  const existing = await IapEvent.findOne({ idempotencyKey: eventData.idempotencyKey });
  if (existing) return existing;

  try {
    return await new IapEvent(eventData).save();
  } catch (error) {
    if (String(error.message || '').includes('duplicate key')) {
      const duplicate = await IapEvent.findOne({ idempotencyKey: eventData.idempotencyKey });
      if (duplicate) return duplicate;
    }
    throw error;
  }
}

function extractSignedPayload(body) {
  const candidates = [
    body?.jwsNotification,
    body?.jwsPurchaseOrder,
    body?.signedPayload,
    body?.signedContent,
    body?.notification,
    body?.payload
  ];

  for (const candidate of candidates) {
    const text = normalizeText(candidate);
    if (text.split('.').length === 3) return text;
  }
  return '';
}

async function applyLifecycleEvent(event, payload, rawBody) {
  const lifecycle = classifyLifecycleEvent(payload);
  const relatedOrder = await findRelatedOrder(payload);
  const userId = normalizeText(pickFirst(payload, ['userId', 'developerPayload', 'appAccountId'])) || relatedOrder?.userId || '';
  const productId = extractProductId(payload, relatedOrder?.productId || '');
  const orderId = extractOrderId(payload);
  const purchaseToken = extractPurchaseToken(payload);
  const now = Date.now();

  event.eventType = extractEventType(payload) || lifecycle;
  event.environment = normalizeEnvironment(pickFirst(payload, ['environment', 'env', 'sandbox']));
  event.orderId = orderId;
  event.purchaseToken = purchaseToken;
  event.productId = productId;
  event.userId = userId;
  event.decodedPayload = payload;

  if (lifecycle === 'purchased') {
    if (!userId) {
      event.processingStatus = 'needs_manual_review';
      event.message = '续订/购买通知未能匹配到本地用户订单';
      event.processedAt = now;
      await event.save();
      return { processed: false, needsManualReview: true, message: event.message };
    }

    const fulfilled = await fulfillPurchase({
      userId,
      purchaseData: payload,
      clientProductId: productId,
      rawNotificationData: rawBody,
      eventType: event.eventType,
      trustedDecodedPayload: true
    });
    event.processingStatus = 'processed';
    event.message = fulfilled.alreadyProcessed ? '订单已处理，跳过重复发货' : '订阅购买/续费已处理';
    event.processedAt = now;
    await event.save();
    return { processed: true, user: fulfilled.user, order: fulfilled.order, message: event.message };
  }

  if (!relatedOrder) {
    event.processingStatus = 'needs_manual_review';
    event.message = '生命周期通知未匹配到本地订单';
    event.processedAt = now;
    await event.save();
    return { processed: false, needsManualReview: true, message: event.message };
  }

  relatedOrder.eventType = event.eventType;
  relatedOrder.rawNotificationData = rawBody;
  relatedOrder.lastEventAt = now;

  if (lifecycle === 'refund') {
    relatedOrder.status = 'refunded';
    relatedOrder.refundedAt = now;
    await relatedOrder.save();
    const user = await recalculateUserMembership(relatedOrder.userId);
    event.processingStatus = 'processed';
    event.message = '退款/撤销通知已处理';
    event.processedAt = now;
    await event.save();
    return { processed: true, user, order: relatedOrder, message: event.message };
  }

  if (lifecycle === 'expired') {
    relatedOrder.status = 'expired';
    relatedOrder.expiredAt = now;
    await relatedOrder.save();
    const user = await recalculateUserMembership(relatedOrder.userId);
    event.processingStatus = 'processed';
    event.message = '订阅过期通知已处理';
    event.processedAt = now;
    await event.save();
    return { processed: true, user, order: relatedOrder, message: event.message };
  }

  if (lifecycle === 'canceled') {
    relatedOrder.status = 'canceled';
    relatedOrder.canceledAt = now;
    await relatedOrder.save();
    event.processingStatus = 'processed';
    event.message = '取消自动续期通知已记录，会员保留到当前周期结束';
    event.processedAt = now;
    await event.save();
    return { processed: true, order: relatedOrder, message: event.message };
  }

  event.processingStatus = 'ignored';
  event.message = '未识别的 IAP 通知类型，已入库待后续排查';
  event.processedAt = now;
  await event.save();
  return { processed: false, ignored: true, message: event.message };
}

async function processHuaweiNotification(body) {
  const rawBody = body || {};
  const jws = extractSignedPayload(rawBody);
  const rawHash = hashValue(stringifyForHash(rawBody));
  let decodedPayload = rawBody;
  let eventId = '';
  let idempotencyKey = `huawei:raw:${rawHash}`;

  if (jws) {
    decodedPayload = verifyJws(jws);
    eventId = extractEventId(decodedPayload);
    idempotencyKey = eventId ? `huawei:event:${eventId}` : `huawei:jws:${hashValue(jws)}`;
  }

  const event = await createOrLoadEvent({
    provider: 'huawei',
    idempotencyKey,
    eventId,
    eventType: extractEventType(decodedPayload),
    environment: normalizeEnvironment(pickFirst(decodedPayload, ['environment', 'env', 'sandbox'])),
    orderId: extractOrderId(decodedPayload),
    purchaseToken: extractPurchaseToken(decodedPayload),
    productId: extractProductId(decodedPayload),
    userId: normalizeText(pickFirst(decodedPayload, ['userId', 'developerPayload', 'appAccountId'])),
    rawPayload: rawBody,
    decodedPayload,
    processingStatus: 'received',
    receivedAt: Date.now()
  });

  if (event.processingStatus === 'processed') {
    return { processed: true, duplicate: true, message: '通知已处理，跳过重复处理' };
  }

  if (!jws) {
    event.processingStatus = 'needs_manual_review';
    event.message = '通知缺少签名载荷，已入库但未处理';
    event.processedAt = Date.now();
    await event.save();
    return { processed: false, needsManualReview: true, message: event.message };
  }

  return applyLifecycleEvent(event, decodedPayload, rawBody);
}

module.exports = {
  HuaweiIapError,
  fulfillPurchase,
  processHuaweiNotification,
  getSupportedProductIds,
  getIapRequestDiagnostics
};
