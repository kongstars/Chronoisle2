import { WIDGET_COLOR_PRIMARY, WIDGET_COLOR_PRIMARY_SOFT } from './WidgetStyle';

@Component
export struct WidgetGlyph {
  @Prop name: string = 'dot';
  @Prop glyphSize: number = 18;
  @Prop color: string = WIDGET_COLOR_PRIMARY;
  @Prop surfaceColor: string = WIDGET_COLOR_PRIMARY_SOFT;

  private getTintMatrix(color: string): number[] {
    const rgba = this.parseColor(color);
    return [
      0, 0, 0, 0, rgba[0] / 255,
      0, 0, 0, 0, rgba[1] / 255,
      0, 0, 0, 0, rgba[2] / 255,
      0, 0, 0, 1, 0
    ];
  }

  private parseColor(color: string): number[] {
    const value = color.trim();
    if (value.startsWith('#')) {
      if (value.length === 7) {
        return [
          parseInt(value.slice(1, 3), 16),
          parseInt(value.slice(3, 5), 16),
          parseInt(value.slice(5, 7), 16),
          255
        ];
      }
      if (value.length === 9) {
        return [
          parseInt(value.slice(3, 5), 16),
          parseInt(value.slice(5, 7), 16),
          parseInt(value.slice(7, 9), 16),
          parseInt(value.slice(1, 3), 16)
        ];
      }
    }

    const rgbaMatch = value.match(/rgba?\(([^)]+)\)/i);
    if (rgbaMatch && rgbaMatch[1]) {
      const parts = rgbaMatch[1].split(',').map((part: string) => part.trim());
      const red = Number(parts[0] ?? '0');
      const green = Number(parts[1] ?? '0');
      const blue = Number(parts[2] ?? '0');
      const alpha = parts.length > 3 ? Math.round(Number(parts[3]) * 255) : 255;
      return [red, green, blue, alpha];
    }

    return [118, 121, 245, 255];
  }

  private getResource(): Resource {
    switch (this.name) {
      case 'focus':
        return $r('app.media.app_icon_focus');
      case 'task':
        return $r('app.media.app_icon_task');
      case 'streak':
        return $r('app.media.app_icon_stats');
      case 'ai':
        return $r('app.media.app_icon_ai');
      case 'pin':
        return $r('app.media.app_icon_flag');
      case 'warning':
        return $r('app.media.app_icon_warning');
      case 'calendar':
        return $r('app.media.app_icon_calendar');
      case 'heart':
        return $r('app.media.app_icon_heart');
      case 'voice':
        return $r('app.media.app_icon_voice');
      case 'dot':
        return $r('app.media.app_icon_radio');
      default:
        return $r('app.media.app_icon_unknown');
    }
  }

  private getIconSize(): number {
    switch (this.name) {
      case 'dot':
        return this.glyphSize * 0.72;
      default:
        return this.glyphSize;
    }
  }

  @Builder
  private GlyphMark(color: string) {
    Image(this.getResource())
      .width(this.getIconSize())
      .height(this.getIconSize())
      .objectFit(ImageFit.Contain)
      .interpolation(ImageInterpolation.High)
      .draggable(false)
      .syncLoad(true)
      .colorFilter(this.getTintMatrix(color))
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
