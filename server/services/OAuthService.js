const axios = require('axios');

const OAUTH_TIMEOUT = 10000; // 10 秒超时，防止外部服务挂起耗尽连接

const http = axios.create({ timeout: OAUTH_TIMEOUT });

class OAuthService {
  /**
   * 获取微信登录URL
   */
  static getWeChatAuthUrl(state = '') {
    const params = new URLSearchParams({
      appid: process.env.WECHAT_APP_ID,
      redirect_uri: process.env.WECHAT_REDIRECT_URI,
      response_type: 'code',
      scope: 'snsapi_userinfo',
      state: state || 'wechat_login'
    });
    return `https://open.weixin.qq.com/connect/oauth2/authorize?${params.toString()}#wechat_redirect`;
  }

  /**
   * 获取微信access_token
   */
  static async getWeChatAccessToken(code) {
    const url = 'https://api.weixin.qq.com/sns/oauth2/access_token';
    const params = {
      appid: process.env.WECHAT_APP_ID,
      secret: process.env.WECHAT_APP_SECRET,
      code,
      grant_type: 'authorization_code'
    };
    
    const response = await http.get(url, { params });
    return response.data;
  }

  /**
   * 获取微信用户信息
   */
  static async getWeChatUserInfo(accessToken, openId) {
    const url = 'https://api.weixin.qq.com/sns/userinfo';
    const params = {
      access_token: accessToken,
      openid: openId,
      lang: 'zh_CN'
    };
    
    const response = await http.get(url, { params });
    return response.data;
  }

  /**
   * 获取QQ登录URL
   */
  static getQQAuthUrl(state = '') {
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: process.env.QQ_APP_ID,
      redirect_uri: process.env.QQ_REDIRECT_URI,
      state: state || 'qq_login',
      scope: 'get_user_info'
    });
    return `https://graph.qq.com/oauth2.0/authorize?${params.toString()}`;
  }

  /**
   * 获取QQ access_token
   */
  static async getQQAccessToken(code) {
    const url = 'https://graph.qq.com/oauth2.0/token';
    const params = {
      grant_type: 'authorization_code',
      client_id: process.env.QQ_APP_ID,
      client_secret: process.env.QQ_APP_KEY,
      code,
      redirect_uri: process.env.QQ_REDIRECT_URI
    };
    
    const response = await http.get(url, { params });
    // QQ返回的是字符串格式：access_token=xxx&expires_in=7776000&refresh_token=xxx
    const result = {};
    response.data.split('&').forEach(pair => {
      const [key, value] = pair.split('=');
      result[key] = value;
    });
    return result;
  }

  /**
   * 获取QQ openId
   */
  static async getQQOpenId(accessToken) {
    const url = 'https://graph.qq.com/oauth2.0/me';
    const params = { access_token: accessToken };
    
    const response = await http.get(url, { params });
    // QQ返回的是JSONP格式：callback( {"client_id":"YOUR_APPID","openid":"YOUR_OPENID"} );
    const jsonp = response.data;
    const jsonStr = jsonp.substring(jsonp.indexOf('{'), jsonp.lastIndexOf('}') + 1);
    return JSON.parse(jsonStr);
  }

  /**
   * 获取QQ用户信息
   */
  static async getQQUserInfo(accessToken, openId) {
    const url = 'https://graph.qq.com/user/get_user_info';
    const params = {
      access_token: accessToken,
      oauth_consumer_key: process.env.QQ_APP_ID,
      openid: openId
    };
    
    const response = await http.get(url, { params });
    return response.data;
  }
  /**
   * 获取华为登录URL
   */
  static getHuaweiAuthUrl(state = '') {
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: process.env.HUAWEI_CLIENT_ID,
      redirect_uri: process.env.HUAWEI_REDIRECT_URI,
      scope: 'openid profile',
      state: state || 'huawei_login'
    });
    return `https://oauth-login.cloud.huawei.com/oauth2/v3/authorize?${params.toString()}`;
  }

  /**
   * 用授权码换取华为 access_token 和 id_token
   */
  static async getHuaweiAccessToken(code) {
    const url = 'https://oauth-login.cloud.huawei.com/oauth2/v3/token';
    const params = new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      client_id: process.env.HUAWEI_CLIENT_ID,
      client_secret: process.env.HUAWEI_CLIENT_SECRET,
      redirect_uri: process.env.HUAWEI_REDIRECT_URI
    });

    const response = await http.post(url, params.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    });
    return response.data;
  }

  /**
   * 获取华为用户信息
   */
  static async getHuaweiUserInfo(accessToken) {
    const url = 'https://account.cloud.huawei.com/rest.php?nsp_svc=GOpen.User.getInfo';
    const params = new URLSearchParams({
      access_token: accessToken,
      getNickName: '1'
    });

    const response = await http.post(url, params.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    });
    return response.data;
  }
}

module.exports = OAuthService;