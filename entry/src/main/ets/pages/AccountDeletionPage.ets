import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { AppPageHeader } from '../ui/base/AppPageHeader';
import { PAGE_PADDING, SECTION_GAP, SPACE_MD, SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';
import { AccountDeletionService } from '../services/AccountDeletionService';

/**
 * 账号注销页
 *
 * 上架合规要求：
 * 1. 必须有清晰可达的入口（已接入 UserPage）。
 * 2. 必须有显著告知：注销影响、宽限期、订阅退订等。
 * 3. 必须二次确认。
 * 4. 提交后清理本地状态并提示用户。
 *
 * 当前版本：服务端 /api/auth/account/delete 端点尚未在生产上线（见上架任务清单 D2）。
 * 客户端按最终接口约定提交请求，若服务端未启用会得到接口错误，UI 会提示并记录日志。
 */
@Entry
@Component
struct AccountDeletionPage {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @State reason: string = '';
  @State agreed: boolean = false;
  @State submitting: boolean = false;

  private static readonly DELETION_NOTICE: string[] = [
    '注销账号是不可逆操作，请认真阅读以下条款后再继续。',
    '提交申请后您的账号会进入 7 天注销宽限期，期间您可以重新登录撤销注销。',
    '宽限期结束后，我们会按隐私政策清理或匿名化您的业务数据，并不可恢复。',
    '若您当前持有自动续费订阅，请先在华为应用市场取消订阅，避免续费产生费用。',
    '已使用的积分、会员权益、AI 历史记录等都不可继续使用或恢复。'
  ];

  private async handleSubmit(): Promise<void> {
    if (!this.agreed) {
      this.getUIContext().getPromptAction().showToast({ message: '请先确认已阅读并同意注销影响' });
      return;
    }

    const dialogResult = await this.getUIContext().getPromptAction().showDialog({
      title: '确认注销账号',
      message: '注销账号是不可逆操作，确认要继续吗？',
      buttons: [
        { text: '我再想想', color: '#888888' },
        { text: '确认注销', color: '#D04848' }
      ]
    });

    if (dialogResult.index !== 1) {
      return;
    }

    this.submitting = true;
    try {
      const result = await AccountDeletionService.submitDeletion(this.reason);
      if (!result.success) {
        this.getUIContext().getPromptAction().showToast({ message: result.message });
        return;
      }
      this.getUIContext().getPromptAction().showToast({ message: '注销申请已提交，您已退出登录' });
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/MainPage' });
    } finally {
      this.submitting = false;
    }
  }

  build() {
    Scroll() {
      Column({ space: SECTION_GAP }) {
        AppPageHeader({
          title: '注销账号',
          subtitle: '我们尊重您对账号去留的选择',
          onBack: () => this.getUIContext().getRouter().back()
        })

        Column({ space: SECTION_GAP }) {
          AppCard({ spacing: SPACE_SM }) {
            Text('您即将注销以下账号')
              .fontSize(TYPE_SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
              .width('100%')
            Text('注销后无法登录、无法找回数据，请确认操作前已完成必要的备份。')
              .fontSize(TYPE_BODY)
              .lineHeight(22)
              .fontColor(this.themeColors.textSecondary)
              .width('100%')
            Text('如果您只是想换设备登录或暂时离开，您可以直接退出登录，无需注销账号。')
              .fontSize(TYPE_META)
              .lineHeight(20)
              .fontColor(this.themeColors.textMuted)
              .width('100%')
          }

          AppCard({ spacing: SPACE_SM }) {
            Text('注销影响')
              .fontSize(TYPE_SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
              .width('100%')
            ForEach(AccountDeletionPage.DELETION_NOTICE, (item: string) => {
              Row({ space: SPACE_XS }) {
                Text('•')
                  .fontSize(TYPE_BODY)
                  .fontColor(this.themeColors.textMuted)
                Text(item)
                  .fontSize(TYPE_BODY)
                  .lineHeight(22)
                  .fontColor(this.themeColors.textSecondary)
                  .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
            }, (item: string) => item)
          }

          AppCard({ spacing: SPACE_SM }) {
            Text('注销原因（可选）')
              .fontSize(TYPE_SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.textPrimary)
              .width('100%')
            Text('我们想了解您离开的原因，便于改进产品。')
              .fontSize(TYPE_META)
              .fontColor(this.themeColors.textMuted)
              .width('100%')
            TextArea({ placeholder: '简短描述（不超过 200 字）', text: this.reason })
              .fontSize(TYPE_BODY)
              .height(120)
              .placeholderColor(this.themeColors.textMuted)
              .fontColor(this.themeColors.textPrimary)
              .backgroundColor(this.themeColors.surfaceSoft)
              .borderRadius(12)
              .padding(SPACE_MD)
              .maxLength(200)
              .onChange((value: string) => {
                this.reason = value;
              })
          }

          AppCard({ spacing: SPACE_SM }) {
            Row({ space: SPACE_SM }) {
              Toggle({ type: ToggleType.Checkbox, isOn: this.agreed })
                .onChange((isOn: boolean) => {
                  this.agreed = isOn;
                })
              Text('我已阅读并同意上述注销影响，且了解注销操作不可逆')
                .fontSize(TYPE_BODY)
                .lineHeight(20)
                .fontColor(this.themeColors.textPrimary)
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }

          AppButton({
            text: this.submitting ? '提交中...' : '提交注销申请',
            variant: 'danger',
            iconName: 'warning',
            disabled: !this.agreed || this.submitting,
            tapAction: () => { this.handleSubmit(); }
          })

          Text('如有任何疑问，欢迎通过「关于」页中的客服邮箱联系我们。')
            .fontSize(TYPE_META)
            .lineHeight(18)
            .fontColor(this.themeColors.textMuted)
            .width('100%')
            .textAlign(TextAlign.Center)
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
