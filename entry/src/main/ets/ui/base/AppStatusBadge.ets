import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { type AppTone, getToneSurfaceColor, getToneTextColor } from '../../theme/ThemeSemantics';
import { ICON_SIZE_XS } from '../../foundation/tokens/IconTokens';
import { RADIUS_SM } from '../../foundation/tokens/RadiusTokens';
import { SPACE_2XS, SPACE_XS } from '../../foundation/tokens/SpacingTokens';
import { TYPE_CAPTION } from '../../foundation/tokens/TypographyTokens';
import { AppIcon } from './AppIcon';

@Component
export struct AppStatusBadge {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop text: string = '';
  @Prop tone: AppTone = 'neutral';
  @Prop iconName: string = '';

  build() {
    Row({ space: SPACE_2XS }) {
      if (this.iconName.length > 0) {
        AppIcon({
          name: this.iconName,
          iconSize: ICON_SIZE_XS,
          tone: this.tone,
          color: getToneTextColor(this.themeColors, this.tone),
          framed: false
        })
      }
      Text(this.text)
        .fontSize(TYPE_CAPTION)
        .fontWeight(FontWeight.Medium)
        .fontColor(getToneTextColor(this.themeColors, this.tone))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
      .alignItems(VerticalAlign.Center)
      .padding({ left: SPACE_XS, right: SPACE_XS, top: SPACE_2XS, bottom: SPACE_2XS })
      .backgroundColor(getToneSurfaceColor(this.themeColors, this.tone))
      .borderRadius(RADIUS_SM)
  }
}
