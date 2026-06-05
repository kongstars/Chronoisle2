// 主 widget：AI 今日计划 + 2 个快捷入口
import { MainWidgetTask } from '../../models/WidgetData';
import { buildTaskRouteParams, buildVoiceRouteParams, buildWidgetRouteAction } from './WidgetNavigation';
import { WIDGET_COLOR_SURFACE, WIDGET_COLOR_PRIMARY_SOFT, WIDGET_COLOR_DANGER_SOFT, WIDGET_COLOR_SUCCESS_SOFT, WIDGET_COLOR_WARNING_SOFT, WIDGET_COLOR_SURFACE_SOFT, WIDGET_COLOR_TEXT_DARK, WIDGET_COLOR_TEXT_HINT, WIDGET_COLOR_ACCENT, WIDGET_COLOR_ORANGE, WIDGET_COLOR_RED_SOFT, WIDGET_COLOR_GRAY, WIDGET_COLOR_TEXT_BOLD, WIDGET_COLOR_TEXT_LIGHT, WIDGET_COLOR_TEXT_MEDIUM, WIDGET_COLOR_SUCCESS_VIBRANT, WIDGET_COLOR_ORANGE_VIBRANT, WIDGET_COLOR_BLUE_VIBRANT } from './WidgetStyle';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct MainWidget {
  @LocalStorageProp('planSummary') planSummary: string = '点击生成';
  @LocalStorageProp('planTaskCount') planTaskCount: number = 0;
  @LocalStorageProp('isPlanAdopted') isPlanAdopted: boolean = false;
  @LocalStorageProp('tasks') tasks: MainWidgetTask[] = [];
  @LocalStorageProp('refreshTime') refreshTime: string = '';

  build() {
    Column({ space: 12 }) {
      this.renderHeader();
      this.renderPlanSection();
      this.renderFooterActions();
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor(WIDGET_COLOR_SURFACE)
  }

  @Builder
  private renderHeader() {
    Row() {
      Column({ space: 2 }) {
        Text('四时清单')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(WIDGET_COLOR_TEXT_BOLD)

        Text(this.refreshTime.length > 0 ? `更新于 ${this.refreshTime}` : 'AI 今日计划')
          .fontSize(14)
          .fontColor(WIDGET_COLOR_TEXT_LIGHT)
      }

      Blank()

      Text(this.planTaskCount > 0 ? (this.isPlanAdopted ? '已采纳' : '已生成') : '待生成')
        .fontSize(14)
        .fontColor(this.planTaskCount > 0 ? WIDGET_COLOR_ACCENT : WIDGET_COLOR_TEXT_HINT)
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor(this.planTaskCount > 0 ? WIDGET_COLOR_PRIMARY_SOFT : WIDGET_COLOR_SURFACE_SOFT)
        .borderRadius(12)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private renderPlanSection() {
    Column({ space: 10 }) {
      Row() {
        Text('AI 今日计划')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(WIDGET_COLOR_TEXT_BOLD)

        Blank()

        Text(this.planTaskCount > 0 ? `${this.planTaskCount} 项` : '未生成')
          .fontSize(14)
          .fontColor(this.planTaskCount > 0 ? WIDGET_COLOR_ACCENT : WIDGET_COLOR_TEXT_HINT)
      }
      .width('100%')

      if (this.planTaskCount === 0 || this.tasks.length === 0) {
        Column({ space: 8 }) {
          Text(this.planSummary.length > 0 ? this.planSummary : '点击生成今日计划')
            .fontSize(14)
            .fontColor(WIDGET_COLOR_TEXT_MEDIUM)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text('点击生成')
            .width('100%')
            .height(36)
            .fontSize(14)
            .fontColor(WIDGET_COLOR_SURFACE)
            .textAlign(TextAlign.Center)
            .backgroundColor(WIDGET_COLOR_ACCENT)
            .borderRadius(10)
            .onClick(() => {
              this.openTodayPlanPage();
            })
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })
      } else {
        Column({ space: 8 }) {
          ForEach(this.getVisiblePlanTasks(), (task: MainWidgetTask) => {
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text(task.isCompleted ? '已完成' : '待完成')
                  .fontSize(14)
                  .fontColor(task.isCompleted ? WIDGET_COLOR_SUCCESS_VIBRANT : WIDGET_COLOR_ORANGE_VIBRANT)

                Text(task.title)
                  .fontSize(14)
                  .fontColor(task.isCompleted ? WIDGET_COLOR_TEXT_HINT : WIDGET_COLOR_TEXT_BOLD)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)

              Text('完成')
                .fontSize(14)
                .fontColor(task.isCompleted ? WIDGET_COLOR_GRAY : WIDGET_COLOR_SURFACE)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .backgroundColor(task.isCompleted ? WIDGET_COLOR_SURFACE_SOFT : WIDGET_COLOR_ACCENT)
                .borderRadius(10)
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .backgroundColor(WIDGET_COLOR_SURFACE)
            .borderRadius(12)
            .onClick(() => {
              this.openTaskDetail(task.id);
            })
          }, (task: MainWidgetTask) => task.id)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(WIDGET_COLOR_SURFACE_SOFT)
    .borderRadius(16)
  }

  @Builder
  private renderFooterActions() {
    Row({ space: 10 }) {
      Text('专注')
        .layoutWeight(1)
        .height(40)
        .fontSize(14)
        .fontColor(WIDGET_COLOR_SURFACE)
        .textAlign(TextAlign.Center)
        .backgroundColor(WIDGET_COLOR_BLUE_VIBRANT)
        .borderRadius(12)
        .onClick(() => {
          this.openFocusPage();
        })

      Text('创建')
        .layoutWeight(1)
        .height(40)
        .fontSize(14)
        .fontColor(WIDGET_COLOR_BLUE_VIBRANT)
        .textAlign(TextAlign.Center)
        .backgroundColor(WIDGET_COLOR_PRIMARY_SOFT)
        .borderRadius(12)
        .onClick(() => {
          this.openMainPageWithVoiceCreate();
        })
    }
    .width('100%')
  }

  private getVisiblePlanTasks(): MainWidgetTask[] {
    return this.tasks.slice(0, 4);
  }

  private openTodayPlanPage(): void {
    postCardAction(this, buildWidgetRouteAction('pages/TodayPlanPage'));
  }

  private openTaskDetail(taskId: string): void {
    if (!taskId) {
      return;
    }
    postCardAction(this, buildWidgetRouteAction('pages/TaskDetailPage', buildTaskRouteParams(taskId)));
  }

  private openFocusPage(): void {
    postCardAction(this, buildWidgetRouteAction('pages/PomodoroPage'));
  }

  private openMainPageWithVoiceCreate(): void {
    postCardAction(this, buildWidgetRouteAction('pages/MainPage', buildVoiceRouteParams()));
  }
}
