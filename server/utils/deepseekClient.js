const axios = require('axios');

const DEFAULT_BASE_URL = 'https://api.deepseek.com';
const DEFAULT_MODEL = 'deepseek-v4-flash';

function trimTrailingSlash(value) {
  return String(value || '').replace(/\/+$/, '');
}

function getDeepSeekBaseUrl() {
  return trimTrailingSlash(process.env.DEEPSEEK_BASE_URL || DEFAULT_BASE_URL);
}

function getDeepSeekApiKey() {
  return String(process.env.DEEPSEEK_API_KEY || '').trim();
}

function getDeepSeekModel(fallbackModel) {
  return String(fallbackModel || process.env.DEEPSEEK_MODEL || DEFAULT_MODEL).trim();
}

function buildChatCompletionsUrl() {
  return `${getDeepSeekBaseUrl()}/chat/completions`;
}

function extractMessageContent(data) {
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content === 'string') {
    return content;
  }
  if (Array.isArray(content)) {
    return content
      .map((item) => (typeof item?.text === 'string' ? item.text : ''))
      .join('')
      .trim();
  }
  return '';
}

function normalizeThinkingLabel(value) {
  if (!value) {
    return 'disabled';
  }
  if (typeof value === 'string') {
    return value;
  }
  if (typeof value === 'object' && typeof value.type === 'string') {
    return value.type;
  }
  return 'custom';
}

function getUsageSummary(data) {
  const usage = data?.usage || {};
  return {
    promptTokens: Number(usage.prompt_tokens || 0),
    completionTokens: Number(usage.completion_tokens || 0),
    totalTokens: Number(usage.total_tokens || 0)
  };
}

async function createChatCompletion(options = {}) {
  const apiKey = getDeepSeekApiKey();
  if (!apiKey) {
    throw new Error('DEEPSEEK_API_KEY 未配置');
  }
  const resolvedThinking = options.thinking === undefined ? 'disabled' : options.thinking;
  const traceLabel = String(options.traceLabel || 'deepseek:unknown');
  const timeoutMs = Number(options.timeoutMs || 30000);
  const startedAt = Date.now();

  const payload = {
    model: getDeepSeekModel(options.model),
    messages: Array.isArray(options.messages) ? options.messages : [],
    temperature: options.temperature ?? 0.2
  };

  payload.thinking = typeof resolvedThinking === 'string'
    ? { type: resolvedThinking }
    : resolvedThinking;

  if (options.max_tokens !== undefined) {
    payload.max_tokens = options.max_tokens;
  }
  if (options.response_format) {
    payload.response_format = options.response_format;
  }

  const response = await axios.post(
    buildChatCompletionsUrl(),
    payload,
    {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      },
      timeout: timeoutMs
    }
  ).then((response) => {
    const durationMs = Date.now() - startedAt;
    const usage = getUsageSummary(response.data);
    console.log(
      `[deepseek] trace=${traceLabel} status=success model=${payload.model} thinking=${normalizeThinkingLabel(resolvedThinking)} timeoutMs=${timeoutMs} durationMs=${durationMs} promptTokens=${usage.promptTokens} completionTokens=${usage.completionTokens} totalTokens=${usage.totalTokens}`
    );
    return {
      data: response.data,
      model: payload.model,
      content: extractMessageContent(response.data),
      durationMs,
      usage
    };
  }).catch((error) => {
    const durationMs = Date.now() - startedAt;
    const statusCode = error?.response?.status || 0;
    const errorCode = error?.code || '';
    const errorMessage = error?.response?.data?.error?.message || error?.message || 'unknown_error';
    console.error(
      `[deepseek] trace=${traceLabel} status=failed model=${payload.model} thinking=${normalizeThinkingLabel(resolvedThinking)} timeoutMs=${timeoutMs} durationMs=${durationMs} statusCode=${statusCode} errorCode=${errorCode} message=${errorMessage}`
    );
    throw error;
  });
}

module.exports = {
  DEFAULT_BASE_URL,
  DEFAULT_MODEL,
  getDeepSeekBaseUrl,
  getDeepSeekApiKey,
  getDeepSeekModel,
  createChatCompletion,
  extractMessageContent
};
