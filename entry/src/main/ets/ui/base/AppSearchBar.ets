import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { BORDER_DEFAULT } from '../../foundation/tokens/BorderTokens';
import { ICON_SIZE_SM, ICON_SIZE_XL } from '../../foundation/tokens/IconTokens';
import { SEARCH_BAR_BADGE_HEIGHT, SEARCH_BAR_HEIGHT } from '../../foundation/tokens/PageDensityTokens';
import { RADIUS_PILL, RADIUS_XL } from '../../foundation/tokens/RadiusTokens';
import { PAGE_PADDING, SPACE_MD, SPACE_SM } from '../../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_CAPTION } from '../../foundation/tokens/TypographyTokens';
import { DISABLED_OPACITY } from '../../foundation/tokens/VisualTokens';
import { AppIcon } from './AppIcon';

@Component
export struct AppSearchBar {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop placeholder: string = '';
  @Prop badgeText: string = '';
  @Prop value: string = '';
  @Prop editable: boolean = false;
  @Prop clearable: boolean = false;
  @Prop disabled: boolean = false;
  @Prop insetHorizontal: number = PAGE_PADDING;
  @State isFocused: boolean = false;
  @State isHovered: boolean = false;
  tapAction?: () => void;
  onChange?: (value: string) => void;
  onClear?: () => void;

  private isInteractive(): boolean {
    return !this.disabled && (this.editable || this.tapAction !== undefined);
  }

  private getBackgroundColor(): string {
    if (this.disabled) {
      return this.themeColors.surfaceSoft;
    }
    if (this.isHovered && this.isInteractive()) {
      return this.themeColors.surface;
    }
    return this.themeColors.inputBackground;
  }

  private getBorderColor(): string {
    if (this.disabled) {
      return this.themeColors.borderColor;
    }
    if (this.isFocused) {
      return this.themeColors.primary;
    }
    if (this.isHovered && this.isInteractive()) {
      return this.themeColors.primaryLight;
    }
    return this.themeColors.borderColor;
  }

  build() {
    Row({ space: SPACE_SM }) {
      AppIcon({
        name: 'search',
        iconSize: ICON_SIZE_SM,
        framed: false,
        color: this.themeColors.textMuted
      })

      if (this.editable) {
        TextInput({ placeholder: this.placeholder, text: this.value })
          .layoutWeight(1)
          .height(SEARCH_BAR_HEIGHT - SPACE_MD)
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textPrimary)
          .backgroundColor(this.themeColors.transparent)
          .placeholderColor(this.themeColors.textSecondary)
          .padding({ top: 0, bottom: 0 })
          .enabled(!this.disabled)
          .focusable(!this.disabled)
          .onFocus(() => {
            this.isFocused = true;
          })
          .onBlur(() => {
            this.isFocused = false;
          })
          .onChange((value: string) => {
            if (!this.disabled && this.onChange) {
              this.onChange(value);
            }
          })
      } else {
        Text(this.placeholder)
          .fontSize(TYPE_BODY)
          .fontColor(this.themeColors.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }

      if (this.editable && this.clearable && this.value.trim().length > 0) {
        Button() {
          Row() {
            AppIcon({
              name: 'close',
              iconSize: ICON_SIZE_SM,
              framed: false,
              color: this.themeColors.textMuted
            })
          }
          .width('100%')
          .height('100%')
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .width(ICON_SIZE_XL)
        .height(ICON_SIZE_XL)
        .padding({ left: 0, right: 0, top: 0, bottom: 0 })
        .backgroundColor(this.themeColors.transparent)
        .enabled(!this.disabled)
        .stateEffect(!this.disabled)
        .hoverEffect(HoverEffect.Auto)
        .focusable(!this.disabled)
        .onClick(() => {
          if (this.disabled) {
            return;
          }
          if (this.onClear) {
            this.onClear();
          } else if (this.onChange) {
            this.onChange('');
          }
        })
      }

      if (this.badgeText.length > 0) {
        Text(this.badgeText)
          .fontSize(TYPE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.primary)
          .height(SEARCH_BAR_BADGE_HEIGHT)
          .lineHeight(SEARCH_BAR_BADGE_HEIGHT)
          .padding({ left: SPACE_SM, right: SPACE_SM })
          .backgroundColor(this.themeColors.primarySubtle)
          .borderRadius(RADIUS_PILL)
      }
    }
    .width('100%')
    .height(SEARCH_BAR_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .padding({ left: SPACE_MD, right: SPACE_MD })
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(RADIUS_XL)
    .border({ width: BORDER_DEFAULT, color: this.getBorderColor() })
    .margin({ left: this.insetHorizontal, right: this.insetHorizontal })
    .opacity(this.disabled ? DISABLED_OPACITY : 1)
    .focusable(!this.editable && this.isInteractive())
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
      if (!this.disabled && !this.editable && this.tapAction) {
        this.tapAction();
      }
    })
  }
}
