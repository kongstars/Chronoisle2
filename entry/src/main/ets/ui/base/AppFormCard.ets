import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { RADIUS_LG } from '../../foundation/tokens/RadiusTokens';
import { BORDER_DEFAULT } from '../../foundation/tokens/BorderTokens';
import { getCardShadow } from '../../foundation/tokens/ElevationTokens';
import { SPACE_CARD, SPACE_MD, SPACE_SM } from '../../foundation/tokens/SpacingTokens';

/**
 * 表单卡片：专门用于包含 TextInput / TextArea 的场景。
 * 不注册任何 onClick / focusable / gesture，避免拦截子组件的触摸事件。
 */

export type AppFormCardVariant = 'base' | 'soft';
export type AppFormCardPadding = 'sm' | 'md' | 'lg';

@Builder
function EmptyFormCardBuilder() {
}

@Component
export struct AppFormCard {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop variant: AppFormCardVariant = 'base';
  @Prop paddingLevel: AppFormCardPadding = 'lg';
  @Prop spacing: number = SPACE_SM;
  @BuilderParam content: () => void = EmptyFormCardBuilder;

  private getBackgroundColor(): string {
    return this.variant === 'soft' ? this.themeColors.surfaceSoft : this.themeColors.cardBackground;
  }

  private getPadding(): number {
    switch (this.paddingLevel) {
      case 'sm': return SPACE_SM;
      case 'md': return SPACE_MD;
      default: return SPACE_CARD;
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
    .border({ width: BORDER_DEFAULT, color: this.themeColors.borderColor })
    .shadow(getCardShadow(this.themeColors))
  }
}
