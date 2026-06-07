export enum ThemeMode {
  LIGHT = 'light',
  DARK = 'dark',
  SYSTEM = 'system'
}

export interface ThemeColors {
  primary: string;
  primaryLight: string;
  primaryDark: string;
  accent: string;
  background: string;
  surface: string;
  surfaceLight: string;
  surfaceRaised: string;
  surfaceSoft: string;
  surfaceOverlay: string;
  textPrimary: string;
  textSecondary: string;
  textMuted: string;
  textOnPrimary: string;
  divider: string;
  success: string;
  warning: string;
  danger: string;
  info: string;
  primarySubtle: string;
  successSubtle: string;
  warningSubtle: string;
  dangerSubtle: string;
  infoSubtle: string;
  announcementSurface: string;
  riskSurface: string;
  premium: string;
  premiumSurface: string;
  premiumText: string;
  premiumBorder: string;
  syncSuccessSurface: string;
  syncErrorSurface: string;
  cardShadow: string;
  navBackground: string;
  cardBackground: string;
  inputBackground: string;
  borderColor: string;
  transparent: string;
  
  // V2 Tokens
  bgBase: string;
  bgPattern: string;
  surfaceBase: string;
  surfacePressed: string;
  brandPrimary: string;
  brandLight: string;
  semanticSuccess: string;
  semanticDanger: string;
  semanticWarning: string;
  borderLight: string;
  borderHighlight: string;
}

export const LightTheme: ThemeColors = {
  primary: '#5B5CE6',
  primaryLight: 'rgba(91, 92, 230, 0.08)',
  primaryDark: '#5F62DA',
  accent: '#FFB56F',
  background: '#F0F2F7',
  surface: '#FFFFFF',
  surfaceLight: '#FAFBFC',
  surfaceRaised: '#FFFFFF',
  surfaceSoft: '#F4F5F8',
  surfaceOverlay: 'rgba(43, 34, 51, 0.12)',
  textPrimary: '#14151A',
  textSecondary: '#525666',
  textMuted: '#8E93A6',
  textOnPrimary: '#FFFFFF',
  divider: 'rgba(0, 0, 0, 0.05)',
  success: '#05A660',
  warning: '#D97706',
  danger: '#E63946',
  info: '#5B5CE6',
  primarySubtle: 'rgba(91, 92, 230, 0.08)',
  successSubtle: 'rgba(5, 166, 96, 0.08)',
  warningSubtle: 'rgba(217, 119, 6, 0.08)',
  dangerSubtle: 'rgba(230, 57, 70, 0.08)',
  infoSubtle: 'rgba(91, 92, 230, 0.08)',
  announcementSurface: 'rgba(91, 92, 230, 0.08)',
  riskSurface: 'rgba(230, 57, 70, 0.08)',
  premium: '#C79A4C',
  premiumSurface: '#FFF6E3',
  premiumText: '#71511A',
  premiumBorder: '#E4C780',
  syncSuccessSurface: 'rgba(5, 166, 96, 0.08)',
  syncErrorSurface: 'rgba(230, 57, 70, 0.08)',
  cardShadow: 'rgba(0, 0, 0, 0.02)',
  navBackground: '#FFFFFF',
  cardBackground: '#FFFFFF',
  inputBackground: '#F4F5F8',
  borderColor: 'rgba(0, 0, 0, 0.05)',
  transparent: 'rgba(0, 0, 0, 0)',

  // V2 Tokens
  bgBase: '#F0F2F7',
  bgPattern: 'rgba(0, 0, 0, 0.03)',
  surfaceBase: '#FFFFFF',
  surfacePressed: '#F4F5F8',
  brandPrimary: '#5B5CE6',
  brandLight: 'rgba(91, 92, 230, 0.08)',
  semanticSuccess: '#05A660',
  semanticDanger: '#E63946',
  semanticWarning: '#D97706',
  borderLight: 'rgba(0, 0, 0, 0.05)',
  borderHighlight: 'rgba(255, 255, 255, 0.8)'
};

export const DarkTheme: ThemeColors = {
  primary: '#7A7CFF',
  primaryLight: 'rgba(122, 124, 255, 0.15)',
  primaryDark: '#817BEA',
  accent: '#F1A765',
  background: '#0D0E12',
  surface: '#1A1B23',
  surfaceLight: '#1E1F29',
  surfaceRaised: '#1E1F29',
  surfaceSoft: '#22242E',
  surfaceOverlay: 'rgba(9, 5, 14, 0.40)',
  textPrimary: '#F3F4F8',
  textSecondary: '#A0A4B8',
  textMuted: '#6B6F85',
  textOnPrimary: '#FFFFFF',
  divider: 'rgba(255, 255, 255, 0.06)',
  success: '#05C973',
  warning: '#FBBF24',
  danger: '#FF4D5E',
  info: '#7A7CFF',
  primarySubtle: 'rgba(122, 124, 255, 0.15)',
  successSubtle: 'rgba(5, 201, 115, 0.1)',
  warningSubtle: 'rgba(251, 191, 36, 0.1)',
  dangerSubtle: 'rgba(255, 77, 94, 0.15)',
  infoSubtle: 'rgba(122, 124, 255, 0.15)',
  announcementSurface: 'rgba(122, 124, 255, 0.15)',
  riskSurface: 'rgba(255, 77, 94, 0.15)',
  premium: '#E1BA65',
  premiumSurface: '#352A1B',
  premiumText: '#F4DEB1',
  premiumBorder: '#8E7241',
  syncSuccessSurface: 'rgba(5, 201, 115, 0.1)',
  syncErrorSurface: 'rgba(255, 77, 94, 0.15)',
  cardShadow: 'rgba(0, 0, 0, 0.4)',
  navBackground: '#1A1B23',
  cardBackground: '#1A1B23',
  inputBackground: '#22242E',
  borderColor: 'rgba(255, 255, 255, 0.06)',
  transparent: 'rgba(0, 0, 0, 0)',

  // V2 Tokens
  bgBase: '#0D0E12',
  bgPattern: 'rgba(255, 255, 255, 0.04)',
  surfaceBase: '#1A1B23',
  surfacePressed: '#22242E',
  brandPrimary: '#7A7CFF',
  brandLight: 'rgba(122, 124, 255, 0.15)',
  semanticSuccess: '#05C973',
  semanticDanger: '#FF4D5E',
  semanticWarning: '#FBBF24',
  borderLight: 'rgba(255, 255, 255, 0.06)',
  borderHighlight: 'rgba(255, 255, 255, 0.12)'
};

export class ThemeManager {
  static getTheme(mode: ThemeMode, systemIsDark: boolean = false): ThemeColors {
    if (mode === ThemeMode.DARK) {
      return DarkTheme;
    } else if (mode === ThemeMode.LIGHT) {
      return LightTheme;
    } else {
      return systemIsDark ? DarkTheme : LightTheme;
    }
  }
}

export interface AppThemeType {
  palette: ThemeColors;
}

export const AppTheme: AppThemeType = {
  palette: LightTheme
};
