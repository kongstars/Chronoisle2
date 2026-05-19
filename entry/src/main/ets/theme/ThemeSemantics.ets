import { ThemeColors } from './AppTheme';

export type AppTone = 'neutral' | 'primary' | 'success' | 'warning' | 'danger' | 'premium' | 'info';
export type AppSurfaceLevel = 'page' | 'base' | 'raised' | 'soft' | 'overlay';
export type AppTextEmphasis = 'high' | 'medium' | 'low';

export function getSurfaceColor(theme: ThemeColors, level: AppSurfaceLevel): string {
  switch (level) {
    case 'base':
      return theme.surface;
    case 'raised':
      return theme.surfaceRaised;
    case 'soft':
      return theme.surfaceSoft;
    case 'overlay':
      return theme.surfaceOverlay;
    default:
      return theme.background;
  }
}

export function getTextColor(theme: ThemeColors, emphasis: AppTextEmphasis): string {
  switch (emphasis) {
    case 'medium':
      return theme.textSecondary;
    case 'low':
      return theme.textMuted;
    default:
      return theme.textPrimary;
  }
}

export function getToneTextColor(theme: ThemeColors, tone: AppTone): string {
  switch (tone) {
    case 'primary':
      return theme.primary;
    case 'success':
      return theme.success;
    case 'warning':
      return theme.warning;
    case 'danger':
      return theme.danger;
    case 'premium':
      return theme.premiumText;
    case 'info':
      return theme.info;
    default:
      return theme.textPrimary;
  }
}

export function getToneSurfaceColor(theme: ThemeColors, tone: AppTone): string {
  switch (tone) {
    case 'primary':
      return theme.primarySubtle;
    case 'success':
      return theme.successSubtle;
    case 'warning':
      return theme.warningSubtle;
    case 'danger':
      return theme.dangerSubtle;
    case 'premium':
      return theme.premiumSurface;
    case 'info':
      return theme.announcementSurface;
    default:
      return theme.surfaceSoft;
  }
}

export function getToneBorderColor(theme: ThemeColors, tone: AppTone): string {
  switch (tone) {
    case 'primary':
      return theme.primaryLight;
    case 'success':
      return theme.success;
    case 'warning':
      return theme.warning;
    case 'danger':
      return theme.danger;
    case 'premium':
      return theme.premiumBorder;
    case 'info':
      return theme.info;
    default:
      return theme.borderColor;
  }
}
