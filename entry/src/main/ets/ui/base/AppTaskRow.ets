import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { BORDER_DEFAULT } from '../../foundation/tokens/BorderTokens';
import { CHECKBOX_SIZE_SM } from '../../foundation/tokens/ComponentSizeTokens';
import { RADIUS_LG } from '../../foundation/tokens/RadiusTokens';
import { SPACE_2XS, SPACE_SM, SPACE_XS } from '../../foundation/tokens/SpacingTokens';
import { DISABLED_OPACITY, MUTED_CONTENT_OPACITY } from '../../foundation/tokens/VisualTokens';
import { TYPE_BODY, TYPE_META } from '../../foundation/tokens/TypographyTokens';
import { ICON_SIZE_XS } from '../../foundation/tokens/IconTokens';
import { AppIcon } from './AppIcon';

@Component
export struct AppTaskRow {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop completed: boolean = false;
  @Prop trailingText: string = '';
  @Prop trailingColor: string = '';
  @Prop indicatorColor: string = '';
  @Prop embedded: boolean = false;
  @Prop disabled: boolean = false;
  @State isFocused: boolean = false;
  @State isPressed: boolean = false;
  onToggle?: () => void;
  onOpen?: () => void;

  private isOpenInteractive(): boolean {
    return !this.disabled && this.onOpen !== undefined;
  }

  private isToggleInteractive(): boolean {
    return !this.disabled && this.onToggle !== undefined;
  }

  private getTrailingColor(): string {
    return this.trailingColor.length > 0 ? this.trailingColor : this.themeColors.textMuted;
  }

  private getBackgroundColor(): string {
    if (this.disabled) {
      return this.embedded ? this.themeColors.transparent : this.themeColors.surfaceSoft;
    }
    if (this.isFocused) {
      return this.themeColors.announcementSurface;
    }
    return this.embedded ? this.themeColors.transparent : this.themeColors.surfaceSoft;
  }

  private getBorderColor(): string {
    if (this.disabled) {
      return this.themeColors.borderColor;
    }
    if (this.isFocused) {
      return this.themeColors.primaryLight;
    }
    return this.themeColors.borderColor;
  }

  private getOpacity(): number {
    if (this.disabled) {
      return DISABLED_OPACITY;
    }
    return this.completed ? MUTED_CONTENT_OPACITY : 1;
  }

  @Builder
  private CompletionToggle() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(CHECKBOX_SIZE_SM)
        .height(CHECKBOX_SIZE_SM)
        .borderRadius(CHECKBOX_SIZE_SM / 2)
        .backgroundColor(this.completed ? this.themeColors.successSubtle : this.themeColors.transparent)
        .border({ width: BORDER_DEFAULT, color: this.completed ? this.themeColors.success : this.themeColors.borderColor })

      if (this.completed) {
        AppIcon({
          name: 'success',
          iconSize: ICON_SIZE_XS,
          framed: false,
          color: this.themeColors.success
        })
      }
    }
    .width(CHECKBOX_SIZE_SM)
    .height(CHECKBOX_SIZE_SM)
    .focusable(this.isToggleInteractive())
    .onFocus(() => {
      this.isFocused = true;
    })
    .onBlur(() => {
      this.isFocused = false;
    })
    .onClick(() => {
      if (this.isToggleInteractive() && this.onToggle) {
        this.onToggle();
      }
    })
  }

  build() {
    Stack() {
      Row({ space: SPACE_XS }) {
        this.CompletionToggle()

        Column({ space: SPACE_2XS }) {
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
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .focusable(this.isOpenInteractive())
        .onFocus(() => {
          this.isFocused = true;
        })
        .onBlur(() => {
          this.isFocused = false;
        })

        if (this.trailingText.length > 0) {
          Row({ space: SPACE_XS }) {
            if (this.indicatorColor.length > 0) {
              Circle()
                .width(SPACE_XS)
                .height(SPACE_XS)
                .fill(this.indicatorColor)
            }

            Text(this.trailingText)
              .fontSize(TYPE_META)
              .fontColor(this.getTrailingColor())
              .maxLines(1)
          }
          .alignItems(VerticalAlign.Center)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: SPACE_SM, right: SPACE_SM, top: SPACE_XS, bottom: SPACE_XS })
      
      if (!this.embedded) {
        Row()
          .width('100%')
          .height('100%')
          .borderRadius(RADIUS_LG)
          .border({ width: 1, color: this.themeColors.borderHighlight })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .backgroundColor(this.getBackgroundColor())
    .borderRadius(RADIUS_LG)
    .border({ width: this.embedded && !this.isFocused ? 0 : BORDER_DEFAULT, color: this.getBorderColor() })
    .opacity(this.getOpacity())
    .scale({
      x: this.isPressed ? 0.98 : 1,
      y: this.isPressed ? 0.98 : 1
    })
    .animation({ duration: 100, curve: Curve.Friction })
    .onTouch((event: TouchEvent) => {
      if (!this.isOpenInteractive()) return;
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onClick(() => {
      if (this.isOpenInteractive() && this.onOpen) {
        this.onOpen();
      }
    })
  }
}
