import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { themeService } from '../services/ThemeService';
import { GuideService } from '../services/GuideService';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { PAGE_PADDING, SECTION_GAP, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_HERO_TITLE, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { MOTION_CURVE_STANDARD, MOTION_DURATION_BASE } from '../foundation/tokens/MotionTokens';

interface FaqItem {
  id: string;
  question: string;
  answer: string;
}

const FAQ_LIST: FaqItem[] = [
  {
    id: 'faq_1',
    question: '登录后数据会自动处理吗？',
    answer: '会。完成登录后，系统会在后台自动处理账号关联和数据同步，不需要手动点击任何同步入口。'
  },
  {
    id: 'faq_2',
    question: '如何使用 AI 语音或文本快速创建任务？',
    answer: '点击底部全局创建入口，选择语音创建或文本创建。说出类似“明天下午三点提醒我开会”的内容，系统会自动识别标题、时间和动作。'
  },
  {
    id: 'faq_3',
    question: '目标和任务有什么区别？',
    answer: '目标用于承载长期方向，任务用于承载具体执行动作。一个目标可以拆成多个任务、提醒和今日计划动作。'
  },
  {
    id: 'faq_4',
    question: '如何创建倒数日或纪念日？',
    answer: '进入提醒或日历相关入口，新建一个日期事件并选择倒数日/纪念日类型，保存后就会在首页和日历里展示。'
  },
  {
    id: 'faq_5',
    question: '应用支持深色模式吗？',
    answer: '支持。你可以在“我的”页面切换浅色、深色或跟随系统；后续页面会逐步统一迁移到新的双模式规范。'
  },
  {
    id: 'faq_6',
    question: '高级会员包含哪些功能？如何订阅？',
    answer: '高级会员解锁无限 AI 使用次数、无限目标数量、白噪音专注、高级统计等全部功能。在“我的”页面点击会员卡片即可进入订阅页面，支持月度或年度连续订阅。'
  },
  {
    id: 'faq_7',
    question: '如何取消自动续费？',
    answer: '自动续费由华为应用内支付管理。取消方式：打开华为应用市场 → 我的 → 账户 → 订阅 → 找到四时清单 → 取消订阅。取消后当前周期内仍可享受会员权益，到期后将不再自动续费。'
  },
  {
    id: 'faq_8',
    question: '换手机后会员权益还在吗？',
    answer: '在。只要使用同一华为账号登录，进入会员页面点击“恢复购买”即可同步已有订阅。如恢复失败，请确认当前华为账号与购买时一致。'
  }
];

@Entry
@Component
struct HelpPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State expandedId: string = '';

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as Context;
    void themeService.initialize(context);
  }

  private toggleExpand(id: string): void {
    this.expandedId = this.expandedId === id ? '' : id;
  }

  @Builder
  private GettingStartedStep(index: string, title: string, description: string) {
    Row({ space: 14 }) {
      Text(index)
        .fontSize(TYPE_HERO_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.primary)
        .width(28)
        .textAlign(TextAlign.Center)

      Column({ space: 4 }) {
        Text(title)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')
        Text(description)
          .fontSize(TYPE_BODY)
          .lineHeight(20)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private FaqCard(item: FaqItem) {
    AppCard({ variant: this.expandedId === item.id ? 'accent' : 'base', spacing: 12 }) {
      Row() {
        Text(item.question)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.expandedId === item.id ? '收起' : '展开')
          .fontSize(TYPE_META)
          .fontColor(this.themeColors.primary)
      }
      .width('100%')
      .onClick(() => {
        this.getUIContext().animateTo({ duration: MOTION_DURATION_BASE, curve: MOTION_CURVE_STANDARD }, () => {
          this.toggleExpand(item.id);
        });
      })

      if (this.expandedId === item.id) {
        Column()
          .width('100%')
          .height(1)
          .backgroundColor(this.themeColors.divider)

        Text(item.answer)
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textSecondary)
          .lineHeight(22)
          .width('100%')
      }
    }
  }

  build() {
    Scroll() {
      Column({ space: SECTION_GAP }) {
        AppPageHeader({
          title: '帮助与支持',
          subtitle: '查看入门说明、常见问题和引导入口',
          onBack: () => this.getUIContext().getRouter().back()
        })

        Column({ space: 16 }) {
          Text('新手入门')
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')

          AppCard({ spacing: 16 }) {
            this.GettingStartedStep('1', '创建一个目标', '描述你想达成的事情，先明确方向，再进入拆解。')
            this.GettingStartedStep('2', '拆成阶段和行动', '把目标拆成里程碑、任务和提醒，让它具备可执行路径。')
            this.GettingStartedStep('3', '进入今日执行', '把真正要做的动作收进今日计划，减少列表噪音。')
            this.GettingStartedStep('4', '用 AI 辅助整理', '使用 AI 补全、今日计划和重排能力，降低手工整理成本。')
          }

          AppButton({
            text: '重新体验新手引导',
            variant: 'secondary',
            fullWidth: true,
            iconName: 'help',
            tapAction: async () => {
              const context = this.getUIContext().getHostContext() as Context;
              await GuideService.initialize(context);
              await GuideService.resetAllGuidesWithContext(context);
              this.getUIContext().getRouter().replaceUrl({ url: 'pages/OnboardingPage' });
            }
          })

          Text('常见问题')
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')

          ForEach(FAQ_LIST, (item: FaqItem) => {
            this.FaqCard(item)
          }, (item: FaqItem) => item.id)

          Text('如果上面没有解决你的问题，可以在后续版本接入的反馈入口中联系我们。')
            .fontSize(TYPE_META)
            .lineHeight(18)
            .fontColor(this.themeColors.textMuted)
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({ top: SPACE_SM, bottom: PAGE_PADDING })
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING })
      }
      .width('100%')
      .padding({ bottom: PAGE_PADDING })
    }
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .scrollBar(BarState.Off)
  }
}
