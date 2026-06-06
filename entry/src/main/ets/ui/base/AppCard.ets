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
  @State isHovered: boolean = false;
  tapAction?: () => void;
  @BuilderParam content: () => void = EmptyCardBuilder;

  private isInteractive(): boolean {
    return this.interactive || this.tapAction !== undefined;
  }

  private getBackgroundColor(): string {
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
        return this.themeColors.cardBackground;
    }
  }

  private getBorderColor(): string {
    if (this.isInteractive() && this.isFocused) {
      return this.themeColors.primaryLight;
    }
    if (this.isInteractive() && this.isHovered) {
      return this.themeColors.divider;
    }
    switch (this.variant) {
      case 'accent':
        return this.themeColors.primaryLight;
      case 'premium':
        return this.themeColors.premiumBorder;
      case 'danger':
        return this.themeColors.borderColor;
      case 'raised':
        return this.themeColors.divider;
      default:
        return this.themeColors.borderColor;
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
    .focusable(this.isInteractive())
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
      if (this.tapAction) {
        this.tapAction();
      }
    })
  }
}
