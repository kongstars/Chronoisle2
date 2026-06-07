import { Goal } from '../models/Goal';
import { Task } from '../models/Task';
import { DayEvent } from '../models/DayEvent';
import { db } from '../storage/Database';
import { authService, UserAccount } from '../services/AuthService';
import type { SavedTodayPlan } from '../models/TodayPlan';
import { injectTodayReminders } from '../models/TodayPlan';
import { TodayTabV2 } from '../components/TodayTabV2';
import { ActionTab } from '../components/ActionTab';
import { GoalsTab } from '../components/GoalsTab';
import { MeTab } from '../components/MeTab';
import { VoiceCreateOverlay, VoiceCreateOutput } from '../components/VoiceCreateOverlay';
import { VoiceCreateParsed, VoiceCreateService, VoiceCreateResult } from '../services/VoiceCreateService';
import { VoiceRecognitionService } from '../services/VoiceRecognitionService';
import { QuotaService, SpendResult } from '../services/QuotaService';
import { hasMicrophonePermission, requestMicrophonePermission } from '../Utils/UserPerm';
import { TodayPlanService } from '../services/TodayPlanService';
import { GoalReschedulePromptService, type GoalReschedulePrompt } from '../services/GoalReschedulePromptService';
import { TelemetryService, type TelemetryProperties } from '../services/TelemetryService';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppIcon } from '../ui/base/AppIcon';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { BORDER_DEFAULT } from '../foundation/tokens/BorderTokens';
import { BOTTOM_BAR_HEIGHT, FAB_SIZE, NAV_ICON_SIZE } from '../foundation/tokens/PageDensityTokens';
import { RADIUS_PILL } from '../foundation/tokens/RadiusTokens';
import { CONTENT_GAP, PANEL_GAP, SPACE_2XS, SPACE_CARD, SPACE_MD, SPACE_SM } from '../foundation/tokens/SpacingTokens';
import { ICON_SIZE_SM, ICON_SIZE_XL } from '../foundation/tokens/IconTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
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

interface MainPageEntryRouteParams {
  openGoalCreate?: string;
  onboardingCategory?: string;
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
  @State showVoiceOnly: boolean = false;
  @State voiceCloseBlocked: boolean = false;
  @State voiceInlinePhase: string = 'idle'; // idle | checking | recording | analyzing | error
  @State voiceInlineText: string = '';
  @State voiceInlineError: string = '';
  @State goals: Goal[] = [];
  @State tasks: Task[] = [];
  @State dayEvents: DayEvent[] = [];
  @State user: UserAccount | null = null;
  @State savedPlan: SavedTodayPlan | null = null;
  @State goalReschedulePrompt: GoalReschedulePrompt | null = null;
  @State hasPlanQuota: boolean = true;
  @State fabFocused: boolean = false;
  @State fabPressed: boolean = false;
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  private readonly fabSize: number = FAB_SIZE;
  private readonly bottomBarHeight: number = BOTTOM_BAR_HEIGHT;
  private hasHandledEntryParams: boolean = false;
  private hasRegisteredDbListener: boolean = false;
  private hasScheduledPageReload: boolean = false;
  private readonly voiceRecognition: VoiceRecognitionService = VoiceRecognitionService.getInstance();
  private voicePressActive: boolean = false;
  private voiceHoldStartTimer: number = -1;
  @State isPageDataLoading: boolean = false;
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
    // 先快速加载本地数据（同步路径，不卡 UI）
    await this.loadPageData();

