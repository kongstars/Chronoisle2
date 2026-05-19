import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { ICON_SIZE_XL, ICON_SYMBOL_DEFAULT_WEIGHT } from '../../foundation/tokens/IconTokens';
import {
  AppTone,
  getToneBorderColor,
  getToneSurfaceColor,
  getToneTextColor
} from '../../theme/ThemeSemantics';

export type AppIconName =
  'today' | 'health' | 'growth' | 'finance' | 'joy' | 'goal' | 'task' | 'reminder' | 'focus' | 'calendar' |
  'habit' | 'milestone' | 'counter' | 'countdown' | 'stats' | 'wallet' | 'archive' | 'help' |
  'info' | 'ai' | 'plan' | 'progress' | 'action' | 'review' | 'warning' | 'success' | 'note' |
  'idea' | 'sync' | 'tomato' | 'noise' | 'rain' | 'storm' | 'wind' | 'water' | 'bird' |
  'power' | 'radio' | 'phone' | 'gear' | 'profile' | 'search' | 'spark' | 'chevron-left' | 'chevron-right' |
  'chevron-up' | 'chevron-down' | 'plus' | 'minus' | 'close' | 'unknown';

export function normalizeAppIconName(value: string): AppIconName {
  switch (value) {
    case 'today':
      return 'today';
    case 'health':
      return 'health';
    case 'growth':
      return 'growth';
    case 'finance':
      return 'finance';
    case 'joy':
      return 'joy';
    case 'goal':
      return 'goal';
    case 'task':
      return 'task';
    case 'reminder':
      return 'reminder';
    case 'focus':
      return 'focus';
    case 'calendar':
      return 'calendar';
    case 'habit':
      return 'habit';
    case 'milestone':
      return 'milestone';
    case 'counter':
      return 'counter';
    case 'countdown':
      return 'countdown';
    case 'stats':
      return 'stats';
    case 'wallet':
      return 'wallet';
    case 'archive':
      return 'archive';
    case 'help':
      return 'help';
    case 'info':
      return 'info';
    case 'ai':
      return 'ai';
    case 'plan':
      return 'plan';
    case 'progress':
      return 'progress';
    case 'action':
      return 'action';
    case 'review':
      return 'review';
    case 'warning':
      return 'warning';
    case 'success':
      return 'success';
    case 'note':
      return 'note';
    case 'idea':
      return 'idea';
    case 'sync':
      return 'sync';
    case 'tomato':
      return 'tomato';
    case 'noise':
      return 'noise';
    case 'rain':
      return 'rain';
    case 'storm':
      return 'storm';
    case 'wind':
      return 'wind';
    case 'water':
      return 'water';
    case 'bird':
      return 'bird';
    case 'power':
      return 'power';
    case 'radio':
      return 'radio';
    case 'phone':
      return 'phone';
    case 'gear':
      return 'gear';
    case 'profile':
      return 'profile';
    case 'search':
      return 'search';
    case 'spark':
      return 'spark';
    case 'chevron-left':
      return 'chevron-left';
    case 'chevron-right':
      return 'chevron-right';
    case 'chevron-up':
      return 'chevron-up';
    case 'chevron-down':
      return 'chevron-down';
    case 'plus':
      return 'plus';
    case 'minus':
      return 'minus';
    case 'close':
      return 'close';
    default:
      return 'unknown';
  }
}

export function getAppIconTone(value: string): AppTone {
  switch (normalizeAppIconName(value)) {
    case 'health':
    case 'task':
    case 'success':
    case 'habit':
      return 'success';
    case 'finance':
    case 'wallet':
    case 'warning':
    case 'counter':
    case 'tomato':
      return 'warning';
    case 'reminder':
    case 'calendar':
    case 'today':
    case 'countdown':
    case 'ai':
    case 'stats':
    case 'goal':
    case 'growth':
    case 'progress':
    case 'plan':
      return 'primary';
    case 'joy':
    case 'milestone':
    case 'spark':
      return 'premium';
    case 'archive':
    case 'focus':
    case 'noise':
    case 'rain':
    case 'storm':
    case 'wind':
    case 'water':
    case 'bird':
    case 'power':
    case 'radio':
    case 'phone':
    case 'gear':
    case 'profile':
    case 'search':
      return 'info';
    case 'chevron-left':
    case 'chevron-right':
    case 'chevron-up':
    case 'chevron-down':
    case 'plus':
    case 'minus':
      return 'primary';
    default:
      return 'neutral';
  }
}

