import dataPreferences from '@ohos.data.preferences';
import http from '@ohos.net.http';
import AppConfig from '../Utils/AppConfig';
import { authService } from './AuthService';
import { dataSyncService } from './DataSyncService';
import { AppErrorService } from './AppErrorService';
import { db } from '../storage/Database';
import { Task, TaskStatus } from '../models/Task';
import type { CloudPlanTaskRef, CloudTaskSnapshotItem, SavedPlanTaskItem, SavedTodayPlan, TodayPlanSource } from '../models/TodayPlan';
import {
  buildTodayPlanStorageDate,
  buildTodayPlanStorageKey,
  cloneSavedTodayPlan,
  syncTodayPlanTaskProgress
} from '../models/TodayPlan';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('TodayPlanService');

interface ApiResponse<T> {
  success: boolean;
  message?: string;
  data?: T;
}

interface TodayPlanResponseData {
  planData?: Object;
  taskSnapshot?: CloudTaskSnapshotItem[];
  generatedAt?: number;
  date?: string;
}

interface AdoptedPlanResponseData {
  adoptedPlanData?: Object;
  date?: string;
  adoptedAt?: number;
}

interface SavePlanBody {
  adoptedPlanData: SavedTodayPlan;
}

interface TodayPlanRequestHeaders {
  'Content-Type': string;
  'Authorization': string;
}

export interface TodayPlanLoadResult {
  plan: SavedTodayPlan | null;
  source: TodayPlanSource;
  cloudPendingPlan: SavedTodayPlan | null;
  cloudPendingGeneratedAt?: number;
  message?: string;
}

export interface TodayPlanSaveResult {
  success: boolean;
  message: string;
}

interface ParsedPlanResult {
  plan: SavedTodayPlan | null;
  message?: string;
  generatedAt?: number;
}

type PlanTaskLike = SavedPlanTaskItem | CloudPlanTaskRef | string;

interface TaskLookupItem {
  taskId: string;
  task: Task;
}

interface SnapshotLookupItem {
  taskId: string;
  snapshot: CloudTaskSnapshotItem;
}

function createTaskLookupItem(task: Task): TaskLookupItem {
  return {
    taskId: task.id,
    task: task
  };
}

function createSnapshotLookupItem(item: CloudTaskSnapshotItem): SnapshotLookupItem {
  return {
    taskId: item.id,
    snapshot: item
  };
}

export class TodayPlanService {
  private static readonly PREFS_NAME: string = 'chronoisle_settings';
  private static readonly CONNECT_TIMEOUT: number = 5000;
  private static readonly READ_TIMEOUT: number = 7000;

  private static async getPreferences(context: Context): Promise<dataPreferences.Preferences> {
    try {
      return dataPreferences.getPreferences(context, TodayPlanService.PREFS_NAME);
    } catch (_) {
      throw new Error('Failed to get preferences');
    }
  }

  private static canUseCloud(token: string | null): boolean {
    return !!token && !token.startsWith('offline-');
  }

  private static async buildHeaders(): Promise<TodayPlanRequestHeaders | null> {
    const token = await authService.getToken();
    if (!TodayPlanService.canUseCloud(token)) {
      return null;
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    };
  }

