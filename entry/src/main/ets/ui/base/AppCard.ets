import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { RADIUS_LG } from '../../foundation/tokens/RadiusTokens';
import { BORDER_DEFAULT } from '../../foundation/tokens/BorderTokens';
import { getCardShadow, getRaisedCardShadow } from '../../foundation/tokens/ElevationTokens';
import { SPACE_CARD, SPACE_MD, SPACE_SM } from '../../foundation/tokens/SpacingTokens';

export type AppCardVariant = 'base' | 'soft' | 'accent' | 'premium' | 'danger' | 'raised';
export type AppCardPadding = 'sm' | 'md' | 'lg';

@Builder
function EmptyCardBuilder() {
}

@Component
export struct AppCard {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop variant: AppCardVariant = 'base';
  @Prop paddingLevel: AppCardPadding = 'lg';
  @Prop spacing: number = SPACE_SM;
  @Prop interactive: boolean = false;
  @State isFocused: boolean = false;
  @State isPressed: boolean = false;
  tapAction?: () => void;
  @BuilderParam content: () => void = EmptyCardBuilder;

  private isInteractive(): boolean {
    return this.interactive || this.tapAction !== undefined;
  }

  private getBackgroundColor(): string {
    if (this.isPressed && this.isInteractive()) {
      return this.themeColors.surfacePressed;
    }
    switch (this.variant) {
      case 'soft':
        return this.themeColors.surfaceSoft;
      case 'raised':
        return this.themeColors.surfaceRaised;
      case 'accent':
        return this.themeColors.announcementSurface;
      case 'premium':
        return this.themeColors.premiumSurface;
      case 'danger':
        return this.themeColors.riskSurface;
      default:
        return this.themeColors.surfaceBase;
    }
  }

  private getBorderColor(): string {
    if (this.isInteractive() && this.isFocused) {
      return this.themeColors.primaryLight;
    }
    switch (this.variant) {
      case 'accent':
        return this.themeColors.primaryLight;
      case 'premium':
        return this.themeColors.premiumBorder;
      case 'danger':
        return this.themeColors.borderColor;
      case 'raised':
        return this.themeColors.borderLight;
      default:
        return this.themeColors.borderLight;
    }
  }

  private getPadding(): number {
    switch (this.paddingLevel) {
      case 'sm':
        return SPACE_SM;
      case 'md':
        return SPACE_MD;
      default:
        return SPACE_CARD;
    }
  }

  build() {
    Column({ space: this.spacing }) {
      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(this.getPadding())
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(RADIUS_LG)
    .border({ width: BORDER_DEFAULT, color: this.getBorderColor() })
    .shadow(this.variant === 'raised' ? getRaisedCardShadow(this.themeColors) : getCardShadow(this.themeColors))
    .scale({ x: this.isPressed && this.isInteractive() ? 0.98 : 1, y: this.isPressed && this.isInteractive() ? 0.98 : 1 })
    .animation({ duration: 100, curve: Curve.Friction })
    .focusable(this.isInteractive())
    .onFocus(() => {
      this.isFocused = true;
    })
    .onBlur(() => {
      this.isFocused = false;
    })
    .onTouch((event: TouchEvent) => {
      if (this.isInteractive()) {
        if (event.type === TouchType.Down) {
          this.isPressed = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.isPressed = false;
        }
      }
    })
    .onClick(() => {
      if (this.tapAction) {
        this.tapAction();
      }
    })
  }
}
