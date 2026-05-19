import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppCard } from '../ui/base/AppCard';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { PAGE_PADDING, SECTION_GAP, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';

@Entry
@Component
struct PrivacyPolicyPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;

  @Builder
  private Clause(title: string, content: string) {
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
          title: '隐私政策',
          subtitle: '说明应用如何收集、使用与保护你的信息',
          onBack: () => this.getUIContext().getRouter().back()
        })

        Column({ space: 16 }) {
          this.Clause('收集的信息', '应用会保存你主动创建的目标、任务、提醒、专注记录与账户信息，用于在不同页面中展示与同步。')
          this.Clause('使用方式', '这些信息仅用于提供目标规划、今日计划、统计分析、会员权益和云端同步等核心功能。')
          this.Clause('信息保护', '本地数据存储在设备侧；如你登录并启用云端能力，必要数据会发送到服务端用于账号识别、配额校验和功能同步。')
          this.Clause('你的选择', '你可以随时修改、删除本地数据，并根据产品后续提供的入口申请查看或清除云端账户信息。')
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING, bottom: PAGE_PADDING })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .scrollBar(BarState.Off)
  }
}
