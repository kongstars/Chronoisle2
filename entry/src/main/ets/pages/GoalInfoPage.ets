import { Goal, GoalCategory } from '../models/Goal';
import { Task } from '../models/Task';
import { db } from '../storage/Database';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { authService } from '../services/AuthService';
import { GOAL_TYPES, type GoalTypeInfo } from '../common/GoalTypeOptions';
import { type GoalBreakdownResult, type ReminderItem } from '../services/AgentService';
import { CounterUnit, DayEvent, DayEventData, DayEventType, getEventTypeIcon, getEventTypeLabel, ReminderRule, ReminderType } from '../models/DayEvent';
import { formatDayEventDate, formatDayEventTime } from '../common/DayEventUtils';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppFormCard } from '../ui/base/AppFormCard';
import { AppIcon } from '../ui/base/AppIcon';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { ICON_SIZE_XS } from '../foundation/tokens/IconTokens';
import { PAGE_PADDING, SECTION_GAP, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { COMFORTABLE_PAGE_PADDING, COMFORTABLE_SECTION_GAP } from '../foundation/tokens/PageTierTokens';
import { RADIUS_MD } from '../foundation/tokens/RadiusTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('GoalInfoPage');

const GOAL_INFO_REMINDER_DRAFT_KEY = 'goalInfoReminderDraft';

@Entry
@Component
struct GoalInfoPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State category: GoalCategory = GOAL_TYPES[0].category;
  @State goalTitle: string = '';
  @State goalDescription: string = '';
  @State isPriority: boolean = false;
  @State isCreating: boolean = false;
  @State newKeyResults: string[] = [];
  @State newKrInput: string = '';
  @State newTasks: string[] = [];
  @State newTaskInput: string = '';
  @State newReminders: DayEventData[] = [];

  private aiBreakdownData: GoalBreakdownResult | null = null;

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    if (params && params['category']) {
      const selectedType = GOAL_TYPES.find((type: GoalTypeInfo) => type.category === params['category'] as GoalCategory);
      if (selectedType) {
        this.category = selectedType.category;
      }
    }
  }

  onPageShow(): void {
    const breakdownResult = AppStorage.get<GoalBreakdownResult>('aiBreakdownResult');
    if (breakdownResult) {
      this.aiBreakdownData = breakdownResult;
      if (breakdownResult.objective) {
        this.goalTitle = breakdownResult.objective;
      }
      this.newKeyResults = [];
      this.newTasks = [];
      this.newReminders = [];
      breakdownResult.keyResults.forEach((kr) => {
        this.newKeyResults.push(`${kr.title} (目标:${kr.targetValue})`);
        kr.tasks.forEach((taskTitle: string) => {
          this.newTasks.push(`[${kr.title}] ${taskTitle}`);
        });
      });
      if (breakdownResult.reminders) {
        this.newReminders = breakdownResult.reminders.map((reminder: ReminderItem) => this.buildReminderDraftFromAgent(reminder));
      }
      AppStorage.delete('aiBreakdownResult');
      this.getUIContext().getPromptAction().showToast({ message: 'AI 拆解草案已成功应用' });
    }

    const reminderDraft = AppStorage.get<DayEventData>(GOAL_INFO_REMINDER_DRAFT_KEY);
    if (reminderDraft) {
      this.newReminders = [...this.newReminders, reminderDraft];
      AppStorage.delete(GOAL_INFO_REMINDER_DRAFT_KEY);
      this.getUIContext().getPromptAction().showToast({ message: '长期提醒已添加' });
    }
  }

  private getSelectedGoalType(): GoalTypeInfo {
    return GOAL_TYPES.find((type: GoalTypeInfo) => type.category === this.category) || GOAL_TYPES[0];
  }

  private isSelectedGoalType(type: GoalTypeInfo): boolean {
    return this.category === type.category;
  }

  private navigateBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (_) {
      this.getUIContext().getPromptAction().showToast({ message: '已返回首页' });
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/MainPage' });
    }
  }

  private canCreateGoal(): boolean {
    return this.goalTitle.trim().length > 0 && !this.isCreating;
  }

  private removeKeyResult(index: number): void {
    this.newKeyResults = this.newKeyResults.filter((_: string, itemIndex: number) => itemIndex !== index);
  }

  private removeTaskDraft(index: number): void {
    this.newTasks = this.newTasks.filter((_: string, itemIndex: number) => itemIndex !== index);
  }

  private removeReminderDraft(index: number): void {
    this.newReminders = this.newReminders.filter((_: DayEventData, itemIndex: number) => itemIndex !== index);
  }

  private getGoalFormHint(): string {
    const selectedType = this.getSelectedGoalType();
    return `${selectedType.title}类目标更适合先写清方向，再补一到三个衡量标准。`;
  }

  private addKeyResult(): void {
    const title = this.newKrInput.trim();
    if (!title) {
      return;
    }
    this.newKeyResults = [...this.newKeyResults, title];
    this.newKrInput = '';
    this.getUIContext().getPromptAction().showToast({ message: `已添加衡量标准：${title}` });
  }

  private addTaskDraft(): void {
    const title = this.newTaskInput.trim();
    if (!title) {
      return;
    }
    this.newTasks = [...this.newTasks, title];
    this.newTaskInput = '';
    this.getUIContext().getPromptAction().showToast({ message: `已添加起步行动：${title}` });
  }

  private getReminderDraftSummary(reminder: DayEventData): string {
    const event = DayEvent.fromJSON(reminder);
    const rule = event.reminderRules.length > 0 ? event.reminderRules[0] : undefined;
    if (!rule) {
      return event.targetDate ? `${getEventTypeLabel(event.type)} · 目标日 ${formatDayEventDate(event.targetDate)}` : `${getEventTypeLabel(event.type)} · 无额外提醒规则`;
    }
    return `${getEventTypeLabel(event.type)} · ${this.getReminderRuleText(event, rule)}`;
  }

  private getReminderRuleText(event: DayEvent, rule: ReminderRule): string {
    const timeText = formatDayEventTime(rule.hour ?? 9, rule.minute ?? 0);
    switch (rule.type) {
      case ReminderType.PERIODIC_WEEKLY:
        return `每周周${['日', '一', '二', '三', '四', '五', '六'][rule.weekday ?? 1]} ${timeText}`;
      case ReminderType.PERIODIC_MONTHLY:
        return `每月 ${rule.dayOfMonth || 1} 日 ${timeText}`;
      case ReminderType.PERIODIC_INTERVAL:
        return `每隔 ${rule.intervalDays || 1} 天 ${timeText}`;
      case ReminderType.HABIT_WEEKLY_TARGET:
        return `每周 ${rule.targetCount || rule.timesPerPeriod || 1} 次 · ${timeText}`;
      case ReminderType.HABIT_MONTHLY_TARGET:
        return `每月 ${rule.targetCount || rule.timesPerPeriod || 1} 次 · ${timeText}`;
      case ReminderType.MILESTONE_LEAD:
        return `提前 ${rule.leadDays || 0} 天 · ${timeText}`;
      case ReminderType.COUNTER_DATE:
        return `指定日期 ${formatDayEventDate(rule.targetDate || event.targetDate || Date.now())} · ${timeText}`;
      case ReminderType.COUNTER_INTERVAL:
        return `第 ${rule.offsetValue || 1}${this.getCounterUnitText(rule.offsetUnit)} · ${timeText}`;
      case ReminderType.HABIT_DAILY:
        return `每天 ${timeText}`;
      default:
        return `每天 ${timeText}`;
    }
  }

  private getCounterUnitText(unit?: CounterUnit): string {
    if (unit === CounterUnit.MONTH) {
      return '个月';
    }
    if (unit === CounterUnit.YEAR) {
      return '年';
    }
    return '天';
  }

  private buildReminderDraftFromAgent(reminder: ReminderItem): DayEventData {
    let dayEventType = DayEventType.PERIODIC;
    let ruleType = ReminderType.PERIODIC_DAILY;

    if (reminder.category === 'countdown') {
      dayEventType = DayEventType.COUNTDOWN;
      ruleType = ReminderType.COUNTER_DATE;
    } else if (reminder.category === 'habit') {
      dayEventType = DayEventType.HABIT;
      if (reminder.rule === 'weekly') {
        ruleType = ReminderType.HABIT_WEEKLY_TARGET;
      } else if (reminder.rule === 'monthly') {
        ruleType = ReminderType.HABIT_MONTHLY_TARGET;
      } else {
        ruleType = ReminderType.HABIT_DAILY;
      }
    } else {
      dayEventType = DayEventType.PERIODIC;
      if (reminder.rule === 'weekly') {
        ruleType = ReminderType.PERIODIC_WEEKLY;
      } else if (reminder.rule === 'monthly') {
        ruleType = ReminderType.PERIODIC_MONTHLY;
      } else {
        ruleType = ReminderType.PERIODIC_DAILY;
      }
    }

    const reminderTime = this.parseReminderTime(reminder.reminderTime || reminder.suggestedTime);
    const rule: ReminderRule = {
      type: ruleType,
      hour: reminderTime.hour,
      minute: reminderTime.minute
    };

    if (reminder.rule === 'weekly') {
      rule.weekday = reminder.timeParams && reminder.timeParams.length > 0 ? parseInt(`${reminder.timeParams[0]}`, 10) : 1;
      if (reminder.category === 'habit') {
        rule.targetCount = 1;
      }
    } else if (reminder.rule === 'monthly') {
      rule.dayOfMonth = reminder.timeParams && reminder.timeParams.length > 0 ? parseInt(`${reminder.timeParams[0]}`, 10) : 1;
      if (reminder.category === 'habit') {
        rule.targetCount = 1;
      }
    } else if (reminder.rule === 'target_date') {
      rule.targetDate = reminder.timeParams && reminder.timeParams.length > 0
        ? new Date(`${reminder.timeParams[0]}`.replace(/-/g, '/')).getTime()
        : Date.now() + 24 * 60 * 60 * 1000;
    }

    const startDate = this.resolveReminderDraftStartDate(reminder, rule, reminderTime.hour, reminderTime.minute);
    const event = new DayEvent(reminder.title, dayEventType, startDate);
    if (rule.targetDate) {
      event.targetDate = rule.targetDate;
      event.endDate = this.endOfDay(rule.targetDate);
    }
    event.addReminderRule(rule);
    const parsedEndDate = this.parseEndDate(reminder.endDate);
    if (parsedEndDate !== undefined) {
      event.endDate = event.endDate !== undefined ? Math.min(event.endDate, parsedEndDate) : parsedEndDate;
    }
    return event.toJSON();
  }

  private parseReminderTime(rawValue?: string): { hour: number; minute: number } {
    const safeValue = (rawValue || '').trim();
    const matched = safeValue.match(/^(\d{1,2}):(\d{1,2})$/);
    if (!matched) {
      return { hour: 9, minute: 0 };
    }

    const hour = parseInt(matched[1], 10);
    const minute = parseInt(matched[2], 10);
    if (isNaN(hour) || isNaN(minute) || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return { hour: 9, minute: 0 };
    }

    return { hour, minute };
  }

  private resolveReminderDraftStartDate(reminder: ReminderItem, rule: ReminderRule, hour: number, minute: number): number {
    if (reminder.rule === 'target_date' && rule.targetDate !== undefined) {
      return this.startOfDay(rule.targetDate);
    }

    if (reminder.rule === 'weekly') {
      const weekdays = (reminder.timeParams || [])
        .map((item: string | number) => parseInt(`${item}`, 10))
        .filter((item: number) => !isNaN(item) && item >= 0 && item <= 6);
      return this.startOfDay(this.getNextWeeklyOccurrence(weekdays.length > 0 ? weekdays : [1], hour, minute));
    }

    if (reminder.rule === 'monthly') {
      const rawDay = reminder.timeParams && reminder.timeParams.length > 0
        ? parseInt(`${reminder.timeParams[0]}`, 10)
        : 1;
      return this.startOfDay(this.getNextMonthlyOccurrence(rawDay, hour, minute));
    }

    return this.startOfDay(this.getNextDailyOccurrence(hour, minute));
  }

  private getNextDailyOccurrence(hour: number, minute: number, referenceTime: number = Date.now()): number {
    const today = this.startOfDay(referenceTime);
    const candidate = this.applyTime(today, hour, minute);
    if (candidate >= referenceTime) {
      return candidate;
    }
    return this.applyTime(today + 24 * 60 * 60 * 1000, hour, minute);
  }

  private getNextWeeklyOccurrence(weekdays: number[], hour: number, minute: number, referenceTime: number = Date.now()): number {
    let nextOccurrence: number | undefined = undefined;
    weekdays.forEach((weekday: number) => {
      const candidate = this.getNextWeeklyOccurrenceForDay(weekday, hour, minute, referenceTime);
      if (nextOccurrence === undefined || candidate < nextOccurrence) {
        nextOccurrence = candidate;
      }
    });
    return nextOccurrence !== undefined ? nextOccurrence : this.getNextDailyOccurrence(hour, minute, referenceTime);
  }

  private getNextWeeklyOccurrenceForDay(weekday: number, hour: number, minute: number, referenceTime: number): number {
    const today = this.startOfDay(referenceTime);
    const currentWeekday = new Date(today).getDay();
    const normalizedWeekday = weekday >= 0 && weekday <= 6 ? weekday : 1;
    let diff = (normalizedWeekday - currentWeekday + 7) % 7;
    let candidate = this.applyTime(today + diff * 24 * 60 * 60 * 1000, hour, minute);
    if (candidate < referenceTime) {
      diff = diff === 0 ? 7 : diff + 7;
      candidate = this.applyTime(today + diff * 24 * 60 * 60 * 1000, hour, minute);
    }
    return candidate;
  }

  private getNextMonthlyOccurrence(dayOfMonth: number, hour: number, minute: number, referenceTime: number = Date.now()): number {
    const normalizedDay = Math.max(1, Math.min(31, dayOfMonth));
    const referenceDate = new Date(referenceTime);
    for (let monthOffset = 0; monthOffset < 24; monthOffset++) {
      const rawMonth = referenceDate.getMonth() + monthOffset;
      const year = referenceDate.getFullYear() + Math.floor(rawMonth / 12);
      const month = rawMonth % 12;
      const daysInMonth = new Date(year, month + 1, 0).getDate();
      if (normalizedDay > daysInMonth) {
        continue;
      }
      const candidate = new Date(year, month, normalizedDay, hour, minute, 0, 0).getTime();
      if (candidate >= referenceTime) {
        return candidate;
      }
    }
    return this.getNextDailyOccurrence(hour, minute, referenceTime);
  }

  private parseEndDate(rawValue?: string): number | undefined {
    if (!rawValue) {
      return undefined;
    }
    const parsed = new Date(rawValue.replace(/-/g, '/')).getTime();
    if (isNaN(parsed)) {
      return undefined;
    }
    return this.endOfDay(parsed);
  }

  private startOfDay(timestamp: number): number {
    const date = new Date(timestamp);
    date.setHours(0, 0, 0, 0);
    return date.getTime();
  }

  private endOfDay(timestamp: number): number {
    const date = new Date(timestamp);
    date.setHours(23, 59, 59, 999);
    return date.getTime();
  }

  private applyTime(dayTimestamp: number, hour: number, minute: number): number {
    const date = new Date(this.startOfDay(dayTimestamp));
    date.setHours(hour, minute, 0, 0);
    return date.getTime();
  }

  private openReminderCreatePage(): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/DayEventCreatePage',
      params: {
        goalInfoReminderDraft: 'true',
        draftStorageKey: GOAL_INFO_REMINDER_DRAFT_KEY
      }
    });
  }

  private openAIBreakdown(): void {
    if (!this.goalTitle.trim()) {
      this.getUIContext().getPromptAction().showToast({ message: '请先至少输入目标名称' });
      return;
    }
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/GoalBreakdownPage',
      params: {
        intent: this.goalTitle.trim() + (this.goalDescription ? `\n${this.goalDescription}` : ''),
        fromGoalInfo: 'true'
      }
    });
  }

  private async createGoal(): Promise<void> {
    if (!this.goalTitle.trim()) {
      this.getUIContext().getPromptAction().showToast({ message: '请先输入目标名称' });
      return;
    }

    this.isCreating = true;
    try {
      const currentUser = await authService.getCurrentUser();
      const isPremium = authService.isPremiumUser(currentUser);

      if (!isPremium) {
        const activeGoalsCount = db.getActiveGoals().length;
        if (activeGoalsCount >= 5) {
          this.getUIContext().getPromptAction().showDialog({
            title: '会员升级提示',
            message: '基础会员最多允许创建 5 个进行中的目标。升级高级会员后可解锁无限目标。',
            buttons: [
              { text: '暂不升级', color: this.themeColors.textMuted },
              { text: '立即升级', color: this.themeColors.premium }
            ]
          }).then((data) => {
            if (data.index === 1) {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/MembershipPage' });
            }
          });
          this.isCreating = false;
          return;
        }
      }

      const goal = new Goal(this.goalTitle.trim(), this.category, this.goalDescription.trim(), this.isPriority);

      if (this.aiBreakdownData && this.aiBreakdownData.keyResults.length > 0) {
        const createdTasks: Task[] = [];
        this.aiBreakdownData.keyResults.forEach((krItem) => {
          const kr = goal.addKeyResult(krItem.title, krItem.targetValue);
          krItem.tasks.forEach((taskTitle: string) => {
            const newTask = new Task(taskTitle, goal.id, goal.title, goal.category);
            newTask.krId = kr.id;
            newTask.aiGenerated = true;
            createdTasks.push(newTask);
          });
        });

        await db.addGoal(goal);

        for (const task of createdTasks) {
          await db.addTask(task);
        }
      } else {
        this.newKeyResults.forEach((krTitle: string) => {
          goal.addKeyResult(krTitle);
        });

        await db.addGoal(goal);

        if (this.newTasks.length > 0) {
          for (const taskTitle of this.newTasks) {
            const newTask = new Task(taskTitle, goal.id, goal.title, goal.category);
            await db.addTask(newTask);
          }
        }
      }

      if (this.newReminders.length > 0) {
        for (const reminder of this.newReminders) {
          const dayEvent = DayEvent.fromJSON(reminder);
          dayEvent.goalId = goal.id;
          dayEvent.goalTitle = goal.title;
          dayEvent.updatedAt = Date.now();
          await db.addDayEvent(dayEvent);
        }
      }

      this.getUIContext().getRouter().replaceUrl({
        url: 'pages/GoalDetailPage',
        params: {
          goalId: goal.id,
          returnToMainOnBack: 'true'
        }
      });
    } catch (error) {
      logger.error('GoalInfoPage createGoal error', error as Object);
      this.getUIContext().getPromptAction().showToast({ message: '创建失败，请稍后重试' });
    } finally {
      this.isCreating = false;
    }
  }

  @Builder
  private GoalTypeCard(type: GoalTypeInfo) {
    Column({ space: SPACE_XS }) {
      AppIcon({ name: type.icon, iconSize: 30 })

      Text(type.title)
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.isSelectedGoalType(type) ? this.themeColors.primary : this.themeColors.textPrimary)
        .width('100%')
        .textAlign(TextAlign.Center)
        .maxLines(1)
    }
    .layoutWeight(1)
    .height(70)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 6, right: 6, top: 8, bottom: 8 })
    .backgroundColor(this.isSelectedGoalType(type) ? this.themeColors.primarySubtle : this.themeColors.surface)
    .borderRadius(RADIUS_MD)
    .border({
      width: this.isSelectedGoalType(type) ? 1.5 : 1,
      color: this.isSelectedGoalType(type) ? this.themeColors.primary : this.themeColors.borderColor
    })
    .shadow({
      radius: this.isSelectedGoalType(type) ? 7 : 4,
      color: this.themeColors.cardShadow,
      offsetX: 0,
      offsetY: this.isSelectedGoalType(type) ? 3 : 2
    })
    .onClick(() => {
      this.category = type.category;
    })
  }

  @Builder
  private SelectedGoalTypeDetail() {
    Column({ space: SPACE_SM }) {
      Row({ space: SPACE_XS }) {
        AppIcon({ name: this.getSelectedGoalType().icon, iconSize: 30 })

        Text(`已选择 ${this.getSelectedGoalType().title}`)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .layoutWeight(1)
      }
      .width('100%')

      Column({ space: SPACE_XS }) {
        Row({ space: SPACE_SM }) {
          Text('适合类型')
            .fontSize(TYPE_META)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.primary)
            .width(64)

          Text(this.getSelectedGoalType().subtitle)
            .fontSize(TYPE_BODY)
            .lineHeight(18)
            .fontColor(this.themeColors.textPrimary)
            .layoutWeight(1)
        }
        .width('100%')

        Row({ space: SPACE_SM }) {
          Text('提示语')
            .fontSize(TYPE_META)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.primary)
            .width(64)

          Text(this.getSelectedGoalType().description)
            .fontSize(TYPE_BODY)
            .lineHeight(18)
            .fontColor(this.themeColors.textSecondary)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.themeColors.primarySubtle)
    .borderRadius(RADIUS_MD)
    .border({ width: 1, color: this.themeColors.primaryLight })
  }

  @Builder
  private SectionHeading(title: string, subtitle: string = '') {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      if (subtitle.length > 0) {
        Text(subtitle)
          .fontSize(TYPE_META)
          .lineHeight(16)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private DraftItemRow(item: string, onRemove: () => void) {
    Row({ space: SPACE_SM }) {
      Row() {
        AppIcon({ name: 'success', iconSize: ICON_SIZE_XS, framed: false, color: this.themeColors.textOnPrimary })
      }
      .width(22)
      .height(22)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.themeColors.success)
      .borderRadius(11)

      Text(item)
        .layoutWeight(1)
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Medium)
        .lineHeight(18)
        .fontColor(this.themeColors.textPrimary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('删除')
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.danger)
        .onClick(() => {
          onRemove();
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.themeColors.successSubtle)
    .borderRadius(RADIUS_MD)
    .border({ width: 1, color: this.themeColors.borderColor })
  }

  @Builder
  private EmptyHint(text: string) {
    Text(text)
      .fontSize(TYPE_META)
      .lineHeight(16)
      .fontColor(this.themeColors.textMuted)
      .width('100%')
      .padding({ left: 2, right: 2, top: 2, bottom: 2 })
  }

  @Builder
  private HeroCard() {
    AppCard({ variant: 'soft', spacing: SPACE_SM }) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        AppStatusBadge({ text: '创建目标', tone: 'primary', iconName: 'goal' })
        AppStatusBadge({ text: this.getSelectedGoalType().title, tone: 'neutral', iconName: this.getSelectedGoalType().icon })
        if (this.aiBreakdownData) {
          AppStatusBadge({ text: '已应用 AI 草案', tone: 'info', iconName: 'ai' })
        }
      }
      .width('100%')

      Text('先把方向说清，再补第一步')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Text(this.getGoalFormHint())
        .fontSize(TYPE_BODY)
        .lineHeight(19)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  @Builder
  private KeyResultDraftList() {
    Column({ space: SPACE_SM }) {
      if (this.newKeyResults.length > 0) {
        Text(`当前已添加 ${this.newKeyResults.length} 个衡量标准`)
          .fontSize(TYPE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.success)
          .width('100%')

        Column({ space: SPACE_XS }) {
          ForEach(this.newKeyResults, (item: string, index: number) => {
            this.DraftItemRow(item, () => {
              this.removeKeyResult(index);
            })
          }, (item: string, index: number) => `key_result_draft_${index}_${item}`)
        }
        .width('100%')
      } else {
        this.EmptyHint('还没有衡量标准，可以先留空，之后再补。')
      }
    }
    .width('100%')
  }

  @Builder
  private TaskDraftList() {
    Column({ space: SPACE_SM }) {
      if (this.newTasks.length > 0) {
        Text(`当前已添加 ${this.newTasks.length} 个起步行动`)
          .fontSize(TYPE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.success)
          .width('100%')

        Column({ space: SPACE_XS }) {
          ForEach(this.newTasks, (item: string, index: number) => {
            this.DraftItemRow(item, () => {
              this.removeTaskDraft(index);
            })
          }, (item: string, index: number) => `task_draft_${index}_${item}`)
        }
        .width('100%')
      } else {
        this.EmptyHint('还没有起步行动，可以等目标创建后再慢慢补。')
      }
    }
    .width('100%')
  }

  @Builder
  private ReminderListCard() {
    Column({ space: SPACE_SM }) {
      Text('长期提醒（可选）')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      if (this.newReminders.length > 0) {
        Column({ space: SPACE_XS }) {
          ForEach(this.newReminders, (reminder: DayEventData, index: number) => {
            Row({ space: SPACE_SM }) {
              AppIcon({ name: getEventTypeIcon(reminder.type), iconSize: 26 })

              Column({ space: 2 }) {
                Text(reminder.title)
                  .fontSize(TYPE_BODY)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.themeColors.textPrimary)
                  .width('100%')

                Text(this.getReminderDraftSummary(reminder))
                  .fontSize(TYPE_META)
                  .fontColor(this.themeColors.textSecondary)
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Text('删除')
                .fontSize(TYPE_META)
                .fontColor(this.themeColors.danger)
                .onClick(() => {
                  this.removeReminderDraft(index);
                })
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
            .backgroundColor(this.themeColors.surfaceSoft)
            .borderRadius(RADIUS_MD)
            .border({ width: 1, color: this.themeColors.borderColor })
          }, (reminder: DayEventData, index: number) => `reminder_${reminder.id}_${index}`)
        }
        .width('100%')
      } else {
        this.EmptyHint('先放一个长期需要坚持的提醒，后续在目标推进时不会漏掉。')
      }

      AppButton({
        text: '添加长期提醒',
        variant: 'secondary',
        buttonSize: 'sm',
        iconName: 'reminder',
        tapAction: () => {
          this.openReminderCreatePage();
        }
      })
    }
    .width('100%')
  }

  @Builder
  private SaveBar() {
    Column({ space: SPACE_XS }) {
      AppButton({
        text: this.isCreating ? '创建中...' : '创建目标',
        variant: 'primary',
        buttonSize: 'lg',
        disabled: !this.canCreateGoal(),
        loading: this.isCreating,
        tapAction: () => {
          void this.createGoal();
        }
      })
        .width('100%')

      Text(this.goalTitle.trim().length > 0 ? '创建后会直接进入目标详情页。' : '先输入目标名称，再继续创建。')
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
    .width('100%')
    .padding({ left: COMFORTABLE_PAGE_PADDING, right: COMFORTABLE_PAGE_PADDING, top: 12, bottom: 24 })
    .backgroundColor(this.themeColors.navBackground)
    .border({ width: { top: 1 }, color: this.themeColors.borderColor })
  }

  build() {
    Column() {
      AppPageHeader({
        title: '创建目标',
        subtitle: '先确定方向，再补充关键结果、起步任务和长期提醒。',
        insetHorizontal: COMFORTABLE_PAGE_PADDING,
        onBack: () => {
          this.navigateBack();
        }
      })

      Scroll() {
        Column({ space: COMFORTABLE_SECTION_GAP }) {
          this.HeroCard()

          AppCard({ variant: 'base', spacing: SPACE_SM }) {
            this.SectionHeading('目标类型', '选择一个最接近当前阶段的方向，后续首页和目标详情会按这个维度展示。')

            Row({ space: SPACE_XS }) {
              this.GoalTypeCard(GOAL_TYPES[0])
              this.GoalTypeCard(GOAL_TYPES[1])
              this.GoalTypeCard(GOAL_TYPES[2])
              this.GoalTypeCard(GOAL_TYPES[3])
            }
            .width('100%')

            this.SelectedGoalTypeDetail()
          }

          AppFormCard({ variant: 'base', spacing: SPACE_MD }) {
            this.SectionHeading('目标信息', '先写清你想达到的状态，后续再决定要不要让 AI 帮你拆成路线。')

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              AppStatusBadge({ text: this.getSelectedGoalType().title, tone: 'primary', iconName: this.getSelectedGoalType().icon })
              if (this.aiBreakdownData) {
                AppStatusBadge({ text: '已应用 AI 草案', tone: 'info', iconName: 'ai' })
              }
            }
            .width('100%')

            Text('目标名称')
              .fontSize(TYPE_SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
              .width('100%')

            TextInput({ placeholder: '输入目标名称', text: this.goalTitle })
              .width('100%')
              .height(48)
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.themeColors.inputBackground)
              .borderRadius(RADIUS_MD)
              .fontColor(this.themeColors.textPrimary)
              .placeholderColor(this.themeColors.textMuted)
              .onChange((value: string) => {
                this.goalTitle = value;
              })

            Text('目标说明（可选）')
              .fontSize(TYPE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColors.textPrimary)
              .width('100%')

            TextArea({ placeholder: '补充这个目标的背景、意义或你想达到的状态', text: this.goalDescription })
              .width('100%')
              .height(104)
              .padding(16)
              .backgroundColor(this.themeColors.inputBackground)
              .borderRadius(RADIUS_MD)
              .fontColor(this.themeColors.textPrimary)
              .placeholderColor(this.themeColors.textMuted)
              .onChange((value: string) => {
                this.goalDescription = value;
              })

            AppButton({
              text: 'AI 拆解目标',
              variant: 'secondary',
              iconName: 'ai',
              tapAction: () => {
                const uiContext = this.getUIContext();
                void (async () => {
                  if (!(await authService.checkLoginWithPrompt(uiContext))) {
                    return;
                  }
                  this.openAIBreakdown();
                })();
              }
            })

            Text('先填标题即可手动创建；如果你已经想好了方向，可以直接交给 AI 生成衡量标准和起步行动。')
              .fontSize(TYPE_META)
              .lineHeight(16)
              .fontColor(this.themeColors.textSecondary)
              .width('100%')
          }

          AppFormCard({ variant: 'base', spacing: SPACE_MD }) {
            this.SectionHeading(
              '衡量标准（可选）',
              '写 1 到 3 个能判断进展的结果，比如次数、体重、存款或完成度。'
            )

            Row({ space: SPACE_SM }) {
              TextInput({ placeholder: '输入衡量标准名称', text: this.newKrInput })
                .layoutWeight(1)
                .height(46)
                .padding({ left: 14, right: 14 })
                .backgroundColor(this.themeColors.inputBackground)
                .borderRadius(RADIUS_MD)
                .fontColor(this.themeColors.textPrimary)
                .placeholderColor(this.themeColors.textMuted)
                .onChange((value: string) => {
                  this.newKrInput = value;
                })
                .onSubmit(() => {
                  this.addKeyResult();
                })

              AppButton({
                text: '添加',
                variant: 'secondary',
                buttonSize: 'sm',
                iconName: 'goal',
                tapAction: () => {
                  this.addKeyResult();
                }
              })
            }
            .width('100%')

            this.KeyResultDraftList()
          }

          AppFormCard({ variant: 'base', spacing: SPACE_MD }) {
            this.SectionHeading(
              '起步行动（可选）',
              '先放 1 到 3 个最容易启动的动作，创建后就能立刻开始做。'
            )

            Row({ space: SPACE_SM }) {
              TextInput({ placeholder: '输入起步任务名称', text: this.newTaskInput })
                .layoutWeight(1)
                .height(46)
                .padding({ left: 14, right: 14 })
                .backgroundColor(this.themeColors.inputBackground)
                .borderRadius(RADIUS_MD)
                .fontColor(this.themeColors.textPrimary)
                .placeholderColor(this.themeColors.textMuted)
                .onChange((value: string) => {
                  this.newTaskInput = value;
                })
                .onSubmit(() => {
                  this.addTaskDraft();
                })

              AppButton({
                text: '添加',
                variant: 'secondary',
                buttonSize: 'sm',
                iconName: 'task',
                tapAction: () => {
                  this.addTaskDraft();
                }
              })
            }
            .width('100%')

            this.TaskDraftList()
          }

          AppCard({ variant: 'base', spacing: SPACE_MD }) {
            this.ReminderListCard()
          }

          AppCard({ variant: 'soft', spacing: SPACE_SM }) {
            Row({ space: SPACE_SM }) {
              Column({ space: 4 }) {
                Text('设为优先目标')
                  .fontSize(TYPE_BODY)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.themeColors.textPrimary)
                  .width('100%')

                Text('优先目标会在首页更靠前展示，相关任务排序权重也会更高。')
                  .fontSize(TYPE_META)
                  .lineHeight(18)
                  .fontColor(this.themeColors.textSecondary)
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: this.isPriority })
                .selectedColor(this.themeColors.primary)
                .onChange((isOn: boolean) => {
                  this.isPriority = isOn;
                })
            }
            .width('100%')
          }

          Text('目标类型创建后不可修改，但标题、描述、衡量标准、行动和提醒都可以继续调整。')
            .fontSize(TYPE_META)
            .lineHeight(16)
            .fontColor(this.themeColors.textMuted)
            .width('100%')
        }
        .width('100%')
        .padding({ left: COMFORTABLE_PAGE_PADDING, right: COMFORTABLE_PAGE_PADDING, top: 8, bottom: COMFORTABLE_PAGE_PADDING + 12 })
      }
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .backgroundColor(this.themeColors.background)

      this.SaveBar()

      Column({ space: SPACE_XS }) {
        AppButton({
          text: '创建目标',
          variant: 'primary',
          iconName: 'goal',
          loading: this.isCreating,
          disabled: this.goalTitle.trim().length === 0,
          tapAction: () => {
            void this.createGoal();
          }
        })
        .width('100%')

        Text(this.goalTitle.trim().length > 0 ? '创建后会直接进入目标详情页。' : '先输入目标名称，再继续创建。')
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
      }
      .width('100%')
      .padding({ left: COMFORTABLE_PAGE_PADDING, right: COMFORTABLE_PAGE_PADDING, top: 12, bottom: 24 })
      .backgroundColor(this.themeColors.navBackground)
      .border({ width: { top: 1 }, color: this.themeColors.borderColor })
      .visibility(Visibility.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
