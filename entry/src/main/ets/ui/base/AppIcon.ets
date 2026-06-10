import { ThemeColors, LightTheme } from '../../theme/AppTheme';
import { ICON_SIZE_XL } from '../../foundation/tokens/IconTokens';
import {
  AppTone,
  getToneBorderColor,
  getToneSurfaceColor,
  getToneTextColor
} from '../../theme/ThemeSemantics';

export type AppIconName =
  'today' | 'health' | 'growth' | 'finance' | 'joy' | 'goal' | 'task' | 'reminder' | 'focus' | 'calendar' |
  'habit' | 'milestone' | 'counter' | 'countdown' | 'stats' | 'wallet' | 'archive' | 'help' | 'info' | 'ai' |
  'plan' | 'progress' | 'action' | 'review' | 'warning' | 'success' | 'note' | 'idea' | 'sync' | 'tomato' |
  'noise' | 'rain' | 'storm' | 'wind' | 'water' | 'bird' | 'power' | 'radio' | 'phone' | 'gear' | 'profile' |
  'search' | 'spark' | 'voice' | 'edit' | 'delete' | 'share' | 'filter' | 'sort' | 'copy' | 'link' | 'lock' |
  'unlock' | 'eye' | 'eye-off' | 'star' | 'star-fill' | 'heart' | 'flag' | 'tag' | 'location' | 'time' |
  'date' | 'chevron-left' | 'chevron-right' | 'chevron-up' | 'chevron-down' | 'plus' | 'minus' | 'close' |
  'unknown';

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
    case 'voice':
      return 'voice';
    case 'edit':
      return 'edit';
    case 'delete':
      return 'delete';
    case 'share':
      return 'share';
    case 'filter':
      return 'filter';
    case 'sort':
      return 'sort';
    case 'copy':
      return 'copy';
    case 'link':
      return 'link';
    case 'lock':
      return 'lock';
    case 'unlock':
      return 'unlock';
    case 'eye':
      return 'eye';
    case 'eye-off':
      return 'eye-off';
    case 'star':
      return 'star';
    case 'star-fill':
      return 'star-fill';
    case 'heart':
      return 'heart';
    case 'flag':
      return 'flag';
    case 'tag':
      return 'tag';
    case 'location':
      return 'location';
    case 'time':
      return 'time';
    case 'date':
      return 'date';
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
    case 'delete':
      return 'danger';
    case 'edit':
    case 'share':
    case 'filter':
    case 'sort':
    case 'copy':
    case 'link':
    case 'lock':
    case 'unlock':
    case 'eye':
    case 'eye-off':
    case 'star':
    case 'star-fill':
    case 'heart':
    case 'flag':
    case 'tag':
    case 'location':
    case 'time':
    case 'date':
    case 'voice':
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
  @Prop selected: boolean = false;

  private getIconName(name: string): AppIconName {
    return normalizeAppIconName(name);
  }

  private getTone(tone: AppTone | 'neutral', name: string): AppTone {
    return tone === 'neutral' ? getAppIconTone(name) : tone;
  }

  private getMarkColor(color: string, tone: AppTone): string {
    if (color.length > 0) {
      return color;
    }
    return getToneTextColor(this.themeColors, tone);
  }

  private getSurfaceColor(framed: boolean, surfaceColor: string, tone: AppTone): string {
    if (!framed) {
      return this.themeColors.transparent;
    }
    if (surfaceColor.length > 0) {
      return surfaceColor;
    }
    return getToneSurfaceColor(this.themeColors, tone);
  }

  private getBorderColor(framed: boolean, tone: AppTone): string {
    return framed ? getToneBorderColor(this.themeColors, tone) + '40' : this.themeColors.transparent;
  }

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

    return [26, 36, 53, 255];
  }

  private usesIntrinsicSelectedAsset(selected: boolean, iconName: AppIconName): boolean {
    if (!selected) {
      return false;
    }
    switch (iconName) {
      case 'today':
      case 'action':
      case 'goal':
      case 'profile':
        return true;
      default:
        return false;
    }
  }

  private getSelectedResource(iconName: AppIconName): Resource {
    switch (iconName) {
      case 'today':
        return $r('app.media.app_icon_today_selected');
      case 'action':
        return $r('app.media.app_icon_action_selected');
      case 'goal':
        return $r('app.media.app_icon_goal_selected');
      case 'profile':
        return $r('app.media.app_icon_profile_selected');
      default:
        return this.getDefaultResource(iconName);
    }
  }

  private getDefaultResource(iconName: AppIconName): Resource {
    switch (iconName) {
      case 'today':
        return $r('app.media.app_icon_today');
      case 'health':
        return $r('app.media.app_icon_health');
      case 'growth':
        return $r('app.media.app_icon_growth');
      case 'finance':
        return $r('app.media.app_icon_finance');
      case 'joy':
        return $r('app.media.app_icon_joy');
      case 'goal':
        return $r('app.media.app_icon_goal');
      case 'task':
        return $r('app.media.app_icon_task');
      case 'reminder':
        return $r('app.media.app_icon_reminder');
      case 'focus':
        return $r('app.media.app_icon_focus');
      case 'calendar':
        return $r('app.media.app_icon_calendar');
      case 'habit':
        return $r('app.media.app_icon_habit');
      case 'milestone':
        return $r('app.media.app_icon_milestone');
      case 'counter':
        return $r('app.media.app_icon_counter');
      case 'countdown':
        return $r('app.media.app_icon_countdown');
      case 'stats':
        return $r('app.media.app_icon_stats');
      case 'wallet':
        return $r('app.media.app_icon_wallet');
      case 'archive':
        return $r('app.media.app_icon_archive');
      case 'help':
        return $r('app.media.app_icon_help');
      case 'info':
        return $r('app.media.app_icon_info');
      case 'ai':
        return $r('app.media.app_icon_ai');
      case 'plan':
        return $r('app.media.app_icon_plan');
      case 'progress':
        return $r('app.media.app_icon_progress');
      case 'action':
        return $r('app.media.app_icon_action');
      case 'review':
        return $r('app.media.app_icon_review');
      case 'warning':
        return $r('app.media.app_icon_warning');
      case 'success':
        return $r('app.media.app_icon_success');
      case 'note':
        return $r('app.media.app_icon_note');
      case 'idea':
        return $r('app.media.app_icon_idea');
      case 'sync':
        return $r('app.media.app_icon_sync');
      case 'tomato':
        return $r('app.media.app_icon_tomato');
      case 'noise':
        return $r('app.media.app_icon_noise');
      case 'rain':
        return $r('app.media.app_icon_rain');
      case 'storm':
        return $r('app.media.app_icon_storm');
      case 'wind':
        return $r('app.media.app_icon_wind');
      case 'water':
        return $r('app.media.app_icon_water');
      case 'bird':
        return $r('app.media.app_icon_bird');
      case 'power':
        return $r('app.media.app_icon_power');
      case 'radio':
        return $r('app.media.app_icon_radio');
      case 'phone':
        return $r('app.media.app_icon_phone');
      case 'gear':
        return $r('app.media.app_icon_gear');
      case 'profile':
        return $r('app.media.app_icon_profile');
      case 'search':
        return $r('app.media.app_icon_search');
      case 'spark':
        return $r('app.media.app_icon_spark');
      case 'voice':
        return $r('app.media.app_icon_voice');
      case 'edit':
        return $r('app.media.app_icon_edit');
      case 'delete':
        return $r('app.media.app_icon_delete');
      case 'share':
        return $r('app.media.app_icon_share');
      case 'filter':
        return $r('app.media.app_icon_filter');
      case 'sort':
        return $r('app.media.app_icon_sort');
      case 'copy':
        return $r('app.media.app_icon_copy');
      case 'link':
        return $r('app.media.app_icon_link');
      case 'lock':
        return $r('app.media.app_icon_lock');
      case 'unlock':
        return $r('app.media.app_icon_unlock');
      case 'eye':
        return $r('app.media.app_icon_eye');
      case 'eye-off':
        return $r('app.media.app_icon_eye_off');
      case 'star':
        return $r('app.media.app_icon_star');
      case 'star-fill':
        return $r('app.media.app_icon_star_fill');
      case 'heart':
        return $r('app.media.app_icon_heart');
      case 'flag':
        return $r('app.media.app_icon_flag');
      case 'tag':
        return $r('app.media.app_icon_tag');
      case 'location':
        return $r('app.media.app_icon_location');
      case 'time':
        return $r('app.media.app_icon_time');
      case 'date':
        return $r('app.media.app_icon_date');
      case 'chevron-left':
        return $r('app.media.app_icon_chevron_left');
      case 'chevron-right':
        return $r('app.media.app_icon_chevron_right');
      case 'chevron-up':
        return $r('app.media.app_icon_chevron_up');
      case 'chevron-down':
        return $r('app.media.app_icon_chevron_down');
      case 'plus':
        return $r('app.media.app_icon_plus');
      case 'minus':
        return $r('app.media.app_icon_minus');
      case 'close':
        return $r('app.media.app_icon_close');
      case 'unknown':
        return $r('app.media.app_icon_unknown');
      default:
        return $r('app.media.app_icon_unknown');
    }
  }

  private getResource(selected: boolean, iconName: AppIconName): Resource {
    return this.usesIntrinsicSelectedAsset(selected, iconName) ? this.getSelectedResource(iconName) : this.getDefaultResource(iconName);
  }

  @Builder
  private IconImage(selected: boolean, iconName: AppIconName, color: string) {
    if (this.usesIntrinsicSelectedAsset(selected, iconName)) {
      Image(this.getResource(selected, iconName))
        .width(this.iconSize)
        .height(this.iconSize)
        .objectFit(ImageFit.Contain)
        .interpolation(ImageInterpolation.High)
        .draggable(false)
        .syncLoad(true)
    } else {
      Image(this.getResource(selected, iconName))
        .width(this.iconSize)
        .height(this.iconSize)
        .objectFit(ImageFit.Contain)
        .interpolation(ImageInterpolation.High)
        .draggable(false)
        .syncLoad(true)
        .fillColor(color)
        .colorFilter(color)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(this.iconSize)
        .height(this.iconSize)
        .backgroundColor(this.getSurfaceColor(this.framed, this.surfaceColor, this.getTone(this.tone, this.name)))
        .borderRadius(this.iconSize * 0.32)
        .border({ width: this.framed ? 1 : 0, color: this.getBorderColor(this.framed, this.getTone(this.tone, this.name)) })
      this.IconImage(this.selected, this.getIconName(this.name), this.getMarkColor(this.color, this.getTone(this.tone, this.name)))
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .opacity(this.muted ? 0.56 : 1)
  }
}
