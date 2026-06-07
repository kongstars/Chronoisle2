
import { Goal, KeyResult, GoalCategory } from '../models/Goal';
import { db } from '../storage/Database';
import { CATEGORIES, CategoryInfo } from '../common/Constants';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { Task, TaskStatus } from '../models/Task';
import { DayEvent, getEventTypeIcon, getEventTypeLabel } from '../models/DayEvent';
import { formatDayEventDate, getDayEventListSummary, getDayEventMetricText, isDayEventEnded } from '../common/DayEventUtils';
import { dataSyncService } from '../services/DataSyncService';
import { GoalBreakdownResult } from '../services/AgentService';
import { TelemetryService, type TelemetryProperties } from '../services/TelemetryService';
import { Logger } from '../Utils/Logger';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppDialogActions } from '../ui/base/AppDialogActions';
import { AppButton } from '../ui/base/AppButton';
import { AppIcon } from '../ui/base/AppIcon';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { ACTION_CHIP_HEIGHT, BUTTON_HEIGHT_LG, BUTTON_HEIGHT_MD, BUTTON_HEIGHT_SM, CHECKBOX_SIZE_SM, REMINDER_CARD_HEIGHT } from '../foundation/tokens/ComponentSizeTokens';
import { STATS_CONTENT_MAX_WIDTH } from '../foundation/tokens/PageDensityTokens';
import { ICON_SIZE_LG, ICON_SIZE_MD, ICON_SIZE_XL, ICON_SIZE_XS } from '../foundation/tokens/IconTokens';
import { PAGE_PADDING, PANEL_GAP, SECTION_GAP, SPACE_2XS, SPACE_CARD, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_HERO_TITLE, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { MOTION_CURVE_STANDARD, MOTION_DURATION_BASE, MOTION_SHIFT_ENTER_Y } from '../foundation/tokens/MotionTokens';

interface ReminderCreateParams {
  goalId: string;
  krId?: string;
}

@Entry
@Component
struct GoalDetailPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State goal: Goal | null = null;
  @State showAddKR: boolean = false;
  @State newKRTitle: string = '';
  @State newKRTargetValue: string = '100';
  @State newKRInitialValue: string = '0';
  @State showEditKR: boolean = false;
  @State editKRTitle: string = '';
  @State editKRTargetValue: string = '';
  @State editKRInitialValue: string = '';
  @State showUpdateKR: boolean = false;
  @State updateKRCurrentValue: string = '';
  @State showDeleteConfirm: boolean = false;
  @State showTaskActionOverlay: boolean = false;
  @State selectedTaskForAction: Task | null = null;
  @State showDeleteTaskConfirm: boolean = false;
  @State refreshFlag: number = 0; // 用于强制触发 UI 更新
  @State activeInfoTab: 'reminders' | 'tasks' = 'reminders';
  private editingKRId: string = '';
  private goalId: string = '';
  @State tasks: Task[] = [];
  @State filteredTasks: Task[] = [];
  @State reminders: DayEvent[] = [];
  private returnToMainOnBack: boolean = false;
  private taskMap: Map<string, Task> = new Map();
  private logger: Logger = Logger.create('GoalDetailPage');


  
  
  private dataChangeListener: () => void = () => {
    try {
      this.refreshFlag++;
      this.loadGoalData();
    } catch (error) {
      this.logger.error('GoalDetailPage listener error', error as Object);
    }
  };

  aboutToAppear(): void {
    let params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    this.goalId = params['goalId'] || '';
    this.returnToMainOnBack = params['returnToMainOnBack'] === 'true';
    // 注册全局状态监听器
    dataSyncService.addListener(this.dataChangeListener);
    db.onDataChanged(this.dataChangeListener);
    this.loadGoalData();
  }
  
  aboutToDisappear(): void {
    // 移除全局状态监听器
    dataSyncService.removeListener(this.dataChangeListener);
    db.offDataChanged(this.dataChangeListener);
  }
  
  onPageShow(): void {
    this.loadGoalData();
    let breakdownResult = AppStorage.get<GoalBreakdownResult>('aiBreakdownResult');
    if (breakdownResult) {
      this.performAiBreakdownSync(breakdownResult);
      AppStorage.delete('aiBreakdownResult');
    }
  }

  async performAiBreakdownSync(result: GoalBreakdownResult) {
    if (!this.goal) return;
    
    let needsUpdate = false;
    if (result.objective && result.objective !== this.goal.title) {
      this.goal.title = result.objective;
      needsUpdate = true;
    }
    
    if (result.keyResults && result.keyResults.length > 0) {
      result.keyResults.forEach(kr => {
        const newKR = new KeyResult(kr.title, kr.targetValue);
        this.goal!.keyResults.push(newKR);
        
        if (kr.tasks && kr.tasks.length > 0) {
          kr.tasks.forEach(async taskTitle => {
            const newTask = new Task(taskTitle, this.goal!.id, this.goal!.title, this.goal!.category);
            newTask.krId = newKR.id;
            newTask.aiGenerated = true;
            await db.addTask(newTask);
            dataSyncService.setTasks([...dataSyncService.getTasks(), newTask]);
          });
        }
      });
      needsUpdate = true;
    }
    
    if (needsUpdate) {
      this.goal.updatedAt = Date.now();
      dataSyncService.updateGoal(this.goal);
      await db.updateGoal(this.goal);
      this.refreshFlag++;
      this.loadGoalData();
      this.getUIContext().getPromptAction().showToast({ message: 'AI 目标拆解应用成功' });
    }
  }

  private getCategoryAccent(category: GoalCategory): string {
    switch (category) {
      case GoalCategory.HEALTH:
        return this.themeColors.success;
      case GoalCategory.LEARNING:
        return this.themeColors.primary;
      case GoalCategory.FINANCE:
        return this.themeColors.warning;
      case GoalCategory.FUN:
        return this.themeColors.premium;
      default:
        return this.themeColors.primary;
    }
  }

  private getCategorySurface(category: GoalCategory): string {
    switch (category) {
      case GoalCategory.HEALTH:
        return this.themeColors.successSubtle;
      case GoalCategory.LEARNING:
        return this.themeColors.primarySubtle;
      case GoalCategory.FINANCE:
        return this.themeColors.warningSubtle;
      case GoalCategory.FUN:
        return this.themeColors.premiumSurface;
      default:
        return this.themeColors.primarySubtle;
    }
  }
  
  loadGoalData(): void {
    const allGoals = db.getAllGoals();
    const allTasks = db.getAllTasks();
    const allReminders = db.getAllDayEvents();

    const goalData = allGoals.find(g => g.id === this.goalId);

    if (goalData) {
      this.goal = goalData;
    } else {
      this.goal = null;
    }

    this.tasks = Array.from(allTasks);
    this.filteredTasks = this.tasks.filter(t => t.goalId === this.goalId);
    this.reminders = allReminders.filter((event: DayEvent) => event.goalId === this.goalId);
    this.taskMap.clear();
    for (const t of this.tasks) {
      this.taskMap.set(t.id, t);
    }
  }

  getCurrentTask(task: Task): Task {
    const current = this.taskMap.get(task.id);
    return current ? current : task;
  }

  isArchivedGoal(): boolean {
    return this.goal?.isArchived === true;
  }

  showArchivedToast(): void {
    this.getUIContext().getPromptAction().showToast({ message: '已归档目标仅支持查看' });
  }
  
  editGoal(): void {
    if (!this.goal) {
      return;
    }
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/EditGoalPage',
      params: {
        goalId: this.goal.id,
        category: this.goal.category,
        categoryTitle: this.goal.category,
        categoryColor: this.themeColors.primary,
        goalTitle: this.goal.title,
        goalDescription: this.goal.description || '',
        isPriority: this.goal.isPriority || false
      }
    });
  }
  
  createTaskForGoal(): void {
    if (!this.goal) {
      return;
    }
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/CreateTaskPage',
      params: {
        goalId: this.goal.id,
        goalTitle: this.goal.title
      }
    });
  }

  openGoalReschedule(): void {
    if (!this.goal) {
      return;
    }
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }

    this.getUIContext().getRouter().pushUrl({
      url: 'pages/GoalReschedulePage',
      params: {
        goalId: this.goal.id
      }
    });
  }
  
  getKRTaskCount(krId: string): string {
    const krTasks = this.tasks.filter((t: Task) => t.krId === krId);
    const incompleteCount = krTasks.filter((t: Task) => t.status === TaskStatus.PENDING).length;
    const totalCount = krTasks.length;
    return `${incompleteCount}/${totalCount}`;
  }
  
  build() {
    Column() {
      AppPageHeader({
        title: this.goal?.title || '目标详情',
        subtitle: '查看目标进度、关键结果、提醒与任务。',
        actionText: this.isArchivedGoal() ? '' : '编辑',
        actionIconName: 'note',
        onBack: () => {
          if (this.returnToMainOnBack) {
            this.getUIContext().getRouter().replaceUrl({ url: 'pages/MainPage' });
            return;
          }
          this.getUIContext().getRouter().back();
        },
        onAction: () => {
          this.editGoal();
        }
      })

      if (this.goal && this.refreshFlag >= 0) {
        Scroll() {
          Column({ space: SECTION_GAP }) {
            this.TargetInfoCard()
            this.StatsRow()
            this.KRList()
            this.RelatedContentSection()
            Blank().height(SPACE_MD)
          }
          .width('100%')
          .constraintSize({ maxWidth: STATS_CONTENT_MAX_WIDTH })
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 4, bottom: PAGE_PADDING + 68 })
        }
        .layoutWeight(1)
        .backgroundColor(this.themeColors.background)
        .scrollBar(BarState.Off)
      } else {
        Scroll() {
          Column() {
            AppEmptyState({
              iconName: 'warning',
              iconTone: 'warning',
              title: '未找到目标',
              description: '当前目标可能已被删除、归档或尚未同步到本地。',
              actionText: '返回首页',
              actionIconName: 'today',
              onAction: () => {
                this.getUIContext().getRouter().replaceUrl({ url: 'pages/MainPage' });
              }
            })
          }
          .width('100%')
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 16, bottom: PAGE_PADDING })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      if (this.showAddKR) this.AddKRDialog()
      if (this.showEditKR) this.EditKRDialog()
      if (this.showUpdateKR) this.UpdateKRDialog()
      if (this.showDeleteConfirm) this.DeleteConfirmDialog()
      if (this.showDeleteTaskConfirm) this.DeleteTaskConfirmDialog()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .onClick(() => {
      if (this.showTaskActionOverlay) {
        this.hideTaskActions();
      }
    })
  }

  @Builder
  StatsRow() {
    Row() {
      // 关键结果统计
      this.StatCard(
        '衡量标准',
        'plan',
        `${this.goal?.keyResults.filter(k => k.progress >= 100).length || 0}/${this.goal?.keyResults.length || 0}`,
        '已完成'
      )

      // 关联任务统计
      this.StatCard(
        '关联任务',
        'task',
        `${this.tasks.filter(t => t.goalId === this.goalId && t.status === TaskStatus.COMPLETED).length}/${this.tasks.filter(t => t.goalId === this.goalId).length}`,
        '已完成'
      )
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .margin({ bottom: SPACE_MD })
  }

  @Builder
  StatCard(title: string, icon: string, value: string, subtext: string) {
    Column() {
      Row() {
        AppIcon({ name: icon, iconSize: ICON_SIZE_MD, framed: false })
          .margin({ right: SPACE_2XS })
        Text(title).fontSize(TYPE_META).fontColor(this.themeColors.textSecondary)
      }
      .margin({ bottom: SPACE_SM })

      Text(value)
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.primary)
        .margin({ bottom: SPACE_2XS })

      Text(subtext)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
    }
    .width('48%')
    .padding(SPACE_MD)
    .backgroundColor(this.themeColors.surface)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Center)
    .shadow({
      radius: 6,
      color: this.themeColors.cardShadow,
      offsetX: 0,
      offsetY: 2
    })
  }

  getDirectReminders(): DayEvent[] {
    return this.reminders.filter((event: DayEvent) => !event.krId);
  }

  getKrReminders(krId: string): DayEvent[] {
    return this.reminders.filter((event: DayEvent) => event.krId === krId);
  }

  getReminderCountForKr(krId: string): number {
    return this.getKrReminders(krId).length;
  }

  openReminderEditor(eventId: string): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/DayEventCreatePage',
      params: { eventId }
    });
  }

  createReminderForGoal(krId?: string): void {
    if (!this.goal) {
      return;
    }
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }

    const params: ReminderCreateParams = {
      goalId: this.goal.id
    };
    if (krId) {
      params.krId = krId;
    }

    this.getUIContext().getRouter().pushUrl({
      url: 'pages/DayEventCreatePage',
      params
    });
  }

  @Builder
  RelatedContentSection() {
    Column() {
      Row() {
        Row() {
          this.InfoTabChip('关联提醒', 'reminders', this.reminders.length)
          this.InfoTabChip('全部任务', 'tasks', this.filteredTasks.length)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: PANEL_GAP })

      Row() {
        Blank()

        if (!this.isArchivedGoal()) {
          AppButton({
            text: this.activeInfoTab === 'reminders' ? '＋ 新建提醒' : '＋ 新建代办',
            variant: 'primary',
            buttonSize: 'sm',
            iconName: 'task',
            tapAction: () => {
              if (this.activeInfoTab === 'reminders') {
                this.createReminderForGoal();
              } else {
                this.createTaskForGoal();
              }
            }
          })
        } else {
          Text('只读')
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textMuted)
        }
      }
      .width('100%')
      .margin({ top: SPACE_SM, bottom: SPACE_MD })

      if (this.activeInfoTab === 'reminders') {
        this.ReminderSectionContent()
      } else {
        this.TaskListContent()
      }
    }
    .width('100%')
  }

  @Builder
  InfoTabChip(label: string, tab: 'reminders' | 'tasks', count: number) {
    Row() {
      Row() {
        Text(label)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.activeInfoTab === tab ? this.themeColors.primary : this.themeColors.textPrimary)

        Text(`${count}`)
          .fontSize(TYPE_META)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.activeInfoTab === tab ? this.themeColors.primary : this.themeColors.primary)
          .margin({ left: SPACE_SM })
      }
    }
    .height(ACTION_CHIP_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 10, right: 10 })
    .margin({ right: SPACE_SM })
    .backgroundColor(this.activeInfoTab === tab ? this.themeColors.primarySubtle : this.themeColors.surfaceLight)
    .border({
      width: 1,
      color: this.activeInfoTab === tab ? this.themeColors.primaryLight : this.themeColors.borderColor
    })
    .borderRadius(12)
    .onClick(() => {
      this.activeInfoTab = tab;
    })
  }

  @Builder
  ReminderSectionContent() {
    Column() {
      if (this.reminders.length === 0) {
        Column() {
          AppIcon({ name: 'reminder', iconSize: ICON_SIZE_XL })
            .margin({ bottom: SPACE_SM })

          Text('这个目标下还没有关联提醒')
            .fontSize(TYPE_BODY)
            .fontColor(this.themeColors.textSecondary)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding(SPACE_CARD)
        .backgroundColor(this.themeColors.surface)
        .borderRadius(12)
      } else {
        if (this.getDirectReminders().length > 0) {
          Text('目标提醒')
            .fontSize(TYPE_META)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
            .margin({ bottom: SPACE_SM })

          ForEach(this.getDirectReminders(), (event: DayEvent) => {
            this.ReminderCard(event)
          }, (event: DayEvent) => `${event.id}_${event.updatedAt}`)
        }

        ForEach(this.goal?.keyResults || [], (kr: KeyResult) => {
          if (this.getReminderCountForKr(kr.id) > 0) {
            Column() {
              Row() {
                Text(kr.title)
                  .fontSize(TYPE_META)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.themeColors.textSecondary)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                if (!this.isArchivedGoal()) {
                  AppButton({
                    text: '新建提醒',
                    variant: 'secondary',
                    buttonSize: 'sm',
                    tapAction: () => {
                      this.createReminderForGoal(kr.id);
                    }
                  })
                }
              }
              .width('100%')
              .margin({ top: SPACE_XS, bottom: SPACE_XS })

              ForEach(this.getKrReminders(kr.id), (event: DayEvent) => {
                this.ReminderCard(event)
              }, (event: DayEvent) => `${event.id}_${event.updatedAt}`)
            }
            .width('100%')
          }
        }, (kr: KeyResult) => kr.id)
      }
    }
    .width('100%')
  }

  @Builder
  ReminderCard(event: DayEvent) {
      Column() {
        Row() {
          AppIcon({ name: getEventTypeIcon(event.type), iconSize: ICON_SIZE_LG })

          Column() {
          Row() {
            Text(event.title)
              .fontSize(TYPE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColors.textPrimary)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (isDayEventEnded(event)) {
              Text('已结束')
                .fontSize(TYPE_CAPTION)
                .fontColor(this.themeColors.textMuted)
                .padding({ left: SPACE_SM, right: SPACE_SM, top: SPACE_2XS, bottom: SPACE_2XS })
                .backgroundColor(this.themeColors.surfaceLight)
                .borderRadius(999)
                .margin({ left: SPACE_SM })
            }
          }
          .width('100%')

          Text(getEventTypeLabel(event.type))
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textMuted)
            .width('100%')
            .margin({ top: SPACE_2XS })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: SPACE_SM })

        Text(getDayEventMetricText(event))
          .fontSize(TYPE_META)
          .fontWeight(FontWeight.Medium)
          .fontColor(isDayEventEnded(event) ? this.themeColors.textMuted : this.themeColors.primary)
      }
      .width('100%')

      Text(getDayEventListSummary(event))
        .fontSize(TYPE_META)
        .lineHeight(20)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
        .margin({ top: SPACE_SM })

      if (event.krTitle) {
        Text(`衡量标准：${event.krTitle}`)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.primary)
          .width('100%')
          .margin({ top: SPACE_XS })
      }

      Text(`创建于 ${formatDayEventDate(event.createdAt)}`)
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textMuted)
        .width('100%')
        .margin({ top: SPACE_SM })
    }
    .width('100%')
    .padding(SPACE_MD)
    .backgroundColor(isDayEventEnded(event) ? this.themeColors.surfaceSoft : this.themeColors.surface)
    .borderRadius(12)
    .margin({ bottom: SPACE_SM })
    .shadow({
      radius: 6,
      color: this.themeColors.cardShadow,
      offsetX: 0,
      offsetY: 2
    })
    .onClick(() => {
      this.openReminderEditor(event.id);
    })
  }

  
  @Builder
  TargetInfoCard() {
    Column() {
      // Row 1: Category Badge | Spacer | Start Date
      Row() {
          Row() {
            AppIcon({
              name: CATEGORIES.find((c) => c.value === this.goal!.category)?.icon || '',
              iconSize: ICON_SIZE_LG,
              framed: false,
              color: this.getCategoryAccent(this.goal!.category)
            })
              .margin({ right: SPACE_2XS })
            Text(this.goal!.category)
            .fontSize(TYPE_META)
            .fontColor(this.getCategoryAccent(this.goal!.category))
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        .backgroundColor(this.getCategorySurface(this.goal!.category))
        .borderRadius(12)

        if (this.goal!.isPriority) {
          Row() {
            Text('优先')
              .fontSize(TYPE_META)
              .fontColor(this.themeColors.textOnPrimary)
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 8, right: 8, top: 5, bottom: 5 })
          .backgroundColor(this.themeColors.warning)
          .borderRadius(12)
          .margin({ left: SPACE_XS })
        }

        Blank()

        Text(`开始: ${this.formatDate(this.goal!.startDate)}`)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: SPACE_MD })

      // Row 2: Title
      Text(this.goal!.title)
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .margin({ bottom: SPACE_MD })
        .width('100%')

      if (this.goal!.description) {
        Text(this.goal!.description)
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
          .lineHeight(18)
          .margin({ bottom: SPACE_MD })
      }

      // Row 3: Progress Label | Percentage
      Row() {
        Text('整体进度(衡量标准进度的平均值)')
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)

        Blank()

        Text(`${this.goal!.progress}%`)
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.warning)
      }
      .width('100%')
      .margin({ bottom: SPACE_SM })

      // Row 4: Progress Bar
      Progress({ value: this.goal!.progress, total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(SPACE_XS)
        .color(this.themeColors.warning)
        .backgroundColor(this.themeColors.surfaceLight)
        .style({ strokeWidth: 6, enableSmoothEffect: true })

    }
    .width('100%')
    .padding(SPACE_MD)
    .backgroundColor(this.themeColors.surface)
    .borderRadius(12)
    .shadow({ radius: 8, color: this.themeColors.cardShadow, offsetY: 3 })
    .margin({ bottom: SPACE_MD })
  }
  
  @Builder
  KRList() {
    Column() {
      Row() {
        Text('衡量标准')
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)

        Text(`(${this.goal!.keyResults.length})`)
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textSecondary)
          .margin({ left: SPACE_SM })

        Blank()

        if (!this.isArchivedGoal()) {

        AppButton({
          text: '添加',
          variant: 'primary',
          buttonSize: 'sm',
          tapAction: () => {
            this.showAddKR = true;
          }
        })
        } else {
          Text('只读')
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textMuted)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: SPACE_MD })
      
      if (this.goal!.keyResults.length === 0) {
        Column() {
          AppIcon({ name: 'plan', iconSize: ICON_SIZE_XL })
            .margin({ bottom: SPACE_SM })
          
          Text('还没有衡量标准')
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textMuted)
          
          Text('点击下方按钮添加第一个衡量标准')
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
            .margin({ top: SPACE_2XS })

          if (!this.isArchivedGoal()) {
            AppButton({
              text: 'AI 补齐追踪和行动',
              variant: 'secondary',
              buttonSize: 'sm',
              iconName: 'ai',
              tapAction: () => {
                this.getUIContext().getRouter().pushUrl({
                  url: 'pages/GoalBreakdownPage',
                  params: {
                    intent: this.goal?.title + (this.goal?.description ? '\n' + this.goal?.description : ''),
                    source: 'enhance_goal',
                    targetGoalId: this.goal?.id || ''
                  }
                });
              }
            })
              .margin({ top: SPACE_SM })
          }
        }
        .width('100%')
        .padding(SPACE_CARD)
      } else {
        ForEach(this.goal!.keyResults, (kr: KeyResult) => {
          this.KRItem(kr)
        }, (kr: KeyResult) => kr.id)
      }
    }
    .width('100%')
  }
  
  @Builder
  KRItem(kr: KeyResult) {
    Column() {
      // Header Row: Title & Update Button
      Row() {
        Text(kr.title)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ right: SPACE_SM })

        if (!this.isArchivedGoal()) {

        AppButton({
          text: '更新',
          variant: 'primary',
          buttonSize: 'sm',
          tapAction: () => {
            this.showUpdateKRDialog(kr);
          }
        })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .margin({ bottom: SPACE_MD })
      
      // Values Row
      Row() {
        Text(`目标值: ${kr.targetValue}`)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
          .margin({ right: SPACE_CARD })
        
        Text(`当前值: ${kr.currentValue}`)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
          .margin({ right: SPACE_CARD })
        
        Text(`初始值: ${kr.initialValue}`)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
      }
      .width('100%')
      .margin({ bottom: SPACE_MD })
      
      // Status Row
      Row() {
        Text(`完成度: ${Math.round(kr.progress)}%`)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.warning) // Yellow
        
        Blank()
        
        Text(`关联任务: ${this.getKRTaskCount(kr.id)}`)
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.textSecondary)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(SPACE_MD)
    .backgroundColor(this.themeColors.surface)
    .borderRadius(12)
    .margin({ bottom: SPACE_SM })
    .shadow({
      radius: 6,
      color: this.themeColors.cardShadow,
      offsetX: 0,
      offsetY: 2
    })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          this.showKRContextMenu(kr);
        })
    )
  }
  
  @Builder
  AddKRDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeColors.surfaceOverlay)
        .onClick(() => {
          this.showAddKR = false;
          this.newKRTitle = '';
          this.newKRTargetValue = '100';
          this.newKRInitialValue = '0';
        })
      
      Column() {
        Text('添加衡量标准')
          .fontSize(TYPE_HERO_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .margin({ bottom: SECTION_GAP })
        
        Text('衡量标准名称')
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
          .margin({ bottom: SPACE_SM })
        
        TextInput({ placeholder: '例如：每周运动 3 次，每次 30 分钟', text: this.newKRTitle })
          .width('100%')
          .height(BUTTON_HEIGHT_LG)
          .fontSize(TYPE_BODY)
          .padding(SPACE_MD)
          .backgroundColor(this.themeColors.inputBackground)
          .borderRadius(8)
          .onChange((value: string) => {
            this.newKRTitle = value;
          })
        
        Row() {
          Column() {
            Text('目标值')
              .fontSize(TYPE_BODY)
              .fontColor(this.themeColors.textSecondary)
              .width('100%')
              .margin({ bottom: SPACE_SM })
            
            TextInput({ text: this.newKRTargetValue })
              .width('100%')
              .height(BUTTON_HEIGHT_LG)
              .fontSize(TYPE_BODY)
              .type(InputType.Number)
              .padding(SPACE_SM)
              .backgroundColor(this.themeColors.inputBackground)
              .borderRadius(8)
              .onChange((value: string) => {
                this.newKRTargetValue = value;
              })
          }
          .layoutWeight(1)
          
          Column() {
            Text('初始值（可选）')
              .fontSize(TYPE_BODY)
              .fontColor(this.themeColors.textSecondary)
              .width('100%')
              .margin({ bottom: SPACE_SM })
            
            TextInput({ text: this.newKRInitialValue })
              .width('100%')
              .height(BUTTON_HEIGHT_LG)
              .fontSize(TYPE_BODY)
              .type(InputType.Number)
              .padding(SPACE_SM)
              .backgroundColor(this.themeColors.inputBackground)
              .borderRadius(8)
              .onChange((value: string) => {
                this.newKRInitialValue = value;
              })
          }
          .layoutWeight(1)
          .margin({ left: SPACE_MD })
        }
        .width('100%')
        .margin({ top: SPACE_CARD })

        // 完成度计算公式提示
        Row() {
          AppIcon({ name: 'idea', iconSize: ICON_SIZE_MD, framed: false })
            .margin({ right: SPACE_XS })
          Text('完成度 = (当前值 - 初始值) / (目标值 - 初始值) × 100%')
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
        }
        .width('100%')
        .padding(SPACE_MD)
        .backgroundColor(this.themeColors.surfaceLight)
        .borderRadius(8)
        .margin({ top: SPACE_CARD })

        AppDialogActions({
          primaryText: '添加',
          primaryDisabled: this.newKRTitle.trim() === '',
          onSecondary: () => {
            this.showAddKR = false;
            this.newKRTitle = '';
            this.newKRTargetValue = '100';
            this.newKRInitialValue = '0';
          },
          onPrimary: () => {
            this.addKR();
          }
        })
        .margin({ top: SPACE_CARD })
      }
      .width('88%')
      .padding(SPACE_CARD)
      .backgroundColor(this.themeColors.cardBackground)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(999)
  }

  @Builder
  EditKRDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeColors.surfaceOverlay)
        .onClick(() => {
          this.showEditKR = false;
          this.editKRTitle = '';
          this.editKRTargetValue = '';
          this.editKRInitialValue = '';
        })
      
      Column() {
        Text('编辑衡量标准')
          .fontSize(TYPE_HERO_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .margin({ bottom: SECTION_GAP })
        
        Text('衡量标准名称')
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
          .margin({ bottom: SPACE_SM })
        
        TextInput({ placeholder: '输入衡量标准标题', text: this.editKRTitle })
          .width('100%')
          .height(BUTTON_HEIGHT_LG)
          .fontSize(TYPE_BODY)
          .padding(SPACE_MD)
          .backgroundColor(this.themeColors.inputBackground)
          .borderRadius(8)
          .onChange((value: string) => {
            this.editKRTitle = value;
          })
        
        Row() {
          Column() {
            Text('目标值')
              .fontSize(TYPE_BODY)
              .fontColor(this.themeColors.textSecondary)
              .width('100%')
              .margin({ bottom: SPACE_SM })
            
            TextInput({ text: this.editKRTargetValue })
              .width('100%')
              .height(BUTTON_HEIGHT_LG)
              .fontSize(TYPE_BODY)
              .type(InputType.Number)
              .padding(SPACE_SM)
              .backgroundColor(this.themeColors.inputBackground)
              .borderRadius(8)
              .onChange((value: string) => {
                this.editKRTargetValue = value;
              })
          }
          .layoutWeight(1)
          
          Column() {
            Text('初始值')
              .fontSize(TYPE_BODY)
              .fontColor(this.themeColors.textSecondary)
              .width('100%')
              .margin({ bottom: SPACE_SM })
            
            TextInput({ text: this.editKRInitialValue })
              .width('100%')
              .height(BUTTON_HEIGHT_LG)
              .fontSize(TYPE_BODY)
              .type(InputType.Number)
              .padding(SPACE_SM)
              .backgroundColor(this.themeColors.inputBackground)
              .borderRadius(8)
              .onChange((value: string) => {
                this.editKRInitialValue = value;
              })
          }
          .layoutWeight(1)
          .margin({ left: SPACE_MD })
        }
        .width('100%')
        .margin({ top: SPACE_CARD })

        AppDialogActions({
          primaryText: '保存',
          primaryDisabled: this.editKRTitle.trim() === '',
          onSecondary: () => {
            this.showEditKR = false;
            this.editKRTitle = '';
            this.editKRTargetValue = '';
            this.editKRInitialValue = '';
          },
          onPrimary: () => {
            this.saveKREdit();
          }
        })
        .margin({ top: SPACE_CARD })
      }
      .width('88%')
      .padding(SPACE_CARD)
      .backgroundColor(this.themeColors.cardBackground)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(999)
  }
  
  addKR() {
    if (!this.goal) {
      return;
    }
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    if (this.newKRTitle.trim().length === 0) {
      return;
    }
    const targetValue = parseFloat(this.newKRTargetValue) || 100;
    const initialValue = parseFloat(this.newKRInitialValue) || 0;
    const newKR = new KeyResult(this.newKRTitle.trim(), targetValue, initialValue);
    newKR.updateProgress();
    this.logger.debug('addKR: created new KR', newKR.id, 'title:', newKR.title, 'target:', newKR.targetValue, 'initial:', newKR.initialValue, 'progress:', newKR.progress);
    if (!this.goal.keyResults) {
      this.goal.keyResults = [];
    }
    this.goal.keyResults.push(newKR);
    this.goal.updateProgress();
    this.logger.debug('addKR: goal progress updated to', this.goal.progress, 'keyResults count:', this.goal.keyResults.length);
    // 验证关键结果数组
    this.logger.debug('addKR: goal.keyResults length:', this.goal.keyResults?.length);
    if (this.goal.keyResults && this.goal.keyResults.length > 0) {
      this.goal.keyResults.forEach((kr, index) => {
        this.logger.debug(`  KR[${index}]: id=${kr.id}, title=${kr.title}, progress=${kr.progress}`);
      });
    }
    this.newKRTitle = '';
    this.newKRTargetValue = '100';
    this.newKRInitialValue = '0';
    this.showAddKR = false;

    // 强制本地UI更新
    this.refreshFlag++;
    
    // 立即更新全局状态以触发其他页面的 UI 刷新
    this.logger.debug('addKR: calling dataSyncService.updateGoal');
    try {
      dataSyncService.updateGoal(this.goal);
      this.logger.debug('addKR: dataSyncService.updateGoal called successfully');
    } catch (error) {
      this.logger.error('addKR: failed to call dataSyncService.updateGoal', error as Object);
    }
    
    // 异步保存到数据库
    db.updateGoal(this.goal).catch((err: Error) => {
      this.logger.error('addKR: db.updateGoal failed', err as Object);
    });
  }

  showEditKRDialog(kr: KeyResult): void {
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    this.editingKRId = kr.id;
    this.editKRTitle = kr.title;
    this.editKRTargetValue = kr.targetValue.toString();
    this.editKRInitialValue = kr.initialValue.toString();
    this.showEditKR = true;
  }
  
  saveKREdit(): void {
    if (!this.goal || this.editKRTitle.trim() === '') {
      return;
    }
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    
    const kr = this.goal.keyResults.find((k: KeyResult) => k.id === this.editingKRId);
    if (kr) {
      kr.title = this.editKRTitle.trim();
      kr.targetValue = parseFloat(this.editKRTargetValue) || kr.targetValue;
      kr.initialValue = parseFloat(this.editKRInitialValue) || kr.initialValue;
      kr.updateProgress();
      this.goal.updateProgress();
      this.logger.debug('saveKREdit: goal progress updated to', this.goal.progress);
      
      // 强制本地UI更新
      this.refreshFlag++;
      
      // 立即更新全局状态以触发其他页面的 UI 刷新
      this.logger.debug('saveKREdit: calling dataSyncService.updateGoal');
      try {
        dataSyncService.updateGoal(this.goal);
        this.logger.debug('saveKREdit: dataSyncService.updateGoal called successfully');
      } catch (error) {
        this.logger.error('saveKREdit: failed to call dataSyncService.updateGoal', error as Object);
      }
      
      db.updateGoal(this.goal).catch((err: Error) => {
        this.logger.error('saveKREdit: db.updateGoal failed', err as Object);
      });
      this.showEditKR = false;
      this.editKRTitle = '';
      this.editKRTargetValue = '';
      this.editKRInitialValue = '';
      this.editingKRId = '';
    }
  }
  
  showUpdateKRDialog(kr: KeyResult): void {
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    this.editingKRId = kr.id;
    this.updateKRCurrentValue = kr.currentValue.toString();
    this.showUpdateKR = true;
  }
  
  saveKRCurrentValue(): void {
    if (!this.goal) {
      return;
    }
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    const kr = this.goal.keyResults.find((k: KeyResult) => k.id === this.editingKRId);
    if (kr) {
      kr.currentValue = parseFloat(this.updateKRCurrentValue) || kr.currentValue;
      kr.updateProgress();
      this.goal.updateProgress();
      this.logger.debug('saveKRCurrentValue: goal progress updated to', this.goal.progress);
      
      // 强制本地UI更新
      this.refreshFlag++;
      
      // 立即更新全局状态以触发其他页面的 UI 刷新
      this.logger.debug('saveKRCurrentValue: calling dataSyncService.updateGoal');
      try {
        dataSyncService.updateGoal(this.goal);
        this.logger.debug('saveKRCurrentValue: dataSyncService.updateGoal called successfully');
      } catch (error) {
        this.logger.error('saveKRCurrentValue: failed to call dataSyncService.updateGoal', error as Object);
      }
      
      db.updateGoal(this.goal).catch((err: Error) => {
        this.logger.error('saveKRCurrentValue: db.updateGoal failed', err as Object);
      });
      this.showUpdateKR = false;
      this.updateKRCurrentValue = '';
      this.editingKRId = '';
    }
  }
  
  showKRContextMenu(kr: KeyResult): void {
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    this.editingKRId = kr.id;
    this.getUIContext().showAlertDialog({
      title: '衡量标准操作',
      message: '请选择要执行的操作',
      buttons: [
        {
          value: '编辑',
          action: () => {
            this.showEditKRDialog(kr);
          }
        },
        {
          value: '删除',
          action: () => {
            this.showDeleteConfirm = true;
          }
        },
        {
          value: '取消',
          action: () => {}
        }
      ]
    });
  }
  
  formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    return `${year}-${month.toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}`;
  }

  getPriorityText(priority: string): string {
    switch (priority) {
      case 'high': return '优先';
      case 'normal': return '普通';
      case 'low': return '暂缓';
      default: return '普通';
    }
  }

  getPriorityColor(priority: string): string {
    return this.themeColors.textOnPrimary;
  }

  getPriorityBgColor(priority: string): string {
    switch (priority) {
      case 'high': return this.themeColors.danger;
      case 'normal': return this.themeColors.primary;
      case 'low': return this.themeColors.textSecondary;
      default: return this.themeColors.textSecondary;
    }
  }
  toggleTaskPinned(task: Task): void {
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    const currentTask = this.getCurrentTask(task);
    currentTask.isPinned = !currentTask.isPinned;
    currentTask.updatedAt = Date.now();
    // 立即更新全局状态以触发 UI 刷新
    db.updateTask(currentTask);
    this.hideTaskActions();
  }

  deleteKR(krId: string): void {
    if (!this.goal) {
      return;
    }
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    this.tasks.forEach((task: Task) => {
      if (task.krId === krId) {
        task.krId = undefined;
        task.krTitle = undefined;
        db.updateTask(task);
      }
    });
    this.goal.keyResults = this.goal.keyResults.filter((kr: KeyResult) => kr.id !== krId);
    this.goal.updateProgress();
    this.logger.debug('deleteKR: goal progress updated to', this.goal.progress);
    
    // 强制本地UI更新
    this.refreshFlag++;
    
    // 立即更新全局状态以触发其他页面的 UI 刷新
    this.logger.debug('deleteKR: calling dataSyncService.updateGoal');
    try {
      dataSyncService.updateGoal(this.goal);
      this.logger.debug('deleteKR: dataSyncService.updateGoal called successfully');
    } catch (error) {
      this.logger.error('deleteKR: failed to call dataSyncService.updateGoal', error as Object);
    }
    
    Promise.all([
      db.updateGoal(this.goal),
      db.unlinkDayEventsFromKeyResult(this.goalId, krId)
    ]).then(() => {
      this.goal = db.getGoalById(this.goalId) || null;
      this.tasks = [...db.getAllTasks()];
      this.filteredTasks = this.tasks.filter(t => t.goalId === this.goalId);
      this.reminders = [...db.getDayEventsByGoalId(this.goalId)];
      this.showDeleteConfirm = false;
      this.editingKRId = '';
    });
  }
  
  @Builder
  UpdateKRDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeColors.surfaceOverlay)
        .onClick(() => {
          this.showUpdateKR = false;
          this.updateKRCurrentValue = '';
        })
      
      Column() {
        Text('更新当前值')
          .fontSize(TYPE_HERO_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .margin({ bottom: SECTION_GAP })
        
        Text('请输入新的当前值')
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
          .margin({ bottom: SPACE_SM })
        
        TextInput({ text: this.updateKRCurrentValue })
          .width('100%')
          .height(BUTTON_HEIGHT_LG)
          .fontSize(TYPE_BODY)
          .type(InputType.Number)
          .padding(SPACE_SM)
          .backgroundColor(this.themeColors.inputBackground)
          .borderRadius(8)
          .onChange((value: string) => {
            this.updateKRCurrentValue = value;
          })

        AppDialogActions({
          primaryText: '确认',
          onSecondary: () => {
            this.showUpdateKR = false;
            this.updateKRCurrentValue = '';
          },
          onPrimary: () => {
            this.saveKRCurrentValue();
          }
        })
        .margin({ top: SPACE_CARD })
      }
      .width('88%')
      .padding(SPACE_CARD)
      .backgroundColor(this.themeColors.cardBackground)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(999)
  }
  
  @Builder
  DeleteConfirmDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeColors.surfaceOverlay)
        .onClick(() => {
          this.showDeleteConfirm = false;
          this.editingKRId = '';
        })
      
      Column() {
        Text('确认删除')
          .fontSize(TYPE_HERO_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .margin({ bottom: SPACE_CARD })
        
        Text('是否删除该衡量标准？删除后关联的行动将改为与目标直接关联。')
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
          .lineHeight(18)
          .margin({ bottom: SECTION_GAP })

        AppDialogActions({
          primaryText: '删除',
          primaryVariant: 'danger',
          onSecondary: () => {
            this.showDeleteConfirm = false;
            this.editingKRId = '';
          },
          onPrimary: () => {
            this.deleteKR(this.editingKRId);
          }
        })
      }
      .width('88%')
      .padding(SPACE_CARD)
      .backgroundColor(this.themeColors.cardBackground)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(999)
  }

  // 任务操作方法
  showTaskActions(task: Task): void {
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    this.selectedTaskForAction = this.getCurrentTask(task);
    this.showTaskActionOverlay = true;
  }

  hideTaskActions(): void {
    this.showTaskActionOverlay = false;
    this.selectedTaskForAction = null;
  }

  editSelectedTask(): void {
    if (!this.selectedTaskForAction) return;
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    const task = this.selectedTaskForAction;
    this.hideTaskActions();
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/CreateTaskPage',
      params: { taskId: task.id }
    });
  }

  deleteSelectedTask(): void {
    if (!this.selectedTaskForAction) return;
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    const taskId = this.selectedTaskForAction.id;
    // 立即从全局状态中移除任务以触发 UI 刷新
    const currentTasks = dataSyncService.getTasks();
    const updatedTasks = currentTasks.filter(t => t.id !== taskId);
    dataSyncService.setTasks(updatedTasks);
    
    db.deleteTask(taskId).then(() => {
      this.tasks = [...db.getAllTasks()];
      this.goal = db.getGoalById(this.goalId) || null;
      this.filteredTasks = this.tasks.filter(t => t.goalId === this.goalId);
    });
    this.hideTaskActions();
    this.showDeleteTaskConfirm = false;
  }
  completeTask(task: Task): void {
    if (this.isArchivedGoal()) {
      this.showArchivedToast();
      return;
    }
    // 从 this.tasks 中找到对应的任务索引
    const currentTask = this.getCurrentTask(task);
    const taskIndex = this.tasks.findIndex(t => t.id === currentTask.id);
    if (taskIndex === -1) return;
    
    // 切换任务状态
    const willComplete = currentTask.status !== TaskStatus.COMPLETED;
    db.setTaskCompletion(currentTask.id, willComplete);
    if (willComplete) {
      (() => {
        const now = new Date();
        now.setHours(0, 0, 0, 0);
        let completedProps: TelemetryProperties = {
          "isToday": currentTask.dueDate !== undefined && currentTask.dueDate >= now.getTime() &&
            currentTask.dueDate < now.getTime() + 24 * 60 * 60 * 1000
        };
        TelemetryService.track('task_completed', completedProps, 'task');
      })();
    }
  }

  @Builder
  TaskListContent() {
    Column() {
      if (this.filteredTasks.length === 0) {
        Column() {
          AppIcon({ name: 'task', iconSize: ICON_SIZE_XL })
            .margin({ bottom: SPACE_MD })
          
          Text('该目标下暂无任务')
            .fontSize(TYPE_BODY)
            .fontColor(this.themeColors.textSecondary)
        }
        .width('100%')
        .padding(SECTION_GAP)
        .alignItems(HorizontalAlign.Center)
      } else {
        ForEach(this.filteredTasks, (task: Task, index: number) => {
          this.TaskItem(task, index)
        }, (task: Task, index: number) => `${task.id}_${task.updatedAt}`)
      }
    }
    .width('100%')
  }
  @Builder
  TaskItem(task: Task, index: number) {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        // 完成/取消完成按钮
        Stack({ alignContent: Alignment.Center }) {
          if (this.getCurrentTask(task).status === 'completed') {
            AppIcon({ name: 'success', iconSize: ICON_SIZE_XS, framed: false, color: this.themeColors.success })
          }
        }
        .width(ACTION_CHIP_HEIGHT)
        .height(ACTION_CHIP_HEIGHT)
        .borderRadius(12)
        .border({
          width: 1.5,
          color: this.getCurrentTask(task).status === 'completed' ? this.themeColors.success : this.themeColors.borderColor
        })
        .backgroundColor(this.isArchivedGoal() ? this.themeColors.surfaceSoft : this.themeColors.transparent)
        .enabled(!this.isArchivedGoal())
        .onClick(() => {
          this.completeTask(task);
        })
        // 任务信息
        Column() {
          Text(this.getCurrentTask(task).title)
            .fontSize(TYPE_BODY)
            .fontColor(this.getCurrentTask(task).status === 'completed' ? this.themeColors.textMuted : this.themeColors.textPrimary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .decoration({ type: this.getCurrentTask(task).status === 'completed' ? TextDecorationType.LineThrough : TextDecorationType.None })
          Row() {
            Text(this.getCurrentTask(task).description || '')
              .fontSize(TYPE_META)
              .fontColor(this.themeColors.textSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: SPACE_2XS })
          // 关联目标和番茄
          if (this.getCurrentTask(task).goalTitle || this.getCurrentTask(task).pomodoroCount > 0) {
            Row() {
              if (this.getCurrentTask(task).goalTitle) {
                Text(this.getCurrentTask(task).goalTitle)
                  .fontSize(TYPE_CAPTION)
                  .fontColor(this.themeColors.primary)
                  .backgroundColor(this.themeColors.primarySubtle)
                  .padding({ left: SPACE_XS, right: SPACE_XS, top: SPACE_2XS, bottom: SPACE_2XS })
                  .borderRadius(4)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              
              // 番茄图标显示（最多 3 个）
              if (this.getCurrentTask(task).pomodoroCount > 0) {
                Row() {
                ForEach(Array.from({length: Math.min(this.getCurrentTask(task).pomodoroCount, 3)}), (_t: undefined, index: number) => {
                    AppIcon({
                      name: 'tomato',
                      iconSize: ICON_SIZE_XS,
                      tone: 'warning',
                      framed: false,
                      useSystemSymbol: false
                    })
                      .margin({ left: SPACE_2XS })
                  })
                }
                .margin({ left: SPACE_SM })
              }
            }
            .width('100%')
            .margin({ top: SPACE_2XS })
          }
        }
        .layoutWeight(1)
        .margin({ left: SPACE_MD })
        .alignItems(HorizontalAlign.Start)
        // 右侧信息：截止日期和优先级
        Column() {
          Row() {
            if (this.getCurrentTask(task).isOverdue) {
              Text('逾期')
                .fontSize(TYPE_CAPTION)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.themeColors.textOnPrimary)
                .padding({ left: SPACE_2XS, right: SPACE_2XS, top: SPACE_2XS, bottom: SPACE_2XS })
                .borderRadius(4)
                .backgroundColor(this.themeColors.danger)
                .margin({ right: SPACE_2XS })
            }

            Text(this.getPriorityText(this.getCurrentTask(task).priority))
              .fontSize(TYPE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getPriorityColor(this.getCurrentTask(task).priority))
              .padding({ left: SPACE_XS, right: SPACE_XS, top: SPACE_2XS, bottom: SPACE_2XS })
              .borderRadius(6)
              .backgroundColor(this.getPriorityBgColor(this.getCurrentTask(task).priority))
          }
          .alignSelf(ItemAlign.End)
          
          if (this.getCurrentTask(task).dueDate) {
            Text(this.formatDate(this.getCurrentTask(task).dueDate || 0) + (this.getCurrentTask(task).dueTime ? ` ${this.getCurrentTask(task).dueTime}` : ''))
              .fontSize(TYPE_CAPTION)
              .fontColor(
                this.getCurrentTask(task).isOverdue
                  ? this.themeColors.danger 
                  : this.themeColors.textMuted
              )
              .margin({ top: SPACE_2XS })
          }
        }
        .alignItems(HorizontalAlign.End)
        .justifyContent(FlexAlign.Center)
        .margin({ left: SPACE_SM })
      }
      .width('100%')
      .padding({ left: SPACE_CARD, right: SPACE_CARD, top: SPACE_MD, bottom: SPACE_MD })
      .alignItems(VerticalAlign.Center)

      if (!this.isArchivedGoal() && this.showTaskActionOverlay && this.selectedTaskForAction?.id === task.id) {
        Column() {
          Row() {
            Row() {
              Text(this.getCurrentTask(task).isPinned ? '取消置顶' : '置顶')
                .fontSize(TYPE_BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.themeColors.textOnPrimary)
            }
            .height(BUTTON_HEIGHT_MD)
            .alignItems(VerticalAlign.Center)
            .justifyContent(FlexAlign.Center)
            .padding({ left: PANEL_GAP, right: PANEL_GAP })
            .borderRadius(19)
            .backgroundColor(this.themeColors.textSecondary)
            .shadow({ radius: 8, color: this.themeColors.cardShadow, offsetX: 0, offsetY: 2 })
            .onClick(() => {
              this.toggleTaskPinned(task);
            })
            
            AppButton({
              text: '编辑',
              variant: 'primary',
              buttonSize: 'md',
              tapAction: () => {
                this.editSelectedTask();
              }
            })
              .margin({ left: SPACE_CARD, right: SPACE_CARD })

            AppButton({
              text: '删除',
              variant: 'danger',
              buttonSize: 'md',
              tapAction: () => {
                this.showDeleteTaskConfirm = true;
              }
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ left: SPACE_CARD, right: SPACE_CARD })
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: MOTION_SHIFT_ENTER_Y })))
          .animation({ duration: MOTION_DURATION_BASE, curve: MOTION_CURVE_STANDARD })
        }
        .width('100%')
            .height(REMINDER_CARD_HEIGHT)
        .backgroundColor(this.themeColors.surfaceOverlay)
        .borderRadius(10)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .transition(TransitionEffect.OPACITY)
      }
    }
    .width('100%')
    .height(REMINDER_CARD_HEIGHT)
    .margin({ bottom: SPACE_SM })
    .borderRadius(10)
    .backgroundColor(this.themeColors.cardBackground)
    .border({
      width: { left: this.getCurrentTask(task).isPinned ? 4 : 1, top: 1, right: 1, bottom: 1 },
      color: { left: this.getCurrentTask(task).isPinned ? this.themeColors.danger : this.themeColors.borderColor, top: this.themeColors.borderColor, right: this.themeColors.borderColor, bottom: this.themeColors.borderColor },
      radius: 10
    })
    .clip(true)
    .shadow({ radius: 8, color: this.themeColors.cardShadow, offsetX: 0, offsetY: 2 })
    .onClick(() => {
      if (this.showTaskActionOverlay) {
        this.hideTaskActions();
      } else {
        if (this.isArchivedGoal()) {
          this.showArchivedToast();
        } else {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/TaskDetailPage', params: {taskId: task.id.toString() } });
        }
      }
    })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          if (!this.isArchivedGoal()) {
            this.showTaskActions(task);
          }
        })
    )
  }

  @Builder
  DeleteTaskConfirmDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeColors.surfaceOverlay)
        .onClick(() => {
          this.showDeleteTaskConfirm = false;
        })
      
      Column() {
        Text('确认删除任务')
          .fontSize(TYPE_HERO_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .margin({ bottom: SPACE_CARD })
        
        Text('是否删除该任务？')
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ bottom: SECTION_GAP })

        AppDialogActions({
          primaryText: '删除',
          primaryVariant: 'danger',
          onSecondary: () => {
            this.showDeleteTaskConfirm = false;
          },
          onPrimary: () => {
            this.deleteSelectedTask();
          }
        })
      }
      .width('88%')
      .padding(SPACE_CARD)
      .backgroundColor(this.themeColors.cardBackground)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(1000)
  }
}
