import { Goal } from '../models/Goal';
import { Task } from '../models/Task';
import { DayEvent } from '../models/DayEvent';
import { db } from '../storage/Database';
import { authService, UserAccount } from '../services/AuthService';
import type { SavedTodayPlan } from '../models/TodayPlan';
import { TodayTab } from '../components/TodayTab';
import { TaskListTab } from '../components/TaskListTab';
import { CalendarTab } from '../components/CalendarTab';
import { MeTab } from '../components/MeTab';
import { VoiceCreateOverlay, VoiceCreateOutput } from '../components/VoiceCreateOverlay';
import { VoiceCreateParsed } from '../services/VoiceCreateService';
import { TodayPlanService } from '../services/TodayPlanService';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppIcon } from '../ui/base/AppIcon';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { BORDER_DEFAULT } from '../foundation/tokens/BorderTokens';
import { BOTTOM_BAR_HEIGHT, FAB_SIZE, NAV_ICON_SIZE } from '../foundation/tokens/PageDensityTokens';
import { RADIUS_LG } from '../foundation/tokens/RadiusTokens';
import { CONTENT_GAP, PANEL_GAP, SPACE_2XS, SPACE_CARD, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { ICON_SIZE_XL } from '../foundation/tokens/IconTokens';
import { TYPE_CAPTION } from '../foundation/tokens/TypographyTokens';
import { TOUCH_TARGET_LG } from '../foundation/tokens/VisualTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('MainPage');
interface GoalInfoRouteParams {
  category: string;
}

interface ReminderVoiceRouteParams {
  title: string;
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

@Component
struct MainFabButton {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop label: string = '+';

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(FAB_SIZE)
        .height(FAB_SIZE)
        .backgroundColor(this.themeColors.primary)
        .borderRadius(FAB_SIZE / 2)
        .shadow({ radius: 16, color: this.themeColors.cardShadow, offsetX: 0, offsetY: 8 })
      Text(this.label)
        .fontSize(ICON_SIZE_XL)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textOnPrimary)
    }
  }
}

@Entry
@Component
struct MainPage {
  @State currentTabIndex: number = 0;
  @State showAddSheet: boolean = false;
  @State voiceCloseBlocked: boolean = false;
  @State goals: Goal[] = [];
  @State tasks: Task[] = [];
  @State dayEvents: DayEvent[] = [];
  @State user: UserAccount | null = null;
  @State savedPlan: SavedTodayPlan | null = null;
  @State hasPlanQuota: boolean = true;
  @State navFocusedIndex: number = -1;
  @State navHoveredIndex: number = -1;
  @State fabFocused: boolean = false;
  @State fabHovered: boolean = false;
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  private readonly fabSize: number = FAB_SIZE;
  private readonly bottomBarHeight: number = BOTTOM_BAR_HEIGHT;
  private hasHandledEntryParams: boolean = false;
  private hasRegisteredDbListener: boolean = false;
  private hasScheduledPageReload: boolean = false;
  private isPageDataLoading: boolean = false;
  private pendingPageDataReload: boolean = false;
  private dataChangeListener: () => void = () => {
    this.schedulePageDataReload();
  };

  aboutToAppear(): void {
    if (!this.hasRegisteredDbListener) {
      db.onDataChanged(this.dataChangeListener);
      this.hasRegisteredDbListener = true;
    }
    void this.initializePage();
  }

  aboutToDisappear(): void {
    if (this.hasRegisteredDbListener) {
      db.offDataChanged(this.dataChangeListener);
      this.hasRegisteredDbListener = false;
    }
  }

  onPageShow(): void {
    void this.refreshOnPageShow();
    this.handleEntryParams();
  }
  private async refreshOnPageShow(): Promise<void> {
    try {
      // 从服务端拉取最新用户信息（会员状态可能被后台或购买页修改）
      const refreshedUser = await authService.refreshUserFromServer();
      if (refreshedUser) {
        this.user = refreshedUser;
      }
    } catch (_e) {
      // 网络异常时静默降级
    }
    await this.loadPageData();
  }

  private getHostContext(): Context {
    return this.getUIContext().getHostContext() as Context;
  }

  private async initializePage(): Promise<void> {
    try {
      const context = this.getHostContext();
      await db.initialize(context);
      await authService.initialize(context);
      await this.loadPageData();
      this.handleEntryParams();
    } catch (error) {
      logger.error('MainPage initialize failed', error as Object);
      this.getUIContext().getPromptAction().showToast({ message: '首页初始化失败' });
    }
  }

