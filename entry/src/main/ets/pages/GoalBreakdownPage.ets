import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { QuotaService, QuotaResult } from '../services/QuotaService';
import {
  GoalPlanningService, StartResponse, ClarificationResponse,
  ProgressResponse, ApplySessionResponse
} from '../services/GoalPlanningService';
import { GoalPlanningApplyService } from '../services/GoalPlanningApplyService';
import { draftService } from '../services/GoalPlanningDraftService';
import {
  PlanningApiResponse, GoalDraft, ClarificationQuestion,
  ProgressPlan, ProgressTrack, ActionPlan, OneOffTask,
  RecurringAction, CountdownItem, QualityReport,
  GoalAssessment, PlanningSession, RuntimeStatus
} from '../models/PlanningSession';
import { RADIUS_LG, RADIUS_MD } from '../foundation/tokens/RadiusTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { BOTTOM_CONTENT_SPACER, BUTTON_HEIGHT_MD, CHECKBOX_SIZE_LG, CHECKBOX_SIZE_SM, ICON_BUTTON_SIZE_MD } from '../foundation/tokens/ComponentSizeTokens';
import { ICON_SIZE_LG, ICON_SIZE_XL, ICON_SIZE_XS } from '../foundation/tokens/IconTokens';
import { PAGE_PADDING, PANEL_GAP, SECTION_GAP, SPACE_2XS, SPACE_CARD, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { COMFORTABLE_PAGE_PADDING, COMFORTABLE_SECTION_GAP } from '../foundation/tokens/PageTierTokens';
import { TelemetryService } from '../services/TelemetryService';
import { UsageService } from '../services/UsageService';
import { AppErrorService } from '../services/AppErrorService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppIcon } from '../ui/base/AppIcon';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';

type PlanningStage = 'loading' | 'understanding' | 'clarifying' | 'progress' | 'actions' | 'applying' | 'done' | 'error';

// === 局部接口，解决 ArkTS 无类型字面量限制 ===
interface StageInfo {
  label: string;
  index: number;
}

interface StageStepData {
  icon: string;
  title: string;
  subtitle: string;
}

interface StageNarrative {
  icon: string;
  step: number;
  title: string;
  description: string;
  outcome: string;
  trustHint: string;
  eta: string;
}

@Entry
@Component
struct GoalBreakdownPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;

  // ===== 核心状态 =====
  @State stage: PlanningStage = 'loading';
  @State sessionId: string = '';
  @State goalDraft: GoalDraft | null = null;
  @State goalAssessment: GoalAssessment | null = null;
  @State progressPlan: ProgressPlan | null = null;
  @State actionPlan: ActionPlan | null = null;
  @State qualityReport: QualityReport | null = null;

  // ===== 澄清阶段 =====
  @State questions: ClarificationQuestion[] = [];
  @State answers: Record<string, string> = {};

  // ===== UI 状态 =====
  @State isProcessing: boolean = false;
  @State processingText: string = '';
  @State runtimeStatus: RuntimeStatus | null = null;
  @State errorMessage: string = '';
  @State suggestedTaskTitle: string = '';
  @State restoreHint: string = '';
  @State intent: string = '';
  @State source: 'create_goal' | 'enhance_goal' = 'create_goal';
  @State targetGoalId: string = '';
  @State quota: QuotaResult = { allowed: false, remaining: 0, limit: 0 };
  @State stageProgress: number = 0;
  @State progressRefreshTick: number = 0;
  @State actionRefreshTick: number = 0;
  @State showTrackEditor: boolean = false;
  @State editingTrackIndex: number = -1;
  @State trackTitleInput: string = '';
  @State trackUnitInput: string = '';
  @State trackTargetInput: string = '';
  @State trackCriteriaInput: string = '';
  @State trackCheckpointInput: string = '';
  @State showTaskEditor: boolean = false;
  @State taskTitleInput: string = '';
  @State taskDescInput: string = '';
  @State taskDueInput: string = '';
  @State taskHoursInput: string = '';
  private fromGoalInfo: boolean = false;
  private fromOnboarding: boolean = false;
  private requestedSessionId: string = '';
  private statusTimer: number = -1;
  private draftTimer: number = -1;
  private sessionCreatedAt: number = 0;

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    if (params) {
      this.intent = params['intent'] || '';
      if (params['source'] === 'enhance_goal') {
        this.source = 'enhance_goal';
      }
      this.targetGoalId = params['targetGoalId'] || '';
      this.fromGoalInfo = params['fromGoalInfo'] === 'true';
      this.fromOnboarding = params['fromOnboarding'] === 'true';
      this.requestedSessionId = params['sessionId'] || '';
    }
    void this.prepareAndStart();
  }

  private shouldReturnToMainOnBack(): boolean {
    return this.fromGoalInfo || this.fromOnboarding;
  }

  aboutToDisappear(): void {
    this.stopRuntimePolling();
    this.clearDraftQueue();
    if (this.sessionId && this.stage !== 'done') {
      void this.persistDraft();
    }
  }

  private async prepareAndStart(): Promise<void> {
    this.stage = 'loading';
    this.processingText = '正在准备规划流程...';
    try {
      const context = this.getUIContext().getHostContext() as Context;
      await draftService.init(context);
    } catch (_e) {
      // ignore
    }
    await this.loadQuotaAndStart();
  }

  private async loadQuotaAndStart(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as Context;
      this.quota = await QuotaService.checkGoalBreakdownQuota(context);
    } catch (e) {
      this.quota = { allowed: false, remaining: 0, limit: 0 };
    }

    if (this.requestedSessionId && await this.restorePlanningSession(this.requestedSessionId, true)) {
      return;
    }

    if (!this.intent.trim()) {
      this.stage = 'error';
      this.errorMessage = '未收到目标内容，请返回上一步';
      return;
    }

    if (await this.tryRestoreMatchingDraft()) {
      return;
    }

    if (!this.quota.allowed) {
      this.stage = 'error';
      this.errorMessage = '当前拆解额度不足，请前往会员中心提升额度';
      return;
    }

    await this.runStart();
  }

  // ===== Step 1: 目标理解 =====
  private async runStart(): Promise<void> {
    this.stage = 'understanding';
    this.isProcessing = true;
    this.processingText = '正在分析目标...';
    this.errorMessage = '';
    this.restoreHint = '';
    this.stageProgress = 0;

    try {
      const context = this.getUIContext().getHostContext() as Context;
      const spendResult = await QuotaService.incrementGoalBreakdownCount(context);
      if (!spendResult.success) {
        if (spendResult.requireMembership) {
          const message = spendResult.message || '需要有效会员才能使用此功能';
          this.showError(`${message}，请前往会员中心开通或同步会员状态。`);
        } else {
          this.showError(spendResult.message || '当前无法使用 AI 拆解，请稍后重试');
        }
        return;
      }

      TelemetryService.track('ai_goal_breakdown_triggered', undefined, 'ai');
      const result: PlanningApiResponse<StartResponse> = await GoalPlanningService.start(
        this.intent, this.source, this.targetGoalId || undefined
      );

      if (!result.success || !result.data) {
        this.showError(result.message || 'AI 分析失败，请重试');
        return;
      }

      // simpleTask 场景：提示用户直接创建待办
      if (result.data.isSimpleTask) {
        this.stage = 'error';
        this.errorMessage = AppErrorService.fromMessage(result.data.message || '这看起来更像是一项待办任务', '这看起来更像是一项待办任务');
        this.suggestedTaskTitle = result.data.suggestedTaskTitle || this.getSuggestedTaskTitle();
        this.isProcessing = false;
        return;
      }

      this.sessionId = result.data.sessionId || '';
      this.sessionCreatedAt = Date.now();
      this.goalDraft = result.data.goalDraft || null;
      this.stageProgress = 1;
      this.isProcessing = false;
      await this.persistDraft('understanding');

      // 自动进入追问阶段
      await this.runClarification();
    } catch (e) {
      this.showError('网络错误，请检查网络后重试');
    }
  }

  // ===== Step 2: AI 追问 =====
  private async runClarification(): Promise<void> {
    this.stage = 'clarifying';
    this.isProcessing = true;
    this.processingText = '正在生成追问...';
    this.errorMessage = '';
    this.runtimeStatus = {
      phase: 'clarifying',
      stepKey: 'clarification',
      currentStep: 1,
      totalSteps: 1,
      title: '正在生成 AI 追问',
      description: 'AI 正在围绕你的目标背景、限制条件和关键信息补充理解。',
      estimatedMs: 15000,
      startedAt: Date.now()
    };

    try {
      if (!this.goalDraft) {
        this.showError('目标草案缺失');
        return;
      }
      await this.startRuntimePolling();
      const result: PlanningApiResponse<ClarificationResponse> = await GoalPlanningService.getClarification(
        this.sessionId, this.goalDraft
      );

      if (!result.success || !result.data) {
        this.showError(result.message || '获取追问失败');
        return;
      }

      this.questions = result.data.questions;
      this.answers = {};
      this.stageProgress = 2;
      this.isProcessing = false;
      await this.persistDraft('clarifying');
      this.stopRuntimePolling();
    } catch (e) {
      this.showError('网络错误');
    } finally {
      if (!this.isProcessing) {
        this.stopRuntimePolling();
      }
    }
  }

  // ===== Step 3: 进度追踪 =====
  private async runProgress(): Promise<void> {
    this.stage = 'progress';
    this.isProcessing = true;
    this.processingText = '正在设计进度追踪...';
    this.errorMessage = '';
    this.runtimeStatus = {
      phase: 'progress',
      stepKey: 'difficulty_assessment',
      currentStep: 1,
      totalSteps: 3,
      title: '正在评估目标难度',
      description: '系统会结合你的补充信息判断目标难度，并生成更合理的进度追踪。',
      estimatedMs: 45000,
      startedAt: Date.now()
    };

    try {
      await this.startRuntimePolling();
      const result: PlanningApiResponse<ProgressResponse> = await GoalPlanningService.generateProgress(
        this.sessionId, this.answers
      );

      if (!result.success || !result.data) {
        this.showError(result.message || '生成进度追踪失败');
        return;
      }

      this.progressPlan = result.data.progressPlan;
      this.goalAssessment = result.data.goalAssessment || null;
      this.stageProgress = 3;
      this.isProcessing = false;
      await this.persistDraft('progress');
      this.stopRuntimePolling();
    } catch (e) {
      this.showError('网络错误');
    } finally {
      if (!this.isProcessing) {
        this.stopRuntimePolling();
      }
    }
  }

  // ===== Step 4: 行动方案 =====
  private async runActions(): Promise<void> {
    this.stage = 'actions';
    this.isProcessing = true;
    this.processingText = '正在规划行动方案...';
    this.errorMessage = '';
    this.runtimeStatus = {
      phase: 'actions',
      stepKey: 'task_planning',
      currentStep: 1,
      totalSteps: 4,
      title: '正在规划行动草案',
      description: '系统会先整理起步任务，再并行生成重复提醒与关键日期。',
      estimatedMs: 120000,
      startedAt: Date.now()
    };

    try {
      await this.syncCurrentSessionToServer();
      await this.startRuntimePolling();
      const result: PlanningApiResponse<ActionPlan> = await GoalPlanningService.generateActions(this.sessionId);

      if (!result.success || !result.data) {
        this.showError(result.message || '生成行动方案失败');
        return;
      }

      this.actionPlan = result.data;
      this.stageProgress = 4;
      this.isProcessing = false;
      await this.persistDraft('actions');
      this.stopRuntimePolling();
    } catch (e) {
      this.showError('网络错误');
    } finally {
      if (!this.isProcessing) {
        this.stopRuntimePolling();
      }
    }
  }

  // ===== Step 5: 确认创建 =====
  private async runApply(): Promise<void> {
    this.stage = 'applying';
    this.isProcessing = true;
    this.processingText = '正在保存方案...';
    this.errorMessage = '';
    this.runtimeStatus = {
      phase: 'saving',
      stepKey: 'apply',
      currentStep: 1,
      totalSteps: 1,
      title: '正在创建目标',
      description: '系统正在保存目标、追踪、任务和提醒。',
      estimatedMs: 12000,
      startedAt: Date.now()
    };

    try {
      await this.syncCurrentSessionToServer();
      await this.startRuntimePolling();
      // 1. 通知服务端标记 session 完成
      const applyResult: PlanningApiResponse<ApplySessionResponse> = await GoalPlanningService.applySession(this.sessionId);
      if (!applyResult.success || !applyResult.data) {
        this.showError(applyResult.message || '采用方案失败');
        return;
      }

      const session = applyResult.data.session;
      // 2. 本地创建 Goal/Task/DayEvent
      const localResult = await GoalPlanningApplyService.apply(session);

      if (localResult.success) {
        void UsageService.reportAIFeatureUsage('goal_breakdown', 'adopt');
        TelemetryService.track('ai_goal_breakdown_adopted', undefined, 'ai');
        // 清理草稿
        try {
          const context = this.getUIContext().getHostContext() as Context;
          await draftService.init(context);
          await draftService.deleteDraft(this.sessionId);
        } catch (_e) { /* ignore */ }

        this.stage = 'done';
        this.isProcessing = false;

        // 导航到目标详情页
        setTimeout(() => {
          if (localResult.goalId) {
            this.getUIContext().getRouter().replaceUrl({
              url: 'pages/GoalDetailPage',
              params: {
                'goalId': localResult.goalId,
                'returnToMainOnBack': this.shouldReturnToMainOnBack() ? 'true' : 'false'
              }
            });
          } else {
            this.getUIContext().getRouter().back();
          }
        }, 1500);
      } else {
        this.showError(localResult.message || '本地保存失败');
      }
    } catch (e) {
      this.showError('保存方案时出错');
    } finally {
      if (!this.isProcessing) {
        this.stopRuntimePolling();
      }
    }
  }

  private showError(msg: string): void {
    this.errorMessage = AppErrorService.fromMessage(msg, 'AI 目标规划失败，请稍后重试');
    this.isProcessing = false;
    this.stopRuntimePolling();
    const currentStage: string = this.stage;
    if (currentStage === 'understanding' || currentStage === 'loading') {
      this.stage = 'error';
    }
    this.queueDraftPersist();
  }

  private showToast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } catch (_e) { /* ignore */ }
  }

  private removeTrack(index: number): void {
    if (!this.progressPlan) {
      return;
    }
    this.progressPlan.tracks.splice(index, 1);
    this.progressRefreshTick += 1;
    this.queueDraftPersist();
  }

  private openTrackEditor(index: number = -1): void {
    this.editingTrackIndex = index;
    if (index >= 0 && this.progressPlan && this.progressPlan.tracks[index]) {
      const track = this.progressPlan.tracks[index];
      this.trackTitleInput = track.title || '';
      this.trackUnitInput = track.unit || '';
      this.trackTargetInput = `${track.targetValue || ''}`;
      this.trackCriteriaInput = track.completionCriteria || '';
      this.trackCheckpointInput = track.checkpointText || '';
    } else {
      this.trackTitleInput = '';
      this.trackUnitInput = '';
      this.trackTargetInput = '';
      this.trackCriteriaInput = '';
      this.trackCheckpointInput = '';
    }
    this.showTrackEditor = true;
  }

  private closeTrackEditor(): void {
    this.showTrackEditor = false;
    this.editingTrackIndex = -1;
    this.trackTitleInput = '';
    this.trackUnitInput = '';
    this.trackTargetInput = '';
    this.trackCriteriaInput = '';
    this.trackCheckpointInput = '';
  }

  private saveTrackEditor(): void {
    if (!this.progressPlan) {
      this.closeTrackEditor();
      return;
    }
    const title = this.trackTitleInput.trim();
    const unit = this.trackUnitInput.trim();
    const targetValue = Number(this.trackTargetInput);
    if (!title || !unit || isNaN(targetValue)) {
      this.showToast('请补全追踪标题、单位和目标值');
      return;
    }
    const track: ProgressTrack = {
      id: this.editingTrackIndex >= 0 && this.progressPlan.tracks[this.editingTrackIndex]
        ? this.progressPlan.tracks[this.editingTrackIndex].id
        : `manual_track_${Date.now()}`,
      title,
      type: this.editingTrackIndex >= 0 && this.progressPlan.tracks[this.editingTrackIndex]
        ? this.progressPlan.tracks[this.editingTrackIndex].type
        : 'custom',
      unit,
      targetValue,
      currentValue: this.editingTrackIndex >= 0 && this.progressPlan.tracks[this.editingTrackIndex]
        ? this.progressPlan.tracks[this.editingTrackIndex].currentValue
        : 0,
      baselineValue: this.editingTrackIndex >= 0 && this.progressPlan.tracks[this.editingTrackIndex]
        ? this.progressPlan.tracks[this.editingTrackIndex].baselineValue
        : 0,
      completionCriteria: this.trackCriteriaInput.trim() || '达到目标值即完成',
      checkpointText: this.trackCheckpointInput.trim(),
      reason: '用户手动补充'
    };
    if (this.editingTrackIndex >= 0) {
      this.progressPlan.tracks[this.editingTrackIndex] = track;
    } else {
      this.progressPlan.tracks.push(track);
    }
    this.progressRefreshTick += 1;
    this.closeTrackEditor();
    this.queueDraftPersist();
  }

  private async regenerateTrack(index: number): Promise<void> {
    if (!this.progressPlan || !this.progressPlan.tracks[index]) {
      return;
    }
    const track = this.progressPlan.tracks[index];
    this.isProcessing = true;
    this.processingText = 'AI 正在重新生成这条追踪...';
    try {
      const res = await GoalPlanningService.regenerateTrack(this.sessionId, track.id);
      if (res.success && res.data?.track) {
        this.progressPlan.tracks[index] = res.data.track;
        this.progressRefreshTick += 1;
        this.queueDraftPersist();
        this.showToast('追踪已更新');
      } else {
        this.showToast(res.message || '重生成失败');
      }
    } finally {
      this.isProcessing = false;
    }
  }

  private async addAiTrack(): Promise<void> {
    this.isProcessing = true;
    this.processingText = 'AI 正在补充一条追踪...';
    try {
      const res = await GoalPlanningService.addTrack(this.sessionId);
      if (res.success && res.data?.track && this.progressPlan) {
        this.progressPlan.tracks.push(res.data.track);
        this.progressRefreshTick += 1;
        this.queueDraftPersist();
        this.showToast('已补充一条追踪');
      } else {
        this.showToast(res.message || '补充追踪失败');
      }
    } finally {
      this.isProcessing = false;
    }
  }

  private removeTask(index: number): void {
    if (!this.actionPlan) {
      return;
    }
    this.actionPlan.oneOffTasks.splice(index, 1);
    this.actionRefreshTick += 1;
    this.queueDraftPersist();
  }

  private openTaskEditor(): void {
    this.taskTitleInput = '';
    this.taskDescInput = '';
    this.taskDueInput = '';
    this.taskHoursInput = '';
    this.showTaskEditor = true;
  }

  private closeTaskEditor(): void {
    this.showTaskEditor = false;
    this.taskTitleInput = '';
    this.taskDescInput = '';
    this.taskDueInput = '';
    this.taskHoursInput = '';
  }

  private saveTaskEditor(): void {
    if (!this.actionPlan) {
      this.closeTaskEditor();
      return;
    }
    const title = this.taskTitleInput.trim();
    if (!title) {
      this.showToast('请填写任务标题');
      return;
    }
    const dueMs = this.taskDueInput.trim() ? new Date(this.taskDueInput.trim()).getTime() : undefined;
    const estimatedHours = this.taskHoursInput.trim() ? Number(this.taskHoursInput.trim()) : undefined;
    this.actionPlan.oneOffTasks.push({
      title,
      description: this.taskDescInput.trim(),
      priority: 'medium',
      estimatedHours: estimatedHours && !isNaN(estimatedHours) ? estimatedHours : undefined,
      suggestedDueDate: dueMs && !isNaN(dueMs) ? dueMs : undefined
    });
    this.actionRefreshTick += 1;
    this.closeTaskEditor();
    this.queueDraftPersist();
  }

  private async regenerateTasks(): Promise<void> {
    this.isProcessing = true;
    this.processingText = 'AI 正在重新规划任务清单...';
    try {
      await this.syncCurrentSessionToServer();
      const res = await GoalPlanningService.regenerateActions(this.sessionId, 'tasks');
      if (res.success && res.data?.actionPlan && this.actionPlan) {
        this.actionPlan.oneOffTasks = res.data.actionPlan.oneOffTasks || [];
        this.actionRefreshTick += 1;
        this.queueDraftPersist();
        this.showToast('任务清单已更新');
      } else {
        this.showToast(res.message || '重生成任务失败');
      }
    } finally {
      this.isProcessing = false;
    }
  }

  private getStageIndex(): number {
    const stageMap: Record<string, number> = {
      'loading': 0, 'understanding': 0, 'clarifying': 1, 'progress': 2,
      'actions': 3, 'applying': 4, 'done': 4, 'error': 0
    };
    return stageMap[this.stage] || 0;
  }

  private getStageNarrative(stage: PlanningStage): StageNarrative {
    switch (stage) {
      case 'clarifying':
        return {
        icon: 'help',
          step: 2,
          title: '补齐关键约束',
          description: '你的回答会影响任务粒度、提醒节奏和关键日期安排。',
          outcome: '输出一组更贴近你真实情况的规划输入。',
          trustHint: '不确定的项可以先留空，后面仍然可以改。',
          eta: '通常 10-20 秒'
        } as StageNarrative;
      case 'progress':
        return {
        icon: 'stats',
          step: 3,
          title: '先定义怎么判断在前进',
          description: '先把结果指标定清楚，再去生成行动，能减少“做了很多却看不见进展”的情况。',
          outcome: '输出 1-3 条你能持续追踪的进度指标。',
          trustHint: '至少保留一条你愿意长期更新的指标。',
          eta: '通常 40-60 秒'
        } as StageNarrative;
      case 'actions':
        return {
        icon: 'archive',
          step: 4,
          title: '把目标落到行动和提醒',
          description: 'AI 会基于追踪项生成起步任务、日常习惯和关键日期。',
          outcome: '输出行动清单、重复提醒和关键日期。',
          trustHint: '现在删改不会影响正式数据，确认创建后才会落地。',
          eta: '通常 1-2 分钟'
        } as StageNarrative;
      case 'applying':
        return {
        icon: 'task',
          step: 5,
          title: '写入你的执行系统',
          description: '系统正在保存目标、任务、提醒和倒计时，并关联回这次规划结果。',
          outcome: '创建完成后会自动跳转到目标详情页。',
          trustHint: '这一步只需要等待，不要重复点击。',
          eta: '通常 10-15 秒'
        } as StageNarrative;
      case 'done':
        return {
        icon: 'success',
          step: 5,
          title: '规划已完成',
          description: '新的目标和配套行动已经创建完成。',
          outcome: '你可以直接去目标详情里开始执行。',
          trustHint: '后续仍然可以继续补任务、补提醒或增强目标。',
          eta: '已完成'
        } as StageNarrative;
      case 'error':
        return {
        icon: 'warning',
          step: Math.max(1, this.getStageIndex() + 1),
          title: '这一步没有顺利完成',
          description: '已生成的内容会尽量保留，你可以重试当前步骤或换一种方式继续。',
          outcome: '不会直接丢掉已经确认过的规划结果。',
          trustHint: '如果是额度或网络问题，先处理阻塞再继续。',
          eta: '处理后可立即继续'
        } as StageNarrative;
      case 'loading':
      case 'understanding':
      default:
        return {
        icon: 'goal',
          step: 1,
          title: '先确认这是不是一个值得规划的目标',
          description: 'AI 会先识别你的意图、周期和成果形态，避免把一件临时待办误拆成长目标。',
          outcome: '输出目标草案、周期和类型判断。',
          trustHint: '这一步只是理解，不会创建任何任务和提醒。',
          eta: '通常 10-20 秒'
        } as StageNarrative;
    }
  }

  private getActiveNarrative(): StageNarrative {
    if (this.stage === 'loading') {
      return this.getStageNarrative('understanding');
    }
    if (this.stage === 'error') {
      if (this.stageProgress >= 4) return this.getStageNarrative('actions');
      if (this.stageProgress >= 3) return this.getStageNarrative('progress');
      if (this.stageProgress >= 2) return this.getStageNarrative('clarifying');
      return this.getStageNarrative('understanding');
    }
    return this.getStageNarrative(this.stage);
  }

  private getQuotaText(): string {
    if (this.quota.limit > 9999) {
      return '会员不限次数';
    }
    return `本月剩余 ${this.quota.remaining}/${this.quota.limit} 次`;
  }

  private getSourceText(): string {
    return this.source === 'enhance_goal' ? '增强现有目标' : '新建目标';
  }

  private getClarificationAnsweredCount(): number {
    let count = 0;
    const keys = Object.keys(this.answers);
    for (let i = 0; i < keys.length; i++) {
      if ((this.answers[keys[i]] || '').trim().length > 0) {
        count += 1;
      }
    }
    return count;
  }

  private getClarificationRequiredCount(): number {
    let count = 0;
    for (let i = 0; i < this.questions.length; i++) {
      if (this.questions[i].required) {
        count += 1;
      }
    }
    return count;
  }

  private hasMissingRequiredAnswers(): boolean {
    for (let i = 0; i < this.questions.length; i++) {
      const question = this.questions[i];
      if (question.required && !(this.answers[question.id] || '').trim()) {
        return true;
      }
    }
    return false;
  }

  private getProcessingMilestones(): string[] {
    if (this.stage === 'clarifying') {
      return ['梳理目标背景', '判断关键约束', '生成追问'];
    }
    if (this.stage === 'progress') {
      return ['评估难度', '设计追踪', '检查可执行性'];
    }
    if (this.stage === 'actions') {
      return ['提炼起步行动', '安排习惯提醒', '补齐关键日期'];
    }
    if (this.stage === 'applying') {
      return ['创建目标', '写入行动', '保存提醒'];
    }
    return ['理解目标', '识别类型', '生成草案'];
  }

  private getActiveMilestoneIndex(): number {
    if (!this.runtimeStatus || this.runtimeStatus.currentStep <= 1) {
      return 0;
    }
    const maxIndex = this.getProcessingMilestones().length - 1;
    return Math.min(maxIndex, Math.max(0, this.runtimeStatus.currentStep - 1));
  }

  private getSuggestedTaskTitle(): string {
    const firstLine = this.intent.split('\n')[0];
    return firstLine ? firstLine.trim() : '新的待办';
  }

  private openSuggestedTaskCreate(): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/CreateTaskPage',
      params: {
        autoFill: 'true',
        title: this.suggestedTaskTitle || this.getSuggestedTaskTitle(),
        description: this.intent.trim(),
        goalId: this.targetGoalId || ''
      }
    });
  }

  private updateAnswer(questionId: string, value: string): void {
    const updated: Record<string, string> = {};
    const keys = Object.keys(this.answers);
    for (let i = 0; i < keys.length; i++) {
      updated[keys[i]] = this.answers[keys[i]];
    }
    updated[questionId] = value;
    this.answers = updated;
    this.queueDraftPersist();
  }

  private queueDraftPersist(): void {
    if (!this.sessionId || !draftService.isInitialized()) {
      return;
    }
    this.clearDraftQueue();
    this.draftTimer = setTimeout(() => {
      this.draftTimer = -1;
      void this.persistDraft();
    }, 600);
  }

  private clearDraftQueue(): void {
    if (this.draftTimer !== -1) {
      clearTimeout(this.draftTimer);
      this.draftTimer = -1;
    }
  }

  private getSessionStage(stage: PlanningStage): 'understanding' | 'clarifying' | 'progress' | 'actions' | 'review' | 'saving' | 'completed' | 'error' {
    if (stage === 'clarifying') return 'clarifying';
    if (stage === 'progress') return 'progress';
    if (stage === 'actions') return 'actions';
    if (stage === 'applying') return 'saving';
    if (stage === 'done') return 'completed';
    if (stage === 'error') return 'error';
    return 'understanding';
  }

  private buildDraftSnapshot(stageOverride?: PlanningStage): PlanningSession {
    const safeStage = stageOverride || this.stage;
    const answers: Record<string, string> = {};
    const answerKeys = Object.keys(this.answers);
    for (let i = 0; i < answerKeys.length; i++) {
      answers[answerKeys[i]] = this.answers[answerKeys[i]];
    }

    return {
      sessionId: this.sessionId,
      source: this.source,
      targetGoalId: this.targetGoalId || undefined,
      rawIntent: this.intent,
      stage: this.getSessionStage(safeStage),
      status: safeStage === 'done' ? 'completed' : 'active',
      goalDraft: this.goalDraft || undefined,
      clarification: (this.questions.length > 0 || answerKeys.length > 0) ? {
        questions: this.questions,
        answers,
        completenessScore: this.questions.length > 0 ? this.getClarificationAnsweredCount() / this.questions.length : 0
      } : undefined,
      goalAssessment: this.goalAssessment || undefined,
      progressPlan: this.progressPlan || undefined,
      actionPlan: this.actionPlan || undefined,
      qualityReport: this.qualityReport || undefined,
      runtimeStatus: this.runtimeStatus || undefined,
      createdAt: this.sessionCreatedAt || Date.now(),
      updatedAt: Date.now()
    } as PlanningSession;
  }

  private async persistDraft(stageOverride?: PlanningStage): Promise<void> {
    if (!this.sessionId || !draftService.isInitialized()) {
      return;
    }
    try {
      await draftService.saveDraft(this.buildDraftSnapshot(stageOverride));
    } catch (_e) {
      // ignore
    }
  }

  private async tryRestoreMatchingDraft(): Promise<boolean> {
    if (!draftService.isInitialized() || !this.intent.trim()) {
      return false;
    }
    try {
      const drafts = await draftService.listDrafts();
      for (let i = 0; i < drafts.length; i++) {
        const draft = drafts[i];
        if ((draft.rawIntent || '').trim() === this.intent.trim()
          && draft.source === this.source
          && (draft.targetGoalId || '') === this.targetGoalId) {
          this.hydrateFromSession(draft, '已恢复上次未完成的拆解草稿');
          return true;
        }
      }
    } catch (_e) {
      // ignore
    }
    return false;
  }

  private async restorePlanningSession(sessionId: string, fromServerFallback: boolean = false): Promise<boolean> {
    if (!sessionId) {
      return false;
    }

    if (draftService.isInitialized()) {
      try {
        const localDraft = await draftService.loadDraft(sessionId);
        if (localDraft) {
          this.hydrateFromSession(localDraft, '已恢复你上次停下来的规划进度');
          return true;
        }
      } catch (_e) {
        // ignore
      }
    }

    if (!fromServerFallback) {
      return false;
    }

    try {
      const result = await GoalPlanningService.getSession(sessionId);
      if (result.success && result.data) {
        this.hydrateFromSession(result.data, '已同步上次的规划进度');
        return true;
      }
    } catch (_e) {
      // ignore
    }

    return false;
  }

  private getStageFromRuntime(runtimeStatus: RuntimeStatus | null): PlanningStage {
    if (!runtimeStatus) {
      return 'understanding';
    }
    const phase = runtimeStatus.phase || runtimeStatus.stage || '';
    if (phase === 'clarifying') return 'clarifying';
    if (phase === 'progress') return 'progress';
    if (phase === 'actions') return 'actions';
    if (phase === 'saving') return 'applying';
    return 'understanding';
  }

  private getStageFromSession(session: PlanningSession): PlanningStage {
    if (session.status === 'completed' || session.stage === 'completed') {
      return 'done';
    }
    if (session.stage === 'saving') {
      return 'applying';
    }
    if (session.actionPlan || session.stage === 'actions') {
      return 'actions';
    }
    if (session.progressPlan || session.stage === 'progress') {
      return 'progress';
    }
    if (session.clarification?.questions?.length || session.stage === 'clarifying') {
      return 'clarifying';
    }
    if (session.runtimeStatus) {
      return this.getStageFromRuntime(session.runtimeStatus as RuntimeStatus);
    }
    return 'understanding';
  }

  private getStageProgressFromSession(session: PlanningSession): number {
    let progress = 0;
    const clarificationAnswers = session.clarification && session.clarification.answers
      ? Object.keys(session.clarification.answers)
      : [];
    if (session.goalDraft) progress = 1;
    if (session.clarification?.questions?.length || clarificationAnswers.length > 0 || session.stage === 'clarifying') {
      progress = Math.max(progress, 2);
    }
    if (session.progressPlan || session.stage === 'progress') {
      progress = Math.max(progress, 3);
    }
    if (session.actionPlan || session.stage === 'actions' || session.stage === 'saving' || session.status === 'completed') {
      progress = Math.max(progress, 4);
    }
    return progress;
  }

  private hydrateFromSession(session: PlanningSession, hint: string): void {
    this.sessionId = session.sessionId;
    this.sessionCreatedAt = session.createdAt || Date.now();
    this.intent = session.rawIntent || this.intent;
    this.source = session.source || this.source;
    this.targetGoalId = session.targetGoalId || this.targetGoalId;
    this.goalDraft = session.goalDraft || null;
    this.goalAssessment = session.goalAssessment || session.progressPlan?.assessment || null;
    this.progressPlan = session.progressPlan || null;
    this.actionPlan = session.actionPlan || null;
    this.qualityReport = session.qualityReport || null;
    this.questions = session.clarification?.questions || [];
    this.answers = session.clarification?.answers || {};
    this.runtimeStatus = session.runtimeStatus ? this.normalizeRuntimeStatus(session.runtimeStatus as RuntimeStatus) : null;
    this.stage = this.getStageFromSession(session);
    this.stageProgress = this.getStageProgressFromSession(session);
    this.isProcessing = !!session.runtimeStatus?.active && this.stage !== 'done' && this.stage !== 'error';
    this.processingText = this.getStageNarrative(this.stage === 'loading' ? 'understanding' : this.stage).title;
    this.restoreHint = hint;
    this.errorMessage = '';

    if (this.isProcessing && this.sessionId) {
      void this.startRuntimePolling();
      return;
    }

    if (this.stage === 'understanding' && this.goalDraft && this.sessionId) {
      void this.runClarification();
      return;
    }

    if (this.stage === 'clarifying' && this.questions.length === 0) {
      void this.runClarification();
      return;
    }
    if (this.stage === 'progress' && !this.progressPlan) {
      void this.runProgress();
      return;
    }
    if (this.stage === 'actions' && !this.actionPlan) {
      void this.runActions();
    }
  }

  private retryCurrentStage(): void {
    if (this.isProcessing) {
      return;
    }
    if (this.stage === 'clarifying') {
      void this.runClarification();
      return;
    }
    if (this.stage === 'progress') {
      void this.runProgress();
      return;
    }
    if (this.stage === 'actions') {
      void this.runActions();
      return;
    }
    if (this.stage === 'applying') {
      void this.runApply();
      return;
    }
    void this.runStart();
  }

  private async startRuntimePolling(): Promise<void> {
    this.stopRuntimePolling(false);
    await this.pollRuntimeStatus();
    this.statusTimer = setInterval(() => {
      this.pollRuntimeStatus();
    }, 1500);
  }

  private stopRuntimePolling(clearStatus: boolean = true): void {
    if (this.statusTimer !== -1) {
      clearInterval(this.statusTimer);
      this.statusTimer = -1;
    }
    if (clearStatus) {
      this.runtimeStatus = null;
    }
  }

  private async pollRuntimeStatus(): Promise<void> {
    if (!this.sessionId) {
      return;
    }
    const res = await GoalPlanningService.getSession(this.sessionId);
    if (res.success && res.data?.runtimeStatus) {
      this.runtimeStatus = this.normalizeRuntimeStatus(res.data.runtimeStatus as RuntimeStatus);
    }
  }

  private getRemainingText(): string {
    const estimatedMs = this.runtimeStatus?.estimatedMs || 0;
    if (!this.runtimeStatus || estimatedMs <= 0) {
      return '预计还需约 1 分钟';
    }
    const seconds = Math.ceil(estimatedMs / 1000);
    if (seconds <= 15) return '预计还需约 10-15 秒';
    if (seconds <= 30) return '预计还需约 20-30 秒';
    if (seconds <= 60) return '预计还需约 40-60 秒';
    if (seconds <= 120) return '预计还需约 90-120 秒';
    return '预计还需约 2 分钟以上';
  }

  private normalizeRuntimeStatus(status: RuntimeStatus): RuntimeStatus {
    return {
      phase: status.phase || status.stage || '',
      stepKey: status.stepKey || status.subStepKey || '',
      currentStep: Number(status.currentStep || status.subStepIndex || 0),
      totalSteps: Number(status.totalSteps || status.subStepTotal || 0),
      title: status.title || this.processingText,
      description: status.description || this.processingText,
      estimatedMs: Number(status.estimatedMs || status.estimatedRemainingMs || 0),
      startedAt: Number(status.startedAt || Date.now()),
      active: status.active,
      stage: status.stage,
      subStepKey: status.subStepKey,
      subStepIndex: status.subStepIndex,
      subStepTotal: status.subStepTotal,
      estimatedRemainingMs: status.estimatedRemainingMs,
      updatedAt: status.updatedAt,
      isSlow: status.isSlow
    };
  }

  private getCategoryLabel(category: string): string {
    if (category === 'HEALTH') return '健康';
    if (category === 'LEARNING') return '成长';
    if (category === 'FINANCE') return '理财';
    if (category === 'FUN') return '快乐';
    return category;
  }

  private getGoalKindLabel(goalKind: string): string {
    if (goalKind === 'exam_oriented') return '考试型';
    if (goalKind === 'habit_oriented') return '习惯型';
    if (goalKind === 'project_oriented') return '项目型';
    if (goalKind === 'outcome_oriented') return '结果型';
    return goalKind;
  }

  private formatTimestamp(ms?: number): string {
    if (!ms || isNaN(ms)) {
      return '待确认';
    }
    const date = new Date(ms);
    return `${date.getMonth() + 1}月${date.getDate()}日`;
  }

  private formatDateText(value?: string): string {
    if (!value) {
      return '待确认';
    }
    const date = new Date(value.replace(/-/g, '/'));
    if (isNaN(date.getTime())) {
      return value;
    }
    return `${date.getMonth() + 1}月${date.getDate()}日`;
  }

  private getWeekdayLabel(day: number): string {
    const labels: string[] = ['日', '一', '二', '三', '四', '五', '六'];
    return labels[day] || `${day}`;
  }

  private getRecurringMeta(action: RecurringAction): string {
    let schedule = '';
    if (action.rule === 'daily') {
      schedule = '每天';
    } else if (action.rule === 'weekly') {
      if (action.weekdays && action.weekdays.length > 0) {
        const weekdayLabels = action.weekdays.map((day: number) => `周${this.getWeekdayLabel(day)}`);
        schedule = weekdayLabels.join('、');
      } else {
        schedule = '每周';
      }
    } else if (action.rule === 'monthly') {
      schedule = '每月';
    } else if (action.cadence) {
      schedule = action.cadence;
    } else {
      schedule = '按计划执行';
    }

    if (action.reminderTime) {
      return `${schedule} · ${action.reminderTime} 提醒`;
    }
    return schedule;
  }

  private async syncCurrentSessionToServer(): Promise<void> {
    const sessionRes = await GoalPlanningService.getSession(this.sessionId);
    if (!sessionRes.success || !sessionRes.data) {
      return;
    }
    const session = sessionRes.data;
    session.goalDraft = this.goalDraft || session.goalDraft;
    session.goalAssessment = this.goalAssessment || session.goalAssessment;
    session.progressPlan = this.progressPlan || session.progressPlan;
    session.actionPlan = this.actionPlan || session.actionPlan;
    session.qualityReport = this.qualityReport || session.qualityReport;
    await GoalPlanningService.saveSession(session);
  }

  // ==========================
  // ====== UI Builders =======
  // ==========================

  // --- 顶部导航 ---
  @Builder
  private HeaderBar() {
    Row() {
      AppButton({
        text: '',
        iconName: 'chevron-left',
        variant: 'secondary',
        buttonSize: 'sm',
        tapAction: () => {
          if (this.shouldReturnToMainOnBack()) {
            this.getUIContext().getRouter().replaceUrl({ url: 'pages/MainPage' });
            return;
          }
          this.getUIContext().getRouter().back();
        }
      })
        .width(ICON_BUTTON_SIZE_MD)

      Column({ space: SPACE_2XS }) {
        Row({ space: SPACE_SM }) {
          Text('AI 目标规划')
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          AppStatusBadge({ text: `第 ${this.getActiveNarrative().step}/5 步`, tone: 'primary', iconName: 'progress' })
        }
        .width('100%')

        Text(this.goalDraft ? this.goalDraft.title : this.intent.split('\n')[0])
          .fontSize(TYPE_META).fontColor(this.themeColors.textSecondary).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: SPACE_MD })

    }
    .width('100%').padding({ left: SPACE_CARD, right: SPACE_CARD, top: SPACE_SM, bottom: SPACE_XS })
  }

  // --- 步骤进度条 ---
  @Builder
  private StepProgress() {
    Column({ space: SPACE_SM }) {
      Row({ space: SPACE_SM }) {
        ForEach(this.getStepLabels(), (item: StageStepData, index: number) => {
          Column({ space: SPACE_2XS }) {
            Stack() {
              Circle()
              .width(CHECKBOX_SIZE_LG).height(CHECKBOX_SIZE_LG)
                .fill(index <= this.getStageIndex() ? this.themeColors.primary : this.themeColors.surfaceLight)
              AppIcon({
                name: item.icon,
                iconSize: ICON_SIZE_LG,
                framed: false,
                color: index <= this.getStageIndex() ? this.themeColors.textOnPrimary : this.themeColors.textMuted
              })
            }
            Text(item.title)
              .fontSize(9)
              .fontWeight(index === this.getStageIndex() ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(index <= this.getStageIndex() ? this.themeColors.primary : this.themeColors.textMuted)
              .maxLines(1)
          }
          .layoutWeight(1).alignItems(HorizontalAlign.Center)

          if (index < 4) {
            Line()
              .width(SPACE_XS).height(SPACE_2XS)
              .backgroundColor(index < this.getStageIndex() ? this.themeColors.primary : this.themeColors.borderColor)
              .margin({ top: -SPACE_CARD })
          }
        })
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        this.InfoTag('入口', this.getSourceText())
        this.InfoTag('额度', this.getQuotaText())
      }
      .width('100%').padding({ left: SPACE_2XS, right: SPACE_2XS })
    }
    .width('100%').padding({ left: SPACE_MD, right: SPACE_MD, top: SPACE_2XS, bottom: SPACE_2XS })
  }

  private getStepLabels(): StageStepData[] {
    const steps: StageStepData[] = [
      { icon: 'goal', title: '理解', subtitle: '' } as StageStepData,
      { icon: 'help', title: '追问', subtitle: '' } as StageStepData,
      { icon: 'stats', title: '追踪', subtitle: '' } as StageStepData,
      { icon: 'plan', title: '行动', subtitle: '' } as StageStepData,
      { icon: 'task', title: '确认', subtitle: '' } as StageStepData
    ];
    return steps;
  }

  @Builder
  private StageOverviewCard() {
    Column() {
      AppCard({ variant: 'raised', paddingLevel: 'md', spacing: SPACE_SM }) {
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          AppStatusBadge({ text: '当前阶段', tone: 'primary', iconName: 'ai' })
          if (this.restoreHint.length > 0) {
            AppStatusBadge({ text: this.restoreHint, tone: 'success', iconName: 'success' })
          }
        }
        .width('100%')

        Text(this.getActiveNarrative().title)
          .fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary)
          .width('100%')
        Text(this.getActiveNarrative().description)
          .fontSize(TYPE_META).lineHeight(20).fontColor(this.themeColors.textSecondary).width('100%')

        Column({ space: SPACE_SM }) {
          Row({ space: SPACE_SM }) {
            AppStatusBadge({ text: '你会得到', tone: 'neutral', iconName: 'plan' })
            Text(this.getActiveNarrative().outcome)
              .fontSize(TYPE_META).fontColor(this.themeColors.textPrimary).layoutWeight(1)
          }
          .width('100%').alignItems(VerticalAlign.Top)

          Row({ space: SPACE_SM }) {
            AppStatusBadge({ text: '提醒', tone: 'neutral', iconName: 'reminder' })
            Text(this.isProcessing ? this.getRemainingText() : this.getActiveNarrative().trustHint)
              .fontSize(TYPE_META).fontColor(this.themeColors.textSecondary).layoutWeight(1)
          }
          .width('100%').alignItems(VerticalAlign.Top)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  // --- AI 处理中动画 ---
  @Builder
  private ProcessingView() {
    Column() {
      AppCard({ variant: 'raised', paddingLevel: 'md', spacing: PANEL_GAP }) {
        LoadingProgress().width(BUTTON_HEIGHT_MD).height(BUTTON_HEIGHT_MD).color(this.themeColors.primary)

        Column({ space: SPACE_SM }) {
          Text(this.runtimeStatus?.title || this.processingText)
            .fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Medium).fontColor(this.themeColors.textPrimary)
          Text(this.runtimeStatus?.description || this.getActiveNarrative().description)
            .fontSize(TYPE_META).lineHeight(20).fontColor(this.themeColors.textSecondary)
            .textAlign(TextAlign.Center)
        }
        .width('100%')

        Column() {
          AppCard({ variant: 'soft', paddingLevel: 'md', spacing: SPACE_SM }) {
            ForEach(this.getProcessingMilestones(), (item: string, index: number) => {
              Row({ space: SPACE_SM }) {
                Stack() {
                  Circle()
                    .width(CHECKBOX_SIZE_SM)
                    .height(CHECKBOX_SIZE_SM)
                    .fill(index <= this.getActiveMilestoneIndex() ? this.themeColors.primary : this.themeColors.surfaceLight)
                  if (index < this.getActiveMilestoneIndex()) {
                    AppIcon({
                      name: 'success',
                      iconSize: ICON_SIZE_XS,
                      framed: false,
                      color: this.themeColors.textOnPrimary
                    })
                  } else if (index === this.getActiveMilestoneIndex()) {
                    Circle()
                      .width(5)
                      .height(5)
                      .fill(this.themeColors.textOnPrimary)
                  }
                }
                Column({ space: SPACE_2XS }) {
                  Text(item)
                    .fontSize(TYPE_META)
                    .fontWeight(index === this.getActiveMilestoneIndex() ? FontWeight.Medium : FontWeight.Regular)
                    .fontColor(index <= this.getActiveMilestoneIndex() ? this.themeColors.textPrimary : this.themeColors.textMuted)
                  if (index === this.getActiveMilestoneIndex()) {
                    Text(this.getRemainingText())
                      .fontSize(TYPE_CAPTION).fontColor(this.themeColors.primary)
                  }
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Start)
              }
              .width('100%')
            })
          }
        }
        .width('100%')

        Text(this.runtimeStatus?.isSlow ? '分析比平时久一些，但这通常意味着 AI 正在处理更复杂的约束，请不要重复点击。' : '这一步还不会改动你的正式数据，结果出来后你可以继续删改。')
          .fontSize(TYPE_META).lineHeight(18).fontColor(this.themeColors.textSecondary)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ left: SPACE_SM, right: SPACE_SM })
      }
    }
    .width('100%')
  }

  private shouldShowMembershipEntry(): boolean {
    return this.errorMessage.indexOf('额度') >= 0 || !this.quota.allowed;
  }

  private isTaskSuggestionError(): boolean {
    return this.errorMessage.indexOf('待办任务') >= 0;
  }

  @Builder
  private InlineErrorBanner() {
    if (this.errorMessage.length > 0 && this.stage !== 'error') {
      Column() {
        AppCard({ variant: 'danger', paddingLevel: 'md', spacing: SPACE_SM }) {
          Text(this.errorMessage)
            .fontSize(TYPE_META).lineHeight(20).fontColor(this.themeColors.textPrimary).width('100%')
          Row({ space: SPACE_SM }) {
            AppButton({
              text: '重试这一步',
              variant: 'secondary',
              buttonSize: 'sm',
              iconName: 'sync',
              tapAction: () => { this.retryCurrentStage(); }
            })
              .layoutWeight(1)
            if (this.shouldShowMembershipEntry()) {
              AppButton({
                text: '去会员中心',
                variant: 'secondary',
                buttonSize: 'sm',
                iconName: 'wallet',
                tapAction: () => { this.getUIContext().getRouter().pushUrl({ url: 'pages/MembershipPage' }); }
              })
                .layoutWeight(1)
            }
          }
        }
      }
      .width('100%')
    }
  }

  // --- 错误视图 ---
  @Builder
  private ErrorView() {
    Column({ space: SECTION_GAP }) {
      AppIcon({ name: 'warning', iconSize: ICON_SIZE_XL })
      Text(this.getStageNarrative('error').title)
        .fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary)
      Text(this.errorMessage)
        .fontSize(TYPE_BODY).lineHeight(21).fontColor(this.themeColors.textSecondary).textAlign(TextAlign.Center)
        .width('100%').padding({ left: SPACE_CARD, right: SPACE_CARD })
      Text(this.getStageNarrative('error').trustHint)
        .fontSize(TYPE_META).fontColor(this.themeColors.textMuted)
        .textAlign(TextAlign.Center)
        .width('100%').padding({ left: SPACE_CARD, right: SPACE_CARD })
      Row({ space: SPACE_MD }) {
        AppButton({
          text: '返回',
          variant: 'secondary',
          buttonSize: 'sm',
          iconName: 'chevron-left',
          tapAction: () => { this.getUIContext().getRouter().back(); }
        })
          .layoutWeight(1)
        if (this.isTaskSuggestionError()) {
          AppButton({
            text: '改成待办',
            buttonSize: 'sm',
            iconName: 'task',
            tapAction: () => { this.openSuggestedTaskCreate(); }
          })
            .layoutWeight(1)
        } else {
          AppButton({
            text: '重新开始',
            buttonSize: 'sm',
            iconName: 'sync',
            tapAction: () => { this.retryCurrentStage(); }
          })
            .layoutWeight(1)
        }
        if (this.shouldShowMembershipEntry()) {
          AppButton({
            text: '会员中心',
            variant: 'secondary',
            buttonSize: 'sm',
            iconName: 'wallet',
            tapAction: () => { this.getUIContext().getRouter().pushUrl({ url: 'pages/MembershipPage' }); }
          })
            .layoutWeight(1)
        }
      }
      .width('100%').padding({ left: SPACE_CARD, right: SPACE_CARD })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%').padding(COMFORTABLE_SECTION_GAP).justifyContent(FlexAlign.Center)
  }

  // === Step 1: 目标理解结果 ===
  @Builder
  private UnderstandingView() {
    Column({ space: SPACE_CARD }) {
      if (this.goalDraft) {
      this.SectionCard('AI 已理解你的目标', this.goalDraft.title, this.goalDraft.description)

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          this.InfoTag('分类', this.getCategoryLabel(this.goalDraft.category))
          this.InfoTag('周期', `${this.goalDraft.periodDays}天`)
          if (this.goalDraft.goalKind) {
            this.InfoTag('类型', this.getGoalKindLabel(this.goalDraft.goalKind))
          }
        }
        .width('100%').padding({ left: PANEL_GAP, right: PANEL_GAP })

        Column({ space: SPACE_XS }) {
          Text('为什么先做这一步')
            .fontSize(TYPE_META).fontWeight(FontWeight.Medium).fontColor(this.themeColors.textPrimary)
            .width('100%')
          Text('先把目标边界和周期看清楚，后面的追踪和行动才不会越拆越散。')
            .fontSize(TYPE_META).lineHeight(19).fontColor(this.themeColors.textSecondary).width('100%')
        }
        .width('100%')
        .padding(SPACE_CARD)
        .backgroundColor(this.themeColors.surfaceLight)
        .borderRadius(RADIUS_LG)
      }
    }
    .width('100%')
  }

  // === Step 2: 追问表单 ===
  @Builder
  private ClarificationView() {
    Column({ space: SPACE_CARD }) {
      Column({ space: SPACE_SM }) {
            Text('补充一点背景，结果会更贴合你的真实节奏')
          .fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.themeColors.textPrimary)
          .width('100%')
        Text(`已回答 ${this.getClarificationAnsweredCount()}/${this.questions.length} 题${this.getClarificationRequiredCount() > 0 ? ` · 必答 ${this.getClarificationRequiredCount()} 题` : ''}`)
          .fontSize(TYPE_META).fontColor(this.themeColors.textSecondary).width('100%')
      }
      .width('100%').padding({ left: SPACE_2XS, right: SPACE_2XS })

      ForEach(this.questions, (q: ClarificationQuestion, index: number) => {
        // key: q.id
        Column({ space: SPACE_SM }) {
          Row() {
            Text(`${index + 1}. ${q.text}`)
              .fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.themeColors.textPrimary)
              .layoutWeight(1)
            if (q.required) {
              Circle()
                .width(6)
                .height(6)
                .fill(this.themeColors.danger)
            }
          }
          .width('100%')

          if (q.type === 'single_choice' && q.options && q.options.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(q.options, (opt: string) => {
                Text(opt)
                  .fontSize(TYPE_META)
                  .padding({ left: SPACE_MD, right: SPACE_MD, top: SPACE_SM, bottom: SPACE_SM })
                  .margin({ right: SPACE_SM, bottom: SPACE_SM })
                  .backgroundColor(this.answers[q.id] === opt ? this.themeColors.primary : this.themeColors.surfaceLight)
                  .fontColor(this.answers[q.id] === opt ? this.themeColors.textOnPrimary : this.themeColors.textPrimary)
                  .borderRadius(20)
                  .onClick(() => { this.updateAnswer(q.id, opt); })
              })
            }
            .width('100%')
          } else {
            TextInput({ placeholder: q.placeholder || '请输入', text: this.answers[q.id] || '' })
              .width('100%').height(BUTTON_HEIGHT_MD)
              .backgroundColor(this.themeColors.surfaceLight)
              .borderRadius(RADIUS_MD)
              .onChange((value: string) => { this.updateAnswer(q.id, value); })
          }
        }
        .width('100%')
        .padding(SPACE_CARD)
        .backgroundColor(this.themeColors.cardBackground)
        .borderRadius(RADIUS_LG)
      })

      if (this.hasMissingRequiredAnswers()) {
        Text('带 * 的问题会直接影响 AI 的判断，如果没有标准答案，先给一个大致范围也比留空更稳。')
          .fontSize(TYPE_META).lineHeight(18).fontColor(this.themeColors.warning)
          .width('100%')
          .padding(SPACE_MD)
          .backgroundColor(this.themeColors.warningSubtle)
          .borderRadius(RADIUS_MD)
      } else {
        Text('如果后面看到的规划不够贴合，你仍然可以回到这一步补充信息后重新生成。')
          .fontSize(TYPE_META).lineHeight(18).fontColor(this.themeColors.textSecondary)
          .width('100%')
          .padding(SPACE_MD)
          .backgroundColor(this.themeColors.surfaceLight)
          .borderRadius(RADIUS_MD)
      }
    }
    .width('100%')
  }

  // === Step 3: 进度追踪 ===
  @Builder
  private ProgressView() {
    Column({ space: SPACE_CARD }) {
      Column({ space: SPACE_XS }) {
      Text('先定义“怎么算在前进”')
          .fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.themeColors.textPrimary)
          .width('100%')
        Text('追踪项不是越多越好，保留 1-3 条你真的愿意持续更新的指标就够了。')
          .fontSize(TYPE_META).lineHeight(18).fontColor(this.themeColors.textSecondary).width('100%')
      }
      .width('100%')
      .padding(SPACE_CARD)
      .backgroundColor(this.themeColors.surfaceLight)
      .borderRadius(RADIUS_LG)

      // 难度评估卡片
      if (this.goalAssessment) {
        Column({ space: SPACE_SM }) {
          Row() {
            Text('难度评估').fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary)
            Blank()
            Text(this.getDifficultyLabel(this.goalAssessment.level))
              .fontSize(TYPE_META).padding({ left: SPACE_SM, right: SPACE_SM, top: SPACE_2XS, bottom: SPACE_2XS })
              .backgroundColor(this.getDifficultyColor(this.goalAssessment.level))
              .fontColor(this.themeColors.textOnPrimary).borderRadius(12)
          }
          .width('100%')

          Text(this.goalAssessment.summary)
            .fontSize(TYPE_META).lineHeight(20).fontColor(this.themeColors.textSecondary).width('100%')

          if (this.goalAssessment.shouldReviseGoal && this.goalAssessment.blockingWarning) {
            Text(this.goalAssessment.blockingWarning)
              .fontSize(TYPE_META).lineHeight(18).fontColor(this.themeColors.warning).width('100%')
              .padding(SPACE_SM).backgroundColor(this.themeColors.warningSubtle).borderRadius(10)
          }
        }
        .width('100%').padding(SPACE_CARD)
        .backgroundColor(this.themeColors.cardBackground).borderRadius(RADIUS_LG)
      }

      // 追踪列表
      Row() {
            Text('进度追踪').fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary)
        Blank()
        AppButton({
          text: 'AI补一条',
          variant: 'secondary',
          buttonSize: 'sm',
          iconName: 'ai',
          tapAction: () => { this.addAiTrack(); }
        })
        AppButton({
          text: '手动补充',
          buttonSize: 'sm',
          iconName: 'plus',
          tapAction: () => { this.openTrackEditor(); }
        })
      }
      .width('100%').padding({ left: SPACE_CARD, right: SPACE_CARD })

      if (this.progressPlan && this.progressPlan.tracks.length > 0) {
        ForEach(this.progressPlan.tracks, (track: ProgressTrack, index: number) => {
          Column({ space: SPACE_XS }) {
            Row() {
              Text(track.title)
                .fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.themeColors.textPrimary)
                .layoutWeight(1)
              Text(`${track.targetValue} ${track.unit}`)
                .fontSize(TYPE_META).fontColor(this.themeColors.primary)
            }
            .width('100%')

            Text(track.completionCriteria)
              .fontSize(TYPE_META).lineHeight(18).fontColor(this.themeColors.textSecondary).width('100%')

            if (track.checkpointText) {
              Text(`建议检查点：${track.checkpointText}`)
                .fontSize(TYPE_CAPTION).fontColor(this.themeColors.textMuted).width('100%')
            }

            if (track.reason) {
              Text(`为什么追这个：${track.reason}`)
                .fontSize(TYPE_CAPTION).fontColor(this.themeColors.textMuted).width('100%').fontStyle(FontStyle.Italic)
            }

            Row({ space: SPACE_SM }) {
              AppButton({
                text: '重生成',
                variant: 'secondary',
                buttonSize: 'sm',
                iconName: 'sync',
                tapAction: () => { this.regenerateTrack(index); }
              })
                .layoutWeight(1)
              AppButton({
                text: '编辑',
                variant: 'secondary',
                buttonSize: 'sm',
                iconName: 'note',
                tapAction: () => { this.openTrackEditor(index); }
              })
                .layoutWeight(1)
              AppButton({
                text: '删除',
                variant: 'danger',
                buttonSize: 'sm',
                iconName: 'warning',
                tapAction: () => { this.removeTrack(index); }
              })
                .layoutWeight(1)
            }
            .width('100%')
          }
          .width('100%').padding(PANEL_GAP)
          .backgroundColor(this.themeColors.cardBackground).borderRadius(RADIUS_MD)
        })
      }
    }
    .width('100%')
  }

  // === Step 4: 行动方案 ===
  @Builder
  private ActionsView() {
    Column({ space: SPACE_CARD }) {
      if (this.actionPlan) {
        Column({ space: SPACE_XS }) {
      Text('现在把追踪落到行动与提醒')
            .fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.themeColors.textPrimary)
            .width('100%')
          Text('先从起步行动开始，习惯提醒和关键日期是帮你把节奏稳住，而不是增加心理负担。')
            .fontSize(TYPE_META).lineHeight(18).fontColor(this.themeColors.textSecondary).width('100%')
        }
        .width('100%')
        .padding(SPACE_CARD)
        .backgroundColor(this.themeColors.surfaceLight)
        .borderRadius(RADIUS_LG)

        if (this.progressPlan && this.progressPlan.tracks.length > 0) {
          Column({ space: SPACE_SM }) {
              Text(`当前追踪 (${this.progressPlan.tracks.length}项)`)
              .fontSize(TYPE_BODY).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary).width('100%').padding({ left: 16 })
            ForEach(this.progressPlan.tracks, (track: ProgressTrack) => {
              Text(`• ${track.title} · 目标 ${track.targetValue}${track.unit}`)
                .fontSize(TYPE_META).fontColor(this.themeColors.textSecondary).width('100%').padding({ left: SPACE_CARD, right: SPACE_CARD })
            })
          }
          .width('100%')
        }

        // 一次性任务
        Row({ space: SPACE_SM }) {
                Text('起步行动').fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary)
          Blank()
          AppButton({
            text: '重生成任务',
            variant: 'secondary',
            buttonSize: 'sm',
            iconName: 'sync',
            tapAction: () => { this.regenerateTasks(); }
          })
          AppButton({
            text: '手动补任务',
            buttonSize: 'sm',
            iconName: 'plus',
            tapAction: () => { this.openTaskEditor(); }
          })
        }
        .width('100%').padding({ left: SPACE_CARD, right: SPACE_CARD })
        .alignItems(VerticalAlign.Center)
        if (this.actionPlan.oneOffTasks.length > 0) {
          ForEach(this.actionPlan.oneOffTasks, (task: OneOffTask, index: number) => {
            Row() {
              Column({ space: SPACE_2XS }) {
                Text(task.title).fontSize(TYPE_BODY).fontWeight(FontWeight.Medium).fontColor(this.themeColors.textPrimary)
                  .width('100%')
                if (task.description) {
                  Text(task.description).fontSize(TYPE_META).fontColor(this.themeColors.textSecondary).width('100%').maxLines(2)
                }
              }
              .layoutWeight(1)
              if (task.priority === 'high') {
                Text('高').fontSize(TYPE_CAPTION).fontColor(this.themeColors.danger).padding({ left: SPACE_XS, right: SPACE_XS, top: SPACE_2XS, bottom: SPACE_2XS })
                  .backgroundColor(this.themeColors.dangerSubtle).borderRadius(6)
              }
            }
            .width('100%').padding(PANEL_GAP)
            .backgroundColor(this.themeColors.cardBackground).borderRadius(RADIUS_MD)

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              if (task.suggestedDueDate) {
                this.InfoTag('建议日期', this.formatTimestamp(task.suggestedDueDate))
              }
              if (task.estimatedHours) {
                this.InfoTag('预计投入', `${task.estimatedHours} 小时`)
              }
            }
            .width('100%')

            Row({ space: SPACE_SM }) {
              AppButton({
                text: '删除',
                variant: 'danger',
                buttonSize: 'sm',
                iconName: 'warning',
                tapAction: () => { this.removeTask(index); }
              })
                .layoutWeight(1)
            }
            .width('100%')
          })
        } else {
          Text('当前还没有起步任务，你可以手动补充，或让 AI 再生成一次。')
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
            .padding({ left: SPACE_CARD, right: SPACE_CARD })
        }

        // 重复行动
        if (this.actionPlan.recurringActions.length > 0) {
                Text('日常习惯').fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary)
            .width('100%').padding({ left: 16 })
          ForEach(this.actionPlan.recurringActions, (action: RecurringAction) => {
            Column({ space: SPACE_XS }) {
              Row() {
                Text(action.title).fontSize(TYPE_BODY).fontColor(this.themeColors.textPrimary).layoutWeight(1)
                if (action.rule) {
                  Text(this.getRuleLabel(action.rule))
                    .fontSize(TYPE_CAPTION).fontColor(this.themeColors.primary)
                    .padding({ left: SPACE_XS, right: SPACE_XS, top: SPACE_2XS, bottom: SPACE_2XS })
                    .backgroundColor(this.themeColors.surfaceLight).borderRadius(6)
                }
              }
              .width('100%')
              Text(this.getRecurringMeta(action))
                .fontSize(TYPE_META).fontColor(this.themeColors.textSecondary).width('100%')
              if (action.description) {
                Text(action.description)
                  .fontSize(TYPE_META).lineHeight(18).fontColor(this.themeColors.textMuted).width('100%')
              }
            }
            .width('100%').padding(PANEL_GAP)
            .backgroundColor(this.themeColors.cardBackground).borderRadius(RADIUS_MD)
          })
        }

        // 倒计时
        if (this.actionPlan.countdowns.length > 0) {
          Text('关键日期').fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary)
            .width('100%').padding({ left: 16 })
          ForEach(this.actionPlan.countdowns, (item: CountdownItem) => {
            Column({ space: SPACE_XS }) {
              Row() {
                Text(item.title).fontSize(TYPE_BODY).fontColor(this.themeColors.textPrimary).layoutWeight(1)
                Text(this.formatDateText(item.targetDate)).fontSize(TYPE_META).fontColor(this.themeColors.textSecondary)
              }
              .width('100%')
              if (item.description) {
                Text(item.description)
                  .fontSize(TYPE_META).lineHeight(18).fontColor(this.themeColors.textMuted).width('100%')
              }
            }
            .width('100%').padding(PANEL_GAP)
            .backgroundColor(this.themeColors.cardBackground).borderRadius(RADIUS_MD)
          })
        }

      }
    }
    .width('100%')
  }

  // === Step 5: 方案总览 ===
  @Builder
  private ReviewView() {
    Column({ space: SPACE_CARD }) {
      if (this.qualityReport) {
        // 评分卡片
        Column({ space: SPACE_SM }) {
          Row() {
            Text('方案评估').fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary)
            Blank()
            Text(`${this.qualityReport.overallScore}分`)
              .fontSize(24).fontWeight(FontWeight.Bold)
              .fontColor(this.qualityReport.overallScore >= 70 ? this.themeColors.success : this.themeColors.warning)
          }
          .width('100%')

          Text(this.qualityReport.summary)
            .fontSize(TYPE_META).lineHeight(20).fontColor(this.themeColors.textSecondary).width('100%')

          // 建议
          if (this.qualityReport.suggestions && this.qualityReport.suggestions.length > 0) {
            Column({ space: SPACE_2XS }) {
              ForEach(this.qualityReport.suggestions, (s: string) => {
                        Text(s).fontSize(TYPE_META).fontColor(this.themeColors.textSecondary).width('100%')
              })
            }
            .width('100%')
          }

          // 需关注
          if (this.qualityReport.needsUserAttention && this.qualityReport.needsUserAttention.length > 0) {
            Column({ space: SPACE_2XS }) {
              ForEach(this.qualityReport.needsUserAttention, (s: string) => {
                Text(s).fontSize(TYPE_META).fontColor(this.themeColors.warning).width('100%')
              })
            }
            .width('100%')
          }
        }
        .width('100%').padding(SPACE_CARD)
        .backgroundColor(this.themeColors.cardBackground).borderRadius(RADIUS_LG)
      }

      // 目标概览
      if (this.goalDraft) {
                this.SectionCard('目标', this.goalDraft.title, this.goalDraft.description)
      }

      // 追踪概览
      if (this.progressPlan && this.progressPlan.tracks.length > 0) {
        Column({ space: SPACE_SM }) {
                  Text(`进度追踪 (${this.progressPlan.tracks.length}项)`)
            .fontSize(TYPE_BODY).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary).width('100%')
          ForEach(this.progressPlan.tracks, (t: ProgressTrack) => {
            Text(`• ${t.title}  →  ${t.targetValue}${t.unit}`)
              .fontSize(TYPE_META).fontColor(this.themeColors.textSecondary).width('100%')
          })
        }
        .width('100%').padding(SPACE_CARD)
        .backgroundColor(this.themeColors.cardBackground).borderRadius(RADIUS_LG)
      }

      // 行动概览
      if (this.actionPlan) {
        Column({ space: SPACE_SM }) {
                  Text(`行动方案`)
            .fontSize(TYPE_BODY).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary).width('100%')
          Text(`${this.actionPlan.oneOffTasks.length} 个起步行动 · ${this.actionPlan.recurringActions.length} 个日常习惯 · ${this.actionPlan.countdowns.length} 个关键日期`)
            .fontSize(TYPE_META).fontColor(this.themeColors.textSecondary).width('100%')
        }
        .width('100%').padding(SPACE_CARD)
        .backgroundColor(this.themeColors.cardBackground).borderRadius(RADIUS_LG)
      }
    }
    .width('100%')
  }

  // === 完成视图 ===
  @Builder
  private DoneView() {
    Column({ space: SECTION_GAP }) {
              AppIcon({ name: 'success', iconSize: ICON_SIZE_XL })
      Text('方案已成功保存！')
        .fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary)
      Text('正在跳转到目标详情页...')
        .fontSize(TYPE_META).fontColor(this.themeColors.textSecondary)
    }
    .width('100%').padding(COMFORTABLE_SECTION_GAP)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  // --- 通用组件 ---
  @Builder
  private SectionCard(title: string, heading: string, desc: string) {
    Column() {
      AppCard({ variant: 'base', paddingLevel: 'md', spacing: SPACE_SM }) {
        Text(title).fontSize(TYPE_BODY).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary).width('100%')
        Text(heading).fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Medium).fontColor(this.themeColors.textPrimary).width('100%')
        if (desc) {
          Text(desc).fontSize(TYPE_META).lineHeight(20).fontColor(this.themeColors.textSecondary).width('100%')
        }
      }
    }
    .width('100%')
  }

  @Builder
  private InfoTag(label: string, value: string) {
    Row({ space: SPACE_2XS }) {
      Text(label).fontSize(TYPE_CAPTION).fontColor(this.themeColors.textMuted)
      Text(value)
        .fontSize(TYPE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themeColors.textPrimary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: SPACE_SM, right: SPACE_SM, top: SPACE_2XS, bottom: SPACE_2XS })
    .margin({ right: SPACE_SM, bottom: SPACE_SM })
    .backgroundColor(this.themeColors.surfaceLight).borderRadius(8)
  }

  // --- 底部操作栏 ---
  @Builder
  private BottomActions() {
    if (this.stage === 'clarifying' && !this.isProcessing) {
      Row({ space: SPACE_MD }) {
        AppButton({
          text: this.hasMissingRequiredAnswers() ? '先跳过' : '稍后再补',
          variant: 'secondary',
          iconName: 'warning',
          tapAction: () => { this.runProgress(); }
        })
          .layoutWeight(1)
        AppButton({
          text: this.hasMissingRequiredAnswers() ? '带现有信息继续' : '生成进度方案',
          iconName: 'progress',
          tapAction: () => { this.runProgress(); }
        })
          .layoutWeight(2)
      }
      .width('100%').padding({ left: PANEL_GAP, right: PANEL_GAP, top: SPACE_SM, bottom: SPACE_MD })
    } else if (this.stage === 'progress' && !this.isProcessing) {
      Column({ space: SPACE_SM }) {
        Text('确认这些追踪项后，下一步会自动生成起步行动、习惯提醒和关键日期。')
          .fontSize(TYPE_META).lineHeight(18).fontColor(this.themeColors.textSecondary)
          .width('100%')
          .padding({ left: SPACE_CARD, right: SPACE_CARD })
        Row() {
          AppButton({
            text: '下一步：生成行动方案',
            iconName: 'plan',
            tapAction: () => { this.runActions(); }
          })
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ left: SPACE_CARD, right: SPACE_CARD, bottom: SPACE_CARD })
      }
      .width('100%').padding({ top: 8 })
    } else if (this.stage === 'actions' && !this.isProcessing) {
      Column({ space: SPACE_SM }) {
        Text('确认创建后，会一次性写入目标、任务、提醒和倒计时。')
          .fontSize(TYPE_META).lineHeight(18).fontColor(this.themeColors.textSecondary)
          .width('100%')
          .padding({ left: SPACE_CARD, right: SPACE_CARD })
        Row() {
          AppButton({
            text: '确认并创建目标',
            iconName: 'goal',
            tapAction: () => { this.runApply(); }
          })
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ left: SPACE_CARD, right: SPACE_CARD, bottom: SPACE_CARD })
      }
      .width('100%').padding({ top: 8 })
    }
  }

  // ==========================
  // ====== 辅助方法 ==========
  // ==========================

  private getDifficultyLabel(level: string): string {
    if (level === 'easy') return '简单';
    if (level === 'moderate') return '中等';
    if (level === 'hard') return '困难';
    if (level === 'very_hard') return '极难';
    return '中等';
  }

  private getDifficultyColor(level: string): string {
    if (level === 'easy') return this.themeColors.success;
    if (level === 'moderate') return this.themeColors.warning;
    if (level === 'hard') return this.themeColors.danger;
    if (level === 'very_hard') return this.themeColors.danger;
    return this.themeColors.warning;
  }

  private getRuleLabel(rule: string): string {
    if (rule === 'daily') return '每天';
    if (rule === 'weekly') return '每周';
    if (rule === 'monthly') return '每月';
    return rule;
  }

  // ==========================
  // ===== 主页面布局 ==========
  // ==========================

  build() {
    Column() {
      this.HeaderBar()

      if (this.stage !== 'error' && this.stage !== 'loading') {
        this.StepProgress()
      }

      if (this.isProcessing || this.stage === 'loading') {
        Column({ space: SPACE_CARD }) {
          if (this.stage !== 'loading') {
            this.StageOverviewCard()
          }
          this.ProcessingView()
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center).padding({ left: PANEL_GAP, right: PANEL_GAP, top: SPACE_SM, bottom: SPACE_SM })
      } else if (this.stage === 'error') {
        Column() {
          this.ErrorView()
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.stage === 'done') {
        Column() {
          this.DoneView()
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: SPACE_MD }) {
            this.StageOverviewCard()

            // Step 1 结果始终显示
            if (this.goalDraft && this.stageProgress >= 1) {
              this.UnderstandingView()
            }

            // Step 2 追问表单
            if (this.stage === 'clarifying' && this.stageProgress >= 2) {
              this.ClarificationView()
            }

            // Step 3 进度追踪
            if ((this.stage === 'progress' || this.stageProgress >= 3) && this.progressPlan) {
              this.ProgressView()
            }

            // Step 4 行动方案
            if ((this.stage === 'actions' || this.stageProgress >= 4) && this.actionPlan) {
              this.ActionsView()
            }

            this.InlineErrorBanner()

            Blank().height(BOTTOM_CONTENT_SPACER)
          }
          .width('100%').padding({ left: 14, right: 14, top: 10 })
        }
        .layoutWeight(1).scrollBar(BarState.Off)
      }

      this.BottomActions()

      if (this.showTrackEditor) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.themeColors.surfaceOverlay)

        Column() {
          AppCard({ variant: 'raised', paddingLevel: 'md', spacing: SPACE_MD }) {
            Text(this.editingTrackIndex >= 0 ? '编辑追踪' : '手动补充追踪')
              .fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary).width('100%')
            TextInput({ text: this.trackTitleInput, placeholder: '追踪标题' })
              .width('100%').height(BUTTON_HEIGHT_MD).backgroundColor(this.themeColors.surfaceLight).borderRadius(RADIUS_MD)
              .onChange((v: string) => { this.trackTitleInput = v; })
            TextInput({ text: this.trackUnitInput, placeholder: '单位，如 分/次/kg/%' })
              .width('100%').height(BUTTON_HEIGHT_MD).backgroundColor(this.themeColors.surfaceLight).borderRadius(RADIUS_MD)
              .onChange((v: string) => { this.trackUnitInput = v; })
            TextInput({ text: this.trackTargetInput, placeholder: '目标值' })
              .width('100%').height(BUTTON_HEIGHT_MD).backgroundColor(this.themeColors.surfaceLight).borderRadius(RADIUS_MD)
              .onChange((v: string) => { this.trackTargetInput = v; })
            TextInput({ text: this.trackCriteriaInput, placeholder: '完成标准' })
              .width('100%').height(BUTTON_HEIGHT_MD).backgroundColor(this.themeColors.surfaceLight).borderRadius(RADIUS_MD)
              .onChange((v: string) => { this.trackCriteriaInput = v; })
            TextInput({ text: this.trackCheckpointInput, placeholder: '检查点（可选）' })
              .width('100%').height(BUTTON_HEIGHT_MD).backgroundColor(this.themeColors.surfaceLight).borderRadius(RADIUS_MD)
              .onChange((v: string) => { this.trackCheckpointInput = v; })
            Row({ space: SPACE_MD }) {
              AppButton({
                text: '取消',
                variant: 'secondary',
                buttonSize: 'sm',
                iconName: 'chevron-left',
                tapAction: () => { this.closeTrackEditor(); }
              })
                .layoutWeight(1)
              AppButton({
                text: '保存',
                buttonSize: 'sm',
                iconName: 'success',
                tapAction: () => { this.saveTrackEditor(); }
              })
                .layoutWeight(1)
            }
            .width('100%')
          }
        }
        .width('90%')
      }

      if (this.showTaskEditor) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.themeColors.surfaceOverlay)

        Column() {
          AppCard({ variant: 'raised', paddingLevel: 'md', spacing: SPACE_MD }) {
            Text('手动补充任务')
              .fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary).width('100%')
            TextInput({ text: this.taskTitleInput, placeholder: '任务标题' })
              .width('100%').height(BUTTON_HEIGHT_MD).backgroundColor(this.themeColors.surfaceLight).borderRadius(RADIUS_MD)
              .onChange((v: string) => { this.taskTitleInput = v; })
            TextInput({ text: this.taskDescInput, placeholder: '任务说明（可选）' })
              .width('100%').height(BUTTON_HEIGHT_MD).backgroundColor(this.themeColors.surfaceLight).borderRadius(RADIUS_MD)
              .onChange((v: string) => { this.taskDescInput = v; })
            TextInput({ text: this.taskDueInput, placeholder: '截止日期（如 2026-08-20，可选）' })
              .width('100%').height(BUTTON_HEIGHT_MD).backgroundColor(this.themeColors.surfaceLight).borderRadius(RADIUS_MD)
              .onChange((v: string) => { this.taskDueInput = v; })
            TextInput({ text: this.taskHoursInput, placeholder: '预计耗时（小时，可选）' })
              .width('100%').height(BUTTON_HEIGHT_MD).backgroundColor(this.themeColors.surfaceLight).borderRadius(RADIUS_MD)
              .onChange((v: string) => { this.taskHoursInput = v; })
            Row({ space: SPACE_MD }) {
              AppButton({
                text: '取消',
                variant: 'secondary',
                buttonSize: 'sm',
                iconName: 'chevron-left',
                tapAction: () => { this.closeTaskEditor(); }
              })
                .layoutWeight(1)
              AppButton({
                text: '保存',
                buttonSize: 'sm',
                iconName: 'success',
                tapAction: () => { this.saveTaskEditor(); }
              })
                .layoutWeight(1)
            }
            .width('100%')
          }
        }
        .width('90%')
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.themeColors.background)
  }
}
