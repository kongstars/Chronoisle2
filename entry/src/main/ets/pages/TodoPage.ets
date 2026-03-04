import { Task, TaskStatus } from '../models/Task';
import { db } from '../storage/Database';
import router from '@ohos.router';

@Entry
@Component
struct TodoPage {
  @State tasks: Task[] = [];
  @State filter: string = 'all';

  aboutToAppear(): void {
    let context = getContext(this);
    db.initialize(context).then(() => {
      this.loadTasks();
    });
  }

  loadTasks(): void {
    if (this.filter === 'pending') {
      this.tasks = db.getPendingTasks();
    } else if (this.filter === 'completed') {
      this.tasks = db.getCompletedTasks();
    } else {
      this.tasks = db.getAllTasks();
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('待办事项')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')

        Blank()

        Button() {
          Text('+')
            .fontSize(28)
            .fontColor('#FFFFFF')
        }
        .width(44)
        .height(44)
        .backgroundColor('#4CAF50')
        .borderRadius(22)
        .onClick(() => {
          router.pushUrl({ url: 'pages/CreateTaskPage' });
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })
      .backgroundColor('#FFFFFF')

      // 筛选器
      Row() {
        Button('全部')
          .fontSize(14)
          .fontColor(this.filter === 'all' ? '#FFFFFF' : '#666')
          .backgroundColor(this.filter === 'all' ? '#4CAF50' : '#F5F5F5')
          .onClick(() => {
            this.filter = 'all';
            this.loadTasks();
          })

        Button('未完成')
          .fontSize(14)
          .fontColor(this.filter === 'pending' ? '#FFFFFF' : '#666')
          .backgroundColor(this.filter === 'pending' ? '#FF9800' : '#F5F5F5')
          .margin({ left: 8 })
          .onClick(() => {
            this.filter = 'pending';
            this.loadTasks();
          })

        Button('已完成')
          .fontSize(14)
          .fontColor(this.filter === 'completed' ? '#FFFFFF' : '#666')
          .backgroundColor(this.filter === 'completed' ? '#4CAF50' : '#F5F5F5')
          .margin({ left: 8 })
          .onClick(() => {
            this.filter = 'completed';
            this.loadTasks();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#F9F9F9')

      // 任务列表
      if (this.tasks.length === 0) {
        Column() {
          Text('📝')
            .fontSize(64)
            .margin({ bottom: 16 })

          Text('还没有任务')
            .fontSize(18)
            .fontColor('#999')
            .margin({ bottom: 8 })

          Text('点击右上角按钮创建第一个任务')
            .fontSize(14)
            .fontColor('#CCC')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.tasks, (task: Task) => {
              this.TaskItem(task)
            }, (task: Task) => task.id)
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  TaskItem(task: Task) {
    Column() {
      Row() {
        // 完成状态复选框
        Button() {
          Text(task.status === 'completed' ? '✓' : '○')
            .fontSize(20)
            .fontColor(task.status === 'completed' ? '#4CAF50' : '#CCC')
        }
        .width(32)
        .height(32)
        .backgroundColor('transparent')
        .onClick(() => {
          if (task.status === 'completed') {
            task.uncomplete();
          } else {
            task.complete();
          }
          db.updateTask(task).then(() => {
            this.loadTasks();
          });
        })

        // 任务信息
        Column() {
          Text(task.title)
            .fontSize(16)
            .fontColor(task.status === 'completed' ? '#999' : '#333')
            .textDecoration(task.status === 'completed' ? TextDecoration.LineThrough : TextDecoration.None)

          Row() {
            Text('🎯 ' + task.goalTitle)
              .fontSize(12)
              .fontColor('#666')

            if (task.dueDate) {
              Text('📅 ' + this.formatDate(task.dueDate))
                .fontSize(12)
                .fontColor(task.isOverdue ? '#FF5722' : '#999')
                .margin({ left: 12 })
            }
          }
          .margin({ top: 4 })
        }
        .layoutWeight(1)
        .margin({ left: 12 })

        // 编辑按钮（仅未完成可编辑）
        if (task.status === 'pending') {
          Button() {
            Text('✏️')
              .fontSize(16)
          }
          .width(36)
          .height(36)
          .backgroundColor('transparent')
          .onClick(() => {
            router.pushUrl({
              url: 'pages/CreateTaskPage',
              params: { taskId: task.id }
            });
          })
        }
      }
      .width('100%')

      if (task.description) {
        Text(task.description)
          .fontSize(14)
          .fontColor('#666')
          .width('100%')
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 12 })
    .shadow({
      radius: 4,
      color: 'rgba(0,0,0,0.05)',
      offsetX: 0,
      offsetY: 2
    })
  }

  formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    return `${year}-${month.toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}`;
  }
}