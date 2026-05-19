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
  primary: '#4A8CFE',
  primaryLight: '#7AA9FF',
  primaryDark: '#3E7BE8',
  accent: '#3DD4B0',
  background: '#F5F9FC',
  surface: '#FFFFFF',
  surfaceLight: '#F8FBFE',
  surfaceRaised: '#FFFFFF',
  surfaceSoft: '#F8FBFE',
  surfaceOverlay: 'rgba(14, 24, 39, 0.14)',
  textPrimary: '#142033',
  textSecondary: '#8B9CB0',
  textMuted: '#A8B8CC',
  textOnPrimary: '#FFFFFF',
  divider: '#E8EDF3',
  success: '#34C982',
  warning: '#F5B850',
  danger: '#F05D63',
  info: '#4A8CFE',
  primarySubtle: '#EEF4FF',
  successSubtle: '#EDFAF4',
  warningSubtle: '#FFF8EE',
  dangerSubtle: '#FFF5F5',
  infoSubtle: '#F0F6FF',
  announcementSurface: '#F0F6FF',
  riskSurface: '#FFF5F5',
  premium: '#CFA24A',
  premiumSurface: '#FFF7E2',
  premiumText: '#71511A',
  premiumBorder: '#E7C87E',
  syncSuccessSurface: '#EDFAF4',
  syncErrorSurface: '#FFF5F5',
  cardShadow: 'rgba(20, 38, 63, 0.08)',
  navBackground: '#FFFFFF',
  cardBackground: '#FFFFFF',
  inputBackground: '#FFFFFF',
  borderColor: '#E4EAF2',
  transparent: 'rgba(0, 0, 0, 0)'
};

export const DarkTheme: ThemeColors = {
  primary: '#6E9BFF',
  primaryLight: '#8EB0FF',
  primaryDark: '#4D76E5',
  accent: '#3AC8AC',
  background: '#121A28',
  surface: '#182233',
  surfaceLight: '#1D2A3E',
  surfaceRaised: '#1B283B',
  surfaceSoft: '#1D2A3E',
  surfaceOverlay: 'rgba(0, 0, 0, 0.28)',
  textPrimary: '#F4F7FB',
  textSecondary: '#B1BED2',
  textMuted: '#8594AA',
  textOnPrimary: '#FFFFFF',
  divider: 'rgba(255, 255, 255, 0.08)',
  success: '#48C78A',
  warning: '#F2B85B',
  danger: '#FF7275',
  info: '#8EB0FF',
  primarySubtle: '#213251',
  successSubtle: '#1F362B',
  warningSubtle: '#392D18',
  dangerSubtle: '#3A2027',
  infoSubtle: '#1D2E47',
  announcementSurface: '#1D2E47',
  riskSurface: '#3A2027',
  premium: '#E1BA65',
  premiumSurface: '#302615',
  premiumText: '#F5DDA1',
  premiumBorder: '#927233',
  syncSuccessSurface: '#1F362B',
  syncErrorSurface: '#3A2027',
  cardShadow: 'rgba(2, 10, 24, 0.24)',
  navBackground: '#1B283B',
  cardBackground: '#182233',
  inputBackground: '#1B283B',
  borderColor: '#293750',
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
