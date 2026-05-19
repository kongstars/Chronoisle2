import { WIDGET_COLOR_PRIMARY, WIDGET_COLOR_PRIMARY_SOFT } from './WidgetStyle';

@Component
export struct WidgetGlyph {
  @Prop name: string = 'dot';
  @Prop glyphSize: number = 18;
  @Prop color: string = WIDGET_COLOR_PRIMARY;
  @Prop surfaceColor: string = WIDGET_COLOR_PRIMARY_SOFT;

  private getStroke(): number {
    return Math.max(1.2, this.glyphSize * 0.08);
  }

  @Builder
  private Bar(width: number, height: number, color: string) {
    Row()
      .width(width)
      .height(height)
      .backgroundColor(color)
      .borderRadius(height / 2)
  }

  @Builder
  private RotatedBar(width: number, height: number, color: string, angle: number, x: number, y: number) {
    Row()
      .width(width)
      .height(height)
      .backgroundColor(color)
      .borderRadius(height / 2)
      .rotate({ angle: angle })
      .position({ x: x, y: y })
  }

  @Builder
  private PositionedBar(width: number, height: number, color: string, x: number, y: number) {
    Row()
      .width(width)
      .height(height)
      .backgroundColor(color)
      .borderRadius(height / 2)
      .position({ x: x, y: y })
  }

  @Builder
  private DotMark(color: string) {
    Row()
      .width(this.glyphSize * 0.42)
      .height(this.glyphSize * 0.42)
      .borderRadius(this.glyphSize * 0.21)
      .border({ width: this.getStroke(), color: color })
  }

  @Builder
  private FocusMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.glyphSize * 0.54)
        .height(this.glyphSize * 0.54)
        .borderRadius(this.glyphSize * 0.27)
        .border({ width: this.getStroke(), color: color })
      this.Bar(this.getStroke(), this.glyphSize * 0.2, color)
    }
  }

  @Builder
  private TaskMark(color: string) {
    Stack() {
      this.RotatedBar(this.glyphSize * 0.22, this.getStroke() * 1.25, color, 45, this.glyphSize * 0.26,
        this.glyphSize * 0.52)
      this.RotatedBar(this.glyphSize * 0.44, this.getStroke() * 1.25, color, -45, this.glyphSize * 0.4,
        this.glyphSize * 0.44)
    }
    .width(this.glyphSize)
    .height(this.glyphSize)
  }

  @Builder
  private StreakMark(color: string) {
    Row({ space: this.glyphSize * 0.08 }) {
      this.Bar(this.getStroke() * 1.1, this.glyphSize * 0.3, color)
      this.Bar(this.getStroke() * 1.1, this.glyphSize * 0.48, color)
      this.Bar(this.getStroke() * 1.1, this.glyphSize * 0.22, color)
    }
    .alignItems(VerticalAlign.Bottom)
    .height(this.glyphSize * 0.58)
  }

  @Builder
  private AiMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      this.Bar(this.glyphSize * 0.44, this.getStroke(), color)
      this.Bar(this.getStroke(), this.glyphSize * 0.44, color)
      Row()
        .width(this.glyphSize * 0.12)
        .height(this.glyphSize * 0.12)
        .borderRadius(this.glyphSize * 0.06)
        .backgroundColor(color)
        .position({ x: this.glyphSize * 0.68, y: this.glyphSize * 0.2 })
    }
    .width(this.glyphSize)
    .height(this.glyphSize)
  }

  @Builder
  private PinMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.glyphSize * 0.36)
        .height(this.glyphSize * 0.36)
        .borderRadius(this.glyphSize * 0.18)
        .border({ width: this.getStroke(), color: color })
      this.PositionedBar(this.getStroke(), this.glyphSize * 0.34, color, this.glyphSize * 0.49,
        this.glyphSize * 0.48)
    }
    .width(this.glyphSize)
    .height(this.glyphSize)
  }

  @Builder
  private WarningMark(color: string) {
    Column({ space: this.glyphSize * 0.08 }) {
      this.Bar(this.getStroke() * 1.25, this.glyphSize * 0.34, color)
      Row()
        .width(this.getStroke() * 1.25)
        .height(this.getStroke() * 1.25)
        .borderRadius(this.getStroke())
        .backgroundColor(color)
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private CalendarMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.glyphSize * 0.56)
        .height(this.glyphSize * 0.48)
        .borderRadius(this.glyphSize * 0.08)
        .border({ width: this.getStroke(), color: color })
      this.PositionedBar(this.glyphSize * 0.56, this.getStroke(), color, this.glyphSize * 0.22,
        this.glyphSize * 0.34)
    }
    .width(this.glyphSize)
    .height(this.glyphSize)
  }

  @Builder
  private HeartMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.glyphSize * 0.22)
        .height(this.glyphSize * 0.22)
        .borderRadius(this.glyphSize * 0.11)
        .backgroundColor(color)
        .position({ x: this.glyphSize * 0.32, y: this.glyphSize * 0.3 })
      Row()
        .width(this.glyphSize * 0.22)
        .height(this.glyphSize * 0.22)
        .borderRadius(this.glyphSize * 0.11)
        .backgroundColor(color)
        .position({ x: this.glyphSize * 0.48, y: this.glyphSize * 0.3 })
      this.RotatedBar(this.glyphSize * 0.3, this.glyphSize * 0.3, color, 45, this.glyphSize * 0.36,
        this.glyphSize * 0.42)
    }
    .width(this.glyphSize)
    .height(this.glyphSize)
  }

  @Builder
  private VoiceMark(color: string) {
    Row({ space: this.glyphSize * 0.07 }) {
      this.Bar(this.getStroke(), this.glyphSize * 0.26, color)
      this.Bar(this.getStroke(), this.glyphSize * 0.44, color)
      this.Bar(this.getStroke(), this.glyphSize * 0.32, color)
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private GlyphMark(color: string) {
    if (this.name === 'focus') {
      this.FocusMark(color)
    } else if (this.name === 'task') {
      this.TaskMark(color)
    } else if (this.name === 'streak') {
      this.StreakMark(color)
    } else if (this.name === 'ai') {
      this.AiMark(color)
    } else if (this.name === 'pin') {
      this.PinMark(color)
    } else if (this.name === 'warning') {
      this.WarningMark(color)
    } else if (this.name === 'calendar') {
      this.CalendarMark(color)
    } else if (this.name === 'heart') {
      this.HeartMark(color)
    } else if (this.name === 'voice') {
      this.VoiceMark(color)
    } else {
      this.DotMark(color)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.glyphSize)
        .height(this.glyphSize)
        .borderRadius(this.glyphSize * 0.32)
        .backgroundColor(this.surfaceColor)

      this.GlyphMark(this.color)
    }
    .width(this.glyphSize)
    .height(this.glyphSize)
  }
}
