const { NodeSSH } = require('node-ssh');
const archiver = require('archiver');
const fs = require('fs');
const path = require('path');
const { ALL_SERVERS } = require('../shared/serverTargets');

const SERVER_ROOT = path.resolve(__dirname, '../..');
const TMP_DIR = path.join(SERVER_ROOT, '.deploy_tmp');

function getTimestamp() {
  const now = new Date();
  const pad = (value) => String(value).padStart(2, '0');
  return `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
}

async function ensureTmpDir() {
  await fs.promises.mkdir(TMP_DIR, { recursive: true });
}

async function buildArtifact(timestamp) {
  await ensureTmpDir();
  const artifactPath = path.join(TMP_DIR, `server_deploy_${timestamp}.zip`);
  await fs.promises.rm(artifactPath, { force: true });

  await new Promise((resolve, reject) => {
    const output = fs.createWriteStream(artifactPath);
    const archive = archiver('zip', { zlib: { level: 9 } });

    output.on('close', resolve);
    output.on('error', reject);
    archive.on('error', reject);

    archive.pipe(output);
    archive.glob('**/*', {
      cwd: SERVER_ROOT,
      dot: true,
      ignore: [
        'node_modules/**',
        '.deploy_tmp/**',
        '.env',
        '.env.*',
        '*.zip',
        'logs/**'
      ]
    });
    archive.finalize();
  });

  return artifactPath;
}

async function backupRemote(ssh, server, timestamp) {
  const backupName = `chronoisle_server_${server.name}_${timestamp}.tar.gz`;
  const backupPath = `${server.backupDir}/${backupName}`;
  const command = [
    `mkdir -p "${server.backupDir}"`,
    `[ -d "${server.appDir}" ]`,
    `tar -czf "${backupPath}" -C "${path.posix.dirname(server.appDir)}" "${path.posix.basename(server.appDir)}"`
  ].join(' && ');
  const result = await ssh.execCommand(command);
  if (result.code !== 0) {
    throw new Error(result.stderr || result.stdout || 'remote backup failed');
  }
  return backupPath;
}

async function deployServer(server, artifactPath, timestamp) {
  const ssh = new NodeSSH();
  const remoteZip = `/opt/server_deploy_${timestamp}.zip`;

  try {
    await ssh.connect({
      host: server.host,
      username: 'root',
      password: server.password,
      readyTimeout: 30000
    });

    const backupPath = await backupRemote(ssh, server, timestamp);
    await ssh.putFile(artifactPath, remoteZip);

    const deployCommand = [
      `mkdir -p "${server.appDir}"`,
      `unzip -o "${remoteZip}" -d "${server.appDir}"`,
      `rm -f "${remoteZip}"`,
      `cd "${server.appDir}"`,
      'npm ci --omit=dev',
      `pm2 restart "${server.pm2Name}" --update-env`,
      `curl -s --max-time 10 http://127.0.0.1:${server.healthPort}/health`
    ].join(' && ');

    const result = await ssh.execCommand(deployCommand);
    if (result.code !== 0) {
      throw new Error(result.stderr || result.stdout || 'deploy failed');
    }

    return {
      server: server.label,
      backupPath,
      health: result.stdout.trim()
    };
  } finally {
    ssh.dispose();
  }
}

async function main() {
  const timestamp = getTimestamp();
  const artifactPath = await buildArtifact(timestamp);

  try {
    for (const server of ALL_SERVERS) {
      const summary = await deployServer(server, artifactPath, timestamp);
      console.log(`${summary.server}: ${summary.backupPath}`);
      console.log(summary.health);
    }
  } finally {
    await fs.promises.rm(TMP_DIR, { recursive: true, force: true });
  }
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});
