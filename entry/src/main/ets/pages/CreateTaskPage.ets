import { Goal, KeyResult } from '../models/Goal';
import { Task, TaskPriority, Subtask } from '../models/Task';
import { DayEvent } from '../models/DayEvent';
import { db } from '../storage/Database';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { dataSyncService } from '../services/DataSyncService';
import { AgentService, SimilarTaskItem } from '../services/AgentService';
import { authService } from '../services/AuthService';
import { QuotaService } from '../services/QuotaService';
import { TelemetryService, type TelemetryProperties } from '../services/TelemetryService';
import { AIFillState } from '../services/AIFillState';
import { AppAIFillBanner } from '../ui/base/AppAIFillBanner';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppFormCard } from '../ui/base/AppFormCard';
import { AppListRow } from '../ui/base/AppListRow';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { BUTTON_HEIGHT_LG, BUTTON_HEIGHT_MD, BUTTON_HEIGHT_SM } from '../foundation/tokens/ComponentSizeTokens';
import { ICON_SIZE_SM, ICON_SIZE_XS } from '../foundation/tokens/IconTokens';
import { PAGE_PADDING, SECTION_GAP, SPACE_2XS, SPACE_CARD, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { COMFORTABLE_PAGE_PADDING, COMFORTABLE_SECTION_GAP } from '../foundation/tokens/PageTierTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('CreateTaskPage');

@Entry
@Component
struct CreateTaskPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State task: Task | null = null;
  @State title: string = '';
  @State description: string = '';
  @State selectedGoalId: string = '';
  @State selectedKrId: string = '';
  @State selectedReminderId: string = '';
  @State dueDate: string = '';
  @State dueTime: string = '';
  @State priority: TaskPriority = TaskPriority.NORMAL;
  @State goals: Goal[] = [];
  @State reminders: DayEvent[] = [];
  @State showGoalPicker: boolean = false;
  @State showReminderPicker: boolean = false;
  @State showKrPicker: boolean = false;
  @State showDatePicker: boolean = false;
  @State datePickerDate: Date = new Date();
  @State timePickerHour: number = 0;
  @State timePickerMinute: number = 0;
  @State hasSelectedTime: boolean = false;
  @State isSaving: boolean = false;
  @State isAutoFilling: boolean = false;
  @State similarTasks: SimilarTaskItem[] = [];
  @State subtasks: Subtask[] = [];
  @State newSubtaskTitle: string = '';
  @State isImportant: boolean = false;
  @State estimatedHoursStr: string = '';
  @State aiFill: AIFillState = new AIFillState();

  private taskId: string = '';
  private isEdit: boolean = false;

  async aboutToAppear(): Promise<void> {
    await this.initializePage();
  }

  onPageShow(): void {
    this.goals = db.getActiveGoals();
    if (this.isEdit && this.taskId) {
      this.loadTaskData();
    }
    this.reminders = db.getAllDayEvents().filter((event: DayEvent) => {
      if (!event.isEnabled) {
        return false;
      }
      if (event.isCompleted && event.id !== this.selectedReminderId) {
        return false;
      }
      return true;
    });
  }

  private async initializePage(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as Context;
      if (!db.isInitialized()) {
        await db.initialize(context);
      }
    } catch (error) {
      logger.error('CreateTaskPage initialize error', error as Object);
    }

    this.goals = db.getActiveGoals();
    this.reminders = db.getAllDayEvents().filter((event: DayEvent) => event.isEnabled);

    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    if (params && params['taskId']) {
      this.taskId = params['taskId'];
      this.isEdit = true;
      this.loadTaskData();
      return;
    }

    if (params && params['autoFill'] === 'true') {
      this.title = params['title'] || '';
      this.description = params['description'] || '';
      this.selectedGoalId = params['goalId'] || '';
      this.selectedKrId = params['krId'] || '';

      const priorityStr = params['priority'];
      if (priorityStr === 'high') {
        this.priority = TaskPriority.HIGH;
      } else if (priorityStr === 'low') {
        this.priority = TaskPriority.LOW;
      } else {
        this.priority = TaskPriority.NORMAL;
      }

      const dueDateStr = params['dueDate'];
      if (dueDateStr) {
        const parsedDate = new Date(dueDateStr.replace(/-/g, '/'));
        if (!isNaN(parsedDate.getTime())) {
          this.datePickerDate = parsedDate;
          this.dueDate = this.formatDateOnly(parsedDate.getTime());
        }
      }
      const dueTimeStr = params['dueTime'];
      if (dueTimeStr) {
        this.dueTime = dueTimeStr;
        this.hasSelectedTime = true;
        const timeParts = dueTimeStr.split(':');
        this.timePickerHour = parseInt(timeParts[0]) || 0;
        this.timePickerMinute = parseInt(timeParts[1]) || 0;
      }
      return;
    }

    if (params && params['goalId']) {
      this.selectedGoalId = params['goalId'];
    }
  }

  private loadTaskData(): void {
    const task = db.getTaskById(this.taskId);
    if (!task) {
      return;
    }

    this.task = task;
    this.title = task.title;
    this.description = task.description;
    this.selectedGoalId = task.goalId;
    this.selectedKrId = task.krId || '';
    this.selectedReminderId = task.reminderId || '';
    this.priority = task.priority || TaskPriority.NORMAL;
    this.dueDate = this.formatDateOnly(task.dueDate);
    this.dueTime = task.dueTime || '';
    this.hasSelectedTime = !!task.dueTime;
    this.subtasks = task.subtasks ? [...task.subtasks] : [];
    this.isImportant = task.isImportant || false;
    this.estimatedHoursStr = task.estimatedHours !== undefined ? task.estimatedHours.toString() : '';

    if (task.dueDate) {
      this.datePickerDate = new Date(task.dueDate);
    }
    if (task.dueTime) {
      const timeParts = task.dueTime.split(':');
      this.timePickerHour = parseInt(timeParts[0]) || 0;
      this.timePickerMinute = parseInt(timeParts[1]) || 0;
    }
  }

  private formatDateOnly(timestamp?: number): string {
    if (!timestamp) {
      return '';
    }
    const date = new Date(timestamp);
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
  }

  private getDisplayDateTime(): string {
    if (!this.dueDate) {
      return '未设置日期';
    }
    if (this.dueTime) {
      return `${this.dueDate} ${this.dueTime}`;
    }
    return this.dueDate;
  }

  private canSave(): boolean {
    return !!this.title.trim() && !this.isSaving;
  }

  private getPageTitle(): string {
    return this.isEdit ? '编辑任务' : '创建任务';
  }

  private getSaveButtonLabel(): string {
    return this.isEdit ? '保存修改' : '创建任务';
  }

  private getSelectedGoal(): Goal | undefined {
    return this.goals.find((goal: Goal) => goal.id === this.selectedGoalId);
  }

  private getSelectedGoalTitle(): string {
    return this.getSelectedGoal()?.title || '暂不关联目标';
  }

  private getSelectedKrTitle(): string {
    return this.getSelectedGoal()?.keyResults.find((kr: KeyResult) => kr.id === this.selectedKrId)?.title || '暂不关联衡量标准';
  }

  private getSelectedReminder(): DayEvent | undefined {
    return this.reminders.find((event: DayEvent) => event.id === this.selectedReminderId);
  }

  private getReminderButtonLabel(): string {
    return this.getSelectedReminder()?.title || '暂不关联提醒';
  }

  private getPriorityTone(priority: TaskPriority): 'primary' | 'warning' | 'neutral' {
    if (priority === TaskPriority.HIGH) {
      return 'warning';
    }
    if (priority === TaskPriority.LOW) {
      return 'neutral';
    }
    return 'primary';
  }

  private addSubtaskDraft(): void {
    if (!this.newSubtaskTitle.trim()) {
      return;
    }
    const newSubtask: Subtask = {
      id: 'subtask_' + Date.now() + '_' + Math.random().toString(36).substr(2, 6),
      title: this.newSubtaskTitle.trim(),
      isCompleted: false
    };
    this.subtasks = [...this.subtasks, newSubtask];
    this.newSubtaskTitle = '';
  }

  private applyDateSelection(): void {
    const year = this.datePickerDate.getFullYear();
    const month = (this.datePickerDate.getMonth() + 1).toString().padStart(2, '0');
    const day = this.datePickerDate.getDate().toString().padStart(2, '0');
    this.dueDate = `${year}-${month}-${day}`;
    if (this.hasSelectedTime) {
      this.dueTime = `${this.timePickerHour.toString().padStart(2, '0')}:${this.timePickerMinute.toString().padStart(2, '0')}`;
    } else {
      this.dueTime = '';
    }
    this.showDatePicker = false;
  }

  private clearDateSelection(): void {
    this.dueDate = '';
    this.dueTime = '';
    this.hasSelectedTime = false;
    this.timePickerHour = 0;
    this.timePickerMinute = 0;
    this.showDatePicker = false;
  }

  private async saveTask(): Promise<void> {
    if (!this.canSave()) {
      return;
    }

    const goal = this.selectedGoalId ? db.getGoalById(this.selectedGoalId) : undefined;
    if (this.selectedGoalId && !goal) {
      return;
    }

    const reminder = this.selectedReminderId ? this.getSelectedReminder() : undefined;
    this.isSaving = true;

    try {
      const currentUser = await authService.getCurrentUser();
      const isPremium = authService.isPremiumUser(currentUser);

      if (!isPremium) {
        if (!this.isEdit) {
          const activeTasksCount = db.getPendingTasks().length;
          if (activeTasksCount >= 100) {
            this.getUIContext().getPromptAction().showDialog({
              title: '待办上限提示',
              message: '基础会员最多允许 100 个未完成任务。请先清理旧任务或升级高级会员。',
              buttons: [
                { text: '暂不升级', color: this.themeColors.textMuted },
                { text: '立即升级', color: this.themeColors.premium }
              ]
            }).then((data) => {
              if (data.index === 1) {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/MembershipPage' });
              }
            });
            this.isSaving = false;
            return;
          }
        }

        if (this.subtasks.length > 0) {
          this.getUIContext().getPromptAction().showDialog({
            title: '会员特权',
            message: '基础会员暂不支持子任务拆解。升级高级会员后可使用无限子任务。',
            buttons: [
              { text: '我知道了', color: this.themeColors.textMuted },
              { text: '立即升级', color: this.themeColors.premium }
            ]
          }).then((data) => {
            if (data.index === 1) {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/MembershipPage' });
            }
          });
          this.isSaving = false;
          return;
        }
      }

      if (this.isEdit && this.task) {
        const previousReminderId = this.task.reminderId;
        this.task.title = this.title.trim();
        this.task.description = this.description.trim();
        this.task.goalId = this.selectedGoalId;
        this.task.goalTitle = goal?.title || '';
        this.task.krId = this.selectedGoalId ? this.selectedKrId || undefined : undefined;
        this.task.krTitle = this.selectedKrId
          ? goal?.keyResults.find((kr: KeyResult) => kr.id === this.selectedKrId)?.title
          : undefined;
        this.task.reminderId = reminder?.id;
        this.task.reminderTitle = reminder?.title;
        if (!reminder || previousReminderId !== reminder.id) {
          this.task.isReminderAutoGenerated = false;
          this.task.reminderOccurrenceTime = undefined;
        }
        this.task.priority = this.priority;
        this.task.updatedAt = Date.now();

        if (this.dueDate) {
          this.task.dueDate = new Date(this.dueDate).getTime();
          this.task.dueTime = this.dueTime || undefined;
        } else {
          this.task.dueDate = undefined;
          this.task.dueTime = undefined;
        }

        this.task.subtasks = this.subtasks;
        this.task.isImportant = this.isImportant;
        const parsedHours = parseFloat(this.estimatedHoursStr);
        this.task.estimatedHours = !isNaN(parsedHours) && parsedHours > 0 ? parsedHours : undefined;

        dataSyncService.updateTask(this.task);
        await db.updateTask(this.task);
      } else {
        const newTask = new Task(this.title.trim(), this.selectedGoalId, goal?.title || '');
        newTask.description = this.description.trim();
        newTask.krId = this.selectedGoalId ? this.selectedKrId || undefined : undefined;
        newTask.krTitle = this.selectedKrId
          ? goal?.keyResults.find((kr: KeyResult) => kr.id === this.selectedKrId)?.title
          : undefined;
        newTask.reminderId = reminder?.id;
        newTask.reminderTitle = reminder?.title;
        newTask.priority = this.priority;

        if (this.dueDate) {
          newTask.dueDate = new Date(this.dueDate).getTime();
          newTask.dueTime = this.dueTime || undefined;
        }

        newTask.subtasks = this.subtasks;
        newTask.isImportant = this.isImportant;
        const parsedHoursNew = parseFloat(this.estimatedHoursStr);
        newTask.estimatedHours = !isNaN(parsedHoursNew) && parsedHoursNew > 0 ? parsedHoursNew : undefined;

        const updatedTasks = [...dataSyncService.getTasks(), newTask];
        dataSyncService.setTasks(updatedTasks);
        await db.addTask(newTask);
        const taskCreatedProps: TelemetryProperties = {
          "priority": newTask.priority,
          "hasGoal": !!newTask.goalId,
          "inputMethod": "text"
        };
        TelemetryService.track('task_created', taskCreatedProps, 'task');
      }

      this.getUIContext().getRouter().back();
    } catch (error) {
      logger.error('Failed to save task', error as Object);
      this.getUIContext().getRouter().back();
    } finally {
      this.isSaving = false;
    }
  }

  private async handleAIFill(): Promise<void> {
    if (!this.title.trim() || this.isAutoFilling) {
      return;
    }
    if (!(await authService.checkLoginWithPrompt(this.getUIContext()))) {
      return;
    }

    this.isAutoFilling = true;
    this.aiFill.startParsing();
    try {
      const context = this.getUIContext().getHostContext() as Context;
      const quota = await QuotaService.checkAITaskQuota(context);
      if (!quota.allowed) {
        this.aiFill.reset();
        this.getUIContext().getPromptAction().showDialog({
          title: '本月额度已用完',
          message: '基础会员每月可使用 20 次 AI 智能功能。升级高级会员后可继续使用。',
          buttons: [
            { text: '暂不升级', color: this.themeColors.textMuted },
            { text: '立即升级', color: this.themeColors.premium }
          ]
        }).then((data) => {
          if (data.index === 1) {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/MembershipPage' });
          }
        });
        return;
      }
      await QuotaService.incrementAITaskCount(context);

      const result = await AgentService.autoFillTask(this.title.trim());
      const filledFields: string[] = [];

      if (this.aiFill.canOverwrite('description') && !this.description.trim() && result.filled.description) {
        this.description = result.filled.description;
        filledFields.push('description');
      }

      if (this.aiFill.canOverwrite('priority')) {
        if (result.filled.priority === 'high') {
          this.priority = TaskPriority.HIGH;
        } else if (result.filled.priority === 'low') {
          this.priority = TaskPriority.LOW;
        } else {
          this.priority = TaskPriority.NORMAL;
        }
        filledFields.push('priority');
      }

      if (this.aiFill.canOverwrite('goalId') && result.matchedGoal && !this.selectedGoalId) {
        this.selectedGoalId = result.matchedGoal.goal.id;
        filledFields.push('goalId');
      }
      if (this.aiFill.canOverwrite('krId') && result.matchedKr && !this.selectedKrId) {
        this.selectedKrId = result.matchedKr.krId;
        filledFields.push('krId');
      }

      if (this.aiFill.canOverwrite('dueDate') && result.filled.due_date && !this.dueDate) {
        const rawDate = result.filled.due_date.replace(/-/g, '/');
        const parsedDate = new Date(rawDate);
        if (!isNaN(parsedDate.getTime())) {
          this.datePickerDate = parsedDate;
          this.dueDate = this.formatDateOnly(parsedDate.getTime());
          const hours = parsedDate.getHours();
          const minutes = parsedDate.getMinutes();
          if (hours !== 0 || minutes !== 0) {
            this.dueTime = `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
            this.hasSelectedTime = true;
            this.timePickerHour = hours;
            this.timePickerMinute = minutes;
          }
          filledFields.push('dueDate');
        }
      }

      this.aiFill.markFilled(filledFields);
      this.similarTasks = result.similarTasks && result.similarTasks.length > 0 ? result.similarTasks : [];
    } catch (error) {
      logger.error('AI fill failed', error as Object);
      this.aiFill.markFailed('AI 补全失败，请稍后重试');
    } finally {
      this.isAutoFilling = false;
    }
  }

  @Builder
  private HeroCard() {
    AppCard({ variant: 'accent', paddingLevel: 'md', spacing: SPACE_XS }) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        AppStatusBadge({ text: this.isEdit ? '编辑任务' : '创建任务', tone: 'primary', iconName: this.isEdit ? 'note' : 'task' })
        if (this.isImportant) {
          AppStatusBadge({ text: '重要', tone: 'warning', iconName: 'warning' })
        }
        if (this.subtasks.length > 0) {
          AppStatusBadge({ text: `${this.subtasks.length} 个子任务`, tone: 'neutral', iconName: 'task' })
        }
      }
      .width('100%')

      Text(this.isEdit ? '更新任务内容与执行约束' : '把一个动作定义清楚，后续执行才会更轻')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Text('目标、提醒、衡量标准、优先级、截止时间和子任务都可以在这里一次补齐。')
        .fontSize(TYPE_BODY)
        .lineHeight(18)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  @Builder
  private TitleCard() {
    AppFormCard({ variant: 'base', paddingLevel: 'md', spacing: SPACE_SM }) {
      Row({ space: SPACE_XS }) {
        Text('任务标题')
          .layoutWeight(1)
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)

        AppButton({
          text: this.isAutoFilling ? '补全中...' : 'AI 补全',
          variant: 'secondary',
          buttonSize: 'sm',
          disabled: !this.title.trim() || this.isAutoFilling,
          iconName: 'ai',
          tapAction: () => {
            void this.handleAIFill();
          }
        })
      }
      .width('100%')

      TextInput({ placeholder: '输入任务标题', text: this.title })
        .height(BUTTON_HEIGHT_MD)
        .padding({ left: SPACE_MD, right: SPACE_MD })
        .backgroundColor(this.themeColors.inputBackground)
        .borderRadius(12)
        .fontSize(TYPE_BODY)
        .fontColor(this.themeColors.textPrimary)
        .placeholderColor(this.themeColors.textMuted)
        .onChange((value: string) => {
          this.title = value;
          this.aiFill.markUserEdited('title');
        })

      if (this.similarTasks.length > 0) {
        Column({ space: SPACE_XS }) {
          Row({ space: SPACE_XS }) {
            AppStatusBadge({ text: '发现相似任务', tone: 'warning', iconName: 'warning' })
            Blank()
            Text('忽略')
              .fontSize(TYPE_META)
              .fontColor(this.themeColors.textMuted)
              .onClick(() => {
                this.similarTasks = [];
              })
          }
          .width('100%')

          ForEach(this.similarTasks, (item: SimilarTaskItem) => {
            AppCard({ variant: 'soft', paddingLevel: 'md', spacing: SPACE_XS }) {
              Row({ space: SPACE_SM }) {
                Text(item.task.title)
                  .layoutWeight(1)
                  .fontSize(TYPE_BODY)
                  .fontColor(this.themeColors.textPrimary)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                AppButton({
                  text: '打开',
                  variant: 'secondary',
                  buttonSize: 'sm',
                  iconName: 'task',
                  tapAction: () => {
                    this.getUIContext().getRouter().pushUrl({ url: 'pages/TaskDetailPage', params: { taskId: item.task.id } });
                  }
                })
              }
              .width('100%')
            }
          }, (item: SimilarTaskItem) => item.task.id)
        }
        .width('100%')
      }
    }
  }

  @Builder
  private RelationCard() {
    AppCard({ variant: 'base', spacing: 0 }) {
      Text('关联信息')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
        .margin({ bottom: SPACE_XS })

      AppListRow({
        leadingIcon: 'goal',
        title: '目标',
        subtitle: '把任务挂到一个目标下，首页和目标详情都会更清晰',
        trailingText: this.getSelectedGoalTitle(),
        tone: this.selectedGoalId ? 'primary' : 'default',
        showDivider: true,
        tapAction: () => {
          this.showGoalPicker = true;
        }
      })

      AppListRow({
        leadingIcon: 'reminder',
        title: '提醒',
        subtitle: '可关联周期提醒、习惯或纪念日',
        trailingText: this.getReminderButtonLabel(),
        tone: this.selectedReminderId ? 'primary' : 'default',
        showDivider: true,
        tapAction: () => {
          this.showReminderPicker = true;
        }
      })

      if (this.selectedGoalId) {
        AppListRow({
          leadingIcon: 'progress',
          title: '衡量标准',
          subtitle: '把任务和目标中的某个 KR 关联起来',
          trailingText: this.getSelectedKrTitle(),
          tone: this.selectedKrId ? 'primary' : 'default',
          showDivider: false,
          tapAction: () => {
            this.showKrPicker = true;
          }
        })
      }
    }
  }

  @Builder
  private PriorityCard() {
    AppCard({ variant: 'base', paddingLevel: 'md', spacing: SPACE_SM }) {
      Text('优先级')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Row({ space: SPACE_XS }) {
        AppButton({
          text: '优先',
          variant: this.priority === TaskPriority.HIGH ? 'danger' : 'secondary',
          buttonSize: 'sm',
          iconName: 'warning',
          tapAction: () => {
            this.priority = TaskPriority.HIGH;
          }
        })
        AppButton({
          text: '正常',
          variant: this.priority === TaskPriority.NORMAL ? 'primary' : 'secondary',
          buttonSize: 'sm',
          iconName: 'task',
          tapAction: () => {
            this.priority = TaskPriority.NORMAL;
          }
        })
        AppButton({
          text: '暂缓',
          variant: this.priority === TaskPriority.LOW ? 'ghost' : 'secondary',
          buttonSize: 'sm',
          iconName: 'plan',
          tapAction: () => {
            this.priority = TaskPriority.LOW;
          }
        })
      }
      .width('100%')

      AppStatusBadge({
        text: this.priority === TaskPriority.HIGH ? '当前为高优先级' : (this.priority === TaskPriority.LOW ? '当前为暂缓' : '当前为正常优先级'),
        tone: this.getPriorityTone(this.priority),
        iconName: this.priority === TaskPriority.HIGH ? 'warning' : (this.priority === TaskPriority.LOW ? 'plan' : 'task')
      })
    }
  }

  @Builder
  private ScheduleCard() {
    AppFormCard({ variant: 'base', paddingLevel: 'md', spacing: SPACE_SM }) {
      Text('时间与投入')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      AppListRow({
        leadingIcon: 'calendar',
        title: '计划完成时间',
        subtitle: '可以只设日期，也可以补充具体时分',
        trailingText: this.getDisplayDateTime(),
        tone: this.dueDate ? 'primary' : 'default',
        showDivider: true,
        tapAction: () => {
          this.showDatePicker = true;
        }
      })

      Column({ space: SPACE_XS }) {
        Text('预估耗时（可选）')
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')

        TextInput({ placeholder: '例如：0.5、1、2', text: this.estimatedHoursStr })
          .type(InputType.NUMBER_DECIMAL)
          .height(BUTTON_HEIGHT_MD)
          .padding({ left: SPACE_MD, right: SPACE_MD })
          .backgroundColor(this.themeColors.inputBackground)
          .borderRadius(12)
          .fontColor(this.themeColors.textPrimary)
          .placeholderColor(this.themeColors.textMuted)
          .onChange((value: string) => {
            this.estimatedHoursStr = value;
          })
      }
      .width('100%')

      Row({ space: SPACE_SM }) {
        Column({ space: SPACE_2XS }) {
          Text('标记为重要')
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')

          Text('重要任务会在行动页和首页获得更高展示优先级。')
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Toggle({ type: ToggleType.Switch, isOn: this.isImportant })
          .selectedColor(this.themeColors.warning)
          .onChange((value: boolean) => {
            this.isImportant = value;
          })
      }
      .width('100%')
    }
  }

  @Builder
  private SubtaskCard() {
    AppFormCard({ variant: 'base', paddingLevel: 'md', spacing: SPACE_SM }) {
      Text('子任务（可选）')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      if (this.subtasks.length > 0) {
        Column({ space: SPACE_XS }) {
          ForEach(this.subtasks, (subtask: Subtask, index: number) => {
            AppFormCard({ variant: 'soft', paddingLevel: 'md', spacing: SPACE_XS }) {
              Row({ space: SPACE_SM }) {
                TextInput({ text: subtask.title })
                  .layoutWeight(1)
                  .height(BUTTON_HEIGHT_SM)
                  .fontSize(TYPE_BODY)
                  .fontColor(subtask.isCompleted ? this.themeColors.textMuted : this.themeColors.textPrimary)
                  .backgroundColor(Color.Transparent)
                  .onChange((value: string) => {
                    this.subtasks[index].title = value;
                  })

                Text('删除')
                  .fontSize(TYPE_META)
                  .fontColor(this.themeColors.danger)
                  .onClick(() => {
                    this.subtasks.splice(index, 1);
                  })
              }
              .width('100%')
            }
          }, (subtask: Subtask) => subtask.id)
        }
        .width('100%')
      }

      Row({ space: SPACE_SM }) {
        TextInput({ placeholder: '添加一个更容易启动的小步骤', text: this.newSubtaskTitle })
          .layoutWeight(1)
          .height(BUTTON_HEIGHT_MD)
          .padding({ left: SPACE_MD, right: SPACE_MD })
          .backgroundColor(this.themeColors.inputBackground)
          .borderRadius(12)
          .fontColor(this.themeColors.textPrimary)
          .placeholderColor(this.themeColors.textMuted)
          .onChange((value: string) => {
            this.newSubtaskTitle = value;
          })
          .onSubmit(() => {
            this.addSubtaskDraft();
          })

        AppButton({
          text: '添加',
          variant: 'secondary',
          buttonSize: 'sm',
          iconName: 'task',
          tapAction: () => {
            this.addSubtaskDraft();
          }
        })
      }
      .width('100%')
    }
  }

  @Builder
  private DescriptionCard() {
    AppFormCard({ variant: 'base', paddingLevel: 'md', spacing: SPACE_XS }) {
      Text('任务说明')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      TextArea({ placeholder: '补充任务背景、交付标准或注意事项', text: this.description })
        .height(96)
        .padding(SPACE_SM)
        .backgroundColor(this.themeColors.inputBackground)
        .borderRadius(12)
        .fontColor(this.themeColors.textPrimary)
        .placeholderColor(this.themeColors.textMuted)
        .fontSize(TYPE_BODY)
        .onChange((value: string) => {
          this.description = value;
          this.aiFill.markUserEdited('description');
        })
    }
  }

  @Builder
  private SaveBar() {
    Column({ space: SPACE_XS }) {
      AppButton({
        text: this.getSaveButtonLabel(),
        variant: 'primary',
        emphasis: 'strong',
        fullWidth: true,
        disabled: !this.canSave(),
        loading: this.isSaving,
        tapAction: () => {
          void this.saveTask();
        }
      })
      if (!this.title.trim()) {
        Text('先输入任务标题后再保存')
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
  private SelectionDialog(title: string) {
    Column({ space: SPACE_MD }) {
      Text(title)
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
    }
    .width('88%')
    .padding(SPACE_CARD)
    .backgroundColor(this.themeColors.surface)
    .borderRadius(20)
    .shadow({
      radius: 14,
      color: this.themeColors.cardShadow,
      offsetX: 0,
      offsetY: 4
    })
  }

  @Builder
  private GoalPickerOverlay() {
    if (this.showGoalPicker) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.themeColors.surfaceOverlay)
          .onClick(() => {
            this.showGoalPicker = false;
          })

        Column({ space: SPACE_MD }) {
          Text('选择目标')
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')

          Scroll() {
            Column({ space: SPACE_SM }) {
              AppButton({
                text: '暂不关联目标',
                variant: this.selectedGoalId ? 'secondary' : 'primary',
                iconName: 'warning',
                tapAction: () => {
                  this.selectedGoalId = '';
                  this.selectedKrId = '';
                  this.showGoalPicker = false;
                }
              })

              if (this.goals.length === 0) {
                AppEmptyState({
                  iconName: 'goal',
                  iconTone: 'primary',
                  title: '当前还没有可选目标',
                  description: '先去创建一个目标，再把任务挂上去会更清晰。'
                })
              } else {
                ForEach(this.goals, (goal: Goal) => {
                  AppButton({
                    text: goal.title,
                    variant: this.selectedGoalId === goal.id ? 'primary' : 'secondary',
                    iconName: 'goal',
                    tapAction: () => {
                      this.selectedGoalId = goal.id;
                      this.selectedKrId = '';
                      this.showGoalPicker = false;
                    }
                  })
                }, (goal: Goal) => goal.id)
              }
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: 320 })
        }
        .width('88%')
        .padding(SPACE_CARD)
        .backgroundColor(this.themeColors.surface)
        .borderRadius(20)
        .shadow({
          radius: 14,
          color: this.themeColors.cardShadow,
          offsetX: 0,
          offsetY: 4
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Center)
    }
  }

  @Builder
  private ReminderPickerOverlay() {
    if (this.showReminderPicker) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.themeColors.surfaceOverlay)
          .onClick(() => {
            this.showReminderPicker = false;
          })

        Column({ space: SPACE_MD }) {
          Text('选择提醒')
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')

          Scroll() {
            Column({ space: SPACE_SM }) {
              AppButton({
                text: '暂不关联提醒',
                variant: this.selectedReminderId ? 'secondary' : 'primary',
                iconName: 'warning',
                tapAction: () => {
                  this.selectedReminderId = '';
                  this.showReminderPicker = false;
                }
              })

              if (this.reminders.length === 0) {
                AppEmptyState({
                  iconName: 'reminder',
                  iconTone: 'info',
                  title: '当前还没有可选提醒',
                  description: '先去创建一个提醒，再把任务挂上来。'
                })
              } else {
                ForEach(this.reminders, (event: DayEvent) => {
                  AppButton({
                    text: event.title,
                    variant: this.selectedReminderId === event.id ? 'primary' : 'secondary',
                    iconName: 'reminder',
                    tapAction: () => {
                      this.selectedReminderId = event.id;
                      this.showReminderPicker = false;
                    }
                  })
                }, (event: DayEvent) => event.id)
              }
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: 320 })
        }
        .width('88%')
        .padding(SPACE_CARD)
        .backgroundColor(this.themeColors.surface)
        .borderRadius(20)
        .shadow({
          radius: 14,
          color: this.themeColors.cardShadow,
          offsetX: 0,
          offsetY: 4
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Center)
    }
  }

  @Builder
  private KrPickerOverlay() {
    if (this.showKrPicker) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.themeColors.surfaceOverlay)
          .onClick(() => {
            this.showKrPicker = false;
          })

        Column({ space: SPACE_MD }) {
          Text('选择衡量标准')
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')

          Scroll() {
            Column({ space: SPACE_SM }) {
              AppButton({
                text: '暂不关联衡量标准',
                variant: this.selectedKrId ? 'secondary' : 'primary',
                iconName: 'warning',
                tapAction: () => {
                  this.selectedKrId = '';
                  this.showKrPicker = false;
                }
              })

              ForEach(this.getSelectedGoal()?.keyResults || [], (kr: KeyResult) => {
                AppButton({
                  text: kr.title,
                  variant: this.selectedKrId === kr.id ? 'primary' : 'secondary',
                  iconName: 'goal',
                  tapAction: () => {
                    this.selectedKrId = kr.id;
                    this.showKrPicker = false;
                  }
                })
              }, (kr: KeyResult) => kr.id)
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: 320 })
        }
        .width('88%')
        .padding(SPACE_CARD)
        .backgroundColor(this.themeColors.surface)
        .borderRadius(20)
        .shadow({
          radius: 14,
          color: this.themeColors.cardShadow,
          offsetX: 0,
          offsetY: 4
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Center)
    }
  }

  @Builder
  private DatePickerOverlay() {
    if (this.showDatePicker) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.themeColors.surfaceOverlay)
          .onClick(() => {
            this.showDatePicker = false;
          })

        Column({ space: SPACE_SM }) {
          Row() {
            Text('选择日期和时间')
              .fontSize(TYPE_SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
            Blank()
            Text('取消')
              .fontSize(TYPE_BODY)
              .fontColor(this.themeColors.textSecondary)
              .onClick(() => {
                this.showDatePicker = false;
              })
            Text('确定')
              .fontSize(TYPE_BODY)
              .fontColor(this.themeColors.primary)
              .margin({ left: SPACE_CARD })
              .onClick(() => {
                this.applyDateSelection();
              })
          }
          .width('100%')

          DatePicker({ selected: this.datePickerDate })
            .onDateChange((value: Date) => {
              this.datePickerDate = value;
            })

          AppCard({ variant: 'soft', spacing: SPACE_SM }) {
            Row({ space: SPACE_SM }) {
              Column({ space: SPACE_2XS }) {
                Text('设置具体时间')
                  .fontSize(TYPE_BODY)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.themeColors.textPrimary)
                  .width('100%')

                Text('关闭后仅保留日期，不包含具体时分。')
                  .fontSize(TYPE_META)
                  .fontColor(this.themeColors.textSecondary)
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: this.hasSelectedTime })
                .selectedColor(this.themeColors.primary)
                .onChange((isOn: boolean) => {
                  this.hasSelectedTime = isOn;
                  if (!isOn) {
                    this.timePickerHour = 0;
                    this.timePickerMinute = 0;
                  }
                })
            }
            .width('100%')

            if (this.hasSelectedTime) {
              TimePicker({ selected: new Date(2026, 0, 1, this.timePickerHour, this.timePickerMinute) })
                .useMilitaryTime(true)
                .onChange((value: TimePickerResult) => {
                  if (value.hour !== undefined && value.minute !== undefined) {
                    this.timePickerHour = value.hour;
                    this.timePickerMinute = value.minute;
                  }
                })
                .height(112)
            }
          }

          if (this.dueDate) {
            AppButton({
              text: '清除日期和时间',
              variant: 'ghost',
              buttonSize: 'sm',
              iconName: 'warning',
              tapAction: () => {
                this.clearDateSelection();
              }
            })
          }
        }
        .width('88%')
        .padding(SPACE_CARD)
        .backgroundColor(this.themeColors.surface)
        .borderRadius(20)
        .shadow({
          radius: 14,
          color: this.themeColors.cardShadow,
          offsetX: 0,
          offsetY: 4
        })
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Center)
    }
  }

  build() {
    Stack() {
      Column() {
        AppPageHeader({
          title: this.getPageTitle(),
          subtitle: '补充上下文、时间和执行边界，让任务更容易被真正做完。',
          onBack: () => {
            this.getUIContext().getRouter().back();
          }
        })

        Scroll() {
          Column({ space: COMFORTABLE_SECTION_GAP }) {
            this.HeroCard()

            if (this.aiFill.shouldShowBanner()) {
              AppAIFillBanner({
                status: this.aiFill.getBannerComponentStatus(),
                title: this.aiFill.getBannerTitle(),
                actionText: this.aiFill.bannerStatus === 'failed' ? '关闭' : '隐藏提示',
                action: () => { this.aiFill.dismiss(); }
              })
            }

            this.TitleCard()
            this.RelationCard()
            this.PriorityCard()
            this.ScheduleCard()
            this.SubtaskCard()
            this.DescriptionCard()
          }
          .width('100%')
          .padding({ left: COMFORTABLE_PAGE_PADDING, right: COMFORTABLE_PAGE_PADDING, top: 4, bottom: COMFORTABLE_PAGE_PADDING + 68 })
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .backgroundColor(this.themeColors.background)

        this.SaveBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeColors.background)

      this.GoalPickerOverlay()
      this.ReminderPickerOverlay()
      this.KrPickerOverlay()
      this.DatePickerOverlay()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
