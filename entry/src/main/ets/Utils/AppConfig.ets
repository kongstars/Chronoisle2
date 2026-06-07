import BuildProfile from 'BuildProfile';

export enum AppEnvironment {
  TEST = 'test',
  PRODUCTION = 'production'
}

export default class AppConfig {
  private static readonly MOCK_MEMBERSHIP_PURCHASE: boolean = false;
  private static readonly TEST_BASE_URL: string = 'https://test-api.sishiqingdan.cn';
  // 正式环境统一走主站域名，避免 API 子域名未正确代理时导致云端 AI / 会员等能力被 403 拦截。
  private static readonly PRODUCTION_BASE_URL: string = 'https://sishiqingdan.cn';

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
