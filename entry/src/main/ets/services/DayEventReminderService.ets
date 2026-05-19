import { CounterUnit, DayEvent, DayEventType, ReminderRule, ReminderType } from '../models/DayEvent';
import { db } from '../storage/Database';
import notificationManager from '@ohos.notificationManager';
import reminderAgentManager from '@ohos.reminderAgentManager';
import wantAgent from '@ohos.wantAgent';
import hilog from '@ohos.hilog';
import { formatDayEventDate, getCounterTargetDate, getReminderSummary, matchesReminderRuleOnDate } from '../common/DayEventUtils';

const TAG = 'DayEventReminder';
const DOMAIN = 0x0001;

export class DayEventReminderService {
  private static instance: DayEventReminderService;
  private context: Context | null = null;
  private timerId: number | null = null;

  private constructor() {}

  static getInstance(): DayEventReminderService {
    if (!DayEventReminderService.instance) {
      DayEventReminderService.instance = new DayEventReminderService();
    }
    return DayEventReminderService.instance;
  }

  async initialize(context: Context): Promise<void> {
    this.context = context;
    try {
      await notificationManager.requestEnableNotification();
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Request notification permission failed: %{public}s', JSON.stringify(error));
    }

    await this.syncAllReminders();

    if (this.timerId === null) {
      this.timerId = setInterval(() => {
        this.syncAllReminders();
      }, 60 * 60 * 1000); // 1 hour sync
    }
  }

  startReminderCheck(): void {
    // Keep for backward compatibility 
  }

  stopReminderCheck(): void {
    if (this.timerId !== null) {
      clearInterval(this.timerId);
      this.timerId = null;
    }
  }

  async checkAndSendReminders(): Promise<void> {
    await this.syncAllReminders();
  }

  async syncAllReminders(): Promise<void> {
    try {
      if (this.context) {
        await reminderAgentManager.cancelAllReminders();
      }
      const events = db.getAllDayEvents();
      const now = Date.now();
      
      let remindersPublished = 0;
      
      for (const event of events) {
        if (!event.isEnabled) {
          continue;
        }

        for (const rule of event.reminderRules) {
          if (remindersPublished >= 30) {
            return;
          }
          
           let nextTriggerTimestamp = 0;
           const currentHour = new Date().getHours();
           const currentMinute = new Date().getMinutes();
           const ruleHour = rule.hour ?? 9;
           const ruleMinute = rule.minute ?? 0;
           
           let startDayOffset = 0;
           if (currentHour > ruleHour || (currentHour === ruleHour && currentMinute >= ruleMinute)) {
             startDayOffset = 1;
           }

           for (let i = startDayOffset; i <= 365; i++) {
             const checkDate = now + i * 24 * 60 * 60 * 1000;
             if (matchesReminderRuleOnDate(event, rule, checkDate)) {
                const dateObj = new Date(checkDate);
                dateObj.setHours(ruleHour, ruleMinute, 0, 0);
                nextTriggerTimestamp = dateObj.getTime();
                break;
             }
           }

           if (nextTriggerTimestamp > 0) {
             const date = new Date(nextTriggerTimestamp);
             const reminder: reminderAgentManager.ReminderRequestCalendar = {
               reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
               dateTime: {
                 year: date.getFullYear(),
                 month: date.getMonth() + 1,
                 day: date.getDate(),
                 hour: date.getHours(),
                 minute: date.getMinutes()
               },
               title: this.getNotificationTitle(event),
               content: this.getNotificationText(event, rule),
               actionButton: [
                 { title: '我知道了', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE }
               ],
               wantAgent: {
                 pkgName: this.context?.applicationInfo.name || 'com.sishiqingdan.app',
                 abilityName: 'EntryAbility'
               },
               ringDuration: 5
             };
             await reminderAgentManager.publishReminder(reminder);
             remindersPublished++;
           }
        }
      }
    } catch(e) {
      hilog.error(DOMAIN, TAG, 'Sync reminders failed: ' + JSON.stringify(e));
    }
  }

  private getNotificationTitle(event: DayEvent): string {
    switch (event.type) {
      case DayEventType.PERIODIC:
        return `周期提醒：${event.title}`;
      case DayEventType.HABIT:
        return `习惯提醒：${event.title}`;
      case DayEventType.MILESTONE:
        return `重要日子：${event.title}`;
      case DayEventType.COUNTER:
        return `纪念日提醒：${event.title}`;
      case DayEventType.COUNTDOWN:
        return `倒计时：${event.title}`;
      default:
        return event.title;
    }
  }

  private getNotificationText(event: DayEvent, rule: ReminderRule): string {
    if (event.type === DayEventType.MILESTONE) {
      const targetDate = event.targetDate || event.startDate;
      const leadDays = rule.leadDays || 0;
      if (leadDays === 0) {
        return `${formatDayEventDate(targetDate)} 就是今天`;
      }
      return `距离 ${formatDayEventDate(targetDate)} 还有 ${leadDays} 天`;
    }

    if (event.type === DayEventType.COUNTER) {
      if (rule.type === ReminderType.COUNTER_INTERVAL) {
        const unitText = rule.offsetUnit === CounterUnit.YEAR ? '年' : rule.offsetUnit === CounterUnit.MONTH ? '个月' : '天';
        return `今天到达 ${event.title} 的第 ${rule.offsetValue || 1}${unitText}`;
      }
      if (rule.type === ReminderType.COUNTER_DATE) {
        return `今天到达你设置的纪念日期：${formatDayEventDate(rule.targetDate || Date.now())}`;
      }
    }

    if (event.type === DayEventType.COUNTDOWN && event.targetDate && rule.type === ReminderType.MILESTONE_LEAD) {
      const leadDays = rule.leadDays || 0;
      if (leadDays === 0) {
        return `${formatDayEventDate(event.targetDate)} 就是目标日`;
      }
      return `距离 ${formatDayEventDate(event.targetDate)} 还有 ${leadDays} 天`;
    }

    if (event.type === DayEventType.COUNTDOWN && event.targetDate) {
      return `${formatDayEventDate(event.targetDate)} 就是目标日`;
    }

    return getReminderSummary(rule);
  }

  async scheduleReminder(_event: DayEvent): Promise<void> {
    await this.syncAllReminders();
  }

  async cancelReminder(eventId: string): Promise<void> {
    await this.syncAllReminders();
  }
}

export const dayEventReminderService: DayEventReminderService = DayEventReminderService.getInstance();
