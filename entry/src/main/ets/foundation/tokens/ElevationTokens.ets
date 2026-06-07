import { ThemeColors } from '../../theme/AppTheme';

export interface AppShadowStyle {
  radius: number;
  color: string;
  offsetX: number;
  offsetY: number;
}

export function getCardShadow(theme: ThemeColors): AppShadowStyle {
  return {
    radius: 12,
    color: theme.cardShadow,
    offsetX: 0,
    offsetY: 4
  };
}

export function getRaisedCardShadow(theme: ThemeColors): AppShadowStyle {
  return {
    radius: 16,
    color: theme.cardShadow,
    offsetX: 0,
    offsetY: 8
  };
}

export function getFloatingShadow(theme: ThemeColors): AppShadowStyle {
  return {
    radius: 24,
    color: theme.cardShadow,
    offsetX: 0,
    offsetY: 12
  };
}
