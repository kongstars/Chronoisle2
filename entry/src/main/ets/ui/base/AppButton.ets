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
  tapAction?: () => void;

  private effectiveVariant(): AppButtonVariant {
    if (this.emphasis === 'strong') return 'primary';
    if (this.emphasis === 'subtle') return 'ghost';
    return this.variant;
  }

  private effectiveSize(): AppButtonSize {
    if (this.emphasis === 'strong') return 'lg';
    if (this.emphasis === 'subtle') return 'sm';
    return this.buttonSize;
  }

  private isEnabled(): boolean {
    return !this.disabled && !this.loading;
  }

  private getHeight(): number {
    switch (this.effectiveSize()) {
      case 'sm':
        return BUTTON_HEIGHT_SM;
      case 'lg':
        return BUTTON_HEIGHT_LG;
      default:
        return BUTTON_HEIGHT_MD;
    }
  }

  private getFontSize(): number {
    return this.effectiveSize() === 'sm' ? TYPE_META : TYPE_BODY;
  }

  private getIconSize(): number {
    if (this.text.length === 0 && this.iconName.length > 0) {
      return ICON_SIZE_SM;
    }
    return this.effectiveSize() === 'sm' ? ICON_SIZE_XS : ICON_SIZE_SM;
  }

  private getPadding(): Padding {
    if (this.text.length === 0 && this.iconName.length > 0) {
      return { left: 0, right: 0, top: 0, bottom: 0 };
    }
    return {
      left: this.effectiveSize() === 'sm' ? SPACE_MD : SPACE_CARD,
      right: this.effectiveSize() === 'sm' ? SPACE_MD : SPACE_CARD,
      top: 0,
      bottom: 0
    };
  }

  private getBackgroundColor(): string {
    if (!this.isEnabled()) {
      return this.themeColors.surfaceSoft;
    }
    switch (this.effectiveVariant()) {
      case 'secondary':
        return this.themeColors.surface;
      case 'ghost':
        return this.themeColors.transparent;
      case 'danger':
        return this.themeColors.danger;
      case 'premium':
        return this.themeColors.premium;
      default:
        return this.themeColors.primary;
    }
  }

  private getTextColor(): string {
    if (!this.isEnabled()) {
      return this.themeColors.textMuted;
    }
    switch (this.effectiveVariant()) {
      case 'secondary':
      case 'ghost':
        return this.themeColors.textPrimary;
      case 'premium':
        return this.themeColors.premiumText;
      default:
        return this.themeColors.textOnPrimary;
    }
  }

  private getBorderWidth(): number {
    if (this.isFocused && this.isEnabled()) {
      return BORDER_DEFAULT;
    }
    return this.effectiveVariant() === 'secondary' ? BORDER_DEFAULT : 0;
  }

  private getBorderColor(): string {
    if (this.isFocused && this.isEnabled()) {
      return this.effectiveVariant() === 'primary' ? this.themeColors.primaryLight : this.themeColors.primary;
    }
    return this.effectiveVariant() === 'secondary' ? this.themeColors.borderColor : this.themeColors.transparent;
  }

  build() {
    Button() {
      Row() {
        if (this.loading) {
          LoadingProgress()
            .width(ICON_SIZE_XS)
            .height(ICON_SIZE_XS)
            .color(this.getTextColor())
        } else if (this.iconName.length > 0) {
          AppIcon({
            name: this.iconName,
            iconSize: this.getIconSize(),
            color: this.getTextColor(),
            framed: false,
            muted: !this.isEnabled()
          })
        }
        if (this.loading || (this.iconName.length > 0 && this.text.length > 0)) {
          Blank().width(SPACE_XS)
        }
        if (this.loading || this.text.length > 0) {
          Text(this.loading ? '加载中...' : this.text)
            .fontSize(this.getFontSize())
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getTextColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)
      .height(this.getHeight())
    }
    .width(this.fullWidth ? '100%' : undefined)
    .height(this.getHeight())
    .padding(this.getPadding())
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(RADIUS_XL)
    .border({ width: this.getBorderWidth(), color: this.getBorderColor() })
    .opacity(this.isEnabled() ? 1 : DISABLED_OPACITY)
    .enabled(this.isEnabled())
    .stateEffect(this.isEnabled())
    .hoverEffect(HoverEffect.Auto)
    .focusable(this.isEnabled())
    .onFocus(() => {
      this.isFocused = true;
    })
    .onBlur(() => {
      this.isFocused = false;
    })
    .onClick(() => {
      if (this.tapAction) {
        this.tapAction();
      }
    })
  }
}
