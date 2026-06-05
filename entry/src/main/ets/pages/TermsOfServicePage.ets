import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppCard } from '../ui/base/AppCard';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { PAGE_PADDING, SECTION_GAP, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';

@Entry
@Component
struct TermsOfServicePage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;

  @Builder
  private Section(title: string, content: string) {
    AppCard({ spacing: SPACE_XS }) {
      Text(title)
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
      Text(content)
        .fontSize(TYPE_BODY)
        .lineHeight(22)
        .fontColor(this.themeColors.textSecondary)
        .width('100%')
    }
  }

  build() {
    Scroll() {
      Column({ space: SECTION_GAP }) {
        AppPageHeader({
          title: '服务条款',
          subtitle: '使用本应用前，请先阅读以下约定',
          onBack: () => this.getUIContext().getRouter().back()
        })

        Column({ space: 16 }) {
          this.Section('功能使用', '你可以在合法合规的前提下使用应用提供的目标管理、任务组织、专注记录、统计分析与会员服务。')
          this.Section('账户责任', '如你注册或登录账号，应妥善保管账户信息，并对账号下发生的操作负责。')
          this.Section('会员服务', '会员权益以页面展示与产品说明为准。购买完成后，权益生效时间与时长将以服务端核验结果为准。')
          this.Section('服务变更', '产品能力可能持续调整，包括页面、配额、价格与会员方案；重大变更将通过产品内说明或版本更新进行告知。')
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: PAGE_PADDING })
      }
      .width('100%')
    }
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .scrollBar(BarState.Off)
  }
}
