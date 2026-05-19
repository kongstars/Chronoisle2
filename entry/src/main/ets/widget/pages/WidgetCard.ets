import { WidgetTask } from '../../models/WidgetData';
import { WidgetGlyph } from './WidgetGlyph';

@Entry
@Component
struct WidgetCard {
  @State tasks: WidgetTask[] = [];

  build() {
    Column({ space: 8 }) {
      Text('今日待办')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)

      if (this.tasks.length === 0) {
        Text('打开四时清单，开始安排今天')
          .fontSize(12)
          .opacity(0.7)
      } else {
        ForEach(this.tasks.slice(0, 4), (task: WidgetTask) => {
          Row({ space: 8 }) {
            WidgetGlyph({ name: 'dot', glyphSize: 12 })
            Text(task.title)
              .fontSize(13)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }, (task: WidgetTask) => task.id)
      }
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }
}
