import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { RADIUS_XL } from '../../foundation/tokens/RadiusTokens';
import { BORDER_DEFAULT } from '../../foundation/tokens/BorderTokens';
import { ICON_SIZE_SM, ICON_SIZE_XS } from '../../foundation/tokens/IconTokens';
import { BUTTON_HEIGHT_LG, BUTTON_HEIGHT_MD, BUTTON_HEIGHT_SM } from '../../foundation/tokens/PageDensityTokens';
import { DISABLED_OPACITY } from '../../foundation/tokens/VisualTokens';
import { SPACE_CARD, SPACE_MD, SPACE_XS } from '../../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_META } from '../../foundation/tokens/TypographyTokens';
import { AppIcon } from './AppIcon';

export type AppButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'premium';
export type AppButtonSize = 'sm' | 'md' | 'lg';
export type AppButtonEmphasis = 'normal' | 'strong' | 'subtle';

@Component
export struct AppButton {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop text: string = '';
  @Prop variant: AppButtonVariant = 'primary';
  @Prop buttonSize: AppButtonSize = 'md';
  @Prop emphasis: AppButtonEmphasis = 'normal';
  @Prop disabled: boolean = false;
  @Prop loading: boolean = false;
  @Prop iconName: string = '';
  @Prop fullWidth: boolean = false;
  @State isFocused: boolean = false;
  @State isPressed: boolean = false;
  tapAction?: () => void;

  private effectiveVariant(): AppButtonVariant {
    if (this.emphasis === 'strong') return 'primary';
    if (this.emphasis === 'subtle') return 'ghost';
    return this.variant;
  }

  private getBackgroundColor(): string {
    if (this.disabled) {
      return this.themeColors.surfaceSoft;
    }
    const variant = this.effectiveVariant();
    
    if (this.isPressed) {
      switch (variant) {
        case 'primary': return this.themeColors.primaryDark;
        case 'secondary': return this.themeColors.surfacePressed;
        case 'ghost': return this.themeColors.surfacePressed;
        case 'danger': return this.themeColors.dangerSubtle;
        case 'premium': return this.themeColors.premiumBorder;
      }
    }

    switch (variant) {
      case 'primary':
        return this.themeColors.brandPrimary;
      case 'secondary':
        return this.themeColors.brandLight;
      case 'ghost':
        return this.themeColors.transparent;
      case 'danger':
        return this.themeColors.riskSurface;
      case 'premium':
        return this.themeColors.premium;
    }
  }

  private getTextColor(): string {
    if (this.disabled) {
      return this.themeColors.textMuted;
    }
    const variant = this.effectiveVariant();
    switch (variant) {
      case 'primary':
      case 'premium':
        return this.themeColors.textOnPrimary;
      case 'danger':
        return this.themeColors.semanticDanger;
      case 'secondary':
      case 'ghost':
        return this.themeColors.brandPrimary;
      default:
        return this.themeColors.textPrimary;
    }
  }

  private getBorderColor(): string {
    if (this.isFocused) {
      return this.themeColors.brandPrimary;
    }
    return this.themeColors.transparent;
  }

  private getHeight(): number {
    switch (this.buttonSize) {
      case 'sm':
        return BUTTON_HEIGHT_SM;
      case 'lg':
        return BUTTON_HEIGHT_LG;
      default:
        return BUTTON_HEIGHT_MD;
    }
  }

  build() {
    Row({ space: SPACE_XS }) {
      if (this.loading) {
        LoadingProgress()
          .width(ICON_SIZE_SM)
          .height(ICON_SIZE_SM)
          .color(this.getTextColor())
      } else if (this.iconName) {
        AppIcon({
          name: this.iconName,
          iconSize: this.buttonSize === 'sm' ? ICON_SIZE_XS : ICON_SIZE_SM,
          color: this.getTextColor(),
          framed: false
        })
      }

      if (this.text) {
        Text(this.text)
          .fontSize(this.buttonSize === 'sm' ? TYPE_META : TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getTextColor())
      }
    }
    .width(this.fullWidth ? '100%' : undefined)
    .height(this.getHeight())
    .padding({ left: SPACE_MD, right: SPACE_MD })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(RADIUS_XL)
    .border({ width: BORDER_DEFAULT, color: this.getBorderColor() })
    .opacity(this.disabled ? DISABLED_OPACITY : 1)
    .scale({ x: this.isPressed && !this.disabled ? 0.96 : 1, y: this.isPressed && !this.disabled ? 0.96 : 1 })
    .animation({ duration: 100, curve: Curve.Friction })
    .focusable(!this.disabled)
    .onFocus(() => {
      if (!this.disabled) this.isFocused = true;
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
      if (!this.disabled && !this.loading && this.tapAction) {
        this.tapAction();
      }
    })
  }
}
