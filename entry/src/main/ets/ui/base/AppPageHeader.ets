import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { BORDER_DEFAULT } from '../../foundation/tokens/BorderTokens';
import { ICON_SIZE_SM, ICON_SIZE_XS } from '../../foundation/tokens/IconTokens';
import { RADIUS_PILL, RADIUS_XL } from '../../foundation/tokens/RadiusTokens';
import { PAGE_PADDING, SPACE_2XS, SPACE_SM, SPACE_XS } from '../../foundation/tokens/SpacingTokens';
import { LINE_HEIGHT_TIGHT, TOUCH_TARGET_SM } from '../../foundation/tokens/VisualTokens';
import { TYPE_CAPTION, TYPE_META, TYPE_PAGE_TITLE } from '../../foundation/tokens/TypographyTokens';
import { AppIcon } from './AppIcon';

@Component
export struct AppPageHeader {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop showBack: boolean = true;
  @Prop actionText: string = '';
  @Prop actionIconName: string = '';
  @State backFocused: boolean = false;
  @State backHovered: boolean = false;
  @State actionFocused: boolean = false;
  @State actionHovered: boolean = false;
  onBack?: () => void;
  onAction?: () => void;

  private getBackBackgroundColor(): string {
    if (this.backFocused || this.backHovered) {
      return this.themeColors.surfaceSoft;
    }
    return this.themeColors.surface;
  }

  private getBackBorderColor(): string {
    if (this.backFocused) {
      return this.themeColors.primary;
    }
    if (this.backHovered) {
      return this.themeColors.primaryLight;
    }
    return this.themeColors.borderColor;
  }

  private getActionBackgroundColor(): string {
    if (this.actionFocused || this.actionHovered) {
      return this.themeColors.surface;
    }
    return this.themeColors.primarySubtle;
  }

  private getActionBorderColor(): string {
    if (this.actionFocused) {
      return this.themeColors.primary;
    }
    if (this.actionHovered) {
      return this.themeColors.primaryLight;
    }
    return this.themeColors.primarySubtle;
  }

  build() {
    Row({ space: SPACE_SM }) {
      if (this.showBack) {
        Button() {
          Row() {
            AppIcon({
              name: 'chevron-left',
              iconSize: ICON_SIZE_SM,
              framed: false,
              color: this.themeColors.textPrimary
            })
          }
          .width('100%')
          .height('100%')
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
        .width(TOUCH_TARGET_SM)
        .height(TOUCH_TARGET_SM)
        .backgroundColor(this.getBackBackgroundColor())
        .borderRadius(RADIUS_XL)
        .border({ width: BORDER_DEFAULT, color: this.getBackBorderColor() })
        .stateEffect(true)
        .hoverEffect(HoverEffect.Auto)
        .focusable(true)
        .onFocus(() => {
          this.backFocused = true;
        })
        .onBlur(() => {
          this.backFocused = false;
        })
        .onHover((isHover: boolean) => {
          this.backHovered = isHover;
        })
        .onClick(() => {
          if (this.onBack) {
            this.onBack();
          }
        })
      }

      Column({ space: SPACE_2XS }) {
        Text(this.title)
          .fontSize(TYPE_PAGE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(TYPE_META)
            .lineHeight(LINE_HEIGHT_TIGHT)
            .fontColor(this.themeColors.textSecondary)
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.actionText.length > 0) {
        Button() {
          Row({ space: SPACE_2XS }) {
            if (this.actionIconName.length > 0) {
              AppIcon({
                name: this.actionIconName,
                iconSize: ICON_SIZE_XS,
                framed: false,
                color: this.themeColors.primary
              })
            }
            Text(this.actionText)
              .fontSize(TYPE_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeColors.primary)
              .lineHeight(TOUCH_TARGET_SM)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .height('100%')
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
          .height(TOUCH_TARGET_SM)
          .padding({ left: SPACE_SM, right: SPACE_SM, top: 0, bottom: 0 })
          .backgroundColor(this.getActionBackgroundColor())
          .borderRadius(RADIUS_PILL)
          .border({ width: BORDER_DEFAULT, color: this.getActionBorderColor() })
          .stateEffect(true)
          .hoverEffect(HoverEffect.Auto)
          .focusable(true)
          .onFocus(() => {
            this.actionFocused = true;
          })
          .onBlur(() => {
            this.actionFocused = false;
          })
          .onHover((isHover: boolean) => {
            this.actionHovered = isHover;
          })
          .onClick(() => {
            if (this.onAction) {
              this.onAction();
            }
          })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: PAGE_PADDING, right: PAGE_PADDING, top: SPACE_SM, bottom: SPACE_XS })
  }
}
