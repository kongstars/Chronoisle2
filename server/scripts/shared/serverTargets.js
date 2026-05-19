const TEST_SERVER = {
  name: 'test',
  label: 'test',
  host: '114.55.135.35',
  password: 'Zcqgfjf64805882',
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
  password: 'Zcqgfjf64805882',
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
