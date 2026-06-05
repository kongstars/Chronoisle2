import dataPreferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';
import { GoalCategory } from '../models/Goal';
import { GoalPlanningService, StartResponse } from '../services/GoalPlanningService';
import { AppErrorService } from '../services/AppErrorService';
import { PrivacyConsentService } from '../services/PrivacyConsentService';
import { Logger } from '../Utils/Logger';
import { PlanningApiResponse, GoalDraft } from '../models/PlanningSession';
import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { CATEGORY_COLORS } from '../common/Constants';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppIcon } from '../ui/base/AppIcon';
import { ICON_SIZE_XS } from '../foundation/tokens/IconTokens';
import { MOTION_CURVE_STANDARD, MOTION_DURATION_BASE, MOTION_DURATION_SLOW } from '../foundation/tokens/MotionTokens';
import { RADIUS_LG, RADIUS_MD, RADIUS_XL } from '../foundation/tokens/RadiusTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_HERO_TITLE, TYPE_META, TYPE_PAGE_TITLE, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';

const ONBOARDING_PREFS_NAME: string = 'onboarding_prefs';
const ONBOARDING_COMPLETED_KEY: string = 'onboarding_completed';
const ONBOARDING_WHITE: string = '#FFFFFF';
const ONBOARDING_WHITE_90: string = 'rgba(255,255,255,0.9)';
const ONBOARDING_WHITE_85: string = 'rgba(255,255,255,0.85)';
const ONBOARDING_WHITE_80: string = 'rgba(255,255,255,0.8)';
const ONBOARDING_WHITE_75: string = 'rgba(255,255,255,0.75)';
const ONBOARDING_WHITE_70: string = 'rgba(255,255,255,0.7)';
const ONBOARDING_WHITE_50: string = 'rgba(255,255,255,0.5)';
const ONBOARDING_WHITE_40: string = 'rgba(255,255,255,0.4)';
const ONBOARDING_WHITE_30: string = 'rgba(255,255,255,0.3)';
const ONBOARDING_WHITE_20: string = 'rgba(255,255,255,0.2)';
const ONBOARDING_WHITE_16: string = 'rgba(255,255,255,0.16)';
const ONBOARDING_WHITE_15: string = 'rgba(255,255,255,0.15)';
const ONBOARDING_WHITE_14: string = 'rgba(255,255,255,0.14)';
const ONBOARDING_WHITE_12: string = 'rgba(255,255,255,0.12)';
const ONBOARDING_WHITE_10: string = 'rgba(255,255,255,0.1)';
const ONBOARDING_TRANSPARENT: string = 'rgba(0,0,0,0)';
const ONBOARDING_SHADOW_LG: string = 'rgba(0,0,0,0.15)';
const ONBOARDING_SHADOW_MD: string = 'rgba(0,0,0,0.12)';
const ONBOARDING_SHADOW_SM: string = 'rgba(0,0,0,0.1)';

const onboardingLogger = Logger.create('OnboardingPage');
export const ONBOARDING_ENTRY_PAYLOAD_KEY: string = 'onboarding_entry_payload';
export const ONBOARDING_COMPLETED_RUNTIME_KEY: string = 'onboarding_completed_runtime';

const ONBOARDING_STEP_GRADIENTS: [string, number][][] = [
  [['#667EEA', 0], ['#764BA2', 1]],
  [['#4F46E5', 0], ['#06B6D4', 1]],
  [['#11998E', 0], ['#38EF7D', 1]]
];

// ======== 预设目标案例 ========

interface PresetGoal {
  icon: string;
  label: string;
  color: string;
  gradientStart: string;
  gradientEnd: string;
  category: GoalCategory;
  title: string;
  description: string;
}

interface TemplateMilestone {
  title: string;
  targetValue: number;
  tasks: string[];
}

interface OnboardingEntryPayload {
  openGoalCreate: string;
  onboardingGoalTitle: string;
  onboardingCategory: string;
  onboardingTemplate: string;
}

interface OnboardingSplashParams extends OnboardingEntryPayload {
  forceOnboardingCompleted: string;
}

interface ForceOnboardingCompletedParams {
  forceOnboardingCompleted: string;
}

interface GoalBreakdownNavigationParams {
  sessionId: string;
  intent: string;
  source: 'create_goal';
  fromOnboarding: string;
}

