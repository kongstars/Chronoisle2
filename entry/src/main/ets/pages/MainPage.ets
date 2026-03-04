import { Goal, KeyResult, GoalCategory } from '../models/Goal';
import { Task } from '../models/Task';
import { db } from '../storage/Database';
import { CATEGORIES, CATEGORY_COLORS, APP_NAME, CategoryInfo } from '../common/Constants';
import router from '@ohos.router';

@Entry
@Component
struct MainPage {
  @State goals: Goal[] = [];
  @State showAddDialog: boolean = false;
  @State newGoalTitle: string = '';
  @State selectedCategory: GoalCategory = GoalCategory.CAREER;
  @State newGoalDescription: string = '';
  @State currentTab: number = 0;

  aboutToAppear(): void {
    let context = getContext(this);
    db.initialize(context).then(() => {
      this.goals = db.getAllGoals();
    });
  }

  build() {
    Column() {
      // 页面内容
      if (this.currentTab === 0) {
        this.HomeTab()
      } else if (this.currentTab === 1) {
        this.TodoTab()
      } else if (this.currentTab === 2) {
        this.StatsTab()
      }

      // 底部导航栏
      this.BottomNavBar()
    }
    .width('100%')
    .height('100%')
  }

  // 底部导航栏
  @Builder
  BottomNavBar() {
    Row() {
      Column() {
        Text('🏠')
          .fontSize(24)
        Text('首页')
          .fontSize(12)
          .fontColor(this.currentTab === 0 ? '#4CAF50' : '#999')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(12)
      .backgroundColor(this.currentTab === 0 ? '#FFFFFF' : '#F9F9F9')
      .onClick(() => { this.currentTab = 0; })

      Column() {
        Text('📝')
          .fontSize(24)
        Text('待办')
          .fontSize(12)
          .fontColor(this.currentTab === 1 ? '#4CAF50' : '#999')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(12)
      .backgroundColor(this.currentTab === 1 ? '#FFFFFF' : '#F9F9F9')
      .onClick(() => { this.currentTab = 1; })

      Column() {
        Text('📊')
          .fontSize(24)
        Text('统计')
          .fontSize(12)
          .fontColor(this.currentTab === 2 ? '#4CAF50' : '#999')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(12)
      .backgroundColor(this.currentTab === 2 ? '#FFFFFF' : '#F9F9F9')
      .onClick(() => { this.currentTab = 2; })
    }
    .width('100%')
    .height(60)
    .backgroundColor('#FFFFFF')
    .shadow({
      radius: 8,
      color: 'rgba(0,0,0,0.1)',
      offsetX: 0,
      offsetY: -2
    })
  }

  @Builder
  HomeTab() {
    Column() {
      Row() {
        Text(APP_NAME)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')

        Blank()
        Button() {
          Text('+')
            .fontSize(20)
            .fontColor('#FFFFFF')
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor('#4CAF50')
        .onClick(() => {
          this.showAddDialog = true;
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 15, bottom: 15 })
      .backgroundColor('#FFFFFF')

      if (this.goals.length === 0) {
        Column() {
          Text('🎯')
            .fontSize(64)
            .margin({ bottom: 16 })

          Text('还没有目标')
            .fontSize(18)
            .fontColor('#999')

          Text('点击右上角 + 号创建你的第一个目标')
            .fontSize(14)
            .fontColor('#CCC')
            .margin({ top: 8 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        List({ space: 12 }) {
          ForEach(this.goals, (goal: Goal) => {
            ListItem() {
              this.GoalCard(goal)
            }
          }, (goal: Goal) => goal.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(12)
      }

      if (this.showAddDialog) {
        this.AddGoalDialog()
      }
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor('#F5F5F5')
  }

  @Builder
  TodoTab() {
    Column() {
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
      .padding({ left: 20, right: 20, top: 15, bottom: 15 })
      .backgroundColor('#FFFFFF')

      TodoContent()
        .layoutWeight(1)
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor('#F5F5F5')
  }

  @Builder
  StatsTab() {
    Column() {
      Row() {
        Text('统计')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 15, bottom: 15 })
      .backgroundColor('#FFFFFF')

      Column() {
        Text('📈')
          .fontSize(64)
          .margin({ bottom: 16 })

        Text('统计功能开发中')
          .fontSize(18)
          .fontColor('#999')

        Text('敬请期待')
          .fontSize(14)
          .fontColor('#CCC')
          .margin({ top: 8 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor('#F5F5F5')
  }

  @Builder
  GoalCard(goal: Goal) {
    Column() {
      Row() {
        Column() {
          Row() {
            Text(CATEGORIES.find((c) => c.value === goal.category)?.icon || '')
              .fontSize(12)
              .margin({ right: 4 })

            Text(goal.category)
              .fontSize(12)
              .fontColor('#FFFFFF')
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(12)
          .backgroundColor(CATEGORY_COLORS[goal.category])

          Text(goal.title)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .margin({ top: 12 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (goal.description) {
            Text(goal.description)
              .fontSize(14)
              .fontColor('#666')
              .margin({ top: 8 })
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          Text(`${goal.progress}%`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4CAF50')

          Text('进度')
            .fontSize(12)
            .fontColor('#999')
            .margin({ top: 4 })
        }
        .width(60)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')

      if (goal.keyResults.length > 0) {
        Row() {
          Text(`📋 ${goal.keyResults.length} 个关键结果`)
            .fontSize(12)
            .fontColor('#999')
        }
        .width('100%')
        .margin({ top: 12 })
      }

      Row() {
        Button('查看')
          .fontSize(14)
          .fontColor('#2196F3')
          .backgroundColor('#E3F2FD')
          .onClick(() => {
            router.pushUrl({
              'url': 'pages/GoalDetailPage',
              'params': { goalId: goal.id }
            });
          })

        Button('删除')
          .fontSize(14)
          .fontColor('#FF5722')
          .backgroundColor('#FFEBEE')
          .margin({ left: 12 })
          .onClick(() => {
            this.deleteGoal(goal);
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({
      radius: 4,
      color: 'rgba(0,0,0,0.05)',
      offsetX: 0,
      offsetY: 2
    })
    .onClick(() => {
      router.pushUrl({
        'url': 'pages/GoalDetailPage',
        'params': { goalId: goal.id }
      });
    })
  }

  @Builder
  AddGoalDialog() {
    Column() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showAddDialog = false;
          this.resetForm();
        })

      Column() {
        Text('创建新目标')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .margin({ bottom: 20 })

        TextInput({ placeholder: '目标标题，例如：3 个月内存 5 万元', text: this.newGoalTitle })
          .width('100%')
          .height(50)
          .fontSize(16)
          .padding(12)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .onChange((value: string) => {
            this.newGoalTitle = value;
          })

        TextInput({ placeholder: '目标描述（可选）', text: this.newGoalDescription })
          .width('100%')
          .height(50)
          .fontSize(16)
          .padding(12)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .margin({ top: 12 })
          .onChange((value: string) => {
            this.newGoalDescription = value;
          })

        Text('选择分类')
          .fontSize(14)
          .fontColor('#666')
          .margin({ top: 16, bottom: 8 })
          .alignSelf(ItemAlign.Start)
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(CATEGORIES, (category: CategoryInfo) => {
            Text(category.label)
              .fontSize(14)
              .fontColor(this.selectedCategory === category.value ? '#FFFFFF' : '#333')
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor(this.selectedCategory === category.value ? category.color : '#F5F5F5')
              .borderRadius(20)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.selectedCategory = category.value;
              })
          })
        }
        .width('100%')

        Row() {
          Button('取消')
            .fontSize(16)
            .fontColor('#666')
            .backgroundColor('#F5F5F5')
            .onClick(() => {
              this.showAddDialog = false;
              this.resetForm();
            })

          Button('创建')
            .fontSize(16)
            .fontColor('#FFFFFF')
            .backgroundColor('#4CAF50')
            .margin({ left: 12 })
            .enabled(this.newGoalTitle.trim() !== '')
            .onClick(() => {
              this.createGoal();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
        .margin({ top: 20 })
      }
      .width('90%')
      .padding(24)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .position({ x: 0, y: 0 })
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
  }

  createGoal(): void {
    if (this.newGoalTitle.trim() === '') {
      return;
    }

    const goal = new Goal(this.newGoalTitle.trim(), this.selectedCategory, this.newGoalDescription.trim());
    db.addGoal(goal).then(() => {
      this.goals = db.getAllGoals();
      this.showAddDialog = false;
      this.resetForm();
    });
  }

  deleteGoal(goal: Goal): void {
    db.deleteGoal(goal.id).then(() => {
      this.goals = db.getAllGoals();
    });
  }

  resetForm(): void {
    this.newGoalTitle = '';
    this.newGoalDescription = '';
    this.selectedCategory = GoalCategory.CAREER;
  }
}

// 待办内容组件
@Component
struct TodoContent {
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

  completeTask(task: Task): void {
    if (task.status === 'completed') {
      task.uncomplete();
    } else {
      task.complete();
    }
    db.updateTask(task).then(() => {
      this.loadTasks();
    });
  }

  build() {
    Column() {
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

      if (this.tasks.length === 0) {
        Column() {
          Text('📝')
            .fontSize(48)
            .margin({ bottom: 12 })

          Text('还没有任务')
            .fontSize(16)
            .fontColor('#999')

          Text('点击右上角 + 号创建第一个任务')
            .fontSize(14)
            .fontColor('#CCC')
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
    .backgroundColor('#F5F5F5')
  }

  @Builder
  TaskItem(task: Task) {
    Column() {
      Row() {
        Button() {
          Text(task.status === 'completed' ? '✓' : '○')
            .fontSize(20)
            .fontColor(task.status === 'completed' ? '#4CAF50' : '#CCC')
        }
        .width(32)
        .height(32)
        .backgroundColor('transparent')
        .onClick(() => {
          this.completeTask(task);
        })

        Column() {
          Text(task.title)
            .fontSize(16)
            .fontColor(task.status === 'completed' ? '#999' : '#333')
            .decoration({ type: task.status === 'completed' ? TextDecorationType.LineThrough : TextDecorationType.None })

          Row() {
            Text('🎯 ' + task.goalTitle)
              .fontSize(12)
              .fontColor('#666')

            if (task.dueDate) {
              Text('📅 ' + this.formatDate(task.dueDate))
                .fontSize(12)
                .fontColor('#999')
                .margin({ left: 12 })
            }
          }
          .margin({ top: 4 })
        }
        .layoutWeight(1)
        .margin({ left: 12 })
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