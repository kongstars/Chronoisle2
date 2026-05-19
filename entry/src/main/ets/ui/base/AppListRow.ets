import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { BORDER_SUBTLE } from '../../foundation/tokens/BorderTokens';
import { ICON_SIZE_LG, ICON_SIZE_SM, ICON_SIZE_XL, ICON_SIZE_XS } from '../../foundation/tokens/IconTokens';
import { RADIUS_MD } from '../../foundation/tokens/RadiusTokens';
import { SPACE_SM, SPACE_XS } from '../../foundation/tokens/SpacingTokens';
import { DISABLED_OPACITY, LINE_HEIGHT_TIGHT, MUTED_CONTENT_OPACITY, TOUCH_TARGET_LG } from '../../foundation/tokens/VisualTokens';
import { TYPE_BODY, TYPE_META } from '../../foundation/tokens/TypographyTokens';
import { AppIcon } from './AppIcon';

@Component
export struct AppListRow {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop leadingText: string = '';
  @Prop leadingIcon: string = '';
  @Prop trailingText: string = '';
  @Prop tone: 'default' | 'primary' | 'danger' = 'default';
  @Prop showDivider: boolean = false;
  @Prop showChevron: boolean = true;
  @Prop completed: boolean = false;
  @Prop disabled: boolean = false;
  @State isFocused: boolean = false;
  @State isHovered: boolean = false;
  tapAction?: () => void;

  private isInteractive(): boolean {
    return !this.disabled && this.tapAction !== undefined;
  }

  private getTrailingColor(): string {
    switch (this.tone) {
      case 'primary':
        return this.themeColors.primary;
      case 'danger':
        return this.themeColors.danger;
      default:
        return this.themeColors.textMuted;
    }
  }

  private getRowBackgroundColor(): string {
    if (!this.isInteractive()) {
      return this.themeColors.transparent;
    }
    if (this.isFocused) {
      return this.themeColors.primarySubtle;
    }
    if (this.isHovered) {
      return this.themeColors.surfaceSoft;
    }
    return this.themeColors.transparent;
  }

  private getRowOpacity(): number {
    if (this.disabled) {
      return DISABLED_OPACITY;
    }
    return this.completed ? MUTED_CONTENT_OPACITY : 1;
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: SPACE_SM }) {
        if (this.leadingIcon.length > 0) {
          Row() {
            AppIcon({ name: this.leadingIcon, iconSize: ICON_SIZE_LG })
          }
          .width(ICON_SIZE_XL)
          .justifyContent(FlexAlign.Center)
        } else if (this.leadingText.length > 0) {
          Text(this.leadingText)
            .fontSize(ICON_SIZE_SM)
            .width(ICON_SIZE_XL)
            .textAlign(TextAlign.Center)
        }

        Column({ space: SPACE_XS }) {
          Text(this.title)
            .fontSize(TYPE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .width('100%')
            .lineHeight(LINE_HEIGHT_TIGHT)
            .maxLines(2)
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

        if (this.trailingText.length > 0) {
          Text(this.trailingText)
            .fontSize(TYPE_META)
            .fontColor(this.getTrailingColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        if (this.showChevron) {
          AppIcon({
            name: 'chevron-right',
            iconSize: ICON_SIZE_XS,
            framed: false,
            color: this.themeColors.textMuted
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 0, right: 0, top: SPACE_XS, bottom: SPACE_XS })
      .constraintSize({ minHeight: TOUCH_TARGET_LG })
      .backgroundColor(this.getRowBackgroundColor())
      .borderRadius(RADIUS_MD)
      .border({ width: BORDER_SUBTLE, color: this.isFocused && this.isInteractive() ? this.themeColors.primary : this.themeColors.transparent })
      .opacity(this.getRowOpacity())
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
        if (this.isInteractive() && this.tapAction) {
          this.tapAction();
        }
      })

      if (this.showDivider) {
        Divider()
          .strokeWidth(BORDER_SUBTLE)
          .color(this.themeColors.divider)
          .margin({ left: ICON_SIZE_XL + SPACE_SM })
      }
    }
    .width('100%')
  }
}