const PRESET_GOALS: PresetGoal[] = [
  {
    icon: 'health',
    label: '健康',
    color: CATEGORY_COLORS[GoalCategory.HEALTH],
    gradientStart: '#43E97B',
    gradientEnd: '#38F9D7',
    category: GoalCategory.HEALTH,
    title: '三个月减重10斤',
    description: '通过合理饮食和规律运动，在三个月内健康减重10斤'
  },
  {
    icon: 'growth',
    label: '成长',
    color: CATEGORY_COLORS[GoalCategory.LEARNING],
    gradientStart: '#F6D365',
    gradientEnd: '#FDA085',
    category: GoalCategory.LEARNING,
    title: '30天养成阅读习惯',
    description: '每天坚持阅读至少30分钟，一个月内读完3本书'
  },
  {
    icon: 'finance',
    label: '财富',
    color: CATEGORY_COLORS[GoalCategory.FINANCE],
    gradientStart: '#A18CD1',
    gradientEnd: '#FBC2EB',
    category: GoalCategory.FINANCE,
    title: '半年攒下第一个1万应急金',
    description: '通过控制支出和记账，半年内存够1万元应急储备金'
  },
  {
    icon: 'joy',
    label: '快乐',
    color: CATEGORY_COLORS[GoalCategory.FUN],
    gradientStart: '#FF6B6B',
    gradientEnd: '#FFAB76',
    category: GoalCategory.FUN,
    title: '学会弹一首完整的吉他曲',
    description: '从零基础开始，3个月内学会弹奏一首完整的吉他曲'
  }
];

// ======== 页面组件 ========

