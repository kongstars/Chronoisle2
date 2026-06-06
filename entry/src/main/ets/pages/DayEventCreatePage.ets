import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { db } from '../storage/Database';
import { Goal } from '../models/Goal';
import { CounterUnit, DayEvent, DayEventData, DayEventType, getEventTypeIcon, ReminderRule, ReminderType } from '../models/DayEvent';
import { endOfDay, formatDayEventDate, formatDayEventTime, startOfDay } from '../common/DayEventUtils';
import { AIFillState } from '../services/AIFillState';
import { AppAIFillBanner } from '../ui/base/AppAIFillBanner';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppFormCard } from '../ui/base/AppFormCard';
import { AppIcon } from '../ui/base/AppIcon';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { COMFORTABLE_PAGE_PADDING, COMFORTABLE_SECTION_GAP } from '../foundation/tokens/PageTierTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_HERO_TITLE, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('DayEventCreatePage');

type PeriodicMode = 'daily' | 'weekly' | 'monthly' | 'interval';
type HabitMode = 'daily' | 'weekly' | 'monthly';
type CounterMode = 'interval' | 'date';
type DateFieldKey = 'periodicStart' | 'periodicEnd' | 'habitStart' | 'habitEnd' | 'milestoneTarget' | 'counterStart' | 'counterTarget' | 'countdownTarget' | '';

interface TypeCardItem {
  type: DayEventType;
  icon: string;
  title: string;
}

interface SuggestionItem {
  title: string;
  subtitle: string;
  enabled: boolean;
  onApply: () => void;
}

interface DayEventCreateRouteParams {
  title?: string;
  eventId?: string;
  goalId?: string;
  goalTitle?: string;
  goalInfoReminderDraft?: string;
  draftStorageKey?: string;
  voiceRawText?: string;
  voiceEventType?: string;
  voicePeriodicMode?: string;
  voiceHabitMode?: string;
  voiceCounterMode?: string;
  voiceStartDate?: string;
  voiceEndDate?: string;
  voiceHasEndDate?: string;
  voiceTargetDate?: string;
  voiceHour?: string;
  voiceMinute?: string;
  voiceWeekday?: string;
  voiceDayOfMonth?: string;
  voiceIntervalDays?: string;
  voiceTimesPerPeriod?: string;
  voiceLeadDays?: string;
  voiceOffsetValue?: string;
  voiceOffsetUnit?: string;
}

