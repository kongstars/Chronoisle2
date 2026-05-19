import BuildProfile from 'BuildProfile';

export enum AppEnvironment {
  TEST = 'test',
  PRODUCTION = 'production'
}

export default class AppConfig {
  private static readonly MOCK_MEMBERSHIP_PURCHASE: boolean = false;
  private static readonly TEST_BASE_URL: string = 'https://test-api.sishiqingdan.cn';
  private static readonly PRODUCTION_BASE_URL: string = 'https://api.sishiqingdan.cn';

  private static isReleaseBuild(): boolean {
    return (BuildProfile.BUILD_MODE_NAME as string) === 'release';
  }

  static getEnvironment(): AppEnvironment {
    return AppConfig.isReleaseBuild() ? AppEnvironment.PRODUCTION : AppEnvironment.TEST;
  }

  static isTestEnvironment(): boolean {
    return !AppConfig.isReleaseBuild();
  }

  static getBaseUrl(): string {
    return AppConfig.isTestEnvironment() ? AppConfig.TEST_BASE_URL : AppConfig.PRODUCTION_BASE_URL;
  }

  static allowOfflineAuthFallback(): boolean {
    return AppConfig.isReleaseBuild();
  }

  static useMockMembershipPurchase(): boolean {
    return AppConfig.MOCK_MEMBERSHIP_PURCHASE;
  }

  static getMembershipProductIds(): string[] {
    return ['vip_monthly_continuous', 'vip_yearly_continuous'];
  }
}
