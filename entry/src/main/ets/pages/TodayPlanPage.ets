import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { cloneSavedTodayPlan, type SavedPlanTaskItem, type SavedTodayPlan, type TodayPlanSource } from '../models/TodayPlan';
import { Task, TaskStatus } from '../models/Task';
import { db } from '../storage/Database';
import { dataSyncService } from '../services/DataSyncService';
import { TodayPlanService } from '../services/TodayPlanService';
import { QuotaService } from '../services/QuotaService';
import { TelemetryService } from '../services/TelemetryService';
import { UsageService } from '../services/UsageService';
import { AgentService } from '../services/AgentService';
import { AppErrorService } from '../services/AppErrorService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppDialogActions } from '../ui/base/AppDialogActions';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppErrorState } from '../ui/base/AppErrorState';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP, SPACE_CARD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('TodayPlanPage');

type PlanTaskAction = 'none' | 'move_to_defer' | 'move_to_focus';

interface TaskSummaryItem {
  id: string;
  title: string;
  dueDate?: number;
  isOverdue: boolean;
  estimatedHours?: number;
  priority: string;
  isImportant: boolean;
}

@Entry
@Component
struct TodayPlanPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State isLoading: boolean = true;
  @State plan: SavedTodayPlan | null = null;
  @State planSource: TodayPlanSource = 'none';
  @State cloudPendingPlan: SavedTodayPlan | null = null;
  @State cloudPendingGeneratedAt: number = 0;
  @State editablePendingPlan: SavedTodayPlan | null = null;
  @State availableTasks: Task[] = [];
  @State showSupplementTasks: boolean = false;
  @State isSaving: boolean = false;
  @State isGeneratingPlan: boolean = false;
  @State emptyMessage: string = '';

  aboutToAppear(): void {
    void this.loadPlan();
  }

  private async loadPlan(): Promise<void> {
    this.isLoading = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      const result = await TodayPlanService.loadPlan(context);
      this.availableTasks = await this.loadAvailableTasks(context);
      this.plan = result.plan;
      this.planSource = result.source;
      this.cloudPendingPlan = result.cloudPendingPlan;
      this.cloudPendingGeneratedAt = result.cloudPendingGeneratedAt || 0;
      const pendingPlan = result.source === 'cloud_pending' ? result.plan : result.cloudPendingPlan;
      this.editablePendingPlan = pendingPlan ? cloneSavedTodayPlan(pendingPlan) : null;
      this.showSupplementTasks = false;
      this.emptyMessage = '';
    } catch (error) {
      logger.error('TodayPlanPage load error', error as Object);
      this.plan = null;
      this.planSource = 'none';
      this.cloudPendingPlan = null;
      this.cloudPendingGeneratedAt = 0;
      this.editablePendingPlan = null;
      this.availableTasks = [];
      this.showSupplementTasks = false;
      this.emptyMessage = AppErrorService.fromUnknown(error, '加载今日计划失败');
    } finally {
      this.isLoading = false;
    }
  }

  private async loadAvailableTasks(context: Context): Promise<Task[]> {
    try {
      if (!db.isInitialized()) {
        await db.initialize(context);
      }
      const syncTasks = dataSyncService.getTasks();
      return (syncTasks.length > 0 ? syncTasks : db.getAllTasks())
        .filter((task: Task) => task.status === TaskStatus.PENDING)
        .sort((first: Task, second: Task) => {
          if (first.isPinned !== second.isPinned) {
            return first.isPinned ? -1 : 1;
          }
          if (first.isOverdue !== second.isOverdue) {
            return first.isOverdue ? -1 : 1;
          }
          return (first.dueDate || Number.MAX_SAFE_INTEGER) - (second.dueDate || Number.MAX_SAFE_INTEGER);
        });
    } catch (error) {
      logger.error('TodayPlanPage loadAvailableTasks error', error as Object);
      return [];
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch (_) {
    }
  }

  private formatDateTime(timestamp?: number): string {
    if (!timestamp) {
      return '今天';
    }
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = `${date.getMonth() + 1}`.padStart(2, '0');
    const day = `${date.getDate()}`.padStart(2, '0');
    const hour = `${date.getHours()}`.padStart(2, '0');
    const minute = `${date.getMinutes()}`.padStart(2, '0');
    return `${year}-${month}-${day} ${hour}:${minute}`;
  }

  private formatHours(hours?: number): string {
    if (!hours || hours <= 0) {
      return '时长待估';
    }
    if (hours < 1) {
      return `${Math.round(hours * 60)} 分钟`;
    }
    return `${hours.toFixed(1)} 小时`;
  }

  private isPendingPreview(): boolean {
    return this.editablePendingPlan !== null;
  }

  private getPendingGeneratedAt(): number {
    if (this.editablePendingPlan && this.editablePendingPlan.sourceGeneratedAt) {
      return this.editablePendingPlan.sourceGeneratedAt;
    }
    return this.cloudPendingGeneratedAt;
  }

  private getSubtitle(): string {
    if (this.isPendingPreview()) {
      const generatedAt = this.getPendingGeneratedAt();
      return generatedAt > 0 ? `生成于 ${this.formatDateTime(generatedAt)}` : 'AI 已为你准备好今日计划';
    }
    if (this.planSource === 'cloud_adopted') {
      return this.plan?.adoptedAt ? `已更新 · ${this.formatDateTime(this.plan.adoptedAt)}` : '已更新';
    }
    if (this.planSource === 'local') {
      return this.plan?.adoptedAt ? `本地计划 · 更新于 ${this.formatDateTime(this.plan.adoptedAt)}` : '本地今日计划';
    }
    return '查看今天的重点任务与执行顺序';
  }

  private getSourceLabel(): string {
    if (this.isPendingPreview()) {
      return 'AI 已生成，等待采纳';
    }
    if (this.planSource === 'cloud_adopted') {
      return 'AI 计划已采纳';
    }
    if (this.planSource === 'local') {
      return '当前为本地执行计划';
    }
    return '今天还没有可用计划';
  }

  private getHeroTitle(): string {
    if (this.isPendingPreview()) {
      return 'AI 已为你排好今天的优先顺序';
    }
    if (this.planSource === 'cloud_adopted') {
      return '今天先按这份 AI 计划推进';
    }
    if (this.planSource === 'local') {
      return '这是你当前采纳中的今日计划';
    }
    return '先确定今天最该做什么';
  }

  private getHeroDescription(): string {
    if (this.isPendingPreview()) {
      return '先调整聚焦与延后任务，再决定是否采纳。采纳后会覆盖当前今日计划，但不会删除原始任务。';
    }
    if (this.planSource === 'cloud_adopted') {
      return '你已经采纳了 AI 方案，现在这份计划会作为今天执行时的参考顺序。';
    }
    if (this.planSource === 'local') {
      return '这份计划来自你本地已确认的安排，你仍然可以继续补任务或重新调整。';
    }
    return '今天没有现成 AI 计划时，也可以先手动挑几件最重要的事开始。';
  }

  private getPlanStats(plan: SavedTodayPlan | null): string {
    if (!plan) {
      return '还没有聚焦任务';
    }
    return `${plan.focusTasks.length} 个聚焦任务 · ${plan.deferTasks.length} 个延后任务 · ${this.formatHours(plan.totalEstimatedHours)}`;
  }

  private getTaskMeta(item: SavedPlanTaskItem): string {
    if (item.estimatedMinutes && item.estimatedMinutes > 0) {
      return `预计 ${item.estimatedMinutes} 分钟`;
    }
    return '已加入今日计划';
  }

  private getPrimaryPlan(): SavedTodayPlan | null {
    return this.editablePendingPlan || this.plan;
  }

  private openTaskDetail(taskId: string): void {
    if (!taskId || taskId.length === 0) {
      return;
    }
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/TaskDetailPage',
        params: { taskId: taskId }
      });
    } catch (error) {
      logger.error('TodayPlanPage openTaskDetail error', error as Object);
      this.showToast('暂时无法打开任务详情');
    }
  }

  private cloneTaskItem(item: SavedPlanTaskItem): SavedPlanTaskItem {
    const cloned: SavedPlanTaskItem = {
      id: item.id,
      title: item.title
    };
    if (item.estimatedMinutes !== undefined) {
      cloned.estimatedMinutes = item.estimatedMinutes;
    }
    if (item.completed !== undefined) {
      cloned.completed = item.completed;
    }
    if (item.reason !== undefined) {
      cloned.reason = item.reason;
    }
    return cloned;
  }

  private buildTaskItem(task: Task, reason: string): SavedPlanTaskItem {
    const item: SavedPlanTaskItem = {
      id: task.id,
      title: task.title,
      reason: reason
    };
    if (task.estimatedHours && task.estimatedHours > 0) {
      item.estimatedMinutes = Math.round(task.estimatedHours * 60);
    }
    item.completed = task.status === TaskStatus.COMPLETED;
    return item;
  }

  private hasPlanItem(plan: SavedTodayPlan, taskId: string): boolean {
    return plan.focusTasks.some((item: SavedPlanTaskItem) => item.id === taskId) ||
      plan.deferTasks.some((item: SavedPlanTaskItem) => item.id === taskId);
  }

  private refreshEditablePlan(plan: SavedTodayPlan): void {
    const totalMinutes = plan.focusTasks.reduce((sum: number, item: SavedPlanTaskItem) => {
      return sum + (item.estimatedMinutes || 0);
    }, 0);
    plan.totalEstimatedHours = totalMinutes > 0 ? totalMinutes / 60 : 0;
    if (plan.focusTasks.length === 0) {
      plan.summary = '当前还没有聚焦任务，可以从延后任务或待办中补充后再采纳。';
    } else if (!plan.summary || plan.summary === '当前还没有聚焦任务，可以从延后任务或待办中补充后再采纳。') {
      plan.summary = `已按你的调整保留 ${plan.focusTasks.length} 个聚焦任务，可采纳为今天的执行计划。`;
    }
    plan.groupedTasks = undefined;
    this.editablePendingPlan = plan;
  }

  private moveFocusTaskToDefer(taskId: string): void {
    if (!this.editablePendingPlan) {
      return;
    }
    const moving = this.editablePendingPlan.focusTasks.find((item: SavedPlanTaskItem) => item.id === taskId);
    if (!moving) {
      return;
    }
    const nextPlan = cloneSavedTodayPlan(this.editablePendingPlan);
    nextPlan.focusTasks = nextPlan.focusTasks.filter((item: SavedPlanTaskItem) => item.id !== taskId);
    if (!nextPlan.deferTasks.some((item: SavedPlanTaskItem) => item.id === taskId)) {
      const deferred = this.cloneTaskItem(moving);
      deferred.reason = '已从今日重点移出，采纳时先延后处理';
      nextPlan.deferTasks = [deferred, ...nextPlan.deferTasks];
    }
    this.refreshEditablePlan(nextPlan);
    this.showToast('已移到延后任务');
  }

  private moveDeferredTaskToFocus(taskId: string): void {
    if (!this.editablePendingPlan) {
      return;
    }
    const moving = this.editablePendingPlan.deferTasks.find((item: SavedPlanTaskItem) => item.id === taskId);
    if (!moving) {
      return;
    }
    const nextPlan = cloneSavedTodayPlan(this.editablePendingPlan);
    nextPlan.deferTasks = nextPlan.deferTasks.filter((item: SavedPlanTaskItem) => item.id !== taskId);
    if (!nextPlan.focusTasks.some((item: SavedPlanTaskItem) => item.id === taskId)) {
      const focused = this.cloneTaskItem(moving);
      focused.reason = focused.reason || '手动调整为今日重点';
      nextPlan.focusTasks = [...nextPlan.focusTasks, focused];
    }
    this.refreshEditablePlan(nextPlan);
    this.showToast('已移到聚焦任务');
  }

  private addTaskToFocus(task: Task): void {
    if (!this.editablePendingPlan) {
      return;
    }
    const nextPlan = cloneSavedTodayPlan(this.editablePendingPlan);
    if (nextPlan.focusTasks.some((item: SavedPlanTaskItem) => item.id === task.id)) {
      this.showToast('任务已在聚焦任务中');
      return;
    }
    nextPlan.deferTasks = nextPlan.deferTasks.filter((item: SavedPlanTaskItem) => item.id !== task.id);
    nextPlan.focusTasks = [...nextPlan.focusTasks, this.buildTaskItem(task, '手动补充到今日重点')];
    this.refreshEditablePlan(nextPlan);
    this.showToast('已加入聚焦任务');
  }

  private getSupplementTasks(): Task[] {
    const plan = this.editablePendingPlan;
    if (!plan) {
      return [];
    }
    return this.availableTasks.filter((task: Task) => !this.hasPlanItem(plan, task.id));
  }

  private getTaskMetaFromTask(task: Task): string {
    const parts: string[] = [];
    if (task.isOverdue) {
      parts.push('已逾期');
    } else if (task.deadline) {
      parts.push(task.deadline);
    } else {
      parts.push('未设置截止时间');
    }
    if (task.estimatedHours && task.estimatedHours > 0) {
      parts.push(`预计 ${this.formatHours(task.estimatedHours)}`);
    }
    return parts.join(' · ');
  }

  private async adoptPlan(plan: SavedTodayPlan | null): Promise<void> {
    if (!plan || this.isSaving) {
      return;
    }

    this.isSaving = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      const spendResult = await QuotaService.incrementTodayPlanCount(context);
      if (!spendResult.success) {
        if (spendResult.requireMembership) {
          this.showToast('采纳 AI 今日计划需要会员或可用配额');
        } else {
          this.showToast(AppErrorService.fromMessage(spendResult.message || '暂时无法采纳当前计划', '暂时无法采纳当前计划'));
        }
        return;
      }

      const result = await TodayPlanService.saveAdoptedPlan(context, plan);
      if (!result.success) {
        this.showToast(AppErrorService.fromMessage(result.message, '今日计划更新失败'));
        return;
      }

      void UsageService.reportAIFeatureUsage('today_plan', 'adopt');
      TelemetryService.track('ai_plan_adopted', undefined, 'ai');
      this.showToast('今日计划已更新');
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/MainPage' });
    } catch (error) {
      logger.error('TodayPlanPage adopt error', error as Object);
      this.showToast('更新失败，请稍后重试');
    } finally {
      this.isSaving = false;
    }
  }

  private async handleGeneratePlan(): Promise<void> {
    if (this.isGeneratingPlan) {
      return;
    }
    const context = this.getUIContext().getHostContext() as Context;

    this.isGeneratingPlan = true;
    try {
      const pendingTasks = this.availableTasks.length > 0
        ? this.availableTasks
        : await this.loadAvailableTasks(context);
      if (pendingTasks.length === 0) {
        this.showToast('当前没有待办任务，请先创建任务');
        return;
      }
      const summaryItems: TaskSummaryItem[] = pendingTasks.map((task: Task) => {
        const item: TaskSummaryItem = {
          id: task.id,
          title: task.title,
          isOverdue: task.isOverdue,
          priority: task.priority || 'normal',
          isImportant: task.isImportant || false
        };
        if (task.dueDate !== undefined) {
          item.dueDate = task.dueDate;
        }
        if (task.estimatedHours !== undefined) {
          item.estimatedHours = task.estimatedHours;
        }
        return item;
      });
      const summary = JSON.stringify(summaryItems);
      const generated = await AgentService.generateTodayPlan(summary);
      if (!generated || (!generated.focusTasks.length && !generated.deferTasks.length)) {
        this.showToast('AI 暂时无法生成有效计划，请手动选择任务');
        return;
      }
      const taskMap: Record<string, Task> = {};
      pendingTasks.forEach((task: Task) => {
        taskMap[task.id] = task;
      });

      const pendingPlan: SavedTodayPlan = {
        focusTasks: (generated.focusTasks || []).map((fItem) => {
          const resolvedTask = taskMap[fItem.id];
          const taskItem: SavedPlanTaskItem = {
            id: fItem.id,
            title: resolvedTask ? resolvedTask.title : fItem.id
          };
          taskItem.reason = fItem.reason || 'AI 推荐今日聚焦';
          if (resolvedTask && resolvedTask.estimatedHours && resolvedTask.estimatedHours > 0) {
            taskItem.estimatedMinutes = Math.round(resolvedTask.estimatedHours * 60);
          }
          return taskItem;
        }),
        deferTasks: (generated.deferTasks || []).map((taskId: string) => {
          const resolvedTask = taskMap[taskId];
          const taskItem: SavedPlanTaskItem = {
            id: taskId,
            title: resolvedTask ? resolvedTask.title : taskId
          };
          taskItem.reason = '建议延后，释放今天带宽';
          return taskItem;
        }),
        summary: generated.summary || 'AI 今日计划',
        totalEstimatedHours: generated.totalEstimatedHours,
        groupedTasks: generated.groupedTasks,
        planSource: 'cloud_pending',
        sourceGeneratedAt: Date.now()
      };
      this.cloudPendingPlan = pendingPlan;
      this.cloudPendingGeneratedAt = Date.now();
      this.editablePendingPlan = cloneSavedTodayPlan(pendingPlan);
      this.showSupplementTasks = false;
      this.emptyMessage = '';
      this.showToast('AI 计划已生成，请调整后采纳');
    } catch (error) {
      logger.error('TodayPlanPage generatePlan error', error as Object);
      this.showToast('AI 生成失败，请稍后重试');
    } finally {
      this.isGeneratingPlan = false;
    }
  }

  @Builder
  private HeroCard() {
    AppCard({ variant: 'soft', spacing: SPACE_SM }) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        AppStatusBadge({ text: 'AI 今日计划', tone: 'primary', iconName: 'ai' })
        AppStatusBadge({
          text: this.getSourceLabel(),
          tone: this.isPendingPreview() ? 'info' : 'neutral',
          iconName: this.isPendingPreview() ? 'info' : 'success'
        })
      }
      .width('100%')

      Text(this.getHeroTitle())
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Text(this.getHeroDescription())
        .fontSize(TYPE_BODY)
        .lineHeight(22)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Text(this.getPlanStats(this.getPrimaryPlan()))
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textMuted)
        .width('100%')
    }
  }

  @Builder
  private TaskCard(item: SavedPlanTaskItem, label: string, tone: 'primary' | 'warning', action: PlanTaskAction) {
    AppCard({
      variant: tone === 'warning' ? 'soft' : 'base',
      spacing: SPACE_XS,
      interactive: true,
      tapAction: () => {
        this.openTaskDetail(item.id);
      }
    }) {
      Row({ space: 10 }) {
        Text(item.title)
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        AppStatusBadge({ text: label, tone: tone, iconName: tone === 'warning' ? 'warning' : 'focus' })
      }
      .width('100%')

      Text(this.getTaskMeta(item))
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textMuted)
        .width('100%')

      Text(item.reason || '已加入今日计划')
        .fontSize(TYPE_BODY)
        .lineHeight(22)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      if (action !== 'none') {
        Row({ space: 8 }) {
          Blank()
          AppButton({
            text: action === 'move_to_focus' ? '移到聚焦' : '移到延后',
            variant: action === 'move_to_focus' ? 'secondary' : 'ghost',
            buttonSize: 'sm',
            iconName: action === 'move_to_focus' ? 'focus' : 'plan',
            tapAction: () => {
              if (action === 'move_to_focus') {
                this.moveDeferredTaskToFocus(item.id);
              } else {
                this.moveFocusTaskToDefer(item.id);
              }
            }
          })
        }
        .width('100%')
      }
    }
  }

  @Builder
  private SupplementTaskCard(task: Task) {
    AppCard({
      variant: 'base',
      spacing: SPACE_XS,
      interactive: true,
      tapAction: () => {
        this.openTaskDetail(task.id);
      }
    }) {
      Row({ space: 10 }) {
        Text(task.title)
          .layoutWeight(1)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (task.isOverdue) {
          AppStatusBadge({ text: '逾期', tone: 'danger', iconName: 'warning' })
        }
      }
      .width('100%')

      Text(task.goalTitle || '未关联目标')
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Text(this.getTaskMetaFromTask(task))
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textMuted)
        .width('100%')

      Row({ space: 8 }) {
        Blank()
        AppButton({
          text: '加入聚焦',
          variant: 'secondary',
          buttonSize: 'sm',
          iconName: 'focus',
          tapAction: () => {
            this.addTaskToFocus(task);
          }
        })
      }
      .width('100%')
    }
  }

  @Builder
  private SupplementTaskSection() {
    Column({ space: SPACE_SM }) {
      Text('补充任务')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      if (this.getSupplementTasks().length === 0) {
        AppEmptyState({
          iconName: 'task',
          iconTone: 'info',
          title: '没有可补充的待办任务',
          description: '所有可用待办已经在聚焦或延后任务里。'
        })
      } else {
        ForEach(this.getSupplementTasks(), (task: Task) => {
          this.SupplementTaskCard(task)
        }, (task: Task) => task.id)
      }
    }
    .width('100%')
  }

  @Builder
  private PlanSummaryCard(plan: SavedTodayPlan) {
    AppCard({ variant: 'base', spacing: SPACE_SM }) {
      Text('计划摘要')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')

      Text(plan.summary)
        .fontSize(TYPE_BODY)
        .lineHeight(22)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  @Builder
  private BottomActionBar() {
    Column({ space: SPACE_SM }) {
      if (!this.getPrimaryPlan()) {
        AppDialogActions({
          secondaryText: '手动选择任务',
          primaryText: this.isGeneratingPlan ? '生成中...' : 'AI 生成计划',
          primaryIconName: 'ai',
          primaryLoading: this.isGeneratingPlan,
          primaryDisabled: this.isGeneratingPlan,
          onSecondary: () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/TaskSelectPage' });
          },
          onPrimary: () => {
            void this.handleGeneratePlan();
          }
        })
      } else if (this.isPendingPreview()) {
        AppDialogActions({
          secondaryText: this.showSupplementTasks ? '收起补充' : '补充任务',
          primaryText: '采纳并更新今天',
          primaryLoading: this.isSaving,
          primaryDisabled: this.isSaving,
          onSecondary: () => {
            this.showSupplementTasks = !this.showSupplementTasks;
          },
          onPrimary: () => {
            void this.adoptPlan(this.editablePendingPlan);
          }
        })
      } else {
        AppDialogActions({
          secondaryText: '继续补任务',
          primaryText: '返回首页',
          secondaryIconName: 'plus',
          onSecondary: () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/TaskSelectPage' });
          },
          onPrimary: () => {
            this.getUIContext().getRouter().back();
          }
        })
      }
    }
    .width('100%')
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: SPACE_SM, bottom: SPACE_CARD })
    .backgroundColor(this.themeColors.background)
  }

  build() {
    Column() {
      AppPageHeader({
        title: 'AI 今日计划',
        subtitle: this.getSubtitle(),
        onBack: () => {
          this.getUIContext().getRouter().back();
        }
      })

      if (this.isLoading) {
        Column() {
          AppLoadingState({ label: '正在准备今天的计划视图...' })
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING })
      } else {
        Scroll() {
          Column({ space: SECTION_GAP }) {
            this.HeroCard()

            if (!this.getPrimaryPlan() && this.emptyMessage.length > 0) {
              AppErrorState({
                title: '今日计划加载失败',
                description: this.emptyMessage,
                actionText: '重新加载',
                onAction: () => {
                  void this.loadPlan();
                }
              })
            } else if (!this.getPrimaryPlan()) {
              AppEmptyState({
                iconName: 'plan',
                iconTone: 'primary',
                title: '今天还没有可用计划',
                description: '暂时还没有预生成结果。你可以让 AI 根据当前待办即时生成一份计划，也可以手动挑选任务。',
                actionText: this.isGeneratingPlan ? '生成中...' : 'AI 生成计划',
                actionIconName: 'ai',
                onAction: () => {
                  void this.handleGeneratePlan();
                }
              })
            } else {
              this.PlanSummaryCard(this.getPrimaryPlan() as SavedTodayPlan)

              Column({ space: SPACE_SM }) {
                Text('聚焦任务')
                  .fontSize(TYPE_SECTION_TITLE)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.themeColors.textPrimary)
                  .width('100%')

                if ((this.getPrimaryPlan() as SavedTodayPlan).focusTasks.length === 0) {
                  AppEmptyState({
                    iconName: 'focus',
                    iconTone: 'primary',
                    title: '聚焦任务为空',
                    description: this.isPendingPreview()
                      ? '可以从延后任务或待办中补充后再采纳。'
                      : '当前计划里还没有今日重点。'
                  })
                } else {
                  ForEach((this.getPrimaryPlan() as SavedTodayPlan).focusTasks, (item: SavedPlanTaskItem) => {
                    this.TaskCard(item, '今日重点', 'primary', this.isPendingPreview() ? 'move_to_defer' : 'none')
                  }, (item: SavedPlanTaskItem) => item.id)
                }
              }
              .width('100%')

              if (this.isPendingPreview() && this.showSupplementTasks) {
                this.SupplementTaskSection()
              }

              if ((this.getPrimaryPlan() as SavedTodayPlan).deferTasks.length > 0) {
                Column({ space: SPACE_SM }) {
                  Text('延后任务')
                    .fontSize(TYPE_SECTION_TITLE)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.themeColors.textPrimary)
                    .width('100%')

                  ForEach((this.getPrimaryPlan() as SavedTodayPlan).deferTasks, (item: SavedPlanTaskItem) => {
                    this.TaskCard(item, '稍后处理', 'warning', this.isPendingPreview() ? 'move_to_focus' : 'none')
                  }, (item: SavedPlanTaskItem) => item.id)
                }
                .width('100%')
              }
            }

            Row()
              .width('100%')
              .height(96)
          }
          .width('100%')
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 16 })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)

        this.BottomActionBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
