// 今日待办卡片
import { WidgetTask } from '../../models/WidgetData';
import { buildTaskRouteParams, buildWidgetRouteAction } from './WidgetNavigation';
import { WidgetGlyph } from './WidgetGlyph';
import { WIDGET_COLOR_SURFACE, WIDGET_COLOR_PRIMARY_SOFT, WIDGET_COLOR_DANGER_SOFT, WIDGET_COLOR_SUCCESS_SOFT, WIDGET_COLOR_WARNING_SOFT, WIDGET_COLOR_SURFACE_SOFT, WIDGET_COLOR_TEXT_DARK, WIDGET_COLOR_TEXT_HINT, WIDGET_COLOR_ACCENT, WIDGET_COLOR_ORANGE, WIDGET_COLOR_RED_SOFT, WIDGET_COLOR_GRAY } from './WidgetStyle';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct TodoWidget {
  @LocalStorageProp('tasks') tasks: WidgetTask[] = [];
  @LocalStorageProp('emptyMessage') emptyMessage: string = '暂无待办，点击添加';

  build() {
    Column({ space: 6 }) {
      Row() {
        Text('今日待办')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(WIDGET_COLOR_TEXT_DARK)

        Blank()

        Text(`${this.tasks.length}`)
          .fontSize(12)
          .fontColor(WIDGET_COLOR_GRAY)
      }
      .width('100%')

      if (this.tasks.length === 0) {
        Text(this.emptyMessage)
          .fontSize(12)
          .fontColor(WIDGET_COLOR_TEXT_HINT)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 20 })
      } else {
        ForEach(this.tasks, (task: WidgetTask) => {
          Row({ space: 6 }) {
            WidgetGlyph({
              name: task.isPinned ? 'pin' : (task.isOverdue ? 'warning' : 'dot'),
              glyphSize: 14,
              color: task.isOverdue ? WIDGET_COLOR_RED_SOFT : WIDGET_COLOR_ACCENT,
              surfaceColor: task.isOverdue ? WIDGET_COLOR_DANGER_SOFT : WIDGET_COLOR_PRIMARY_SOFT
            })

            Text(task.title)
              .fontSize(12)
              .fontColor(task.isOverdue ? WIDGET_COLOR_RED_SOFT : WIDGET_COLOR_TEXT_DARK)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Blank()

            if (task.dueDate) {
              Text(this.formatDueDate(task.dueDate))
                .fontSize(10)
                .fontColor(WIDGET_COLOR_TEXT_HINT)
            }
          }
          .width('100%')
          .height(28)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.navigateToTaskDetail(task.id);
          })
        }, (task: WidgetTask) => task.id)
      }

      Row() {
        Blank()
        Text('+ 添加任务')
          .fontSize(12)
          .fontColor(WIDGET_COLOR_ACCENT)
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .backgroundColor(WIDGET_COLOR_PRIMARY_SOFT)
          .borderRadius(12)
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .onClick(() => {
        this.navigateToCreateTask();
      })
    }
    .width('100%')
    .height('100%')
    .padding(10)
    .backgroundColor(WIDGET_COLOR_SURFACE)
    .onClick(() => {
      this.navigateToTodayPage();
    })
  }

  private formatDueDate(timestamp: number): string {
    const diff = timestamp - Date.now();
    const days = Math.ceil(diff / (1000 * 60 * 60 * 24));
    if (days < 0) {
      return '已逾期';
    }
    if (days === 0) {
      return '今天';
    }
    if (days === 1) {
      return '明天';
    }
    return `${days}天后`;
  }

  private navigateToTaskDetail(taskId: string): void {
    postCardAction(this, buildWidgetRouteAction('pages/TaskDetailPage', buildTaskRouteParams(taskId)));
  }

  private navigateToCreateTask(): void {
    postCardAction(this, buildWidgetRouteAction('pages/CreateTaskPage'));
  }

  private navigateToTodayPage(): void {
    postCardAction(this, buildWidgetRouteAction('pages/MainPage'));
  }
}
