import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { type AppTone, getToneBorderColor, getToneSurfaceColor, getToneTextColor } from '../../theme/ThemeSemantics';
import { BORDER_DEFAULT } from '../../foundation/tokens/BorderTokens';
import { ICON_SIZE_XS } from '../../foundation/tokens/IconTokens';
import { RADIUS_SM } from '../../foundation/tokens/RadiusTokens';
import { SPACE_2XS, SPACE_SM } from '../../foundation/tokens/SpacingTokens';
import { TYPE_META } from '../../foundation/tokens/TypographyTokens';
import { DISABLED_OPACITY } from '../../foundation/tokens/VisualTokens';
import { AppIcon } from './AppIcon';

@Component
export struct AppChip {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop label: string = '';
  @Prop tone: AppTone = 'neutral';
  @Prop active: boolean = false;
  @Prop disabled: boolean = false;
  @Prop iconName: string = '';
  @State isFocused: boolean = false;
  @State isHovered: boolean = false;
  tapAction?: () => void;

  private getBackgroundColor(): string {
    if (this.disabled) {
      return this.themeColors.surfaceSoft;
    }
    if (this.isHovered && !this.active) {
      return this.themeColors.surface;
    }
    return this.active ? getToneSurfaceColor(this.themeColors, this.tone) : this.themeColors.surfaceSoft;
  }

  private getTextColor(): string {
    if (this.disabled) {
      return this.themeColors.textMuted;
    }
    return this.active ? getToneTextColor(this.themeColors, this.tone) : this.themeColors.textSecondary;
  }

  private getBorderColor(): string {
    if (this.isFocused && !this.disabled) {
      return this.themeColors.primaryLight;
    }
    if (this.isHovered && !this.disabled) {
      return this.active ? getToneBorderColor(this.themeColors, this.tone) : this.themeColors.divider;
    }
    return this.active ? getToneBorderColor(this.themeColors, this.tone) : this.themeColors.borderColor;
  }

  build() {
    Row({ space: SPACE_2XS }) {
      if (this.iconName.length > 0) {
        AppIcon({
          name: this.iconName,
          iconSize: ICON_SIZE_XS,
          color: this.getTextColor(),
          framed: false
        })
      }
      Text(this.label)
        .fontSize(TYPE_META)
        .fontWeight(this.active ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.getTextColor())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
      .alignItems(VerticalAlign.Center)
      .padding({ left: SPACE_SM, right: SPACE_SM, top: SPACE_2XS, bottom: SPACE_2XS })
      .backgroundColor(this.getBackgroundColor())
      .borderRadius(RADIUS_SM)
      .border({ width: BORDER_DEFAULT, color: this.getBorderColor() })
      .opacity(this.disabled ? DISABLED_OPACITY : 1)
      .focusable(!this.disabled)
      .onFocus(() => {
        this.isFocused = true;
      })
      .onBlur(() => {
        this.isFocused = false;
      })
      .onHover((isHover: boolean) => {
        this.isHovered = isHover;
      })
      .onClick(() => {
        if (!this.disabled && this.tapAction) {
          this.tapAction();
        }
      })
  }
}
