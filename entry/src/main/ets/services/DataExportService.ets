import fs from '@ohos.file.fs';
import picker from '@ohos.file.picker';
import BuildProfile from 'BuildProfile';

import { db } from '../storage/Database';
import { authService, UserAccount } from './AuthService';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('DataExportService');

/**
 * 单次导出的元信息，用户能直接看到自己导出的范围。
 */
export interface DataExportSummary {
  goals: number;
  tasks: number;
  dayEvents: number;
  pomodoros: number;
}

/**
 * 导出结果。
 * - cancelled：用户在系统文件选择器中点了取消。
 * - success：导出成功并写入用户选择的文件。
 * - failure：写入或读取数据时出现异常。
 */
export interface DataExportResult {
  status: 'success' | 'cancelled' | 'failure';
  summary?: DataExportSummary;
  filename?: string;
  message?: string;
}

interface ExportPayload {
  meta: ExportMeta;
  user: ExportUser | null;
  data: ExportData;
}

interface ExportMeta {
  appName: string;
  appVersion: string;
  exportedAt: string;
  format: string;
  notice: string;
}

interface ExportUser {
  userId: string;
  account: string;
  accountType: string;
  nickname?: string;
  membershipType?: string;
}

interface ExportData {
  goals: object[];
  tasks: object[];
  dayEvents: object[];
  pomodoros: object[];
}

/**
 * 数据导出服务
 *
 * 上架合规要求：用户可以一键导出自己的目标、任务、提醒、专注记录。
 * 导出格式选用 JSON，便于二次处理；同时附带导出元信息，便于排查。
 *
 * 数据来源：直接从本地 Database（已和云端双向同步）读取，避免再次请求服务端。
 */
export class DataExportService {
  static async export(): Promise<DataExportResult> {
    try {
      const exportData = DataExportService.collectAll();
      const user = await authService.getCurrentUser();
      const payload: ExportPayload = {
        meta: DataExportService.buildMeta(),
        user: DataExportService.buildUserSnapshot(user),
        data: exportData
      };

      const json = JSON.stringify(payload, null, 2);
      const filename = DataExportService.buildFilename(user);

      const saveResult = await DataExportService.writeToUserPickedFile(filename, json);
      if (saveResult === 'cancelled') {
        return { status: 'cancelled' };
      }

      return {
        status: 'success',
        summary: {
          goals: exportData.goals.length,
          tasks: exportData.tasks.length,
          dayEvents: exportData.dayEvents.length,
          pomodoros: exportData.pomodoros.length
        },
        filename
      };
    } catch (error) {
      logger.error('export failed', error as Object);
      return {
        status: 'failure',
        message: '导出失败，请稍后重试'
      };
    }
  }

  private static collectAll(): ExportData {
    return {
      goals: DataExportService.toPlainArray(db.getAllGoals() as object[]),
      tasks: DataExportService.toPlainArray(db.getAllTasks() as object[]),
      dayEvents: DataExportService.toPlainArray(db.getAllDayEvents() as object[]),
      pomodoros: DataExportService.toPlainArray(db.getAllPomodoros() as object[])
    };
  }

  private static toPlainArray(items: object[]): object[] {
    if (!items || items.length === 0) {
      return [];
    }
    // 用 JSON 序列化 + 解析，剥离类原型上的方法，得到纯数据对象。
    return JSON.parse(JSON.stringify(items)) as object[];
  }

  private static buildMeta(): ExportMeta {
    return {
      appName: '四时清单',
      appVersion: BuildProfile.VERSION_NAME as string,
      exportedAt: new Date().toISOString(),
      format: 'chronoisle-export-v1',
      notice: '本文件包含您在四时清单中的全部业务数据，请妥善保管，避免泄露给第三方。'
    };
  }

  private static buildUserSnapshot(user: UserAccount | null): ExportUser | null {
    if (!user) {
      return null;
    }
    return {
      userId: user.userId,
      account: user.account,
      accountType: user.accountType as string,
      nickname: user.nickname,
      membershipType: user.membershipType
    };
  }

  private static buildFilename(user: UserAccount | null): string {
    const dateStr = new Date().toISOString().split('T')[0];
    const idHint = user ? `_${user.userId.slice(-6)}` : '';
    return `Chronoisle_Export_${dateStr}${idHint}.json`;
  }

  private static async writeToUserPickedFile(filename: string, content: string): Promise<'success' | 'cancelled'> {
    const documentSaveOptions = new picker.DocumentSaveOptions();
    documentSaveOptions.newFileNames = [filename];

    const documentViewPicker = new picker.DocumentViewPicker();
    const saveResult = await documentViewPicker.save(documentSaveOptions);
    if (!saveResult || saveResult.length === 0) {
      return 'cancelled';
    }

    const uri = saveResult[0];
    const file = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
    try {
      await fs.write(file.fd, content);
    } finally {
      await fs.close(file);
    }
    return 'success';
  }
}
