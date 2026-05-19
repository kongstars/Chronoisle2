import http from '@ohos.net.http';
import AppConfig from '../Utils/AppConfig';
import { authService } from './AuthService';
import { AppErrorService } from './AppErrorService';
import {
  PlanningSession, GoalDraft, GoalAssessment,
  ProgressPlan, ProgressTrack, ActionPlan,
  QualityReport, PlanningApiResponse, ClarificationQuestion
} from '../models/PlanningSession';

// 请求体接口定义
interface StartRequest {
  rawIntent: string;
  source: 'create_goal' | 'enhance_goal';
  targetGoalId?: string;
  onboarding?: boolean;
}

interface ClarificationRequest {
  sessionId: string;
  goalDraft: GoalDraft;
}

interface ProgressRequest {
  sessionId: string;
  answers: Record<string, string>;
}

interface RegenerateTrackRequest {
  sessionId: string;
  trackId: string;
  userHint?: string;
}

interface ActionsRequest {
  sessionId: string;
}

interface RegenerateActionsRequest {
  sessionId: string;
  section: 'tasks' | 'recurring' | 'countdowns';
  userHint?: string;
}

interface ReviewRequest {
  sessionId: string;
}

interface ApplySessionRequest {
  sessionId: string;
}

interface GetSessionRequest {
  sessionId: string;
}

interface SaveSessionRequest {
  session: PlanningSession;
}

async function buildHeaders(includeVisitorId: boolean = false): Promise<Record<string, string>> {
  const token = await authService.getToken();
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  } else if (includeVisitorId || GoalPlanningVisitorId.id.length > 0) {
    // 未登录时使用设备唯一标识作为 visitor-id（用于新手引导免登录体验）
    // 缓存 visitor-id 以便同一会话使用
    if (!GoalPlanningVisitorId.id) {
      GoalPlanningVisitorId.id = 'onboarding_' + Date.now().toString(36) + '_' + Math.random().toString(36).substring(2, 10);
    }
    headers['x-goal-planning-visitor-id'] = GoalPlanningVisitorId.id;
  }
  return headers;
}

class GoalPlanningVisitorId {
  static id: string = '';
}

const GOAL_PLANNING_POST_TIMEOUT_MS: number = 900000;
const GOAL_PLANNING_GET_TIMEOUT_MS: number = 60000;

async function postRequest<T, B extends Object>(
  path: string,
  body: B,
  useVisitorId: boolean = false,
  readTimeout: number = GOAL_PLANNING_POST_TIMEOUT_MS
): Promise<T> {
  const httpRequest = http.createHttp();
  try {
    const headers = await buildHeaders(useVisitorId);
    const response = await httpRequest.request(
      `${AppConfig.getBaseUrl()}${path}`,
      {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(body),
        connectTimeout: 15000,
        readTimeout: readTimeout
      }
    );
    if (response.responseCode === 200) {
      return JSON.parse(response.result as string) as T;
    }
    throw new Error(AppErrorService.fromResponse(response.responseCode, String(response.result)));
  } finally {
    httpRequest.destroy();
  }
}

async function getRequest<T>(path: string, useVisitorId: boolean = false): Promise<T> {
  const httpRequest = http.createHttp();
  try {
    const headers = await buildHeaders(useVisitorId);
    const response = await httpRequest.request(
      `${AppConfig.getBaseUrl()}${path}`,
      { method: http.RequestMethod.GET, header: headers, connectTimeout: 15000, readTimeout: GOAL_PLANNING_GET_TIMEOUT_MS }
    );
    if (response.responseCode === 200) {
      return JSON.parse(response.result as string) as T;
    }
    throw new Error(AppErrorService.fromResponse(response.responseCode, String(response.result)));
  } finally {
    httpRequest.destroy();
  }
}
// ===== API 响应类型 =====
export interface StartResponse {
  sessionId?: string;
  goalDraft?: GoalDraft;
  isSimpleTask?: boolean;
  message?: string;
  suggestedTaskTitle?: string;
}

export interface ClarificationResponse {
  questions: ClarificationQuestion[];
}

export interface ProgressResponse {
  progressPlan: ProgressPlan;
  goalAssessment?: GoalAssessment;
}

export interface RegenerateTrackResponse {
  track: ProgressTrack;
}

export interface RegenerateActionsResponse {
  actionPlan: ActionPlan;
}

export interface ReviewResponse {
  goalDraft: GoalDraft;
  progressPlan: ProgressPlan;
  actionPlan: ActionPlan;
  qualityReport: QualityReport;
}

export interface ApplySessionResponse {
  session: PlanningSession;
}

export interface GoalPlanningTraceSession {
  sessionId: string;
  stage: string;
  status: string;
  source: string;
  targetGoalId?: string;
  goalDraft?: GoalDraft;
  createdAt: number;
  updatedAt: number;
}

