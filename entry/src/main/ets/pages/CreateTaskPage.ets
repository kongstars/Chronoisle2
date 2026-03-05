import { Task, TaskStatus } from '../models/Task';
import { Goal, KeyResult } from '../models/Goal';
import { db } from '../storage/Database';
import router from '@ohos.router';
@Entry
@Component
struct CreateTaskPage {
  @State task: Task | null = null;
  @State title: string = '';
  @State description: string = '';
  @State selectedGoalId: string = '';
  @State selectedKrId: string = '';
  @State dueDate: string = '';
  @State goals: Goal[] = [];
  @State showGoalPicker: boolean = false;
  @State showKrPicker: boolean = false;
  @State showDatePicker: boolean = false;
  @State datePickerDate: Date = new Date();
  private taskId?: string = '';
  private isEdit: boolean = false;
  aboutToAppear(): void {
    let context = getContext(this);
    db.initialize(context).then(() => {
      this.goals = db.getAllGoals();

      // 检查是否是编辑模式
      let params = router.getParams() as Record<string, string>;
      if (params['taskId']) {
        this.taskId = params['taskId'];
        this.isEdit = true;
        const task = db.getTaskById(this.taskId);
        if (task) {
          this.task = task;
          this.title = task.title;
          this.description = task.description;
          this.selectedGoalId = task.goalId;
          this.selectedKrId = task.krId || '';
          if (task.dueDate) {
            const date = new Date(task.dueDate);
            this.dueDate = `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
          }
        }
      }
    });
  }
  saveTask(): void {
    if (!this.title.trim() || !this.selectedGoalId) {
      return;
    }
    const goal = db.getGoalById(this.selectedGoalId);
    if (!goal) {
      return;
    }
    if (this.isEdit && this.task) {
      // 编辑模式
      this.task.title = this.title.trim();
      this.task.description = this.description.trim();
      this.task.goalId = this.selectedGoalId;
      this.task.goalTitle = goal.title;
      this.task.krId = this.selectedKrId || undefined;
      this.task.krTitle = this.selectedKrId ?
        goal.keyResults.find(kr => kr.id === this.selectedKrId)?.title : undefined;

      if (this.dueDate) {
        this.task.dueDate = new Date(this.dueDate).getTime();
      }

      db.updateTask(this.task).then(() => {
        router.back();
      });
    } else {
      // 新建模式
      const newTask = new Task(this.title.trim(), this.selectedGoalId, goal.title);
      newTask.description = this.description.trim();
      newTask.krId = this.selectedKrId || undefined;
      newTask.krTitle = this.selectedKrId ?
        goal.keyResults.find(kr => kr.id === this.selectedKrId)?.title : undefined;

      if (this.dueDate) {
        newTask.dueDate = new Date(this.dueDate).getTime();
      }

      db.addTask(newTask).then(() => {
        router.back();
      });
    }
  }
  build() {
    Stack() {
      Column() {
        // 标题栏 - 渐变背景
        Row() {
          Button() {
            Text('←')
              .fontSize(18)
              .fontColor('#FFFFFF')
          }
          .width(40)
          .height(40)
          .backgroundColor('rgba(255,255,255,0.15)')
          .borderRadius(12)
          .onClick(() => {
            router.back();
          })
          
          Text(this.isEdit ? '✏️ 编辑任务' : '➕ 创建任务')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .layoutWeight(1)
            .margin({ left: 12 })
          
          Button('保存')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .background(
              LinearGradient({
                direction: { x1: 0, y1: 0, x2: 1, y2: 0 },
                colors: [['#48BB78', 0], ['#38A169', 1]]
              })
            )
            .borderRadius(16)
            .padding({ left: 16, right: 16 })
            .shadow({
              radius: 10,
              color: 'rgba(72, 187, 120, 0.4)',
              offsetX: 0,
              offsetY: 2
            })
            .enabled(this.title.trim() !== '' && this.selectedGoalId !== '')
            .onClick(() => {
              this.saveTask();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 16 })
        .background(
          LinearGradient({
            direction: { x1: 0, y1: 0, x2: 1, y2: 1 },
            colors: [['#48BB78', 0], ['#38A169', 1]]
          })
        )
      Scroll() {
        Column() {
          // 任务标题
          Column() {
            Text('任务名称 *')
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.7)')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 8 })
            TextInput({ placeholder: '例如：每周运动 3 次', text: this.title })
              .width('100%')
              .height(50)
              .fontSize(15)
              .padding(14)
              .backgroundColor('rgba(255,255,255,0.1)')
              .borderRadius(12)
              .fontColor('#FFFFFF')
              .placeholderColor('rgba(255,255,255,0.4)')
              .onChange((value: string) => {
                this.title = value;
              })
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#16213E')
          .borderRadius(14)
          .margin({ bottom: 12 })
          // 关联目标
          Column() {
            Text('关联目标 *')
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.7)')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 8 })
            Button(this.selectedGoalId ?
              this.goals.find(g => g.id === this.selectedGoalId)?.title || '选择目标' :
              '选择目标')
              .width('100%')
              .height(50)
              .fontSize(15)
              .fontColor('#FFFFFF')
              .backgroundColor('rgba(255,255,255,0.1)')
              .borderRadius(12)
              .onClick(() => {
                this.showGoalPicker = true;
              })
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#16213E')
          .borderRadius(14)
          .margin({ bottom: 12 })
          
          // 关联关键结果（可选）
          if (this.selectedGoalId) {
            Column() {
              Text('关联关键结果（可选）')
                .fontSize(13)
                .fontColor('rgba(255,255,255,0.7)')
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })
              Button(this.selectedKrId ?
                this.goals.find(g => g.id === this.selectedGoalId)
                ?.keyResults.find(kr => kr.id === this.selectedKrId)?.title || '选择关键结果' :
                '选择关键结果')
                .width('100%')
                .height(50)
                .fontSize(15)
                .fontColor('#FFFFFF')
                .backgroundColor('rgba(255,255,255,0.1)')
                .borderRadius(12)
                .onClick(() => {
                  this.showKrPicker = true;
                })
            }
            .width('100%')
            .padding(18)
            .backgroundColor('#16213E')
            .borderRadius(14)
            .margin({ bottom: 12 })
          }
          // 计划完成时间
          Column() {
            Text('计划完成时间')
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.7)')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 8 })

            Button(this.dueDate ? this.dueDate : '📅 选择日期')
              .width('100%')
              .height(50)
              .fontSize(15)
              .fontColor('#FFFFFF')
              .backgroundColor('rgba(255,255,255,0.1)')
              .borderRadius(12)
              .onClick(() => {
                this.showDatePicker = true;
              })
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#16213E')
          .borderRadius(14)
          .margin({ bottom: 12 })
          
          // 任务描述
          Column() {
            Text('任务描述')
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.7)')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 8 })
            TextArea({ placeholder: '详细描述任务内容（可选）', text: this.description })
              .width('100%')
              .height(120)
              .fontSize(15)
              .padding(14)
              .backgroundColor('rgba(255,255,255,0.1)')
              .borderRadius(12)
              .fontColor('#FFFFFF')
              .placeholderColor('rgba(255,255,255,0.4)')
              .onChange((value: string) => {
                this.description = value;
              })
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#16213E')
          .borderRadius(14)
          .margin({ bottom: 12 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .backgroundColor('#0F0F23')

      // 目标选择器（居中显示）
      if (this.showGoalPicker) {
        Stack() {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.5)')
            .onClick(() => {
              this.showGoalPicker = false;
            })

          Column() {
            Text('选择目标')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
              .margin({ bottom: 16 })

            Scroll() {
              Column() {
                ForEach(this.goals, (goal: Goal) => {
                  Button(goal.title)
                    .width('100%')
                    .height(50)
                    .fontSize(16)
                    .fontColor('#333')
                    .backgroundColor(this.selectedGoalId === goal.id ? '#E8F5E9' : '#FFFFFF')
                    .margin({ bottom: 8 })
                    .onClick(() => {
                      this.selectedGoalId = goal.id;
                      this.selectedKrId = '';
                      this.showGoalPicker = false;
                    })
                }, (goal: Goal) => goal.id)
              }
              .width('100%')
            }
            .width('100%')
            .height(300)
          }
          .width('90%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
        .align(Alignment.Center)
      }
      // 关键结果选择器
      if (this.showKrPicker) {
        Stack() {
          // 遮罩层
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.5)')
            .onClick(() => {
              this.showKrPicker = false;
            })

          // 弹窗内容
          Column() {
            Text('选择关键结果')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
              .margin({ bottom: 16 })

            Scroll() {
              Column() {
                Button('不关联')
                  .width('100%')
                  .height(50)
                  .fontSize(16)
                  .fontColor('#FF5722')
                  .backgroundColor('#FFF5F5')
                  .margin({ bottom: 8 })
                  .onClick(() => {
                    this.selectedKrId = '';
                    this.showKrPicker = false;
                  })

                ForEach(
                  this.goals.find(g => g.id === this.selectedGoalId)?.keyResults || [],
                  (kr: KeyResult) => {
                    Button(kr.title)
                      .width('100%')
                      .height(50)
                      .fontSize(16)
                      .fontColor('#333')
                      .backgroundColor(this.selectedKrId === kr.id ? '#E8F5E9' : '#FFFFFF')
                      .margin({ bottom: 8 })
                      .onClick(() => {
                        this.selectedKrId = kr.id;
                        this.showKrPicker = false;
                      })
                  },
                  (kr: KeyResult) => kr.id
                )
              }
              .width('100%')
            }
            .width('100%')
            .height(300)
          }
          .width('90%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
        .alignSelf(ItemAlign.End)
        .borderRadius({ topLeft: 16, topRight: 16 })
      }
    }
    // 日期选择器弹窗（居中显示）
    if (this.showDatePicker) {
      Stack() {
        // 遮罩层
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.5)')
          .onClick(() => {
            this.showDatePicker = false;
          })

        // 弹窗内容（居中）
        Column() {
          Row() {
            Text('选择日期')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')

            Blank()

            Button('取消')
              .fontSize(14)
              .fontColor('#666')
              .backgroundColor('transparent')
              .onClick(() => {
                this.showDatePicker = false;
              })

            Button('确定')
              .fontSize(14)
              .fontColor('#4CAF50')
              .backgroundColor('transparent')
              .margin({ left: 16 })
              .onClick(() => {
                const year = this.datePickerDate.getFullYear();
                const month = (this.datePickerDate.getMonth() + 1).toString().padStart(2, '0');
                const day = this.datePickerDate.getDate().toString().padStart(2, '0');
                this.dueDate = `${year}-${month}-${day}`;
                this.showDatePicker = false;
              })
          }
          .width('100%')
          .margin({ bottom: 16 })

          DatePicker()
            .onChange((value: DatePickerResult) => {
              if (value.year !== undefined && value.month !== undefined && value.day !== undefined) {
                this.datePickerDate = new Date(value.year, value.month, value.day);
              }
            })
        }
        .width('90%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Center)  // ← 关键：居中对齐
    }
  }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}