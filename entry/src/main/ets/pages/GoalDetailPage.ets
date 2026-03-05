
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
  @State showEditKR: boolean = false;
  @State editKRTitle: string = '';
  private editingKRId: string = '';
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
        
        Column() {
          Text(this.goal?.title || '目标详情')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          
          if (this.goal) {
            Text(`${this.goal.category} · ${this.goal.progress}% 完成`)
              .fontSize(12)
              .fontColor('rgba(255,255,255,0.7)')
              .margin({ top: 2 })
          }
        }
        .layoutWeight(1)
        .margin({ left: 12 })
        
        Button() {
          Text('✏️')
            .fontSize(18)
        }
        .width(40)
        .height(40)
        .backgroundColor('rgba(255,255,255,0.15)')
        .borderRadius(12)
        .onClick(() => {
          this.showEditGoal = true;
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .background(
        LinearGradient({
          direction: { x1: 0, y1: 0, x2: 1, y2: 1 },
          colors: [['#667EEA', 0], ['#764BA2', 1]]
        })
      )
      
      if (this.goal) {
        Scroll() {
          Column() {
            // 目标信息卡片
            this.TargetInfoCard()
            
            // 关键结果列表
            this.KRList()
            
            // 添加 KR 按钮 - 霓虹风格
            Button() {
              Row() {
                Text('+')
                  .fontSize(18)
                  .fontColor('#FFFFFF')
                  .margin({ right: 4 })
                
                Text('添加关键结果')
                  .fontSize(15)
                  .fontColor('#FFFFFF')
              }
            }
            .width('90%')
            .height(52)
            .background(
              LinearGradient({
                direction: { x1: 0, y1: 0, x2: 1, y2: 0 },
                colors: [['#48BB78', 0], ['#38A169', 1]]
              })
            )
            .borderRadius(26)
            .shadow({
              radius: 14,
              color: 'rgba(72, 187, 120, 0.4)',
              offsetX: 0,
              offsetY: 4
            })
            .margin({ top: 24, bottom: 40 })
            .onClick(() => {
              this.showAddKR = true;
            })
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
        .backgroundColor('#0F0F23')
      }
      
      // 添加 KR 对话框
      if (this.showAddKR) {
        this.AddKRDialog()
      }
      
      // 编辑 KR 对话框
      if (this.showEditKR) {
        this.EditKRDialog()
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
        Row() {
          Text(CATEGORIES.find((c) => c.value === this.goal!.category)?.icon || '')
            .fontSize(12)
            .margin({ right: 4 })
          
          Text(this.goal!.category)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(20)
        .backgroundColor(CATEGORY_COLORS[this.goal!.category])
        
        Blank()
        
        Text(`开始：${this.formatDate(this.goal!.startDate)}`)
          .fontSize(12)
          .fontColor('rgba(255,255,255,0.6)')
      }
      .width('100%')
      .margin({ bottom: 16 })
      
      Text(this.goal!.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .width('100%')
        .margin({ bottom: 12 })
      
      if (this.goal!.description) {
        Text(this.goal!.description)
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.7)')
          .width('100%')
          .lineHeight(22)
          .margin({ bottom: 20 })
      }
      
      // 进度条
      Column() {
        Row() {
          Text('整体进度')
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.7)')
          
          Blank()
          
          Text(`${this.goal!.progress}%`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.goal!.progress >= 80 ? '#48BB78' : this.goal!.progress >= 50 ? '#4299E1' : '#F6AD55')
        }
        .width('100%')
        .margin({ bottom: 10 })
        
        Progress({ value: this.goal!.progress, total: 100 })
          .width('100%')
          .height(8)
          .color(this.goal!.progress >= 80 ? '#48BB78' : this.goal!.progress >= 50 ? '#667EEA' : '#F6AD55')
          .backgroundColor('rgba(255,255,255,0.1)')
          .borderRadius(4)
      }
      .width('100%')
      .padding(18)
      .backgroundColor('rgba(255,255,255,0.05)')
      .borderRadius(14)
      .border({ width: 1, color: 'rgba(255,255,255,0.1)' })
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
  
  @Builder
  KRList() {
    Column() {
      Row() {
        Text('关键结果')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
        
        Text(`(${this.goal!.keyResults.length})`)
          .fontSize(15)
          .fontColor('rgba(255,255,255,0.6)')
          .margin({ left: 8 })
        
        Blank()
      }
      .width('100%')
      .margin({ bottom: 16 })
      
      if (this.goal!.keyResults.length === 0) {
        Column() {
          Text('📝')
            .fontSize(56)
            .margin({ bottom: 16 })
            .opacity(0.8)
          
          Text('还没有关键结果')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#A0AEC0')
          
          Text('点击下方按钮添加第一个关键结果')
            .fontSize(14)
            .fontColor('#718096')
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
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .layoutWeight(1)
          .margin({ bottom: 12 })
        
        // 编辑 KR 按钮
        Button() {
          Text('✏️')
            .fontSize(14)
        }
        .width(32)
        .height(32)
        .backgroundColor('rgba(255,255,255,0.08)')
        .borderRadius(8)
        .onClick(() => {
          this.showEditKRDialog(kr);
        })
        
        // 删除 KR 按钮
        Button() {
          Text('×')
            .fontSize(16)
            .fontColor('#FC8181')
        }
        .width(32)
        .height(32)
        .backgroundColor('rgba(252, 129, 129, 0.15)')
        .borderRadius(8)
        .margin({ left: 6 })
        .onClick(() => {
          this.deleteKR(kr.id);
        })
      }
      .width('100%')
      
      Row() {
        Text('0%')
          .fontSize(11)
          .fontColor('rgba(255,255,255,0.5)')
        
        Slider({ value: kr.progress, min: 0, max: 100, step: 10 })
          .layoutWeight(1)
          .margin({ left: 12, right: 12 })
          .color('#48BB78')
          .trackColor('rgba(255,255,255,0.1)')
          .onChange((value: number) => {
            this.updateKRProgress(kr.id, value);
          })
        
        Text(`${kr.progress}%`)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(kr.progress === 100 ? '#48BB78' : '#FFFFFF')
          .width(40)
      }
      .width('100%')
      
      if (kr.progress === 100) {
        Row() {
          Text('✅ 已完成')
            .fontSize(12)
            .fontColor('#48BB78')
        }
        .width('100%')
        .margin({ top: 8 })
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
  EditKRDialog() {
    Column() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .position({ x: 0, y: 0 })
        .onClick(() => {
          this.showEditKR = false;
          this.editKRTitle = '';
        })
      
      Column() {
        Text('编辑关键结果')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .margin({ bottom: 20 })
        
        TextInput({ placeholder: '输入关键结果标题', text: this.editKRTitle })
          .width('100%')
          .height(50)
          .fontSize(16)
          .padding(12)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .onChange((value: string) => {
            this.editKRTitle = value;
          })
        
        Row() {
          Button('取消')
            .fontSize(16)
            .fontColor('#666')
            .backgroundColor('#F5F5F5')
            .onClick(() => {
              this.showEditKR = false;
              this.editKRTitle = '';
            })
          
          Button('保存')
            .fontSize(16)
            .fontColor('#FFFFFF')
            .backgroundColor('#4CAF50')
            .margin({ left: 12 })
            .enabled(this.editKRTitle.trim() !== '')
            .onClick(() => {
              this.saveKREdit();
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
  addKR() {
    if (!this.goal) {
      return;
    }
    if (this.newKRTitle.trim().length === 0) {
      return;
    }
    // ✅ 正确：使用构造函数创建实例
    const newKR = new KeyResult(this.newKRTitle.trim());
    if (!this.goal.keyResults) {
      this.goal.keyResults = [];
    }
    this.goal.keyResults.push(newKR);
    // 更新进度
    if (this.goal.keyResults.length > 0) {
      const total = this.goal.keyResults.reduce((sum, kr) => sum + kr.progress, 0);
      this.goal.progress = Math.round(total / this.goal.keyResults.length);
    }
    this.goal.updatedAt = Date.now();
    this.newKRTitle = '';

    // ✅ 添加：保存到数据库
    db.updateGoal(this.goal).then(() => {
      this.goal = db.getGoalById(this.goalId) || null;
    });
  }
  
  // 显示编辑 KR 对话框
  showEditKRDialog(kr: KeyResult): void {
    this.editingKRId = kr.id;
    this.editKRTitle = kr.title;
    this.showEditKR = true;
  }
  
  // 保存 KR 编辑
  saveKREdit(): void {
    if (!this.goal || this.editKRTitle.trim() === '') {
      return;
    }
    
    const kr = this.goal.keyResults.find((k: KeyResult) => k.id === this.editingKRId);
    if (kr) {
      kr.title = this.editKRTitle.trim();
      db.updateGoal(this.goal).then(() => {
        this.goal = db.getGoalById(this.goalId) || null;
        this.showEditKR = false;
        this.editKRTitle = '';
        this.editingKRId = '';
      });
    }
  }
  
  updateKRProgress(krId: string, progress: number): void {
    if (!this.goal) {
      return;
    }

    const kr = this.goal.keyResults.find((k: KeyResult) => k.id === krId);
    if (kr) {
      kr.progress = progress;
      kr.completed = progress === 100;

      // ✅ 修复：手动计算进度，不调用类方法
      if (this.goal.keyResults.length > 0) {
        const total = this.goal.keyResults.reduce((sum, k) => sum + k.progress, 0);
        this.goal.progress = Math.round(total / this.goal.keyResults.length);
      }
      this.goal.updatedAt = Date.now();

      // ✅ 保存到数据库
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

  deleteKR(krId: string): void {
    if (!this.goal) {
      return;
    }

    this.goal.keyResults = this.goal.keyResults.filter((kr: KeyResult) => kr.id !== krId);

    // 手动计算进度
    if (this.goal.keyResults.length > 0) {
      const total = this.goal.keyResults.reduce((sum, kr) => sum + kr.progress, 0);
      this.goal.progress = Math.round(total / this.goal.keyResults.length);
    }
    this.goal.updatedAt = Date.now();

    db.updateGoal(this.goal).then(() => {
      this.goal = db.getGoalById(this.goalId) || null;
    });
  }
}  // ← deleteKR 必须在这个 } 之前
