import { Goal, GoalCategory, KeyResultData, GoalData } from '../models/Goal';
import { Task, TaskStatus, TaskData } from '../models/Task';
import { DayEvent, DayEventData } from '../models/DayEvent';
import { Pomodoro, PomodoroData } from '../models/Pomodoro';
import http from '@ohos.net.http';
import AppConfig from '../Utils/AppConfig';
import { authService } from './AuthService';
import { TelemetryProperties } from '../services/TelemetryService';
import { TelemetryService } from './TelemetryService';
import { TelemetryErrorCode } from '../models/TelemetryErrorCode';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('CloudSyncService');
interface ApiResponse<T> {
  success: boolean;
  message: string;
  data?: T;
  debugCode?: string;
}

interface SyncDataResponse {
  goals?: GoalData[];
  tasks?: TaskData[];
  dayEvents?: DayEventData[];
  pomodoros?: PomodoroData[];
}

export interface SyncDataSet {
  goals: Goal[];
  tasks: Task[];
  dayEvents: DayEvent[];
  pomodoros: Pomodoro[];
}

export interface DatabaseAdapter {
  exportData(): SyncDataSet;
  replaceAllData(goals: Goal[], tasks: Task[], dayEvents?: DayEvent[], pomodoros?: Pomodoro[]): Promise<void>;
}

class CloudSyncService {
  // 保持与旧接口兼容
  async initialize(context: Context): Promise<void> {
    // No-op, data is now fetched from the cloud directly
  }

