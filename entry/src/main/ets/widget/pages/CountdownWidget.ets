// 时间提醒卡片
import { WidgetCountdown, WidgetCountdownType } from '../../models/WidgetData';
import { buildEventRouteParams, buildWidgetRouteAction } from './WidgetNavigation';
import { WidgetGlyph } from './WidgetGlyph';
import { WIDGET_COLOR_SURFACE, WIDGET_COLOR_PRIMARY_SOFT, WIDGET_COLOR_DANGER_SOFT, WIDGET_COLOR_SUCCESS_SOFT, WIDGET_COLOR_WARNING_SOFT, WIDGET_COLOR_SURFACE_SOFT, WIDGET_COLOR_TEXT_DARK, WIDGET_COLOR_TEXT_HINT, WIDGET_COLOR_ACCENT, WIDGET_COLOR_ORANGE, WIDGET_COLOR_PINK } from './WidgetStyle';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct CountdownWidget {
  @LocalStorageProp('countdowns') countdowns: WidgetCountdown[] = [];
  @LocalStorageProp('emptyMessage') emptyMessage: string = '暂无倒计时，点击添加';

  build() {
    Column({ space: 8 }) {
      Row() {
        Text('时间提醒')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(WIDGET_COLOR_TEXT_DARK)

        Blank()

        Text('+ 添加')
          .fontSize(12)
          .fontColor(WIDGET_COLOR_ACCENT)
      }
      .width('100%')
      .onClick(() => {
        this.navigateToCreate();
      })

      if (this.countdowns.length === 0) {
        Text(this.emptyMessage)
          .fontSize(12)
          .fontColor(WIDGET_COLOR_TEXT_HINT)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 20 })
      } else {
        ForEach(this.countdowns, (item: WidgetCountdown) => {
          Row({ space: 8 }) {
            WidgetGlyph({
              name: this.getIcon(item.type),
              glyphSize: 20,
              color: this.getColor(item.type),
              surfaceColor: WIDGET_COLOR_SURFACE_SOFT
            })

            Column({ space: 2 }) {
              Text(item.title)
                .fontSize(12)
                .fontColor(WIDGET_COLOR_TEXT_DARK)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Text(this.formatDays(item.daysRemaining, item.type))
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getColor(item.type))
            }
            .alignItems(HorizontalAlign.Start)

            Blank()
          }
          .width('100%')
          .padding({ top: 6, bottom: 6 })
          .onClick(() => {
            this.navigateToDetail(item.id);
          })
        }, (item: WidgetCountdown) => item.id)
      }
    }
    .width('100%')
    .height('100%')
    .padding(10)
    .backgroundColor(WIDGET_COLOR_SURFACE)
    .onClick(() => {
      this.navigateToList();
    })
  }

  private getIcon(type: WidgetCountdownType): string {
    switch (type) {
      case 'milestone':
        return 'calendar';
      case 'anniversary':
        return 'heart';
      case 'reminder':
        return 'reminder';
      default:
        return 'calendar';
    }
  }

  private formatDays(days: number, type: WidgetCountdownType): string {
    if (days < 0) {
      return `已过 ${Math.abs(days)} 天`;
    }
    if (days === 0) {
      return '就是今天!';
    }
    if (type === 'anniversary') {
      return `第 ${days} 天`;
    }
    if (type === 'reminder') {
      return `还有 ${days} 天`;
    }
    return `还有 ${days} 天`;
  }

  private getColor(type: WidgetCountdownType): string {
    switch (type) {
      case 'milestone':
        return WIDGET_COLOR_ORANGE;
      case 'anniversary':
        return WIDGET_COLOR_PINK;
      case 'reminder':
        return WIDGET_COLOR_ACCENT;
      default:
        return WIDGET_COLOR_ACCENT;
    }
  }

  private navigateToDetail(eventId: string): void {
    postCardAction(this, buildWidgetRouteAction('pages/DayEventDetailPage', buildEventRouteParams(eventId)));
  }

  private navigateToCreate(): void {
    postCardAction(this, buildWidgetRouteAction('pages/DayEventCreatePage'));
  }

  private navigateToList(): void {
    postCardAction(this, buildWidgetRouteAction('pages/DayEventListPage'));
  }
}
