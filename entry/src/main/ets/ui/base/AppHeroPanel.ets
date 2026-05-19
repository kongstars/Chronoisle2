import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { type AppTone, getToneBorderColor, getToneSurfaceColor } from '../../theme/ThemeSemantics';
import { BORDER_DEFAULT } from '../../foundation/tokens/BorderTokens';
import { getRaisedCardShadow } from '../../foundation/tokens/ElevationTokens';
import { HERO_PANEL_HEIGHT_COMPACT } from '../../foundation/tokens/PageDensityTokens';
import { RADIUS_LG, RADIUS_PILL } from '../../foundation/tokens/RadiusTokens';
import { SPACE_2XS, SPACE_CARD, SPACE_MD, SPACE_SM, SPACE_XS } from '../../foundation/tokens/SpacingTokens';
import { TYPE_CAPTION, TYPE_HERO_TITLE, TYPE_META } from '../../foundation/tokens/TypographyTokens';

@Builder
function EmptyHeroBuilder() {
}

@Component
export struct AppHeroPanel {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop eyebrow: string = '';
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop tone: AppTone = 'primary';
  @Prop minHeight: number = HERO_PANEL_HEIGHT_COMPACT;
  @BuilderParam content: () => void = EmptyHeroBuilder;

  build() {
    Column({ space: SPACE_XS }) {
      if (this.eyebrow.length > 0) {
        Text(this.eyebrow)
          .fontSize(TYPE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.primary)
          .padding({ left: SPACE_SM, right: SPACE_SM, top: SPACE_2XS, bottom: SPACE_2XS })
          .backgroundColor(this.themeColors.primarySubtle)
          .borderRadius(RADIUS_PILL)
      }

      Column({ space: SPACE_XS }) {
        Text(this.title)
          .fontSize(TYPE_HERO_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themeColors.textPrimary)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.description.length > 0) {
          Text(this.description)
            .fontSize(TYPE_META)
            .fontColor(this.themeColors.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)

      this.content()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: SPACE_MD, right: SPACE_MD, top: SPACE_MD, bottom: SPACE_MD })
    .constraintSize({ minHeight: this.minHeight })
    .backgroundColor(getToneSurfaceColor(this.themeColors, this.tone))
    .borderRadius(RADIUS_LG)
    .border({ width: BORDER_DEFAULT, color: getToneBorderColor(this.themeColors, this.tone) })
    .shadow(getRaisedCardShadow(this.themeColors))
  }
}
