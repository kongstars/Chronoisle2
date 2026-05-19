import dataPreferences from '@ohos.data.preferences';
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant';
import resourceManager from '@ohos.resourceManager';
import { ThemeMode, ThemeColors, ThemeManager, LightTheme } from '../theme/AppTheme';
import { Logger } from '../Utils/Logger';

const logger = Logger.create('ThemeService');

const PREFERENCES_NAME = 'app_theme_prefs';
const THEME_MODE_KEY = 'theme_mode';
export const CURRENT_COLOR_MODE_KEY = 'currentColorMode';
export const SYSTEM_IS_DARK_KEY = 'systemIsDark';

interface ThemeConfigLike {
  colorMode?: ConfigurationConstant.ColorMode;
}

interface ThemeResourceConfigLike {
  colorMode?: resourceManager.ColorMode;
}

interface ThemeResourceManagerLike {
  getConfiguration?: () => Promise<ThemeResourceConfigLike>;
}

interface ThemeContextLike {
  config?: ThemeConfigLike;
  resourceManager?: ThemeResourceManagerLike;
  setColorMode?: (colorMode: ConfigurationConstant.ColorMode) => void;
}

class ThemeService {
  private prefs: dataPreferences.Preferences | null = null;
  private currentMode: ThemeMode = ThemeMode.SYSTEM;
  private currentColors: ThemeColors = LightTheme;
  private listeners: Array<(colors: ThemeColors) => void> = [];
  private hostContext: ThemeContextLike | null = null;
  private isSyncingContextColorMode: boolean = false;

  async initialize(context: Context): Promise<void> {
    const themeContext = context as ThemeContextLike;
    if (typeof themeContext.setColorMode === 'function') {
      this.hostContext = themeContext;
    }

    if (!this.prefs) {
      try {
        this.prefs = await dataPreferences.getPreferences(context, PREFERENCES_NAME);
      } catch (error) {
        logger.error('ThemeService initialize error', error as Object);
      }
    }

    const systemIsDark = await this.resolveSystemIsDark(themeContext);
    AppStorage.setOrCreate<boolean>(SYSTEM_IS_DARK_KEY, systemIsDark);

    const savedMode = this.loadSavedThemeMode();
    this.currentMode = savedMode;
    this.syncContextColorMode();
    this.applyTheme(savedMode);
  }

  getThemeMode(): ThemeMode {
    return this.currentMode;
  }

  getThemeColors(): ThemeColors {
    return this.currentColors;
  }

  isSyncingProgrammaticColorMode(): boolean {
    return this.isSyncingContextColorMode;
  }

  async setThemeMode(mode: ThemeMode): Promise<void> {
    this.currentMode = mode;
    this.syncContextColorMode();
    this.applyTheme(mode);
    this.notifyListeners();
    if (this.prefs) {
      try {
        await this.prefs.put(THEME_MODE_KEY, mode);
        await this.prefs.flush();
      } catch (error) {
        logger.error('ThemeService setThemeMode error', error as Object);
      }
    }
  }

  private applyTheme(mode: ThemeMode): void {
    const systemIsDark = AppStorage.get<boolean>(SYSTEM_IS_DARK_KEY) || false;
    this.currentColors = ThemeManager.getTheme(mode, systemIsDark);
    AppStorage.setOrCreate<ThemeColors>('themeColors', this.currentColors);
    AppStorage.setOrCreate<string>('themeMode', mode);
  }

  updateSystemTheme(isDark: boolean): void {
    AppStorage.setOrCreate<boolean>(SYSTEM_IS_DARK_KEY, isDark);
    AppStorage.setOrCreate<ConfigurationConstant.ColorMode>(
      CURRENT_COLOR_MODE_KEY,
      isDark ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    );
    this.applyTheme(this.currentMode);
    this.notifyListeners();
  }

  refreshSystemTheme(colorMode?: ConfigurationConstant.ColorMode): void {
    let nextColorMode = colorMode;
    if (nextColorMode === undefined) {
      nextColorMode = this.hostContext?.config?.colorMode;
    }

    if (nextColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      this.updateSystemTheme(true);
      return;
    }

    if (nextColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      this.updateSystemTheme(false);
      return;
    }

    this.updateSystemTheme(AppStorage.get<boolean>(SYSTEM_IS_DARK_KEY) || false);
  }

  subscribe(listener: (colors: ThemeColors) => void): void {
    this.listeners.push(listener);
  }

  unsubscribe(listener: (colors: ThemeColors) => void): void {
    const index = this.listeners.indexOf(listener);
    if (index > -1) {
      this.listeners.splice(index, 1);
    }
  }

  private notifyListeners(): void {
    this.listeners.forEach(listener => listener(this.currentColors));
  }

  isDarkThemeActive(): boolean {
    return (AppStorage.get<ThemeColors>('themeColors') || this.currentColors).background !== LightTheme.background;
  }

  private loadSavedThemeMode(): ThemeMode {
    if (!this.prefs) {
      return this.currentMode;
    }

    try {
      const savedMode = this.prefs.getSync(THEME_MODE_KEY, ThemeMode.SYSTEM) as string;
      if (savedMode === ThemeMode.LIGHT || savedMode === ThemeMode.DARK || savedMode === ThemeMode.SYSTEM) {
        return savedMode as ThemeMode;
      }
    } catch (error) {
      logger.error('ThemeService loadSavedThemeMode error', error as Object);
    }

    return ThemeMode.SYSTEM;
  }

  private async resolveSystemIsDark(context: ThemeContextLike): Promise<boolean> {
    try {
      const config = await context.resourceManager?.getConfiguration?.();
      if (config?.colorMode === resourceManager.ColorMode.DARK) {
        return true;
      }

      if (config?.colorMode === resourceManager.ColorMode.LIGHT) {
        return false;
      }
    } catch (error) {
      logger.error('ThemeService resolveSystemIsDark resourceManager error', error as Object);
    }

    const storedColorMode = AppStorage.get<ConfigurationConstant.ColorMode>(CURRENT_COLOR_MODE_KEY);
    if (storedColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      return true;
    }

    if (storedColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      return false;
    }

    if (context.config?.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
      return true;
    }

    if (context.config?.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
      return false;
    }

    return AppStorage.get<boolean>(SYSTEM_IS_DARK_KEY) || false;
  }

  private syncContextColorMode(): void {
    if (!this.hostContext?.setColorMode) {
      return;
    }

    if (this.isSyncingContextColorMode) {
      return;
    }

    try {
      this.isSyncingContextColorMode = true;
      if (this.currentMode === ThemeMode.DARK) {
        this.hostContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else if (this.currentMode === ThemeMode.LIGHT) {
        this.hostContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else {
        this.hostContext.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (error) {
      logger.error('ThemeService syncContextColorMode error', error as Object);
    } finally {
      this.isSyncingContextColorMode = false;
    }
  }
}

export const themeService = new ThemeService();
