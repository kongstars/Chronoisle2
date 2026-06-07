import { ICON_SIZE_XL } from '../../foundation/tokens/IconTokens';
import { SPACE_XS } from '../../foundation/tokens/SpacingTokens';
import { TYPE_META, TYPE_SECTION_TITLE } from '../../foundation/tokens/TypographyTokens';
import { LINE_HEIGHT_TIGHT } from '../../foundation/tokens/VisualTokens';
import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { type AppTone } from '../../theme/ThemeSemantics';
import { AppButton } from './AppButton';
import { AppCard } from './AppCard';
import { AppIcon } from './AppIcon';

@Component
export struct AppEmptyState {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop actionText: string = '';
  @Prop actionIconName: string = '';
  @Prop iconName: string = 'info';
  @Prop iconTone: AppTone = 'info';
  onAction?: () => void;

  build() {
    AppCard({ variant: 'soft', spacing: SPACE_XS, paddingLevel: 'md' }) {
      if (this.iconName.length > 0) {
        AppIcon({ name: this.iconName, iconSize: ICON_SIZE_XL, tone: this.iconTone })
      }
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
