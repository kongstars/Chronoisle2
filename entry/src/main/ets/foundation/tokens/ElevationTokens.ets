import { ThemeColors } from '../../theme/AppTheme';

export interface AppShadowStyle {
  radius: number;
  color: string;
  offsetX: number;
  offsetY: number;
}

export function getCardShadow(theme: ThemeColors): AppShadowStyle {
  return {
    radius: 10,
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
    offsetY: 6
  };
}

export function getFloatingShadow(theme: ThemeColors): AppShadowStyle {
  return {
    radius: 22,
    color: theme.cardShadow,
    offsetX: 0,
    offsetY: 10
  };
}
