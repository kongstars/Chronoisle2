// 专注快捷卡片
import { WidgetFocus } from '../../models/WidgetData';
import { buildWidgetRouteAction } from './WidgetNavigation';
import { WidgetGlyph } from './WidgetGlyph';
import { WIDGET_COLOR_SURFACE, WIDGET_COLOR_PRIMARY_SOFT, WIDGET_COLOR_DANGER_SOFT, WIDGET_COLOR_SUCCESS_SOFT, WIDGET_COLOR_WARNING_SOFT, WIDGET_COLOR_SURFACE_SOFT, WIDGET_COLOR_TEXT_DARK, WIDGET_COLOR_TEXT_HINT, WIDGET_COLOR_ACCENT, WIDGET_COLOR_ORANGE, WIDGET_COLOR_RED_SOFT, WIDGET_COLOR_GRAY } from './WidgetStyle';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct FocusWidget {
  @LocalStorageProp('focus') focus: WidgetFocus = new WidgetFocus();
  @LocalStorageProp('emptyMessage') emptyMessage: string = '点击开始专注';

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('专注时钟')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(WIDGET_COLOR_TEXT_DARK)

        Blank()

        WidgetGlyph({ name: 'focus', glyphSize: 18, color: WIDGET_COLOR_RED_SOFT, surfaceColor: WIDGET_COLOR_DANGER_SOFT })
      }
      .width('100%')

      if (this.focus.isFocusing) {
        Column({ space: 8 }) {
          Text(this.formatTime(this.focus.remainingSeconds))
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor(WIDGET_COLOR_RED_SOFT)

          Text(this.focus.currentTask || '专注中...')
            .fontSize(12)
            .fontColor(WIDGET_COLOR_GRAY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: 12 }) {
            Text('进入专注页')
              .fontSize(11)
              .fontColor(WIDGET_COLOR_SURFACE)
              .padding({ left: 12, right: 12, top: 4, bottom: 4 })
              .backgroundColor(WIDGET_COLOR_RED_SOFT)
              .borderRadius(12)
          }
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
      } else {
        Column({ space: 8 }) {
          if (this.focus.totalFocusMinutes > 0) {
            Text('今日已专注')
              .fontSize(11)
              .fontColor(WIDGET_COLOR_TEXT_HINT)

            Row({ space: 4 }) {
              Text(`${this.focus.totalFocusMinutes}`)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(WIDGET_COLOR_ACCENT)

              Text('分钟')
                .fontSize(12)
                .fontColor(WIDGET_COLOR_GRAY)
            }
          } else {
            WidgetGlyph({ name: 'focus', glyphSize: 44, color: WIDGET_COLOR_RED_SOFT, surfaceColor: WIDGET_COLOR_DANGER_SOFT })

            Text(this.emptyMessage)
              .fontSize(11)
              .fontColor(WIDGET_COLOR_TEXT_HINT)
          }
        }
        .width('100%')
        .padding({ top: 10, bottom: 10 })
      }

      Row() {
        Blank()
        Text(this.focus.isFocusing ? '进入专注页' : '开始专注')
          .fontSize(12)
          .fontColor(WIDGET_COLOR_SURFACE)
          .padding({ left: 16, right: 16, top: 6, bottom: 6 })
          .backgroundColor(WIDGET_COLOR_ACCENT)
          .borderRadius(12)
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .padding(10)
    .backgroundColor(WIDGET_COLOR_SURFACE)
    .onClick(() => {
      this.navigateToFocus();
    })
  }

  private formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  private navigateToFocus(): void {
    postCardAction(this, buildWidgetRouteAction('pages/PomodoroPage'));
  }
}