@Entry
@Component
struct OnboardingPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State currentStep: number = 0;
  @State selectedPresetIndex: number = -1;
  @State customGoalInput: string = '';
  @State animOpacity: number = 0;
  @State contentOffsetY: number = 30;
  @State teachBubbleOpacity: number = 0;
  @State isAIProcessing: boolean = false;
  @State aiErrorMessage: string = '';
  @State isLeavingOnboarding: boolean = false;
  @State hasAgreedPrivacy: boolean = false;
  @State planningSessionId: string = '';
  @State goalDraft: GoalDraft | null = null;
  // Step 2: 拆解结果展示
  @State showResultCards: boolean[] = [false, false, false];
  @State resultCardScale: number = 0.92;
  private prefs: dataPreferences.Preferences | null = null;

  async aboutToAppear(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as Context;
      this.prefs = await dataPreferences.getPreferences(context, ONBOARDING_PREFS_NAME);
    } catch (error) {
      onboardingLogger.error('Failed to initialize preferences', error as Object);
    }
    this.animateStepIn();
  }

  animateStepIn(): void {
    this.animOpacity = 0;
    this.contentOffsetY = 30;
    this.teachBubbleOpacity = 0;
    this.showResultCards = [false, false, false];
    this.resultCardScale = 0.92;

    const self = this;
    setTimeout(() => {
      self.animOpacity = 1;
      self.contentOffsetY = 0;
    }, 100);

    setTimeout(() => {
      self.teachBubbleOpacity = 1;
    }, 800);

    // Step 2 的卡片逐个出现
    if (this.currentStep === 2) {
      setTimeout(() => { self.showResultCards = [true, false, false]; }, 300);
      setTimeout(() => { self.showResultCards = [true, true, false]; }, 600);
      setTimeout(() => { self.showResultCards = [true, true, true]; self.resultCardScale = 1; }, 900);
    }
  }

  async markOnboardingCompleted(): Promise<void> {
    AppStorage.setOrCreate<boolean>(ONBOARDING_COMPLETED_RUNTIME_KEY, true);
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const prefs = this.prefs ?? await dataPreferences.getPreferences(hostContext, ONBOARDING_PREFS_NAME);
      this.prefs = prefs;
      await prefs.put(ONBOARDING_COMPLETED_KEY, true);
      await prefs.flush();
    } catch (error) {
      onboardingLogger.error('Failed to save onboarding status', error as Object);
    }

    // 用户已经勾选同意隐私政策与用户协议，触发延迟初始化 SDK 与网络
    try {
      await PrivacyConsentService.initializeAfterConsent(hostContext);
    } catch (error) {
      onboardingLogger.error('initializeAfterConsent failed', error as Object);
    }
  }

  async skipOnboarding(): Promise<void> {
    if (this.isLeavingOnboarding) {
      return;
    }
    this.isLeavingOnboarding = true;
    AppStorage.delete(ONBOARDING_ENTRY_PAYLOAD_KEY);
    void this.markOnboardingCompleted();
    this.navigateFromOnboarding('pages/MainPage');
  }

  goToStep(step: number): void {
    this.currentStep = step;
    this.animateStepIn();
  }

  getSelectedGoalTitle(): string {
    if (this.selectedPresetIndex >= 0 && this.selectedPresetIndex < PRESET_GOALS.length) {
      return PRESET_GOALS[this.selectedPresetIndex].title;
    }
    return this.customGoalInput.trim();
  }

  getSelectedGoalDescription(): string {
    if (this.selectedPresetIndex >= 0 && this.selectedPresetIndex < PRESET_GOALS.length) {
      return PRESET_GOALS[this.selectedPresetIndex].description;
    }
    return '';
  }

  getSelectedCategory(): GoalCategory {
    if (this.selectedPresetIndex >= 0 && this.selectedPresetIndex < PRESET_GOALS.length) {
      return PRESET_GOALS[this.selectedPresetIndex].category;
    }
    return GoalCategory.LEARNING;
  }

  getSelectedColor(): string {
    if (this.selectedPresetIndex >= 0 && this.selectedPresetIndex < PRESET_GOALS.length) {
      return PRESET_GOALS[this.selectedPresetIndex].color;
    }
    return this.themeColors.primary;
  }

  hasValidGoalInput(): boolean {
    return this.selectedPresetIndex >= 0 || this.customGoalInput.trim().length > 2;
  }

  // 调用 AI Agent 拆解
  async startAIBreakdown(): Promise<void> {
    const goalTitle = this.getSelectedGoalTitle();
    if (!goalTitle) {
      return;
    }

    this.isAIProcessing = true;
    this.aiErrorMessage = '';
    this.goToStep(2);

    try {
      const intentText = goalTitle + (this.getSelectedGoalDescription() ? '\n' + this.getSelectedGoalDescription() : '');
      const result: PlanningApiResponse<StartResponse> = await GoalPlanningService.start(
        intentText, 'create_goal', undefined, true
      );

      if (result.success && result.data?.sessionId) {
        this.planningSessionId = result.data.sessionId;
        if (result.data.goalDraft) {
          this.goalDraft = result.data.goalDraft;
        }
        // 目标创建成功，跳转到目标规划页面完整体验
        void this.markOnboardingCompleted();
        const goalBreakdownParams: GoalBreakdownNavigationParams = {
          sessionId: this.planningSessionId,
          intent: intentText,
          source: 'create_goal',
          fromOnboarding: 'true'
        };
        this.navigateFromOnboarding('pages/GoalBreakdownPage', goalBreakdownParams);
      } else {
        // AI 调用失败时使用预设模板保底
        this.aiErrorMessage = AppErrorService.fromMessage(result.message || '网络连接超时', '网络连接超时');
        this.isAIProcessing = false;
        this.fallbackToLocalTemplate();
      }
    } catch (error) {
      onboardingLogger.error('AI breakdown error', error as Object);
      this.aiErrorMessage = AppErrorService.fromUnknown(error, '网络连接超时');
      this.isAIProcessing = false;
      this.fallbackToLocalTemplate();
    }
  }

  // 本地模板保底
  fallbackToLocalTemplate(): void {
    this.isAIProcessing = false;
    this.animateStepIn();
  }

  async finishWithLocalTemplate(): Promise<void> {
    if (this.isLeavingOnboarding) {
      return;
    }
    this.isLeavingOnboarding = true;
    const goalTitle = this.getSelectedGoalTitle();
    const category = this.getSelectedCategory();
    const onboardingParams: OnboardingEntryPayload = {
      openGoalCreate: 'true',
      onboardingGoalTitle: goalTitle,
      onboardingCategory: `${category}`,
      onboardingTemplate: JSON.stringify({
        milestones: this.getLocalTemplateMilestones()
      })
    };
    AppStorage.setOrCreate<OnboardingEntryPayload>(ONBOARDING_ENTRY_PAYLOAD_KEY, onboardingParams);
    void this.markOnboardingCompleted();
    this.navigateFromOnboarding('pages/MainPage');
  }

  private navigateFromOnboarding(url: string, params?: Object): void {
    const pageRouter = this.getUIContext().getRouter();
    try {
      if (params) {
        pageRouter.replaceUrl({ url, params });
      } else {
        pageRouter.replaceUrl({ url });
      }
      return;
    } catch (error) {
      onboardingLogger.error(`replaceUrl failed for ${url}`, error as Object);
    }

    try {
      if (params) {
        pageRouter.pushUrl({ url, params });
      } else {
        pageRouter.pushUrl({ url });
      }
      return;
    } catch (fallbackError) {
      onboardingLogger.error(`pushUrl failed for ${url}`, fallbackError as Object);
      this.isLeavingOnboarding = false;
    }
  }

  getLocalTemplateMilestones(): TemplateMilestone[] {
    const cat = this.getSelectedCategory();
    if (cat === GoalCategory.HEALTH) {
      const m1: TemplateMilestone = { title: '饮食习惯改善', targetValue: 30, tasks: ['制定每日低卡饮食计划', '学会看食品热量标签', '每周至少自己做3次饭'] };
      const m2: TemplateMilestone = { title: '运动习惯养成', targetValue: 12, tasks: ['选择适合的运动方式', '每周运动3次每次30分钟', '记录每次运动数据'] };
      const m3: TemplateMilestone = { title: '体重稳步下降', targetValue: 10, tasks: ['每周固定时间称重记录', '月底复盘调整方案', '达标后制定维持计划'] };
      return [m1, m2, m3];
    } else if (cat === GoalCategory.LEARNING) {
      const m1: TemplateMilestone = { title: '阅读计划建立', targetValue: 3, tasks: ['挑选3本感兴趣的书', '每天固定30分钟阅读时间', '准备笔记本记录感悟'] };
      const m2: TemplateMilestone = { title: '阅读习惯巩固', targetValue: 20, tasks: ['坚持每天打卡阅读', '每读完一章写3个关键点', '和朋友分享读书心得'] };
      const m3: TemplateMilestone = { title: '输出读书成果', targetValue: 3, tasks: ['为每本书写一篇读后感', '制作一份书籍推荐清单', '用学到的知识解决一个实际问题'] };
      return [m1, m2, m3];
    } else if (cat === GoalCategory.FINANCE) {
      const m1: TemplateMilestone = { title: '摸清收支现状', targetValue: 1, tasks: ['下载记账工具开始记账', '记录一个月完整开销', '分析哪些是不必要支出'] };
      const m2: TemplateMilestone = { title: '月度储蓄达标', targetValue: 6, tasks: ['设定每月存款目标金额', '发工资后先存后花', '每月月底检查存款进度'] };
      const m3: TemplateMilestone = { title: '建立理财意识', targetValue: 1, tasks: ['学习基础理财知识', '了解低风险理财产品', '制定下半年理财计划'] };
      return [m1, m2, m3];
    } else {
      const m1: TemplateMilestone = { title: '入门基础打牢', targetValue: 1, tasks: ['购买入门装备和教材', '找到学习资源或老师', '完成第一节基础课程'] };
      const m2: TemplateMilestone = { title: '持续练习提升', targetValue: 20, tasks: ['每周练习3次每次30分钟', '学习基本技巧和指法', '录制练习视频记录进步'] };
      const m3: TemplateMilestone = { title: '完成作品展示', targetValue: 1, tasks: ['选择一首目标曲目', '分段练习直到完整弹奏', '录制完整演奏视频'] };
      return [m1, m2, m3];
    }
  }

  getStepGradient(): [string, number][] {
    return ONBOARDING_STEP_GRADIENTS[this.currentStep] || ONBOARDING_STEP_GRADIENTS[0];
  }

  build() {
    Stack() {
      // 底层渐变背景
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: this.getStepGradient()
        })

      Column() {
        // 顶部栏
        this.TopBar()

        // 内容区
        Column() {
          if (this.currentStep === 0) {
            this.Step0_BrandIntro()
          } else if (this.currentStep === 1) {
            this.Step1_GoalSelect()
          } else {
            this.Step2_AIProcessing()
          }
        }
        .width('100%')
        .layoutWeight(1)
        .opacity(this.animOpacity)
        .translate({ y: this.contentOffsetY })
        .animation({
          duration: MOTION_DURATION_SLOW,
          curve: MOTION_CURVE_STANDARD
        })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  // ======== 顶部栏 ========

  @Builder
  TopBar() {
    Row() {
      // 进度指示器
      Row({ space: 8 }) {
        ForEach([0, 1, 2], (index: number) => {
          Column()
            .width(this.currentStep === index ? 32 : 12)
            .height(6)
            .borderRadius(3)
            .backgroundColor(index <= this.currentStep ? ONBOARDING_WHITE : ONBOARDING_WHITE_30)
            .animation({ duration: MOTION_DURATION_BASE, curve: MOTION_CURVE_STANDARD })
        }, (index: number) => `step_indicator_${index}`)
      }
      .layoutWeight(1)

      Button() {
        Row({ space: 4 }) {
          Text('跳过')
            .fontSize(TYPE_BODY)
            .fontColor(ONBOARDING_WHITE_90)
          AppIcon({
            name: 'chevron-right',
            iconSize: ICON_SIZE_XS,
            framed: false,
            color: ONBOARDING_WHITE_90
          })
        }
      }
      .backgroundColor(ONBOARDING_WHITE_20)
      .borderRadius(RADIUS_LG)
      .padding({ top: 8, bottom: 8, left: 16, right: 16 })
      .onClick(() => {
        this.skipOnboarding();
      })
    }
    .width('100%')
    .padding({ top: 36, left: 20, right: 20, bottom: 10 })
  }

  // ======== Step 0: 品牌介绍 ========

  @Builder
  Step0_BrandIntro() {
    Column() {
      Blank()

      // 品牌 Logo 区域
      Column({ space: 8 }) {
        AppIcon({ name: 'joy', iconSize: 48, color: ONBOARDING_WHITE, surfaceColor: ONBOARDING_WHITE_16 })

        Text('四时清单')
          .fontSize(TYPE_PAGE_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ONBOARDING_WHITE)

        Text('AI 驱动的目标管理')
          .fontSize(TYPE_BODY)
          .fontColor(ONBOARDING_WHITE_80)
      }
      .alignItems(HorizontalAlign.Center)

      Blank().height(32)

      // 产品核心能力
      Column({ space: 20 }) {
        this.FeatureItem('goal', '目标拆解', '把模糊的想法变成可执行的行动计划')
        this.FeatureItem('ai', '智能规划', 'AI 帮你安排每天最重要的事')
        this.FeatureItem('stats', '进度追踪', '实时看到自己离目标还有多远')
      }
      .padding({ left: 40, right: 40 })

      Blank()

      // 教学气泡
      Column() {
        Text('1 分钟体验，创建你的第一个目标')
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ONBOARDING_WHITE)
          .textAlign(TextAlign.Center)
      }
      .width('85%')
      .padding({ left: 18, right: 18, top: 12, bottom: 12 })
      .backgroundColor(ONBOARDING_WHITE_15)
      .borderRadius(RADIUS_MD)
      .opacity(this.teachBubbleOpacity)
      .animation({ duration: MOTION_DURATION_SLOW, curve: MOTION_CURVE_STANDARD })

      // 隐私协议同意
      Row({ space: 10 }) {
        Checkbox()
          .select(this.hasAgreedPrivacy)
          .selectedColor(Color.White)
          .width(20)
          .height(20)
          .onChange((value: boolean) => {
            this.hasAgreedPrivacy = value;
          })

        Column({ space: 2 }) {
          Text('我已阅读并同意')
            .fontSize(TYPE_CAPTION)
            .fontColor(ONBOARDING_WHITE_85)

          Row({ space: 4 }) {
            Text('《隐私政策》')
              .fontSize(TYPE_CAPTION)
              .fontColor(ONBOARDING_WHITE)
              .fontWeight(FontWeight.Medium)
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPolicyPage' });
              })
            Text('和')
              .fontSize(TYPE_CAPTION)
              .fontColor(ONBOARDING_WHITE_85)
            Text('《用户协议》')
              .fontSize(TYPE_CAPTION)
              .fontColor(ONBOARDING_WHITE)
              .fontWeight(FontWeight.Medium)
              .onClick(() => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/TermsOfServicePage' });
              })
          }
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('85%')
      .padding({ left: 18, right: 18, top: 12, bottom: 12 })
      .backgroundColor(ONBOARDING_WHITE_10)
      .borderRadius(RADIUS_MD)
      .margin({ top: 12 })

      // 底部按钮
      Button('开始创建第一个目标')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.hasAgreedPrivacy
          ? (this.getStepGradient()[0][0] as string)
          : ONBOARDING_WHITE_40)
        .backgroundColor(this.hasAgreedPrivacy ? ONBOARDING_WHITE : ONBOARDING_WHITE_12)
        .borderRadius(RADIUS_XL)
        .width('75%')
        .height(46)
        .shadow(this.hasAgreedPrivacy
          ? { radius: 20, color: ONBOARDING_SHADOW_LG, offsetY: 8 }
          : { radius: 0, color: ONBOARDING_TRANSPARENT, offsetY: 0 })
        .enabled(this.hasAgreedPrivacy)
        .margin({ top: 16, bottom: 32 })
        .onClick(() => {
          this.goToStep(1);
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  FeatureItem(icon: string, title: string, desc: string) {
    Row({ space: 16 }) {
      AppIcon({ name: icon, iconSize: 44, color: ONBOARDING_WHITE, surfaceColor: ONBOARDING_WHITE_14 })

      Column({ space: 4 }) {
        Text(title)
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ONBOARDING_WHITE)
        Text(desc)
          .fontSize(TYPE_BODY)
          .fontColor(ONBOARDING_WHITE_80)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(ONBOARDING_WHITE_10)
    .borderRadius(RADIUS_MD)
  }

  // ======== Step 1: 选择目标 ========

  @Builder
  Step1_GoalSelect() {
    Column() {
      Column({ space: 8 }) {
        Text('选一个你想实现的目标')
          .fontSize(TYPE_HERO_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(ONBOARDING_WHITE)
          .textAlign(TextAlign.Center)

        Text('AI 会帮你把它拆解成具体的行动计划')
          .fontSize(TYPE_BODY)
          .fontColor(ONBOARDING_WHITE_80)
          .textAlign(TextAlign.Center)
      }
      .margin({ top: 24 })

      // 四宫格预设目标
      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 12 }) {
            Column() {
              this.PresetGoalCard(0)
            }
            .layoutWeight(1)

            Column() {
              this.PresetGoalCard(1)
            }
            .layoutWeight(1)
          }
          .width('100%')

          Row({ space: 12 }) {
            Column() {
              this.PresetGoalCard(2)
            }
            .layoutWeight(1)

            Column() {
              this.PresetGoalCard(3)
            }
            .layoutWeight(1)
          }
          .width('100%')

          // 或者自定义输入
          Column({ space: 12 }) {
            Row() {
              Column()
                .width(60)
                .height(1)
                .backgroundColor(ONBOARDING_WHITE_30)
              Text('  或者，输入你自己的目标  ')
                .fontSize(TYPE_META)
                .fontColor(ONBOARDING_WHITE_70)
              Column()
                .width(60)
                .height(1)
                .backgroundColor(ONBOARDING_WHITE_30)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)

            TextInput({
              placeholder: '例如：通过英语六级考试',
              text: this.customGoalInput
            })
              .height(44)
              .fontSize(TYPE_SECTION_TITLE)
              .fontColor(this.themeColors.textPrimary)
              .placeholderColor(this.themeColors.textMuted)
              .backgroundColor(this.themeColors.inputBackground)
              .borderRadius(RADIUS_MD)
              .padding({ left: 16, right: 16 })
              .onChange((value: string) => {
                this.customGoalInput = value;
                if (value.trim().length > 0) {
                  this.selectedPresetIndex = -1; // 取消预设选择
                }
              })
          }
          .margin({ top: 8 })
        }
        .padding({ left: 28, right: 28, top: 20, bottom: 24 })
      }
      .align(Alignment.Top)
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 底部按钮
      Button('让 AI 帮我拆解')
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.hasValidGoalInput() ? this.themeColors.primary : ONBOARDING_WHITE_50)
        .backgroundColor(this.hasValidGoalInput() ? ONBOARDING_WHITE : ONBOARDING_WHITE_15)
        .borderRadius(RADIUS_XL)
        .width('75%')
        .height(46)
        .shadow({ radius: 16, color: ONBOARDING_SHADOW_MD, offsetY: 6 })
        .enabled(this.hasValidGoalInput())
        .onClick(() => {
          this.startAIBreakdown();
        })
        .margin({ bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  PresetGoalCard(index: number) {
    Column({ space: 6 }) {
      AppIcon({
        name: PRESET_GOALS[index].icon,
        iconSize: 36,
        color: ONBOARDING_WHITE,
        surfaceColor: ONBOARDING_WHITE_14
      })

      Text(PRESET_GOALS[index].label)
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(ONBOARDING_WHITE)

      Text(PRESET_GOALS[index].title)
        .fontSize(TYPE_META)
        .fontColor(ONBOARDING_WHITE_75)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 8, right: 8, top: 14, bottom: 14 })
    .linearGradient({
      angle: 145,
      colors: this.selectedPresetIndex === index
        ? [[ONBOARDING_WHITE_40, 0], [ONBOARDING_WHITE_20, 1]]
        : [[PRESET_GOALS[index].gradientStart + '30', 0], [PRESET_GOALS[index].gradientEnd + '20', 1]]
    })
    .borderRadius(RADIUS_LG)
    .border({
      width: this.selectedPresetIndex === index ? 2.5 : 1,
      color: this.selectedPresetIndex === index ? ONBOARDING_WHITE : ONBOARDING_WHITE_20
    })
    .shadow({ radius: 12, color: ONBOARDING_SHADOW_SM, offsetY: 4 })
    .animation({ duration: MOTION_DURATION_BASE, curve: MOTION_CURVE_STANDARD })
    .onClick(() => {
      this.selectedPresetIndex = index;
      this.customGoalInput = ''; // 清除自定义输入
    })
  }

  // ======== Step 2: AI 处理中 / 本地模板展示 ========

  @Builder
  Step2_AIProcessing() {
    Column() {
      if (this.isAIProcessing) {
        // AI 处理中的等待界面
        Blank()
        Column({ space: 24 }) {
          LoadingProgress()
            .width(52)
            .height(52)
            .color(Color.White)

          Text('AI 正在为你拆解目标...')
            .fontSize(TYPE_HERO_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ONBOARDING_WHITE)

          Text(`正在分析「${this.getSelectedGoalTitle()}」`)
            .fontSize(TYPE_BODY)
            .fontColor(ONBOARDING_WHITE_80)
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .padding({ left: 32, right: 32 })

          Column({ space: 8 }) {
            Text('AI 正在调用目标拆解引擎...')
              .fontSize(TYPE_META)
              .fontColor(ONBOARDING_WHITE_70)
            Text('正在生成进度追踪方案...')
              .fontSize(TYPE_META)
              .fontColor(ONBOARDING_WHITE_50)
            Text('正在规划具体行动清单...')
              .fontSize(TYPE_META)
              .fontColor(ONBOARDING_WHITE_40)
          }
          .margin({ top: 12 })
        }
        .alignItems(HorizontalAlign.Center)
        Blank()
      } else {
        // 本地模板保底方案展示
        this.LocalTemplatePreview()
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  LocalTemplatePreview() {
    Column() {
      Row() {
        AppButton({
          text: '返回',
          variant: 'secondary',
          buttonSize: 'sm',
          iconName: 'chevron-left',
          tapAction: () => {
            this.goToStep(1);
          }
        })

        Column({ space: 2 }) {
          Text('你的目标拆解方案')
            .fontSize(TYPE_HERO_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ONBOARDING_WHITE)
          if (this.aiErrorMessage) {
            Text(this.aiErrorMessage)
              .fontSize(TYPE_CAPTION)
              .fontColor(ONBOARDING_WHITE_70)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8 })

      // 拆解结果滚动区域
      Scroll() {
        Column({ space: 14 }) {
          // 目标卡片
          Column() {
            AppCard({ variant: 'base', spacing: 8, paddingLevel: 'md' }) {
              Row({ space: 8 }) {
                AppIcon({ name: 'goal', iconSize: 24 })
                Text('你的目标').fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary)
              }
              Text(this.getSelectedGoalTitle())
                .fontSize(TYPE_HERO_TITLE)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.themeColors.textPrimary)
                .width('100%')
            }
          }
          .width('100%')
          .opacity(this.showResultCards[0] ? 1 : 0)
          .animation({ duration: MOTION_DURATION_SLOW, curve: MOTION_CURVE_STANDARD })

          // 衡量标准卡片
          Column() {
            AppCard({ variant: 'base', spacing: 10, paddingLevel: 'md' }) {
              Row({ space: 8 }) {
                AppIcon({ name: 'stats', iconSize: 24 })
                Text('怎么衡量是否达成？').fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary)
              }
              .width('100%')

              ForEach(this.getLocalTemplateMilestones(), (m: TemplateMilestone, index: number) => {
                Row() {
                  AppIcon({ name: 'success', iconSize: ICON_SIZE_XS, framed: false, color: this.getSelectedColor() })
                    .margin({ right: 10 })
                  Text(m.title)
                    .fontSize(TYPE_BODY)
                    .fontColor(this.themeColors.textPrimary)
                    .layoutWeight(1)
                  Text(`目标 ${m.targetValue}`)
                    .fontSize(TYPE_META)
                    .fontColor(this.themeColors.textSecondary)
                }
                .width('100%')
                .padding({ top: 6, bottom: 6 })
              }, (m: TemplateMilestone, index: number) => `milestone_${index}`)
            }
          }
          .width('100%')
          .opacity(this.showResultCards[1] ? 1 : 0)
          .animation({ duration: MOTION_DURATION_SLOW, curve: MOTION_CURVE_STANDARD })

          // 具体行动卡片
          Column() {
            AppCard({ variant: 'base', spacing: 10, paddingLevel: 'md' }) {
              Row({ space: 8 }) {
                AppIcon({ name: 'plan', iconSize: 24 })
                Text('具体要做什么？').fontSize(TYPE_SECTION_TITLE).fontWeight(FontWeight.Bold).fontColor(this.themeColors.textPrimary)
              }
              .width('100%')

              ForEach(this.getAllLocalTasks(), (taskTitle: string, index: number) => {
                Row() {
                  Column()
                    .width(6)
                    .height(6)
                    .borderRadius(3)
                    .backgroundColor(this.getSelectedColor())
                    .margin({ right: 10, top: 6 })
                  Text(taskTitle)
                    .fontSize(TYPE_BODY)
                    .fontColor(this.themeColors.textSecondary)
                    .layoutWeight(1)
                }
                .width('100%')
                .padding({ top: 3, bottom: 3 })
                .alignItems(VerticalAlign.Top)
              }, (task: string, index: number) => `task_${index}`)
            }
          }
          .width('100%')
          .opacity(this.showResultCards[2] ? 1 : 0)
          .scale({ x: this.resultCardScale, y: this.resultCardScale })
          .animation({ duration: MOTION_DURATION_SLOW, curve: MOTION_CURVE_STANDARD })

          // 提示气泡
          Column({ space: 6 }) {
            Text('保存后，四时清单会帮你追踪每个步骤的进度')
              .fontSize(TYPE_META)
              .fontColor(ONBOARDING_WHITE_90)
            Text('进入首页后可以随时用 AI 进一步优化你的计划')
              .fontSize(TYPE_META)
              .fontColor(ONBOARDING_WHITE_80)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(ONBOARDING_WHITE_15)
          .borderRadius(RADIUS_MD)
          .opacity(this.teachBubbleOpacity)
          .animation({ duration: MOTION_DURATION_SLOW, curve: MOTION_CURVE_STANDARD })
        }
        .padding({ left: 20, right: 20, top: 12, bottom: 24 })
      }
      .align(Alignment.Top)
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 底部按钮
      Column({ space: 10 }) {
        AppButton({
          text: '保存并开始使用',
          variant: 'secondary',
          buttonSize: 'lg',
          iconName: 'success',
          tapAction: () => {
            this.finishWithLocalTemplate();
          }
        })
          .width('80%')

        AppButton({
          text: '跳过，自己探索',
          variant: 'ghost',
          buttonSize: 'sm',
          iconName: 'chevron-right',
          tapAction: () => {
            this.skipOnboarding();
          }
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: 24, top: 8 })
    }
    .width('100%')
    .height('100%')
  }

  getAllLocalTasks(): string[] {
    const allTasks: string[] = [];
    const milestones = this.getLocalTemplateMilestones();
    milestones.forEach((m: TemplateMilestone) => {
      if (m.tasks) {
        m.tasks.forEach((t: string) => {
          allTasks.push(t);
        });
      }
    });
    return allTasks;
  }
}

export async function isOnboardingCompleted(context: Context): Promise<boolean> {
  try {
    const prefs: dataPreferences.Preferences = await dataPreferences.getPreferences(context, ONBOARDING_PREFS_NAME);
    const value: dataPreferences.ValueType = await prefs.get(ONBOARDING_COMPLETED_KEY, false);
    return value as boolean;
  } catch (error) {
    onboardingLogger.error('Failed to check onboarding status', error as Object);
    return false;
  }
}
