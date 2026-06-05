import router from '@ohos.router';
import { TaskPriority, TaskStatus, type Task, type Subtask } from '../models/Task';
import { type Goal } from '../models/Goal';
import { type Pomodoro } from '../models/Pomodoro';
import { db } from '../storage/Database';
import { LightTheme, type ThemeColors } from '../theme/AppTheme';
import { authService } from '../services/AuthService';
import promptAction from '@ohos.promptAction';
import { TelemetryService, type TelemetryProperties } from '../services/TelemetryService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppIcon } from '../ui/base/AppIcon';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AVATAR_SIZE_MD, BUTTON_HEIGHT_MD, BUTTON_HEIGHT_SM, CHECKBOX_SIZE_SM, ICON_BUTTON_SIZE_SM } from '../foundation/tokens/ComponentSizeTokens';
import { ICON_SIZE_SM } from '../foundation/tokens/IconTokens';
import { PANEL_GAP, SECTION_GAP, SPACE_2XS, SPACE_CARD, SPACE_MD, SPACE_SM, SPACE_XL, SPACE_XS } from '../foundation/tokens/SpacingTokens';

@Entry
@Component
struct TaskDetailPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State taskId: string = '';
  @State task: Task | null = null;
  @State goal: Goal | null = null;
  @State pomodoros: Pomodoro[] = [];
  @State totalPomodoroMinutes: number = 0;
  @State isUpdatingTask: boolean = false;
  @State newSubtaskTitle: string = '';

  aboutToAppear(): void {
    const params: Record<string, string> = router.getParams() as Record<string, string>;
    if (params && params.taskId) {
      this.taskId = params.taskId;
    }
    this.loadTaskData();
  }

  onPageShow(): void {
    if (this.taskId) {
      this.loadTaskData();
    }
  }

  loadTaskData(): void {
    try {
      const currentTask = this.taskId ? db.getTaskById(this.taskId) || null : null;
      this.task = currentTask;

      if (!currentTask) {
        this.goal = null;
        this.pomodoros = [];
        this.totalPomodoroMinutes = 0;
        return;
      }

      this.goal = db.getGoalById(currentTask.goalId) || null;

      const pomodoroRecords = db.getPomodorosByTaskId(this.taskId);
      pomodoroRecords.sort((a: Pomodoro, b: Pomodoro) => b.startTime - a.startTime);
      this.pomodoros = [...pomodoroRecords];

      this.totalPomodoroMinutes = this.pomodoros.reduce((sum: number, pomodoro: Pomodoro) => {
        return sum + this.getPomodoroDuration(pomodoro);
      }, 0);
    } catch (error) {
      console.error('TaskDetailPage loadTaskData error:', JSON.stringify(error));
    }
  }

  startPomodoro(): void {
    try {
      router.pushUrl({
        url: 'pages/CreatePomodoroPage',
        params: {
          taskId: this.taskId,
          autoSelect: 'true'
        }
      });
    } catch (error) {
      console.error('TaskDetailPage startPomodoro error:', JSON.stringify(error));
    }
  }

  editTask(): void {
    if (!this.task) {
      return;
    }

    try {
      router.pushUrl({
        url: 'pages/CreateTaskPage',
        params: {
          taskId: this.task.id,
          isEdit: 'true'
        }
      });
    } catch (error) {
      console.error('TaskDetailPage editTask error:', JSON.stringify(error));
    }
  }

  async toggleTaskCompletion(): Promise<void> {
    if (!this.task || this.isUpdatingTask) {
      return;
    }

    this.isUpdatingTask = true;
    try {
      const willComplete = this.task.status !== TaskStatus.COMPLETED;
      await db.setTaskCompletion(this.task.id, willComplete);
      if (willComplete) {
        (() => {
          const now = new Date();
          now.setHours(0, 0, 0, 0);
          let completedProps: TelemetryProperties = {
            "isToday": !!this.task && this.task.dueDate !== undefined && this.task.dueDate >= now.getTime() &&
              this.task.dueDate < now.getTime() + 24 * 60 * 60 * 1000
          };
          TelemetryService.track('task_completed', completedProps, 'task');
        })();
      }
      this.loadTaskData();
    } catch (error) {
      console.error('TaskDetailPage toggleTaskCompletion error:', JSON.stringify(error));
    } finally {
      this.isUpdatingTask = false;
    }
  }

  async addSubtask(): Promise<void> {
    if (!this.task || !this.newSubtaskTitle.trim() || this.isUpdatingTask) {
      return;
    }

    this.isUpdatingTask = true;
    try {
      const currentUser = await authService.getCurrentUser();
      const isPremium = authService.isPremiumUser(currentUser);
      if (!isPremium) {
        promptAction.showDialog({
          title: '升级高级会员',
          message: '基础会员不支持子任务拆解。升级高级会员，畅享无限子任务分解功能！',
          buttons: [{ text: '暂不升级', color: this.themeColors.textMuted }, { text: '查看特权', color: this.themeColors.premium }]
        }).then(data => {
          if (data.index === 1) {
            router.pushUrl({ url: 'pages/MembershipPage' });
          }
        });
        this.isUpdatingTask = false;
        return;
      }

      const newSubtask: Subtask = {
        id: 'subtask_' + Date.now() + '_' + Math.random().toString(36).substr(2, 6),
        title: this.newSubtaskTitle.trim(),
        isCompleted: false
      };
      
      this.task.subtasks = this.task.subtasks || [];
      this.task.subtasks.push(newSubtask);
      this.task.updatedAt = Date.now();
      
      await db.updateTask(this.task);
      this.newSubtaskTitle = '';
    } catch (error) {
      console.error('TaskDetailPage addSubtask error:', JSON.stringify(error));
    } finally {
      this.isUpdatingTask = false;
    }
  }

  async toggleSubtaskCompletion(subtaskId: string): Promise<void> {
    if (!this.task || this.isUpdatingTask || !this.task.subtasks) {
      return;
    }

    const index = this.task.subtasks.findIndex(s => s.id === subtaskId);
    if (index === -1) return;

    this.isUpdatingTask = true;
    try {
      this.task.subtasks[index].isCompleted = !this.task.subtasks[index].isCompleted;
      this.task.updatedAt = Date.now();
      await db.updateTask(this.task);
    } catch (error) {
      console.error('TaskDetailPage toggleSubtask error:', JSON.stringify(error));
    } finally {
      this.isUpdatingTask = false;
    }
  }

  async deleteSubtask(subtaskId: string): Promise<void> {
    if (!this.task || this.isUpdatingTask || !this.task.subtasks) {
      return;
    }

    const index = this.task.subtasks.findIndex(s => s.id === subtaskId);
    if (index === -1) return;

    this.isUpdatingTask = true;
    try {
      this.task.subtasks.splice(index, 1);
      this.task.updatedAt = Date.now();
      await db.updateTask(this.task);
    } catch (error) {
      console.error('TaskDetailPage deleteSubtask error:', JSON.stringify(error));
    } finally {
      this.isUpdatingTask = false;
    }
  }

  formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    return `${year}-${month.toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}`;
  }

  formatDateTime(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${year}-${month}-${day} ${hours}:${minutes}`;
  }

  formatDuration(minutes: number): string {
    if (minutes <= 0) {
      return '0分钟';
    }
    if (minutes < 60) {
      return `${minutes}分钟`;
    }

    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;
    if (remainingMinutes === 0) {
      return `${hours}小时`;
    }
    return `${hours}小时${remainingMinutes}分钟`;
  }

  getPomodoroDuration(pomodoro: Pomodoro): number {
    if (pomodoro.endTime) {
      return Math.round((pomodoro.endTime - pomodoro.startTime) / 60000);
    }
    return pomodoro.duration;
  }

  isCompleted(): boolean {
    return this.task?.status === TaskStatus.COMPLETED;
  }

  isOverdue(): boolean {
    return !!(this.task && this.task.isOverdue);
  }

  getStatusText(): string {
    return this.isCompleted() ? '已完成' : '进行中';
  }

  getStatusColor(): string {
    return this.isCompleted() ? this.themeColors.success : this.themeColors.primary;
  }

  getStatusBackground(): string {
    return this.isCompleted() ? this.themeColors.successSubtle : this.themeColors.primarySubtle;
  }

  getPriorityText(priority: string): string {
    switch (priority) {
      case TaskPriority.HIGH:
        return '优先';
      case TaskPriority.LOW:
        return '暂缓';
      case TaskPriority.NORMAL:
      default:
        return '普通';
    }
  }

  getPriorityColor(priority: string): string {
    return this.themeColors.textOnPrimary;
  }

  getPriorityBackground(priority: string): string {
    switch (priority) {
      case TaskPriority.HIGH:
        return this.themeColors.danger;
      case TaskPriority.LOW:
        return this.themeColors.textSecondary;
      case TaskPriority.NORMAL:
      default:
        return this.themeColors.primary;
    }
  }

  getGoalTitle(): string {
    return this.goal?.title || this.task?.goalTitle || '未关联目标';
  }

  getKrTitle(): string {
    return this.task?.krTitle || '未关联衡量标准';
  }

  getReminderTitle(): string {
    return this.task?.reminderTitle || '未关联提醒';
  }

  getDueDateText(): string {
    if (!this.task?.dueDate) {
      return '未设置截止时间';
    }
    const dateStr = this.formatDate(this.task.dueDate);
    const timeStr = this.task.dueTime ? ` ${this.task.dueTime}` : '';
    if (this.isOverdue()) {
      return `${dateStr}${timeStr} · 已逾期`;
    }
    return `${dateStr}${timeStr}`;
  }

  getDueDateColor(): string {
    return this.isOverdue() ? this.themeColors.danger : this.themeColors.textPrimary;
  }

  getDescriptionText(): string {
    const description = this.task?.description?.trim();
    return description ? description : '暂无任务说明';
  }

  getCompletionButtonLabel(): string {
    if (this.isUpdatingTask) {
      return this.isCompleted() ? '恢复中...' : '完成中...';
    }
    return this.isCompleted() ? '标记为未完成' : '完成任务';
  }

  getPomodoroSummaryText(): string {
    if (this.pomodoros.length === 0) {
      return '还没有开始专注';
    }
    return `${this.pomodoros.length} 次专注，累计 ${this.formatDuration(this.totalPomodoroMinutes)}`;
  }

  getLatestPomodoroText(): string {
    if (this.pomodoros.length === 0) {
      return '暂无记录';
    }
    return this.formatDateTime(this.pomodoros[0].startTime);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.PageHeader()

        if (this.task) {
          Scroll() {
            Column() {
              this.TaskHeroCard()
              this.FocusStatsRow()
              
              Column() {
                this.TaskInfoSection()
                if (this.task?.subtasks && this.task.subtasks.length > 0) {
                  Divider().color(this.themeColors.borderColor).margin({ left: SECTION_GAP, right: SECTION_GAP, top: 0 })
                  this.SubtasksSection()
                } else {
                  Divider().color(this.themeColors.borderColor).margin({ left: SECTION_GAP, right: SECTION_GAP, top: 0 })
                  this.SubtasksSection()
                }
                Divider().color(this.themeColors.borderColor).margin({ left: SECTION_GAP, right: SECTION_GAP, top: 0 })
                this.PomodoroSection()
              }
              .width('100%')
              .backgroundColor(this.themeColors.surface)
              .borderRadius(20)
              .border({ width: 1, color: this.themeColors.borderColor })
              .margin({ top: SPACE_CARD })
            }
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 120 })
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        } else {
          this.EmptyState()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeColors.background)

      if (this.task) {
        this.BottomActionBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }

  @Builder
  PageHeader() {
    AppPageHeader({
      title: '任务详情',
      subtitle: '查看任务进度、关联信息和专注记录',
      actionText: !this.isCompleted() ? '编辑' : '',
      actionIconName: 'note',
      onBack: () => {
        router.back();
      },
      onAction: () => {
        if (!this.isCompleted()) {
          this.editTask();
        }
      }
    })
  }

  @Builder
  TaskHeroCard() {
    Column() {
      Row() {
        Row() {
          if (this.task?.isImportant) {
            this.TagChip('重要', this.themeColors.textOnPrimary, this.themeColors.warning)
          }
          this.TagChip(this.getStatusText(), this.getStatusColor(), this.getStatusBackground())
          this.TagChip(
            this.getPriorityText(this.task?.priority || TaskPriority.NORMAL),
            this.getPriorityColor(this.task?.priority || TaskPriority.NORMAL),
            this.getPriorityBackground(this.task?.priority || TaskPriority.NORMAL)
          )
        }

        Blank()

        if (this.task?.isPinned) {
          this.TagChip('已置顶', this.themeColors.warning, this.themeColors.warningSubtle)
        }
      }
      .width('100%')

      Text(this.task?.title || '')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
        .textAlign(TextAlign.Start)
        .margin({ top: SPACE_MD })

      Text(this.getPomodoroSummaryText())
        .fontSize(13)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
        .lineHeight(18)
        .margin({ top: SPACE_XS })

      Row() {
        if (this.task?.reminderTitle) {
          this.MetaPill('提醒', this.getReminderTitle())
        }

        this.MetaPill('目标', this.getGoalTitle())

        if (this.task?.krTitle) {
          this.MetaPill('衡量标准', this.getKrTitle())
        }
      }
      .width('100%')
      .margin({ top: SPACE_MD })

      Column() {
        Text('任务说明')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textMuted)
          .width('100%')

        Text(this.getDescriptionText())
          .fontSize(13)
          .fontColor(this.task?.description ? this.themeColors.textPrimary : this.themeColors.textMuted)
          .lineHeight(18)
          .width('100%')
          .textAlign(TextAlign.Start)
          .margin({ top: SPACE_SM })
      }
      .width('100%')
      .padding({ top: 12 })
      .margin({ top: SPACE_SM })
      .border({
        width: { top: 1 },
        color: this.themeColors.borderColor
      })
    }
    .width('100%')
    .padding(SPACE_CARD)
    .backgroundColor(this.themeColors.surface)
    .borderRadius(18)
    .border({ width: 1, color: this.themeColors.borderColor })
    .shadow({
      radius: 10,
      color: this.themeColors.cardShadow,
      offsetX: 0,
      offsetY: 4
    })
    .margin({ top: SPACE_2XS })
  }

  @Builder
  FocusStatsRow() {
    Row() {
      this.StatCard(
        '专注次数',
        `${this.pomodoros.length}`,
        this.pomodoros.length > 0 ? `已完成 ${this.pomodoros.filter((item: Pomodoro) => item.completed).length} 次` : '还没有开始',
        this.themeColors.primary
      )

      this.StatCard(
        '累计时长',
        this.formatDuration(this.totalPomodoroMinutes),
        `最近一次 ${this.getLatestPomodoroText()}`,
        this.themeColors.accent
      )
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .margin({ top: SPACE_SM })
  }

  @Builder
  StatCard(title: string, value: string, subtitle: string, accentColor: string) {
    Column() {
      AppCard({ variant: 'soft', spacing: 4, paddingLevel: 'md' }) {
        Text(title)
          .fontSize(13)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')

        Text(value)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(accentColor)
          .width('100%')

        Text(subtitle)
          .fontSize(12)
          .fontColor(this.themeColors.textMuted)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('48.5%')
  }

  @Builder
  TaskInfoSection() {
    Column() {
      this.SectionHeader('任务信息', '把关键字段拆开看，会更容易理解这条任务现在的状态。')

      Row() {
        this.InfoTile('关联目标', this.getGoalTitle(), this.themeColors.textPrimary)
        this.InfoTile('衡量标准', this.getKrTitle(), this.themeColors.textPrimary)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: SPACE_SM })

      Row() {
        this.InfoTile('截止时间', this.getDueDateText(), this.getDueDateColor())
        this.InfoTile('创建时间', this.formatDate(this.task?.createdAt || Date.now()), this.themeColors.textPrimary)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: SPACE_SM })

      Row() {
        this.InfoTile('预估耗时', this.task?.estimatedHours ? `${this.task.estimatedHours} 小时` : '未设置', this.themeColors.textPrimary)
        this.InfoTile('关联提醒', this.getReminderTitle(), this.themeColors.textPrimary)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: SPACE_SM })

      Row() {
        this.InfoTile(
          '完成时间',
          this.task?.completedAt ? this.formatDateTime(this.task.completedAt) : '尚未完成',
          this.isCompleted() ? this.themeColors.success : this.themeColors.textSecondary
        )
        Blank()
          .width('48.5%')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: SPACE_SM })
    }
    .width('100%')
    .padding(PANEL_GAP)
  }

  @Builder
  PomodoroSection() {
    Column() {
      Row() {
        Column() {
          this.SectionHeader('专注记录', '每一次番茄钟都会沉淀在这里，帮助你回看投入节奏。')
        }
        .layoutWeight(1)

        Text('查看完整报告 →')
          .fontSize(12)
          .fontColor(this.themeColors.primary)
          .onClick(() => {
            router.pushUrl({ url: 'pages/StatsHubPage' });
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.pomodoros.length === 0) {
        Column() {
          Image($r('app.media.tomato'))
            .width(AVATAR_SIZE_MD)
            .height(AVATAR_SIZE_MD)
            .margin({ bottom: PANEL_GAP })

          Text('还没有记录，点击下方按钮立即开始专注')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .margin({ bottom: SPACE_XS })
        }
        .width('100%')
        .padding({ top: SECTION_GAP, bottom: SPACE_XL, left: PANEL_GAP, right: PANEL_GAP })
        .alignItems(HorizontalAlign.Center)
      } else {
        Column() {
          ForEach(this.pomodoros, (pomodoro: Pomodoro, index: number) => {
            this.PomodoroItem(pomodoro, index)
          }, (pomodoro: Pomodoro) => pomodoro.id)
        }
        .width('100%')
        .margin({ top: SPACE_2XS })
      }
    }
    .width('100%')
    .padding(PANEL_GAP)
  }

  @Builder
  SectionHeader(title: string, subtitle: string) {
    Column() {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Text(subtitle)
        .fontSize(12)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
        .lineHeight(18)
        .margin({ top: SPACE_2XS })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  InfoTile(label: string, value: string, valueColor: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor(this.themeColors.textMuted)
        .width('100%')

      Text(value)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(valueColor)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: SPACE_SM })
    }
    .width('48.5%')
    .height(68)
    .padding(SPACE_MD)
    .backgroundColor(this.themeColors.surfaceLight)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  TagChip(text: string, textColor: string, backgroundColor: string) {
    Row() {
      Text(text)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(textColor)
    }
    .padding({ left: 8, right: 8, top: 5, bottom: 5 })
    .backgroundColor(backgroundColor)
    .borderRadius(999)
    .margin({ right: SPACE_XS })
  }

  @Builder
  MetaPill(label: string, value: string) {
    Row() {
      Text(`${label} · `)
        .fontSize(12)
        .fontColor(this.themeColors.textMuted)

      Text(value)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: 8, right: 8, top: 5, bottom: 5 })
    .backgroundColor(this.themeColors.surfaceLight)
    .borderRadius(999)
    .margin({ right: SPACE_XS, bottom: SPACE_XS })
  }

  @Builder
  PomodoroItem(pomodoro: Pomodoro, index: number) {
    Row() {
      Column() {
        Image($r('app.media.tomato'))
          .width(ICON_SIZE_SM)
          .height(ICON_SIZE_SM)
      }
      .width(BUTTON_HEIGHT_MD)
      .height(BUTTON_HEIGHT_SM)
      .borderRadius(20)
      .backgroundColor(this.themeColors.warningSubtle)
      .justifyContent(FlexAlign.Center)

      Column() {
        Row() {
          Text(`第 ${this.pomodoros.length - index} 次专注`)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)

          Blank()

          this.TagChip(
            pomodoro.completed ? '已完成' : '进行中',
            pomodoro.completed ? this.themeColors.success : this.themeColors.warning,
            pomodoro.completed ? this.themeColors.successSubtle : this.themeColors.warningSubtle
          )
        }
        .width('100%')

        Text(`${this.formatDateTime(pomodoro.startTime)} - ${this.formatDateTime(pomodoro.endTime || pomodoro.startTime + pomodoro.duration * 60000)}`)
          .fontSize(13)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
          .margin({ top: SPACE_XS })

        Text(`专注时长 ${this.getPomodoroDuration(pomodoro)} 分钟`)
          .fontSize(13)
          .fontColor(this.themeColors.textMuted)
          .width('100%')
          .margin({ top: SPACE_2XS })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: SPACE_SM })
    }
    .width('100%')
    .padding(SPACE_MD)
    .backgroundColor(this.themeColors.surfaceLight)
    .borderRadius(12)
    .margin({ top: index === 0 ? 10 : 8 })
  }

  @Builder
  BottomActionBar() {
    Column() {
      AppCard({ variant: 'raised', spacing: 10, paddingLevel: 'md' }) {
        if (!this.isCompleted()) {
          Row({ space: SPACE_SM }) {
            AppButton({
              text: '开始专注',
              variant: 'primary',
              buttonSize: 'md',
              iconName: 'focus',
              tapAction: () => {
                this.startPomodoro();
              }
            })
              .layoutWeight(1)

            AppButton({
              text: this.getCompletionButtonLabel(),
              variant: 'secondary',
              buttonSize: 'md',
              disabled: this.isUpdatingTask,
              iconName: 'success',
              tapAction: () => {
                this.toggleTaskCompletion();
              }
            })
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        } else {
          AppButton({
            text: '重启任务',
            variant: 'secondary',
            buttonSize: 'md',
            disabled: this.isUpdatingTask,
            iconName: 'task',
            tapAction: () => {
              this.toggleTaskCompletion();
            }
          })
            .width('100%')
        }
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 8, bottom: 10 })
    .backgroundColor(this.themeColors.navBackground)
  }

  @Builder
  EmptyState() {
    Column() {
      AppEmptyState({
        iconName: 'warning',
        iconTone: 'warning',
        title: '任务不存在或已被删除',
        description: '返回上一页，再选择一条任务继续查看。',
        actionText: '返回',
        actionIconName: 'chevron-left',
        onAction: () => {
          router.back();
        }
      })
    }
    .layoutWeight(1)
    .width('100%')
    .padding(SECTION_GAP)
    .justifyContent(FlexAlign.Center)
  }
  @Builder
  SubtasksSection() {
    Column() {
      Row() {
        this.SectionHeader('子任务', '将大块头拆分为小颗粒，一步步实现目标。')
        Blank()
        if (this.task?.subtasks && this.task.subtasks.length > 0) {
          Text(`${this.task.subtasks.filter(s => s.isCompleted).length}/${this.task.subtasks.length}`)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.primary)
            .backgroundColor(this.themeColors.primarySubtle)
            .padding({ left: SPACE_SM, right: SPACE_SM, top: SPACE_2XS, bottom: SPACE_2XS })
            .borderRadius(12)
        }
      }
      .width('100%')

      Column({ space: SPACE_SM }) {
        if (this.task?.subtasks) {
          ForEach(this.task.subtasks, (subtask: Subtask) => {
            Row() {
              Checkbox({ name: subtask.id })
                .select(subtask.isCompleted)
                .selectedColor(this.themeColors.primary)
                .width(CHECKBOX_SIZE_SM)
                .height(CHECKBOX_SIZE_SM)
                .margin({ right: SPACE_MD })
                .onChange(() => {
                  this.toggleSubtaskCompletion(subtask.id);
                })

              Text(subtask.title)
                .fontSize(15)
                .fontColor(subtask.isCompleted ? this.themeColors.textMuted : this.themeColors.textPrimary)
                .decoration({ type: subtask.isCompleted ? TextDecorationType.LineThrough : TextDecorationType.None })
                .layoutWeight(1)

              Button() {
                AppIcon({
                  name: 'close',
                  iconSize: 14,
                  framed: false,
                  color: this.themeColors.textMuted
                })
              }
              .width(ICON_BUTTON_SIZE_SM)
              .height(ICON_BUTTON_SIZE_SM)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                this.deleteSubtask(subtask.id);
              })
            }
            .width('100%')
            .padding({ left: SPACE_MD, right: SPACE_SM, top: SPACE_SM, bottom: SPACE_SM })
            .backgroundColor(this.themeColors.surfaceLight)
            .borderRadius(12)
          }, (subtask: Subtask) => subtask.id + '_' + subtask.isCompleted)
        }

        Row() {
          TextInput({ placeholder: '添加新子任务...', text: this.newSubtaskTitle })
            .layoutWeight(1)
            .height(BUTTON_HEIGHT_SM)
            .fontSize(15)
            .backgroundColor(Color.Transparent)
            .fontColor(this.themeColors.textPrimary)
            .placeholderColor(this.themeColors.textMuted)
            .onChange((value: string) => {
              this.newSubtaskTitle = value;
            })
            .onSubmit(() => {
              this.addSubtask();
            })
          
          Button('添加')
            .height(BUTTON_HEIGHT_SM)
            .fontSize(14)
            .fontColor(this.newSubtaskTitle.trim() ? this.themeColors.textOnPrimary : this.themeColors.textMuted)
            .backgroundColor(this.newSubtaskTitle.trim() ? this.themeColors.primary : this.themeColors.surface)
            .borderRadius(8)
            .margin({ right: SPACE_XS })
            .onClick(() => {
              this.addSubtask();
            })
        }
        .width('100%')
        .padding({ left: SPACE_MD, right: SPACE_XS, top: SPACE_2XS, bottom: SPACE_2XS })
        .backgroundColor(this.themeColors.surfaceLight)
        .borderRadius(12)
        .margin({ top: this.task?.subtasks?.length ? 4 : 0 })
      }
      .width('100%')
      .margin({ top: SPACE_MD })
    }
    .width('100%')
    .padding(PANEL_GAP)
  }
}
