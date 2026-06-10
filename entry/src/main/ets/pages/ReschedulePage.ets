import promptAction from '@ohos.promptAction';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { Task } from '../models/Task';
import {
  AgentService,
  type RescheduleItemWithReason,
  type RescheduleJobStatus,
  type RescheduleResult,
  type RescheduleSplitItem,
  type RescheduleWeekItem
} from '../services/AgentService';
import { authService } from '../services/AuthService';
import { QuotaService, type QuotaResult } from '../services/QuotaService';
import { RescheduleService } from '../services/RescheduleService';
import { UsageService } from '../services/UsageService';
import { TelemetryService, type TelemetryProperties } from '../services/TelemetryService';
import { AppErrorService } from '../services/AppErrorService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppEmptyState } from '../ui/base/AppEmptyState';
import { AppLoadingState } from '../ui/base/AppLoadingState';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SECTION_GAP, SPACE_2XS, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_HERO_TITLE, TYPE_META, TYPE_NUMERIC_MD, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('ReschedulePage');

type SuggestionGroup = 'tomorrow' | 'thisWeek' | 'downgrade' | 'split' | 'shelve' | 'delete';
type AdjustmentTarget = 'tomorrow' | 'thisWeek' | 'downgrade' | 'shelve' | 'delete';

interface AdjustmentOption {
  label: string;
  target: AdjustmentTarget;
}

