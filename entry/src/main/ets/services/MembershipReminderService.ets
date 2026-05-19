import reminderAgentManager from '@ohos.reminderAgentManager';
import notificationManager from '@ohos.notificationManager';
import dataPreferences from '@ohos.data.preferences';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('MembershipReminder');

const REMINDER_PREFS_KEY = 'chronoisle_membership_reminder';
const REMINDER_7DAY_ID_KEY = 'reminder_7day_id';
const REMINDER_3DAY_ID_KEY = 'reminder_3day_id';
const REMINDER_1DAY_ID_KEY = 'reminder_1day_id';
const REMINDER_LAST_SHOWN_KEY = 'reminder_last_shown_date';

/**
 * 会员到期提醒服务
 * - 购买会员后自动调度 7天/3天/1天 到期前系统通知
 * - APP 启动时检查是否需要弹窗提醒
 */
export class MembershipReminderService {

  /**
   * 购买成功后调用：调度到期提醒通知
   * @param context 上下文
   * @param expireAt 会员到期时间戳(ms)
   * @param isAutoRenew 是否是自动续费套餐（自动续费不需要提醒）
   */
  static async scheduleExpiryReminders(context: Context, expireAt: number, isAutoRenew: boolean): Promise<void> {
    // 自动续费套餐不需要到期提醒
    if (isAutoRenew) {
      return;
    }

    // 先取消旧的提醒
    await MembershipReminderService.cancelAllReminders(context);

    const now = Date.now();
    const prefs = await dataPreferences.getPreferences(context, REMINDER_PREFS_KEY);
    // 提前 7天、3天、1天 提醒
    interface ReminderOffset {
      days: number;
      key: string;
      content: string;
    }
    
    const reminderOffsets: ReminderOffset[] = [
      { days: 7, key: REMINDER_7DAY_ID_KEY, content: '您的四时清单会员将在7天后到期，续费可继续享受全部高级功能' },
      { days: 3, key: REMINDER_3DAY_ID_KEY, content: '您的四时清单会员将在3天后到期，请及时续费以免功能受限' },
      { days: 1, key: REMINDER_1DAY_ID_KEY, content: '您的四时清单会员明天就要到期了，立即续费保持高级体验' }
    ];

    for (const offset of reminderOffsets) {
      const triggerTime = expireAt - offset.days * 24 * 60 * 60 * 1000;

      // 跳过已经过去的提醒时间
      if (triggerTime <= now) {
        continue;
      }

      // 计算距离触发的秒数
      const secondsUntilTrigger = Math.floor((triggerTime - now) / 1000);

      try {
        const timer: reminderAgentManager.ReminderRequestTimer = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
          triggerTimeInSeconds: secondsUntilTrigger,
          actionButton: [
            { title: '去续费', type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE }
          ],
          wantAgent: {
            pkgName: 'com.sishiqingdan.app',
            abilityName: 'EntryAbility'
          },
          title: '会员到期提醒',
          content: offset.content,
          expiredContent: '会员即将到期，请及时续费',
          notificationId: 20000 + offset.days,
          slotType: notificationManager.SlotType.SOCIAL_COMMUNICATION
        };

        const reminderId = await reminderAgentManager.publishReminder(timer);
        await prefs.put(offset.key, reminderId);
        logger.debug(`已调度 ${offset.days} 天到期提醒, ID=${reminderId}`);
      } catch (e) {
        logger.warn(`调度 ${offset.days} 天提醒失败`, e as Object);
      }
    }

    await prefs.flush();
  }

  /**
   * 取消所有已调度的到期提醒
   */
  static async cancelAllReminders(context: Context): Promise<void> {
    try {
      const prefs = await dataPreferences.getPreferences(context, REMINDER_PREFS_KEY);

      const keys = [REMINDER_7DAY_ID_KEY, REMINDER_3DAY_ID_KEY, REMINDER_1DAY_ID_KEY];
      for (const key of keys) {
        const reminderId = await prefs.get(key, -1) as number;
        if (reminderId > 0) {
          try {
            await reminderAgentManager.cancelReminder(reminderId);
          } catch (e) {
            // 可能已过期或不存在，忽略
          }
          await prefs.delete(key);
        }
      }

      await prefs.flush();
    } catch (e) {
      logger.warn('取消提醒失败', e as Object);
    }
  }

  /**
   * APP 启动时检查会员到期状态
   * @returns null 表示不需要提醒；否则返回提醒文案
   */
  static async checkExpiryOnLaunch(
    context: Context,
    membershipType: string | undefined,
    membershipExpireAt: number | undefined
  ): Promise<string | null> {
    // 非高级会员，不需要提醒
    if (!membershipType || membershipType !== 'premium') {
      return null;
    }

    if (!membershipExpireAt) {
      return null;
    }

    const now = Date.now();
    const daysLeft = Math.ceil((membershipExpireAt - now) / (24 * 60 * 60 * 1000));

    // 已过期
    if (daysLeft <= 0) {
      return '您的高级会员已到期，部分功能已受限。立即续费恢复全部功能！';
    }

    // 7天内到期
    if (daysLeft <= 7) {
      // 每天最多提醒 1 次
      const prefs = await dataPreferences.getPreferences(context, REMINDER_PREFS_KEY);
      const lastShown = await prefs.get(REMINDER_LAST_SHOWN_KEY, '') as string;
      const todayStr = new Date().toISOString().split('T')[0];

      if (lastShown === todayStr) {
        return null; // 今天已经提醒过了
      }

      await prefs.put(REMINDER_LAST_SHOWN_KEY, todayStr);
      await prefs.flush();

      if (daysLeft === 1) {
        return '您的高级会员将于明天到期，续费可继续畅享全部功能';
      }
      return `您的高级会员将在 ${daysLeft} 天后到期，建议及时续费`;
    }

    return null;
  }
}
