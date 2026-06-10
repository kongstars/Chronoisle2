const { NodeSSH } = require('node-ssh');
(async () => {
  const ssh = new NodeSSH();
  try {
    await ssh.connect({ host: '114.55.135.35', username: 'root', password: 'Zcqgfjf64805882', readyTimeout: 30000 });
    const cmds = [
      "pm2 describe chronoisle-server-prod",
      "pm2 logs chronoisle-server-prod --lines 120 --nostream",
      "curl -sS --max-time 10 http://127.0.0.1:3000/health"
    ];
    for (const cmd of cmds) {
      const res = await ssh.execCommand(cmd);
      console.log(`\\n>>> ${cmd}\\n[code] ${res.code}\\n[stdout]\\n${res.stdout}\\n[stderr]\\n${res.stderr}`);
    }
  } finally {
    ssh.dispose();
  }
})().catch((err) => { console.error(err && err.stack ? err.stack : String(err)); process.exit(1); });
