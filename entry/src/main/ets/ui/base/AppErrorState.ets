import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { AppButton } from './AppButton';
import { AppCard } from './AppCard';
import { AppIcon } from './AppIcon';
import { ICON_SIZE_XL } from '../../foundation/tokens/IconTokens';
import { SPACE_XS } from '../../foundation/tokens/SpacingTokens';
import { TYPE_META, TYPE_SECTION_TITLE } from '../../foundation/tokens/TypographyTokens';
import { LINE_HEIGHT_TIGHT } from '../../foundation/tokens/VisualTokens';

@Component
export struct AppErrorState {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop title: string = '出错了';
  @Prop description: string = '';
  @Prop actionText: string = '';
  @Prop actionIconName: string = 'sync';
  @Prop iconName: string = 'warning';
  onAction?: () => void;

  build() {
    AppCard({ variant: 'soft', spacing: SPACE_XS, paddingLevel: 'md' }) {
      AppIcon({ name: this.iconName, iconSize: ICON_SIZE_XL, tone: 'danger' })
      Text(this.title)
        .fontSize(TYPE_SECTION_TITLE)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.themeColors.textPrimary)
        .width('100%')
      if (this.description.length > 0) {
        Text(this.description)
          .fontSize(TYPE_META)
          .lineHeight(LINE_HEIGHT_TIGHT)
          .fontColor(this.themeColors.textSecondary)
          .width('100%')
      }
      if (this.actionText.length > 0) {
        Row() {
          AppButton({
            text: this.actionText,
            variant: 'secondary',
            buttonSize: 'sm',
            iconName: this.actionIconName,
            tapAction: this.onAction
          })
        }
        .margin({ top: SPACE_XS })
      }
    }
  }
}
