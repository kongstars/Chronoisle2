// 语音创建快捷卡片
import { buildVoiceRouteParams, buildWidgetRouteAction } from './WidgetNavigation';
import { WidgetGlyph } from './WidgetGlyph';
import { WIDGET_COLOR_SURFACE, WIDGET_COLOR_PRIMARY_SOFT, WIDGET_COLOR_DANGER_SOFT, WIDGET_COLOR_SUCCESS_SOFT, WIDGET_COLOR_WARNING_SOFT, WIDGET_COLOR_SURFACE_SOFT, WIDGET_COLOR_TEXT_DARK, WIDGET_COLOR_TEXT_HINT, WIDGET_COLOR_ACCENT, WIDGET_COLOR_ORANGE, WIDGET_COLOR_RED_SOFT, WIDGET_COLOR_GRAY, WIDGET_COLOR_SURFACE_ULTRA_LIGHT } from './WidgetStyle';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct VoiceWidget {
  @LocalStorageProp('promptText') promptText: string = '点击语音创建';
  @LocalStorageProp('isListening') isListening: boolean = false;

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('语音创建')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(WIDGET_COLOR_TEXT_DARK)

        Blank()

        WidgetGlyph({ name: 'voice', glyphSize: 20, color: WIDGET_COLOR_ACCENT, surfaceColor: WIDGET_COLOR_PRIMARY_SOFT })
      }
      .width('100%')

      Column({ space: 10 }) {
        Row() {
          WidgetGlyph({
            name: 'voice',
            glyphSize: 56,
            color: this.isListening ? WIDGET_COLOR_RED_SOFT : WIDGET_COLOR_ACCENT,
            surfaceColor: this.isListening ? WIDGET_COLOR_DANGER_SOFT : WIDGET_COLOR_PRIMARY_SOFT
          })
        }
        .width(80)
        .height(80)
        .backgroundColor(this.isListening ? WIDGET_COLOR_RED_SOFT : WIDGET_COLOR_SURFACE_ULTRA_LIGHT)
        .borderRadius(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Text(this.isListening ? '正在听...' : this.promptText)
          .fontSize(12)
          .fontColor(this.isListening ? WIDGET_COLOR_RED_SOFT : WIDGET_COLOR_GRAY)
      }
      .width('100%')
      .padding({ top: 15, bottom: 15 })

      Row() {
        Text('说话创建任务/目标/提醒')
          .fontSize(10)
          .fontColor(WIDGET_COLOR_TEXT_HINT)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding(10)
    .backgroundColor(WIDGET_COLOR_SURFACE)
    .onClick(() => {
      this.navigateToVoiceCreate();
    })
  }

  private navigateToVoiceCreate(): void {
    postCardAction(this, buildWidgetRouteAction('pages/MainPage', buildVoiceRouteParams()));
  }
}
