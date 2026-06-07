const { NodeSSH } = require('node-ssh');
const archiver = require('archiver');
const fs = require('fs');
const path = require('path');
const { PROD_SERVER } = require('../shared/serverTargets');

const SERVER_ROOT = path.resolve(__dirname, '../..');

function buildRemoteEnvPatchCommand() {
  const updates = {
    NODE_ENV: 'production',
    PORT: String(PROD_SERVER.healthPort),
    MONGODB_URI: `mongodb://127.0.0.1:27017/${PROD_SERVER.mongoDb}`,
    CORS_ORIGIN: 'https://sishiqingdan.cn,https://www.sishiqingdan.cn,https://api.sishiqingdan.cn,https://test-api.sishiqingdan.cn'
  };
  const patchScript = `
const fs = require('fs');
const file = '.env.production';
const updates = ${JSON.stringify(updates)};
const existing = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
const seen = new Set();
const lines = [];
for (const line of existing.split(/\\r?\\n/)) {
  if (!line.trim()) continue;
  const key = line.split('=')[0];
  if (Object.prototype.hasOwnProperty.call(updates, key)) {
    if (!seen.has(key)) {
      lines.push(key + '=' + updates[key]);
      seen.add(key);
    }
  } else {
    lines.push(line);
  }
}
for (const [key, value] of Object.entries(updates)) {
  if (!seen.has(key)) lines.push(key + '=' + value);
}
fs.writeFileSync(file, lines.join('\\n') + '\\n', 'utf8');
`;
  return `cd "${PROD_SERVER.appDir}" && node <<'NODE_ENV_PATCH'\n${patchScript}\nNODE_ENV_PATCH`;
}

function buildNginxInstallCommand() {
  return [
    `install -m 644 "${PROD_SERVER.appDir}/nginx_prod.conf" "/etc/nginx/conf.d/chronoisle-prod.conf"`,
    'nginx -t',
    '(systemctl reload nginx || nginx -s reload)'
  ].join(' && ');
}

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
    await execStep(ssh, 'patch-env', buildRemoteEnvPatchCommand());
    await execStep(ssh, 'npm-ci', `cd "${PROD_SERVER.appDir}" && npm ci --omit=dev`);
    await execStep(ssh, 'install-nginx', buildNginxInstallCommand());
    await execStep(
      ssh,
      'pm2-restart',
      `cd "${PROD_SERVER.appDir}" && export NODE_ENV=production PORT=${PROD_SERVER.healthPort} MONGODB_URI="mongodb://127.0.0.1:27017/${PROD_SERVER.mongoDb}" && (pm2 describe "${PROD_SERVER.pm2Name}" >/dev/null 2>&1 && pm2 restart "${PROD_SERVER.pm2Name}" --update-env || pm2 start index.js --name "${PROD_SERVER.pm2Name}" --update-env)`
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
