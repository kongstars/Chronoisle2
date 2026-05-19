import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { SPACE_SM } from '../../foundation/tokens/SpacingTokens';
import { TYPE_META } from '../../foundation/tokens/TypographyTokens';
import { STATE_BLOCK_VERTICAL_PADDING, STATE_INDICATOR_SIZE } from '../../foundation/tokens/VisualTokens';

@Component
export struct AppLoadingState {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop label: string = '加载中...';

  build() {
    Column({ space: SPACE_SM }) {
      LoadingProgress()
        .width(STATE_INDICATOR_SIZE)
        .height(STATE_INDICATOR_SIZE)
        .color(this.themeColors.primary)
      Text(this.label)
        .fontSize(TYPE_META)
        .fontColor(this.themeColors.textSecondary)
    }
    .width('100%')
    .padding({ top: STATE_BLOCK_VERTICAL_PADDING, bottom: STATE_BLOCK_VERTICAL_PADDING })
    .justifyContent(FlexAlign.Center)
  }
}
