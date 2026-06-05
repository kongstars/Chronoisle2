const crypto = require('crypto');

function createTraceId() {
  if (typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  return `trace_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

function attachTraceId(req, res, next) {
  const incomingTraceId = String(req.headers['x-trace-id'] || '').trim();
  req.traceId = incomingTraceId || createTraceId();
  res.setHeader('X-Trace-Id', req.traceId);
  next();
}

function sendSuccess(res, payload = {}, status = 200) {
  return res.status(status).json({
    success: true,
    traceId: res.req?.traceId || '',
    ...payload
  });
}

function sendError(res, status, errorCode, message, extra = {}) {
  return res.status(status).json({
    success: false,
    errorCode,
    message,
    traceId: res.req?.traceId || '',
    ...extra
  });
}

function logRequestError(scope, req, error, message) {
  const traceId = req?.traceId || 'unknown';
  const safeMessage = message || 'Unhandled error';
  console.error(`[${scope}] trace=${traceId} ${safeMessage}:`, error);
}

module.exports = {
  attachTraceId,
  sendSuccess,
  sendError,
  logRequestError
};