  // 从云端拉取数据
  async fetchCloudData(): Promise<SyncDataSet> {
    try {
      const token = await authService.getToken();
      if (!token) throw new Error('AUTH_REQUIRED');

      const baseUrl = AppConfig.getBaseUrl();
      let httpRequest = http.createHttp();

      const response = await httpRequest.request(`${baseUrl}/api/sync/data`, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        connectTimeout: 10000,
        readTimeout: 10000
      });

      if (response.responseCode === 401 || response.responseCode === 403) {
        throw new Error('AUTH_FAILED');
      }

      if (response.responseCode !== 200) {
        throw new Error(`SERVER_ERROR:${response.responseCode}`);
      }

      const result: ApiResponse<SyncDataResponse> = JSON.parse(response.result as string);
      if (result.success && result.data) {
        const rawGoals: GoalData[] = result.data?.goals || [];
        const rawTasks: TaskData[] = result.data?.tasks || [];
        const rawDayEvents: DayEventData[] = result.data?.dayEvents || [];
        const rawPomodoros: PomodoroData[] = result.data?.pomodoros || [];
        return {
          goals: rawGoals.map((g: GoalData) => Goal.fromJSON(g)),
          tasks: rawTasks.map((t: TaskData) => Task.fromJSON(t)),
          dayEvents: rawDayEvents.map((d: DayEventData) => DayEvent.fromJSON(d)),
          pomodoros: rawPomodoros.map((p: PomodoroData) => Pomodoro.fromJSON(p))
        };
      }

      return { goals: [], tasks: [], dayEvents: [], pomodoros: [] };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      logger.error('CloudSyncService fetchCloudData error:', message as Object);
      (() => { let _p: TelemetryProperties = {
        "code": TelemetryErrorCode.ERR_SYNC_DOWNLOAD_FAIL,
        "msg": message.substring(0, 50),
        "path": 'sync/data'
      }; TelemetryService.track('api_error', _p, 'other'); })();
      throw new Error(message);
    }
  }

  // 检查云端是否曾经有过记录
  async hasCloudHistory(): Promise<boolean> {
    try {
      const data = await this.fetchCloudData();
      return data.goals.length > 0 || data.tasks.length > 0 || data.dayEvents.length > 0 || data.pomodoros.length > 0;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (message.startsWith('AUTH_')) {
        return false;
      }
      logger.error('CloudSyncService hasCloudHistory error:', message as Object);
      return false;
    }
  }

  // 合并本地和云端数据
  mergeData(local: SyncDataSet, cloud: SyncDataSet): SyncDataSet {
    const goalMap: Record<string, Goal> = {};
    local.goals.forEach((goal: Goal) => { goalMap[goal.id] = goal; });
    cloud.goals.forEach((goal: Goal) => {
      const existing = goalMap[goal.id];
      if (!existing || goal.updatedAt > existing.updatedAt) {
        goalMap[goal.id] = goal;
      }
    });

    const taskMap: Record<string, Task> = {};
    local.tasks.forEach((task: Task) => { taskMap[task.id] = task; });
    cloud.tasks.forEach((task: Task) => {
      const existing = taskMap[task.id];
      if (!existing || task.updatedAt > existing.updatedAt) {
        taskMap[task.id] = task;
      }
    });

    const dayEventMap: Record<string, DayEvent> = {};
    local.dayEvents.forEach((event: DayEvent) => { dayEventMap[event.id] = event; });
    cloud.dayEvents.forEach((event: DayEvent) => {
      const existing = dayEventMap[event.id];
      if (!existing || event.updatedAt > existing.updatedAt) {
        dayEventMap[event.id] = event;
      }
    });

    const pomodoroMap: Record<string, Pomodoro> = {};
    local.pomodoros.forEach((pomo: Pomodoro) => { pomodoroMap[pomo.id] = pomo; });
    cloud.pomodoros.forEach((pomo: Pomodoro) => {
      const existing = pomodoroMap[pomo.id];
      // Pomodoros don't have updatedAt typically, they are immutable once completed
      // If we need to merge, just check existence
      if (!existing) {
        pomodoroMap[pomo.id] = pomo;
      }
    });

    const goals: Goal[] = Object.values(goalMap).sort((a: Goal, b: Goal) => b.updatedAt - a.updatedAt);
    const tasks: Task[] = Object.values(taskMap).sort((a: Task, b: Task) => b.updatedAt - a.updatedAt);
    const dayEvents: DayEvent[] = Object.values(dayEventMap).sort((a: DayEvent, b: DayEvent) => b.updatedAt - a.updatedAt);
    const pomodoros: Pomodoro[] = Object.values(pomodoroMap).sort((a: Pomodoro, b: Pomodoro) => b.createdAt - a.createdAt);

    return { goals, tasks, dayEvents, pomodoros };
  }

  // 执行双向同步
  async sync(db: DatabaseAdapter): Promise<void> {
    const localData = db.exportData();
    try {
      const cloudData = await this.fetchCloudData();
      const mergedData = this.mergeData(localData, cloudData);

      await db.replaceAllData(mergedData.goals, mergedData.tasks, mergedData.dayEvents, mergedData.pomodoros);
      await this.uploadData(mergedData);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (message.startsWith('AUTH_')) {
        logger.error('CloudSyncService sync: auth failed, keeping local data intact');
        return;
      }
      logger.error('CloudSyncService sync error:', message as Object);
    }
  }

  // 完全从云端下载强制覆盖本地
  async downloadAndReplace(db: DatabaseAdapter): Promise<void> {
    try {
      const cloudData = await this.fetchCloudData();
      await db.replaceAllData(cloudData.goals, cloudData.tasks, cloudData.dayEvents, cloudData.pomodoros);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (message.startsWith('AUTH_')) {
        logger.error('CloudSyncService downloadAndReplace: auth failed, keeping local data intact');
        return;
      }
      logger.error('CloudSyncService downloadAndReplace error:', message as Object);
    }
  }

  // 推送数据覆盖云端
  async uploadData(dataSet: SyncDataSet): Promise<void> {
    try {
      const token = await authService.getToken();
      if (!token) throw new Error('未授权');
      const goalDataList = dataSet.goals.map((g: Goal) => JSON.parse(JSON.stringify(g)) as GoalData);
      const taskDataList = dataSet.tasks.map((t: Task) => JSON.parse(JSON.stringify(t)) as TaskData);
      const dayEventDataList = dataSet.dayEvents.map((d: DayEvent) => JSON.parse(JSON.stringify(d)) as DayEventData);
      const pomodoroDataList = dataSet.pomodoros.map((p: Pomodoro) => JSON.parse(JSON.stringify(p)) as PomodoroData);
      
      const baseUrl = AppConfig.getBaseUrl();
      let httpRequest = http.createHttp();
      
      await httpRequest.request(`${baseUrl}/api/sync/data`, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        extraData: JSON.stringify({ 
          goals: goalDataList, 
          tasks: taskDataList, 
          dayEvents: dayEventDataList, 
          pomodoros: pomodoroDataList 
        }),
        connectTimeout: 10000,
        readTimeout: 10000
      });
    } catch (error) {
      logger.error('CloudSyncService uploadData error:', error as Object);
      (() => { let _p: TelemetryProperties = { 
        "code": TelemetryErrorCode.ERR_SYNC_UPLOAD_FAIL, 
        "msg": String(error).substring(0, 50),
        "path": 'sync/data/upload'
      }; TelemetryService.track('api_error', _p, 'other'); })();
    }
  }
}

export const cloudSyncService = new CloudSyncService();