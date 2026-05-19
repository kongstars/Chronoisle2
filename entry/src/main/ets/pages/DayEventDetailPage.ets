import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { db } from '../storage/Database';
import { CounterUnit, DayEvent, DayEventType, getEventTypeIcon, getEventTypeLabel, ReminderRule, ReminderType } from '../models/DayEvent';
import { Task, TaskStatus } from '../models/Task';
import {
  formatDayEventDate,
  formatDayEventTime,
  getCounterTargetDate,
  startOfDay
} from '../common/DayEventUtils';
import {
  getNextReminderOccurrenceTime,
  getReminderCompletionCandidate,
  getReminderCompletionCount,
  getReminderPeriodProgress
} from '../services/ReminderTaskService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppHeroPanel } from '../ui/base/AppHeroPanel';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppPanelSection } from '../ui/base/AppPanelSection';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { SPACE_LG, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_META } from '../foundation/tokens/TypographyTokens';
import { BUTTON_HEIGHT_SM } from '../foundation/tokens/PageDensityTokens';
import { RADIUS_XL } from '../foundation/tokens/RadiusTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('DayEventDetailPage');

interface DetailField {
  label: string;
  value: string;
}

@Entry
@Component
struct DayEventDetailPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State event: DayEvent | null = null;
  @State tasks: Task[] = [];
  @State loading: boolean = true;
  @State eventId: string = '';

  async aboutToAppear(): Promise<void> {
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    this.eventId = params?.['eventId'] || '';
    await this.loadData();
  }

  onPageShow(): void {
    if (this.eventId) {
      this.refreshCurrentData();
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch (_) {
    }
  }

  private async loadData(): Promise<void> {
    this.loading = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await db.initialize(context);
      this.refreshCurrentData();
    } catch (error) {
      logger.error('DayEventDetailPage load error', error as Object);
      this.event = null;
      this.tasks = [];
    } finally {
      this.loading = false;
    }
  }

  private refreshCurrentData(): void {
    this.event = this.eventId ? db.getDayEventById(this.eventId) || null : null;
    this.tasks = db.getAllTasks();
  }

  private getRuleText(rule: ReminderRule): string {
    switch (rule.type) {
      case ReminderType.PERIODIC_DAILY:
      case ReminderType.HABIT_DAILY:
        return `每天 ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      case ReminderType.PERIODIC_WEEKLY: {
        const labels = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
        return `每${labels[rule.weekday ?? 1]} ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      }
      case ReminderType.PERIODIC_MONTHLY:
        return `每月 ${rule.dayOfMonth ?? 1} 日 ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      case ReminderType.PERIODIC_INTERVAL:
        return `每隔 ${rule.intervalDays ?? 1} 天 ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      case ReminderType.HABIT_WEEKLY_TARGET:
        return `每周 ${rule.timesPerPeriod ?? 1} 次 · ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      case ReminderType.HABIT_MONTHLY_TARGET:
        return `每月 ${rule.timesPerPeriod ?? 1} 次 · ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      case ReminderType.MILESTONE_LEAD:
        return `提前 ${rule.leadDays ?? 1} 天 · ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      case ReminderType.COUNTER_INTERVAL: {
        const unitText = rule.offsetUnit === CounterUnit.YEAR ? '年' : (rule.offsetUnit === CounterUnit.MONTH ? '个月' : '天');
        return `第 ${rule.offsetValue ?? 1}${unitText} · ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      }
      case ReminderType.COUNTER_DATE:
        return `${formatDayEventDate(rule.targetDate || Date.now())} · ${formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0)}`;
      default:
        return '未设置规则';
    }
  }

  private getPrimaryRuleText(): string {
    if (!this.event) {
      return '暂无规则';
    }
    if (this.event.reminderRules.length === 0) {
      return this.event.type === DayEventType.COUNTDOWN ? '倒计时仅按目标日期展示' : '当前没有可执行规则';
    }
    return this.getRuleText(this.event.reminderRules[0]);
  }

  private formatRelativeOccurrenceText(timestamp: number): string {
    const today = startOfDay(Date.now());
    const targetDay = startOfDay(timestamp);
    const dayDiff = Math.floor((targetDay - today) / 86400000);
    const date = new Date(timestamp);
    const minuteText = `${date.getMinutes()}`.padStart(2, '0');
    const timeText = `${date.getHours()}点${minuteText}分`;

    if (dayDiff <= 0) {
      return `今天${timeText}`;
    }
    if (dayDiff === 1) {
      return `明天${timeText}`;
    }
    if (dayDiff === 2) {
      return `后天${timeText}`;
    }
    return `${dayDiff}天后${timeText}`;
  }

  private getNextOccurrenceText(): string {
    if (!this.event) {
      return '暂无';
    }
    const nextOccurrence = getNextReminderOccurrenceTime(this.event, this.tasks, Date.now());
    if (nextOccurrence === undefined) {
      return '暂无下一次提醒';
    }
    return this.formatRelativeOccurrenceText(nextOccurrence);
  }

  private getCompletionText(): string {
    if (!this.event) {
      return '0 次';
    }
    return `${getReminderCompletionCount(this.tasks, this.event.id)} 次`;
  }

  private getCurrentPeriodText(): string {
    if (!this.event) {
      return '无';
    }
    const progress = getReminderPeriodProgress(this.event, this.tasks, Date.now());
    if (!progress) {
      return '无周期统计';
    }
    return `${progress.label} ${progress.completed}/${progress.target}`;
  }

  private hasCompletedToday(): boolean {
    if (!this.event) {
      return false;
    }
    const today = startOfDay(Date.now());
    return this.tasks.some((task: Task) => {
      return task.reminderId === this.event!.id &&
        task.status === TaskStatus.COMPLETED &&
        task.completedAt !== undefined &&
        startOfDay(task.completedAt) === today;
    });
  }

  private canCompleteNow(): boolean {
    if (!this.event) {
      return false;
    }
    return getReminderCompletionCandidate(this.event, this.tasks, Date.now()) !== null;
  }

  private getStatusText(): string {
    if (!this.event) {
      return '暂无状态';
    }
    if (!this.event.isEnabled) {
      return '当前已暂停';
    }
    if (this.event.skipOnceUntil !== undefined && this.event.skipOnceUntil >= Date.now()) {
      return '已跳过一次';
    }
    if (this.hasCompletedToday()) {
      return '今天已打卡';
    }
    if (this.canCompleteNow()) {
      return '现在可以打卡';
    }
    return '等待下一次提醒';
  }

  private getStatusTone(): 'primary' | 'success' | 'warning' | 'neutral' {
    if (!this.event) {
      return 'neutral';
    }
    if (!this.event.isEnabled || (this.event.skipOnceUntil !== undefined && this.event.skipOnceUntil >= Date.now())) {
      return 'warning';
    }
    if (this.hasCompletedToday()) {
      return 'success';
    }
    if (this.canCompleteNow()) {
      return 'primary';
    }
    return 'neutral';
  }

  private getPauseHintText(): string {
    if (!this.event) {
      return '';
    }
    if (!this.event.isEnabled) {
      return '恢复后会重新生成下一次打卡任务。';
    }
    if (this.event.skipOnceUntil !== undefined && this.event.skipOnceUntil >= Date.now()) {
      return `已跳过一次，直到 ${formatDayEventDate(this.event.skipOnceUntil)} ${formatDayEventTime(this.event.skipOnceUntil)}`;
    }
    return '可以跳过一次，也可以直接暂停整个提醒。';
  }

  private getCompactGoalTitle(): string {
    if (!this.event || !this.event.goalTitle || this.event.goalTitle.length === 0) {
      return '';
    }
    return this.event.goalTitle.length > 12 ? `${this.event.goalTitle.slice(0, 12)}...` : this.event.goalTitle;
  }

  private getRecentCompletedTasks(): Task[] {
    if (!this.event) {
      return [];
    }
    return this.tasks
      .filter((task: Task) => task.reminderId === this.event!.id && task.status === TaskStatus.COMPLETED)
      .sort((first: Task, second: Task) => (second.completedAt || 0) - (first.completedAt || 0))
      .slice(0, 6);
  }

  private getDetailFields(): DetailField[] {
    if (!this.event) {
      return [];
    }

    const fields: DetailField[] = [
      { label: '标题', value: this.event.title },
      { label: '类型', value: getEventTypeLabel(this.event.type) },
      { label: '关联目标', value: this.event.goalTitle || '未关联' },
      { label: '开始时间', value: formatDayEventDate(this.event.startDate) },
      { label: '结束时间', value: this.event.endDate ? formatDayEventDate(this.event.endDate) : '无结束时间' },
      { label: '目标时间', value: this.event.targetDate ? formatDayEventDate(this.event.targetDate) : '无' },
      { label: '纪念起点', value: this.event.counterStartDate ? formatDayEventDate(this.event.counterStartDate) : '无' },
      { label: '下一次提醒', value: this.getNextOccurrenceText() }
    ];

    if (this.event.reminderRules.length > 0) {
      this.event.reminderRules.forEach((rule: ReminderRule, index: number) => {
        fields.push({
          label: `提醒规则 ${index + 1}`,
          value: this.getRuleText(rule)
        });
      });
    } else {
      fields.push({
        label: '提醒规则',
        value: '无，倒计时仅展示目标时间'
      });
    }

    if (this.event.type === DayEventType.COUNTER &&
      this.event.reminderRules.length > 0 &&
      this.event.reminderRules[0].type === ReminderType.COUNTER_INTERVAL) {
      fields.push({
        label: '推算目标日',
        value: formatDayEventDate(getCounterTargetDate(this.event, this.event.reminderRules[0]))
      });
    }

    return fields;
  }

  private async markCurrentDone(): Promise<void> {
    if (!this.event) {
      return;
    }
    const success = await db.completeDayEventOccurrence(this.event.id, Date.now());
    this.showToast(success ? '已标记本次完成' : '当前没有可完成的提醒');
    this.refreshCurrentData();
  }

  private async pauseOnce(): Promise<void> {
    if (!this.event) {
      return;
    }
    const nextOccurrence = getNextReminderOccurrenceTime(this.event, this.tasks, Date.now());
    if (nextOccurrence === undefined) {
      this.showToast('当前没有可暂停的下一次提醒');
      return;
    }
    await db.pauseDayEventOnce(this.event.id, nextOccurrence);
    this.showToast('已跳过 1 次');
    this.refreshCurrentData();
  }

  private async pauseForever(): Promise<void> {
    if (!this.event) {
      return;
    }
    await db.pauseDayEventIndefinitely(this.event.id);
    this.showToast('已无限暂停');
    this.refreshCurrentData();
  }

  private async resumeReminder(): Promise<void> {
    if (!this.event) {
      return;
    }
    await db.resumeDayEvent(this.event.id);
    this.showToast('已恢复提醒');
    this.refreshCurrentData();
  }

  private openEditPage(): void {
    if (!this.event) {
      return;
    }
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/DayEventCreatePage',
      params: {
        eventId: this.event.id
      }
    });
  }

  private async deleteReminder(): Promise<void> {
    if (!this.event) {
      return;
    }
    await db.deleteDayEvent(this.event.id);
    this.showToast('已删除提醒');
    this.getUIContext().getRouter().back();
  }

  private openDeleteDialog(): void {
    if (!this.event) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '删除提醒',
      message: `删除“${this.event.title}”后，相关自动生成的待办也会一并清理。此操作不可恢复。`,
      buttons: [
        {
          value: '删除',
          action: () => { void this.deleteReminder(); }
        },
        {
          value: '取消',
          action: () => {}
        }
      ]
    });
  }

  private openPauseDialog(): void {
    if (!this.event) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '暂停提醒',
      message: `你想如何暂停“${this.event.title}”？`,
      buttons: [
        {
          value: '跳过一次',
          action: () => { void this.pauseOnce(); }
        },
        {
          value: '无限暂停',
          action: () => { void this.pauseForever(); }
        },
        {
          value: '取消',
          action: () => {}
        }
      ]
    });
  }

  @Builder
  private MetricCard(label: string, value: string, hint: string, tone: 'primary' | 'success' | 'warning') {
    AppCard({ variant: 'raised', spacing: SPACE_XS, paddingLevel: 'sm' }) {
      Text(label)
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Text(value)
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(
          tone === 'success'
            ? this.themeColors.success
            : tone === 'warning'
              ? this.themeColors.warning
              : this.themeColors.primary
        )
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (hint.length > 0) {
        Text(hint)
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textMuted)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
  }

  @Builder
  private DetailFieldRow(field: DetailField, isLast: boolean) {
    Row({ space: SPACE_SM }) {
      Text(field.label)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width(84)

      Text(field.value)
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.textPrimary)
        .layoutWeight(1)
        .lineHeight(18)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: isLast ? 0 : 1 }, color: this.themeColors.divider })
  }

  @Builder
  private ButtonCell(text: string, variant: 'primary' | 'secondary' | 'danger', disabled: boolean, iconName: string, onTap: () => void) {
    Column() {
      AppButton({
        text,
        variant,
        buttonSize: 'sm',
        fullWidth: true,
        disabled,
        iconName,
        tapAction: onTap
      })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private CompletedButtonCell(text: string) {
    Column() {
      Row() {
        Text(text)
          .fontSize(TYPE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.success)
      }
      .width('100%')
      .height(BUTTON_HEIGHT_SM)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .padding({ left: SPACE_MD, right: SPACE_MD })
      .backgroundColor(this.themeColors.successSubtle)
      .borderRadius(RADIUS_XL)
      .border({ width: 1, color: this.themeColors.success })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private HistoryRow(task: Task, isLast: boolean) {
    Row({ space: SPACE_SM }) {
      AppStatusBadge({ text: '已完成', tone: 'success', iconName: 'success' })

      Column({ space: 2 }) {
        Text(task.title)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(task.completedAt ? `${formatDayEventDate(task.completedAt)} ${formatDayEventTime(task.completedAt)}` : '已完成')
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: isLast ? 0 : 1 }, color: this.themeColors.divider })
  }

  build() {
    Column({ space: SPACE_SM }) {
      AppPageHeader({
        title: '提醒详情',
        subtitle: '在这里快速完成、跳过、暂停或恢复提醒',
        onBack: () => {
          this.getUIContext().getRouter().back();
        }
      })

      if (this.loading) {
        Column({ space: SPACE_SM }) {
          AppHeroPanel({
            eyebrow: '提醒详情',
            title: '正在读取提醒数据',
            description: '会同步读取规则、最近完成记录和下一次触发时间。',
            tone: 'info'
          }) {
          }
          AppLoadingState({ label: '正在加载提醒详情...' })
        }
        .width('100%')
        .padding({ left: SPACE_LG, right: SPACE_LG })
      } else if (!this.event) {
        Column() {
          AppEmptyState({
            iconName: 'warning',
            iconTone: 'warning',
            title: '提醒不存在',
            description: '当前提醒可能已被删除，或者参数未正确传入。',
            actionText: '返回',
            actionIconName: 'chevron-left',
            onAction: () => {
              this.getUIContext().getRouter().back();
            }
          })
        }
        .width('100%')
        .padding({ left: SPACE_LG, right: SPACE_LG, top: 40 })
      } else {
        Scroll() {
          Column({ space: SPACE_LG }) {
            AppHeroPanel({
              eyebrow: getEventTypeLabel(this.event.type),
              title: this.event.title,
              description: this.getPrimaryRuleText(),
              tone: 'info'
            }) {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                AppStatusBadge({
                  text: this.getStatusText(),
                  tone: this.getStatusTone(),
                  iconName: this.getStatusTone() === 'success' ? 'success' : (this.getStatusTone() === 'warning' ? 'warning' : 'info')
                })
                AppStatusBadge({ text: getEventTypeLabel(this.event.type), tone: 'neutral', iconName: getEventTypeIcon(this.event.type) })
                if (this.getCompactGoalTitle().length > 0) {
                  AppStatusBadge({ text: this.getCompactGoalTitle(), tone: 'info', iconName: 'goal' })
                }
              }
              .width('100%')

              Column({ space: SPACE_SM }) {
                Row({ space: SPACE_SM }) {
                  Column() {
                    this.MetricCard('累计完成', this.getCompletionText(), '总共完成的打卡次数', 'success')
                  }
                  .layoutWeight(1)

                  Column() {
                    this.MetricCard('当前周期', this.getCurrentPeriodText(), '观察本周期的完成进度', 'primary')
                  }
                  .layoutWeight(1)
                }
                .width('100%')

                this.MetricCard('下一次', this.getNextOccurrenceText(), '', 'warning')
              }
              .width('100%')
            }

            AppPanelSection({
              title: '快速操作',
              subtitle: this.getPauseHintText()
            }) {
              Column({ space: SPACE_MD }) {
                Row({ space: SPACE_SM }) {
                  if (this.hasCompletedToday()) {
                    this.CompletedButtonCell('今天已打卡')
                  } else {
                    this.ButtonCell(
                      '标记本次完成',
                      'primary',
                      !this.canCompleteNow(),
                      'success',
                      () => {
                        void this.markCurrentDone();
                      }
                    )
                  }

                  this.ButtonCell('跳过一次', 'secondary', false, 'warning', () => {
                    void this.pauseOnce();
                  })

                  this.ButtonCell(
                    this.event.isEnabled ? '暂停提醒' : '恢复提醒',
                    'secondary',
                    false,
                    this.event.isEnabled ? 'warning' : 'success',
                    () => {
                      if (!this.event) {
                        return;
                      }
                      if (this.event.isEnabled) {
                        this.openPauseDialog();
                        return;
                      }
                      void this.resumeReminder();
                    }
                  )
                }
                .width('100%')

              }
              .width('100%')
            }

            AppPanelSection({
              title: '全部信息',
              subtitle: '规则、时间和关联信息都在这里'
            }) {
              AppCard({ spacing: 0, paddingLevel: 'md' }) {
                Column() {
                  ForEach(this.getDetailFields(), (field: DetailField, index: number) => {
                    this.DetailFieldRow(field, index === this.getDetailFields().length - 1)
                  })
                }
                .width('100%')
              }
            }

            AppPanelSection({
              title: '最近完成记录',
              subtitle: '帮助你回看这条提醒最近的执行情况'
            }) {
              if (this.getRecentCompletedTasks().length === 0) {
                AppEmptyState({
                  iconName: 'success',
                  iconTone: 'success',
                  title: '暂无记录',
                  description: '你还没有完成过这条提醒，第一次打卡后会在这里留下记录。'
                })
              } else {
                AppCard({ spacing: 0, paddingLevel: 'md' }) {
                  Column() {
                    ForEach(this.getRecentCompletedTasks(), (task: Task, index: number) => {
                      this.HistoryRow(task, index === this.getRecentCompletedTasks().length - 1)
                    })
                  }
                  .width('100%')
                }
              }
            }

            AppPanelSection({
              title: '重要操作',
              subtitle: '低频操作，建议确认后再执行'
            }) {
              Row({ space: SPACE_SM }) {
                this.ButtonCell('编辑', 'secondary', false, 'note', () => {
                  this.openEditPage();
                })
                this.ButtonCell('删除', 'danger', false, 'warning', () => {
                  this.openDeleteDialog();
                })
              }
              .width('100%')
            }

            Blank().height(10)
          }
          .width('100%')
          .padding({ left: SPACE_LG, right: SPACE_LG, bottom: SPACE_LG })
        }
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
