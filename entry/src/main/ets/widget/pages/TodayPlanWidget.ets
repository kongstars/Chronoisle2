// AI 今日计划卡片
import { WidgetPlanTask, WidgetTodayPlan } from '../../models/WidgetData';
import { buildWidgetRouteAction } from './WidgetNavigation';
import { WidgetGlyph } from './WidgetGlyph';
import { WIDGET_COLOR_SURFACE, WIDGET_COLOR_PRIMARY_SOFT, WIDGET_COLOR_DANGER_SOFT, WIDGET_COLOR_SUCCESS_SOFT, WIDGET_COLOR_WARNING_SOFT, WIDGET_COLOR_SURFACE_SOFT, WIDGET_COLOR_TEXT_DARK, WIDGET_COLOR_TEXT_HINT, WIDGET_COLOR_ACCENT, WIDGET_COLOR_ORANGE, WIDGET_COLOR_RED_SOFT, WIDGET_COLOR_GRAY, WIDGET_COLOR_SUCCESS_DARK, WIDGET_COLOR_INACTIVE, WIDGET_COLOR_INACTIVE_SURFACE } from './WidgetStyle';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct TodayPlanWidget {
  @LocalStorageProp('plan') plan: WidgetTodayPlan | null = null;
  @LocalStorageProp('emptyMessage') emptyMessage: string = '暂无 AI 计划，点击生成';

  build() {
    Column({ space: 8 }) {
      Row() {
        Text(this.isPlanAdopted() ? '今日计划 (已采纳)' : 'AI 计划待采纳')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.isPlanAdopted() ? WIDGET_COLOR_ACCENT : WIDGET_COLOR_ORANGE)

        Blank()

        Text(this.formatTime(this.getGeneratedAt()))
          .fontSize(10)
          .fontColor(WIDGET_COLOR_TEXT_HINT)
      }
      .width('100%')

      if (this.plan === null) {
        Column({ space: 12 }) {
          WidgetGlyph({ name: 'ai', glyphSize: 42, color: WIDGET_COLOR_ACCENT, surfaceColor: WIDGET_COLOR_PRIMARY_SOFT })

          Text(this.emptyMessage)
            .fontSize(11)
            .fontColor(WIDGET_COLOR_TEXT_HINT)

          Text('点击进入今日计划')
            .fontSize(11)
            .fontColor(WIDGET_COLOR_ACCENT)
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })
      } else {
        ForEach(this.getPlanTasks(), (task: WidgetPlanTask) => {
          Row({ space: 8 }) {
            WidgetGlyph({
              name: task.isCompleted ? 'task' : 'dot',
              glyphSize: 14,
              color: task.isCompleted ? WIDGET_COLOR_SUCCESS_DARK : WIDGET_COLOR_INACTIVE,
              surfaceColor: task.isCompleted ? WIDGET_COLOR_SUCCESS_SOFT : WIDGET_COLOR_INACTIVE_SURFACE
            })

            Column({ space: 2 }) {
              Text(task.title)
                .fontSize(11)
                .fontColor(task.isCompleted ? WIDGET_COLOR_TEXT_HINT : WIDGET_COLOR_TEXT_DARK)
                .decoration({ type: task.isCompleted ? TextDecorationType.LineThrough : TextDecorationType.None })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              if (task.timeSlot) {
                Text(task.timeSlot)
                  .fontSize(9)
                  .fontColor(WIDGET_COLOR_TEXT_HINT)
              }
            }

            Blank()
          }
          .width('100%')
          .height(28)
          .alignItems(VerticalAlign.Center)
        }, (task: WidgetPlanTask) => task.id)

        if (!this.isPlanAdopted()) {
          Row() {
            Text('采纳计划')
              .fontSize(12)
              .fontColor(WIDGET_COLOR_SURFACE)
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .backgroundColor(WIDGET_COLOR_ACCENT)
              .borderRadius(12)

            Blank()

            Text('重新生成')
              .fontSize(12)
              .fontColor(WIDGET_COLOR_ACCENT)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(WIDGET_COLOR_PRIMARY_SOFT)
              .borderRadius(12)
          }
          .width('100%')
          .margin({ top: 8 })
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding(10)
    .backgroundColor(WIDGET_COLOR_SURFACE)
    .onClick(() => {
      this.navigateToTodayPlan();
    })
  }

  private getPlanTasks(): WidgetPlanTask[] {
    if (this.plan === null) {
      return [];
    }
    return this.plan.tasks;
  }

  private isPlanAdopted(): boolean {
    if (this.plan === null) {
      return false;
    }
    return this.plan.isAdopted;
  }

  private getGeneratedAt(): number {
    if (this.plan === null || !this.plan.generatedAt) {
      return 0;
    }
    return this.plan.generatedAt;
  }

  private formatTime(timestamp: number): string {
    if (timestamp === 0) {
      return '';
    }
    const date = new Date(timestamp);
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    return `${hour}:${minute}`;
  }

  private navigateToTodayPlan(): void {
    postCardAction(this, buildWidgetRouteAction('pages/TodayPlanPage'));
  }
}