export interface GoalPlanningTraceFilters {
  traceType: 'all' | 'step' | 'agent';
  stepName: string;
  agentKey: string;
  status: 'all' | 'success' | 'failed' | 'partial';
  order: 'asc' | 'desc';
  limit: number;
}

export interface GoalPlanningTraceSummary {
  totalCount: number;
  stepCount: number;
  agentCount: number;
  successCount: number;
  failedCount: number;
  partialCount: number;
  fallbackCount: number;
  totalDurationMs: number;
  stepDurations: Record<string, number>;
  agentDurations: Record<string, number>;
  latestCreatedAt: number;
}

export interface GoalPlanningTraceItem {
  _id?: string;
  sessionId: string;
  userId: string;
  traceType: 'step' | 'agent';
  stepName: string;
  stage: string;
  source: string;
  status: 'success' | 'failed' | 'partial';
  agentKey: string;
  model: string;
  durationMs: number;
  fallbackUsed: boolean;
  requestPreview: string;
  responsePreview: string;
  payload?: Object | null;
  metrics?: Object | null;
  errorMessage: string;
  createdAt: number;
}

export interface GoalPlanningTraceResponse {
  session: GoalPlanningTraceSession;
  filters: GoalPlanningTraceFilters;
  summary: GoalPlanningTraceSummary;
  traces: GoalPlanningTraceItem[];
}

export interface GoalPlanningTraceQuery {
  traceType?: 'step' | 'agent';
  status?: 'success' | 'failed' | 'partial';
  order?: 'asc' | 'desc';
  limit?: number;
}

export class GoalPlanningService {
  private static readonly BASE_PATH = '/api/goal-planning';
  public static async start(
    rawIntent: string,
    source: 'create_goal' | 'enhance_goal' = 'create_goal',
    targetGoalId?: string,
    onboarding: boolean = false
  ): Promise<PlanningApiResponse<StartResponse>> {
    try {
      const body: StartRequest = { rawIntent: rawIntent, source: source };
      if (targetGoalId) {
        body.targetGoalId = targetGoalId;
      }
      if (onboarding) {
        body.onboarding = true;
      }
      return await postRequest<PlanningApiResponse<StartResponse>, StartRequest>(
        `${GoalPlanningService.BASE_PATH}/start`, body, onboarding
      );
    } catch (err) {
      const e = err as Error;
      return { success: false, message: e.message || '网络错误，请重试' } as PlanningApiResponse<StartResponse>;
    }
  }

  public static async getClarification(
    sessionId: string,
    goalDraft: GoalDraft
  ): Promise<PlanningApiResponse<ClarificationResponse>> {
    try {
      const body: ClarificationRequest = { sessionId: sessionId, goalDraft: goalDraft };
      return await postRequest<PlanningApiResponse<ClarificationResponse>, ClarificationRequest>(
        `${GoalPlanningService.BASE_PATH}/clarification`, body
      );
    } catch (err) {
      const e = err as Error;
      return { success: false, message: e.message || '获取追问失败，请重试' } as PlanningApiResponse<ClarificationResponse>;
    }
  }

  public static async generateProgress(
    sessionId: string,
    answers: Record<string, string>
  ): Promise<PlanningApiResponse<ProgressResponse>> {
    try {
      const body: ProgressRequest = { sessionId, answers };
      return await postRequest<PlanningApiResponse<ProgressResponse>, ProgressRequest>(
        `${GoalPlanningService.BASE_PATH}/progress`, body
      );
    } catch (err) {
      const e = err as Error;
      return { success: false, message: e.message || '生成进度追踪失败，请重试' } as PlanningApiResponse<ProgressResponse>;
    }
  }
  public static async regenerateTrack(
    sessionId: string,
    trackId: string,
    userHint?: string
  ): Promise<PlanningApiResponse<RegenerateTrackResponse>> {
    try {
      const body: RegenerateTrackRequest = { sessionId, trackId };
      if (userHint) body.userHint = userHint;
      return await postRequest<PlanningApiResponse<RegenerateTrackResponse>, RegenerateTrackRequest>(
        `${GoalPlanningService.BASE_PATH}/progress/regenerate`, body
      );
    } catch (err) {
      const e = err as Error;
      return { success: false, message: e.message || '重生成失败，请重试' } as PlanningApiResponse<RegenerateTrackResponse>;
    }
  }

