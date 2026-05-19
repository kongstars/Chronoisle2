import { Task, TaskStatus } from '../models/Task';
import { Goal } from '../models/Goal';
import { db } from '../storage/Database';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { themeService } from '../services/ThemeService';
import { QuotaService } from '../services/QuotaService';
import { WhiteNoiseService, whiteNoiseService, NoiseOption } from '../services/WhiteNoiseService';
import { AIFillState } from '../services/AIFillState';
import { AppAIFillBanner } from '../ui/base/AppAIFillBanner';
import { AppButton } from '../ui/base/AppButton';
import { AppHeroPanel } from '../ui/base/AppHeroPanel';
import { AppIcon } from '../ui/base/AppIcon';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { AppStatusBadge } from '../ui/base/AppStatusBadge';
import { ACTION_CHIP_HEIGHT, BUTTON_HEIGHT_LG, BUTTON_HEIGHT_MD, BUTTON_HEIGHT_SM, ICON_BUTTON_SIZE_SM } from '../foundation/tokens/ComponentSizeTokens';
import { ICON_SIZE_LG, ICON_SIZE_SM, ICON_SIZE_XL, ICON_SIZE_XS } from '../foundation/tokens/IconTokens';
import { HERO_PANEL_HEIGHT_COMPACT } from '../foundation/tokens/PageDensityTokens';
import { PANEL_GAP, SECTION_GAP, SPACE_2XS, SPACE_CARD, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { COMFORTABLE_PAGE_PADDING, COMFORTABLE_SECTION_GAP } from '../foundation/tokens/PageTierTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_HERO_TITLE, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';

@Entry
@Component
struct CreatePomodoroPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State duration: number = 25;
  @State taskId: string = '';
  @State taskTitle: string = '';
  @State showTaskSelector: boolean = false;
  @State autoSelect: boolean = false;
  @State tasks: Task[] = [];
  @State filteredTasks: Task[] = [];
  @State goals: Goal[] = [];
  @State searchText: string = '';
  @State displayCount: number = 5;

  // --- 连续番茄 Premium 设置 ---
  @State continuousMode: boolean = false;
  @State totalRounds: number = 4;
  @State breakDuration: number = 5;
  @State longBreakDuration: number = 15;
  @State isPremium: boolean = false;
  @State showNoiseSelector: boolean = false;
  @State selectedNoiseKey: string = '';
  @State aiFill: AIFillState = new AIFillState();

  private showMembershipDialog(message: string = '连续番茄轮次是高级会员专属功能。升级后可自定义工作-休息循环，提升专注效率！'): void {
    try {
      this.getUIContext().getPromptAction().showDialog({
        title: '升级高级会员',
        message,
        buttons: [{ text: '暂不升级', color: this.themeColors.textMuted }, { text: '查看特权', color: this.themeColors.premium }]
      }).then((data) => {
        if (data.index === 1) {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/MembershipPage' });
        }
      });
    } catch (_) {
    }
  }

  aboutToAppear(): void {
    let context = this.getUIContext().getHostContext() as Context;
    themeService.initialize(context);

    this.goals = db.getActiveGoals();
    this.loadPendingTasks();
    void this.checkPremium();
    void this.loadNoisePreference();

    // 获取参数
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    if (params) {
      const voiceFilledFields: string[] = [];
      if (params['taskId']) {
        this.taskId = params['taskId'];
        const task = db.getTaskById(params['taskId']);
        if (task) {
          this.taskTitle = task.title;
          voiceFilledFields.push('taskId');
        }
      }
      if (params['taskTitle']) {
        this.taskTitle = params['taskTitle'];
        voiceFilledFields.push('taskTitle');
      }
      if (params['autoSelect'] === 'true') {
        this.autoSelect = true;
      }
      if (voiceFilledFields.length > 0) {
        this.aiFill.markFilled(voiceFilledFields);
      }
    }
  }

  onPageShow(): void {
    // 刷新任务和目标列表
    this.goals = db.getActiveGoals();
    this.loadPendingTasks();
    void this.checkPremium();
    void this.loadNoisePreference();

    // 重新检查参数
    const params = this.getUIContext().getRouter().getParams() as Record<string, string>;
    if (params && params['taskId']) {
      const task = db.getTaskById(params['taskId']);
      if (task) {
        this.taskId = params['taskId'];
        this.taskTitle = task.title;
      }
    }
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

  async loadNoisePreference(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as Context;
      const key = await whiteNoiseService.getLastSelectedKey(context);
      this.selectedNoiseKey = WhiteNoiseService.getOptionByKey(key) ? key : '';
    } catch (_) {
      this.selectedNoiseKey = '';
    }
  }

  loadPendingTasks(): void {
    const allTasks = db.getAllTasks();
    const pendingTasks = allTasks.filter((t: Task) => t.status === TaskStatus.PENDING);
    pendingTasks.sort((a: Task, b: Task) => this.calculateTaskScore(b) - this.calculateTaskScore(a));
    this.tasks = pendingTasks;
    this.filteredTasks = pendingTasks.slice(0, this.displayCount);
  }

  calculateTaskScore(task: Task): number {
    let score = 0;
    const goal = this.goals.find(g => g.id === task.goalId);

    if (task.isPinned) {
      score += 20;
    }

    if (goal) {
      if (goal.isPriority) {
        score += 3;
      } else {
        score += 1;
      }

      if (task.dueDate) {
        const now = Date.now();
        const dueDate = task.dueDate;
        const diffDays = Math.ceil((dueDate - now) / (24 * 60 * 60 * 1000));

        if (diffDays < 0) {
          score += 10;
        } else if (diffDays === 0) {
          score += 5;
        } else if (diffDays <= 3) {
          score += 3;
        } else if (diffDays <= 5) {
          score += 2;
        } else if (diffDays <= 7) {
          score += 1;
        }
      }
    }

    return score;
  }

  filterTasks(): void {
    let filtered = this.tasks;

    if (this.searchText.trim()) {
      const keyword = this.searchText.toLowerCase();
      filtered = filtered.filter((t: Task) =>
        t.title.toLowerCase().includes(keyword) ||
        (t.description && t.description.toLowerCase().includes(keyword)) ||
        (t.goalTitle && t.goalTitle.toLowerCase().includes(keyword))
      );
    }

    this.filteredTasks = filtered.slice(0, this.displayCount);
  }

  getFilteredTaskCount(): number {
    if (!this.searchText.trim()) {
      return this.tasks.length;
    }

    const keyword = this.searchText.toLowerCase();
    return this.tasks.filter((t: Task) =>
      t.title.toLowerCase().includes(keyword) ||
      (t.description && t.description.toLowerCase().includes(keyword)) ||
      (t.goalTitle && t.goalTitle.toLowerCase().includes(keyword))
    ).length;
  }

  loadMoreTasks(): void {
    this.displayCount += 5;
    this.filterTasks();
  }

  openTaskSelector(): void {
    this.showTaskSelector = true;
    this.displayCount = 5;
    this.searchText = '';
    this.filterTasks();
  }

  selectTask(task: Task): void {
    this.taskId = task.id;
    this.taskTitle = task.title;
    this.aiFill.markUserEdited('taskId');
    this.aiFill.markUserEdited('taskTitle');
    this.showTaskSelector = false;
    this.searchText = '';
    this.displayCount = 5;
  }

  handleContinuousToggle(): void {
    if (!this.isPremium) {
      this.showMembershipDialog();
      return;
    }
    this.continuousMode = !this.continuousMode;
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
    return option ? option.label : '不使用白噪音';
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
      return '可选，开始后静音进入';
    }
    return '开始后自动播放，可随时切换';
  }

  openNoiseSelector(): void {
    if (!this.isPremium) {
      this.showMembershipDialog('白噪音背景音是高级会员专属功能。升级后可在创建页提前选择，番茄开始后自动播放。');
      return;
    }
    this.showNoiseSelector = true;
  }

  async selectNoise(option: NoiseOption): Promise<void> {
    if (option.isPremium && !this.isPremium) {
      this.showMembershipDialog(`"${option.label}"是高级会员专属氛围音。升级后可在创建页提前选择并在专注时自动播放。`);
      return;
    }

    this.selectedNoiseKey = option.key;
    this.showNoiseSelector = false;

    try {
      const context = this.getUIContext().getHostContext() as Context;
      await whiteNoiseService.rememberLastSelectedKey(context, option.key);
    } catch (_) {
    }
  }

  async clearNoiseSelection(): Promise<void> {
    this.selectedNoiseKey = '';
    this.showNoiseSelector = false;

    try {
      const context = this.getUIContext().getHostContext() as Context;
      await whiteNoiseService.rememberLastSelectedKey(context, '');
    } catch (_) {
    }
  }

  @Builder
  private StepperIconAction(iconName: string, size: number, radius: number, action: () => void) {
    Row() {
      AppIcon({ name: iconName, iconSize: ICON_SIZE_XS, framed: false, color: this.themeColors.primary })
    }
    .width(size)
    .height(size)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.themeColors.primary + '15')
    .borderRadius(radius)
    .onClick(action)
  }

  @Builder
  private SheetCloseAction(action: () => void) {
    Row() {
      AppIcon({ name: 'close', iconSize: ICON_SIZE_SM, framed: false, color: this.themeColors.textSecondary })
    }
    .width(ICON_BUTTON_SIZE_SM)
    .height(ICON_BUTTON_SIZE_SM)
    .justifyContent(FlexAlign.Center)
    .onClick(action)
  }

  build() {
    Stack() {
      Column({ space: SPACE_SM }) {
        AppPageHeader({
          title: '创建番茄',
          subtitle: '设置时长、关联任务和连续专注参数',
          onBack: () => {
            this.getUIContext().getRouter().back();
          }
        })

        Scroll() {
          Column({ space: SPACE_MD }) {
            AppHeroPanel({
              eyebrow: '专注准备',
              title: '先确定这次番茄专注',
              description: this.continuousMode
                ? `当前已开启连续番茄，将按 ${this.totalRounds} 轮节奏自动进入休息。`
                : '先设置单次专注时长，再决定是否启用连续番茄和白噪音。',
              tone: 'info',
              minHeight: HERO_PANEL_HEIGHT_COMPACT
            }) {
              Column({ space: SPACE_MD }) {
                Text('番茄时长')
                  .fontSize(TYPE_BODY)
                  .fontColor(this.themeColors.textSecondary)

                Row() {
                  this.StepperIconAction('minus', BUTTON_HEIGHT_MD, 20, () => {
                    if (this.duration > 5) {
                      this.duration -= 5;
                    }
                  })

                  Text(`${this.duration} 分钟`)
                    .fontSize(28)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.themeColors.textPrimary)
                    .margin({ left: SPACE_CARD, right: SPACE_CARD })

                  this.StepperIconAction('plus', BUTTON_HEIGHT_MD, 20, () => {
                    if (this.duration < 120) {
                      this.duration += 5;
                    }
                  })
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            // === 连续番茄设置（Premium） ===
            Column() {
              Row() {
                Column() {
                  Row() {
                    Text('连续番茄')
                      .fontSize(TYPE_SECTION_TITLE)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.themeColors.textPrimary)
                    if (!this.isPremium) {
                      AppStatusBadge({ text: 'VIP', tone: 'premium', iconName: 'wallet' })
                        .margin({ left: SPACE_SM })
                    }
                  }
                  Text('经典番茄工作法：工作→短休息→工作→长休息')
                    .fontSize(TYPE_META)
                    .fontColor(this.themeColors.textSecondary)
                    .margin({ top: SPACE_2XS })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Toggle({ type: ToggleType.Switch, isOn: this.continuousMode })
                  .selectedColor(this.isPremium ? this.themeColors.primary : this.themeColors.borderColor)
                  .onChange(() => {
                    this.handleContinuousToggle();
                  })
              }
              .width('100%')

              // 轮次详细设置（仅在开启且是Premium时显示）
              if (this.continuousMode && this.isPremium) {
                Column() {
                  // 轮次数
                  Row() {
                    Text('轮次数')
                      .fontSize(TYPE_BODY)
                      .fontColor(this.themeColors.textSecondary)
                      .layoutWeight(1)
                    Row() {
                      this.StepperIconAction('minus', ACTION_CHIP_HEIGHT, 16, () => { if (this.totalRounds > 2) this.totalRounds--; })
                      Text(`${this.totalRounds} 轮`)
                        .fontSize(TYPE_SECTION_TITLE)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.themeColors.textPrimary)
                        .margin({ left: SPACE_CARD, right: SPACE_CARD })
                      this.StepperIconAction('plus', ACTION_CHIP_HEIGHT, 16, () => { if (this.totalRounds < 8) this.totalRounds++; })
                    }
                  }
                  .width('100%')
                  .margin({ top: SPACE_CARD })

                  // 短休息时长
                  Row() {
                    Text('短休息')
                      .fontSize(TYPE_BODY)
                      .fontColor(this.themeColors.textSecondary)
                      .layoutWeight(1)
                    Row() {
                      this.StepperIconAction('minus', ACTION_CHIP_HEIGHT, 16, () => { if (this.breakDuration > 1) this.breakDuration--; })
                      Text(`${this.breakDuration} 分钟`)
                        .fontSize(TYPE_SECTION_TITLE)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.themeColors.textPrimary)
                        .margin({ left: SPACE_CARD, right: SPACE_CARD })
                      this.StepperIconAction('plus', ACTION_CHIP_HEIGHT, 16, () => { if (this.breakDuration < 15) this.breakDuration++; })
                    }
                  }
                  .width('100%')
                  .margin({ top: SPACE_MD })

                  // 长休息时长
                  Row() {
                    Text('长休息')
                      .fontSize(TYPE_BODY)
                      .fontColor(this.themeColors.textSecondary)
                      .layoutWeight(1)
                    Row() {
                      this.StepperIconAction('minus', ACTION_CHIP_HEIGHT, 16, () => { if (this.longBreakDuration > 5) this.longBreakDuration -= 5; })
                      Text(`${this.longBreakDuration} 分钟`)
                        .fontSize(TYPE_SECTION_TITLE)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.themeColors.textPrimary)
                        .margin({ left: SPACE_CARD, right: SPACE_CARD })
                      this.StepperIconAction('plus', ACTION_CHIP_HEIGHT, 16, () => { if (this.longBreakDuration < 30) this.longBreakDuration += 5; })
                    }
                  }
                  .width('100%')
                  .margin({ top: SPACE_MD })

                  // 预览总时间
                  Text(`总计 ${this.totalRounds * this.duration + (this.totalRounds - 1) * this.breakDuration} 分钟（含休息）`)
                    .fontSize(TYPE_META)
                    .fontColor(this.themeColors.textMuted)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .margin({ top: SPACE_CARD })
                }
                .width('100%')
                .padding({ top: 4 })
              }
            }
            .width('100%')
            .padding(PANEL_GAP)
            .backgroundColor(this.themeColors.cardBackground)
            .borderRadius(16)
            .margin({ bottom: SPACE_MD })

            // 白噪音设置
            Column() {
              Row() {
                Text('白噪音（可选）')
                  .fontSize(TYPE_BODY)
                  .fontColor(this.themeColors.textSecondary)

                Blank()

                if (!this.isPremium) {
                  Text('VIP 专属')
                    .fontSize(TYPE_CAPTION)
                    .fontColor(this.themeColors.premium)
                }
              }
              .width('100%')
              .margin({ bottom: SPACE_MD })

              Row() {
                Row() {
                  AppIcon({
                    name: this.isPremium ? this.getSelectedNoiseIcon() : 'noise',
                    iconSize: ICON_SIZE_XL,
                    framed: true,
                    muted: !this.isPremium
                  })

                  Column() {
                    Text(this.isPremium ? this.getSelectedNoiseLabel() : '白噪音')
                      .fontSize(TYPE_BODY)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.themeColors.textPrimary)
                    Text(this.getNoiseHintText())
                      .fontSize(TYPE_META)
                      .fontColor(this.themeColors.textMuted)
                      .margin({ top: SPACE_2XS })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .margin({ left: SPACE_SM })
                }

                Blank()

                AppIcon({
                  name: 'chevron-right',
                  iconSize: 18,
                  framed: false,
                  color: this.themeColors.textMuted
                })
              }
              .width('100%')
              .padding({ left: SPACE_MD, right: SPACE_MD, top: SPACE_MD, bottom: SPACE_MD })
              .backgroundColor(this.themeColors.cardBackground)
              .borderRadius(16)
              .onClick(() => {
                this.openNoiseSelector();
              })
            }
            .width('100%')
            .margin({ bottom: SPACE_MD })

            // 关联代办
            if (this.aiFill.shouldShowBanner()) {
              AppAIFillBanner({
                status: this.aiFill.getBannerComponentStatus(),
                title: this.aiFill.getBannerTitle(),
                actionText: '隐藏提示',
                action: () => { this.aiFill.dismiss(); }
              })
            }

            Column() {
              Text('关联代办 *')
                .fontSize(TYPE_BODY)
                .fontColor(this.themeColors.textSecondary)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: SPACE_SM })

              Column() {
                if (this.taskId && this.taskTitle) {
                  Row() {
                    Text(this.taskTitle)
                      .fontSize(TYPE_SECTION_TITLE)
                      .fontColor(this.themeColors.textPrimary)
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    AppIcon({ name: 'success', iconSize: ICON_SIZE_XS, framed: false, color: this.themeColors.success })
                      .margin({ left: SPACE_SM })
                  }
                  .width('100%')
                } else {
                  Text('点击选择待办事项')
                    .fontSize(TYPE_SECTION_TITLE)
                    .fontColor(this.themeColors.textMuted)
                }
              }
              .width('100%')
              .height(BUTTON_HEIGHT_LG)
              .padding({ left: SPACE_CARD, right: SPACE_CARD })
              .backgroundColor(this.themeColors.surfaceLight)
              .borderRadius(12)
              .justifyContent(FlexAlign.Center)
              .enabled(!this.autoSelect)
              .onClick(() => {
                if (!this.autoSelect) {
                  this.openTaskSelector();
                }
              })
            }
            .width('100%')
            .margin({ bottom: SPACE_CARD })

            Row() {
              AppButton({
                text: this.continuousMode ? `开始连续番茄 · ${this.totalRounds}轮` : '立即开始',
                variant: 'primary',
                buttonSize: 'lg',
                fullWidth: true,
                iconName: 'tomato',
                disabled: !(this.taskId || this.taskTitle),
                tapAction: () => {
                  if (this.taskId || this.taskTitle) {
                    this.getUIContext().getRouter().pushUrl({
                      url: 'pages/PomodoroPage',
                      params: {
                        duration: this.duration,
                        taskId: this.taskId || '',
                        taskTitle: this.taskTitle,
                        continuousMode: this.continuousMode,
                        totalRounds: this.totalRounds,
                        breakDuration: this.breakDuration,
                        longBreakDuration: this.longBreakDuration,
                        noiseKey: this.isPremium ? this.selectedNoiseKey : ''
                      }
                    });
                  }
                }
              })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: SPACE_CARD, right: SPACE_CARD, top: SPACE_SM, bottom: SPACE_MD })
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeColors.background)

      this.NoiseSelectorOverlay()
      this.TaskSelectorOverlay()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }

  @Builder
  NoiseSelectorOverlay() {
    if (this.showNoiseSelector) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.themeColors.surfaceOverlay)
          .onClick(() => {
            this.showNoiseSelector = false;
          })

        Column() {
          Row() {
            Blank()
              .width(ICON_BUTTON_SIZE_SM)

            Text('选择白噪音')
              .fontSize(TYPE_HERO_TITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColors.textPrimary)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)

            this.SheetCloseAction(() => {
              this.showNoiseSelector = false;
            })
          }
          .width('100%')
          .margin({ bottom: SPACE_SM })

          Text('这里仅做预选，番茄开始后会自动播放')
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textMuted)
            .width('100%')
            .margin({ bottom: SPACE_CARD })

          AppButton({
            text: this.selectedNoiseKey ? '不使用白噪音' : '当前不使用白噪音',
            variant: this.selectedNoiseKey ? 'danger' : 'secondary',
            buttonSize: 'md',
            fullWidth: true,
            tapAction: () => {
              void this.clearNoiseSelection();
            }
          })
            .margin({ bottom: SPACE_CARD })

          Scroll() {
            Column() {
              Text('自然声音')
                .fontSize(TYPE_META)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.themeColors.textSecondary)
                .width('100%')
                .margin({ bottom: SPACE_SM })

              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.getNatureNoiseOptions(), (option: NoiseOption) => {
                  this.NoiseOptionItem(option)
                })
              }
              .width('100%')

              Text('人类 / 人造声音')
                .fontSize(TYPE_META)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.themeColors.textSecondary)
                .width('100%')
                .margin({ top: SPACE_SM, bottom: SPACE_SM })

              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.getArtificialNoiseOptions(), (option: NoiseOption) => {
                  this.NoiseOptionItem(option)
                })
              }
              .width('100%')
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Auto)
        }
        .width('100%')
        .height('62%')
        .padding(SPACE_CARD)
        .backgroundColor(this.themeColors.surface)
        .borderRadius({ topLeft: 16, topRight: 16 })
        .position({ x: 0, y: '38%' })
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .zIndex(998)
    }
  }

  @Builder
  NoiseOptionItem(option: NoiseOption) {
    Column() {
      Stack() {
        AppIcon({ name: option.icon, iconSize: ICON_SIZE_XL, framed: false })

        if (this.selectedNoiseKey === option.key) {
          AppIcon({ name: 'success', iconSize: ICON_SIZE_XS, framed: false, color: this.themeColors.primary })
            .position({ x: 20, y: -2 })
        }
      }
      .width(BUTTON_HEIGHT_LG)
      .height(BUTTON_HEIGHT_LG)
      .backgroundColor(this.selectedNoiseKey === option.key ? this.themeColors.primary + '18' : this.themeColors.surfaceLight)
      .borderRadius(20)
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
        .margin({ top: SPACE_2XS })
    }
    .width('24%')
    .margin({ right: '1%', bottom: 14 })
    .onClick(() => {
      void this.selectNoise(option);
    })
  }

  @Builder
  TaskSelectorOverlay() {
    if (this.showTaskSelector) {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.themeColors.surfaceOverlay)
          .onClick(() => {
            this.showTaskSelector = false;
          })

        Column() {
          Row() {
            Blank()
              .width(ICON_BUTTON_SIZE_SM)

            Text('选择关联任务')
              .fontSize(TYPE_HERO_TITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColors.textPrimary)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)

            this.SheetCloseAction(() => {
              this.showTaskSelector = false;
            })
          }
          .width('100%')
          .margin({ bottom: SPACE_CARD })

          TextInput({ text: this.searchText, placeholder: '搜索任务...' })
            .width('100%')
            .height(BUTTON_HEIGHT_MD)
            .fontColor(this.themeColors.textPrimary)
            .placeholderColor(this.themeColors.textMuted)
            .backgroundColor(this.themeColors.inputBackground)
            .borderRadius(8)
            .padding(SPACE_SM)
            .margin({ bottom: SPACE_CARD })
            .onChange((value: string) => {
              this.searchText = value;
              this.displayCount = 5;
              this.filterTasks();
            })

          Scroll() {
            Column() {
              ForEach(this.filteredTasks, (task: Task) => {
                this.TaskItem(task)
              }, (task: Task) => task.id)

              if (this.filteredTasks.length < this.getFilteredTaskCount()) {
                AppButton({
                  text: '加载更多',
                  variant: 'ghost',
                  buttonSize: 'md',
                  fullWidth: true,
                  tapAction: () => {
                    this.loadMoreTasks();
                  }
                })
                  .margin({ top: SPACE_SM })
              }
            }
            .width('100%')
          }
          .width('100%')
          .layoutWeight(1)
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Auto)
        }
        .width('100%')
        .height('62%')
        .padding(SPACE_CARD)
        .backgroundColor(this.themeColors.surface)
        .borderRadius({ topLeft: 16, topRight: 16 })
        .position({ x: 0, y: '38%' })
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .zIndex(999)
    }
  }

  @Builder
  TaskItem(task: Task) {
    Column() {
      Row() {
        Column() {
          Text(task.title)
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row() {
            Text(task.goalTitle)
              .fontSize(TYPE_META)
              .fontColor(this.themeColors.textSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            // 番茄图标显示
            if (task.pomodoroCount > 0) {
              Row() {
                ForEach(Array.from({length: Math.min(task.pomodoroCount, 3)}), (item: undefined, index: number) => {
                  AppIcon({ name: 'tomato', iconSize: ICON_SIZE_XS, framed: false })
                    .margin({ left: SPACE_2XS })
                })
              }
              .margin({ left: SPACE_SM })
            }
          }
          .margin({ top: SPACE_2XS })
        }
        .layoutWeight(1)

        if (this.taskId === task.id) {
          AppIcon({ name: 'success', iconSize: ICON_SIZE_XS, framed: false, color: this.themeColors.success })
        }
      }
      .width('100%')
      .padding(SPACE_MD)
    }
    .width('100%')
    .backgroundColor(this.taskId === task.id ? this.themeColors.primary + '15' : this.themeColors.surfaceLight)
    .borderRadius(12)
    .margin({ bottom: SPACE_SM })
    .onClick(() => {
      this.selectTask(task);
    })
  }
}
