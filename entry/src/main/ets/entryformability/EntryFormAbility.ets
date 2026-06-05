import FormExtensionAbility from '@ohos.app.form.FormExtensionAbility';
import formBindingData from '@ohos.app.form.formBindingData';
import formInfo from '@ohos.app.form.formInfo';
import formProvider from '@ohos.app.form.formProvider';
import type Want from '@ohos.app.ability.Want';
import dataPreferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';
import { WidgetFormDataPayload, WidgetFormDataService, WidgetType } from '../services/WidgetFormDataService';

const TAG: string = 'EntryFormAbility';
const WIDGET_STORAGE_NAME: string = 'widget_storage';
const FORM_IDS_KEY: string = 'formIds';
const FORM_NAME_KEY_PREFIX: string = 'formName_';
const FORM_ID_PARAM: string = 'ohos.extra.param.key.form_identity';
const FORM_NAME_PARAM: string = 'ohos.extra.param.key.form_name';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = this.readStringParameter(want, FORM_ID_PARAM);
    const formName = WidgetFormDataService.normalizeFormName(this.readStringParameter(want, FORM_NAME_PARAM));

    hilog.info(0x0000, TAG, 'onAddForm: formId=%{public}s, formName=%{public}s',
      formId.length > 0 ? formId : 'unknown', formName);

    this.persistFormInfo(formId, formName).catch(() => {});
    if (formId.length > 0) {
      this.updateFormData(formId, formName).catch(() => {});
    }

    return this.createBindingData(WidgetFormDataService.buildDefaultFormData(formName));
  }

  async onUpdateForm(formId: string): Promise<void> {
    try {
      const formName = await this.getStoredFormName(formId);
      await this.updateFormData(formId, formName);
      hilog.info(0x0000, TAG, 'onUpdateForm success: formId=%{public}s, formName=%{public}s', formId, formName);
    } catch (error) {
      hilog.error(0x0000, TAG, 'onUpdateForm failed: %{public}s', JSON.stringify(error));
    }
  }

  async onRemoveForm(formId: string): Promise<void> {
    try {
      const prefs = await dataPreferences.getPreferences(this.context, { name: WIDGET_STORAGE_NAME });
      const raw = await prefs.get(FORM_IDS_KEY, '[]') as string;
      const formIds = this.parseFormIds(raw);
      const nextIds = formIds.filter((id: string) => id !== formId);
      await prefs.put(FORM_IDS_KEY, JSON.stringify(nextIds));
      await prefs.delete(`${FORM_NAME_KEY_PREFIX}${formId}`);
      await prefs.flush();
      hilog.info(0x0000, TAG, 'onRemoveForm success: formId=%{public}s', formId);
    } catch (error) {
      hilog.error(0x0000, TAG, 'onRemoveForm failed: %{public}s', JSON.stringify(error));
    }
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }

  private readStringParameter(want: Want, key: string): string {
    if (!want.parameters) {
      return '';
    }
    const value = want.parameters[key] as string | undefined;
    return value || '';
  }

  private async persistFormInfo(formId: string, formName: string): Promise<void> {
    if (formId.length === 0) {
      return;
    }

    try {
      const prefs = await dataPreferences.getPreferences(this.context, { name: WIDGET_STORAGE_NAME });
      const raw = await prefs.get(FORM_IDS_KEY, '[]') as string;
      const formIds = this.parseFormIds(raw);
      if (!formIds.includes(formId)) {
        formIds.push(formId);
      }
      await prefs.put(FORM_IDS_KEY, JSON.stringify(formIds));
      await prefs.put(`${FORM_NAME_KEY_PREFIX}${formId}`, formName);
      await prefs.flush();
    } catch (error) {
      hilog.error(0x0000, TAG, 'persistFormInfo failed: %{public}s', JSON.stringify(error));
    }
  }

  private async getStoredFormName(formId: string): Promise<string> {
    try {
      const prefs = await dataPreferences.getPreferences(this.context, { name: WIDGET_STORAGE_NAME });
      const value = await prefs.get(`${FORM_NAME_KEY_PREFIX}${formId}`, WidgetType.VOICE) as string;
      return WidgetFormDataService.normalizeFormName(value);
    } catch (_) {
      return WidgetType.VOICE;
    }
  }

  private async updateFormData(formId: string, formName: string): Promise<void> {
    try {
      const payload: WidgetFormDataPayload = await WidgetFormDataService.buildFormData(this.context, formName);
      await formProvider.updateForm(formId, this.createBindingData(payload));
    } catch (_) {}
  }

  private createBindingData(payload: WidgetFormDataPayload): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(payload);
  }

  private parseFormIds(raw: string): string[] {
    try {
      return JSON.parse(raw) as string[];
    } catch (error) {
      return [];
    }
  }
}
