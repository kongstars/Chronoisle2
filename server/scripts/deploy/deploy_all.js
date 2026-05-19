const { NodeSSH } = require('node-ssh');
const archiver = require('archiver');
const fs = require('fs');
const path = require('path');
const { ALL_SERVERS } = require('../shared/serverTargets');

const SERVER_ROOT = path.resolve(__dirname, '../..');

async function buildArtifact() {
  return new Promise((resolve, reject) => {
    const artifactPath = path.join(__dirname, 'deploy_bundle.zip');
    const output = fs.createWriteStream(artifactPath);
    const archive = archiver('zip', { zlib: { level: 9 } });

    output.on('close', () => resolve(artifactPath));
    output.on('error', reject);
    archive.on('error', reject);

    archive.pipe(output);
    archive.glob('**/*', {
      cwd: SERVER_ROOT,
      dot: true,
      ignore: [
        'node_modules/**',
        '.deploy_tmp/**',
        '*.zip',
        'logs/**',
        '.env',
        '.env.*'
      ]
    });
    archive.finalize();
  });
}

async function deployServer(server, artifactPath) {
  const ssh = new NodeSSH();
  const remoteZip = '/opt/chronoisle_deploy.zip';

  try {
    console.log(`Deploying to ${server.label} (${server.host})`);
    await ssh.connect({
      host: server.host,
      username: 'root',
      password: server.password,
      readyTimeout: 30000
    });

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

    console.log(result.stdout.trim());
  } finally {
    ssh.dispose();
  }
}

async function main() {
  const artifactPath = await buildArtifact();

  try {
    for (const server of ALL_SERVERS) {
      await deployServer(server, artifactPath);
    }
  } finally {
    if (fs.existsSync(artifactPath)) {
      fs.unlinkSync(artifactPath);
    }
  }
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});
