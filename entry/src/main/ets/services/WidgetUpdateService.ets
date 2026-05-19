import formBindingData from '@ohos.app.form.formBindingData';
import formProvider from '@ohos.app.form.formProvider';
import dataPreferences from '@ohos.data.preferences';
import hilog from '@ohos.hilog';
import common from '@ohos.app.ability.common';
import { TaskData, TaskStatus } from '../models/Task';
import { WidgetTask, WidgetFormData } from '../models/WidgetData';

export class WidgetUpdateService {
  private static instance: WidgetUpdateService;

  private constructor() {}

  static getInstance(): WidgetUpdateService {
    if (!WidgetUpdateService.instance) {
      WidgetUpdateService.instance = new WidgetUpdateService();
    }
    return WidgetUpdateService.instance;
  }

  async updateAllWidgets(context: common.UIAbilityContext | common.ExtensionContext): Promise<void> {
    try {
      let prefs = await dataPreferences.getPreferences(context, { name: 'widget_storage' });
      let formIdsJson = await prefs.get('formIds', '[]');
      let formIds: string[] = JSON.parse(formIdsJson as string);

      if (formIds.length === 0) {
        return;
      }

      // Read tasks data
      let lifeGoalsPrefs = await dataPreferences.getPreferences(context, { name: 'life_goal_storage' });
      let tasksJson = await lifeGoalsPrefs.get('tasks', '[]');
      let tasks: TaskData[] = JSON.parse(tasksJson as string);

      // Filter and sort today's tasks
      let pendingTasks = tasks.filter((task) => task.status === TaskStatus.PENDING);
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayEnd = new Date(todayStart.getTime() + 24 * 60 * 60 * 1000 - 1);
      
      let todayTasks = pendingTasks.filter(task => {
        if (!task.dueDate) return true;
        return task.dueDate <= todayEnd.getTime();
      });

      todayTasks.sort((a, b) => {
        if (a.isPinned !== b.isPinned) return a.isPinned ? -1 : 1;
        if (a.dueDate && b.dueDate) return a.dueDate - b.dueDate;
        return (b.createdAt || 0) - (a.createdAt || 0);
      });

      let widgetTasks: WidgetTask[] = todayTasks.slice(0, 10).map(t => {
        let wt = new WidgetTask();
        wt.id = t.id;
        wt.title = t.title;
        wt.dueDate = t.dueDate;
        wt.isPinned = t.isPinned ?? false;
        return wt;
      });

      let formData = new WidgetFormData();
      formData.tasks = widgetTasks;

      let bindingData = formBindingData.createFormBindingData(formData);

      for (const formId of formIds) {
        try {
          await formProvider.updateForm(formId, bindingData);
          hilog.info(0x0000, 'WidgetUpdate', 'Widget updated successfully: %{public}s', formId);
        } catch (updateErr) {
          hilog.error(0x0000, 'WidgetUpdate', 'Failed to update widget: %{public}s', formId);
        }
      }
    } catch (e) {
      hilog.error(0x0000, 'WidgetUpdate', 'updateAllWidgets error: %{public}s', JSON.stringify(e));
    }
  }
}

export const widgetUpdateService = WidgetUpdateService.getInstance();
