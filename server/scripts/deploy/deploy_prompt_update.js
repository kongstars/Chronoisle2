const { NodeSSH } = require('node-ssh');
const path = require('path');
const { ALL_SERVERS } = require('../shared/serverTargets');

const localFile = path.join(__dirname, '..', '..', 'routes', 'goalPlanning.js');

async function deploy() {
  for (const server of ALL_SERVERS) {
    const ssh = new NodeSSH();

    try {
      console.log(`[${server.label}] uploading goalPlanning.js`);
      await ssh.connect({
        host: server.host,
        username: 'root',
        password: server.password,
        readyTimeout: 30000
      });

      await ssh.putFile(localFile, `${server.appDir}/routes/goalPlanning.js`);
      const result = await ssh.execCommand(`cd "${server.appDir}" && pm2 restart "${server.pm2Name}" --update-env`);
      if (result.code !== 0) {
        throw new Error(result.stderr || result.stdout || 'restart failed');
      }

      console.log(`[${server.label}] ${result.stdout.trim()}`);
    } finally {
      ssh.dispose();
    }
  }
}

deploy().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});