@Entry
@Component
struct ReschedulePage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State tasks: Task[] = [];
  @State overdueTasks: Task[] = [];
  @State futureTasks: Task[] = [];
  @State isLoading: boolean = true;
  @State isGenerating: boolean = false;
  @State isApplying: boolean = false;
  @State result: RescheduleResult | null = null;
  @State includeDeleteSuggestions: boolean = false;
  @State errorMessage: string = '';
  @State quotaHint: string = '';
  @State generationProgressCurrent: number = 0;
  @State generationProgressTotal: number = 0;
  @State generationProgressPercent: number = 0;
  @State generationProgressMessage: string = '';
  @State generationProgressPhase: string = 'queued';
  private readonly overduePreviewLimit: number = 6;
  private generationActive: boolean = false;

  aboutToAppear(): void {
    void this.loadTasks();
  }

  aboutToDisappear(): void {
    this.generationActive = false;
  }

  private async loadTasks(): Promise<void> {
    this.isLoading = true;
    try {
      const context = this.getUIContext().getHostContext() as Context;
      const pendingTasks = await RescheduleService.loadPendingTasks(context);
      this.tasks = pendingTasks;
      this.overdueTasks = RescheduleService.getOverdueTasks(pendingTasks);
      this.futureTasks = RescheduleService.getFutureTasks(pendingTasks);
      const quota = await QuotaService.checkRescheduleQuota(context);
      this.quotaHint = this.getQuotaHint(quota);
    } catch (error) {
      logger.error('ReschedulePage load error', error as Object);
      this.tasks = [];
      this.overdueTasks = [];
      this.futureTasks = [];
      this.quotaHint = '';
    } finally {
      this.isLoading = false;
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch (_) {
    }
  }

  private getTaskTitle(taskId: string): string {
    const matchedTask = this.tasks.find((task: Task) => task.id === taskId);
    return matchedTask ? matchedTask.title : taskId;
  }

  private formatDateText(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
  }

  private getLaterSuggestionDate(): string {
    const date = new Date();
    date.setDate(date.getDate() + 2);
    date.setHours(0, 0, 0, 0);
    return this.formatDateText(date.getTime());
  }

  private getGroupLabel(group: SuggestionGroup): string {
    if (group === 'tomorrow') {
      return '明天继续';
    }
    if (group === 'thisWeek') {
      return '本周稍后';
    }
    if (group === 'downgrade') {
      return '降低优先级';
    }
    if (group === 'split') {
      return '拆分任务';
    }
    if (group === 'shelve') {
      return '暂缓处理';
    }
    return '删除';
  }

  private getAdjustmentTargetLabel(target: AdjustmentTarget): string {
    if (target === 'tomorrow') {
      return '明天继续';
    }
    if (target === 'thisWeek') {
      return '后续处理';
    }
    if (target === 'downgrade') {
      return '降低优先级';
    }
    if (target === 'shelve') {
      return '暂缓处理';
    }
    return '删除';
  }

  private getSectionTitle(group: SuggestionGroup): string {
    if (group === 'tomorrow') {
      return '明天继续';
    }
    if (group === 'thisWeek') {
      return '本周稍后';
    }
    if (group === 'downgrade') {
      return '降低优先级';
    }
    if (group === 'split') {
      return '建议拆分';
    }
    if (group === 'shelve') {
      return '暂缓处理';
    }
    return '删除建议';
  }

  private getSectionHint(group: SuggestionGroup): string {
    if (group === 'tomorrow') {
      return '只保留少量真正要明天接住的任务';
    }
    if (group === 'thisWeek') {
      return '延后处理，不再强塞进明天';
    }
    if (group === 'downgrade') {
      return '继续保留，但主动下调优先级';
    }
    if (group === 'split') {
      return '先降低启动门槛，再逐步推进';
    }
    if (group === 'shelve') {
      return '明确先不做，先减压';
    }
    return '高风险操作，默认不会自动执行';
  }

  private getSectionDescription(group: SuggestionGroup): string {
    if (group === 'tomorrow') {
      return '这一组代表最值得继续承接的少量任务，应该是短、重要、且明天确实做得动的事项。';
    }
    if (group === 'thisWeek') {
      return '这一组不是放弃，而是有意识地延后到本周更合适的日期，避免明天继续过载。';
    }
    if (group === 'downgrade') {
      return '这一组仍会保留在待办里，但不再和核心事项抢同等注意力。';
    }
    if (group === 'split') {
      return '这一组不要求你一次做完，重点是先拆成更容易开始的小步骤。';
    }
    if (group === 'shelve') {
      return '这一组表示近期先移出主战场，避免低价值事项反复制造心理负担。';
    }
    return '这一组只是在提醒你这些任务可能可以删，但是否真的删除，仍由你最后决定。';
  }

  private getSectionTone(group: SuggestionGroup): 'primary' | 'warning' | 'neutral' | 'danger' {
    if (group === 'tomorrow' || group === 'thisWeek' || group === 'split') {
      return 'primary';
    }
    if (group === 'downgrade') {
      return 'warning';
    }
    if (group === 'delete') {
      return 'danger';
    }
    return 'neutral';
  }

  private getSectionVariant(group: SuggestionGroup): 'accent' | 'soft' | 'danger' {
    if (group === 'tomorrow' || group === 'thisWeek' || group === 'split') {
      return 'accent';
    }
    if (group === 'delete') {
      return 'danger';
    }
    return 'soft';
  }

  private getSectionIcon(group: SuggestionGroup): string {
    if (group === 'tomorrow') {
      return 'calendar';
    }
    if (group === 'thisWeek') {
      return 'time';
    }
    if (group === 'downgrade') {
      return 'warning';
    }
    if (group === 'split') {
      return 'task';
    }
    if (group === 'shelve') {
      return 'archive';
    }
    return 'warning';
  }

  private cloneResult(result: RescheduleResult): RescheduleResult {
    return {
      tomorrowTasks: [...(result.tomorrowTasks || [])],
      thisWeekTasks: [...(result.thisWeekTasks || [])],
      downgradeTasks: [...(result.downgradeTasks || [])],
      splitTasks: (result.splitTasks || []).map((item: RescheduleSplitItem) => {
        const copy: RescheduleSplitItem = {
          id: item.id,
          subTasks: [...item.subTasks],
          reason: item.reason
        };
        return copy;
      }),
      shelveTasks: [...(result.shelveTasks || [])],
      deleteTasks: [...(result.deleteTasks || [])],
      summary: result.summary,
      errorMsg: result.errorMsg
    };
  }

  private removeTaskFromResult(result: RescheduleResult, taskId: string): void {
    result.tomorrowTasks = (result.tomorrowTasks || []).filter((item: RescheduleItemWithReason) => item.id !== taskId);
    result.thisWeekTasks = (result.thisWeekTasks || []).filter((item: RescheduleWeekItem) => item.id !== taskId);
    result.downgradeTasks = (result.downgradeTasks || []).filter((item: RescheduleItemWithReason) => item.id !== taskId);
    result.splitTasks = (result.splitTasks || []).filter((item: RescheduleSplitItem) => item.id !== taskId);
    result.shelveTasks = (result.shelveTasks || []).filter((item: RescheduleItemWithReason) => item.id !== taskId);
    result.deleteTasks = (result.deleteTasks || []).filter((item: RescheduleItemWithReason) => item.id !== taskId);
  }

  private getAdjustmentOptions(group: SuggestionGroup): AdjustmentOption[] {
    if (group === 'tomorrow') {
      return [
        { label: '移到后续', target: 'thisWeek' },
        { label: '降低优先级', target: 'downgrade' },
        { label: '删除', target: 'delete' }
      ];
    }
    if (group === 'thisWeek') {
      return [
        { label: '改成明天继续', target: 'tomorrow' },
        { label: '暂时搁置', target: 'shelve' },
        { label: '删除', target: 'delete' }
      ];
    }
    if (group === 'downgrade') {
      return [
        { label: '改成明天继续', target: 'tomorrow' },
        { label: '移到后续', target: 'thisWeek' },
        { label: '删除', target: 'delete' }
      ];
    }
    if (group === 'split') {
      return [
        { label: '改成明天继续', target: 'tomorrow' },
        { label: '移到后续', target: 'thisWeek' },
        { label: '删除', target: 'delete' }
      ];
    }
    if (group === 'shelve') {
      return [
        { label: '改成明天继续', target: 'tomorrow' },
        { label: '移到后续', target: 'thisWeek' },
        { label: '删除', target: 'delete' }
      ];
    }
    return [
      { label: '改成明天继续', target: 'tomorrow' },
      { label: '移到后续', target: 'thisWeek' },
      { label: '降低优先级', target: 'downgrade' }
    ];
  }

  private applyManualAdjustment(taskId: string, target: AdjustmentTarget): void {
    if (!this.result) {
      return;
    }

    const nextResult = this.cloneResult(this.result);
    this.removeTaskFromResult(nextResult, taskId);

    if (target === 'tomorrow') {
      nextResult.tomorrowTasks = nextResult.tomorrowTasks || [];
      nextResult.tomorrowTasks.push({
        id: taskId,
        reason: '已改为明天继续，后续将按你的手动选择执行。'
      });
    } else if (target === 'thisWeek') {
      nextResult.thisWeekTasks = nextResult.thisWeekTasks || [];
      nextResult.thisWeekTasks.push({
        id: taskId,
        newDate: this.getLaterSuggestionDate(),
        reason: '已改为后续处理，系统会尽量错开到更合适的日期。'
      });
    } else if (target === 'downgrade') {
      nextResult.downgradeTasks = nextResult.downgradeTasks || [];
      nextResult.downgradeTasks.push({
        id: taskId,
        reason: '已改为降低优先级，避免继续挤占当前注意力。'
      });
    } else if (target === 'shelve') {
      nextResult.shelveTasks = nextResult.shelveTasks || [];
      nextResult.shelveTasks.push({
        id: taskId,
        reason: '已改为暂缓处理，先移出当前恢复范围。'
      });
    } else {
      nextResult.deleteTasks = nextResult.deleteTasks || [];
      nextResult.deleteTasks.push({
        id: taskId,
        reason: '已手动改为删除，应用建议时会一并处理。'
      });
      this.includeDeleteSuggestions = true;
    }

    this.result = RescheduleService.normalizeResult(nextResult, this.tasks);
    if ((this.result.deleteTasks || []).length === 0) {
      this.includeDeleteSuggestions = false;
    }

    const taskTitle = this.getTaskTitle(taskId);
    const targetLabel = this.getAdjustmentTargetLabel(target);
    if (target === 'delete') {
      this.showToast(`已将“${taskTitle}”改为${targetLabel}，并自动纳入应用`);
      return;
    }
    this.showToast(`已将“${taskTitle}”改为${targetLabel}`);
  }

  private showTaskAdjustmentMenu(taskId: string, group: SuggestionGroup): void {
    if (this.isApplying || this.isGenerating) {
      return;
    }

    const taskTitle = this.getTaskTitle(taskId);
    const options = this.getAdjustmentOptions(group);
    const optionButtons = options.map((option: AdjustmentOption) => {
      const btn: AlertDialogButtonOptions = {
        value: option.label,
        action: () => {
          this.applyManualAdjustment(taskId, option.target);
        }
      };
      return btn;
    });
    const cancelBtn: AlertDialogButtonOptions = {
      value: '取消',
      action: () => {}
    };
    const allButtons: AlertDialogButtonOptions[] = [...optionButtons, cancelBtn];
    this.getUIContext().showAlertDialog({
      title: '调整单条建议',
      message: `当前建议：${this.getGroupLabel(group)}\n任务：${taskTitle}\n请选择新的处理方式`,
      buttons: allButtons
    });
  }

  private getQuotaHint(quota: QuotaResult): string {
    if (quota.limit > 9999) {
      return '会员不限次数';
    }
    return `本月剩余 ${quota.remaining}/${quota.limit} 次`;
  }

  private getHeroTitle(): string {
    if (this.isGenerating) {
      return 'AI 正在整理今天的积压';
    }
    if (this.result) {
      return '先看差异，再决定是否采纳';
    }
    if (this.overdueTasks.length === 0) {
      return '今天暂时不需要 AI 重排';
    }
    return '把积压任务拆成更容易恢复执行的方案';
  }

  private getHeroDescription(): string {
    if (this.isGenerating) {
      return '会综合逾期任务和接下来几天的安排，把高压状态拆成更容易接受的恢复计划。';
    }
    if (this.result) {
      return '现在看到的是建议预览。只有你点击应用后，任务日期、优先级和状态才会真正更新。';
    }
    if (this.overdueTasks.length === 0) {
      return '没有逾期任务时，不必为了整理而整理。等真正出现积压，再集中处理更合适。';
    }
    return 'AI 会把任务分成“明天继续、本周稍后、降低优先级、拆分、暂缓”几类，帮你快速恢复秩序。';
  }

  private getSuggestionSummary(): string {
    if (!this.result) {
      return `当前有 ${this.overdueTasks.length} 项逾期任务，未来 7 天内还有 ${this.futureTasks.length} 项已安排任务。`;
    }

    return `${this.getTomorrowTasks().length} 项明天继续 · ${this.getThisWeekTasks().length} 项本周稍后 · ${
      this.getDowngradeTasks().length
    } 项降级 · ${this.getSplitTasks().length} 项拆分 · ${this.getShelveTasks().length} 项暂缓${
      this.getDeleteTasks().length > 0 ? ` · ${this.getDeleteTasks().length} 项可删` : ''
    }`;
  }

  private hasSuggestions(): boolean {
    return this.getTomorrowTasks().length > 0 ||
      this.getThisWeekTasks().length > 0 ||
      this.getDowngradeTasks().length > 0 ||
      this.getSplitTasks().length > 0 ||
      this.getShelveTasks().length > 0 ||
      this.getDeleteTasks().length > 0;
  }

  private getTomorrowTasks(): RescheduleItemWithReason[] {
    return this.result?.tomorrowTasks || [];
  }

  private getThisWeekTasks(): RescheduleWeekItem[] {
    return this.result?.thisWeekTasks || [];
  }

  private getDowngradeTasks(): RescheduleItemWithReason[] {
    return this.result?.downgradeTasks || [];
  }

  private getSplitTasks(): RescheduleSplitItem[] {
    return this.result?.splitTasks || [];
  }

  private getShelveTasks(): RescheduleItemWithReason[] {
    return this.result?.shelveTasks || [];
  }

  private getDeleteTasks(): RescheduleItemWithReason[] {
    return this.result?.deleteTasks || [];
  }

  private getOverduePreviewTasks(): Task[] {
    return this.overdueTasks.slice(0, this.overduePreviewLimit);
  }

  private getHiddenOverdueCount(): number {
    return Math.max(0, this.overdueTasks.length - this.getOverduePreviewTasks().length);
  }

  private getOverduePreviewSummaryText(): string {
    if (this.getHiddenOverdueCount() > 0) {
      return `下方仅预览最早到期的 ${this.getOverduePreviewTasks().length} 项，其余 ${this.getHiddenOverdueCount()} 项会一起参与 AI 分析。`;
    }
    return '下方展示全部当前逾期任务。';
  }

  private getGenerationProgressBarWidth(): string {
    return `${Math.max(3, Math.min(100, this.generationProgressPercent))}%`;
  }

  private resetGenerationProgress(): void {
    this.generationProgressCurrent = 0;
    this.generationProgressTotal = Math.max(1, this.overdueTasks.length);
    this.generationProgressPercent = 0;
    this.generationProgressMessage = '等待服务端创建重排任务';
    this.generationProgressPhase = 'queued';
  }

  private getGenerationPhaseText(phase: string): string {
    if (phase === 'preparing') {
      return '校验积压任务';
    }
    if (phase === 'context') {
      return '构建任务上下文';
    }
    if (phase === 'ai_generating') {
      return 'AI 生成方案';
    }
    if (phase === 'parsing') {
      return '解析校验建议';
    }
    if (phase === 'completed') {
      return '重排建议已生成';
    }
    if (phase === 'failed') {
      return '生成失败';
    }
    return '等待开始';
  }

  private getGenerationProgressLabel(): string {
    if (this.generationProgressPhase === 'preparing') {
      return `进行中 ${this.generationProgressCurrent}/${this.generationProgressTotal}`;
    }
    return `${this.generationProgressPercent}%`;
  }

  private applyGenerationStatus(status: RescheduleJobStatus): void {
    this.generationProgressCurrent = Math.max(0, status.current);
    this.generationProgressTotal = Math.max(1, status.total);
    this.generationProgressPercent = Math.max(0, Math.min(100, status.percent));
    this.generationProgressMessage = status.message || this.getGenerationPhaseText(status.phase);
    this.generationProgressPhase = status.phase || status.status;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  private async waitForRescheduleJob(jobId: string): Promise<RescheduleJobStatus> {
    let latest = await AgentService.getRescheduleJobStatus(jobId);
    this.applyGenerationStatus(latest);
    while (this.generationActive && latest.status !== 'completed' && latest.status !== 'failed') {
      await this.sleep(1200);
      latest = await AgentService.getRescheduleJobStatus(jobId);
      this.applyGenerationStatus(latest);
    }
    return latest;
  }

  private async showQuotaDialog(): Promise<void> {
    try {
      const dialogResult = await this.getUIContext().getPromptAction().showDialog({
        title: '本月额度已用完',
        message: '基础会员每月可用 5 次 AI 一键整理。升级高级会员后可继续使用。',
        buttons: [
          { text: '稍后再说', color: this.themeColors.textMuted },
          { text: '立即升级', color: this.themeColors.premium }
        ]
      }) as promptAction.ShowDialogSuccessResponse;
      if (dialogResult.index === 1) {
        this.getUIContext().getRouter().pushUrl({ url: 'pages/MembershipPage' });
      }
    } catch (_) {
    }
  }

  private async generateSuggestion(): Promise<void> {
    if (this.isGenerating) {
      return;
    }
    if (this.overdueTasks.length === 0) {
      this.showToast('当前没有逾期任务可整理');
      return;
    }
    if (!(await authService.checkLoginWithPrompt(this.getUIContext()))) {
      return;
    }

    const context = this.getUIContext().getHostContext() as Context;
    const quota = await QuotaService.checkRescheduleQuota(context);
    if (!quota.allowed) {
      await this.showQuotaDialog();
      return;
    }

    const spendResult = await QuotaService.incrementRescheduleCount(context);
    if (!spendResult.success) {
      this.showToast(AppErrorService.fromMessage(spendResult.message || '暂时无法使用 AI 重排', '暂时无法使用 AI 重排'));
      if (spendResult.requireMembership) {
        await this.showQuotaDialog();
      }
      return;
    }

    this.isGenerating = true;
    this.errorMessage = '';
    this.generationActive = true;
    this.resetGenerationProgress();
    try {
      const triggerProps: TelemetryProperties = {
        "overdueCount": this.overdueTasks.length
      };
      TelemetryService.track('ai_reschedule_triggered', triggerProps, 'ai');

      const overdueSummary = RescheduleService.buildOverdueTasksSummary(this.overdueTasks);
      const futureSummary = RescheduleService.buildFutureTasksSummary(this.futureTasks);
      const startedJob = await AgentService.startRescheduleJob(
        overdueSummary,
        futureSummary,
        this.overdueTasks.length
      );
      this.applyGenerationStatus(startedJob);

      const finalStatus = await this.waitForRescheduleJob(startedJob.jobId);
      if (!this.generationActive && finalStatus.status !== 'completed' && finalStatus.status !== 'failed') {
        return;
      }
      if (finalStatus.status !== 'completed' || !finalStatus.result) {
        throw new Error(finalStatus.error || finalStatus.message || 'AI 重排失败');
      }

      this.result = RescheduleService.normalizeResult(finalStatus.result, this.tasks);
      this.includeDeleteSuggestions = false;

      if (!this.hasSuggestions() && (!this.result.summary || this.result.summary.length === 0)) {
        this.showToast('AI 暂时没有给出可执行建议');
      }
    } catch (error) {
      const failureMessage = AppErrorService.fromUnknown(error, 'AI 重排失败，请稍后重试');
      logger.error('ReschedulePage generate error:', failureMessage as Object);
      this.errorMessage = failureMessage;
      this.showToast(failureMessage);
    } finally {
      this.generationActive = false;
      this.isGenerating = false;
    }
  }

  private async confirmDeleteSuggestions(): Promise<boolean> {
    try {
      const dialogResult = await this.getUIContext().getPromptAction().showDialog({
        title: '确认删除建议',
        message: '这会按 AI 建议删除部分任务。建议确认这些任务确实不再需要。',
        buttons: [
          { text: '取消', color: this.themeColors.textMuted },
          { text: '继续应用', color: this.themeColors.danger }
        ]
      }) as promptAction.ShowDialogSuccessResponse;
      return dialogResult.index === 1;
    } catch (_) {
      return false;
    }
  }

  private async applySuggestion(): Promise<void> {
    if (!this.result || this.isApplying) {
      return;
    }
    if (this.includeDeleteSuggestions) {
      const confirmed = await this.confirmDeleteSuggestions();
      if (!confirmed) {
        return;
      }
    }

    this.isApplying = true;
    this.errorMessage = '';
    try {
      const context = this.getUIContext().getHostContext() as Context;
      const appliedCount = await RescheduleService.applyResult(context, this.result, this.includeDeleteSuggestions);
      if (appliedCount <= 0) {
        this.showToast('没有可应用的调整');
        return;
      }

      UsageService.reportAIFeatureUsage('reschedule', 'adopt');
      const adoptedProps: TelemetryProperties = {
        "adoptedCount": appliedCount
      };
      TelemetryService.track('ai_reschedule_adopted', adoptedProps, 'ai');

      this.showToast(`已应用 ${appliedCount} 项调整`);
      await this.loadTasks();
      this.getUIContext().getRouter().back();
    } catch (error) {
      logger.error('ReschedulePage apply error', error as Object);
      this.errorMessage = '应用建议失败，请重试';
      this.showToast('应用建议失败，请重试');
    } finally {
      this.isApplying = false;
    }
  }

  @Builder
  private HeroCard() {
    AppCard({ variant: 'accent', spacing: SPACE_SM }) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        AppStatusBadge({ text: 'AI 一键重排', tone: 'primary', iconName: 'ai' })
        if (this.quotaHint.length > 0) {
          AppStatusBadge({ text: this.quotaHint, tone: 'neutral', iconName: 'info' })
        }
      }
      .width('100%')

      Text(this.getHeroTitle())
        .fontSize(TYPE_HERO_TITLE)
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

      Text(this.getSuggestionSummary())
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textMuted)
        .width('100%')
    }
  }

  @Builder
  private ErrorBanner() {
    if (this.errorMessage.length > 0) {
      AppCard({ variant: 'danger', spacing: SPACE_SM }) {
        Text(this.errorMessage)
          .fontSize(TYPE_BODY)
          .lineHeight(22)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')

        AppButton({
          text: this.isGenerating ? '请稍候...' : '重新生成',
          variant: 'secondary',
          buttonSize: 'sm',
          iconName: 'ai',
          disabled: this.isGenerating || this.isApplying,
          tapAction: () => {
            void this.generateSuggestion();
          }
        })
      }
    }
  }

  @Builder
  private SectionHeader(group: SuggestionGroup, count: number) {
    AppCard({ variant: this.getSectionVariant(group), spacing: SPACE_XS, paddingLevel: 'md' }) {
      Row({ space: SPACE_SM }) {
        Column({ space: SPACE_XS }) {
          Text(this.getSectionTitle(group))
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')

          AppStatusBadge({
            text: this.getSectionHint(group),
            tone: this.getSectionTone(group),
            iconName: this.getSectionIcon(group)
          })

          Text(this.getSectionDescription(group))
            .fontSize(TYPE_META)
            .lineHeight(18)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        AppStatusBadge({ text: `${count} 项`, tone: this.getSectionTone(group), iconName: 'task' })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  @Builder
  private ReasonItemCard(
    taskId: string,
    reason: string,
    group: SuggestionGroup
  ) {
    AppCard({ variant: group === 'delete' ? 'danger' : 'base', spacing: SPACE_XS }) {
      Row({ space: SPACE_XS }) {
        Text(this.getTaskTitle(taskId))
          .layoutWeight(1)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        AppButton({
          text: '调整',
          variant: 'ghost',
          buttonSize: 'sm',
          iconName: 'edit',
          contentGap: SPACE_2XS,
          disabled: this.isApplying || this.isGenerating,
          tapAction: () => {
            this.showTaskAdjustmentMenu(taskId, group);
          }
        })
      }
      .width('100%')

      Text(reason)
        .fontSize(TYPE_BODY)
        .lineHeight(20)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  @Builder
  private SplitItemCard(item: RescheduleSplitItem) {
    AppCard({ variant: 'base', spacing: SPACE_XS }) {
      Row({ space: SPACE_XS }) {
        Text(this.getTaskTitle(item.id))
          .layoutWeight(1)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        AppButton({
          text: '调整',
          variant: 'ghost',
          buttonSize: 'sm',
          iconName: 'edit',
          contentGap: SPACE_2XS,
          disabled: this.isApplying || this.isGenerating,
          tapAction: () => {
            this.showTaskAdjustmentMenu(item.id, 'split');
          }
        })
      }
      .width('100%')

      Text(item.reason)
        .fontSize(TYPE_BODY)
        .lineHeight(20)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Text(`建议拆成 ${item.subTasks.length} 项`)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.primary)
        .width('100%')

      Text(item.subTasks.join(' · '))
        .fontSize(TYPE_META)
        .lineHeight(18)
        .fontColor(this.themeColors.textMuted)
        .width('100%')
    }
  }

  @Builder
  private WeekItemCard(item: RescheduleWeekItem) {
    AppCard({ variant: 'base', spacing: SPACE_XS }) {
      Row({ space: SPACE_XS }) {
        Text(this.getTaskTitle(item.id))
          .layoutWeight(1)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        AppButton({
          text: '调整',
          variant: 'ghost',
          buttonSize: 'sm',
          iconName: 'edit',
          contentGap: SPACE_2XS,
          disabled: this.isApplying || this.isGenerating,
          tapAction: () => {
            this.showTaskAdjustmentMenu(item.id, 'thisWeek');
          }
        })
      }
      .width('100%')

      Text(item.reason)
        .fontSize(TYPE_BODY)
        .lineHeight(20)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')

      Text(`建议日期：${item.newDate}`)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.primary)
        .width('100%')
    }
  }

  @Builder
  private OverduePreviewCard(task: Task) {
    AppCard({ variant: 'danger', spacing: SPACE_XS }) {
      Text(task.title)
        .fontSize(TYPE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(task.deadline || '未设置日期')
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  @Builder
  private OverduePreviewSection() {
    Column({ space: SPACE_SM }) {
      AppCard({ variant: 'soft', spacing: SPACE_SM, paddingLevel: 'md' }) {
        Row({ space: SPACE_SM }) {
          Column({ space: SPACE_XS }) {
            Text('积压预览')
              .fontSize(TYPE_SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
              .width('100%')

            Text(this.getOverduePreviewSummaryText())
              .fontSize(TYPE_META)
              .lineHeight(18)
              .fontColor(this.themeColors.textSecondary)
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          AppStatusBadge({
            text: `预览 ${this.getOverduePreviewTasks().length}/${this.overdueTasks.length}`,
            tone: 'warning',
            iconName: 'warning'
          })
        }
        .width('100%')

        Row({ space: SPACE_SM }) {
          Column({ space: 4 }) {
            Text(`${this.overdueTasks.length}`)
              .fontSize(TYPE_NUMERIC_MD)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.danger)
            Text('全部逾期')
              .fontSize(TYPE_META)
              .fontColor(this.themeColors.textSecondary)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text(`${this.getOverduePreviewTasks().length}`)
              .fontSize(TYPE_NUMERIC_MD)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.warning)
            Text('当前展示')
              .fontSize(TYPE_META)
              .fontColor(this.themeColors.textSecondary)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text(`${this.getHiddenOverdueCount()}`)
              .fontSize(TYPE_NUMERIC_MD)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textSecondary)
            Text('未展开')
              .fontSize(TYPE_META)
              .fontColor(this.themeColors.textSecondary)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
      }

      ForEach(this.getOverduePreviewTasks(), (task: Task) => {
        this.OverduePreviewCard(task);
      }, (task: Task) => task.id)
    }
    .width('100%')
  }

  @Builder
  private GenerationProgressCard() {
    AppCard({ variant: 'soft', spacing: SPACE_SM, paddingLevel: 'md' }) {
      Row({ space: SPACE_SM }) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(this.themeColors.primary)

        Column({ space: SPACE_XS }) {
          Row() {
            Text(this.getGenerationPhaseText(this.generationProgressPhase))
              .fontSize(TYPE_BODY)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColors.textPrimary)

            Blank()

            Text(this.getGenerationProgressLabel())
              .fontSize(TYPE_META)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColors.primary)
          }
          .width('100%')

          Text(this.generationProgressMessage)
            .fontSize(TYPE_META)
            .lineHeight(18)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')

          Stack({ alignContent: Alignment.TopStart }) {
            Row()
              .width('100%')
              .height(4)
              .backgroundColor(this.themeColors.borderColor)
              .borderRadius(999)

            Row()
              .width(this.getGenerationProgressBarWidth())
              .height(4)
              .backgroundColor(this.themeColors.primary)
              .borderRadius(999)
          }
          .width('100%')
          .height(4)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  @Builder
  private SuggestionsCard() {
    if (!this.result) {
      AppCard({ variant: 'base', spacing: SPACE_SM }) {
        Text('AI 会把积压任务整理成一份可预览的恢复方案。')
          .fontSize(TYPE_BODY)
          .lineHeight(22)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')

        Text('建议范围包括：明天继续、本周稍后、降低优先级、拆分任务、暂缓，以及可选的删除建议。')
          .fontSize(TYPE_META)
          .lineHeight(18)
          .fontColor(this.themeColors.textMuted)
          .width('100%')
      }
    } else {
      Column({ space: SECTION_GAP }) {
        AppCard({ variant: 'base', spacing: SPACE_SM }) {
          Text('整理摘要')
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')

          Text(this.result.summary || 'AI 已生成一份可执行的重排建议。')
            .fontSize(TYPE_BODY)
            .lineHeight(22)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
        }

        if (!this.hasSuggestions()) {
          AppEmptyState({
            iconName: 'success',
            iconTone: 'success',
            title: '这一轮没有发现必须大改的地方',
            description: '如果你仍然觉得今天过载，可以稍后重新生成，或者直接手动调整优先级。'
          })
        }

        if (this.getTomorrowTasks().length > 0) {
          Column({ space: SPACE_SM }) {
            this.SectionHeader('tomorrow', this.getTomorrowTasks().length)
            ForEach(this.getTomorrowTasks(), (item: RescheduleItemWithReason) => {
              this.ReasonItemCard(item.id, item.reason, 'tomorrow');
            }, (item: RescheduleItemWithReason) => item.id)
          }
          .width('100%')
        }

        if (this.getThisWeekTasks().length > 0) {
          Column({ space: SPACE_SM }) {
            this.SectionHeader('thisWeek', this.getThisWeekTasks().length)
            ForEach(this.getThisWeekTasks(), (item: RescheduleWeekItem) => {
              this.WeekItemCard(item);
            }, (item: RescheduleWeekItem) => item.id)
          }
          .width('100%')
        }

        if (this.getDowngradeTasks().length > 0) {
          Column({ space: SPACE_SM }) {
            this.SectionHeader('downgrade', this.getDowngradeTasks().length)
            ForEach(this.getDowngradeTasks(), (item: RescheduleItemWithReason) => {
              this.ReasonItemCard(item.id, item.reason, 'downgrade');
            }, (item: RescheduleItemWithReason) => item.id)
          }
          .width('100%')
        }

        if (this.getSplitTasks().length > 0) {
          Column({ space: SPACE_SM }) {
            this.SectionHeader('split', this.getSplitTasks().length)
            ForEach(this.getSplitTasks(), (item: RescheduleSplitItem) => {
              this.SplitItemCard(item);
            }, (item: RescheduleSplitItem) => item.id)
          }
          .width('100%')
        }

        if (this.getShelveTasks().length > 0) {
          Column({ space: SPACE_SM }) {
            this.SectionHeader('shelve', this.getShelveTasks().length)
            ForEach(this.getShelveTasks(), (item: RescheduleItemWithReason) => {
              this.ReasonItemCard(item.id, item.reason, 'shelve');
            }, (item: RescheduleItemWithReason) => item.id)
          }
          .width('100%')
        }

        if (this.getDeleteTasks().length > 0) {
          Column({ space: SPACE_SM }) {
            this.SectionHeader('delete', this.getDeleteTasks().length)
            ForEach(this.getDeleteTasks(), (item: RescheduleItemWithReason) => {
              this.ReasonItemCard(item.id, item.reason, 'delete');
            }, (item: RescheduleItemWithReason) => item.id)

            AppCard({ variant: 'soft', spacing: SPACE_XS }) {
              Row({ space: SPACE_SM }) {
                Column({ space: 4 }) {
                  Text('同时应用删除建议')
                    .fontSize(TYPE_BODY)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.themeColors.textPrimary)
                    .width('100%')

                  Text('默认关闭，避免误删。')
                    .fontSize(TYPE_META)
                    .fontColor(this.themeColors.textSecondary)
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Toggle({ type: ToggleType.Switch, isOn: this.includeDeleteSuggestions })
                  .selectedColor(this.themeColors.danger)
                  .onChange((value: boolean) => {
                    this.includeDeleteSuggestions = value;
                  })
              }
              .width('100%')
            }
          }
          .width('100%')
        }
      }
      .width('100%')
    }
  }

  @Builder
  private ActionBar() {
    Column() {
      if (!this.result) {
        AppButton({
          text: '生成重排建议',
          variant: 'primary',
          fullWidth: true,
          loading: this.isGenerating,
          disabled: this.overdueTasks.length === 0,
          iconName: 'ai',
          tapAction: () => {
            void this.generateSuggestion();
          }
        })
      } else {
        Row({ space: SPACE_SM }) {
          AppButton({
            text: '重新生成',
            variant: 'secondary',
            buttonSize: 'md',
            disabled: this.isGenerating || this.isApplying,
            iconName: 'ai',
            tapAction: () => {
              void this.generateSuggestion();
            }
          })
            .layoutWeight(1)

          AppButton({
            text: '应用建议',
            variant: 'primary',
            buttonSize: 'md',
            loading: this.isApplying,
            iconName: 'success',
            tapAction: () => {
              void this.applySuggestion();
            }
          })
            .layoutWeight(1)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ top: SPACE_XS, bottom: SPACE_SM })
  }

  build() {
    Column() {
      AppPageHeader({
        title: 'AI 一键重排',
        subtitle: `当前有 ${this.overdueTasks.length} 项逾期任务`,
        onBack: () => {
          this.getUIContext().getRouter().back();
        }
      })

      if (this.isLoading) {
        Column({ space: SPACE_MD }) {
          this.HeroCard()
          AppLoadingState({ label: '正在分析积压和未来安排' })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 8, bottom: PAGE_PADDING })
      } else {
        Scroll() {
          Column({ space: SECTION_GAP }) {
            this.HeroCard()
            this.ErrorBanner()

            if (this.overdueTasks.length === 0 && !this.result) {
              AppEmptyState({
                iconName: 'success',
                iconTone: 'success',
                title: '当前没有逾期任务',
                description: '等真正出现积压时，再来生成恢复方案会更有价值。'
              })
            } else {
              if (this.overdueTasks.length > 0 && !this.result) {
                this.OverduePreviewSection()
              }

              if (this.isGenerating) {
                this.GenerationProgressCard()
              } else {
                this.SuggestionsCard()
              }

              if (!this.isGenerating) {
                this.ActionBar()
              }
            }
          }
          .width('100%')
          .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: 8, bottom: PAGE_PADDING + 16 })
        }
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
