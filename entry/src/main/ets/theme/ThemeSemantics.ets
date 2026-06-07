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
      return theme.brandPrimary;
    case 'success':
      return theme.semanticSuccess;
    case 'warning':
      return theme.semanticWarning;
    case 'danger':
      return theme.semanticDanger;
    case 'premium':
      return theme.premiumText;
    case 'info':
      return theme.brandPrimary;
    default:
      return theme.textPrimary;
  }
}

export function getToneSurfaceColor(theme: ThemeColors, tone: AppTone): string {
  switch (tone) {
    case 'primary':
      return theme.brandLight;
    case 'success':
      return theme.successSubtle; // Using old ones mapped to new ones for now, or just directly return the semantic color with opacity? Let's use subtle colors from theme, which we updated.
    case 'warning':
      return theme.warningSubtle;
    case 'danger':
      return theme.dangerSubtle;
    case 'premium':
      return theme.premiumSurface;
    case 'info':
      return theme.brandLight;
    default:
      return theme.surfaceBase;
  }
}

export function getToneBorderColor(theme: ThemeColors, tone: AppTone): string {
  switch (tone) {
    case 'primary':
      return theme.brandLight;
    case 'success':
      return theme.successSubtle;
    case 'warning':
      return theme.warningSubtle;
    case 'danger':
      return theme.dangerSubtle;
    case 'premium':
      return theme.premiumBorder;
    case 'info':
      return theme.brandLight;
    default:
      return theme.borderLight;
  }
}
