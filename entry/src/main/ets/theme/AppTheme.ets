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
}

export const LightTheme: ThemeColors = {
  primary: '#7679F5',
  primaryLight: '#9A96FF',
  primaryDark: '#5F62DA',
  accent: '#FFB56F',
  background: '#FBF4E9',
  surface: '#FFFDF9',
  surfaceLight: '#FFFBF6',
  surfaceRaised: '#FFFFFF',
  surfaceSoft: '#F7EFE6',
  surfaceOverlay: 'rgba(43, 34, 51, 0.12)',
  textPrimary: '#2B2233',
  textSecondary: '#786C7D',
  textMuted: '#B2A7B1',
  textOnPrimary: '#FFFFFF',
  divider: '#EEE5DA',
  success: '#42A483',
  warning: '#D69041',
  danger: '#DD7A72',
  info: '#9A96FF',
  primarySubtle: '#F3EDFF',
  successSubtle: '#EEF8F3',
  warningSubtle: '#FFF2E2',
  dangerSubtle: '#FCEEEB',
  infoSubtle: '#F6F0FF',
  announcementSurface: '#F7F1FF',
  riskSurface: '#FCEEEB',
  premium: '#C79A4C',
  premiumSurface: '#FFF6E3',
  premiumText: '#71511A',
  premiumBorder: '#E4C780',
  syncSuccessSurface: '#EEF8F3',
  syncErrorSurface: '#FCEEEB',
  cardShadow: 'rgba(91, 68, 52, 0.10)',
  navBackground: '#FFFDF9',
  cardBackground: '#FFFFFF',
  inputBackground: '#FFF9F3',
  borderColor: '#E7DDD1',
  transparent: 'rgba(0, 0, 0, 0)'
};

export const DarkTheme: ThemeColors = {
  primary: '#9A96FF',
  primaryLight: '#BEB6FF',
  primaryDark: '#817BEA',
  accent: '#F1A765',
  background: '#17121D',
  surface: '#211827',
  surfaceLight: '#2A1F30',
  surfaceRaised: '#2D2234',
  surfaceSoft: '#261D2D',
  surfaceOverlay: 'rgba(9, 5, 14, 0.40)',
  textPrimary: '#F5EDF7',
  textSecondary: '#B8A8BF',
  textMuted: '#8F7F97',
  textOnPrimary: '#FFFFFF',
  divider: 'rgba(255, 255, 255, 0.08)',
  success: '#59B294',
  warning: '#F1A765',
  danger: '#D98C86',
  info: '#BEB6FF',
  primarySubtle: '#31263A',
  successSubtle: '#24372E',
  warningSubtle: '#3A2B23',
  dangerSubtle: '#3A2930',
  infoSubtle: '#30273B',
  announcementSurface: '#30273B',
  riskSurface: '#3A2930',
  premium: '#E1BA65',
  premiumSurface: '#352A1B',
  premiumText: '#F4DEB1',
  premiumBorder: '#8E7241',
  syncSuccessSurface: '#24372E',
  syncErrorSurface: '#3A2930',
  cardShadow: 'rgba(7, 5, 10, 0.32)',
  navBackground: '#231A2A',
  cardBackground: '#211827',
  inputBackground: '#2A1F30',
  borderColor: '#3A2D43',
  transparent: 'rgba(0, 0, 0, 0)'
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
