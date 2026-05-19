// 数据仪表盘卡片
import { WidgetStats } from '../../models/WidgetData';
import { buildWidgetRouteAction } from './WidgetNavigation';
import { WidgetGlyph } from './WidgetGlyph';
import { WIDGET_COLOR_SURFACE, WIDGET_COLOR_PRIMARY_SOFT, WIDGET_COLOR_DANGER_SOFT, WIDGET_COLOR_SUCCESS_SOFT, WIDGET_COLOR_WARNING_SOFT, WIDGET_COLOR_SURFACE_SOFT, WIDGET_COLOR_TEXT_DARK, WIDGET_COLOR_TEXT_HINT, WIDGET_COLOR_ACCENT, WIDGET_COLOR_ORANGE, WIDGET_COLOR_RED_SOFT, WIDGET_COLOR_GRAY, WIDGET_COLOR_SUCCESS_DARK } from './WidgetStyle';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct DashboardWidget {
  @LocalStorageProp('stats') stats: WidgetStats = new WidgetStats();

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('本周概览')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(WIDGET_COLOR_TEXT_DARK)

        Blank()

        Text('查看详情 >')
          .fontSize(11)
          .fontColor(WIDGET_COLOR_ACCENT)
      }
      .width('100%')

      Row({ space: 8 }) {
        Column({ space: 4 }) {
          WidgetGlyph({ name: 'focus', glyphSize: 18, color: WIDGET_COLOR_RED_SOFT, surfaceColor: WIDGET_COLOR_DANGER_SOFT })
          Text(`${this.stats.focusMinutesToday}`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(WIDGET_COLOR_RED_SOFT)
          Text('今日专注 (分钟)')
            .fontSize(9)
            .fontColor(WIDGET_COLOR_TEXT_HINT)
        }
        .width('30%')
        .padding(8)
        .backgroundColor(WIDGET_COLOR_DANGER_SOFT)
        .borderRadius(8)

        Column({ space: 4 }) {
          WidgetGlyph({ name: 'task', glyphSize: 18, color: WIDGET_COLOR_ACCENT, surfaceColor: WIDGET_COLOR_PRIMARY_SOFT })
          Text(`${this.stats.tasksCompletedToday}/${this.stats.tasksTotalToday}`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(WIDGET_COLOR_ACCENT)
          Text('今日任务')
            .fontSize(9)
            .fontColor(WIDGET_COLOR_TEXT_HINT)
        }
        .width('33%')
        .padding(8)
        .backgroundColor('#F0F9FF')
        .borderRadius(8)

        Column({ space: 4 }) {
          WidgetGlyph({ name: 'streak', glyphSize: 18, color: WIDGET_COLOR_ORANGE, surfaceColor: '#FFF3DA' })
          Text(`${this.stats.currentStreak}`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(WIDGET_COLOR_ORANGE)
          Text('连续打卡 (天)')
            .fontSize(9)
            .fontColor(WIDGET_COLOR_TEXT_HINT)
        }
        .width('30%')
        .padding(8)
        .backgroundColor(WIDGET_COLOR_WARNING_SOFT)
        .borderRadius(8)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        Column({ space: 4 }) {
          Text('本周专注')
            .fontSize(10)
            .fontColor(WIDGET_COLOR_GRAY)
          Row({ space: 4 }) {
            Text(`${this.stats.weekFocusMinutes}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(WIDGET_COLOR_ACCENT)
            Text('分钟')
              .fontSize(10)
              .fontColor(WIDGET_COLOR_TEXT_HINT)
          }
        }
        .width('50%')
        .padding(10)
        .backgroundColor(WIDGET_COLOR_SURFACE_SOFT)
        .borderRadius(8)

        Column({ space: 4 }) {
          Text('本周完成')
            .fontSize(10)
            .fontColor(WIDGET_COLOR_GRAY)
          Row({ space: 4 }) {
            Text(`${this.stats.weekTasksCompleted}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(WIDGET_COLOR_SUCCESS_DARK)
            Text('个任务')
              .fontSize(10)
              .fontColor(WIDGET_COLOR_TEXT_HINT)
          }
        }
        .width('50%')
        .padding(10)
        .backgroundColor(WIDGET_COLOR_SURFACE_SOFT)
        .borderRadius(8)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor(WIDGET_COLOR_SURFACE)
    .onClick(() => {
      this.navigateToStats();
    })
  }

  private navigateToStats(): void {
    postCardAction(this, buildWidgetRouteAction('pages/StatsHubPage'));
  }
}
