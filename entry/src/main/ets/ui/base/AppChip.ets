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
  @State isPressed: boolean = false;
  tapAction?: () => void;

  private getBackgroundColor(): string {
    if (this.disabled) {
      return this.themeColors.surfaceSoft;
    }
    if (this.isPressed) {
      return this.themeColors.surfacePressed;
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
    if (this.isFocused) {
      return this.themeColors.brandPrimary;
    }
    return this.active ? getToneBorderColor(this.themeColors, this.tone) : this.themeColors.transparent;
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
      .scale({ x: this.isPressed && !this.disabled ? 0.96 : 1, y: this.isPressed && !this.disabled ? 0.96 : 1 })
      .animation({ duration: 100, curve: Curve.Friction })
      .opacity(this.disabled ? DISABLED_OPACITY : 1)
      .focusable(!this.disabled)
      .onFocus(() => {
        this.isFocused = true;
      })
      .onBlur(() => {
        this.isFocused = false;
      })
      .onTouch((event: TouchEvent) => {
        if (!this.disabled) {
          if (event.type === TouchType.Down) {
            this.isPressed = true;
          } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
            this.isPressed = false;
          }
        }
      })
      .onClick(() => {
        if (!this.disabled && this.tapAction) {
          this.tapAction();
        }
      })
  }
}
