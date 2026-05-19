module.exports = {
  apps: [
    {
      name: 'chronoisle-server-prod',
      script: './index.js',
      exec_mode: 'fork',
      instances: 1,
      max_memory_restart: '512M',
      error_file: './logs/error.log',
      out_file: './logs/out.log',
      merge_logs: true,
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000,
        MONGODB_URI: 'mongodb://127.0.0.1:27017/sishiqingdan_prod'
      }
    }
  ]
};
