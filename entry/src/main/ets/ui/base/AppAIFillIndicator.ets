import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { getToneSurfaceColor, getToneTextColor } from '../../theme/ThemeSemantics';
import { RADIUS_PILL } from '../../foundation/tokens/RadiusTokens';
import { SPACE_2XS } from '../../foundation/tokens/SpacingTokens';
import { ICON_SIZE_XS } from '../../foundation/tokens/IconTokens';
import { AppAIFillStatus } from './AppAIFillBanner';
import { AppIcon } from './AppIcon';

@Component
export struct AppAIFillIndicator {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop status: AppAIFillStatus = 'filled';

  private getTone(): 'primary' | 'danger' | 'info' {
    if (this.status === 'failed') {
      return 'danger';
    }
    if (this.status === 'parsing') {
      return 'info';
    }
    return 'primary';
  }

  build() {
    Row({ space: SPACE_2XS }) {
      if (this.status === 'parsing') {
        LoadingProgress()
          .width(10)
          .height(10)
          .color(getToneTextColor(this.themeColors, this.getTone()))
      } else {
        AppIcon({
          name: 'ai',
          iconSize: ICON_SIZE_XS,
          framed: false,
          color: getToneTextColor(this.themeColors, this.getTone())
        })
      }
    }
    .height(18)
    .padding({ left: 6, right: 6 })
    .backgroundColor(getToneSurfaceColor(this.themeColors, this.getTone()))
    .borderRadius(RADIUS_PILL)
  }
}