@Component
export struct AppIcon {
  @StorageLink('themeColors') themeColors: ThemeColors = LightTheme;
  @Prop name: string = 'unknown';
  @Prop iconSize: number = ICON_SIZE_XL;
  @Prop tone: AppTone = 'neutral';
  @Prop color: string = '';
  @Prop surfaceColor: string = '';
  @Prop framed: boolean = true;
  @Prop muted: boolean = false;
  @Prop useSystemSymbol: boolean = true;

  private getIconName(): AppIconName {
    return normalizeAppIconName(this.name);
  }

  private getTone(): AppTone {
    return this.tone === 'neutral' ? getAppIconTone(this.name) : this.tone;
  }

  private getMarkColor(): string {
    if (this.color.length > 0) {
      return this.color;
    }
    return getToneTextColor(this.themeColors, this.getTone());
  }

  private getSurfaceColor(): string {
    if (!this.framed) {
      return 'rgba(0,0,0,0)';
    }
    if (this.surfaceColor.length > 0) {
      return this.surfaceColor;
    }
    return getToneSurfaceColor(this.themeColors, this.getTone());
  }

  private getBorderColor(): string {
    return this.framed ? getToneBorderColor(this.themeColors, this.getTone()) + '40' : 'rgba(0,0,0,0)';
  }

  private getStroke(): number {
    return Math.max(1.2, this.iconSize * 0.075);
  }

  private getInnerSize(): number {
    return this.iconSize * 0.58;
  }

  private getSmallRadius(): number {
    return Math.max(1, this.iconSize * 0.08);
  }

  private hasSystemSymbol(iconName: AppIconName): boolean {
    if (!this.useSystemSymbol) {
      return false;
    }
    switch (iconName) {
      case 'success':
      case 'warning':
      case 'info':
      case 'goal':
      case 'task':
      case 'reminder':
      case 'focus':
      case 'calendar':
      case 'today':
      case 'profile':
      case 'search':
      case 'chevron-left':
      case 'chevron-right':
      case 'chevron-up':
      case 'chevron-down':
      case 'wallet':
      case 'archive':
      case 'note':
      case 'gear':
      case 'plus':
      case 'close':
        return true;
      default:
        return false;
    }
  }

  private getSystemSymbolResource(iconName: AppIconName): Resource {
    switch (iconName) {
      case 'warning':
        return $r('sys.symbol.exclamationmark_triangle_fill');
      case 'info':
        return $r('sys.symbol.info_circle');
      case 'goal':
        return $r('sys.symbol.flag');
      case 'task':
        return $r('sys.symbol.list_checkmask');
      case 'reminder':
        return $r('sys.symbol.bell_fill');
      case 'focus':
        return $r('sys.symbol.timer');
      case 'calendar':
        return $r('sys.symbol.calendar');
      case 'today':
        return $r('sys.symbol.house');
      case 'profile':
        return $r('sys.symbol.person');
      case 'search':
        return $r('sys.symbol.magnifyingglass');
      case 'chevron-left':
        return $r('sys.symbol.chevron_left');
      case 'chevron-right':
        return $r('sys.symbol.chevron_right');
      case 'chevron-up':
        return $r('sys.symbol.chevron_up');
      case 'chevron-down':
        return $r('sys.symbol.chevron_down');
      case 'wallet':
        return $r('sys.symbol.creditcard');
      case 'archive':
        return $r('sys.symbol.archivebox');
      case 'note':
        return $r('sys.symbol.doc_text');
      case 'gear':
        return $r('sys.symbol.gearshape');
      case 'plus':
        return $r('sys.symbol.plus');
      case 'close':
        return $r('sys.symbol.xmark');
      case 'success':
      default:
        return $r('sys.symbol.checkmark');
    }
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
  private CenterRotatedBar(width: number, height: number, color: string, angle: number) {
    Row()
      .width(width)
      .height(height)
      .backgroundColor(color)
      .borderRadius(height / 2)
      .rotate({ angle: angle })
  }

  @Builder
  private BarsMark(color: string) {
    Row({ space: this.iconSize * 0.08 }) {
      this.Bar(this.iconSize * 0.11, this.iconSize * 0.32, color)
      this.Bar(this.iconSize * 0.11, this.iconSize * 0.46, color)
      this.Bar(this.iconSize * 0.11, this.iconSize * 0.24, color)
    }
    .alignItems(VerticalAlign.Bottom)
    .height(this.getInnerSize())
  }

  @Builder
  private BoxMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.getInnerSize())
        .height(this.iconSize * 0.42)
        .borderRadius(this.getSmallRadius())
        .border({ width: this.getStroke(), color: color })

