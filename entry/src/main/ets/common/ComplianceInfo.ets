/**
 * 合规与备案信息集中配置
 *
 * 上架前需要把所有备案号、客服联系方式、公司主体填入此文件。
 * 「关于」页与「算法披露」页都从这里读取，避免散落在多个页面里。
 *
 * 每一项都写明用途和填写来源，便于负责人对应。
 */
export class ComplianceInfo {
  /** 应用主体名称（与 AGC 后台、营业执照一致） */
  static readonly OPERATOR_NAME: string = '方江锋';

  /** 软件著作权登记号（中国版权保护中心签发） */
  static readonly COPYRIGHT_REG_NO: string = '【待填写：软著登记号】';

  /** ICP 备案号（如 京ICP备XXXXXXXX号-X） */
  static readonly ICP_BEIAN_NO: string = '浙ICP备2026021379号';

  /** ICP 备案查询入口（公开站点） */
  static readonly ICP_BEIAN_URL: string = 'https://beian.miit.gov.cn/';

  /** 公安备案号（公安备案系统签发） */
  static readonly POLICE_BEIAN_NO: string = '【待填写：公安备案号】';

  /** 公安备案查询入口（公开站点） */
  static readonly POLICE_BEIAN_URL: string = 'https://beian.gov.cn/';

  /** 移动应用程序备案号（工信部 App 备案） */
  static readonly APP_BEIAN_NO: string = '浙ICP备2026021379号-1A';

  /** 算法备案号（互联网信息服务算法备案系统） */
  static readonly ALGORITHM_BEIAN_NO: string = '【待填写：算法备案号】';

  /** 算法备案查询入口 */
  static readonly ALGORITHM_BEIAN_URL: string = 'https://beian.cac.gov.cn/';

  /** 客服邮箱 */
  static readonly CUSTOMER_SERVICE_EMAIL: string = 'fangjiangfeng@live.com';

  /** 客服电话（如不提供电话渠道可保留为空字符串） */
  static readonly CUSTOMER_SERVICE_PHONE: string = '';

  /** 公司联系地址（用于版权页、隐私政策） */
  static readonly OPERATOR_ADDRESS: string = '【待填写：联系地址】';

  /**
   * 是否为占位文本（未填写）
   * 用于「关于」页判断是否展示该字段。
   */
  static isPlaceholder(value: string): boolean {
    if (!value) return true;
    return value.startsWith('【待填写');
  }
}
