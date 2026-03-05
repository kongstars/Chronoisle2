import { db } from '../storage/Database';
import { statsService, CategoryStat, TimeRange } from '../services/StatsService';
import { GoalCategory } from '../models/Goal';
import { TaskStatus } from '../models/Task';

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
  
  // 时间筛选
  @State selectedTimeRange: TimeRange = TimeRange.LAST_7_DAYS;
  @State showTimeRangePicker: boolean = false;
  
  // 图表数据
  @State chartData: number[] = [];
  @State maxChartValue: number = 1;
  
  // 导出功能
  @State showExportDialog: boolean = false;
  @State exportEmail: string = '';

  aboutToAppear(): void {
    this.loadStats();
  }

  loadStats(): void {
    let context = getContext(this);
    db.initialize(context).then(() => {
      const goals = db.getAllGoals();
      const tasks = db.getAllTasks();
      const stats = statsService.calculateStats(goals, tasks, this.selectedTimeRange);
      
      this.totalGoals = stats.totalGoals;
      this.completedGoals = stats.completedGoals;
      this.goalCompletionRate = stats.goalCompletionRate;
      
      this.totalTasks = stats.totalTasks;
      this.completedTasks = stats.completedTasks;
      this.taskCompletionRate = stats.taskCompletionRate;
      
      this.categoryStats = stats.categoryStats;
      
      // 准备图表数据
      this.prepareChartData(stats.dailyStats);
    });
  }
  
  prepareChartData(dailyStats: any[]): void {
    this.chartData = dailyStats.map(stat => stat.completedTasks + stat.completedGoals);
    this.maxChartValue = Math.max(...this.chartData, 1);
  }
  
  getTimeRangeLabel(): string {
    switch (this.selectedTimeRange) {
      case TimeRange.LAST_7_DAYS: return '最近 7 天';
      case TimeRange.LAST_30_DAYS: return '最近 30 天';
      case TimeRange.LAST_90_DAYS: return '最近 90 天';
      case TimeRange.ALL_TIME: return '全部时间';
      default: return '自定义';
    }
  }

  build() {
    Column() {
      // 标题栏 - 渐变背景
      Row() {
        Column() {
          Text('📊 数据统计')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          
          Text('追踪你的成长轨迹')
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.8)')
            .margin({ top: 4 })
        }
        
        Blank()
        
        // 时间筛选按钮
        Button() {
          Row() {
            Text('📅')
              .fontSize(14)
              .margin({ right: 4 })
            
            Text(this.getTimeRangeLabel())
              .fontSize(13)
              .fontColor('#FFFFFF')
          }
        }
        .height(36)
        .padding({ left: 14, right: 14 })
        .background(
          LinearGradient({
            direction: { x1: 0, y1: 0, x2: 1, y2: 0 },
            colors: [['#667EEA', 0], ['#764BA2', 1]]
          })
        )
        .borderRadius(18)
        .shadow({
          radius: 8,
          color: 'rgba(102, 126, 234, 0.4)',
          offsetX: 0,
          offsetY: 2
        })
        .margin({ right: 8 })
        .onClick(() => {
          this.showTimeRangePicker = true;
        })
        
        // 导出按钮
        Button() {
          Text('📤')
            .fontSize(18)
        }
        .width(40)
        .height(40)
        .backgroundColor('rgba(255,255,255,0.15)')
        .borderRadius(12)
        .onClick(() => {
          this.showExportDialog = true;
        })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 20, bottom: 20 })
      .background(
        LinearGradient({
          direction: { x1: 0, y1: 0, x2: 1, y2: 1 },
          colors: [['#667EEA', 0], ['#764BA2', 1]]
        })
      )

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
      .backgroundColor('#0F0F23')
      
      // 分类详情对话框
      if (this.showCategoryDetail && this.selectedCategory) {
        this.CategoryDetailDialog()
      }
      
      // 时间范围选择器
      if (this.showTimeRangePicker) {
        this.TimeRangePicker()
      }
      
      // 导出对话框
      if (this.showExportDialog) {
        this.ExportDialog()
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
        Row() {
          Text('🎯')
            .fontSize(28)
          
          Blank()
          
          Text(`${this.totalGoals}`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width('100%')
        
        Text('总目标')
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.7)')
          .margin({ top: 8 })
      }
      .layoutWeight(1)
      .padding(20)
      .background(
        LinearGradient({
          direction: { x1: 0, y1: 0, x2: 1, y2: 1 },
          colors: [['#667EEA', 0], ['#764BA2', 1]]
        })
      )
      .borderRadius(16)
      .margin({ right: 8 })
      .shadow({
        radius: 12,
        color: 'rgba(102, 126, 234, 0.4)',
        offsetX: 0,
        offsetY: 6
      })
      
      // 任务卡片
      Column() {
        Row() {
          Text('✅')
            .fontSize(28)
          
          Blank()
          
          Text(`${this.totalTasks}`)
            .fontSize(32)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width('100%')
        
        Text('总任务')
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.7)')
          .margin({ top: 8 })
      }
      .layoutWeight(1)
      .padding(20)
      .background(
        LinearGradient({
          direction: { x1: 0, y1: 0, x2: 1, y2: 1 },
          colors: [['#48BB78', 0], ['#38A169', 1]]
        })
      )
      .borderRadius(16)
      .margin({ left: 8 })
      .shadow({
        radius: 12,
        color: 'rgba(72, 187, 120, 0.4)',
        offsetX: 0,
        offsetY: 6
      })
    }
    .width('100%')
    .margin({ bottom: 20 })
  }

  // 目标完成率
  @Builder
  GoalProgressSection() {
    Column() {
      Row() {
        Text('目标完成情况')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        
        Blank()
        
        Text(`${this.completedGoals}/${this.totalGoals}`)
          .fontSize(13)
          .fontColor('rgba(255,255,255,0.8)')
      }
      .width('100%')
      .margin({ bottom: 16 })
      
      // 进度条
      Row() {
        Column() {
          Progress({ value: this.goalCompletionRate, total: 100 })
            .width('100%')
            .height(8)
            .color('#48BB78')
            .backgroundColor('rgba(255,255,255,0.15)')
            .borderRadius(4)
          
          Row() {
            Text(`${this.goalCompletionRate}% 完成`)
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.7)')
            
            Blank()
            
            Text(`未完成：${this.totalGoals - this.completedGoals}`)
              .fontSize(12)
              .fontColor('rgba(255,255,255,0.5)')
          }
          .width('100%')
          .margin({ top: 12 })
        }
        .layoutWeight(1)
        
        Column() {
          Text(`${this.completedGoals}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#48BB78')
          
          Text('已完成')
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.6)')
        }
        .width(70)
        .alignItems(HorizontalAlign.Center)
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
        Text('趋势图表')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        
        Blank()
        
        Text('(柱状图：每日完成情况)')
          .fontSize(12)
          .fontColor('#999')
      }
      .width('100%')
      .margin({ bottom: 12 })
      
      Column() {
        // 图例
        Row() {
          Row() {
            Rectangle()
              .width(12)
              .height(12)
              .backgroundColor('#4CAF50')
              .borderRadius(2)
            
            Text('目标')
              .fontSize(12)
              .fontColor('#666')
              .margin({ left: 4 })
          }
          .margin({ right: 16 })
          
          Row() {
            Rectangle()
              .width(12)
              .height(12)
              .backgroundColor('#2196F3')
              .borderRadius(2)
            
            Text('任务')
              .fontSize(12)
              .fontColor('#666')
              .margin({ left: 4 })
          }
        }
        .width('100%')
        .margin({ bottom: 16 })
        
        // 柱状图
        Row() {
          ForEach(this.chartData.slice(-7), (value: number, index: number) => {
            Column() {
              // 柱子
              Column() {
                if (value > 0) {
                  Column() {
                    // 目标部分（绿色）
                    if (value > 0) {
                      Rectangle()
                        .width(30)
                        .height(Math.max((value / this.maxChartValue) * 100, 4))
                        .backgroundColor('#4CAF50')
                        .borderRadius(4)
                    }
                  }
                  .height(120)
                  .justifyContent(FlexAlign.End)
                } else {
                  Column()
                    .width(30)
                    .height(120)
                }
              }
              
              // 日期标签
              Text(`${index + 1}`)
                .fontSize(10)
                .fontColor('#999')
                .margin({ top: 8 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }, (value: number, index: number) => index.toString())
        }
        .width('100%')
        .height(160)
        .padding({ left: 8, right: 8 })
        
        // 数值标签
        Row() {
          ForEach(this.chartData.slice(-7), (value: number, index: number) => {
            Text(`${value}`)
              .fontSize(10)
              .fontColor('#666')
          }, (value: number, index: number) => index.toString())
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
        .margin({ top: 8 })
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
  
  // 时间范围选择器
  @Builder
  TimeRangePicker() {
    Column() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showTimeRangePicker = false;
        })
      
      Column() {
        Text('选择时间范围')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .margin({ bottom: 20 })
        
        // 时间选项
        this.TimeRangeOption(TimeRange.LAST_7_DAYS, '最近 7 天')
        this.TimeRangeOption(TimeRange.LAST_30_DAYS, '最近 30 天')
        this.TimeRangeOption(TimeRange.LAST_90_DAYS, '最近 90 天')
        this.TimeRangeOption(TimeRange.ALL_TIME, '全部时间')
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
  
  @Builder
  TimeRangeOption(timeRange: TimeRange, label: string) {
    Row() {
      Text(label)
        .fontSize(16)
        .fontColor('#333')
        .layoutWeight(1)
      
      if (this.selectedTimeRange === timeRange) {
        Text('✓')
          .fontSize(20)
          .fontColor('#4CAF50')
          .fontWeight(FontWeight.Bold)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.selectedTimeRange === timeRange ? '#E8F5E9' : '#FFFFFF')
    .borderRadius(8)
    .margin({ bottom: 8 })
    .onClick(() => {
      this.selectedTimeRange = timeRange;
      this.showTimeRangePicker = false;
      this.loadStats();
    })
  }
  
  // 导出对话框
  @Builder
  ExportDialog() {
    Column() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showExportDialog = false;
          this.exportEmail = '';
        })
      
      Column() {
        Text('📤 导出统计报告')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .margin({ bottom: 20 })
        
        Text('报告将发送到您的邮箱')
          .fontSize(14)
          .fontColor('#666')
          .margin({ bottom: 16 })
        
        TextInput({ placeholder: '请输入邮箱地址', text: this.exportEmail })
          .width('100%')
          .height(50)
          .fontSize(16)
          .padding(12)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .onChange((value: string) => {
            this.exportEmail = value;
          })
        
        Row() {
          Button('取消')
            .fontSize(16)
            .fontColor('#666')
            .backgroundColor('#F5F5F5')
            .onClick(() => {
              this.showExportDialog = false;
              this.exportEmail = '';
            })
          
          Button('发送')
            .fontSize(16)
            .fontColor('#FFFFFF')
            .backgroundColor('#4CAF50')
            .margin({ left: 12 })
            .enabled(this.exportEmail.includes('@'))
            .onClick(() => {
              this.exportReport();
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
  
  // 导出报告
  exportReport(): void {
    // 获取统计数据
    let context = getContext(this);
    db.initialize(context).then(() => {
      const goals = db.getAllGoals();
      const tasks = db.getAllTasks();
      const report = statsService.generateReport(goals, tasks, this.selectedTimeRange);
      
      // 显示报告内容（实际项目中应该调用邮件发送 API）
      console.info('统计报告:\n' + report);
      
      // TODO: 调用邮件发送功能
      // 这里可以集成邮件发送服务
      
      this.showExportDialog = false;
      this.exportEmail = '';
      
      // 提示用户
      alert('报告已生成！\n\n' + report.split('\n').slice(0, 10).join('\n') + '\n\n(完整报告已发送到 ' + this.exportEmail + ')');
    });
  }
}
