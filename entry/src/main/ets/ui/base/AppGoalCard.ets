import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { BORDER_DEFAULT } from '../../foundation/tokens/BorderTokens';
import { RADIUS_LG, RADIUS_PILL, RADIUS_SM } from '../../foundation/tokens/RadiusTokens';
import { SPACE_2XS, SPACE_MD, SPACE_SM, SPACE_XS } from '../../foundation/tokens/SpacingTokens';
import { TYPE_BODY, TYPE_CAPTION, TYPE_META, TYPE_SECTION_TITLE } from '../../foundation/tokens/TypographyTokens';
import { DISABLED_OPACITY } from '../../foundation/tokens/VisualTokens';

@Component
export struct AppGoalCard {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop badgeText: string = '';
  @Prop title: string = '';
  @Prop progressText: string = '';
  @Prop percentText: string = '';
  @Prop keyResults: string[] = [];
  @Prop accentColor: string = '';
  @Prop badgeTextColor: string = '';
  @Prop badgeBackgroundColor: string = '';
  @Prop surfaceColor: string = '';
  @Prop disabled: boolean = false;
  @State isFocused: boolean = false;
  @State isPressed: boolean = false;
  tapAction?: () => void;

  private isInteractive(): boolean {
    return !this.disabled && this.tapAction !== undefined;
  }

  private getAccentColor(): string {
    return this.accentColor.length > 0 ? this.accentColor : this.themeColors.primary;
  }

  private getBadgeTextColor(): string {
    return this.badgeTextColor.length > 0 ? this.badgeTextColor : this.themeColors.primary;
  }

  private getBadgeBackgroundColor(): string {
    return this.badgeBackgroundColor.length > 0 ? this.badgeBackgroundColor : this.themeColors.announcementSurface;
  }

  private getSurfaceColor(): string {
    return this.surfaceColor.length > 0 ? this.surfaceColor : this.themeColors.cardBackground;
  }

  private getCardBackgroundColor(): string {
    if (this.disabled) {
      return this.themeColors.surfaceSoft;
    }
    return this.getSurfaceColor();
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

  private getVisibleKeyResultCount(): number {
    return Math.min(3, Math.max(0, this.keyResults.length));
  }

  private getAccentHeight(): number {
    const keyResultCount = this.getVisibleKeyResultCount();
    if (keyResultCount <= 0) {
      return 76;
    }
    return 64 + keyResultCount * 28;
  }

  build() {
    Row({ space: SPACE_SM }) {
      Column()
        .width(2)
        .height(this.getAccentHeight())
        .backgroundColor(this.themeColors.divider)
        .borderRadius(RADIUS_PILL)

      Column({ space: SPACE_XS }) {
        Row() {
          if (this.badgeText.length > 0) {
            Row({ space: SPACE_2XS }) {
              Row()
                .width(6)
                .height(6)
                .backgroundColor(this.themeColors.primaryLight)
                .borderRadius(RADIUS_PILL)

              Text(this.badgeText)
                .fontSize(TYPE_CAPTION)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getBadgeTextColor())
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(this.getBadgeBackgroundColor())
            .borderRadius(RADIUS_SM)
            .alignItems(VerticalAlign.Center)
          }

          Blank()

          if (this.percentText.length > 0) {
            Text(this.percentText)
              .fontSize(TYPE_SECTION_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.themeColors.primary)
          }
        }
        .width('100%')

        Column({ space: SPACE_2XS }) {
          Text(this.title)
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          if (this.progressText.length > 0) {
            Text(this.progressText)
              .fontSize(TYPE_META)
              .fontColor(this.themeColors.textSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
        }
        .alignItems(HorizontalAlign.Start)

        Column({ space: SPACE_2XS }) {
          ForEach(this.keyResults.slice(0, 3), (item: string) => {
            Row({ space: SPACE_XS }) {
              Circle()
                .width(5)
                .height(5)
                .fill(this.themeColors.primaryLight)

              Text(item)
                .fontSize(TYPE_BODY)
                .fontColor(this.themeColors.textPrimary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(this.themeColors.surfaceSoft)
            .borderRadius(RADIUS_SM)
          })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ left: 12, right: 12, top: SPACE_MD, bottom: SPACE_MD })
    .backgroundColor(this.getCardBackgroundColor())
    .borderRadius(RADIUS_LG)
    .border({ width: BORDER_DEFAULT, color: this.getBorderColor() })
    .opacity(this.disabled ? DISABLED_OPACITY : 1)
    .scale({
      x: this.isPressed ? 0.98 : 1,
      y: this.isPressed ? 0.98 : 1
    })
    .animation({ duration: 100, curve: Curve.Friction })
    .focusable(this.isInteractive())
    .onFocus(() => {
      this.isFocused = true;
    })
    .onBlur(() => {
      this.isFocused = false;
    })
    .onTouch((event: TouchEvent) => {
      if (!this.isInteractive()) return;
      if (event.type === TouchType.Down) {
        this.isPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.isPressed = false;
      }
    })
    .onClick(() => {
      if (this.isInteractive() && this.tapAction) {
        this.tapAction();
      }
    })
  }
}