  public static async addTrack(
    sessionId: string,
    userHint?: string
  ): Promise<PlanningApiResponse<RegenerateTrackResponse>> {
    try {
      const body: Record<string, string> = { 'sessionId': sessionId };
      if (userHint) body['userHint'] = userHint;
      return await postRequest<PlanningApiResponse<RegenerateTrackResponse>, Record<string, string>>(
        `${GoalPlanningService.BASE_PATH}/progress/add-track`, body
      );
    } catch (err) {
      const e = err as Error;
      return { success: false, message: e.message || '添加追踪失败，请重试' } as PlanningApiResponse<RegenerateTrackResponse>;
    }
  }

  public static async generateActions(
    sessionId: string
  ): Promise<PlanningApiResponse<ActionPlan>> {
    try {
      const body: ActionsRequest = { sessionId };
      return await postRequest<PlanningApiResponse<ActionPlan>, ActionsRequest>(
        `${GoalPlanningService.BASE_PATH}/actions`, body
      );
    } catch (err) {
      const e = err as Error;
      return { success: false, message: e.message || '生成行动方案失败，请重试' } as PlanningApiResponse<ActionPlan>;
    }
  }

  public static async regenerateActions(
    sessionId: string,
    section: 'tasks' | 'recurring' | 'countdowns',
    userHint?: string
  ): Promise<PlanningApiResponse<RegenerateActionsResponse>> {
    try {
      const body: RegenerateActionsRequest = { sessionId, section };
      if (userHint) body.userHint = userHint;
      return await postRequest<PlanningApiResponse<RegenerateActionsResponse>, RegenerateActionsRequest>(
        `${GoalPlanningService.BASE_PATH}/actions/regenerate`, body
      );
    } catch (err) {
      const e = err as Error;
      return { success: false, message: e.message || '重生成失败，请重试' } as PlanningApiResponse<RegenerateActionsResponse>;
    }
  }

  public static async getReview(
    sessionId: string
  ): Promise<PlanningApiResponse<ReviewResponse>> {
    try {
      const body: ReviewRequest = { sessionId };
      return await postRequest<PlanningApiResponse<ReviewResponse>, ReviewRequest>(
        `${GoalPlanningService.BASE_PATH}/review`, body
      );
    } catch (err) {
      const e = err as Error;
      return { success: false, message: e.message || '获取总览失败，请重试' } as PlanningApiResponse<ReviewResponse>;
    }
  }

  public static async applySession(
    sessionId: string
  ): Promise<PlanningApiResponse<ApplySessionResponse>> {
    try {
      const body: ApplySessionRequest = { sessionId };
      return await postRequest<PlanningApiResponse<ApplySessionResponse>, ApplySessionRequest>(
        `${GoalPlanningService.BASE_PATH}/apply`, body
      );
    } catch (err) {
      const e = err as Error;
      return { success: false, message: e.message || '采用方案失败，请重试' } as PlanningApiResponse<ApplySessionResponse>;
    }
  }

  public static async getSession(
    sessionId: string
  ): Promise<PlanningApiResponse<PlanningSession>> {
    try {
      return await getRequest<PlanningApiResponse<PlanningSession>>(
        `${GoalPlanningService.BASE_PATH}/session/${sessionId}`,
        true
      );
    } catch (err) {
      const e = err as Error;
      return { success: false, message: e.message || '草稿加载失败' } as PlanningApiResponse<PlanningSession>;
    }
  }

  public static async getTrace(
    sessionId: string,
    query: GoalPlanningTraceQuery = {}
  ): Promise<PlanningApiResponse<GoalPlanningTraceResponse>> {
    try {
      const queryParts: string[] = [];
      if (query.traceType) {
        queryParts.push(`traceType=${query.traceType}`);
      }
      if (query.status) {
        queryParts.push(`status=${query.status}`);
      }
      if (query.order) {
        queryParts.push(`order=${query.order}`);
      }
      if (query.limit !== undefined) {
        queryParts.push(`limit=${query.limit}`);
      }
      const suffix = queryParts.length > 0 ? `?${queryParts.join('&')}` : '';
      return await getRequest<PlanningApiResponse<GoalPlanningTraceResponse>>(
        `${GoalPlanningService.BASE_PATH}/trace/${sessionId}${suffix}`,
        true
      );
    } catch (err) {
      const e = err as Error;
      return { success: false, message: e.message || 'Trace 加载失败' } as PlanningApiResponse<GoalPlanningTraceResponse>;
    }
  }

  public static async saveSession(
    session: PlanningSession
  ): Promise<PlanningApiResponse<PlanningSession>> {
    try {
      const body: SaveSessionRequest = { session };
      return await postRequest<PlanningApiResponse<PlanningSession>, SaveSessionRequest>(
        `${GoalPlanningService.BASE_PATH}/session/save`,
        body
      );
    } catch (err) {
      const e = err as Error;
      return { success: false, message: e.message || '同步规划会话失败' } as PlanningApiResponse<PlanningSession>;
    }
  }
}
