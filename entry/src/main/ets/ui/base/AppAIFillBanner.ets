import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { getToneBorderColor, getToneSurfaceColor, getToneTextColor } from '../../theme/ThemeSemantics';
import { BORDER_DEFAULT } from '../../foundation/tokens/BorderTokens';
import { RADIUS_LG, RADIUS_SM } from '../../foundation/tokens/RadiusTokens';
import { SPACE_SM, SPACE_XS } from '../../foundation/tokens/SpacingTokens';
import { TYPE_CAPTION, TYPE_META } from '../../foundation/tokens/TypographyTokens';

export type AppAIFillStatus = 'parsing' | 'filled' | 'failed';

@Component
export struct AppAIFillBanner {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop status: AppAIFillStatus = 'filled';
  @Prop title: string = 'AI 已填入信息';
  @Prop actionText: string = '隐藏提示';
  action?: () => void;

  private getTone(): 'primary' | 'danger' | 'info' {
    if (this.status === 'failed') {
      return 'danger';
    }
    if (this.status === 'parsing') {
      return 'info';
    }
    return 'primary';
  }

  private getIconText(): string {
    if (this.status === 'failed') {
      return '!';
    }
    return 'AI';
  }

  build() {
    Row({ space: SPACE_SM }) {
      Row() {
        if (this.status === 'parsing') {
          LoadingProgress()
            .width(12)
            .height(12)
            .color(this.themeColors.textOnPrimary)
        } else {
          Text(this.getIconText())
            .fontSize(TYPE_CAPTION - 1)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeColors.textOnPrimary)
        }
      }
      .width(24)
      .height(24)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(getToneTextColor(this.themeColors, this.getTone()))
      .borderRadius(RADIUS_SM)

      Text(this.title)
        .fontSize(TYPE_META)
        .fontWeight(FontWeight.Medium)
        .fontColor(getToneTextColor(this.themeColors, this.getTone()))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      Text(this.actionText)
        .fontSize(TYPE_CAPTION)
        .fontColor(this.themeColors.textMuted)
        .padding({ left: SPACE_XS, right: SPACE_XS, top: 4, bottom: 4 })
        .backgroundColor(this.themeColors.surface)
        .borderRadius(RADIUS_SM)
        .onClick(() => {
          if (this.action) {
            this.action();
          }
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor(getToneSurfaceColor(this.themeColors, this.getTone()))
    .borderRadius(RADIUS_LG)
    .border({ width: BORDER_DEFAULT, color: getToneBorderColor(this.themeColors, this.getTone()) + '66' })
  }
}
