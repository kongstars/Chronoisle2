import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppCard } from '../ui/base/AppCard';
import { AppListRow } from '../ui/base/AppListRow';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { PAGE_PADDING, SECTION_GAP, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { ComplianceInfo } from '../common/ComplianceInfo';
import BuildProfile from 'BuildProfile';

interface BeianRow {
  label: string;
  value: string;
}

@Entry
@Component
struct AboutPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;

  private buildBeianRows(): BeianRow[] {
    const rows: BeianRow[] = [];
    if (!ComplianceInfo.isPlaceholder(ComplianceInfo.OPERATOR_NAME)) {
      rows.push({ label: '运营主体', value: ComplianceInfo.OPERATOR_NAME });
    }
    if (!ComplianceInfo.isPlaceholder(ComplianceInfo.ICP_BEIAN_NO)) {
      rows.push({ label: 'ICP 备案号', value: ComplianceInfo.ICP_BEIAN_NO });
    }
    if (!ComplianceInfo.isPlaceholder(ComplianceInfo.POLICE_BEIAN_NO)) {
      rows.push({ label: '公安备案号', value: ComplianceInfo.POLICE_BEIAN_NO });
    }
    if (!ComplianceInfo.isPlaceholder(ComplianceInfo.APP_BEIAN_NO)) {
      rows.push({ label: '移动应用备案号', value: ComplianceInfo.APP_BEIAN_NO });
    }
    if (!ComplianceInfo.isPlaceholder(ComplianceInfo.ALGORITHM_BEIAN_NO)) {
      rows.push({ label: '算法备案号', value: ComplianceInfo.ALGORITHM_BEIAN_NO });
    }
    if (!ComplianceInfo.isPlaceholder(ComplianceInfo.COPYRIGHT_REG_NO)) {
      rows.push({ label: '软件著作权', value: ComplianceInfo.COPYRIGHT_REG_NO });
    }
    return rows;
  }

  private buildContactRows(): BeianRow[] {
    const rows: BeianRow[] = [];
    if (!ComplianceInfo.isPlaceholder(ComplianceInfo.CUSTOMER_SERVICE_EMAIL)) {
      rows.push({ label: '客服邮箱', value: ComplianceInfo.CUSTOMER_SERVICE_EMAIL });
    }
    if (ComplianceInfo.CUSTOMER_SERVICE_PHONE && ComplianceInfo.CUSTOMER_SERVICE_PHONE.length > 0) {
      rows.push({ label: '客服电话', value: ComplianceInfo.CUSTOMER_SERVICE_PHONE });
    }
    if (!ComplianceInfo.isPlaceholder(ComplianceInfo.OPERATOR_ADDRESS)) {
      rows.push({ label: '联系地址', value: ComplianceInfo.OPERATOR_ADDRESS });
    }
    return rows;
  }

  @Builder
  private SectionCard(title: string, content: string) {
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

  @Builder
  private InfoRow(item: BeianRow) {
    Row() {
      Text(item.label)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textMuted)
      Blank()
      Text(item.value)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textPrimary)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  build() {
    Scroll() {
      Column({ space: SECTION_GAP }) {
        AppPageHeader({
          title: '关于四时清单',
          subtitle: '目标、任务、提醒与专注的统一行动界面',
          onBack: () => this.getUIContext().getRouter().back()
        })

        Column({ space: 16 }) {
          this.SectionCard('产品定位', '四时清单围绕目标、任务、提醒、今日计划与专注组织你的日常行动，让长期目标可以被拆成可执行的安排。')
          this.SectionCard('当前能力', '你可以创建目标、拆分行动、管理提醒、生成今日计划、记录番茄专注，并在统计与会员模块查看配额和使用情况。')
          this.SectionCard('技术说明', '四时清单基于 HarmonyOS NEXT 原生开发，使用 ArkTS + ArkUI 构建，支持亮暗色双模式。')

          AppCard({ spacing: SPACE_SM }) {
            Text('合规与备案')
              .fontSize(TYPE_SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
              .width('100%')

            if (this.buildBeianRows().length === 0) {
              Text('备案信息将在上线前补齐。')
                .fontSize(TYPE_BODY)
                .fontColor(this.themeColors.textSecondary)
                .width('100%')
            } else {
              ForEach(this.buildBeianRows(), (item: BeianRow) => {
                this.InfoRow(item)
              }, (item: BeianRow) => item.label)
            }
          }

          AppCard({ spacing: SPACE_SM }) {
            Text('联系我们')
              .fontSize(TYPE_SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
              .width('100%')
            if (this.buildContactRows().length === 0) {
              Text('联系方式将在上线前补齐。')
                .fontSize(TYPE_BODY)
                .fontColor(this.themeColors.textSecondary)
                .width('100%')
            } else {
              ForEach(this.buildContactRows(), (item: BeianRow) => {
                this.InfoRow(item)
              }, (item: BeianRow) => item.label)
            }
          }

          AppCard({ spacing: 0 }) {
            Text('政策与算法')
              .fontSize(TYPE_SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
              .width('100%')
              .margin({ bottom: SPACE_XS })

            AppListRow({
              leadingIcon: 'info',
              title: '隐私政策',
              subtitle: '我们如何收集、使用、保护您的信息',
              showDivider: true,
              tapAction: () => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/PrivacyPolicyPage' });
              }
            })
            AppListRow({
              leadingIcon: 'note',
              title: '用户协议',
              subtitle: '使用本服务前请阅读完整协议',
              showDivider: true,
              tapAction: () => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/TermsOfServicePage' });
              }
            })
            AppListRow({
              leadingIcon: 'gear',
              title: '算法说明',
              subtitle: '了解 AI 计划、AI 重排和语音识别如何工作',
              showDivider: false,
              tapAction: () => {
                this.getUIContext().getRouter().pushUrl({ url: 'pages/AlgorithmDisclosurePage' });
              }
            })
          }

          Text(`Version ${BuildProfile.VERSION_NAME}`)
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textMuted)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 4, bottom: PAGE_PADDING })
        }
        .width('100%')
        .padding({ left: PAGE_PADDING, right: PAGE_PADDING })
      }
      .width('100%')
      .padding({ bottom: PAGE_PADDING })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
    .scrollBar(BarState.Off)
  }
}
