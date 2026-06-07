import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { VoiceCreateService, VoiceCreateResult, VoiceCreateParsed } from '../services/VoiceCreateService';
import { QuotaService, SpendResult } from '../services/QuotaService';
import { authService } from '../services/AuthService';
import { VoiceRecognitionService } from '../services/VoiceRecognitionService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppIcon } from '../ui/base/AppIcon';
import { ICON_SIZE_XS } from '../foundation/tokens/IconTokens';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { TelemetryService, type TelemetryProperties } from '../services/TelemetryService';
import { AppErrorService } from '../services/AppErrorService';
import { hasMicrophonePermission, requestMicrophonePermission } from '../Utils/UserPerm';
import { TYPE_BODY, TYPE_CAPTION, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';

export interface VoiceCreateOutput {
  intent: string;
  parsed: VoiceCreateParsed;
}

type VoiceOverlayPhase = 'ready' | 'checking' | 'recording' | 'analyzing' | 'done' | 'error';

interface PhaseDescriptor {
  badge: string;
  title: string;
  description: string;
}

@Component
export struct VoiceCreateOverlay {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  hostContext: Context | null = null;

  @State phase: VoiceOverlayPhase = 'ready';
  @State realtimeText: string = '';
  @State errorMessage: string = '';
  @State analyzeResult: VoiceCreateResult | null = null;
  @State dotCount: number = 0;
  @State requireMembership: boolean = false;
  @State requireLogin: boolean = false;

  onResult: (output: VoiceCreateOutput) => void = () => {};
  onClose: () => void = () => {};
  onBusyStateChange: (busy: boolean) => void = () => {};

  private dotTimer: number = -1;
  private continueTimer: number = -1;
  private holdStartTimer: number = -1;
  private transcriptScrollTimer: number = -1;
  private readonly voiceRecognition = VoiceRecognitionService.getInstance();
  private readonly transcriptScroller: Scroller = new Scroller();
  private isVoiceButtonPressed: boolean = false;
  private voicePressToken: number = 0;
  private readonly voiceBarHeight: number = 64;
  private readonly compactStageCardHeight: number = 108;
  private readonly fixedStageCardHeight: number = 148;
  private readonly transcriptViewportHeight: number = 44;

  aboutToAppear(): void {
    this.resetViewState();
    this.trackVoiceEvent('voice_overlay_viewed');
  }

  aboutToDisappear(): void {
    this.clearTimers();
    this.voiceRecognition.cancelRecognition();
    this.voiceRecognition.reset();
    this.onBusyStateChange(false);
  }

  private isBlockingClose(phase: VoiceOverlayPhase): boolean {
    return phase === 'checking' || phase === 'recording' || phase === 'analyzing' || phase === 'done';
  }

  private updatePhase(phase: VoiceOverlayPhase): void {
    this.phase = phase;
    this.onBusyStateChange(this.isBlockingClose(phase));
  }

  private resetViewState(): void {
    this.updatePhase('ready');
    this.realtimeText = '';
    this.errorMessage = '';
    this.analyzeResult = null;
    this.requireMembership = false;
    this.requireLogin = false;
    this.clearTimers();
  }

  private setError(
    message: string,
    requireMembership: boolean = false,
    requireLogin: boolean = false
  ): void {
    const previousPhase: VoiceOverlayPhase = this.phase;
    this.updatePhase('error');
    const normalizedMessage = AppErrorService.fromMessage(message, '语音创建失败，请稍后重试');
    this.errorMessage = (AppErrorService.isTechnicalMessage(message) || normalizedMessage.indexOf(':') > 0)
      ? normalizedMessage
      : this.getFriendlyErrorMessage(message);
    this.requireMembership = requireMembership;
    this.requireLogin = requireLogin;
    this.clearTimers();
    const failureProps: TelemetryProperties = {
      "phase": previousPhase,
      "reason": this.getVoiceFailureReason(message, requireMembership, requireLogin),
      "requireMembership": requireMembership,
      "requireLogin": requireLogin,
      "hasTranscript": this.realtimeText.trim().length > 0
    };
    this.trackVoiceEvent('voice_create_failed', failureProps);
  }

  private trackVoiceEvent(
    eventName: string,
    properties?: TelemetryProperties
  ): void {
    TelemetryService.track(eventName, properties, 'voice');
  }

  private getVoiceFailureReason(
    message: string,
    requireMembership: boolean,
    requireLogin: boolean
  ): string {
    const normalized: string = message.trim().toLowerCase();
    if (requireLogin || normalized.includes('登录')) {
      return 'login_required';
    }
    if (
      requireMembership ||
      normalized.includes('会员') ||
      normalized.includes('积分') ||
      normalized.includes('额度') ||
      normalized.includes('权益')
    ) {
      return 'membership_required';
    }
    if (
      normalized.includes('没有识别到有效内容') ||
      normalized.includes('先输入一句话') ||
      normalized.includes('没有听清')
    ) {
      return 'empty_transcript';
    }
    if (
      normalized.includes('这句话我还没完全听懂') ||
      normalized.includes('语音理解失败') ||
      normalized.includes('识别失败') ||
      normalized.includes('解析失败')
    ) {
      return 'understanding_failed';
    }
    if (
      normalized.includes('libneonui') ||
      normalized.includes('arm64') ||
      normalized.includes('初始化失败') ||
      normalized.includes('未成功加载')
    ) {
      return 'recognition_unavailable';
    }
    if (
      normalized.includes('404') ||
      normalized.includes('500') ||
      normalized.includes('server') ||
      normalized.includes('network') ||
      normalized.includes('服务器错误') ||
      normalized.includes('服务错误') ||
      normalized.includes('网络异常')
    ) {
      return 'service_error';
    }
    return 'unknown';
  }

  private getFriendlyErrorMessage(message: string): string {
    const trimmed = message.trim();
    const lower = trimmed.toLowerCase();
    const hasTranscript = this.realtimeText.trim().length > 0;

    if (!trimmed) {
      return '创建失败，请重试';
    }
    if (trimmed.includes('没有识别到有效内容') || trimmed.includes('先输入一句话')) {
      return hasTranscript ? '内容已识别，但创建失败，请重试' : '没有听清，请再说一次';
    }
    if (
      trimmed.includes('这句话我还没完全听懂') ||
      trimmed.includes('语音理解失败') ||
      trimmed.includes('识别失败') ||
      trimmed.includes('解析失败')
    ) {
      return hasTranscript ? '内容已识别，但创建失败，请重试' : '没理解这句话，请换种说法';
    }
    if (trimmed.includes('登录')) {
      return '请先登录后再使用语音创建';
    }
    if (trimmed.includes('会员') || trimmed.includes('积分') || trimmed.includes('权益') || trimmed.includes('额度')) {
      return '当前暂时无法使用语音创建';
    }
    if (
      lower.includes('404') ||
      lower.includes('500') ||
      lower.includes('server') ||
      lower.includes('network') ||
      trimmed.includes('服务器错误') ||
      trimmed.includes('服务错误') ||
      trimmed.includes('网络异常')
    ) {
      return hasTranscript ? '内容已识别，但创建失败，请重试' : '创建失败，请稍后再试';
    }
    if (
      lower.includes('libneonui') ||
      lower.includes('arm64') ||
      trimmed.includes('初始化失败') ||
      trimmed.includes('未成功加载')
    ) {
      return '语音服务暂不可用，请稍后再试';
    }
    if (hasTranscript && (trimmed.includes('失败') || trimmed.includes('错误'))) {
      return '内容已识别，但创建失败，请重试';
    }
    return trimmed.length > 18 ? '创建失败，请重试' : trimmed;
  }

  private clearTimers(): void {
    if (this.dotTimer !== -1) {
      clearInterval(this.dotTimer);
      this.dotTimer = -1;
    }
    if (this.continueTimer !== -1) {
      clearTimeout(this.continueTimer);
      this.continueTimer = -1;
    }
    if (this.holdStartTimer !== -1) {
      clearTimeout(this.holdStartTimer);
      this.holdStartTimer = -1;
    }
    if (this.transcriptScrollTimer !== -1) {
      clearTimeout(this.transcriptScrollTimer);
      this.transcriptScrollTimer = -1;
    }
  }

  private startDotAnimation(): void {
    this.dotCount = 0;
    if (this.dotTimer !== -1) {
      clearInterval(this.dotTimer);
    }
    this.dotTimer = setInterval(() => {
      this.dotCount = (this.dotCount + 1) % 4;
    }, 500);
  }

  private scrollTranscriptToBottom(): void {
    if (this.transcriptScrollTimer !== -1) {
      clearTimeout(this.transcriptScrollTimer);
    }
    this.transcriptScrollTimer = setTimeout(() => {
      this.transcriptScrollTimer = -1;
      try {
        this.transcriptScroller.scrollEdge(Edge.Bottom);
      } catch (_) {
        // The scroller may not be bound on the first transcript frame.
      }
    }, 30);
  }

  private getDots(): string {
    let dots = '';
    for (let i = 0; i < this.dotCount; i++) {
      dots += '.';
    }
    return dots;
  }

  private shouldContinueHeldVoice(token: number): boolean {
    return this.isVoiceButtonPressed && this.voicePressToken === token;
  }

  private restoreReadyAfterAbortedHold(): void {
    this.clearTimers();
    this.updatePhase('ready');
    this.realtimeText = '';
    this.errorMessage = '';
    this.analyzeResult = null;
    this.requireMembership = false;
    this.requireLogin = false;
  }

  private async ensureMicrophonePermissionBeforeRecording(): Promise<boolean> {
    if (!this.hostContext) {
      this.setError('当前无法启动语音输入，请稍后再试。');
      return false;
    }

    if (await hasMicrophonePermission()) {
      return true;
    }

    this.isVoiceButtonPressed = false;
    const granted = await requestMicrophonePermission(this.hostContext);
    if (granted) {
      this.trackVoiceEvent('voice_microphone_permission_granted');
      this.restoreReadyAfterAbortedHold();
      return false;
    }

    const deniedProps: TelemetryProperties = { "reason": 'microphone_permission_denied' };
    this.trackVoiceEvent('voice_input_cancelled', deniedProps);
    this.setError('请先允许麦克风权限后再使用语音输入');
    return false;
  }

  private onVoiceButtonPressStart(): void {
    if (this.phase !== 'ready' && this.phase !== 'error') {
      return;
    }

    this.isVoiceButtonPressed = true;
    const token = ++this.voicePressToken;
    if (this.holdStartTimer !== -1) {
      clearTimeout(this.holdStartTimer);
    }
    this.holdStartTimer = setTimeout(() => {
      if (this.shouldContinueHeldVoice(token)) {
        void this.beginVoiceFlow(token);
      }
    }, 260);
  }

  private onVoiceButtonPressEnd(): void {
    this.isVoiceButtonPressed = false;
    if (this.holdStartTimer !== -1) {
      clearTimeout(this.holdStartTimer);
      this.holdStartTimer = -1;
    }

    if (this.phase === 'recording') {
      void this.stopRecognitionAndSubmit();
      return;
    }

    if (this.phase === 'checking') {
      const cancelProps: TelemetryProperties = { "reason": 'hold_aborted' };
      this.trackVoiceEvent('voice_input_cancelled', cancelProps);
      this.restoreReadyAfterAbortedHold();
    }
  }

  private onVoiceButtonTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.onVoiceButtonPressStart();
      return;
    }

    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.onVoiceButtonPressEnd();
    }
  }

  private async beginVoiceFlow(token: number): Promise<void> {
    if (this.phase === 'checking' || this.phase === 'recording' || this.phase === 'analyzing') {
      return;
    }
    if (!this.hostContext) {
      this.setError('当前无法启动语音输入，请稍后再试。');
      return;
    }

    this.updatePhase('checking');
    this.errorMessage = '';
    this.analyzeResult = null;
    this.requireMembership = false;
    this.requireLogin = false;
    this.startDotAnimation();

    const currentUser = await authService.getCurrentUser();
    if (!currentUser) {
      this.setError('登录后才能继续使用语音创建。', false, true);
      return;
    }

    const accessResult = await QuotaService.checkVoiceCreateAccess();
    if (!accessResult.allowed) {
      this.setError(
        accessResult.message || '当前暂时无法使用语音创建，请稍后再试。',
        accessResult.requireMembership,
        false
      );
      return;
    }

    if (!this.shouldContinueHeldVoice(token)) {
      this.restoreReadyAfterAbortedHold();
      return;
    }

    await this.startRecognitionSession();

    if (!this.shouldContinueHeldVoice(token)) {
      void this.stopRecognitionAndSubmit();
    }
  }

  private async startRecognitionSession(): Promise<void> {
    if (!this.hostContext) {
      this.setError('当前无法启动语音输入，请稍后再试。');
      return;
    }

    if (!(await this.ensureMicrophonePermissionBeforeRecording())) {
      return;
    }

    this.clearTimers();
    this.updatePhase('recording');
    this.realtimeText = '';
    this.errorMessage = '';
    this.analyzeResult = null;
    this.requireMembership = false;
    this.requireLogin = false;

    const status = await this.voiceRecognition.startRecognition(
      this.hostContext,
      (text: string) => {
        this.realtimeText = text;
        this.scrollTranscriptToBottom();
      },
      (text: string) => {
        if (text.trim()) {
          this.realtimeText = text;
          this.scrollTranscriptToBottom();
        }
      }
    );

    if (!this.voiceRecognition.isRecordingInProgress()) {
      this.setError(status || this.voiceRecognition.getStatusDescription());
      return;
    }

    this.trackVoiceEvent('voice_input_started');
  }

  private async stopRecognitionAndSubmit(): Promise<void> {
    if (this.phase !== 'recording') {
      return;
    }

    const text = (await this.voiceRecognition.stopRecognition()).trim();
    this.realtimeText = text;
    this.scrollTranscriptToBottom();
    this.voiceRecognition.reset();

    if (!text) {
      const cancelProps: TelemetryProperties = { "reason": 'empty_transcript' };
      this.trackVoiceEvent('voice_input_cancelled', cancelProps);
      this.setError('没有识别到有效内容，可以再说一次。');
      return;
    }

    const completedProps: TelemetryProperties = {
      "charCount": text.length
    };
    this.trackVoiceEvent('voice_input_completed', completedProps);

    await this.submitCurrentText();
  }

  private async submitCurrentText(): Promise<void> {
    const text = this.realtimeText.trim();
    if (!text) {
      this.setError('没有听清，请再说一次');
      return;
    }

    const currentUser = await authService.getCurrentUser();
    if (!currentUser) {
      this.setError('登录后才能继续使用语音创建。', false, true);
      return;
    }

    this.updatePhase('analyzing');
    this.errorMessage = '';
    this.requireMembership = false;
    this.requireLogin = false;
    this.startDotAnimation();

    const spendResult: SpendResult = await QuotaService.spendCredit('voice_task');
    if (!spendResult.success) {
      this.setError(
        spendResult.message || '当前暂时无法使用语音创建，请稍后再试。',
        !!spendResult.requireMembership
      );
      return;
    }

    const result = await VoiceCreateService.analyze(text);
    this.clearTimers();

    if (result.success && result.intent && result.parsed) {
      const classifiedProps: TelemetryProperties = {
        "intent": result.intent,
        "charCount": text.length,
        "confidence": Math.round((result.confidence || 0) * 100) / 100
      };
      this.trackVoiceEvent('voice_create_classified', classifiedProps);
      this.analyzeResult = result;
      this.updatePhase('done');
      this.continueTimer = setTimeout(() => {
        this.emitResult();
      }, 900);
      return;
    }

    this.setError(result.message || '这句话我还没完全听懂，可以换个说法再试一次。');
  }

  private emitResult(): void {
    if (!this.analyzeResult?.parsed) {
      return;
    }
    this.clearTimers();
    this.onBusyStateChange(false);
    const routedProps: TelemetryProperties = {
      "intent": this.analyzeResult.intent || 'unknown',
      "hasTranscript": this.realtimeText.trim().length > 0
    };
    this.trackVoiceEvent('voice_create_routed', routedProps);
    this.onResult({
      intent: this.analyzeResult.intent || 'unknown',
      parsed: this.analyzeResult.parsed as VoiceCreateParsed
    });
  }

  private openLoginPage(): void {
    this.trackVoiceEvent('voice_login_redirect_clicked');
    try {
      this.onClose();
      this.getUIContext().getRouter().pushUrl({ url: 'pages/LoginPage' });
    } catch (_) {
      this.onClose();
    }
  }

  private openMembershipPage(): void {
    this.trackVoiceEvent('voice_membership_redirect_clicked');
    try {
      this.onClose();
      this.getUIContext().getRouter().pushUrl({ url: 'pages/MembershipPage' });
    } catch (_) {
      this.onClose();
    }
  }

  private getIntentLabel(intent: string): string {
    switch (intent) {
      case 'task': return '待办';
      case 'reminder': return '提醒';
      case 'goal': return '目标';
      case 'focus': return '专注';
      default: return '未分类';
    }
  }

  private getIntentColor(intent: string): string {
    switch (intent) {
      case 'task': return this.themeColors.info;
      case 'reminder': return this.themeColors.warning;
      case 'goal': return this.themeColors.premium;
      case 'focus': return this.themeColors.danger;
      default: return this.themeColors.textSecondary;
    }
  }

  private getResultSummary(): string {
    const intent = this.analyzeResult?.intent || '';
    const parsed = this.analyzeResult?.parsed;
    if (!parsed) {
      return '';
    }

    if (intent === 'task') {
      return parsed.title || parsed.rawText || this.realtimeText;
    }
    if (intent === 'reminder') {
      return parsed.title || parsed.rawText || this.realtimeText;
    }
    if (intent === 'goal') {
      return parsed.intentText || this.realtimeText;
    }
    if (intent === 'focus') {
      const duration = parsed.duration ? `${parsed.duration} 分钟` : '';
      const subject = parsed.focusSubject || this.realtimeText;
      return duration ? `${subject} · ${duration}` : subject;
    }
    return (
      parsed.rawText ||
      parsed.title ||
      parsed.intentText ||
      parsed.focusSubject ||
      parsed.description ||
      this.realtimeText
    ).trim();
  }

  private getPhaseDescriptor(): PhaseDescriptor {
    switch (this.phase) {
      case 'checking':
        return {
          badge: '准备中',
          title: `正在准备${this.getDots()}`,
          description: ''
        } as PhaseDescriptor;
      case 'recording':
        return {
          badge: '正在录音',
          title: '松开后结束',
          description: ''
        } as PhaseDescriptor;
      case 'analyzing':
        return {
          badge: '识别中',
          title: `正在创建${this.getDots()}`,
          description: ''
        } as PhaseDescriptor;
      case 'done':
        return {
          badge: '识别完成',
          title: '即将进入创建页',
          description: ''
        } as PhaseDescriptor;
      case 'error':
        return {
          badge: this.realtimeText.trim().length > 0 ? '创建失败' : '未听清',
          title: '',
          description: this.requireLogin
            ? '登录后可继续使用'
            : (this.requireMembership ? '开通权益后可继续使用' : '按住下方按钮重试')
        } as PhaseDescriptor;
      case 'ready':
      default:
        return {
          badge: '语音创建',
          title: '',
          description: ''
        } as PhaseDescriptor;
    }
  }

  private shouldShowStatusCard(): boolean {
    return this.phase !== 'ready' || this.realtimeText.trim().length > 0;
  }

  private shouldUseCompactStageCard(): boolean {
    const hasTranscript: boolean = this.realtimeText.trim().length > 0;
    const hasResult: boolean = this.phase === 'done' && !!this.analyzeResult;
    const hasFooter: boolean = this.requireLogin || this.requireMembership || hasResult;
    return !hasTranscript && !hasFooter;
  }

  private shouldUseFixedStageCard(): boolean {
    return this.phase === 'checking' || this.phase === 'recording' || this.phase === 'analyzing';
  }

  private getVoiceEntryHint(): string {
    switch (this.phase) {
      case 'checking':
        return '准备中';
      case 'recording':
        return '松开';
      case 'analyzing':
        return '识别中';
      case 'done':
        return '进入';
      case 'error':
        return '重试';
      default:
        return '按住';
    }
  }

  private getVoiceEntryDescription(): string {
    switch (this.phase) {
      case 'checking':
        return '继续按住';
      case 'recording':
        return '松开后自动识别';
      case 'analyzing':
        return '正在生成创建结果';
      case 'done':
        return '识别完成';
      case 'error':
        return '按住重试';
      default:
        return '按住说话，松开完成';
    }
  }

  @Builder
  private TranscriptCard() {
    Column() {
      AppCard({ variant: 'soft', paddingLevel: 'sm', spacing: 0 }) {
        Scroll(this.transcriptScroller) {
          Text(this.realtimeText)
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Medium)
            .lineHeight(22)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')
        }
        .align(Alignment.Top)
        .width('100%')
        .height(this.transcriptViewportHeight)
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
      }
    }
    .width('100%')
  }

  @Builder
  private ResultCard() {
    if (this.phase === 'done' && this.analyzeResult) {
      Column() {
        AppCard({ variant: 'soft', paddingLevel: 'md', spacing: 10 }) {
          Row({ space: 8 }) {
            Text('将创建为')
              .fontSize(TYPE_CAPTION)
              .fontColor(this.themeColors.textSecondary)
            Text(this.getIntentLabel(this.analyzeResult.intent || ''))
              .fontSize(TYPE_BODY)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getIntentColor(this.analyzeResult.intent || ''))
          }
          .width('100%')

          Text(this.getResultSummary())
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .width('100%')
    }
  }

  @Builder
  private FooterActions() {
    Column({ space: 10 }) {
      if (this.requireLogin) {
        Row() {
          AppButton({
            text: '去登录后继续',
            variant: 'secondary',
            buttonSize: 'sm',
            fullWidth: true,
            iconName: 'profile',
            tapAction: () => {
              this.openLoginPage();
            }
          })
            .layoutWeight(1)
        }
        .width('100%')
      }

      if (this.requireMembership) {
        Row() {
          AppButton({
            text: '去会员中心查看权益',
            variant: 'premium',
            buttonSize: 'sm',
            fullWidth: true,
            iconName: 'wallet',
            tapAction: () => {
              this.openMembershipPage();
            }
          })
            .layoutWeight(1)
        }
        .width('100%')
      }

      if (this.phase === 'done' && this.analyzeResult) {
        Row() {
          AppButton({
            text: '立即进入',
            buttonSize: 'sm',
            fullWidth: true,
            iconName: 'success',
            tapAction: () => {
              this.emitResult();
            }
          })
            .layoutWeight(1)
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  private StageCardContent() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        AppStatusBadge({
          text: this.getPhaseDescriptor().badge,
          tone: this.phase === 'error' ? 'danger' : 'primary',
          iconName: this.phase === 'error' ? 'warning' : (this.phase === 'done' ? 'success' : 'ai')
        })

        Blank()

        if (!this.isBlockingClose(this.phase)) {
          Stack({ alignContent: Alignment.Center }) {
            AppIcon({
              name: 'close',
              iconSize: ICON_SIZE_XS,
              framed: false,
              color: this.themeColors.textSecondary
            })
          }
          .width(28)
          .height(28)
          .backgroundColor(this.themeColors.surfaceSoft)
          .borderRadius(14)
          .onClick(() => {
            this.resetViewState();
          })
        }
      }
      .width('100%')

      if ((this.phase === 'error' ? this.errorMessage : this.getPhaseDescriptor().title).length > 0) {
        Text(this.phase === 'error' ? this.errorMessage : this.getPhaseDescriptor().title)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.phase === 'error' ? this.themeColors.danger : this.themeColors.textPrimary)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (this.getPhaseDescriptor().description.length > 0) {
        Text(this.getPhaseDescriptor().description)
          .fontSize(TYPE_META)
          .lineHeight(18)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (this.realtimeText.trim().length > 0 || this.shouldUseFixedStageCard()) {
        this.TranscriptCard()
      }

      this.ResultCard()
      if (this.requireLogin || this.requireMembership || (this.phase === 'done' && this.analyzeResult)) {
        this.FooterActions()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private StageCard() {
    if (this.shouldUseFixedStageCard()) {
      Column() {
        AppCard({ variant: 'raised', paddingLevel: 'sm', spacing: 0 }) {
          this.StageCardContent()
        }
      }
      .width('100%')
      .height(this.fixedStageCardHeight)
      .alignItems(HorizontalAlign.Start)
    } else if (this.shouldUseCompactStageCard()) {
      Column() {
        AppCard({ variant: 'raised', paddingLevel: 'sm', spacing: 0 }) {
          this.StageCardContent()
        }
      }
      .width('100%')
      .height(this.compactStageCardHeight)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Start)
    } else {
      Column() {
        AppCard({ variant: 'raised', paddingLevel: 'sm', spacing: 0 }) {
          this.StageCardContent()
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private VoiceEntryBar() {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(36)
          .height(36)
          .backgroundColor(this.phase === 'recording' || this.phase === 'checking'
            ? this.themeColors.announcementSurface
            : this.themeColors.primarySubtle)
          .borderRadius(18)
        AppIcon({
          name: 'noise',
          iconSize: 24,
          framed: false,
          color: this.phase === 'recording' ? this.themeColors.primary : this.themeColors.textSecondary
        })
      }

      Column({ space: 4 }) {
        Text('语音创建')
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')

        Text(this.getVoiceEntryDescription())
          .fontSize(TYPE_CAPTION)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.getVoiceEntryHint())
        .fontSize(TYPE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(
          this.phase === 'error'
            ? this.themeColors.danger
            : (this.phase === 'ready' ? this.themeColors.textSecondary : this.themeColors.primary)
        )
    }
    .width('100%')
    .height(this.voiceBarHeight)
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor(this.phase === 'recording' ? this.themeColors.announcementSurface : this.themeColors.surface)
    .borderRadius(20)
    .border({
      width: 1,
      color: this.phase === 'recording' || this.phase === 'checking'
        ? this.themeColors.primaryLight
        : this.themeColors.borderColor
    })
    .scale({
      x: this.phase === 'recording' ? 0.99 : 1,
      y: this.phase === 'recording' ? 0.99 : 1
    })
    .onTouch((event: TouchEvent) => {
      this.onVoiceButtonTouch(event);
    })
  }

  build() {
    Column({ space: 8 }) {
      if (this.shouldShowStatusCard()) {
        this.StageCard()
      }

      this.VoiceEntryBar()
    }
    .width('100%')
  }
}
