import { Pomodoro } from '../models/Pomodoro';
import { db } from '../storage/Database';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { themeService } from '../services/ThemeService';
import { dataSyncService } from '../services/DataSyncService';
import { WhiteNoiseService, whiteNoiseService, NoiseOption } from '../services/WhiteNoiseService';
import { QuotaService } from '../services/QuotaService';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppIcon } from '../ui/base/AppIcon';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { PAGE_PADDING, SPACE_CARD } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_HERO_TITLE, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { MOTION_CURVE_STANDARD, MOTION_DURATION_BASE } from '../foundation/tokens/MotionTokens';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('PomodoroPage');

@Entry
@Component
struct PomodoroPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State taskId: string = '';
  @State taskTitle: string = '';
  @State totalDuration: number = 25;
  @State remainingTime: number = 25 * 60;
  @State isPaused: boolean = false;
  @State showControls: boolean = false;
  @State isCompleted: boolean = false;

  // --- 轮次循环 ---
  @State continuousMode: boolean = false;
  @State currentRound: number = 1;
  @State totalRounds: number = 4;
  @State breakDuration: number = 5;
  @State longBreakDuration: number = 15;
  @State isBreakPhase: boolean = false;
  @State allRoundsCompleted: boolean = false;
  @State completedRoundsCount: number = 0;
  @State totalFocusMinutes: number = 0;

  // --- 白噪音 ---
  @State selectedNoiseKey: string = '';
  @State isNoiseActive: boolean = false;
  @State isPremium: boolean = false;
  @State showNoisePanel: boolean = false;

  private timer: number = -1;
  private pomodoro: Pomodoro | null = null;
  private suspendDelayId: number = -1;
  private cachedRounds: number = -1;
  private roundsArray: undefined[] = [];

  private getRoundsArray(): undefined[] {
    if (this.cachedRounds !== this.totalRounds) {
      this.cachedRounds = this.totalRounds;
      this.roundsArray = Array.from({ length: this.totalRounds });
    }
    return this.roundsArray;
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message });
    } catch (error) {
      logger.error('Failed to show toast', error as Object);
    }
  }

  private showPremiumNoiseDialog(option?: NoiseOption): void {
    this.getUIContext().showAlertDialog({
      title: '升级高级会员',
      message: option ? `"${option.label}"是高级会员专属氛围音。升级后可解锁全部白噪音。` :
        '白噪音背景音是高级会员专属功能。升级后可在番茄开始后自由选择并随时切换白噪音。',
      buttons: [
        {
          value: '暂不升级',
          action: () => {}
        },
        {
          value: '查看特权',
          action: () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/MembershipPage' });
          }
        }
      ]
    });
  }

  async aboutToAppear(): Promise<void> {
    let context = this.getUIContext().getHostContext() as Context;
    await themeService.initialize(context);
    await this.checkPremium();

    const params = this.getUIContext().getRouter().getParams() as Record<string, string | number | boolean>;
    if (params) {
      this.totalDuration = typeof params['duration'] === 'number' ? params['duration'] : 25;
      this.taskId = typeof params['taskId'] === 'string' ? params['taskId'] : '';
      this.taskTitle = typeof params['taskTitle'] === 'string' ? params['taskTitle'] : '专注';
      this.continuousMode = params['continuousMode'] === true;
      this.totalRounds = typeof params['totalRounds'] === 'number' ? params['totalRounds'] : 4;
      this.breakDuration = typeof params['breakDuration'] === 'number' ? params['breakDuration'] : 5;
      this.longBreakDuration = typeof params['longBreakDuration'] === 'number' ? params['longBreakDuration'] : 15;

      if (!this.continuousMode) {
        this.totalRounds = 1;
      }
      this.remainingTime = this.totalDuration * 60;

      if (typeof params['noiseKey'] === 'string') {
        this.selectedNoiseKey = params['noiseKey'];
      }

      if (this.taskId) {
        this.pomodoro = new Pomodoro(this.taskId, this.taskTitle, this.totalDuration);
        this.pomodoro.roundIndex = 1;
        this.pomodoro.totalRounds = this.totalRounds;
        this.pomodoro.breakDuration = this.breakDuration;
        db.addPomodoro(this.pomodoro);
      }
    }

    if (!this.selectedNoiseKey) {
      this.selectedNoiseKey = await whiteNoiseService.getLastSelectedKey(context);
    }

    const noiseOption = WhiteNoiseService.getOptionByKey(this.selectedNoiseKey);
    if (!noiseOption) {
      this.selectedNoiseKey = '';
    } else if (this.isPremium) {
      await this.applyNoiseSelection(noiseOption);
    }

    this.startTimer();
  }

  onForeground(): void {
    // 休眠唤醒后基于时钟重算剩余时间
    if (this.pomodoro && !this.isPaused && !this.isCompleted && !this.isBreakPhase) {
      const elapsed = Math.floor((Date.now() - this.pomodoro.startTime) / 1000);
      const recalculated = this.totalDuration * 60 - elapsed;
      if (recalculated <= 0) {
        this.remainingTime = 0;
        this.onPhaseComplete();
      } else if (recalculated < this.remainingTime) {
        this.remainingTime = recalculated;
      }
    }
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    if (this.suspendDelayId !== -1) {
      try {
        backgroundTaskManager.cancelSuspendDelay(this.suspendDelayId);
        this.suspendDelayId = -1;
      } catch (e) {}
    }
    // 停止白噪音
    whiteNoiseService.stop();
  }

  async checkPremium(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as Context;
      const result = await QuotaService.checkPremiumFeature(context);
      this.isPremium = result.allowed;
    } catch (e) {
      this.isPremium = false;
    }
  }

  onPageShow(): void {
    void this.checkPremium();
  }

  onBackPress(): boolean {
    if (!this.isCompleted && !this.allRoundsCompleted) {
      this.showControls = true;
      this.showToast('请先完成或结束番茄');
      return true;
    }
    return false;
  }

  startTimer(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
    }

    // 申请后台短时任务延迟挂起保证不会立马被杀
    if (this.suspendDelayId === -1) {
      try {
        let delayInfo = backgroundTaskManager.requestSuspendDelay("PomodoroTimer", () => {
          logger.warn('Suspend delay expired');
        });
        this.suspendDelayId = delayInfo.requestId;
      } catch (error) {
        logger.error('suspend delay failed: ${error}');
      }
    }

    this.timer = setInterval(() => {
      if (!this.isPaused && this.remainingTime > 0) {
        this.remainingTime--;
        if (this.remainingTime === 0) {
          this.onPhaseComplete();
        }
      }
    }, 1000);
  }

  onPhaseComplete(): void {
    if (this.isBreakPhase) {
      // 休息结束 → 开始下一轮工作
      this.isBreakPhase = false;
      this.currentRound++;
      this.remainingTime = this.totalDuration * 60;

      // 创建新轮次的 Pomodoro 记录
      if (this.taskId) {
        this.pomodoro = new Pomodoro(this.taskId, this.taskTitle, this.totalDuration);
        this.pomodoro.roundIndex = this.currentRound;
        this.pomodoro.totalRounds = this.totalRounds;
        this.pomodoro.breakDuration = this.breakDuration;
        db.addPomodoro(this.pomodoro);
      }

      this.showToast(`第 ${this.currentRound} 轮开始`);
    } else {
      // 工作阶段结束
      this.completedRoundsCount++;
      this.totalFocusMinutes += this.totalDuration;

      // 完成当前番茄记录
      if (this.pomodoro) {
        this.pomodoro.complete();
        db.updatePomodoro(this.pomodoro);

        if (this.taskId) {
          const task = db.getTaskById(this.taskId);
          if (task) {
            task.pomodoroCount = (task.pomodoroCount || 0) + 1;
            dataSyncService.updateTask(task);
            db.updateTask(task);
          }
        }
      }

      if (this.currentRound >= this.totalRounds) {
        // 所有轮次都完成了
        this.allRoundsCompleted = true;
        this.isCompleted = true;
        this.showControls = true;
        if (this.timer !== -1) {
          clearInterval(this.timer);
          this.timer = -1;
        }

        if (this.continuousMode) {
          this.showToast(`${this.totalRounds} 轮番茄全部完成`);
        } else {
          this.showToast('番茄完成');
        }
      } else if (this.continuousMode) {
        // 还有后续轮次 → 进入休息阶段
        this.isBreakPhase = true;
        // 每 4 轮用长休息，否则短休息
        const isLongBreak = this.currentRound % 4 === 0;
        this.remainingTime = (isLongBreak ? this.longBreakDuration : this.breakDuration) * 60;

        this.showToast(isLongBreak ? '长休息时间' : '短休息一下');
      } else {
        // 单次模式完成
        this.isCompleted = true;
        this.showControls = true;
        if (this.timer !== -1) {
          clearInterval(this.timer);
          this.timer = -1;
        }
        this.showToast('番茄完成');
      }
    }
  }

  endEarly(): void {
    // 提前结束当前阶段
    if (this.isBreakPhase) {
      // 跳过休息
      this.isBreakPhase = false;
      this.currentRound++;
      this.remainingTime = this.totalDuration * 60;

      if (this.taskId) {
        this.pomodoro = new Pomodoro(this.taskId, this.taskTitle, this.totalDuration);
        this.pomodoro.roundIndex = this.currentRound;
        this.pomodoro.totalRounds = this.totalRounds;
        this.pomodoro.breakDuration = this.breakDuration;
        db.addPomodoro(this.pomodoro);
      }
    } else {
      // 结束全部
      if (this.pomodoro) {
        this.pomodoro.complete();
        db.updatePomodoro(this.pomodoro);

        if (this.taskId) {
          const task = db.getTaskById(this.taskId);
          if (task) {
            task.pomodoroCount = (task.pomodoroCount || 0) + 1;
            dataSyncService.updateTask(task);
            db.updateTask(task);
          }
        }
      }
      this.completedRoundsCount++;
      this.totalFocusMinutes += Math.round((this.totalDuration * 60 - this.remainingTime) / 60);
      this.allRoundsCompleted = true;
      this.isCompleted = true;
      this.showControls = true;
      if (this.timer !== -1) {
        clearInterval(this.timer);
        this.timer = -1;
      }
    }
  }

  formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  adjustDuration(minutes: number): void {
    const delta = minutes * 60;
    const newTime = this.remainingTime + delta;
    if (newTime >= 60 && newTime <= 7200) {
      this.remainingTime = newTime;
    }
  }

  getSelectedNoiseOption(): NoiseOption | undefined {
    return WhiteNoiseService.getOptionByKey(this.selectedNoiseKey);
  }

  getNatureNoiseOptions(): NoiseOption[] {
    return WhiteNoiseService.getOptionsByCategory('nature');
  }

  getArtificialNoiseOptions(): NoiseOption[] {
    return WhiteNoiseService.getOptionsByCategory('artificial');
  }

  getSelectedNoiseLabel(): string {
    const option = this.getSelectedNoiseOption();
    return option ? option.label : '选择白噪音';
  }

  getSelectedNoiseIcon(): string {
    const option = this.getSelectedNoiseOption();
    return option ? option.icon : 'noise';
  }

  getNoiseHintText(): string {
    if (!this.isPremium) {
      return '高级会员专属';
    }
    if (!this.selectedNoiseKey) {
      return '点击选择白噪音';
    }
    return this.isNoiseActive ? '播放中，点击切换' : '已选择，点击切换';
  }

  openNoisePanel(): void {
    if (!this.isPremium) {
      this.showPremiumNoiseDialog();
      return;
    }
    this.showNoisePanel = true;
  }

  async applyNoiseSelection(option: NoiseOption): Promise<void> {
    const context = this.getUIContext().getHostContext() as Context;
    const previousKey = this.selectedNoiseKey;
    const previousActive = this.isNoiseActive;
    this.selectedNoiseKey = option.key;
    this.isNoiseActive = false;
    try {
      await whiteNoiseService.play(context, option.key);
      this.isNoiseActive = whiteNoiseService.isPlaying();
    } catch (error) {
      logger.error('PomodoroPage applyNoiseSelection error', error as Object);
      this.selectedNoiseKey = previousKey;
      this.isNoiseActive = previousActive;
      this.showToast('白噪音切换失败');
    }
  }

  async toggleNoise(option: NoiseOption): Promise<void> {
    if (option.isPremium && !this.isPremium) {
      this.showPremiumNoiseDialog(option);
      return;
    }

    if (this.selectedNoiseKey === option.key && this.isNoiseActive) {
      whiteNoiseService.stop();
      this.isNoiseActive = false;
      this.selectedNoiseKey = option.key;
    } else {
      await this.applyNoiseSelection(option);
    }
  }

  async handleNoiseOptionClick(option: NoiseOption): Promise<void> {
    await this.toggleNoise(option);
    this.showNoisePanel = false;
  }

  getPhaseColor(): string {
    if (this.isCompleted) return this.themeColors.success;
    if (this.isBreakPhase) return this.themeColors.success;
    return this.themeColors.textPrimary;
  }

  getPhaseBackgroundColor(): string {
    if (this.isBreakPhase) return this.themeColors.successSubtle;
    return this.themeColors.background;
  }

  build() {
    Column() {
      // 主要内容区域
      Column() {
        // 阶段标签
        if (this.showControls && this.continuousMode) {
          Row() {
            AppStatusBadge({
              text: this.isBreakPhase ? '休息中' : `第 ${this.currentRound}/${this.totalRounds} 轮`,
              tone: this.isBreakPhase ? 'success' : 'primary',
              iconName: this.isBreakPhase ? 'success' : 'focus'
            })
          }
          .margin({ bottom: 16 })
        }

        if (this.taskTitle && this.showControls) {
          Text(this.taskTitle)
            .fontSize(TYPE_SECTION_TITLE)
            .fontColor(this.themeColors.textSecondary)
            .margin({ bottom: 20 })
        }

        Text(this.formatTime(this.remainingTime))
          .fontSize(80)
          .fontWeight(FontWeight.Lighter)
          .fontColor(this.getPhaseColor())

        if (this.isPaused && !this.isCompleted) {
          Text('已暂停')
            .fontSize(TYPE_BODY)
            .fontColor(this.themeColors.warning)
            .margin({ top: 12 })
        }

        if (this.isCompleted && this.continuousMode && this.completedRoundsCount > 1) {
          Column() {
            Text('全部完成')
              .fontSize(20)
              .fontColor(this.themeColors.success)
              .margin({ top: 16 })
            Text(`${this.completedRoundsCount} 轮番茄 · 累计专注 ${this.totalFocusMinutes} 分钟`)
              .fontSize(TYPE_BODY)
              .fontColor(this.themeColors.textSecondary)
              .margin({ top: 8 })
          }
        } else if (this.isCompleted) {
          Text('完成')
            .fontSize(20)
            .fontColor(this.themeColors.success)
            .margin({ top: 16 })
        }

        // 轮次进度指示器
        if (this.continuousMode && this.showControls && this.totalRounds > 1) {
          Row() {
            ForEach(this.getRoundsArray(), (item: undefined, index: number) => {
              Text(index < this.completedRoundsCount ? '●' :
                (index === this.completedRoundsCount && !this.isBreakPhase && !this.isCompleted ? '◉' : '○'))
                .fontSize(TYPE_SECTION_TITLE)
                .fontColor(index < this.completedRoundsCount ? this.themeColors.success :
                  (index === this.completedRoundsCount && !this.isBreakPhase && !this.isCompleted ? this.themeColors.primary : this.themeColors.textMuted))
                .margin({ left: 6, right: 6 })
            })
          }
          .margin({ top: 24 })
        }
      }
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)

      // 白噪音入口
      if (this.showControls && !this.isCompleted) {
        Column() {
          AppCard({
            variant: 'soft',
            spacing: 10,
            paddingLevel: 'md',
            interactive: true,
            tapAction: () => {
              this.openNoisePanel();
            }
          }) {
            Row() {
              Text('白噪音')
                .fontSize(TYPE_BODY)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.themeColors.textSecondary)
              Blank()
              if (!this.isPremium) {
                AppStatusBadge({ text: 'VIP 专属', tone: 'premium', iconName: 'wallet' })
              }
            }
            .width('100%')

            Row() {
              Row() {
                Text(this.getSelectedNoiseIcon())
                  .fontSize(20)
                  .fontColor(this.isPremium ? this.themeColors.primary : this.themeColors.textMuted)
                  .width(36)
                  .height(36)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.isPremium ? this.themeColors.primary + '15' : this.themeColors.surfaceLight)
                  .borderRadius(18)

                Column() {
                  Text(this.isPremium ? this.getSelectedNoiseLabel() : '白噪音')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.themeColors.textPrimary)
                  Text(this.getNoiseHintText())
                    .fontSize(TYPE_CAPTION)
                    .fontColor(this.isPremium && this.isNoiseActive ? this.themeColors.success : this.themeColors.textMuted)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 12 })
              }

              Blank()

              AppIcon({
                name: 'chevron-right',
                iconSize: 22,
                framed: false,
                color: this.themeColors.textMuted
              })
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: SPACE_CARD })
      }

      // 操作按钮区域
      if (this.showControls) {
        Column() {
          // 修改时长按钮（仅工作阶段且未完成时可调）
          if (!this.isCompleted && !this.isBreakPhase) {
            Row() {
              AppButton({
                text: '-5 分钟',
                variant: 'secondary',
                buttonSize: 'sm',
                iconName: 'warning',
                tapAction: () => {
                  this.adjustDuration(-5);
                }
              })
                .width('30%')

              Text('调整时长')
                .fontSize(13)
                .fontColor(this.themeColors.textMuted)

              AppButton({
                text: '+5 分钟',
                variant: 'secondary',
                buttonSize: 'sm',
                iconName: 'tomato',
                tapAction: () => {
                  this.adjustDuration(5);
                }
              })
                .width('30%')
            }
            .justifyContent(FlexAlign.SpaceBetween)
            .width('100%')
            .margin({ bottom: 16 })
          }

          // 暂停和结束按钮
          Row() {
            if (!this.isCompleted) {
              AppButton({
                text: this.isPaused ? '继续' : '暂停',
                variant: 'secondary',
                buttonSize: 'md',
                iconName: this.isPaused ? 'focus' : 'warning',
                tapAction: () => {
                  this.isPaused = !this.isPaused;
                }
              })
                .width('45%')
            }

            AppButton({
              text: this.isCompleted ? '完成' : (this.isBreakPhase ? '跳过休息' : '结束'),
              variant: this.isCompleted || this.isBreakPhase ? 'primary' : 'danger',
              buttonSize: 'md',
              iconName: this.isCompleted ? 'success' : (this.isBreakPhase ? 'chevron-right' : 'warning'),
              tapAction: () => {
                if (this.isCompleted) {
                  this.getUIContext().getRouter().back({ url: 'pages/MainPage' });
                } else {
                  this.endEarly();
                }
              }
            })
              .width(this.isCompleted ? '100%' : '45%')
          }
          .width('100%')
          .justifyContent(this.isCompleted ? FlexAlign.Center : FlexAlign.SpaceBetween)
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: 40 })
        .transition(TransitionEffect.OPACITY)
        .animation({ duration: MOTION_DURATION_BASE, curve: MOTION_CURVE_STANDARD })
      }

      if (this.showNoisePanel) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.themeColors.surfaceOverlay)
            .onClick(() => {
              this.showNoisePanel = false;
            })

          Column() {
            Row() {
              Text('选择白噪音')
                .fontSize(TYPE_HERO_TITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.themeColors.textPrimary)
                .layoutWeight(1)
              Row() {
                AppIcon({
                  name: 'close',
                  iconSize: 18,
                  framed: false,
                  color: this.themeColors.textSecondary
                })
              }
                .width(32)
                .height(32)
                .justifyContent(FlexAlign.Center)
                .onClick(() => {
                  this.showNoisePanel = false;
                })
            }
            .width('100%')
            .margin({ bottom: 8 })

            Text('再次点击当前音效可关闭背景音')
              .fontSize(TYPE_CAPTION)
              .fontColor(this.themeColors.textMuted)
              .width('100%')
              .margin({ bottom: 16 })

            Scroll() {
              Column() {
                Text('自然声音')
                  .fontSize(TYPE_CAPTION)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.themeColors.textSecondary)
                  .width('100%')
                  .margin({ bottom: 8 })

                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.getNatureNoiseOptions(), (option: NoiseOption) => {
                    Column() {
                      Stack() {
                        AppIcon({ name: option.icon, iconSize: 32, framed: false })
                        if (this.selectedNoiseKey === option.key) {
                          Text(this.isNoiseActive ? '●' : '○')
                            .fontSize(10)
                            .fontColor(this.themeColors.primary)
                            .position({ x: 20, y: -2 })
                        }
                      }
                      .width(44)
                      .height(44)
                      .backgroundColor(this.selectedNoiseKey === option.key ?
                        (this.isNoiseActive ? this.themeColors.primary + '25' : this.themeColors.primary + '12') : this.themeColors.surfaceLight)
                      .borderRadius(22)
                      .border({
                        width: this.selectedNoiseKey === option.key ? 2 : 0,
                        color: this.themeColors.primary
                      })
                      .alignContent(Alignment.Center)

                      Text(option.label)
                        .fontSize(10)
                        .fontColor(this.themeColors.textMuted)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ top: 4 })
                    }
                    .width('24%')
                    .margin({ right: '1%', bottom: 14 })
                    .onClick(() => {
                      this.handleNoiseOptionClick(option);
                    })
                  })
                }
                .width('100%')

                Text('人类 / 人造声音')
                  .fontSize(TYPE_CAPTION)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.themeColors.textSecondary)
                  .width('100%')
                  .margin({ top: 8, bottom: 8 })

                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.getArtificialNoiseOptions(), (option: NoiseOption) => {
                    Column() {
                      Stack() {
                        AppIcon({ name: option.icon, iconSize: 32, framed: false })
                        if (this.selectedNoiseKey === option.key) {
                          Text(this.isNoiseActive ? '●' : '○')
                            .fontSize(10)
                            .fontColor(this.themeColors.primary)
                            .position({ x: 20, y: -2 })
                        }
                      }
                      .width(44)
                      .height(44)
                      .backgroundColor(this.selectedNoiseKey === option.key ?
                        (this.isNoiseActive ? this.themeColors.primary + '25' : this.themeColors.primary + '12') : this.themeColors.surfaceLight)
                      .borderRadius(22)
                      .border({
                        width: this.selectedNoiseKey === option.key ? 2 : 0,
                        color: this.themeColors.primary
                      })
                      .alignContent(Alignment.Center)

                      Text(option.label)
                        .fontSize(10)
                        .fontColor(this.themeColors.textMuted)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ top: 4 })
                    }
                    .width('24%')
                    .margin({ right: '1%', bottom: 14 })
                    .onClick(() => {
                      this.handleNoiseOptionClick(option);
                    })
                  })
                }
                .width('100%')
              }
              .width('100%')
            }
            .scrollable(ScrollDirection.Vertical)
            .scrollBar(BarState.Auto)
          }
          .width('100%')
          .padding(PAGE_PADDING)
          .backgroundColor(this.themeColors.surface)
          .borderRadius({ topLeft: 20, topRight: 20 })
          .height('58%')
          .position({ x: 0, y: '42%' })
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getPhaseBackgroundColor())
    .onClick(() => {
      if (!this.showNoisePanel) {
        this.showControls = !this.showControls;
      }
    })
  }
}