      Column({ space: this.iconSize * 0.07 }) {
        this.Bar(this.iconSize * 0.34, this.getStroke(), color)
        this.Bar(this.iconSize * 0.22, this.getStroke(), color)
      }
    }
  }

  @Builder
  private TargetMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.getInnerSize())
        .height(this.getInnerSize())
        .borderRadius(this.getInnerSize() / 2)
        .border({ width: this.getStroke(), color: color })
      Row()
        .width(this.iconSize * 0.18)
        .height(this.iconSize * 0.18)
        .borderRadius(this.iconSize * 0.09)
        .backgroundColor(color)
    }
  }

  @Builder
  private CheckMark(color: string) {
    Stack() {
      this.RotatedBar(this.iconSize * 0.22, this.getStroke() * 1.35, color, 45, this.iconSize * 0.26,
        this.iconSize * 0.53)
      this.RotatedBar(this.iconSize * 0.48, this.getStroke() * 1.35, color, -45, this.iconSize * 0.38,
        this.iconSize * 0.44)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  private PlusMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      this.Bar(this.iconSize * 0.44, this.getStroke() * 1.25, color)
      this.Bar(this.getStroke() * 1.25, this.iconSize * 0.44, color)
    }
  }

  @Builder
  private CloseMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      this.CenterRotatedBar(this.iconSize * 0.48, this.getStroke() * 1.25, color, 45)
      this.CenterRotatedBar(this.iconSize * 0.48, this.getStroke() * 1.25, color, -45)
    }
  }

  @Builder
  private WaveMark(color: string) {
    Column({ space: this.iconSize * 0.08 }) {
      this.Bar(this.iconSize * 0.46, this.getStroke(), color)
      this.Bar(this.iconSize * 0.34, this.getStroke(), color)
      this.Bar(this.iconSize * 0.42, this.getStroke(), color)
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private AlertMark(color: string) {
    Column({ space: this.iconSize * 0.08 }) {
      this.Bar(this.getStroke() * 1.35, this.iconSize * 0.32, color)
      this.Bar(this.getStroke() * 1.35, this.getStroke() * 1.35, color)
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private InfoMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.getInnerSize())
        .height(this.getInnerSize())
        .borderRadius(this.getInnerSize() / 2)
        .border({ width: this.getStroke(), color: color })
      Column({ space: this.iconSize * 0.07 }) {
        this.Bar(this.getStroke() * 1.25, this.getStroke() * 1.25, color)
        this.Bar(this.getStroke() * 1.25, this.iconSize * 0.24, color)
      }
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private HelpMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.getInnerSize())
        .height(this.getInnerSize())
        .borderRadius(this.getInnerSize() / 2)
        .border({ width: this.getStroke(), color: color })
      Row()
        .width(this.iconSize * 0.24)
        .height(this.getStroke() * 1.2)
        .backgroundColor(color)
        .borderRadius(this.getStroke())
        .rotate({ angle: -24 })
        .margin({ bottom: this.iconSize * 0.14 })
      Row()
        .width(this.getStroke() * 1.25)
        .height(this.getStroke() * 1.25)
        .borderRadius(this.getStroke())
        .backgroundColor(color)
        .margin({ top: this.iconSize * 0.34 })
    }
  }

  @Builder
  private AiMark(color: string) {
    Stack() {
      Row()
        .width(this.iconSize * 0.16)
        .height(this.iconSize * 0.16)
        .borderRadius(this.iconSize * 0.04)
        .backgroundColor(color)
        .position({ x: this.iconSize * 0.25, y: this.iconSize * 0.24 })
      Row()
        .width(this.iconSize * 0.22)
        .height(this.iconSize * 0.22)
        .borderRadius(this.iconSize * 0.06)
        .border({ width: this.getStroke(), color: color })
        .position({ x: this.iconSize * 0.46, y: this.iconSize * 0.20 })
      Row()
        .width(this.iconSize * 0.22)
        .height(this.iconSize * 0.22)
        .borderRadius(this.iconSize * 0.06)
        .border({ width: this.getStroke(), color: color })
        .position({ x: this.iconSize * 0.26, y: this.iconSize * 0.52 })
      Row()
        .width(this.iconSize * 0.16)
        .height(this.iconSize * 0.16)
        .borderRadius(this.iconSize * 0.04)
        .backgroundColor(color)
        .position({ x: this.iconSize * 0.58, y: this.iconSize * 0.58 })
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  private PowerMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.getInnerSize())
        .height(this.getInnerSize())
        .borderRadius(this.getInnerSize() / 2)
        .border({ width: this.getStroke(), color: color })
      Row()
        .width(this.getStroke() * 1.3)
        .height(this.iconSize * 0.32)
        .borderRadius(this.getStroke())
        .backgroundColor(color)
        .margin({ bottom: this.iconSize * 0.28 })
    }
  }

  @Builder
  private PhoneMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.iconSize * 0.38)
        .height(this.iconSize * 0.58)
        .borderRadius(this.iconSize * 0.08)
        .border({ width: this.getStroke(), color: color })
      Row()
        .width(this.iconSize * 0.12)
        .height(this.getStroke())
        .borderRadius(this.getStroke() / 2)
        .backgroundColor(color)
        .margin({ top: this.iconSize * 0.38 })
    }
  }

  @Builder
  private ProfileMark(color: string) {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.iconSize * 0.22)
        .height(this.iconSize * 0.22)
        .borderRadius(this.iconSize * 0.11)
        .border({ width: this.getStroke(), color: color })
        .position({ x: this.iconSize * 0.39, y: this.iconSize * 0.26 })
      Row()
        .width(this.iconSize * 0.42)
        .height(this.iconSize * 0.20)
        .borderRadius(this.iconSize * 0.10)
        .border({ width: this.getStroke(), color: color })
        .position({ x: this.iconSize * 0.29, y: this.iconSize * 0.54 })
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  private SystemSymbolMark(resource: Resource, color: string) {
    SymbolGlyph(resource)
      .fontSize(this.iconSize * 0.78)
      .fontColor([color])
      .fontWeight(ICON_SYMBOL_DEFAULT_WEIGHT)
      .renderingStrategy(SymbolRenderingStrategy.SINGLE)
      .width(this.iconSize)
      .height(this.iconSize)
  }

  @Builder
  private ChevronMark(direction: 'left' | 'right', color: string) {
    Stack() {
      Row()
        .width(this.iconSize * 0.42)
        .height(this.getStroke() * 1.45)
        .backgroundColor(color)
        .borderRadius(this.getStroke())
        .rotate({ angle: direction === 'left' ? -42 : 42 })
        .position({
          x: this.iconSize * (direction === 'left' ? 0.22 : 0.36),
          y: this.iconSize * 0.32
        })

      Row()
        .width(this.iconSize * 0.42)
        .height(this.getStroke() * 1.45)
        .backgroundColor(color)
        .borderRadius(this.getStroke())
        .rotate({ angle: direction === 'left' ? 42 : -42 })
        .position({
          x: this.iconSize * (direction === 'left' ? 0.22 : 0.36),
          y: this.iconSize * 0.52
        })
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  private ChevronVerticalMark(direction: 'up' | 'down', color: string) {
    Stack() {
      Row()
        .width(this.iconSize * 0.42)
        .height(this.getStroke() * 1.45)
        .backgroundColor(color)
        .borderRadius(this.getStroke())
        .rotate({ angle: direction === 'up' ? -42 : 42 })
        .position({
          x: this.iconSize * 0.24,
          y: this.iconSize * (direction === 'up' ? 0.40 : 0.48)
        })

      Row()
        .width(this.iconSize * 0.42)
        .height(this.getStroke() * 1.45)
        .backgroundColor(color)
        .borderRadius(this.getStroke())
        .rotate({ angle: direction === 'up' ? 42 : -42 })
        .position({
          x: this.iconSize * 0.44,
          y: this.iconSize * (direction === 'up' ? 0.40 : 0.48)
        })
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }

  @Builder
  private IconMark(iconName: AppIconName, color: string) {
    if (this.hasSystemSymbol(iconName)) {
      this.SystemSymbolMark(this.getSystemSymbolResource(iconName), color)
    } else if (iconName === 'health') {
      this.PlusMark(color)
    } else if (iconName === 'plus') {
      this.PlusMark(color)
    } else if (iconName === 'minus') {
      this.Bar(this.iconSize * 0.44, this.getStroke() * 1.25, color)
    } else if (iconName === 'close') {
      this.CloseMark(color)
    } else if (iconName === 'growth') {
      this.BarsMark(color)
    } else if (iconName === 'finance' || iconName === 'wallet') {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(this.getInnerSize())
          .height(this.getInnerSize())
          .borderRadius(this.getInnerSize() / 2)
          .border({ width: this.getStroke(), color: color })
        this.Bar(this.iconSize * 0.28, this.getStroke(), color)
      }
    } else if (iconName === 'goal' || iconName === 'focus') {
      this.TargetMark(color)
    } else if (iconName === 'task' || iconName === 'success') {
      this.CheckMark(color)
    } else if (iconName === 'habit') {
      this.CheckMark(color)
    } else if (iconName === 'reminder' || iconName === 'calendar' || iconName === 'today' || iconName === 'countdown') {
      this.BoxMark(color)
    } else if (iconName === 'stats' || iconName === 'progress') {
      this.BarsMark(color)
    } else if (iconName === 'archive') {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(this.getInnerSize())
          .height(this.iconSize * 0.36)
          .borderRadius(this.getSmallRadius())
          .border({ width: this.getStroke(), color: color })
        Row()
          .width(this.iconSize * 0.22)
          .height(this.getStroke() * 1.4)
          .backgroundColor(color)
          .borderRadius(this.getStroke())
          .margin({ bottom: this.iconSize * 0.28, right: this.iconSize * 0.2 })
      }
    } else if (iconName === 'note' || iconName === 'plan' || iconName === 'action') {
      this.BoxMark(color)
    } else if (iconName === 'warning') {
      this.AlertMark(color)
    } else if (iconName === 'help') {
      this.HelpMark(color)
    } else if (iconName === 'info') {
      this.InfoMark(color)
    } else if (iconName === 'ai') {
      this.AiMark(color)
    } else if (iconName === 'idea' || iconName === 'joy' || iconName === 'spark' || iconName === 'milestone') {
      Stack({ alignContent: Alignment.Center }) {
        this.Bar(this.iconSize * 0.42, this.getStroke(), color)
        this.Bar(this.getStroke(), this.iconSize * 0.42, color)
        Row()
          .width(this.iconSize * 0.12)
          .height(this.iconSize * 0.12)
          .borderRadius(this.iconSize * 0.06)
          .backgroundColor(color)
          .margin({ left: this.iconSize * 0.32, bottom: this.iconSize * 0.32 })
      }
    } else if (iconName === 'tomato') {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(this.getInnerSize())
          .height(this.getInnerSize())
          .borderRadius(this.getInnerSize() / 2)
          .border({ width: this.getStroke(), color: color })
        Row()
          .width(this.iconSize * 0.18)
          .height(this.getStroke())
          .backgroundColor(color)
          .borderRadius(this.getStroke() / 2)
          .margin({ bottom: this.iconSize * 0.42 })
      }
    } else if (iconName === 'noise' || iconName === 'rain' || iconName === 'storm' || iconName === 'wind' ||
      iconName === 'water' || iconName === 'bird' || iconName === 'radio') {
      this.WaveMark(color)
    } else if (iconName === 'power') {
      this.PowerMark(color)
    } else if (iconName === 'phone') {
      this.PhoneMark(color)
    } else if (iconName === 'gear') {
      this.TargetMark(color)
    } else if (iconName === 'profile') {
      this.ProfileMark(color)
    } else if (iconName === 'search') {
      this.TargetMark(color)
    } else if (iconName === 'counter') {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(this.getInnerSize())
          .height(this.getInnerSize())
          .borderRadius(this.getInnerSize() / 2)
          .border({ width: this.getStroke(), color: color })
        this.Bar(this.iconSize * 0.34, this.getStroke(), color)
        this.Bar(this.getStroke(), this.iconSize * 0.34, color)
      }
    } else if (iconName === 'chevron-left') {
      this.ChevronMark('left', color)
    } else if (iconName === 'chevron-right') {
      this.ChevronMark('right', color)
    } else if (iconName === 'chevron-up') {
      this.ChevronVerticalMark('up', color)
    } else if (iconName === 'chevron-down') {
      this.ChevronVerticalMark('down', color)
    } else {
      Row()
        .width(this.iconSize * 0.22)
        .height(this.iconSize * 0.22)
        .borderRadius(this.iconSize * 0.11)
        .backgroundColor(color)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.iconSize)
        .height(this.iconSize)
        .backgroundColor(this.getSurfaceColor())
        .borderRadius(this.iconSize * 0.32)
        .border({ width: this.framed ? 1 : 0, color: this.getBorderColor() })
      this.IconMark(this.getIconName(), this.getMarkColor())
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .opacity(this.muted ? 0.56 : 1)
  }
}
