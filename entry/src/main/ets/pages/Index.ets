@Entry
@Component
struct Index {
  @State message: string = '欢迎使用人生目标管理器';
  
  build() {
    Column() {
      Text('🎯 人生目标管理器')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .margin({ bottom: 40 })
      
      Text(this.message)
        .fontSize(18)
        .fontColor('#666')
        .margin({ bottom: 60 })
      
      Column() {
        Text('✅ 项目已就绪')
          .fontSize(20)
          .fontColor('#4CAF50')
          .margin({ bottom: 20 })
        
        Text('接下来我们将逐步添加功能：')
          .fontSize(16)
          .fontColor('#999')
        
        Text('1. 目标管理（OKR）')
          .fontSize(16)
          .fontColor('#333')
          .margin({ top: 20 })
        
        Text('2. 任务系统')
          .fontSize(16)
          .fontColor('#333')
        
        Text('3. 生活记录')
          .fontSize(16)
          .fontColor('#333')
        
        Text('4. 数据统计')
          .fontSize(16)
          .fontColor('#333')
      }
      .padding(20)
      .backgroundColor('#F5F5F5')
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#FFFFFF')
  }
}
