import { ThemeColors, LightTheme } from '../theme/AppTheme';
import { AppButton } from '../ui/base/AppButton';
import { AppCard } from '../ui/base/AppCard';
import { SPACE_SM, SPACE_XS } from '../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META, TYPE_SECTION_TITLE } from '../foundation/tokens/TypographyTokens';

@Component
export struct GuideOverlay {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Link showGuide: boolean;
  onComplete?: () => void;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.themeColors.surfaceOverlay)

      AppCard({ variant: 'raised', spacing: SPACE_SM, paddingLevel: 'lg' }) {
        Text('新手引导')
          .fontSize(TYPE_SECTION_TITLE)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeColors.textPrimary)

        Text('核心功能已经准备好，接下来可以直接开始创建目标、任务或提醒。')
          .fontSize(TYPE_META)
          .lineHeight(18)
          .fontColor(this.themeColors.textMuted)
          .width('100%')

        Row() {
          AppButton({
            text: '我知道了',
            variant: 'primary',
            fullWidth: true,
            iconName: 'success',
            tapAction: () => {
              this.showGuide = false;
              if (this.onComplete) {
                this.onComplete();
              }
            }
          })
        }
        .margin({ top: SPACE_XS })
      }
      .width('84%')
      .backgroundColor(this.themeColors.surfaceRaised)
    }
    .width('100%')
    .height('100%')
  }
}
