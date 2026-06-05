// Widget 刷新服务 - 在数据变更时触发桌面卡片更新
import formBindingData from '@ohos.app.form.formBindingData';
import formProvider from '@ohos.app.form.formProvider';
import dataPreferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';
import type { common } from '@kit.AbilityKit';
import { WidgetFormDataPayload, WidgetFormDataService, WidgetType } from './WidgetFormDataService';

const TAG = 'WidgetRefreshService';
const WIDGET_STORAGE_NAME = 'widget_storage';
const FORM_IDS_KEY = 'formIds';
const FORM_NAME_KEY_PREFIX = 'formName_';

export class WidgetRefreshService {
  private static instance: WidgetRefreshService;
  private context: common.UIAbilityContext | null = null;

  private constructor() {}

  static getInstance(): WidgetRefreshService {
    if (!WidgetRefreshService.instance) {
      WidgetRefreshService.instance = new WidgetRefreshService();
    }
    return WidgetRefreshService.instance;
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
  }

  async refreshAllWidgets(): Promise<void> {
    if (!this.context) {
      hilog.error(0x0000, TAG, 'Context not initialized');
      return;
    }

    try {
      const formIds = await this.readFormIds();
      if (formIds.length === 0) {
        hilog.info(0x0000, TAG, 'No active widgets to refresh');
        return;
      }

      hilog.info(0x0000, TAG, 'Refreshing %{public}d widgets', formIds.length);
      for (const formId of formIds) {
        await this.refreshWidget(formId);
      }
    } catch (error) {
      hilog.error(0x0000, TAG, 'refreshAllWidgets error: %{public}s', JSON.stringify(error));
    }
  }

  async refreshWidgetsByType(formName: string): Promise<void> {
    if (!this.context) {
      return;
    }

    try {
      const formIds = await this.readFormIds();
      for (const formId of formIds) {
        const storedFormName = await this.readFormName(formId);
        if (storedFormName === formName) {
          await this.refreshWidget(formId);
          hilog.info(0x0000, TAG, 'Widget %{public}s (%{public}s) refreshed', formId, formName);
        }
      }
    } catch (error) {
      hilog.error(0x0000, TAG, 'refreshWidgetsByType error: %{public}s', JSON.stringify(error));
    }
  }

  async removeFormId(formId: string): Promise<void> {
    if (!this.context) {
      return;
    }

    try {
      const prefs = await dataPreferences.getPreferences(this.context, { name: WIDGET_STORAGE_NAME });
      const formIds = await this.readFormIds();
      const nextIds = formIds.filter((id: string) => id !== formId);

      await prefs.put(FORM_IDS_KEY, JSON.stringify(nextIds));
      await prefs.delete(`${FORM_NAME_KEY_PREFIX}${formId}`);
      await prefs.flush();

      hilog.info(0x0000, TAG, 'FormId %{public}s removed, remaining: %{public}d',
        formId, nextIds.length);
    } catch (error) {
      hilog.error(0x0000, TAG, 'removeFormId error: %{public}s', JSON.stringify(error));
    }
  }

  private async refreshWidget(formId: string): Promise<void> {
    if (!this.context) {
      return;
    }
    try {
      const formName = await this.readFormName(formId);
      const payload: WidgetFormDataPayload = await WidgetFormDataService.buildFormData(this.context, formName);
      const bindingData = formBindingData.createFormBindingData(payload);
      await formProvider.updateForm(formId, bindingData);
      hilog.info(0x0000, TAG, 'Widget %{public}s refreshed', formId);
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to refresh widget %{public}s: %{public}s',
        formId, JSON.stringify(error));
    }
  }

  private async readFormIds(): Promise<string[]> {
    if (!this.context) {
      return [];
    }
    try {
      const prefs = await dataPreferences.getPreferences(this.context, { name: WIDGET_STORAGE_NAME });
      const raw = await prefs.get(FORM_IDS_KEY, '[]') as string;
      try {
        return JSON.parse(raw) as string[];
      } catch (error) {
        return [];
      }
    } catch (_) {
      return [];
    }
  }

  private async readFormName(formId: string): Promise<string> {
    if (!this.context) {
      return WidgetType.VOICE;
    }
    try {
      const prefs = await dataPreferences.getPreferences(this.context, { name: WIDGET_STORAGE_NAME });
      const value = await prefs.get(`${FORM_NAME_KEY_PREFIX}${formId}`, WidgetType.VOICE) as string;
      return WidgetFormDataService.normalizeFormName(value);
    } catch (_) {
      return WidgetType.VOICE;
    }
  }
}

export const widgetRefreshService = WidgetRefreshService.getInstance();