  private schedulePageDataReload(): void {
    if (this.hasScheduledPageReload) {
      return;
    }
    this.hasScheduledPageReload = true;
    setTimeout(() => {
      this.hasScheduledPageReload = false;
      void this.loadPageData();
    }, 16);
  }

  private async loadPageData(): Promise<void> {
    if (this.isPageDataLoading) {
      this.pendingPageDataReload = true;
      return;
    }

    this.isPageDataLoading = true;
    try {
      do {
        this.pendingPageDataReload = false;
        const context = this.getHostContext();
        this.goals = db.getActiveGoals();
        this.tasks = db.getAllTasks();
        this.dayEvents = db.getAllDayEvents();
        this.user = await authService.getCurrentUser();
        await this.loadTodayPlan(context);
      } while (this.pendingPageDataReload);
    } catch (error) {
      logger.error('MainPage loadPageData failed', error as Object);
      this.goals = [];
      this.tasks = [];
      this.dayEvents = [];
      this.savedPlan = null;
    } finally {
      this.isPageDataLoading = false;
    }
  }

  private async loadTodayPlan(context: Context): Promise<void> {
    try {
      const result = await TodayPlanService.loadPlan(context);
      this.savedPlan = result.plan;
    } catch (error) {
      logger.error('MainPage loadTodayPlan failed', error as Object);
      this.savedPlan = null;
    }
  }

  private handleEntryParams(): void {
    if (this.hasHandledEntryParams) {
      return;
    }

    this.hasHandledEntryParams = true;
    const params = this.getUIContext().getRouter().getParams() as Record<string, Object>;
    if (!params || params['openGoalCreate'] !== 'true') {
      return;
    }

    const category = params['onboardingCategory'] as string;
        this.getUIContext().getPromptAction().showToast({ message: '已进入首页，继续创建目标' });
    setTimeout(() => {
      if (category && category.length > 0) {
        const routeParams: GoalInfoRouteParams = { category: category };
        this.getUIContext().getRouter().pushUrl({ url: 'pages/GoalInfoPage', params: routeParams });
      } else {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/GoalInfoPage' });
      }
    }, 250);
  }

