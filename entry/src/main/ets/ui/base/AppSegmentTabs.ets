import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { BORDER_DEFAULT } from '../../foundation/tokens/BorderTokens';
import { RADIUS_LG, RADIUS_SM } from '../../foundation/tokens/RadiusTokens';
import { SPACE_2XS } from '../../foundation/tokens/SpacingTokens';
import { TYPE_META } from '../../foundation/tokens/TypographyTokens';
import { DISABLED_OPACITY, TOUCH_TARGET_SM } from '../../foundation/tokens/VisualTokens';

@Component
export struct AppSegmentTabs {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop tabs: string[] = [];
  @Prop selectedIndex: number = 0;
  @Prop disabled: boolean = false;
  @State hoveredIndex: number = -1;
  @State focusedIndex: number = -1;
  onSelect?: (index: number) => void;

  private isSelected(index: number): boolean {
    return index === this.selectedIndex;
  }

  private isFocused(index: number): boolean {
    return index === this.focusedIndex;
  }

  private isHovered(index: number): boolean {
    return index === this.hoveredIndex;
  }

  private getTabBackgroundColor(index: number): string {
    if (this.isSelected(index)) {
      return this.themeColors.surface;
    }
    if (!this.disabled && this.isHovered(index)) {
      return this.themeColors.surfaceSoft;
    }
    return this.themeColors.transparent;
  }

  private getTabTextColor(index: number): string {
    if (this.disabled) {
      return this.themeColors.textMuted;
    }
    return this.isSelected(index) ? this.themeColors.primary : this.themeColors.textSecondary;
  }

  private getTabBorderColor(index: number): string {
    if (this.disabled) {
      return this.themeColors.transparent;
    }
    if (this.isFocused(index)) {
      return this.themeColors.primaryLight;
    }
    return this.themeColors.transparent;
  }

  build() {
    Row({ space: SPACE_2XS }) {
      ForEach(this.tabs, (tab: string, index: number) => {
        Row() {
          Text(tab)
            .fontSize(TYPE_META)
            .fontWeight(this.isSelected(index) ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.getTabTextColor(index))
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .height(TOUCH_TARGET_SM)
        .backgroundColor(this.getTabBackgroundColor(index))
        .borderRadius(RADIUS_SM)
        .border({ width: BORDER_DEFAULT, color: this.getTabBorderColor(index) })
        .focusable(!this.disabled)
        .onFocus(() => {
          this.focusedIndex = index;
        })
        .onBlur(() => {
          if (this.focusedIndex === index) {
            this.focusedIndex = -1;
          }
        })
        .onHover((isHover: boolean) => {
          this.hoveredIndex = isHover ? index : -1;
        })
        .onClick(() => {
          if (!this.disabled && this.onSelect) {
            this.onSelect(index);
          }
        })
      })
    }
    .width('100%')
    .padding(SPACE_2XS)
    .backgroundColor(this.themeColors.surfaceSoft)
    .borderRadius(RADIUS_LG)
    .border({ width: BORDER_DEFAULT, color: this.themeColors.borderColor })
    .opacity(this.disabled ? DISABLED_OPACITY : 1)
  }
}
