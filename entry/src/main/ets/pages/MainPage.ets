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

  // 底部导航栏 - 科技感风格
  @Builder
  BottomNavBar() {
    Row() {
      // 左侧装饰线
      Rectangle()
        .width(2)
        .height(30)
        .backgroundColor('#667EEA')
        .borderRadius(2)
        .margin({ right: 12 })
      
      Column() {
        Text('🏠')
          .fontSize(22)
        Text('首页')
          .fontSize(11)
          .fontColor(this.currentTab === 0 ? '#667EEA' : '#718096')
          .fontWeight(this.currentTab === 0 ? FontWeight.Bold : FontWeight.Normal)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(12)
      .onClick(() => { this.currentTab = 0; })

      Column() {
        Text('📝')
          .fontSize(22)
        Text('待办')
          .fontSize(11)
          .fontColor(this.currentTab === 1 ? '#667EEA' : '#718096')
          .fontWeight(this.currentTab === 1 ? FontWeight.Bold : FontWeight.Normal)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(12)
      .onClick(() => { this.currentTab = 1; })

      Column() {
        Text('📊')
          .fontSize(22)
        Text('统计')
          .fontSize(11)
          .fontColor(this.currentTab === 2 ? '#667EEA' : '#718096')
          .fontWeight(this.currentTab === 2 ? FontWeight.Bold : FontWeight.Normal)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(12)
      .onClick(() => { this.currentTab = 2; })
    }
    .width('100%')
    .height(70)
    .backgroundColor('#1A1A2E')
    .shadow({
      radius: 16,
      color: 'rgba(102, 126, 234, 0.3)',
      offsetX: 0,
      offsetY: -4
    })
  }

  @Builder
  HomeTab() {
    Column() {
      // 顶部标题栏 - 渐变背景
      Row() {
        Column() {
          Text(APP_NAME)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          
          Text('掌控你的人生目标')
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
        .width(48)
        .height(48)
        .borderRadius(24)
        .backgroundColor('#667EEA')
        .shadow({
          radius: 12,
          color: 'rgba(102, 126, 234, 0.5)',
          offsetX: 0,
          offsetY: 4
        })
        .onClick(() => {
          this.showAddDialog = true;
        })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 20, bottom: 20 })
      .background(
        $r('sys.color.theme_color') || 
        LinearGradient({
          direction: { x1: 0, y1: 0, x2: 1, y2: 1 },
          colors: [['#667EEA', 0], ['#764BA2', 1]]
        })
      )

      if (this.goals.length === 0) {
        Column() {
          Text('🎯')
            .fontSize(72)
            .margin({ bottom: 20 })
            .opacity(0.8)

          Text('还没有目标')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#A0AEC0')

          Text('点击右上角 + 号创建你的第一个目标')
            .fontSize(14)
            .fontColor('#718096')
            .margin({ top: 8 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        List({ space: 16 }) {
          ForEach(this.goals, (goal: Goal) => {
            ListItem() {
              this.GoalCard(goal)
            }
          }, (goal: Goal) => goal.id)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(16)
      }

      if (this.showAddDialog) {
        this.AddGoalDialog()
      }
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor('#0F0F23')
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
      StatsPage()
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor('#F5F5F5')
  }

  @Builder
  GoalCard(goal: Goal) {
    Column() {
      // 顶部进度条
      Row() {
        // 分类标签
        Row() {
          Text(CATEGORIES.find((c) => c.value === goal.category)?.icon || '')
            .fontSize(14)
            .margin({ right: 4 })
          
          Text(goal.category)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(20)
        .backgroundColor(CATEGORY_COLORS[goal.category])
        
        Blank()
        
        // 进度百分比
        Text(`${goal.progress}%`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(goal.progress >= 80 ? '#48BB78' : goal.progress >= 50 ? '#4299E1' : '#A0AEC0')
      }
      .width('100%')
      
      // 目标标题
      Text(goal.title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ top: 12, bottom: 8 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      
      // 目标描述
      if (goal.description) {
        Text(goal.description)
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.7)')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(20)
      }
      
      // 进度条
      Row() {
        Progress({ value: goal.progress, total: 100 })
          .width('100%')
          .height(6)
          .color(goal.progress >= 80 ? '#48BB78' : goal.progress >= 50 ? '#667EEA' : '#F6AD55')
          .backgroundColor('rgba(255,255,255,0.1)')
          .borderRadius(3)
      }
      .width('100%')
      .margin({ top: 12, bottom: 8 })
      
      // 关键结果数量
      if (goal.keyResults.length > 0) {
        Row() {
          Text('📋')
            .fontSize(12)
            .margin({ right: 4 })
          
          Text(`${goal.keyResults.length} 个关键结果`)
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.6)')
        }
      }
      
      // 操作按钮
      Row() {
        Button() {
          Text('查看')
            .fontSize(13)
            .fontColor('#FFFFFF')
        }
        .height(32)
        .padding({ left: 16, right: 16 })
        .backgroundColor('rgba(102, 126, 234, 0.3)')
        .borderRadius(16)
        .border({ width: 1, color: 'rgba(102, 126, 234, 0.5)' })
        .onClick(() => {
          router.pushUrl({
            'url': 'pages/GoalDetailPage',
            'params': { goalId: goal.id }
          });
        })
        
        Button() {
          Text('删除')
            .fontSize(13)
            .fontColor('#FC8181')
        }
        .height(32)
        .padding({ left: 16, right: 16 })
        .backgroundColor('rgba(245, 101, 101, 0.15)')
        .borderRadius(16)
        .border({ width: 1, color: 'rgba(245, 101, 101, 0.3)' })
        .margin({ left: 12 })
        .onClick(() => {
          this.deleteGoal(goal);
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#16213E')
    .borderRadius(16)
    .shadow({
      radius: 12,
      color: 'rgba(0, 0, 0, 0.3)',
      offsetX: 0,
      offsetY: 4
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
        .backgroundColor('rgba(0,0,0,0.7)')
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showAddDialog = false;
          this.resetForm();
        })

      Column() {
        // 标题
        Row() {
          Text('🎯')
            .fontSize(24)
            .margin({ right: 8 })
          
          Text('创建新目标')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width('100%')
        .margin({ bottom: 24 })
        
        // 输入框 - 标题
        Column() {
          Text('目标标题')
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.7)')
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)
          
          TextInput({ placeholder: '例如：3 个月内存 5 万元', text: this.newGoalTitle })
            .width('100%')
            .height(50)
            .fontSize(15)
            .padding(14)
            .backgroundColor('rgba(255,255,255,0.1)')
            .borderRadius(12)
            .fontColor('#FFFFFF')
            .placeholderColor('rgba(255,255,255,0.4)')
            .onChange((value: string) => {
              this.newGoalTitle = value;
            })
        }
        .width('100%')
        .margin({ bottom: 16 })
        
        // 输入框 - 描述
        Column() {
          Text('目标描述（可选）')
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.7)')
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)
          
          TextInput({ placeholder: '详细描述你的目标', text: this.newGoalDescription })
            .width('100%')
            .height(50)
            .fontSize(15)
            .padding(14)
            .backgroundColor('rgba(255,255,255,0.1)')
            .borderRadius(12)
            .fontColor('#FFFFFF')
            .placeholderColor('rgba(255,255,255,0.4)')
            .onChange((value: string) => {
              this.newGoalDescription = value;
            })
        }
        .width('100%')
        .margin({ bottom: 20 })
        
        // 分类选择
        Text('选择分类')
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.7)')
          .margin({ bottom: 12 })
          .alignSelf(ItemAlign.Start)
        
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(CATEGORIES, (category: CategoryInfo) => {
            Row() {
              Text(category.icon)
                .fontSize(14)
                .margin({ right: 6 })
              
              Text(category.label)
                .fontSize(13)
                .fontWeight(this.selectedCategory === category.value ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.selectedCategory === category.value ? '#FFFFFF' : 'rgba(255,255,255,0.7)')
            }
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .backgroundColor(this.selectedCategory === category.value ? category.color : 'rgba(255,255,255,0.08)')
            .borderRadius(20)
            .border({
              width: this.selectedCategory === category.value ? 0 : 1,
              color: 'rgba(255,255,255,0.2)'
            })
            .margin({ right: 10, bottom: 10 })
            .onClick(() => {
              this.selectedCategory = category.value;
            })
          })
        }
        .width('100%')
        .margin({ top: 8, bottom: 24 })
        
        // 按钮
        Row() {
          Button('取消')
            .fontSize(15)
            .fontColor('rgba(255,255,255,0.7)')
            .backgroundColor('rgba(255,255,255,0.1)')
            .onClick(() => {
              this.showAddDialog = false;
              this.resetForm();
            })
          
          Button('创建')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .background(
              LinearGradient({
                direction: { x1: 0, y1: 0, x2: 1, y2: 0 },
                colors: [['#667EEA', 0], ['#764BA2', 1]]
              })
            )
            .enabled(this.newGoalTitle.trim() !== '')
            .shadow({
              radius: 12,
              color: 'rgba(102, 126, 234, 0.5)',
              offsetX: 0,
              offsetY: 4
            })
            .margin({ left: 16 })
            .onClick(() => {
              this.createGoal();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
      .width('92%')
      .padding(28)
      .background(
        LinearGradient({
          direction: { x1: 0, y1: 0, x2: 1, y2: 1 },
          colors: [['#1A1A2E', 0], ['#16213E', 1]]
        })
      )
      .borderRadius(20)
      .shadow({
        radius: 24,
        color: 'rgba(0, 0, 0, 0.5)',
        offsetX: 0,
        offsetY: 8
      })
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