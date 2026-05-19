import { ThemeColors, LightTheme } from '../theme/AppTheme';

@Builder
function EmptyThemeContent() {
}

@Component
export struct ThemeWrapper {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @BuilderParam content: () => void = EmptyThemeContent;

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeColors.background)
  }
}

export function getThemeColors(): ThemeColors {
  const colors = AppStorage.Get<ThemeColors>('themeColors');
  return colors || LightTheme;
}
