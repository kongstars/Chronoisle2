const { NodeSSH } = require('node-ssh');
const archiver = require('archiver');
const fs = require('fs');
const path = require('path');
const { PROD_SERVER } = require('../shared/serverTargets');

const SERVER_ROOT = path.resolve(__dirname, '../..');

async function execStep(ssh, label, command) {
  const result = await ssh.execCommand(command);
  const stdout = (result.stdout || '').trim();
  const stderr = (result.stderr || '').trim();

  if (stdout) {
    console.log(`[${label}] stdout:\n${stdout}`);
  }
  if (stderr) {
    console.warn(`[${label}] stderr:\n${stderr}`);
  }

  if (result.code !== 0) {
    throw new Error(`[${label}] failed with code ${result.code}`);
  }
}

async function waitForHealth(ssh, port, label) {
  const url = `http://127.0.0.1:${port}/health`;
  let lastError = 'health check did not run';

  for (let attempt = 1; attempt <= 10; attempt += 1) {
    const result = await ssh.execCommand(`curl -fsS --max-time 10 "${url}"`);
    if (result.code === 0) {
      const stdout = (result.stdout || '').trim();
      if (stdout) {
        console.log(`[${label}] health:\n${stdout}`);
      }
      return;
    }

    lastError = (result.stderr || result.stdout || `curl exit code ${result.code}`).trim();
    console.warn(`[${label}] health attempt ${attempt} failed: ${lastError}`);
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }

  throw new Error(`[${label}] health check failed: ${lastError}`);
}

async function buildArtifact() {
  return new Promise((resolve, reject) => {
    const artifactPath = path.join(__dirname, 'prod_deploy.zip');
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
        '*.zip',
        'logs/**',
        '.env',
        '.env.*'
      ]
    });
    archive.finalize();
  });
}

async function main() {
  const ssh = new NodeSSH();
  const artifactPath = await buildArtifact();
  const remoteZip = '/opt/prod_deploy.zip';

  try {
    await ssh.connect({
      host: PROD_SERVER.host,
      username: 'root',
      password: PROD_SERVER.password,
      readyTimeout: 30000
    });

    await ssh.putFile(artifactPath, remoteZip);
    await execStep(ssh, 'prepare-dir', `mkdir -p "${PROD_SERVER.appDir}"`);
    await execStep(ssh, 'unzip', `unzip -o "${remoteZip}" -d "${PROD_SERVER.appDir}"`);
    await execStep(ssh, 'cleanup-zip', `rm -f "${remoteZip}"`);
    await execStep(ssh, 'npm-ci', `cd "${PROD_SERVER.appDir}" && npm ci --omit=dev`);
    await execStep(
      ssh,
      'pm2-restart',
      `cd "${PROD_SERVER.appDir}" && (pm2 describe "${PROD_SERVER.pm2Name}" >/dev/null 2>&1 && pm2 restart "${PROD_SERVER.pm2Name}" --update-env || pm2 start index.js --name "${PROD_SERVER.pm2Name}")`
    );
    await waitForHealth(ssh, PROD_SERVER.healthPort, 'prod');
  } finally {
    ssh.dispose();
    if (fs.existsSync(artifactPath)) {
      fs.unlinkSync(artifactPath);
    }
  }
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});
