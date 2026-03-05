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
      // 标题栏 - 渐变背景
      Row() {
        Column() {
          Text('📝 待办事项')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          
          Text('管理你的日常任务')
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.8)')
            .margin({ top: 4 })
        }

        Blank()

        // 添加按钮 - 霓虹效果
        Button() {
          Text('+')
            .fontSize(24)
            .fontColor('#FFFFFF')
        }
        .width(44)
        .height(44)
        .background(
          LinearGradient({
            direction: { x1: 0, y1: 0, x2: 1, y2: 1 },
            colors: [['#48BB78', 0], ['#38A169', 1]]
          })
        )
        .borderRadius(22)
        .shadow({
          radius: 12,
          color: 'rgba(72, 187, 120, 0.4)',
          offsetX: 0,
          offsetY: 4
        })
        .onClick(() => {
          router.pushUrl({ url: 'pages/CreateTaskPage' });
        })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 20, bottom: 20 })
      .background(
        LinearGradient({
          direction: { x1: 0, y1: 0, x2: 1, y2: 1 },
          colors: [['#48BB78', 0], ['#38A169', 1]]
        })
      )

      // 筛选器 - 深色风格
      Row() {
        this.FilterButton('全部', 'all')
        this.FilterButton('未完成', 'pending')
        this.FilterButton('已完成', 'completed')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#16213E')

      // 任务列表
      if (this.tasks.length === 0) {
        Column() {
          Text('📝')
            .fontSize(72)
            .margin({ bottom: 20 })
            .opacity(0.8)

          Text('还没有任务')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#A0AEC0')

          Text('点击右上角按钮创建第一个任务')
            .fontSize(14)
            .fontColor('#718096')
            .margin({ top: 8 })
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
    .backgroundColor('#0F0F23')
  }

  @Builder
  FilterButton(label: string, filterValue: string) {
    Button(label)
      .fontSize(14)
      .fontWeight(this.filter === filterValue ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.filter === filterValue ? '#FFFFFF' : 'rgba(255,255,255,0.6)')
      .backgroundColor(this.filter === filterValue ? '#48BB78' : 'rgba(255,255,255,0.08)')
      .borderRadius(16)
      .border({
        width: this.filter === filterValue ? 0 : 1,
        color: 'rgba(255,255,255,0.15)'
      })
      .margin({ left: filterValue === 'all' ? 0 : 8 })
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.filter = filterValue;
        this.loadTasks();
      })
  }

  @Builder
  TaskItem(task: Task) {
    Column() {
      Row() {
        // 完成状态复选框 - 霓虹风格
        Button() {
          Text(task.status === 'completed' ? '✓' : '○')
            .fontSize(18)
            .fontColor(task.status === 'completed' ? '#48BB78' : '#4A5568')
        }
        .width(32)
        .height(32)
        .backgroundColor(task.status === 'completed' ? 'rgba(72, 187, 120, 0.15)' : 'rgba(255,255,255,0.05)')
        .borderRadius(10)
        .border({
          width: 1,
          color: task.status === 'completed' ? '#48BB78' : 'rgba(255,255,255,0.1)'
        })
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
            .fontWeight(FontWeight.Medium)
            .fontColor(task.status === 'completed' ? '#4A5568' : '#FFFFFF')
            .textDecoration(task.status === 'completed' ? TextDecoration.LineThrough : TextDecoration.None)

          Row() {
            Text('🎯 ' + task.goalTitle)
              .fontSize(12)
              .fontColor('rgba(255,255,255,0.6)')

            if (task.dueDate) {
              Text('📅 ' + this.formatDate(task.dueDate))
                .fontSize(12)
                .fontColor(task.isOverdue ? '#FC8181' : 'rgba(255,255,255,0.5)')
                .margin({ left: 12 })
            }
          }
          .margin({ top: 4 })
        }
        .layoutWeight(1)
        .margin({ left: 12 })

        // 编辑按钮
        if (task.status === 'pending') {
          Button() {
            Text('✏️')
              .fontSize(16)
          }
          .width(36)
          .height(36)
          .backgroundColor('rgba(255,255,255,0.08)')
          .borderRadius(10)
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
          .fontColor('rgba(255,255,255,0.6)')
          .width('100%')
          .margin({ top: 8 })
          .lineHeight(20)
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#16213E')
    .borderRadius(14)
    .margin({ bottom: 12 })
    .shadow({
      radius: 10,
      color: 'rgba(0, 0, 0, 0.3)',
      offsetX: 0,
      offsetY: 3
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