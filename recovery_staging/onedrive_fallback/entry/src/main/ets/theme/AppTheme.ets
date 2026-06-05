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
  primary: '#3E7BFA',
  primaryLight: '#6E9BFF',
  primaryDark: '#2F63DB',
  accent: '#27C1A3',
  background: '#F4F8FD',
  surface: '#FFFFFF',
  surfaceLight: '#F6FAFF',
  surfaceRaised: '#FFFFFF',
  surfaceSoft: '#F6FAFF',
  surfaceOverlay: 'rgba(14, 24, 39, 0.18)',
  textPrimary: '#142033',
  textSecondary: '#5D708A',
  textMuted: '#8FA2BC',
  textOnPrimary: '#FFFFFF',
  divider: '#E2EAF4',
  success: '#2FB879',
  warning: '#F2AE45',
  danger: '#F05D63',
  info: '#3E7BFA',
  primarySubtle: '#EAF2FF',
  successSubtle: '#EAF8F2',
  warningSubtle: '#FFF5E6',
  dangerSubtle: '#FFF1F1',
  infoSubtle: '#EEF5FF',
  announcementSurface: '#EEF5FF',
  riskSurface: '#FFF1F1',
  premium: '#CFA24A',
  premiumSurface: '#FFF7E2',
  premiumText: '#71511A',
  premiumBorder: '#E7C87E',
  syncSuccessSurface: '#EAF8F2',
  syncErrorSurface: '#FFF1F1',
  cardShadow: 'rgba(20, 38, 63, 0.10)',
  navBackground: '#FFFFFF',
  cardBackground: '#FFFFFF',
  inputBackground: '#FFFFFF',
  borderColor: '#DCE6F2',
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
