import { ThemeColors } from '../../theme/AppTheme';

export interface AppShadowStyle {
  radius: number;
  color: string;
  offsetX: number;
  offsetY: number;
}

export function getCardShadow(theme: ThemeColors): AppShadowStyle {
  return {
    radius: 8,
    color: theme.cardShadow,
    offsetX: 0,
    offsetY: 3
  };
}

export function getRaisedCardShadow(theme: ThemeColors): AppShadowStyle {
  return {
    radius: 14,
    color: theme.cardShadow,
    offsetX: 0,
    offsetY: 6
  };
}

export function getFloatingShadow(theme: ThemeColors): AppShadowStyle {
  return {
    radius: 20,
    color: theme.cardShadow,
    offsetX: 0,
    offsetY: 10
  };
}
