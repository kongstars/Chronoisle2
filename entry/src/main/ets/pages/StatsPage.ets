import { db } from '../storage/Database';
import { statsService, CategoryStat } from '../services/StatsService';
import { GoalCategory } from '../models/Goal';

@Entry
@Component
struct StatsPage {
  @State totalGoals: number = 0;
  @State completedGoals: number = 0;
  @State goalCompletionRate: number = 0;
  
  @State totalTasks: number = 0;
  @State completedTasks: number = 0;
  @State taskCompletionRate: number = 0;
  
  @State categoryStats: CategoryStat[] = [];
  @State showCategoryDetail: boolean = false;
  @State selectedCategory: CategoryStat | null = null;

  aboutToAppear(): void {
    this.loadStats();
  }

  loadStats(): void {
    let context = getContext(this);
    db.initialize(context).then(() => {
      const goals = db.getAllGoals();
      const tasks = db.getAllTasks();
      const stats = statsService.calculateStats(goals, tasks);
      
      this.totalGoals = stats.totalGoals;
      this.completedGoals = stats.completedGoals;
      this.goalCompletionRate = stats.goalCompletionRate;
      
      this.totalTasks = stats.totalTasks;
      this.completedTasks = stats.completedTasks;
      this.taskCompletionRate = stats.taskCompletionRate;
      
      this.categoryStats = stats.categoryStats;
    });
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('📊 数据统计')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        
        Blank()
        
        Button() {
          Text('🔄')
            .fontSize(18)
        }
        .width(40)
        .height(40)
        .backgroundColor('transparent')
        .onClick(() => {
          this.loadStats();
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 15, bottom: 15 })
      .backgroundColor('#FFFFFF')

      Scroll() {
        Column() {
          // 核心指标卡片
          this.OverviewCards()
          
          // 目标完成率
          this.GoalProgressSection()
          
          // 任务完成情况
          this.TaskProgressSection()
          
          // 分类统计
          this.CategorySection()
          
          // 趋势图表
          this.TrendSection()
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
      
      // 分类详情对话框
      if (this.showCategoryDetail && this.selectedCategory) {
        this.CategoryDetailDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  // 核心指标概览
  @Builder
  OverviewCards() {
    Row() {
      // 目标卡片
      Column() {
        Text('🎯')
          .fontSize(32)
          .margin({ bottom: 8 })
        
        Text(`${this.totalGoals}`)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4CAF50')
        
        Text('总目标')
          .fontSize(14)
          .fontColor('#666')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ right: 8 })
      .shadow({
        radius: 4,
        color: 'rgba(0,0,0,0.05)',
        offsetX: 0,
        offsetY: 2
      })
      
      // 任务卡片
      Column() {
        Text('✅')
          .fontSize(32)
          .margin({ bottom: 8 })
        
        Text(`${this.totalTasks}`)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2196F3')
        
        Text('总任务')
          .fontSize(14)
          .fontColor('#666')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
      .margin({ left: 8 })
      .shadow({
        radius: 4,
        color: 'rgba(0,0,0,0.05)',
        offsetX: 0,
        offsetY: 2
      })
    }
    .width('100%')
    .margin({ bottom: 16 })
  }

  // 目标完成率
  @Builder
  GoalProgressSection() {
    Column() {
      Row() {
        Text('目标完成情况')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        
        Blank()
        
        Text(`${this.completedGoals}/${this.totalGoals}`)
          .fontSize(14)
          .fontColor('#666')
      }
      .width('100%')
      .margin({ bottom: 12 })
      
      Row() {
        // 进度条
        Column() {
          Progress({ value: this.goalCompletionRate, total: 100 })
            .width('100%')
            .height(12)
            .color('#4CAF50')
            .backgroundColor('#E8F5E9')
          
          Row() {
            Text(`${this.goalCompletionRate}% 完成`)
              .fontSize(14)
              .fontColor('#666')
            
            Blank()
            
            Text(`未完成：${this.totalGoals - this.completedGoals}`)
              .fontSize(12)
              .fontColor('#999')
          }
          .width('100%')
          .margin({ top: 8 })
        }
        .layoutWeight(1)
        
        // 完成数
        Column() {
          Text(`${this.completedGoals}`)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4CAF50')
          
          Text('已完成')
            .fontSize(12)
            .fontColor('#666')
        }
        .width(80)
        .alignItems(HorizontalAlign.Center)
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
    }
    .width('100%')
    .margin({ bottom: 16 })
  }

  // 任务完成情况
  @Builder
  TaskProgressSection() {
    Column() {
      Row() {
        Text('任务完成情况')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        
        Blank()
        
        Text(`${this.completedTasks}/${this.totalTasks}`)
          .fontSize(14)
          .fontColor('#666')
      }
      .width('100%')
      .margin({ bottom: 12 })
      
      Row() {
        Column() {
          Progress({ value: this.taskCompletionRate, total: 100 })
            .width('100%')
            .height(12)
            .color('#2196F3')
            .backgroundColor('#E3F2FD')
          
          Row() {
            Text(`${this.taskCompletionRate}% 完成`)
              .fontSize(14)
              .fontColor('#666')
            
            Blank()
            
            Text(`待完成：${this.totalTasks - this.completedTasks}`)
              .fontSize(12)
              .fontColor('#999')
          }
          .width('100%')
          .margin({ top: 8 })
        }
        .layoutWeight(1)
        
        Column() {
          Text(`${this.completedTasks}`)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2196F3')
          
          Text('已完成')
            .fontSize(12)
            .fontColor('#666')
        }
        .width(80)
        .alignItems(HorizontalAlign.Center)
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
    }
    .width('100%')
    .margin({ bottom: 16 })
  }

  // 分类统计
  @Builder
  CategorySection() {
    Column() {
      Row() {
        Text('分类统计')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        
        Blank()
      }
      .width('100%')
      .margin({ bottom: 12 })
      
      ForEach(this.categoryStats, (category: CategoryStat) => {
        this.CategoryCard(category)
      }, (category: CategoryStat) => category.category)
    }
    .width('100%')
    .margin({ bottom: 16 })
  }

  @Builder
  CategoryCard(category: CategoryStat) {
    Column() {
      Row() {
        // 图标和名称
        Row() {
          Text(category.icon)
            .fontSize(24)
            .margin({ right: 8 })
          
          Column() {
            Text(category.categoryName)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333')
            
            Text(`${category.totalGoals} 个目标 · ${category.totalTasks} 个任务`)
              .fontSize(12)
              .fontColor('#999')
              .margin({ top: 2 })
          }
        }
        .layoutWeight(1)
        
        // 完成率
        Column() {
          Text(`${category.completionRate}%`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(category.completionRate >= 50 ? '#4CAF50' : '#FF9800')
          
          Text('完成率')
            .fontSize(11)
            .fontColor('#999')
        }
        .width(60)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      
      // 迷你进度条
      Progress({ value: category.completionRate, total: 100 })
        .width('100%')
        .height(6)
        .color(category.color)
        .backgroundColor('#F5F5F5')
        .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 8 })
    .shadow({
      radius: 4,
      color: 'rgba(0,0,0,0.05)',
      offsetX: 0,
      offsetY: 2
    })
    .onClick(() => {
      if (category.totalGoals > 0) {
        this.selectedCategory = category;
        this.showCategoryDetail = true;
      }
    })
  }

  // 趋势图表
  @Builder
  TrendSection() {
    Column() {
      Row() {
        Text('最近 7 天趋势')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        
        Blank()
      }
      .width('100%')
      .margin({ bottom: 12 })
      
      Column() {
        // 简单的柱状图
        Row() {
          Text('目标')
            .fontSize(12)
            .fontColor('#4CAF50')
            .margin({ right: 12 })
          
          Text('任务')
            .fontSize(12)
            .fontColor('#2196F3')
        }
        .width('100%')
        .margin({ bottom: 12 })
        
        // 这里可以添加更复杂的图表，目前用简单柱状图
        Text('📈 趋势图开发中')
          .fontSize(14)
          .fontColor('#999')
          .margin({ top: 20, bottom: 20 })
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
    }
    .width('100%')
  }

  // 分类详情对话框
  @Builder
  CategoryDetailDialog() {
    if (this.selectedCategory) {
      Column() {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.5)')
          .position({ x: 0, y: 0 })
          .onClick(() => {
            this.showCategoryDetail = false;
            this.selectedCategory = null;
          })
        
        Column() {
          Row() {
            Text(this.selectedCategory!.icon)
              .fontSize(32)
              .margin({ right: 12 })
            
            Text(this.selectedCategory!.categoryName)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
            
            Blank()
            
            Button() {
              Text('×')
                .fontSize(20)
                .fontColor('#666')
            }
            .width(32)
            .height(32)
            .backgroundColor('transparent')
            .onClick(() => {
              this.showCategoryDetail = false;
              this.selectedCategory = null;
            })
          }
          .width('100%')
          .margin({ bottom: 20 })
          
          // 统计信息
          Column() {
            this.StatRow('总目标数', `${this.selectedCategory!.totalGoals} 个`)
            this.StatRow('已完成目标', `${this.selectedCategory!.completedGoals} 个`)
            this.StatRow('目标完成率', `${this.selectedCategory!.completionRate}%`)
            this.StatRow('总任务数', `${this.selectedCategory!.totalTasks} 个`)
            this.StatRow('已完成任务', `${this.selectedCategory!.completedTasks} 个`)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F9F9F9')
          .borderRadius(12)
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
  }

  @Builder
  StatRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#666')
      
      Blank()
      
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333')
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }
}
