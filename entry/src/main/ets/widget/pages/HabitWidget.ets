// 习惯打卡卡片
import { WidgetHabit } from '../../models/WidgetData';
import { buildEventRouteParams, buildWidgetRouteAction } from './WidgetNavigation';
import { WidgetGlyph } from './WidgetGlyph';
import { WIDGET_COLOR_SURFACE, WIDGET_COLOR_PRIMARY_SOFT, WIDGET_COLOR_DANGER_SOFT, WIDGET_COLOR_SUCCESS_SOFT, WIDGET_COLOR_WARNING_SOFT, WIDGET_COLOR_SURFACE_SOFT, WIDGET_COLOR_TEXT_DARK, WIDGET_COLOR_TEXT_HINT, WIDGET_COLOR_ACCENT, WIDGET_COLOR_ORANGE, WIDGET_COLOR_RED_SOFT, WIDGET_COLOR_GRAY, WIDGET_COLOR_SUCCESS_DARK, WIDGET_COLOR_INACTIVE, WIDGET_COLOR_INACTIVE_SURFACE } from './WidgetStyle';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct HabitWidget {
  @LocalStorageProp('habits') habits: WidgetHabit[] = [];
  @LocalStorageProp('completedCount') completedCount: number = 0;
  @LocalStorageProp('totalCount') totalCount: number = 0;
  @LocalStorageProp('emptyMessage') emptyMessage: string = '暂无习惯，点击添加';

  build() {
    Column({ space: 8 }) {
      Row() {
        Text('习惯打卡')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(WIDGET_COLOR_TEXT_DARK)

        Blank()

        Text(`${this.completedCount}/${this.totalCount}`)
          .fontSize(12)
          .fontColor(WIDGET_COLOR_GRAY)
      }
      .width('100%')

      if (this.totalCount > 0) {
        Row() {
          Row()
            .width(`${(this.completedCount / this.totalCount) * 100}%`)
            .height(6)
            .backgroundColor(WIDGET_COLOR_ACCENT)
            .borderRadius(3)
          Row()
            .layoutWeight(1)
            .height(6)
            .backgroundColor('#E6E6E6')
            .borderRadius(3)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }

      if (this.habits.length === 0) {
        Text(this.emptyMessage)
          .fontSize(12)
          .fontColor(WIDGET_COLOR_TEXT_HINT)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 20 })
      } else {
        ForEach(this.habits, (habit: WidgetHabit) => {
          Row({ space: 8 }) {
            WidgetGlyph({
              name: habit.isCompleted ? 'task' : 'dot',
              glyphSize: 14,
              color: habit.isCompleted ? WIDGET_COLOR_SUCCESS_DARK : WIDGET_COLOR_INACTIVE,
              surfaceColor: habit.isCompleted ? WIDGET_COLOR_SUCCESS_SOFT : WIDGET_COLOR_INACTIVE_SURFACE
            })

            Text(habit.title)
              .fontSize(12)
              .fontColor(habit.isCompleted ? WIDGET_COLOR_TEXT_HINT : WIDGET_COLOR_TEXT_DARK)
              .decoration({ type: habit.isCompleted ? TextDecorationType.LineThrough : TextDecorationType.None })
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Blank()
          }
          .width('100%')
          .height(32)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.navigateToHabitDetail(habit.id);
          })
        }, (habit: WidgetHabit) => habit.id)
      }

      Row() {
        Blank()
        Text('+ 添加习惯')
          .fontSize(12)
          .fontColor(WIDGET_COLOR_ACCENT)
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .backgroundColor(WIDGET_COLOR_PRIMARY_SOFT)
          .borderRadius(12)
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .onClick(() => {
        this.navigateToCreateHabit();
      })
    }
    .width('100%')
    .height('100%')
    .padding(10)
    .backgroundColor(WIDGET_COLOR_SURFACE)
    .onClick(() => {
      this.navigateToHabitPage();
    })
  }

  private navigateToHabitDetail(habitId: string): void {
    postCardAction(this, buildWidgetRouteAction('pages/DayEventDetailPage', buildEventRouteParams(habitId)));
  }

  private navigateToCreateHabit(): void {
    postCardAction(this, buildWidgetRouteAction('pages/DayEventCreatePage'));
  }

  private navigateToHabitPage(): void {
    postCardAction(this, buildWidgetRouteAction('pages/ReminderListPage'));
  }
}