    // 然后在后台异步刷新云端数据，不阻塞页面显示
    void this.refreshFromCloudInBackground();
  }

  private async refreshFromCloudInBackground(): Promise<void> {
    try {
      const refreshedUser = await authService.refreshUserFromServer();
      if (refreshedUser) {
        this.user = refreshedUser;
      }
      await this.refreshTodayPlanFromCloud(this.getHostContext());
    } catch (_e) {
      // 后台刷新失败静默忽略
    }
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
        // 仅读取本地数据，不做网络请求；保证切页面不会卡住
        this.goals = db.getActiveGoals();
        this.tasks = db.getAllTasks();
        this.dayEvents = db.getAllDayEvents();
        this.user = await authService.getCurrentUser();
        await this.loadTodayPlan(context);
        await this.refreshGoalReschedulePrompt(false);
      } while (this.pendingPageDataReload);
    } catch (error) {
      logger.error('MainPage loadPageData failed', error as Object);
      // 不重置已有数据，避免 loading 死循环
    } finally {
      this.isPageDataLoading = false;
    }
  }

  private async loadTodayPlan(context: Context): Promise<void> {
    try {
      // 仅读取本地缓存计划，不做网络请求（loadPlan 会触发 HTTP 调用导致页面卡住）
      const localPlan = await TodayPlanService.loadLocalPlan(context);
      if (localPlan) {
        this.savedPlan = injectTodayReminders(localPlan, this.dayEvents, this.tasks);
      } else {
        // 即使没有本地计划，也构建一个仅含提醒的计划
        const emptyPlan: SavedTodayPlan = { focusTasks: [], deferTasks: [], summary: '今日计划' };
        const withReminders = injectTodayReminders(emptyPlan, this.dayEvents, this.tasks);
        this.savedPlan = withReminders.focusTasks.length > 0 ? withReminders : null;
      }
    } catch (error) {
      logger.error('MainPage loadTodayPlan failed', error as Object);
      // 出错也不重置 savedPlan，保留之前显示的内容
    }
  }

  private async refreshTodayPlanFromCloud(context: Context): Promise<void> {
    try {
      const result = await TodayPlanService.loadPlan(context);
      if (result.plan) {
        this.savedPlan = injectTodayReminders(result.plan, this.dayEvents, this.tasks);
      }
    } catch (error) {
      logger.error('MainPage refreshTodayPlanFromCloud failed', error as Object);
    }
  }

  private async refreshGoalReschedulePrompt(markAsShown: boolean): Promise<void> {
    if (this.currentTabIndex !== 2) {
      this.goalReschedulePrompt = null;
      return;
    }

    try {
      const context = this.getHostContext();
      const candidate = await GoalReschedulePromptService.getPromptCandidate(context, this.goals, this.tasks);
      if (!candidate) {
        if (this.goalReschedulePrompt &&
          GoalReschedulePromptService.isGoalStillEligible(this.goalReschedulePrompt.goalId, this.goals, this.tasks)) {
          return;
        }
        this.goalReschedulePrompt = null;
        return;
      }

      this.goalReschedulePrompt = candidate;
      if (markAsShown) {
        await GoalReschedulePromptService.markPromptShown(context, candidate.goalId);
        const shownProps: TelemetryProperties = {
          "goalId": candidate.goalId,
          "remainingTaskCount": candidate.remainingTaskCount,
          "overdueTaskCount": candidate.overdueTaskCount,
          "stalledDays": candidate.stalledDays
        };
        TelemetryService.track('goal_reschedule_prompt_shown', shownProps, 'goal');
      }
    } catch (error) {
      logger.error('MainPage refreshGoalReschedulePrompt failed', error as Object);
    }
  }

  private async dismissGoalReschedulePrompt(goalId: string): Promise<void> {
    try {
      await GoalReschedulePromptService.dismissPrompt(this.getHostContext(), goalId);
      const dismissProps: TelemetryProperties = {
        "goalId": goalId
      };
      TelemetryService.track('goal_reschedule_prompt_dismissed', dismissProps, 'goal');
    } catch (error) {
      logger.error('MainPage dismissGoalReschedulePrompt failed', error as Object);
    } finally {
      if (this.goalReschedulePrompt?.goalId === goalId) {
        this.goalReschedulePrompt = null;
      }
    }
  }

  private async openGoalRescheduleFromPrompt(goalId: string): Promise<void> {
    try {
      await GoalReschedulePromptService.acceptPrompt(this.getHostContext(), goalId);
      const clickProps: TelemetryProperties = {
        "goalId": goalId
      };
      TelemetryService.track('goal_reschedule_prompt_clicked', clickProps, 'goal');
    } catch (error) {
      logger.error('MainPage openGoalRescheduleFromPrompt failed', error as Object);
    } finally {
      if (this.goalReschedulePrompt?.goalId === goalId) {
        this.goalReschedulePrompt = null;
      }
      this.getUIContext().getRouter().pushUrl({ url: 'pages/GoalReschedulePage', params: { goalId } });
    }
  }

  private handleEntryParams(): void {
    if (this.hasHandledEntryParams) {
      return;
    }

    this.hasHandledEntryParams = true;
    const params = this.getUIContext().getRouter().getParams() as MainPageEntryRouteParams;
    if (!params || params.openGoalCreate !== 'true') {
      return;
    }

    const category = params.onboardingCategory || '';
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
    if (this.showVoiceOnly) {
      if (!this.voiceCloseBlocked) {
        this.showVoiceOnly = false;
      }
      return true;
    }
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
      TodayTabV2({
        goals: this.goals,
        tasks: this.tasks,
        savedPlan: this.savedPlan,
        user: this.user,
        dayEvents: this.dayEvents,
        onCreateTask: () => { this.openTaskCreatePage(); },
        onCreateGoal: () => { this.openGoalCreatePage(); },
        onCreateReminder: () => { this.openReminderCreatePage(); },
        onStartFocus: () => { this.openPomodoroCreatePage(); },
        onOpenSearch: () => { this.openSearchPage(); },
        onOpenTodayPlan: () => { this.openTodayPlanPage(); },
        onOpenGoalDetail: (goalId: string) => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/GoalDetailPage', params: { goalId } });
        },
        onOpenReschedule: () => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/ReschedulePage' });
        },
        onOpenReminderCenter: () => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/ReminderListPage' });
        },
        onOpenTaskDetail: (taskId: string) => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/TaskDetailPage', params: { taskId } });
        },
        onToggleTaskComplete: (task: Task) => {
          void db.setTaskCompletion(task.id, task.status !== 'completed');
          void this.loadPageData();
        },
        onCompleteReminder: (eventId: string) => {
          void db.completeDayEventOccurrence(eventId).then(() => {
            void this.loadPageData();
          });
        }
      })
    } else if (this.currentTabIndex === 1) {
      ActionTab({
        tasks: this.tasks,
        goals: this.goals,
        dayEvents: this.dayEvents,
        onCreate: () => {
          this.showAddSheet = true;
          this.voiceCloseBlocked = false;
        },
        onOpenReminderCenter: () => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/ReminderListPage' });
        },
        onOpenSearch: () => { this.openSearchPage(); }
      })
    } else if (this.currentTabIndex === 2) {
      GoalsTab({
        goals: this.goals,
        tasks: this.tasks,
        goalReschedulePrompt: this.goalReschedulePrompt,
        onCreate: () => {
          this.openGoalCreatePage();
        },
        onOpenGoalDetail: (goalId: string) => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/GoalDetailPage', params: { goalId } });
        },
        onOpenGoalReschedule: (goalId: string) => {
          void this.openGoalRescheduleFromPrompt(goalId);
        },
        onDismissGoalReschedulePrompt: (goalId: string) => {
          void this.dismissGoalReschedulePrompt(goalId);
        }
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

  private tabIconColor(index: number): string {
    if (this.isTabActive(index)) {
      return this.themeColors.primary;
    }
    if (index === 0) {
      return this.themeColors.textMuted;
    }
    return this.themeColors.textSecondary;
  }

  private getFabBorderColor(): string {
    return this.fabFocused || this.fabPressed ? this.themeColors.primaryLight : this.themeColors.transparent;
  }

  // ========== 底部 Tab 图标（统一走 AppIcon） ==========

  private getTabIconName(index: number): string {
    if (index === 0) {
      return 'today';
    }
    if (index === 1) {
      return 'action';
    }
    if (index === 2) {
      return 'goal';
    }
    return 'profile';
  }

  @Builder
  private TabIcon(index: number) {
    if (index === 0 && !this.isTabActive(index)) {
      Image($r('app.media.app_icon_today_inactive'))
        .width(NAV_ICON_SIZE)
        .height(NAV_ICON_SIZE)
        .objectFit(ImageFit.Contain)
        .interpolation(ImageInterpolation.High)
        .draggable(false)
        .syncLoad(true)
    } else {
      AppIcon({
        name: this.getTabIconName(index),
        iconSize: NAV_ICON_SIZE,
        color: this.tabIconColor(index),
        framed: false,
        useSystemSymbol: false,
        selected: this.isTabActive(index)
      })
    }
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
    .justifyContent(FlexAlign.Center)
    .constraintSize({ minHeight: TOUCH_TARGET_LG })
    .onClick(() => {
      this.getUIContext().animateTo({ duration: 450, curve: Curve.FastOutSlowIn }, () => {
        this.currentTabIndex = index;
        this.showAddSheet = false;
        this.showVoiceOnly = false;
      });
      this.resetInlineVoiceState();
      if (index === 2) {
        void this.refreshGoalReschedulePrompt(true);
      } else {
        this.goalReschedulePrompt = null;
      }
    })
  }

  // 收缩态：当前 tab 的 icon（无背景，由外层容器提供）
  @Builder
  private CollapsedNavIcon() {
    Stack({ alignContent: Alignment.Center }) {
      this.TabIcon(this.currentTabIndex)
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      this.getUIContext().animateTo({ duration: 450, curve: Curve.FastOutSlowIn }, () => {
        this.showVoiceOnly = false;
      });
      this.resetInlineVoiceState();
    })
  }

  // 语音按钮（实心圆形，无边框，无独立阴影 - 由外层容器提供）
  @Builder
  private VoiceMicButton() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeColors.announcementSurface)
        .borderRadius(RADIUS_PILL)
        .border({ width: BORDER_DEFAULT, color: this.themeColors.primaryLight })
      AppIcon({
        name: 'voice',
        iconSize: NAV_ICON_SIZE,
        color: this.themeColors.primary,
        framed: false,
        useSystemSymbol: false
      })
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      this.getUIContext().animateTo({ duration: 450, curve: Curve.FastOutSlowIn }, () => {
        this.showVoiceOnly = true;
      });
    })
  }

  @Builder
  private BottomBar() {
    Column() {
      Row({ space: SPACE_SM }) {
        // 左侧容器：固定 navBackground + 阴影，宽度动画
        Stack({ alignContent: Alignment.Start }) {
          // 4 tab 视图（默认态）
          Row() {
            this.NavItem(0, '今日')
            this.NavItem(1, '行动')
            this.NavItem(2, '目标')
            this.NavItem(3, '我的')
          }
          .width('100%')
          .height('100%')
          .padding({ left: SPACE_MD, right: SPACE_MD })
          .visibility(this.showVoiceOnly ? Visibility.None : Visibility.Visible)

          // 收缩 icon（语音态）
          Stack() {
            this.CollapsedNavIcon()
          }
          .width('100%')
          .height('100%')
          .visibility(this.showVoiceOnly ? Visibility.Visible : Visibility.None)
        }
        .width(this.showVoiceOnly ? this.bottomBarHeight - 8 : undefined)
        .height(this.bottomBarHeight - 8)
        .layoutWeight(this.showVoiceOnly ? 0 : 1)
        .clip(true)
        .backgroundColor(this.themeColors.navBackground)
        .borderRadius(RADIUS_PILL)
        .shadow({ radius: 16, color: this.themeColors.cardShadow, offsetX: 0, offsetY: 4 })

        // 右侧容器：固定 navBackground + 阴影，宽度动画
        Stack({ alignContent: Alignment.End }) {
          // 语音按钮（默认态）- 蓝色实心圆覆盖白色容器
          Stack() {
            this.VoiceMicButton()
          }
          .width('100%')
          .height('100%')
          .visibility(this.showVoiceOnly ? Visibility.None : Visibility.Visible)

          // 语音输入面板（语音态）
          Row() {
            this.InlineVoicePanel()
          }
          .width('100%')
          .height('100%')
          .padding({ left: SPACE_SM, right: SPACE_SM })
          .visibility(this.showVoiceOnly ? Visibility.Visible : Visibility.None)
        }
        .width(this.showVoiceOnly ? undefined : this.bottomBarHeight - 8)
        .height(this.bottomBarHeight - 8)
        .layoutWeight(this.showVoiceOnly ? 1 : 0)
        .clip(true)
        .backgroundColor(this.themeColors.navBackground)
        .borderRadius(RADIUS_PILL)
        .shadow({ radius: 16, color: this.themeColors.cardShadow, offsetX: 0, offsetY: 4 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: SPACE_CARD, right: SPACE_CARD, top: SPACE_2XS, bottom: SPACE_SM })
  }

  // ========== 内联语音面板（专为底部胶囊设计） ==========

  private resetInlineVoiceState(): void {
    this.voiceInlinePhase = 'idle';
    this.voiceInlineText = '';
    this.voiceInlineError = '';
    this.voiceCloseBlocked = false;
    this.voicePressActive = false;
    if (this.voiceHoldStartTimer !== -1) {
      clearTimeout(this.voiceHoldStartTimer);
      this.voiceHoldStartTimer = -1;
    }
  }

  private async startInlineVoice(): Promise<void> {
    if (this.voiceInlinePhase !== 'idle' && this.voiceInlinePhase !== 'error') {
      return;
    }

    this.voicePressActive = true;
    this.voiceInlinePhase = 'checking';
    this.voiceInlineText = '';
    this.voiceInlineError = '';
    this.voiceCloseBlocked = true;

    // 用户登录检查
    const currentUser = await authService.getCurrentUser();
    if (!currentUser) {
      this.voiceInlineError = '请先登录后再使用语音创建';
      this.voiceInlinePhase = 'error';
      this.voiceCloseBlocked = false;
      this.voicePressActive = false;
      return;
    }

    // 配额检查
    const accessResult = await QuotaService.checkVoiceCreateAccess();
    if (!accessResult.allowed) {
      this.voiceInlineError = accessResult.message || '当前暂时无法使用语音创建';
      this.voiceInlinePhase = 'error';
      this.voiceCloseBlocked = false;
      this.voicePressActive = false;
      return;
    }

    // 麦克风权限检查
    if (!(await hasMicrophonePermission())) {
      const granted = await requestMicrophonePermission(this.getHostContext());
      if (!granted) {
        this.voiceInlineError = '请先允许麦克风权限后再使用语音输入';
        this.voiceInlinePhase = 'error';
        this.voiceCloseBlocked = false;
        this.voicePressActive = false;
        return;
      }
      // 权限刚授予，本次不继续录音，恢复 idle 让用户重新按住
      this.resetInlineVoiceState();
      return;
    }

    // 用户在权限检查期间已松手
    if (!this.voicePressActive) {
      this.resetInlineVoiceState();
      return;
    }

    // 启动录音
    this.voiceInlinePhase = 'recording';
    const status = await this.voiceRecognition.startRecognition(
      this.getHostContext(),
      (text: string) => {
        this.voiceInlineText = text;
      },
      (text: string) => {
        if (text.trim()) {
          this.voiceInlineText = text;
        }
      }
    );

    if (!this.voiceRecognition.isRecordingInProgress()) {
      this.voiceInlineError = status || '语音服务暂不可用';
      this.voiceInlinePhase = 'error';
      this.voiceCloseBlocked = false;
      this.voicePressActive = false;
    }
  }

  private async stopInlineVoice(): Promise<void> {
    this.voicePressActive = false;
    if (this.voiceHoldStartTimer !== -1) {
      clearTimeout(this.voiceHoldStartTimer);
      this.voiceHoldStartTimer = -1;
    }

    // 还在权限检查阶段，直接退出
    if (this.voiceInlinePhase === 'checking') {
      this.resetInlineVoiceState();
      return;
    }

    if (this.voiceInlinePhase !== 'recording') {
      return;
    }

    const text = (await this.voiceRecognition.stopRecognition()).trim();
    this.voiceRecognition.reset();
    this.voiceInlineText = text;

    // 没有内容，直接退出
    if (!text) {
      this.resetInlineVoiceState();
      return;
    }

    // 有内容，进入识别阶段
    this.voiceInlinePhase = 'analyzing';

    // 扣配额
    const spendResult: SpendResult = await QuotaService.spendCredit('voice_task');
    if (!spendResult.success) {
      this.voiceInlineError = spendResult.message || '当前暂时无法使用语音创建';
      this.voiceInlinePhase = 'error';
      this.voiceCloseBlocked = false;
      return;
    }

    // 调用后端识别意图
    const result: VoiceCreateResult = await VoiceCreateService.analyze(text);
    this.voiceCloseBlocked = false;

    if (result.success && result.intent && result.parsed) {
      // 成功，路由到对应创建页
      this.showVoiceOnly = false;
      this.resetInlineVoiceState();
      this.handleVoiceResult({
        intent: result.intent,
        parsed: result.parsed
      });
      return;
    }

    // 失败
    this.voiceInlineError = result.message || '没听清你说的内容，再试一次';
    this.voiceInlinePhase = 'error';
  }

  @Builder
  private InlineVoicePanel() {
    Row({ space: SPACE_SM }) {
      // 麦克风指示
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(32)
          .height(32)
          .backgroundColor(this.voiceInlinePhase === 'recording' ? this.themeColors.riskSurface :
                          this.voiceInlinePhase === 'error' ? this.themeColors.dangerSubtle :
                          this.themeColors.primarySubtle)
          .borderRadius(16)
        AppIcon({
          name: 'voice',
          iconSize: TYPE_BODY + 4,
          color: this.voiceInlinePhase === 'recording' ? this.themeColors.danger :
            this.voiceInlinePhase === 'error' ? this.themeColors.danger : this.themeColors.primary,
          framed: false,
          useSystemSymbol: false
        })
      }
      .width(32)
      .height(32)

      // 文字区域：实时转写或状态文字
      Column({ space: 2 }) {
        Text(this.getInlineVoiceTitle())
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.voiceInlinePhase === 'error' ? this.themeColors.danger : this.themeColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.getInlineVoiceHint())
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 右侧操作提示
      Text(this.getInlineVoiceAction())
        .fontSize(TYPE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.primary)
        .padding({ left: SPACE_SM, right: SPACE_2XS })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        // 错误态点击重置为 idle
        if (this.voiceInlinePhase === 'error') {
          this.resetInlineVoiceState();
          return;
        }
        void this.startInlineVoice();
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        void this.stopInlineVoice();
      }
    })
  }

  private getInlineVoiceTitle(): string {
    if (this.voiceInlinePhase === 'recording') {
      // 优先显示实时转写
      return this.voiceInlineText.length > 0 ? this.voiceInlineText : '正在听...';
    }
    if (this.voiceInlinePhase === 'analyzing') {
      return this.voiceInlineText.length > 0 ? this.voiceInlineText : '识别中...';
    }
    if (this.voiceInlinePhase === 'checking') {
      return '准备中...';
    }
    if (this.voiceInlinePhase === 'error') {
      return this.voiceInlineError || '出错了';
    }
    return '语音创建';
  }

  private getInlineVoiceHint(): string {
    if (this.voiceInlinePhase === 'recording') {
      return '松开完成录入';
    }
    if (this.voiceInlinePhase === 'analyzing') {
      return 'AI 正在理解你的意图';
    }
    if (this.voiceInlinePhase === 'checking') {
      return '正在准备语音输入';
    }
    if (this.voiceInlinePhase === 'error') {
      return '点击重试';
    }
    return '按住说话，松开完成';
  }

  private getInlineVoiceAction(): string {
    if (this.voiceInlinePhase === 'recording') {
      return '松开';
    }
    if (this.voiceInlinePhase === 'analyzing') {
      return '...';
    }
    if (this.voiceInlinePhase === 'checking') {
      return '...';
    }
    if (this.voiceInlinePhase === 'error') {
      return '重试';
    }
    return '按住';
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
            .fontSize(TYPE_BODY)
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
          Row() {
            Text('新建内容')
              .fontSize(TYPE_SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)

            Blank()

            Stack({ alignContent: Alignment.Center }) {
              Row()
                .width(TOUCH_TARGET_LG)
                .height(TOUCH_TARGET_LG)
                .backgroundColor(this.themeColors.surfaceSoft)
                .borderRadius(TOUCH_TARGET_LG / 2)
                .border({ width: BORDER_DEFAULT, color: this.themeColors.borderColor })

              AppIcon({
                name: 'close',
                iconSize: ICON_SIZE_SM,
                framed: false,
                color: this.themeColors.textSecondary
              })
            }
            .onClick(() => {
              if (!this.voiceCloseBlocked) {
                this.closeAddSheet();
              }
            })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

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
    Stack({ alignContent: Alignment.Center }) {
      MainFabButton()
    }
    .width(this.fabSize)
    .height(this.fabSize)
    .backgroundColor(Color.Transparent)
    .borderRadius(this.fabSize / 2)
    .border({ width: BORDER_DEFAULT, color: this.getFabBorderColor() })
    .scale({
      x: this.fabPressed ? 0.92 : 1,
      y: this.fabPressed ? 0.92 : 1
    })
    .animation({ duration: 100, curve: Curve.Friction })
    .focusable(true)
    .onFocus(() => {
      this.fabFocused = true;
    })
    .onBlur(() => {
      this.fabFocused = false;
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.fabPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.fabPressed = false;
      }
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
    Column() {
      this.BottomBar()
    }
    .width('100%')
    .backgroundColor(this.themeColors.transparent)
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
      }

      // AI 识别中浮层（仅在 analyzing 阶段显示）
      if (this.voiceInlinePhase === 'analyzing') {
        this.VoiceAnalyzingOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }

  @Builder
  private VoiceAnalyzingOverlay() {
    Column() {
      Column() {
        // 遮罩点击不关闭，避免用户误操作
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeColors.surfaceOverlay)

      // 居中卡片
      Column({ space: SPACE_CARD }) {
        // 旋转加载动画
        LoadingProgress()
          .width(48)
          .height(48)
          .color(this.themeColors.primary)

        Text('AI 正在理解')
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)

        if (this.voiceInlineText.length > 0) {
          Text(this.voiceInlineText)
            .fontSize(TYPE_BODY)
            .fontColor(this.themeColors.textSecondary)
            .textAlign(TextAlign.Center)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: SPACE_CARD, right: SPACE_CARD })
        } else {
          Text('正在分析你说的内容...')
            .fontSize(TYPE_BODY)
            .fontColor(this.themeColors.textSecondary)
        }

        Text('稍候片刻，即将进入创建页')
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textMuted)
      }
      .padding(SPACE_CARD * 2)
      .width('80%')
      .backgroundColor(this.themeColors.surface)
      .borderRadius(20)
      .shadow({ radius: 24, color: this.themeColors.cardShadow, offsetX: 0, offsetY: 8 })
      .position({ x: '10%', y: '36%' })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(40)
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