  private static async getRequest<T>(path: string): Promise<ApiResponse<T>> {
    const headers = await TodayPlanService.buildHeaders();
    if (!headers) {
      return { success: false, message: '未登录' } as ApiResponse<T>;
    }

    const request = http.createHttp();
    try {
      const response = await request.request(`${AppConfig.getBaseUrl()}${path}`, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: TodayPlanService.CONNECT_TIMEOUT,
        readTimeout: TodayPlanService.READ_TIMEOUT
      });
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as ApiResponse<T>;
      }
      return { success: false, message: AppErrorService.fromResponse(response.responseCode, String(response.result)) } as ApiResponse<T>;
    } catch (error) {
      logger.error('TodayPlanService GET failed', error as Object);
      return { success: false, message: AppErrorService.fromUnknown(error, '网络异常') } as ApiResponse<T>;
    } finally {
      request.destroy();
    }
  }

  private static async postRequest<T, B extends Object>(path: string, body: B): Promise<ApiResponse<T>> {
    const headers = await TodayPlanService.buildHeaders();
    if (!headers) {
      return { success: false, message: '未登录' } as ApiResponse<T>;
    }

    const request = http.createHttp();
    try {
      const response = await request.request(`${AppConfig.getBaseUrl()}${path}`, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(body),
        connectTimeout: TodayPlanService.CONNECT_TIMEOUT,
        readTimeout: TodayPlanService.READ_TIMEOUT
      });
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as ApiResponse<T>;
      }
      return { success: false, message: AppErrorService.fromResponse(response.responseCode, String(response.result)) } as ApiResponse<T>;
    } catch (error) {
      logger.error('TodayPlanService POST failed', error as Object);
      return { success: false, message: AppErrorService.fromUnknown(error, '网络异常') } as ApiResponse<T>;
    } finally {
      request.destroy();
    }
  }

  private static async ensureDatabase(context: Context): Promise<void> {
    if (!db.isInitialized()) {
      await db.initialize(context);
    }
  }

  private static async getLocalTasks(context: Context): Promise<Task[]> {
    await TodayPlanService.ensureDatabase(context);
    const syncedTasks = dataSyncService.getTasks();
    if (syncedTasks.length > 0) {
      return syncedTasks;
    }
    return db.getAllTasks();
  }

  private static buildTaskLookup(tasks: Task[]): TaskLookupItem[] {
    return tasks.map((task: Task) => createTaskLookupItem(task));
  }

  private static findTaskById(taskLookup: TaskLookupItem[], taskId: string): Task | undefined {
    const matched = taskLookup.find((item: TaskLookupItem) => item.taskId === taskId);
    return matched ? matched.task : undefined;
  }

  private static buildSnapshotLookup(snapshotList: CloudTaskSnapshotItem[]): SnapshotLookupItem[] {
    return snapshotList.map((item: CloudTaskSnapshotItem) => createSnapshotLookupItem(item));
  }

  private static findSnapshotById(snapshotLookup: SnapshotLookupItem[], taskId: string): CloudTaskSnapshotItem | undefined {
    const matched = snapshotLookup.find((item: SnapshotLookupItem) => item.taskId === taskId);
    return matched ? matched.snapshot : undefined;
  }

  private static parseEstimatedMinutes(task: Task | undefined, snapshot: CloudTaskSnapshotItem | undefined): number | undefined {
    if (task && task.estimatedHours !== undefined && task.estimatedHours > 0) {
      return Math.round(task.estimatedHours * 60);
    }
    if (snapshot && snapshot.estimatedHours !== undefined && snapshot.estimatedHours > 0) {
      return Math.round(snapshot.estimatedHours * 60);
    }
    return undefined;
  }

  private static parseTaskItem(
    rawItem: PlanTaskLike,
    taskLookup: TaskLookupItem[],
    snapshotLookup: SnapshotLookupItem[],
    defaultReason: string
  ): SavedPlanTaskItem | null {
    let taskId: string = '';
    let title: string = '';
    let reason: string = defaultReason;
    let estimatedMinutes: number | undefined = undefined;
    let completed: boolean | undefined = undefined;

    if (typeof rawItem === 'string') {
      taskId = rawItem;
    } else {
      const cloudItem = rawItem as CloudPlanTaskRef;
      const savedItem = rawItem as SavedPlanTaskItem;
      taskId = cloudItem.id;
      title = savedItem.title || '';
      reason = cloudItem.reason || defaultReason;
      estimatedMinutes = savedItem.estimatedMinutes;
      completed = savedItem.completed;
    }

    if (!taskId || taskId.length === 0) {
      return null;
    }

    const task = TodayPlanService.findTaskById(taskLookup, taskId);
    const snapshot = TodayPlanService.findSnapshotById(snapshotLookup, taskId);
    if (!title || title.length === 0) {
      if (task && task.title.length > 0) {
        title = task.title;
      } else if (snapshot && snapshot.title && snapshot.title.length > 0) {
        title = snapshot.title;
      } else {
        title = taskId;
      }
    }

    if (estimatedMinutes === undefined) {
      estimatedMinutes = TodayPlanService.parseEstimatedMinutes(task, snapshot);
    }

    if (task) {
      completed = task.status === TaskStatus.COMPLETED;
    }

    if ((!reason || reason.length === 0) && task && task.isOverdue) {
      reason = '因为任务已逾期';
    } else if ((!reason || reason.length === 0) && snapshot && snapshot.isOverdue) {
      reason = '因为任务已逾期';
    }

    const item: SavedPlanTaskItem = { id: taskId, title: title };
    if (estimatedMinutes !== undefined) {
      item.estimatedMinutes = estimatedMinutes;
    }
    if (completed !== undefined) {
      item.completed = completed;
    }
    if (reason && reason.length > 0) {
      item.reason = reason;
    }
    return item;
  }

  private static normalizePlanObject(
    rawPlan: Object | undefined,
    source: TodayPlanSource,
    localTasks: Task[],
    snapshotList: CloudTaskSnapshotItem[],
    fallbackDate?: string,
    fallbackTimestamp?: number
  ): SavedTodayPlan | null {
    if (!rawPlan) {
      return null;
    }

    const taskLookup = TodayPlanService.buildTaskLookup(localTasks);
    const snapshotLookup = TodayPlanService.buildSnapshotLookup(snapshotList);
    const planData = rawPlan as SavedTodayPlan;
    const rawFocusTasks = Array.isArray(planData.focusTasks) ? planData.focusTasks : [];
    const rawDeferTasks = Array.isArray(planData.deferTasks) ? planData.deferTasks : [];

    const focusTasks: SavedPlanTaskItem[] = [];
    rawFocusTasks.forEach((item: PlanTaskLike) => {
      const parsed = TodayPlanService.parseTaskItem(item, taskLookup, snapshotLookup, '已加入今日计划');
      if (parsed) {
        focusTasks.push(parsed);
      }
    });

    const deferTasks: SavedPlanTaskItem[] = [];
    rawDeferTasks.forEach((item: PlanTaskLike) => {
      const parsed = TodayPlanService.parseTaskItem(item, taskLookup, snapshotLookup, '建议延后，释放今天带宽');
      if (parsed) {
        deferTasks.push(parsed);
      }
    });

    if (focusTasks.length === 0 && deferTasks.length === 0) {
      return null;
    }

    const normalized: SavedTodayPlan = {
      focusTasks: focusTasks,
      deferTasks: deferTasks,
      summary: planData.summary && planData.summary.length > 0 ? planData.summary : '今日计划',
      planSource: source
    };
    if (planData.totalEstimatedHours !== undefined) {
      normalized.totalEstimatedHours = planData.totalEstimatedHours;
    }
    if (planData.groupedTasks !== undefined) {
      normalized.groupedTasks = planData.groupedTasks;
    }
    normalized.adoptedAt = planData.adoptedAt || fallbackTimestamp || Date.now();
    if (planData.sourceDate !== undefined) {
      normalized.sourceDate = planData.sourceDate;
    } else if (fallbackDate !== undefined) {
      normalized.sourceDate = fallbackDate;
    }
    if (planData.sourceGeneratedAt !== undefined) {
      normalized.sourceGeneratedAt = planData.sourceGeneratedAt;
    } else if (fallbackTimestamp !== undefined) {
      normalized.sourceGeneratedAt = fallbackTimestamp;
    }

    return syncTodayPlanTaskProgress(normalized, localTasks);
  }

  public static async loadLocalPlan(context: Context): Promise<SavedTodayPlan | null> {
    try {
      const prefs = await TodayPlanService.getPreferences(context);
      const localTasks = await TodayPlanService.getLocalTasks(context);
      const localDate = buildTodayPlanStorageDate();
      const raw = await prefs.get(buildTodayPlanStorageKey(localDate), '') as string;
      if (!raw || raw.length === 0) {
        return null;
      }
      const parsed = JSON.parse(raw) as Object;
      return TodayPlanService.normalizePlanObject(parsed, 'local', localTasks, [], localDate);
    } catch (error) {
      logger.error('TodayPlanService loadLocalPlan error', error as Object);
      return null;
    }
  }

  private static async fetchAdoptedPlan(localTasks: Task[]): Promise<ParsedPlanResult> {
    const response = await TodayPlanService.getRequest<AdoptedPlanResponseData>('/api/plan/adopted');
    if (!response.success || !response.data) {
      return { plan: null, message: response.message };
    }
    const normalized = TodayPlanService.normalizePlanObject(
      response.data.adoptedPlanData,
      'cloud_adopted',
      localTasks,
      [],
      response.data.date,
      response.data.adoptedAt
    );
    return { plan: normalized, message: response.message, generatedAt: response.data.adoptedAt };
  }

  private static async fetchPendingPlan(localTasks: Task[]): Promise<ParsedPlanResult> {
    const response = await TodayPlanService.getRequest<TodayPlanResponseData>('/api/plan/today');
    if (!response.success || !response.data) {
      return { plan: null, message: response.message };
    }
    const normalized = TodayPlanService.normalizePlanObject(
      response.data.planData,
      'cloud_pending',
      localTasks,
      response.data.taskSnapshot || [],
      response.data.date,
      response.data.generatedAt
    );
    return { plan: normalized, message: response.message, generatedAt: response.data.generatedAt };
  }

  public static async persistLocalPlan(context: Context, plan: SavedTodayPlan): Promise<void> {
    const prefs = await TodayPlanService.getPreferences(context);
    const planToStore = cloneSavedTodayPlan(plan);
    const localDate = buildTodayPlanStorageDate();
    if (!planToStore.sourceDate) {
      planToStore.sourceDate = localDate;
    }

    const keys: string[] = [buildTodayPlanStorageKey(localDate)];
    if (planToStore.sourceDate !== localDate) {
      keys.push(buildTodayPlanStorageKey(planToStore.sourceDate));
    }

    const serialized = JSON.stringify(planToStore);
    try {
      for (const key of keys) {
        await prefs.put(key, serialized);
      }
      await prefs.flush();
    } catch (_) {}
  }

  public static async loadPlan(context: Context): Promise<TodayPlanLoadResult> {
    const localPlan = await TodayPlanService.loadLocalPlan(context);
    const localTasks = await TodayPlanService.getLocalTasks(context);
    const token = await authService.getToken();

    if (!TodayPlanService.canUseCloud(token)) {
      return {
        plan: localPlan,
        source: localPlan ? 'local' : 'none',
        cloudPendingPlan: null
      };
    }

    const adoptedResult = await TodayPlanService.fetchAdoptedPlan(localTasks);
    if (adoptedResult.plan) {
      await TodayPlanService.persistLocalPlan(context, adoptedResult.plan);
      return {
        plan: adoptedResult.plan,
        source: 'cloud_adopted',
        cloudPendingPlan: null
      };
    }

    const pendingResult = await TodayPlanService.fetchPendingPlan(localTasks);
    if (localPlan) {
      return {
        plan: localPlan,
        source: 'local',
        cloudPendingPlan: pendingResult.plan,
        cloudPendingGeneratedAt: pendingResult.generatedAt
      };
    }
    if (pendingResult.plan) {
      return {
        plan: pendingResult.plan,
        source: 'cloud_pending',
        cloudPendingPlan: null,
        cloudPendingGeneratedAt: pendingResult.generatedAt
      };
    }
    return {
      plan: null,
      source: 'none',
      cloudPendingPlan: null,
      message: pendingResult.message || adoptedResult.message
    };
  }

  private static preparePlanForSave(plan: SavedTodayPlan, adoptedSource: TodayPlanSource): SavedTodayPlan {
    const prepared = cloneSavedTodayPlan(plan);
    prepared.adoptedAt = Date.now();
    if (!prepared.sourceDate || prepared.sourceDate.length === 0) {
      prepared.sourceDate = buildTodayPlanStorageDate();
    }
    prepared.planSource = adoptedSource;
    return prepared;
  }

  private static async postAdoptedPlan(plan: SavedTodayPlan): Promise<TodayPlanSaveResult> {
    const result = await TodayPlanService.postRequest<Object, SavePlanBody>('/api/plan/save', {
      adoptedPlanData: plan
    });
    if (!result.success) {
      return {
        success: false,
        message: result.message || '保存失败'
      };
    }
    return {
      success: true,
      message: result.message || '今日计划已更新'
    };
  }

  public static async saveAdoptedPlan(context: Context, plan: SavedTodayPlan): Promise<TodayPlanSaveResult> {
    const adoptedSource: TodayPlanSource = plan.planSource === 'local' ? 'local' : 'cloud_adopted';
    const prepared = TodayPlanService.preparePlanForSave(plan, adoptedSource);
    const result = await TodayPlanService.postAdoptedPlan(prepared);
    if (!result.success) {
      return result;
    }
    await TodayPlanService.persistLocalPlan(context, prepared);
    return result;
  }

  public static async trySyncPlanToCloud(plan: SavedTodayPlan): Promise<boolean> {
    const adoptedSource: TodayPlanSource = plan.planSource === 'cloud_pending' ? 'cloud_adopted' : (plan.planSource || 'local');
    const prepared = TodayPlanService.preparePlanForSave(plan, adoptedSource);
    const result = await TodayPlanService.postAdoptedPlan(prepared);
    return result.success;
  }
}
