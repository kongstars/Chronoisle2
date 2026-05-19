import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { type AppTone, getToneBorderColor } from '../../theme/ThemeSemantics';
import { BORDER_DEFAULT } from '../../foundation/tokens/BorderTokens';
import { STATUS_STRIP_HEIGHT, STATUS_STRIP_WIDTH_SM } from '../../foundation/tokens/ComponentSizeTokens';
import { ICON_SIZE_LG } from '../../foundation/tokens/IconTokens';
import { REMINDER_CARD_HEIGHT, REMINDER_CARD_MIN_WIDTH } from '../../foundation/tokens/PageDensityTokens';
import { RADIUS_MD } from '../../foundation/tokens/RadiusTokens';
import { SPACE_MD, SPACE_SM, SPACE_XS } from '../../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_META } from '../../foundation/tokens/TypographyTokens';
import { DISABLED_OPACITY } from '../../foundation/tokens/VisualTokens';
import { AppIcon } from './AppIcon';

@Component
export struct AppReminderCard {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop meta: string = '';
  @Prop tone: AppTone = 'primary';
  @Prop iconName: string = '';
  @Prop disabled: boolean = false;
  @State isFocused: boolean = false;
  @State isHovered: boolean = false;
  tapAction?: () => void;

  private isInteractive(): boolean {
    return !this.disabled && this.tapAction !== undefined;
  }

  private getBackgroundColor(): string {
    if (this.disabled) {
      return this.themeColors.surfaceSoft;
    }
    if (this.isHovered && this.isInteractive()) {
      return this.themeColors.surface;
    }
    return this.themeColors.cardBackground;
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
      Column()
        .width(STATUS_STRIP_WIDTH_SM)
        .height(STATUS_STRIP_HEIGHT)
        .backgroundColor(getToneBorderColor(this.themeColors, this.tone))
        .borderRadius(999)

      if (this.iconName.length > 0) {
        AppIcon({
          name: this.iconName,
          iconSize: ICON_SIZE_LG,
          tone: this.tone
        })
      }

      Column({ space: SPACE_XS }) {
        Text(this.title)
          .fontSize(TYPE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        if (this.meta.length > 0) {
          Text(this.meta)
            .fontSize(TYPE_CAPTION)
            .fontColor(this.themeColors.textMuted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width(REMINDER_CARD_MIN_WIDTH)
    .height(REMINDER_CARD_HEIGHT)
    .alignItems(VerticalAlign.Top)
    .justifyContent(FlexAlign.Start)
    .padding(SPACE_MD)
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(RADIUS_MD)
    .border({ width: BORDER_DEFAULT, color: this.getBorderColor() })
    .opacity(this.disabled ? DISABLED_OPACITY : 1)
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
  }
}
