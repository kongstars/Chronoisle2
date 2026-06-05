import { TelemetryService, TelemetryProperties } from './TelemetryService';
import { TelemetryErrorCode } from '../models/TelemetryErrorCode';

interface BaseTelemetryProperties extends TelemetryProperties {
  code: TelemetryErrorCode;
  msg: string;
  path: string;
}

function getTelemetryMessage(error: string | Object): string {
  if (typeof error === 'string') {
    return error.substring(0, 50);
  }
  return String(error).substring(0, 50);
}

function createBaseProperties(
  code: TelemetryErrorCode,
  error: string | Object,
  path: string
): BaseTelemetryProperties {
  const props: BaseTelemetryProperties = {
    code: code,
    msg: getTelemetryMessage(error),
    path: path
  };
  return props;
}

function mergeTelemetryProperties(
  target: BaseTelemetryProperties,
  source?: TelemetryProperties
): BaseTelemetryProperties {
  if (!source) {
    return target;
  }

  const keys: string[] = Object.keys(source);
  for (let i = 0; i < keys.length; i += 1) {
    const key: string = keys[i];
    target[key] = source[key];
  }
  return target;
}

export function trackApiError(
  code: TelemetryErrorCode,
  error: string | Object,
  path: string,
  additionalProps?: TelemetryProperties
): void {
  const properties: BaseTelemetryProperties = mergeTelemetryProperties(
    createBaseProperties(code, error, path),
    additionalProps
  );

  TelemetryService.track('api_error', properties, 'other');
}

export function trackNetworkError(
  path: string,
  error: string | Object,
  httpCode?: number
): void {
  // 使用 HTTP 错误码时使用 ERR_HTTP_EXCEPTION，否则使用 ERR_NET_TIMEOUT
  const errorCode = httpCode !== undefined
    ? TelemetryErrorCode.ERR_HTTP_EXCEPTION
    : TelemetryErrorCode.ERR_NET_TIMEOUT;

  const props: BaseTelemetryProperties = createBaseProperties(
    errorCode,
    error,
    path
  );

  if (httpCode !== undefined) {
    props.httpCode = httpCode;
  }

  TelemetryService.track('api_error', props, 'other');
}

export function trackAuthError(
  path: string,
  error: string | Object,
  errorType: TelemetryErrorCode = TelemetryErrorCode.ERR_AUTH_TOKEN_EXPIRED
): void {
  const props: BaseTelemetryProperties = createBaseProperties(errorType, error, path);
  TelemetryService.track('api_error', props, 'other');
}

export function trackAIError(
  path: string,
  error: string | Object,
  errorType: TelemetryErrorCode = TelemetryErrorCode.ERR_AI_JSON_PARSE_FAIL
): void {
  const props: BaseTelemetryProperties = createBaseProperties(errorType, error, path);
  TelemetryService.track('api_error', props, 'ai');
}