  private openSearchPage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/SearchPage' });
  }

  private openGoalCreatePage(): void {
    this.showAddSheet = false;
    this.getUIContext().getRouter().pushUrl({ url: 'pages/GoalInfoPage' });
  }

  private openTaskCreatePage(): void {
    this.showAddSheet = false;
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CreateTaskPage' });
  }

  private openReminderCreatePage(): void {
    this.showAddSheet = false;
    this.getUIContext().getRouter().pushUrl({ url: 'pages/DayEventCreatePage' });
  }

  private openPomodoroCreatePage(): void {
    this.showAddSheet = false;
    this.getUIContext().getRouter().pushUrl({ url: 'pages/CreatePomodoroPage' });
  }

  private buildReminderRouteParams(parsed: VoiceCreateParsed): ReminderVoiceRouteParams {
    const params: ReminderVoiceRouteParams = {
      title: parsed.title || parsed.rawText || ''
    };

    if (parsed.rawText) {
      params.voiceRawText = parsed.rawText;
    }
    if (parsed.eventType) {
      params.voiceEventType = parsed.eventType;
    }
    if (parsed.periodicMode) {
      params.voicePeriodicMode = parsed.periodicMode;
    }
    if (parsed.habitMode) {
      params.voiceHabitMode = parsed.habitMode;
    }
    if (parsed.counterMode) {
      params.voiceCounterMode = parsed.counterMode;
    }
    if (parsed.startDate) {
      params.voiceStartDate = parsed.startDate;
    }
    if (parsed.endDate) {
      params.voiceEndDate = parsed.endDate;
    }
    if (parsed.hasEndDate !== undefined) {
      params.voiceHasEndDate = parsed.hasEndDate ? 'true' : 'false';
    }
    if (parsed.targetDate) {
      params.voiceTargetDate = parsed.targetDate;
    }
    if (parsed.hour !== undefined) {
      params.voiceHour = String(parsed.hour);
    }
    if (parsed.minute !== undefined) {
      params.voiceMinute = String(parsed.minute);
    }
    if (parsed.weekday !== undefined) {
      params.voiceWeekday = String(parsed.weekday);
    }
    if (parsed.dayOfMonth !== undefined) {
      params.voiceDayOfMonth = String(parsed.dayOfMonth);
    }
    if (parsed.intervalDays !== undefined) {
      params.voiceIntervalDays = String(parsed.intervalDays);
    }
    if (parsed.timesPerPeriod !== undefined) {
      params.voiceTimesPerPeriod = String(parsed.timesPerPeriod);
    }
    if (parsed.leadDays !== undefined) {
      params.voiceLeadDays = String(parsed.leadDays);
    }
    if (parsed.offsetValue !== undefined) {
      params.voiceOffsetValue = String(parsed.offsetValue);
    }
    if (parsed.offsetUnit) {
      params.voiceOffsetUnit = parsed.offsetUnit;
    }

    return params;
  }

  private openReminderCreatePageWithVoice(parsed: VoiceCreateParsed): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/DayEventCreatePage',
      params: this.buildReminderRouteParams(parsed)
    });
  }

  private closeAddSheet(): void {
    this.voiceCloseBlocked = false;
    this.showAddSheet = false;
  }

  onBackPress(): boolean {
    if (this.showAddSheet) {
      this.closeAddSheet();
      return true;
    }
    return false;
  }

  private openTodayPlanPage(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/TodayPlanPage' });
  }

  private openManualTaskSelect(): void {
    this.getUIContext().getRouter().pushUrl({ url: 'pages/TaskSelectPage' });
  }

  private handleAddAction(actionKey: string): void {
    if (actionKey === 'goal') {
      this.openGoalCreatePage();
      return;
    }
    if (actionKey === 'task') {
      this.openTaskCreatePage();
      return;
    }
    if (actionKey === 'reminder') {
      this.openReminderCreatePage();
      return;
    }
    if (actionKey === 'focus') {
      this.openPomodoroCreatePage();
      return;
    }
  }

  @Builder
  private PageContent() {
    if (this.currentTabIndex === 0) {
      TodayTab({
        goals: this.goals,
        tasks: this.tasks,
        savedPlan: this.savedPlan,
        user: this.user,
        dayEvents: this.dayEvents,
        onShowTodayPlanDialog: () => { this.openTodayPlanPage(); },
        onOpenManualTaskSelect: () => { this.openManualTaskSelect(); },
        onCheckGoalQuotaAndNavigate: () => { this.openGoalCreatePage(); },
        onOpenSearch: () => { this.openSearchPage(); }
      })
    } else if (this.currentTabIndex === 1) {
      TaskListTab({
        tasks: this.tasks,
        goals: this.goals
      })
    } else if (this.currentTabIndex === 2) {
      CalendarTab({
        dayEvents: this.dayEvents,
        tasks: this.tasks
      })
    } else {
      MeTab({ user: this.user })
    }
  }

  private isTabActive(index: number): boolean {
    return this.currentTabIndex === index;
  }

  private tabLabelColor(index: number): string {
    return this.isTabActive(index) ? this.themeColors.primary : this.themeColors.textSecondary;
  }

  private getNavItemBackgroundColor(index: number): string {
    if (this.isTabActive(index)) {
      return this.themeColors.primarySubtle;
    }
    if (this.navFocusedIndex === index || this.navHoveredIndex === index) {
      return this.themeColors.surfaceSoft;
    }
    return this.themeColors.transparent;
  }

  private getNavItemBorderColor(index: number): string {
    if (this.navFocusedIndex === index) {
      return this.themeColors.primary;
    }
    if (this.navHoveredIndex === index) {
      return this.themeColors.primaryLight;
    }
    return this.themeColors.transparent;
  }

  private getFabBorderColor(): string {
    return this.fabFocused || this.fabHovered ? this.themeColors.primaryLight : this.themeColors.transparent;
  }

  private getTabIconName(index: number): string {
    if (index === 0) {
      return 'today';
    }
    if (index === 1) {
      return 'task';
    }
    if (index === 2) {
      return 'calendar';
    }
    return 'profile';
  }

  @Builder
  private TabIcon(index: number) {
    AppIcon({
      name: this.getTabIconName(index),
      iconSize: NAV_ICON_SIZE,
      framed: false,
      color: this.tabLabelColor(index)
    })
  }

  @Builder
  private NavItem(index: number, label: string) {
    Column({ space: SPACE_2XS }) {
      this.TabIcon(index)
      Text(label)
        .fontSize(TYPE_CAPTION)
        .fontWeight(this.isTabActive(index) ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.tabLabelColor(index))
    }
    .layoutWeight(1)
    .padding({ left: SPACE_XS, right: SPACE_XS, top: SPACE_XS, bottom: SPACE_2XS })
    .justifyContent(FlexAlign.Center)
    .constraintSize({ minHeight: TOUCH_TARGET_LG })
    .backgroundColor(this.getNavItemBackgroundColor(index))
    .borderRadius(RADIUS_LG)
    .border({ width: BORDER_DEFAULT, color: this.getNavItemBorderColor(index) })
    .focusable(true)
    .onFocus(() => {
      this.navFocusedIndex = index;
    })
    .onBlur(() => {
      if (this.navFocusedIndex === index) {
        this.navFocusedIndex = -1;
      }
    })
    .onHover((isHover: boolean) => {
      this.navHoveredIndex = isHover ? index : -1;
    })
    .onClick(() => {
      this.currentTabIndex = index;
      this.showAddSheet = false;
    })
  }

  @Builder
  private BottomBar() {
    Row() {
      this.NavItem(0, '今日')
      this.NavItem(1, '任务')
      Blank().layoutWeight(1)
      this.NavItem(2, '打卡')
      this.NavItem(3, '我的')
    }
    .width('100%')
    .height(this.bottomBarHeight)
    .padding({ left: SPACE_SM, right: SPACE_SM, top: SPACE_SM, bottom: SPACE_2XS })
    .backgroundColor(this.themeColors.surface)
    .border({ width: { top: 1 }, color: this.themeColors.borderColor })
  }

  @Builder
  private AddSheetItem(icon: string, title: string, desc: string, actionKey: string) {
    AppCard({
      variant: 'raised',
      spacing: SPACE_MD,
      paddingLevel: 'md',
      interactive: true,
      tapAction: () => {
        if (!this.voiceCloseBlocked) {
          this.handleAddAction(actionKey);
        }
      }
    }) {
      Row({ space: SPACE_MD }) {
        AppIcon({ name: icon, iconSize: ICON_SIZE_XL })
        Column({ space: SPACE_2XS }) {
          Text(title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')
          Text(desc)
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        AppIcon({
          name: 'chevron-right',
          iconSize: ICON_SIZE_XL,
          framed: false,
          color: this.themeColors.textMuted
        })
      }
    }
  }

  @Builder
  private AddActionSheet() {
    Column() {
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor(this.themeColors.surfaceOverlay)
        .onClick(() => {
          if (!this.voiceCloseBlocked) {
            this.closeAddSheet();
          }
        })

      Column() {
        AppCard({ variant: 'raised', spacing: PANEL_GAP, paddingLevel: 'lg' }) {
          Text('新建内容')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')

          Column({ space: CONTENT_GAP }) {
            this.AddSheetItem('goal', '新建目标', '设定方向和阶段计划', 'goal')
            this.AddSheetItem('task', '新建行动', '记录接下来要推进的一件事', 'task')
            this.AddSheetItem('reminder', '新建提醒', '添加倒计时或日常提醒', 'reminder')
            this.AddSheetItem('focus', '开始专注', '立即开启一段番茄专注', 'focus')
          }
          .width('100%')

          VoiceCreateOverlay({
            hostContext: this.getHostContext(),
            onBusyStateChange: (busy: boolean) => {
              this.voiceCloseBlocked = busy;
            },
            onClose: () => {
              this.closeAddSheet();
            },
            onResult: (output: VoiceCreateOutput) => {
              this.closeAddSheet();
              this.handleVoiceResult(output);
            }
          })
        }
      }
      .width('100%')
      .padding({ left: SPACE_CARD, right: SPACE_CARD, top: PANEL_GAP, bottom: SPACE_CARD })

      Row()
        .width('100%')
        .height(this.bottomBarHeight + this.fabSize / 2 + SPACE_CARD)
    }
    .width('100%')
    .height('100%')
    .zIndex(20)
  }

  @Builder
  private FloatingButton() {
    Button() {
      MainFabButton()
    }
    .width(this.fabSize)
    .height(this.fabSize)
    .backgroundColor(Color.Transparent)
    .borderRadius(this.fabSize / 2)
    .border({ width: BORDER_DEFAULT, color: this.getFabBorderColor() })
    .stateEffect(true)
    .hoverEffect(HoverEffect.Auto)
    .focusable(true)
    .onFocus(() => {
      this.fabFocused = true;
    })
    .onBlur(() => {
      this.fabFocused = false;
    })
    .onHover((isHover: boolean) => {
      this.fabHovered = isHover;
    })
    .onClick(() => {
      if (this.showAddSheet) {
        this.closeAddSheet();
      } else {
        this.showAddSheet = true;
        this.voiceCloseBlocked = false;
      }
    })
    .align(Alignment.Bottom)
    .zIndex(10)
    .rotate({ angle: this.showAddSheet ? 45 : 0 })
    .animation({ duration: 250, curve: Curve.EaseInOut })
  }

  @Builder
  private BottomNavigationArea() {
    Stack({ alignContent: Alignment.Bottom }) {
      this.BottomBar()
      this.FloatingButton()
    }
    .width('100%')
    .height(this.bottomBarHeight)
    .backgroundColor(this.themeColors.surface)
    .clip(false)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Stack() {
      Column() {
        Column() {
          if (this.isPageDataLoading && this.goals.length === 0 && this.tasks.length === 0) {
            AppLoadingState({ label: '加载中...' })
          } else {
            this.PageContent()
          }
        }
        .layoutWeight(1)
        .width('100%')
        this.BottomNavigationArea()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeColors.background)

      if (this.showAddSheet) {
        this.AddActionSheet()

        Stack() {
          this.FloatingButton()
        }
        .width(this.fabSize)
        .height(this.fabSize)
        .align(Alignment.Bottom)
        .translate({ y: -(this.bottomBarHeight / 2) })
        .zIndex(30)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }

  private handleVoiceResult(output: VoiceCreateOutput): void {
    if (output.intent === 'goal') {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/GoalBreakdownPage',
        params: { intent: output.parsed.intentText || '' }
      });
    } else if (output.intent === 'task') {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/CreateTaskPage',
        params: {
          autoFill: 'true',
          title: output.parsed.title || '',
          description: output.parsed.description || '',
          priority: output.parsed.priority || 'normal',
          dueDate: output.parsed.dueDate || '',
          goalId: output.parsed.goalId || '',
          krId: output.parsed.krId || ''
        }
      });
    } else if (output.intent === 'reminder') {
      this.openReminderCreatePageWithVoice(output.parsed);
    } else if (output.intent === 'focus') {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/CreatePomodoroPage',
        params: {
          focusSubject: output.parsed.focusSubject || '',
          duration: output.parsed.duration || 25,
          taskId: output.parsed.matchedTaskId || '',
          taskTitle: output.parsed.matchedTaskTitle || ''
        }
      });
    } else {
      this.handleVoiceFallback(output.parsed);
    }
  }

  private handleVoiceFallback(parsed: VoiceCreateParsed): void {
    const goalIntent = (parsed.intentText || '').trim();
    if (goalIntent) {
      this.getUIContext().getPromptAction().showToast({ message: '已保留原话，先带你进入 AI 目标规划页' });
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/GoalBreakdownPage',
        params: { intent: goalIntent }
      });
      return;
    }

    const focusSubject = (parsed.focusSubject || '').trim();
    if (focusSubject) {
      this.getUIContext().getPromptAction().showToast({ message: '已保留原话，先带你进入专注创建页' });
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/CreatePomodoroPage',
        params: {
          focusSubject,
          duration: parsed.duration || 25,
          taskId: parsed.matchedTaskId || '',
          taskTitle: parsed.matchedTaskTitle || ''
        }
      });
      return;
    }

    const reminderText = (parsed.rawText || '').trim();
    if (reminderText && (parsed.eventType || parsed.title)) {
      this.getUIContext().getPromptAction().showToast({ message: '已保留原话，先带你进入提醒创建页' });
      this.openReminderCreatePageWithVoice(parsed);
      return;
    }

    const fallbackTitle = (parsed.title || reminderText || '').trim();
    const fallbackDescription = (parsed.description || '').trim();
    const fallbackRawText = this.getVoiceFallbackText(parsed);

    if (!fallbackRawText) {
      this.getUIContext().getPromptAction().showToast({ message: '暂时没完全识别出类型，换一种说法再试一次' });
      return;
    }

    this.getUIContext().getPromptAction().showToast({ message: '暂时没完全识别出类型，已先保留到文字创建页' });
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/CreateTaskPage',
      params: {
        autoFill: 'true',
        title: fallbackTitle || fallbackRawText,
        description: fallbackDescription || (fallbackRawText !== fallbackTitle ? fallbackRawText : '')
      }
    });
  }

  private getVoiceFallbackText(parsed: VoiceCreateParsed): string {
    return (
      parsed.title ||
      parsed.rawText ||
      parsed.intentText ||
      parsed.focusSubject ||
      parsed.description ||
      ''
    ).trim();
  }
}