@Entry
@Component
struct DayEventCreatePage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State title: string = '';
  @State editingEventId: string = '';
  @State selectedType: DayEventType = DayEventType.PERIODIC;
  @State saving: boolean = false;
  @State goals: Goal[] = [];
  @State showGoalPicker: boolean = false;
  @State selectedGoalId: string = '';
  @State selectedGoalTitle: string = '';
  @State activeDateField: DateFieldKey = '';
  @State aiFill: AIFillState = new AIFillState();
  @State periodicMode: PeriodicMode = 'daily';
  @State habitMode: HabitMode = 'daily';
  @State counterMode: CounterMode = 'interval';
  @State periodicStartDate: Date = new Date();
  @State periodicEndDate: Date = new Date(Date.now() + 90 * 86400000);
  @State hasPeriodicEndDate: boolean = false;
  @State habitStartDate: Date = new Date();
  @State habitEndDate: Date = new Date(Date.now() + 90 * 86400000);
  @State hasHabitEndDate: boolean = false;
  @State milestoneTargetDate: Date = new Date(Date.now() + 7 * 86400000);
  @State counterStartDate: Date = new Date();
  @State counterTargetDate: Date = new Date(Date.now() + 100 * 86400000);
  @State countdownTargetDate: Date = new Date(Date.now() + 30 * 86400000);
  @State reminderHour: number = 9;
  @State reminderMinute: number = 0;
  @State periodicWeekday: number = 1;
  @State periodicDayOfMonth: number = new Date().getDate();
  @State periodicIntervalDays: number = 3;
  @State habitTimesPerPeriod: number = 3;
  @State milestoneLeadDays: number = 1;
  @State counterOffsetValue: number = 100;
  @State counterOffsetUnit: CounterUnit = CounterUnit.DAY;
  private goalInfoReminderDraft: boolean = false;
  private draftStorageKey: string = 'goalInfoReminderDraft';

  private readonly typeCards: TypeCardItem[] = [
    { type: DayEventType.PERIODIC, icon: 'calendar', title: '周期类' },
    { type: DayEventType.HABIT, icon: 'habit', title: '习惯养成' },
    { type: DayEventType.MILESTONE, icon: 'milestone', title: '重要日子' },
    { type: DayEventType.COUNTER, icon: 'counter', title: '纪念日' },
    { type: DayEventType.COUNTDOWN, icon: 'countdown', title: '倒计时' }
  ];

  async aboutToAppear(): Promise<void> {
    const params = this.getUIContext().getRouter().getParams() as DayEventCreateRouteParams;
    this.applyRouteParams(params);
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await db.initialize(context);
      this.goals = db.getActiveGoals();
      if (this.selectedGoalId && !this.selectedGoalTitle) {
        const matchedGoal = this.goals.find((goal: Goal) => goal.id === this.selectedGoalId);
        this.selectedGoalTitle = matchedGoal ? matchedGoal.title : '';
      }
      if (this.editingEventId) {
        const event = db.getDayEventById(this.editingEventId);
        if (event) {
          this.fillFormFromEvent(event);
        }
      }
    } catch (error) {
      logger.error('DayEventCreatePage initialize error', error as Object);
    }
  }

  private applyRouteParams(params: DayEventCreateRouteParams | undefined): void {
    if (!params) {
      return;
    }

    this.goalInfoReminderDraft = params.goalInfoReminderDraft === 'true';
    this.draftStorageKey = params.draftStorageKey || 'goalInfoReminderDraft';

    if (params.title) {
      this.title = params.title;
    } else if (params.voiceRawText) {
      this.title = params.voiceRawText;
    }

    if (params.eventId) {
      this.editingEventId = params.eventId;
    }

    if (params.goalId) {
      this.selectedGoalId = params.goalId;
    }
    if (params.goalTitle) {
      this.selectedGoalTitle = params.goalTitle;
    }

    if (!this.editingEventId) {
      this.applyVoicePrefill(params);
    }
  }

  private applyVoicePrefill(params: DayEventCreateRouteParams): void {
    if (!params.voiceEventType && !params.voiceRawText) {
      return;
    }

    this.selectedType = this.parseVoiceEventType(params.voiceEventType);

    if (params.voicePeriodicMode === 'daily' || params.voicePeriodicMode === 'weekly' ||
      params.voicePeriodicMode === 'monthly' || params.voicePeriodicMode === 'interval') {
      this.periodicMode = params.voicePeriodicMode;
    }
    if (params.voiceHabitMode === 'daily' || params.voiceHabitMode === 'weekly' || params.voiceHabitMode === 'monthly') {
      this.habitMode = params.voiceHabitMode;
    }
    if (params.voiceCounterMode === 'interval' || params.voiceCounterMode === 'date') {
      this.counterMode = params.voiceCounterMode;
    }

    const startDate = this.parseDateParam(params.voiceStartDate);
    const endDate = this.parseDateParam(params.voiceEndDate);
    const targetDate = this.parseDateParam(params.voiceTargetDate);
    const hasEndDate = this.parseBooleanParam(params.voiceHasEndDate);

    if (startDate) {
      this.periodicStartDate = startDate;
      this.habitStartDate = startDate;
      this.counterStartDate = startDate;
    }
    if (endDate) {
      this.periodicEndDate = endDate;
      this.habitEndDate = endDate;
    }
    if (hasEndDate !== undefined) {
      this.hasPeriodicEndDate = hasEndDate;
      this.hasHabitEndDate = hasEndDate;
    } else if (endDate) {
      this.hasPeriodicEndDate = true;
      this.hasHabitEndDate = true;
    }
    if (targetDate) {
      this.milestoneTargetDate = targetDate;
      this.counterTargetDate = targetDate;
      this.countdownTargetDate = targetDate;
    }

    const hour = this.parseNumberParam(params.voiceHour);
    const minute = this.parseNumberParam(params.voiceMinute);
    const weekday = this.parseNumberParam(params.voiceWeekday);
    const dayOfMonth = this.parseNumberParam(params.voiceDayOfMonth);
    const intervalDays = this.parseNumberParam(params.voiceIntervalDays);
    const timesPerPeriod = this.parseNumberParam(params.voiceTimesPerPeriod);
    const leadDays = this.parseNumberParam(params.voiceLeadDays);
    const offsetValue = this.parseNumberParam(params.voiceOffsetValue);

    if (hour !== undefined) {
      this.reminderHour = Math.max(0, Math.min(23, hour));
    }
    if (minute !== undefined) {
      this.reminderMinute = Math.max(0, Math.min(59, minute));
    }
    if (weekday !== undefined) {
      this.periodicWeekday = Math.max(0, Math.min(6, weekday));
    }
    if (dayOfMonth !== undefined) {
      this.periodicDayOfMonth = Math.max(1, Math.min(31, dayOfMonth));
    }
    if (intervalDays !== undefined && intervalDays > 0) {
      this.periodicIntervalDays = intervalDays;
    }
    if (timesPerPeriod !== undefined && timesPerPeriod > 0) {
      this.habitTimesPerPeriod = timesPerPeriod;
    }
    if (leadDays !== undefined && leadDays >= 0) {
      this.milestoneLeadDays = leadDays;
    }
    if (offsetValue !== undefined && offsetValue > 0) {
      this.counterOffsetValue = offsetValue;
    }

    const offsetUnit = this.parseCounterUnit(params.voiceOffsetUnit);
    if (offsetUnit) {
      this.counterOffsetUnit = offsetUnit;
    }

    // 标记所有被语音解析填入的字段
    const voiceFilledFields: string[] = ['title', 'eventType'];
    if (params.voicePeriodicMode || params.voiceHabitMode || params.voiceCounterMode) {
      voiceFilledFields.push('mode');
    }
    if (params.voiceStartDate) {
      voiceFilledFields.push('startDate');
    }
    if (params.voiceTargetDate) {
      voiceFilledFields.push('targetDate');
    }
    if (params.voiceHour || params.voiceMinute) {
      voiceFilledFields.push('reminderTime');
    }
    if (params.voiceWeekday) {
      voiceFilledFields.push('weekday');
    }
    if (params.voiceDayOfMonth) {
      voiceFilledFields.push('dayOfMonth');
    }
    if (params.voiceIntervalDays) {
      voiceFilledFields.push('intervalDays');
    }
    if (params.voiceTimesPerPeriod) {
      voiceFilledFields.push('timesPerPeriod');
    }
    this.aiFill.markFilled(voiceFilledFields);
  }

  private parseVoiceEventType(value?: string): DayEventType {
    switch (value) {
      case DayEventType.HABIT:
        return DayEventType.HABIT;
      case DayEventType.MILESTONE:
        return DayEventType.MILESTONE;
      case DayEventType.COUNTER:
        return DayEventType.COUNTER;
      case DayEventType.COUNTDOWN:
        return DayEventType.COUNTDOWN;
      default:
        return DayEventType.PERIODIC;
    }
  }

  private parseDateParam(value?: string): Date | undefined {
    if (!value) {
      return undefined;
    }
    const match = value.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
    if (!match) {
      return undefined;
    }

    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);
    if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day)) {
      return undefined;
    }
    return new Date(year, month - 1, day);
  }

  private parseBooleanParam(value?: string): boolean | undefined {
    if (value === 'true') {
      return true;
    }
    if (value === 'false') {
      return false;
    }
    return undefined;
  }

  private parseNumberParam(value?: string): number | undefined {
    if (!value) {
      return undefined;
    }
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }

  private parseCounterUnit(value?: string): CounterUnit | undefined {
    if (value === CounterUnit.DAY) {
      return CounterUnit.DAY;
    }
    if (value === CounterUnit.MONTH) {
      return CounterUnit.MONTH;
    }
    if (value === CounterUnit.YEAR) {
      return CounterUnit.YEAR;
    }
    return undefined;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch (_) {
    }
  }

  private getTypeTitle(type: DayEventType = this.selectedType): string {
    const item = this.typeCards.find((card: TypeCardItem) => card.type === type);
    return item ? item.title : '提醒';
  }

  private getTypeDescription(): string {
    switch (this.selectedType) {
      case DayEventType.HABIT:
        return '适合培养长期习惯，支持每天提醒、每周 X 次和每月 X 次，并统计本周期与累计完成次数。';
      case DayEventType.MILESTONE:
        return '适合某个重要日子前的提前提醒，比如除夕、生日、出发日。';
      case DayEventType.COUNTER:
        return '适合结婚纪念日、恋爱纪念日等日期型提醒，支持第 X 天或指定日期提醒。';
      case DayEventType.COUNTDOWN:
        return '倒计时只需要目标时间，会作为首页常驻倒计时卡片使用，不需要额外提醒规则。';
      default:
        return '适合固定频率重复发生的提醒，比如每月写月报、每周复盘或每隔几天检查一次。';
    }
  }

  private getSelectedGoalText(): string {
    return this.selectedGoalTitle || '目标（可选）';
  }

  private isEditMode(): boolean {
    return this.editingEventId.length > 0;
  }

  private isGoalDraftMode(): boolean {
    return this.goalInfoReminderDraft;
  }

  private getPageTitle(): string {
    if (this.isGoalDraftMode()) {
      return '添加长期提醒';
    }
    return this.isEditMode() ? '编辑提醒' : '新建提醒';
  }

  private getSaveButtonText(): string {
    if (this.saving) {
      if (this.isGoalDraftMode()) {
        return '添加中...';
      }
      return this.isEditMode() ? '更新中...' : '创建中...';
    }
    if (this.isGoalDraftMode()) {
      return '添加到目标草稿';
    }
    return this.isEditMode() ? '保存修改' : '创建提醒';
  }

  private fillFormFromEvent(event: DayEvent): void {
    this.title = event.title;
    this.selectedType = event.type;
    this.selectedGoalId = event.goalId || '';
    this.selectedGoalTitle = event.goalTitle || '';

    const firstRule = event.reminderRules[0];
    this.reminderHour = firstRule?.hour ?? 9;
    this.reminderMinute = firstRule?.minute ?? 0;

    if (event.type === DayEventType.PERIODIC) {
      this.periodicStartDate = new Date(event.startDate);
      this.hasPeriodicEndDate = event.endDate !== undefined;
      this.periodicEndDate = new Date(event.endDate || (Date.now() + 90 * 86400000));
      switch (firstRule?.type) {
        case ReminderType.PERIODIC_WEEKLY:
          this.periodicMode = 'weekly';
          this.periodicWeekday = firstRule.weekday ?? 1;
          break;
        case ReminderType.PERIODIC_MONTHLY:
          this.periodicMode = 'monthly';
          this.periodicDayOfMonth = firstRule.dayOfMonth ?? new Date().getDate();
          break;
        case ReminderType.PERIODIC_INTERVAL:
          this.periodicMode = 'interval';
          this.periodicIntervalDays = firstRule.intervalDays ?? 3;
          break;
        default:
          this.periodicMode = 'daily';
          break;
      }
    }

    if (event.type === DayEventType.HABIT) {
      this.habitStartDate = new Date(event.startDate);
      this.hasHabitEndDate = event.endDate !== undefined;
      this.habitEndDate = new Date(event.endDate || (Date.now() + 90 * 86400000));
      switch (firstRule?.type) {
        case ReminderType.HABIT_WEEKLY_TARGET:
          this.habitMode = 'weekly';
          this.habitTimesPerPeriod = firstRule.timesPerPeriod ?? 3;
          break;
        case ReminderType.HABIT_MONTHLY_TARGET:
          this.habitMode = 'monthly';
          this.habitTimesPerPeriod = firstRule.timesPerPeriod ?? 12;
          break;
        default:
          this.habitMode = 'daily';
          break;
      }
    }

    if (event.type === DayEventType.MILESTONE) {
      this.milestoneTargetDate = new Date(event.targetDate || Date.now() + 7 * 86400000);
      this.milestoneLeadDays = firstRule?.leadDays ?? 1;
    }

    if (event.type === DayEventType.COUNTER) {
      this.counterStartDate = new Date(event.counterStartDate || event.startDate);
      if (firstRule?.type === ReminderType.COUNTER_DATE) {
        this.counterMode = 'date';
        this.counterTargetDate = new Date(firstRule.targetDate || Date.now() + 30 * 86400000);
      } else {
        this.counterMode = 'interval';
        this.counterOffsetValue = firstRule?.offsetValue ?? 100;
        this.counterOffsetUnit = firstRule?.offsetUnit ?? CounterUnit.DAY;
      }
    }

    if (event.type === DayEventType.COUNTDOWN) {
      this.countdownTargetDate = new Date(event.targetDate || Date.now() + 30 * 86400000);
    }
  }

  private getDateForField(field: DateFieldKey): Date {
    switch (field) {
      case 'periodicStart':
        return this.periodicStartDate;
      case 'periodicEnd':
        return this.periodicEndDate;
      case 'habitStart':
        return this.habitStartDate;
      case 'habitEnd':
        return this.habitEndDate;
      case 'milestoneTarget':
        return this.milestoneTargetDate;
      case 'counterStart':
        return this.counterStartDate;
      case 'counterTarget':
        return this.counterTargetDate;
      case 'countdownTarget':
        return this.countdownTargetDate;
      default:
        return new Date();
    }
  }

  private setDateForField(field: DateFieldKey, date: Date): void {
    switch (field) {
      case 'periodicStart':
        this.periodicStartDate = date;
        break;
      case 'periodicEnd':
        this.hasPeriodicEndDate = true;
        this.periodicEndDate = date;
        break;
      case 'habitStart':
        this.habitStartDate = date;
        break;
      case 'habitEnd':
        this.hasHabitEndDate = true;
        this.habitEndDate = date;
        break;
      case 'milestoneTarget':
        this.milestoneTargetDate = date;
        break;
      case 'counterStart':
        this.counterStartDate = date;
        break;
      case 'counterTarget':
        this.counterTargetDate = date;
        break;
      case 'countdownTarget':
        this.countdownTargetDate = date;
        break;
      default:
        break;
    }
  }

  private getActiveDateValueText(field: DateFieldKey, placeholder: string): string {
    if ((field === 'periodicEnd' && !this.hasPeriodicEndDate) || (field === 'habitEnd' && !this.hasHabitEndDate)) {
      return placeholder;
    }
    return formatDayEventDate(this.getDateForField(field).getTime());
  }

  private formatReminderTime(): string {
    return formatDayEventTime(this.reminderHour, this.reminderMinute);
  }

  private getPeriodicRuleSummary(): string {
    switch (this.periodicMode) {
      case 'weekly': {
        const weekLabels: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
        return `每${weekLabels[this.periodicWeekday]} ${this.formatReminderTime()}`;
      }
      case 'monthly':
        return `每月 ${this.periodicDayOfMonth} 日 ${this.formatReminderTime()}`;
      case 'interval':
        return `每隔 ${this.periodicIntervalDays} 天 ${this.formatReminderTime()}`;
      default:
        return `每天 ${this.formatReminderTime()}`;
    }
  }

  private getHabitRuleSummary(): string {
    switch (this.habitMode) {
      case 'weekly':
        return `每周 ${this.habitTimesPerPeriod} 次 · ${this.formatReminderTime()}`;
      case 'monthly':
        return `每月 ${this.habitTimesPerPeriod} 次 · ${this.formatReminderTime()}`;
      default:
        return `每天 ${this.formatReminderTime()}`;
    }
  }

  private getMilestoneRuleSummary(): string {
    return `提前 ${this.milestoneLeadDays} 天 · ${this.formatReminderTime()}`;
  }

  private getCounterRuleSummary(): string {
    if (this.counterMode === 'date') {
      return `在 ${formatDayEventDate(this.counterTargetDate.getTime())} ${this.formatReminderTime()} 提醒`;
    }
    const unitText = this.counterOffsetUnit === CounterUnit.YEAR ? '年' : (this.counterOffsetUnit === CounterUnit.MONTH ? '个月' : '天');
    return `第 ${this.counterOffsetValue}${unitText} ${this.formatReminderTime()} 提醒`;
  }

  private getSuggestions(): SuggestionItem[] {
    switch (this.selectedType) {
      case DayEventType.HABIT:
        return [
          {
            title: '每天 07:00',
            subtitle: '每天固定提醒',
            enabled: this.habitMode === 'daily' && this.reminderHour === 7 && this.reminderMinute === 0,
            onApply: () => {
              this.habitMode = 'daily';
              this.reminderHour = 7;
              this.reminderMinute = 0;
            }
          },
          {
            title: '每周 3 次',
            subtitle: '适合锻炼/复盘',
            enabled: this.habitMode === 'weekly' && this.habitTimesPerPeriod === 3,
            onApply: () => {
              this.habitMode = 'weekly';
              this.habitTimesPerPeriod = 3;
              this.reminderHour = 20;
              this.reminderMinute = 0;
            }
          },
          {
            title: '每月 12 次',
            subtitle: '适合长周期习惯',
            enabled: this.habitMode === 'monthly' && this.habitTimesPerPeriod === 12,
            onApply: () => {
              this.habitMode = 'monthly';
              this.habitTimesPerPeriod = 12;
              this.reminderHour = 20;
              this.reminderMinute = 0;
            }
          }
        ];
      case DayEventType.MILESTONE:
        return [
          {
            title: '提前 1 天',
            subtitle: '临近提醒',
            enabled: this.milestoneLeadDays === 1,
            onApply: () => { this.milestoneLeadDays = 1; }
          },
          {
            title: '提前 3 天',
            subtitle: '预留准备时间',
            enabled: this.milestoneLeadDays === 3,
            onApply: () => { this.milestoneLeadDays = 3; }
          },
          {
            title: '提前 7 天',
            subtitle: '适合旅行/大事',
            enabled: this.milestoneLeadDays === 7,
            onApply: () => { this.milestoneLeadDays = 7; }
          }
        ];
      case DayEventType.COUNTER:
        return [
          {
            title: '第 30 天',
            subtitle: '短期纪念',
            enabled: this.counterMode === 'interval' && this.counterOffsetValue === 30 && this.counterOffsetUnit === CounterUnit.DAY,
            onApply: () => {
              this.counterMode = 'interval';
              this.counterOffsetValue = 30;
              this.counterOffsetUnit = CounterUnit.DAY;
            }
          },
          {
            title: '第 100 天',
            subtitle: '常用纪念节点',
            enabled: this.counterMode === 'interval' && this.counterOffsetValue === 100 && this.counterOffsetUnit === CounterUnit.DAY,
            onApply: () => {
              this.counterMode = 'interval';
              this.counterOffsetValue = 100;
              this.counterOffsetUnit = CounterUnit.DAY;
            }
          },
          {
            title: '指定日期',
            subtitle: '按具体日期提醒',
            enabled: this.counterMode === 'date',
            onApply: () => {
              this.counterMode = 'date';
            }
          }
        ];
      case DayEventType.COUNTDOWN:
        return [];
      default:
        return [
          {
            title: '每天 09:00',
            subtitle: '每天固定时间',
            enabled: this.periodicMode === 'daily' && this.reminderHour === 9 && this.reminderMinute === 0,
            onApply: () => {
              this.periodicMode = 'daily';
              this.reminderHour = 9;
              this.reminderMinute = 0;
            }
          },
          {
            title: '每周周日 09:00',
            subtitle: '每周固定星期',
            enabled: this.periodicMode === 'weekly' && this.periodicWeekday === 0,
            onApply: () => {
              this.periodicMode = 'weekly';
              this.periodicWeekday = 0;
              this.reminderHour = 9;
              this.reminderMinute = 0;
            }
          },
          {
            title: `每月 ${this.periodicDayOfMonth} 日 09:00`,
            subtitle: '每月固定日期',
            enabled: this.periodicMode === 'monthly',
            onApply: () => {
              this.periodicMode = 'monthly';
              this.reminderHour = 9;
              this.reminderMinute = 0;
            }
          },
          {
            title: '每隔 3 天 09:00',
            subtitle: '按固定间隔提醒',
            enabled: this.periodicMode === 'interval' && this.periodicIntervalDays === 3,
            onApply: () => {
              this.periodicMode = 'interval';
              this.periodicIntervalDays = 3;
              this.reminderHour = 9;
              this.reminderMinute = 0;
            }
          }
        ];
    }
  }

  private canSubmit(): boolean {
    if (!this.title.trim()) {
      return false;
    }
    if (this.selectedType === DayEventType.COUNTDOWN) {
      return this.countdownTargetDate.getTime() >= Date.now();
    }
    if (this.selectedType === DayEventType.COUNTER) {
      return this.counterMode === 'date' ? this.counterTargetDate.getTime() >= this.counterStartDate.getTime() : this.counterOffsetValue > 0;
    }
    return true;
  }

  private buildRule(): ReminderRule | null {
    switch (this.selectedType) {
      case DayEventType.HABIT:
        if (this.habitMode === 'weekly') {
          const weeklyRule: ReminderRule = {
            type: ReminderType.HABIT_WEEKLY_TARGET,
            timesPerPeriod: this.habitTimesPerPeriod,
            targetCount: this.habitTimesPerPeriod,
            hour: this.reminderHour,
            minute: this.reminderMinute
          };
          return weeklyRule;
        }
        if (this.habitMode === 'monthly') {
          const monthlyRule: ReminderRule = {
            type: ReminderType.HABIT_MONTHLY_TARGET,
            timesPerPeriod: this.habitTimesPerPeriod,
            targetCount: this.habitTimesPerPeriod,
            hour: this.reminderHour,
            minute: this.reminderMinute
          };
          return monthlyRule;
        }
        const habitRule: ReminderRule = {
          type: ReminderType.HABIT_DAILY,
          hour: this.reminderHour,
          minute: this.reminderMinute
        };
        return habitRule;
      case DayEventType.MILESTONE:
        const milestoneRule: ReminderRule = {
          type: ReminderType.MILESTONE_LEAD,
          leadDays: this.milestoneLeadDays,
          hour: this.reminderHour,
          minute: this.reminderMinute
        };
        return milestoneRule;
      case DayEventType.COUNTER:
        if (this.counterMode === 'date') {
          const counterDateRule: ReminderRule = {
            type: ReminderType.COUNTER_DATE,
            targetDate: startOfDay(this.counterTargetDate.getTime()),
            hour: this.reminderHour,
            minute: this.reminderMinute
          };
          return counterDateRule;
        }
        const counterIntervalRule: ReminderRule = {
          type: ReminderType.COUNTER_INTERVAL,
          offsetValue: this.counterOffsetValue,
          offsetUnit: this.counterOffsetUnit,
          hour: this.reminderHour,
          minute: this.reminderMinute
        };
        return counterIntervalRule;
      case DayEventType.COUNTDOWN:
        return null;
      default:
        if (this.periodicMode === 'weekly') {
          const periodicWeeklyRule: ReminderRule = {
            type: ReminderType.PERIODIC_WEEKLY,
            weekday: this.periodicWeekday,
            hour: this.reminderHour,
            minute: this.reminderMinute
          };
          return periodicWeeklyRule;
        }
        if (this.periodicMode === 'monthly') {
          const periodicMonthlyRule: ReminderRule = {
            type: ReminderType.PERIODIC_MONTHLY,
            dayOfMonth: this.periodicDayOfMonth,
            hour: this.reminderHour,
            minute: this.reminderMinute
          };
          return periodicMonthlyRule;
        }
        if (this.periodicMode === 'interval') {
          const periodicIntervalRule: ReminderRule = {
            type: ReminderType.PERIODIC_INTERVAL,
            intervalDays: this.periodicIntervalDays,
            hour: this.reminderHour,
            minute: this.reminderMinute
          };
          return periodicIntervalRule;
        }
        const periodicDailyRule: ReminderRule = {
          type: ReminderType.PERIODIC_DAILY,
          hour: this.reminderHour,
          minute: this.reminderMinute
        };
        return periodicDailyRule;
    }
  }

  private async saveEvent(): Promise<void> {
    if (this.saving || !this.canSubmit()) {
      return;
    }
    this.saving = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await db.initialize(context);
      const startTimestamp = this.selectedType === DayEventType.HABIT
        ? startOfDay(this.habitStartDate.getTime())
        : (this.selectedType === DayEventType.PERIODIC
          ? startOfDay(this.periodicStartDate.getTime())
          : (this.selectedType === DayEventType.COUNTER ? startOfDay(this.counterStartDate.getTime()) : startOfDay(Date.now())));
      const existingEvent = this.isEditMode() ? db.getDayEventById(this.editingEventId) : undefined;
      const event = existingEvent || new DayEvent(this.title.trim(), this.selectedType, startTimestamp);
      event.title = this.title.trim();
      event.type = this.selectedType;
      event.startDate = startTimestamp;
      event.goalId = this.selectedGoalId || undefined;
      event.goalTitle = this.selectedGoalTitle || undefined;
      event.targetDate = undefined;
      event.counterStartDate = undefined;
      event.endDate = undefined;
      event.reminderRules = [];

      if (this.selectedType === DayEventType.PERIODIC) {
        event.endDate = this.hasPeriodicEndDate ? endOfDay(this.periodicEndDate.getTime()) : undefined;
      }
      if (this.selectedType === DayEventType.HABIT) {
        event.endDate = this.hasHabitEndDate ? endOfDay(this.habitEndDate.getTime()) : undefined;
      }
      if (this.selectedType === DayEventType.MILESTONE) {
        event.targetDate = startOfDay(this.milestoneTargetDate.getTime());
      }
      if (this.selectedType === DayEventType.COUNTER) {
        event.counterStartDate = startOfDay(this.counterStartDate.getTime());
      }
      if (this.selectedType === DayEventType.COUNTDOWN) {
        event.targetDate = startOfDay(this.countdownTargetDate.getTime());
      }

      const rule = this.buildRule();
      if (rule) {
        event.addReminderRule(rule);
      }

      if (this.isGoalDraftMode()) {
        const draftData: DayEventData = event.toJSON();
        AppStorage.setOrCreate<DayEventData>(this.draftStorageKey, draftData);
        this.showToast('已添加到目标创建页');
        this.getUIContext().getRouter().back();
        return;
      }

      if (existingEvent) {
        await db.updateDayEvent(event);
      } else {
        await db.addDayEvent(event);
      }
      this.showToast(existingEvent ? '已更新提醒' : '已创建提醒');
      this.getUIContext().getRouter().back();
    } catch (error) {
      logger.error('DayEventCreatePage save error', error as Object);
      this.showToast('创建失败，请重试');
    } finally {
      this.saving = false;
    }
  }

  @Builder
  private TypeCard(item: TypeCardItem) {
    Column({ space: 6 }) {
      AppIcon({ name: item.icon, iconSize: 28, framed: true })
      Text(item.title)
        .fontSize(TYPE_BODY)
        .fontWeight(this.selectedType === item.type ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.selectedType === item.type ? this.themeColors.primary : this.themeColors.textSecondary)
    }
    .width('18.5%')
    .height(82)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.selectedType === item.type ? this.themeColors.primarySubtle : this.themeColors.cardBackground)
    .borderRadius(14)
    .border({
      width: this.selectedType === item.type ? 1.5 : 1,
      color: this.selectedType === item.type ? this.themeColors.primary : this.themeColors.borderColor
    })
    .onClick(() => {
      this.selectedType = item.type;
      this.activeDateField = '';
    })
  }

  @Builder
  private SectionCard(title: string, subtitle: string) {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')
        Text(subtitle)
          .fontSize(TYPE_CAPTION)
          .lineHeight(16)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.themeColors.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.themeColors.borderColor })
  }

  @Builder
  private LabeledInput(label: string, placeholder: string, value: string, onChange: (value: string) => void) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
      TextInput({ text: value, placeholder })
        .width('100%')
        .height(42)
        .fontSize(TYPE_BODY)
        .backgroundColor(this.themeColors.surfaceLight)
        .borderRadius(12)
        .padding({ left: 12, right: 12 })
        .onChange(onChange)
    }
    .width('100%')
  }

  @Builder
  private DateSelector(label: string, value: string, field: DateFieldKey, placeholder: string) {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
      Row() {
        Column({ space: 4 }) {
          Text(value)
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(value === placeholder ? this.themeColors.textSecondary : this.themeColors.primary)
            .width('100%')
          Text(`点击修改${label}`)
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textMuted)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        AppButton({
          text: '选择',
          buttonSize: 'sm',
          tapAction: () => {
            this.activeDateField = this.activeDateField === field ? '' : field;
          }
        })
      }
      .width('100%')
      .padding(14)
      .backgroundColor(this.themeColors.surfaceLight)
      .borderRadius(16)
      if (this.activeDateField === field) {
        DatePicker({
          start: new Date(2024, 0, 1),
          end: new Date(2035, 11, 31),
          selected: this.getDateForField(field)
        })
          .onDateChange((value: Date) => {
            this.setDateForField(field, value);
          })
          .height(150)
      }
    }
    .width('100%')
  }

  @Builder
  private TimeSelector() {
    Column({ space: 8 }) {
      Text('提醒时间')
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
      Row() {
        Text(this.formatReminderTime())
          .fontSize(TYPE_HERO_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.primary)
        Blank()
      }
      .width('100%')
      TimePicker({ selected: new Date(2026, 0, 1, this.reminderHour, this.reminderMinute) })
        .useMilitaryTime(true)
        .onChange((value: TimePickerResult) => {
          if (value.hour !== undefined && value.minute !== undefined) {
            this.reminderHour = value.hour;
            this.reminderMinute = value.minute;
          }
        })
        .height(120)
    }
    .width('100%')
  }

  @Builder
  private ModeChip(label: string, selected: boolean, onClick: () => void) {
    Text(label)
      .fontSize(TYPE_CAPTION)
      .fontWeight(selected ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(selected ? this.themeColors.textOnPrimary : this.themeColors.textSecondary)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .backgroundColor(selected ? this.themeColors.primary : this.themeColors.surfaceLight)
      .borderRadius(14)
      .onClick(onClick)
  }

  @Builder
  private SuggestionCard(item: SuggestionItem) {
    Row() {
      Column({ space: 4 }) {
        Text(item.title)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')
        Text(item.subtitle)
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textMuted)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      AppButton({
        text: item.enabled ? '已加入' : '加入',
        variant: item.enabled ? 'secondary' : 'primary',
        buttonSize: 'sm',
        disabled: item.enabled,
        tapAction: () => {
          item.onApply();
        }
      })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.themeColors.surfaceLight)
    .borderRadius(16)
  }

  @Builder
  private OverviewCard() {
    AppCard({ variant: 'accent', spacing: SPACE_SM }) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        AppStatusBadge({
          text: this.isGoalDraftMode() ? '目标草稿' : (this.isEditMode() ? '编辑模式' : '新提醒'),
          tone: 'info',
          iconName: this.isGoalDraftMode() ? 'goal' : (this.isEditMode() ? 'note' : 'reminder')
        })
        AppStatusBadge({ text: this.getTypeTitle(), tone: 'primary', iconName: getEventTypeIcon(this.selectedType) })
        if (this.selectedGoalTitle) {
          AppStatusBadge({ text: '已关联目标', tone: 'success', iconName: 'goal' })
        }
      }
      .width('100%')

      Text(this.isGoalDraftMode() ? '配置后回到目标创建页' : (this.isEditMode() ? '调整提醒规则和关联信息' : '先确定类型，再补全规则'))
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Text(this.getTypeDescription())
        .fontSize(TYPE_BODY)
        .lineHeight(20)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  @Builder
  private SaveBar() {
    Column({ space: SPACE_XS }) {
      AppButton({
        text: this.getSaveButtonText(),
        buttonSize: 'lg',
        fullWidth: true,
        loading: this.saving,
        disabled: !this.canSubmit(),
        tapAction: () => {
          this.saveEvent();
        }
      })
      if (!this.title.trim()) {
        Text('先输入提醒标题后再创建')
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textMuted)
          .width('100%')
      }
    }
    .width('100%')
    .padding({ left: COMFORTABLE_PAGE_PADDING, right: COMFORTABLE_PAGE_PADDING, top: 8, bottom: 16 })
    .backgroundColor(this.themeColors.navBackground)
    .border({ width: { top: 1 }, color: this.themeColors.borderColor })
  }

  @Builder
  private GoalPickerDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeColors.surfaceOverlay)
        .onClick(() => {
          this.showGoalPicker = false;
        })

      Column({ space: 16 }) {
        Text('关联目标')
          .fontSize(TYPE_HERO_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')
        Scroll() {
          Column({ space: 10 }) {
            AppButton({
              text: '暂不关联目标',
              variant: this.selectedGoalId ? 'secondary' : 'primary',
              buttonSize: 'md',
              tapAction: () => {
                this.selectedGoalId = '';
                this.selectedGoalTitle = '';
                this.showGoalPicker = false;
              }
            })
              .width('100%')
            ForEach(this.goals, (goal: Goal) => {
              AppButton({
                text: goal.title,
                variant: this.selectedGoalId === goal.id ? 'primary' : 'secondary',
                buttonSize: 'md',
                tapAction: () => {
                  this.selectedGoalId = goal.id;
                  this.selectedGoalTitle = goal.title;
                  this.showGoalPicker = false;
                }
              })
                .width('100%')
            }, (goal: Goal) => goal.id)
          }
          .width('100%')
        }
        .align(Alignment.Top)
        .width('100%')
        .constraintSize({ maxHeight: 320 })
      }
      .width('88%')
      .padding(16)
      .backgroundColor(this.themeColors.surface)
      .borderRadius(20)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Center)
  }

  @Builder
  private TypeSection() {
    Column({ space: 8 }) {
      Text('先选一个类型')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
      Text('类型决定后面的提醒建议和配置方式。')
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
      Row({ space: 8 }) {
        ForEach(this.typeCards, (item: TypeCardItem) => {
          this.TypeCard(item)
        }, (item: TypeCardItem) => item.type)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.themeColors.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.themeColors.borderColor })
  }

  @Builder
  private GoalSection() {
    Column({ space: 8 }) {
      Text('关联目标')
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
      Row() {
        Column({ space: 4 }) {
          Text(this.getSelectedGoalText())
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.selectedGoalTitle ? this.themeColors.textPrimary : this.themeColors.textSecondary)
            .width('100%')
          Text('目标（可选）')
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textMuted)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        AppButton({
          text: '选择',
          buttonSize: 'sm',
          tapAction: () => {
            this.showGoalPicker = true;
          }
        })
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.themeColors.surfaceLight)
      .borderRadius(14)
    }
    .width('100%')
  }

  @Builder
  private PeriodicSection() {
    Column({ space: 14 }) {
      this.DateSelector('开始时间', this.getActiveDateValueText('periodicStart', ''), 'periodicStart', '')
      this.DateSelector('结束时间', this.getActiveDateValueText('periodicEnd', '无结束时间'), 'periodicEnd', '无结束时间')
      Row() {
        Text('启用结束时间')
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textSecondary)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.hasPeriodicEndDate })
          .onChange((isOn: boolean) => {
            this.hasPeriodicEndDate = isOn;
            if (!isOn && this.activeDateField === 'periodicEnd') {
              this.activeDateField = '';
            }
          })
      }
      .width('100%')
      this.TimeSelector()
      Row({ space: 8 }) {
        this.ModeChip('每天', this.periodicMode === 'daily', () => { this.periodicMode = 'daily'; })
        this.ModeChip('每周', this.periodicMode === 'weekly', () => { this.periodicMode = 'weekly'; })
        this.ModeChip('每月', this.periodicMode === 'monthly', () => { this.periodicMode = 'monthly'; })
        this.ModeChip('间隔', this.periodicMode === 'interval', () => { this.periodicMode = 'interval'; })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      if (this.periodicMode === 'weekly') {
        Row({ space: 8 }) {
          ForEach(['日', '一', '二', '三', '四', '五', '六'], (day: string, index: number) => {
            this.ModeChip(`周${day}`, this.periodicWeekday === index, () => { this.periodicWeekday = index; })
          }, (day: string) => day)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      if (this.periodicMode === 'monthly') {
        Column({ space: 8 }) {
          Text('每月日期')
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')
          TextInput({ text: `${this.periodicDayOfMonth}`, placeholder: '1-31' })
            .width('100%')
            .height(46)
            .backgroundColor(this.themeColors.surfaceLight)
            .borderRadius(14)
            .padding({ left: 14, right: 14 })
            .type(InputType.Number)
            .onChange((value: string) => {
              const nextValue = parseInt(value, 10);
              if (!isNaN(nextValue)) {
                this.periodicDayOfMonth = Math.max(1, Math.min(31, nextValue));
              }
            })
        }
      }
      if (this.periodicMode === 'interval') {
        Column({ space: 8 }) {
          Text('每隔天数')
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')
          TextInput({ text: `${this.periodicIntervalDays}`, placeholder: '请输入间隔天数' })
            .width('100%')
            .height(46)
            .backgroundColor(this.themeColors.surfaceLight)
            .borderRadius(14)
            .padding({ left: 14, right: 14 })
            .type(InputType.Number)
            .onChange((value: string) => {
              const nextValue = parseInt(value, 10);
              if (!isNaN(nextValue)) {
                this.periodicIntervalDays = Math.max(1, nextValue);
              }
            })
        }
      }
      Text(`当前规则：${this.getPeriodicRuleSummary()}`)
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  private HabitSection() {
    Column({ space: 14 }) {
      this.DateSelector('开始时间', this.getActiveDateValueText('habitStart', ''), 'habitStart', '')
      this.DateSelector('结束时间', this.getActiveDateValueText('habitEnd', '无结束时间'), 'habitEnd', '无结束时间')
      Row() {
        Text('启用结束时间')
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textSecondary)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.hasHabitEndDate })
          .onChange((isOn: boolean) => {
            this.hasHabitEndDate = isOn;
            if (!isOn && this.activeDateField === 'habitEnd') {
              this.activeDateField = '';
            }
          })
      }
      .width('100%')
      this.TimeSelector()
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        this.ModeChip('每天提醒', this.habitMode === 'daily', () => { this.habitMode = 'daily'; })
        this.ModeChip('每周 X 次', this.habitMode === 'weekly', () => { this.habitMode = 'weekly'; })
        this.ModeChip('每月 X 次', this.habitMode === 'monthly', () => { this.habitMode = 'monthly'; })
      }
      .width('100%')
      if (this.habitMode !== 'daily') {
        Column({ space: 8 }) {
          Text(this.habitMode === 'weekly' ? '每周目标次数' : '每月目标次数')
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')
          TextInput({ text: `${this.habitTimesPerPeriod}`, placeholder: '请输入次数' })
            .width('100%')
            .height(46)
            .backgroundColor(this.themeColors.surfaceLight)
            .borderRadius(14)
            .padding({ left: 14, right: 14 })
            .type(InputType.Number)
            .onChange((value: string) => {
              const nextValue = parseInt(value, 10);
              if (!isNaN(nextValue)) {
                this.habitTimesPerPeriod = Math.max(1, nextValue);
              }
            })
        }
      }
      Text(`当前规则：${this.getHabitRuleSummary()}`)
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  private MilestoneSection() {
    Column({ space: 14 }) {
      this.DateSelector('目标日期', this.getActiveDateValueText('milestoneTarget', ''), 'milestoneTarget', '')
      this.TimeSelector()
      Row({ space: 10 }) {
        this.ModeChip('提前 1 天', this.milestoneLeadDays === 1, () => { this.milestoneLeadDays = 1; })
        this.ModeChip('提前 3 天', this.milestoneLeadDays === 3, () => { this.milestoneLeadDays = 3; })
        this.ModeChip('提前 7 天', this.milestoneLeadDays === 7, () => { this.milestoneLeadDays = 7; })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      Text(`当前规则：${this.getMilestoneRuleSummary()}`)
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  private CounterSection() {
    Column({ space: 14 }) {
      this.DateSelector('纪念起点', this.getActiveDateValueText('counterStart', ''), 'counterStart', '')
      this.TimeSelector()
      Row({ space: 8 }) {
        this.ModeChip('第 X 天提醒', this.counterMode === 'interval', () => { this.counterMode = 'interval'; })
        this.ModeChip('具体日期提醒', this.counterMode === 'date', () => { this.counterMode = 'date'; })
      }
      .width('100%')
      if (this.counterMode === 'interval') {
        Column({ space: 8 }) {
          Text('第几天提醒')
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')
          TextInput({ text: `${this.counterOffsetValue}`, placeholder: '请输入数值' })
            .width('100%')
            .height(46)
            .backgroundColor(this.themeColors.surfaceLight)
            .borderRadius(14)
            .padding({ left: 14, right: 14 })
            .type(InputType.Number)
            .onChange((value: string) => {
              const nextValue = parseInt(value, 10);
              if (!isNaN(nextValue)) {
                this.counterOffsetValue = Math.max(1, nextValue);
              }
            })
          Row({ space: 8 }) {
            this.ModeChip('天', this.counterOffsetUnit === CounterUnit.DAY, () => { this.counterOffsetUnit = CounterUnit.DAY; })
            this.ModeChip('月', this.counterOffsetUnit === CounterUnit.MONTH, () => { this.counterOffsetUnit = CounterUnit.MONTH; })
            this.ModeChip('年', this.counterOffsetUnit === CounterUnit.YEAR, () => { this.counterOffsetUnit = CounterUnit.YEAR; })
          }
          .width('100%')
        }
      } else {
        this.DateSelector('提醒日期', this.getActiveDateValueText('counterTarget', ''), 'counterTarget', '')
      }
      Text(`当前规则：${this.getCounterRuleSummary()}`)
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  private CountdownSection() {
    Column({ space: 12 }) {
      this.DateSelector('目标时间', this.getActiveDateValueText('countdownTarget', ''), 'countdownTarget', '')
      Text('倒计时只记录目标时间，不额外创建提醒时间，首页会直接展示剩余天数。')
        .fontSize(TYPE_CAPTION)
        .lineHeight(18)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
        .padding(14)
        .backgroundColor(this.themeColors.surfaceLight)
        .borderRadius(14)
    }
    .width('100%')
  }

  @Builder
  private SuggestionSection() {
    if (this.getSuggestions().length > 0) {
      Column({ space: 10 }) {
        Text('自动提醒建议')
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')
        Text('系统已按当前类型生成建议，你也可以继续自定义。')
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
        ForEach(this.getSuggestions(), (item: SuggestionItem) => {
          this.SuggestionCard(item)
        }, (item: SuggestionItem) => item.title)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.themeColors.surface)
      .borderRadius(20)
      .border({ width: 1, color: this.themeColors.borderColor })
    }
  }

  build() {
    Stack() {
      Column() {
        AppPageHeader({
          title: this.getPageTitle(),
          subtitle: this.isGoalDraftMode() ? '配置类型、时间和提醒规则，保存后回到目标创建页。' : '配置类型、时间、目标和提醒规则，让提醒真正可执行。',
          insetHorizontal: COMFORTABLE_PAGE_PADDING,
          onBack: () => {
            this.getUIContext().getRouter().back();
          }
        })

        Scroll() {
          Column({ space: COMFORTABLE_SECTION_GAP }) {
            this.OverviewCard()

            if (this.aiFill.shouldShowBanner()) {
              AppAIFillBanner({
                status: this.aiFill.getBannerComponentStatus(),
                title: this.aiFill.getBannerTitle(),
                actionText: '隐藏提示',
                action: () => { this.aiFill.dismiss(); }
              })
            }

            this.TypeSection()

            AppFormCard() {
              Column({ space: SPACE_MD }) {
                this.LabeledInput('标题', '例如：' + this.getTypeTitle() + '提醒', this.title, (value: string) => {
                  this.title = value;
                  this.aiFill.markUserEdited('title');
                })
                if (!this.isGoalDraftMode()) {
                  this.GoalSection()
                }
              }
              .width('100%')
            }

            if (this.selectedType === DayEventType.PERIODIC) {
              AppFormCard() {
                Column({ space: SPACE_MD }) {
                  Text('时间规则')
                    .fontSize(TYPE_SECTION_TITLE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.themeColors.textPrimary)
                  Text('适合固定频率的重复提醒，例如每周复盘、每月结算或隔几天执行一次。')
                    .fontSize(TYPE_META)
                    .lineHeight(20)
                    .fontColor(this.themeColors.textSecondary)
                  this.PeriodicSection()
                }
                .width('100%')
              }
            }

            if (this.selectedType === DayEventType.HABIT) {
              AppFormCard() {
                Column({ space: SPACE_MD }) {
                  Text('习惯规则')
                    .fontSize(TYPE_SECTION_TITLE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.themeColors.textPrimary)
                  Text('适合长期习惯打卡，可按每日、每周次数或每月次数来管理。')
                    .fontSize(TYPE_META)
                    .lineHeight(20)
                    .fontColor(this.themeColors.textSecondary)
                  this.HabitSection()
                }
                .width('100%')
              }
            }

            if (this.selectedType === DayEventType.MILESTONE) {
              AppFormCard() {
                Column({ space: SPACE_MD }) {
                  Text('重要日期')
                    .fontSize(TYPE_SECTION_TITLE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.themeColors.textPrimary)
                  Text('适合生日、出发日、截止日等重要节点，支持提前若干天提醒。')
                    .fontSize(TYPE_META)
                    .lineHeight(20)
                    .fontColor(this.themeColors.textSecondary)
                  this.MilestoneSection()
                }
                .width('100%')
              }
            }

            if (this.selectedType === DayEventType.COUNTER) {
              AppFormCard() {
                Column({ space: SPACE_MD }) {
                  Text('纪念日规则')
                    .fontSize(TYPE_SECTION_TITLE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.themeColors.textPrimary)
                  Text('适合恋爱纪念日、结婚纪念日等，可按第 X 天或具体日期提醒。')
                    .fontSize(TYPE_META)
                    .lineHeight(20)
                    .fontColor(this.themeColors.textSecondary)
                  this.CounterSection()
                }
                .width('100%')
              }
            }

            if (this.selectedType === DayEventType.COUNTDOWN) {
              AppFormCard() {
                Column({ space: SPACE_MD }) {
                  Text('倒计时设置')
                    .fontSize(TYPE_SECTION_TITLE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.themeColors.textPrimary)
                  Text('只记录目标时间，用于首页倒计时卡片展示，不额外生成提醒规则。')
                    .fontSize(TYPE_META)
                    .lineHeight(20)
                    .fontColor(this.themeColors.textSecondary)
                  this.CountdownSection()
                }
                .width('100%')
              }
            }

            this.SuggestionSection()

            Blank().height(64)
          }
          .width('100%')
          .padding({ left: COMFORTABLE_PAGE_PADDING, right: COMFORTABLE_PAGE_PADDING, top: 4, bottom: COMFORTABLE_PAGE_PADDING + 68 })
        }
        .align(Alignment.Top)
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        this.SaveBar()
      }
      .width('100%')
      .height('100%')

      if (this.showGoalPicker) {
        this.GoalPickerDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
