import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { ICON_SIZE_XS } from '../../foundation/tokens/IconTokens';
import { RADIUS_PILL } from '../../foundation/tokens/RadiusTokens';
import { PAGE_PADDING, SPACE_2XS, SPACE_SM, SPACE_XS } from '../../foundation/tokens/SpacingTokens';
import { TYPE_CAPTION, TYPE_META, TYPE_SECTION_TITLE } from '../../foundation/tokens/TypographyTokens';
import { TOUCH_TARGET_SM } from '../../foundation/tokens/VisualTokens';
import { AppIcon } from './AppIcon';

@Builder
function EmptySectionBuilder() {
}

@Component
export struct AppPanelSection {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop actionText: string = '';
  @Prop actionIconName: string = '';
  @Prop insetHorizontal: number = PAGE_PADDING;
  @State actionPressed: boolean = false;
  onAction?: () => void;
  @BuilderParam content: () => void = EmptySectionBuilder;

  build() {
    Column({ space: SPACE_SM }) {
      Row({ space: SPACE_XS }) {
        Column({ space: SPACE_2XS }) {
          Text(this.title)
            .fontSize(TYPE_SECTION_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.themeColors.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(TYPE_META)
              .fontColor(this.themeColors.textSecondary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.actionText.length > 0) {
          Stack({ alignContent: Alignment.Center }) {
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
          .backgroundColor(this.themeColors.transparent)
          .borderRadius(RADIUS_PILL)
          .scale({ x: this.actionPressed ? 0.96 : 1, y: this.actionPressed ? 0.96 : 1 })
          .animation({ duration: 100, curve: Curve.Friction })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.actionPressed = true;
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.actionPressed = false;
            }
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

      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: this.insetHorizontal, right: this.insetHorizontal })
  }
}
