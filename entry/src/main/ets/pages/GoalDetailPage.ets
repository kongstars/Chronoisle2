
import { Goal, KeyResult, GoalCategory } from '../models/Goal';
import { db } from '../storage/Database';
import { CATEGORIES, CATEGORY_COLORS, CategoryInfo } from '../common/Constants';
import router from '@ohos.router';

@Entry
@Component
struct GoalDetailPage {
  @State goal: Goal | null = null;
  @State showAddKR: boolean = false;
  @State newKRTitle: string = '';
  @State showEditGoal: boolean = false;
  @State editTitle: string = '';
  @State editDescription: string = '';
  @State selectedCategory: GoalCategory = GoalCategory.CAREER;
  private goalId: string = '';
  
  aboutToAppear(): void {
    let params = router.getParams() as Record<string, string>;
    this.goalId = params['goalId'] || '';
    
    let context = getContext(this);
    db.initialize(context).then(() => {
      let goal = db.getGoalById(this.goalId);
      if (goal) {
        this.goal = goal;
        this.editTitle = goal.title;
        this.editDescription = goal.description;
        this.selectedCategory = goal.category;
      }
    });
  }
  
  build() {
    Column() {
      // 标题栏
      Row() {
        Button() {
          Text('←')
            .fontSize(16)
            .fontColor('#1A1A1A')
        }
        .width(40)
        .height(40)
        .backgroundColor('transparent')
        .onClick(() => {
          router.back();
        })
        
        Text(this.goal?.title || '目标详情')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .layoutWeight(1)
          .margin({ left: 12 })
        
        Button() {
          Image($r('sys.media.ohos_ic_public_edit'))
            .width(24)
            .height(24)
            .fillColor('#1A1A1A')
        }
        .width(40)
        .height(40)
        .backgroundColor('transparent')
        .onClick(() => {
          this.showEditGoal = true;
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF')
      
      if (this.goal) {
        Scroll() {
          Column() {
            // 目标信息卡片
            this.TargetInfoCard()
            
            // 关键结果列表
            this.KRList()
            
            // 添加 KR 按钮
            Button('添加关键结果')
              .width('90%')
              .height(50)
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor('#4CAF50')
              .borderRadius(25)
              .margin({ top: 20, bottom: 40 })
              .onClick(() => {
                this.showAddKR = true;
              })
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
        .backgroundColor('#F5F5F5')
      }
      
      // 添加 KR 对话框
      if (this.showAddKR) {
        this.AddKRDialog()
      }
      
      // 编辑目标对话框
      if (this.showEditGoal) {
        this.EditGoalDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
  
  @Builder
  TargetInfoCard() {
    Column() {
      Row() {
        Text(this.goal!.category)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(20)
          .backgroundColor(CATEGORY_COLORS[this.goal!.category])
        
        Blank()
        
        Text(`开始：${this.formatDate(this.goal!.startDate)}`)
          .fontSize(12)
          .fontColor('#999')
      }
      .width('100%')
      .margin({ bottom: 16 })
      
      Text(this.goal!.title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .width('100%')
        .margin({ bottom: 12 })
      
      if (this.goal!.description) {
        Text(this.goal!.description)
          .fontSize(16)
          .fontColor('#666')
          .width('100%')
          .lineHeight(24)
          .margin({ bottom: 16 })
      }
      
      // 进度条
      Column() {
        Row() {
          Text('整体进度')
            .fontSize(14)
            .fontColor('#666')
          
          Blank()
          
          Text(`${this.goal!.progress}%`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#4CAF50')
        }
        .width('100%')
        .margin({ bottom: 8 })
        
        Progress({ value: this.goal!.progress, total: 100 })
          .width('100%')
          .height(8)
          .color('#4CAF50')
          .backgroundColor('#E8F5E9')
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F9F9F9')
      .borderRadius(12)
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({
      radius: 8,
      color: 'rgba(0,0,0,0.05)',
      offsetX: 0,
      offsetY: 2
    })
  }
  
  @Builder
  KRList() {
    Column() {
      Row() {
        Text('关键结果')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        
        Text(`(${this.goal!.keyResults.length})`)
          .fontSize(16)
          .fontColor('#999')
          .margin({ left: 8 })
        
        Blank()
      }
      .width('100%')
      .margin({ bottom: 16 })
      
      if (this.goal!.keyResults.length === 0) {
        Column() {
          Text('📝')
            .fontSize(48)
            .margin({ bottom: 12 })
          
          Text('还没有关键结果')
            .fontSize(16)
            .fontColor('#999')
          
          Text('点击下方按钮添加第一个关键结果')
            .fontSize(14)
            .fontColor('#CCC')
            .margin({ top: 8 })
        }
        .width('100%')
        .padding(40)
      } else {
        ForEach(this.goal!.keyResults, (kr: KeyResult) => {
          this.KRItem(kr)
        }, (kr: KeyResult) => kr.id)
      }
    }
    .width('100%')
  }
  
  @Builder
  KRItem(kr: KeyResult) {
    Column() {
      Row() {
        Text(kr.title)
          .fontSize(16)
          .fontColor('#333')
          .layoutWeight(1)
          .margin({ bottom: 12 })
        Button() {
          Text('×')
            .fontSize(16)
            .fontColor('#FF5722')
        }
        .width(32)
        .height(32)
        .backgroundColor('transparent')
        .onClick(() => {
          this.deleteKR(kr.id);
        })
      }
      .width('100%')
      
      Row() {
        Text('0%')
          .fontSize(12)
          .fontColor('#999')
        
        Slider({ value: kr.progress, min: 0, max: 100, step: 10 })
          .layoutWeight(1)
          .margin({ left: 12, right: 12 })
          .onChange((value: number) => {
            this.updateKRProgress(kr.id, value);
          })
        
        Text(`${kr.progress}%`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(kr.progress === 100 ? '#4CAF50' : '#666')
          .width(40)
      }
      .width('100%')
      
      if (kr.progress === 100) {
        Row() {
          Text('✅ 已完成')
            .fontSize(12)
            .fontColor('#4CAF50')
        }
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
  
  @Builder
  AddKRDialog() {
    Column() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showAddKR = false;
          this.newKRTitle = '';
        })
      
      Column() {
        Text('添加关键结果')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .margin({ bottom: 20 })
        
        TextInput({ placeholder: '例如：每周运动 3 次，每次 30 分钟', text: this.newKRTitle })
          .width('100%')
          .height(50)
          .fontSize(16)
          .padding(12)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .onChange((value: string) => {
            this.newKRTitle = value;
          })
        
        Row() {
          Button('取消')
            .fontSize(16)
            .fontColor('#666')
            .backgroundColor('#F5F5F5')
            .onClick(() => {
              this.showAddKR = false;
              this.newKRTitle = '';
            })
          
          Button('添加')
            .fontSize(16)
            .fontColor('#FFFFFF')
            .backgroundColor('#4CAF50')
            .margin({ left: 12 })
            .enabled(this.newKRTitle.trim() !== '')
            .onClick(() => {
              this.addKR();
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
  
  @Builder
  EditGoalDialog() {
    Column() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showEditGoal = false;
          this.resetEditForm();
        })
      
      Column() {
        Text('编辑目标')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .margin({ bottom: 20 })
        
        TextInput({ placeholder: '目标标题', text: this.editTitle })
          .width('100%')
          .height(50)
          .fontSize(16)
          .padding(12)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .onChange((value: string) => {
            this.editTitle = value;
          })
        
        TextInput({ placeholder: '目标描述（可选）', text: this.editDescription })
          .width('100%')
          .height(50)
          .fontSize(16)
          .padding(12)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .margin({ top: 12 })
          .onChange((value: string) => {
            this.editDescription = value;
          })
        
        Text('选择分类')
          .fontSize(14)
          .fontColor('#666')
          .margin({ top: 16, bottom: 8 })
          .alignSelf(ItemAlign.Start)
        Column() {
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
              this.showEditGoal = false;
              this.resetEditForm();
            })
          
          Button('保存')
            .fontSize(16)
            .fontColor('#FFFFFF')
            .backgroundColor('#4CAF50')
            .margin({ left: 12 })
            .enabled(this.editTitle.trim() !== '')
            .onClick(() => {
              this.saveGoalEdit();
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
  
  addKR(): void {
    if (!this.goal || this.newKRTitle.trim() === '') {
      return;
    }
    
    const kr = this.goal.addKeyResult(this.newKRTitle.trim());
    db.updateGoal(this.goal).then(() => {
      this.goal = db.getGoalById(this.goalId) || null;
      this.showAddKR = false;
      this.newKRTitle = '';
    });
  }
  deleteKR(krId: string): void {
    if (!this.goal) {
      return;
    }
    
    this.goal.removeKeyResult(krId);
    db.updateGoal(this.goal).then(() => {
      this.goal = db.getGoalById(this.goalId) || null;
    });
  }
  
  updateKRProgress(krId: string, progress: number): void {
    if (!this.goal) {
      return;
    }
    
    const kr = this.goal.keyResults.find((k: KeyResult) => k.id === krId);
    if (kr) {
      kr.progress = progress;
      kr.completed = progress === 100;
      this.goal.updateProgress();
      
      db.updateGoal(this.goal).then(() => {
        this.goal = db.getGoalById(this.goalId) || null;
      });
    }
  }
  
  saveGoalEdit(): void {
    if (!this.goal || this.editTitle.trim() === '') {
      return;
    }
    
    this.goal.title = this.editTitle.trim();
    this.goal.description = this.editDescription.trim();
    this.goal.category = this.selectedCategory;
    this.goal.updatedAt = Date.now();
    db.updateGoal(this.goal).then(() => {
      this.goal = db.getGoalById(this.goalId) || null;
      this.showEditGoal = false;
      this.resetEditForm();
    });
  }
  
  resetEditForm(): void {
    if (this.goal) {
      this.editTitle = this.goal.title;
      this.editDescription = this.goal.description;
      this.selectedCategory = this.goal.category;
    }
  }
  
  formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = date.getMonth() + 1;
    const day = date.getDate();
    return `${year}-${month.toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}`;
  }
}
