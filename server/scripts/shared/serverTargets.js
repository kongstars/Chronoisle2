function readServerPassword(envName) {
  const value = String(process.env[envName] || '').trim();
  if (!value) {
    console.warn(`[serverTargets] 缺少环境变量 ${envName}，相关部署脚本将无法通过密码方式登录服务器`);
  }
  return value;
}

const TEST_SERVER = {
  name: 'test',
  label: 'test',
  host: '114.55.135.35',
  password: readServerPassword('CHRONOISLE_TEST_SERVER_PASSWORD'),
  appDir: '/opt/chronoisle-server',
  backupDir: '/opt/chronoisle-backups',
  pm2Name: 'chronoisle-server-prod',
  healthPort: 3000,
  mongoDb: 'chronoisle_prod'
};

const PROD_SERVER = {
  name: 'prod',
  label: 'prod',
  host: '116.62.6.179',
  password: readServerPassword('CHRONOISLE_PROD_SERVER_PASSWORD'),
  appDir: '/opt/chronoisle-server',
  backupDir: '/opt/chronoisle-backups',
  pm2Name: 'sishiqingdan-server-prod',
  healthPort: 3000,
  mongoDb: 'sishiqingdan_prod'
};

const ALL_SERVERS = [TEST_SERVER, PROD_SERVER];

module.exports = {
  TEST_SERVER,
  PROD_SERVER,
  ALL_SERVERS
};
