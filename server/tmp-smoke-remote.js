const { NodeSSH } = require('node-ssh');
(async () => {
  const ssh = new NodeSSH();
  const script = `cd /opt/chronoisle-server && node - <<'NODE'
require('dotenv').config({ path: '.env.production' });
const { createChatCompletion } = require('./utils/deepseekClient');
(async () => {
  const result = await createChatCompletion({
    model: process.env.VOICE_CLASSIFY_MODEL || process.env.DEEPSEEK_MODEL,
    timeoutMs: 10000,
    traceLabel: 'smoke.voice.intent',
    messages: [
      { role: 'system', content: '你是分类器，只返回 JSON。' },
      { role: 'user', content: '请把“明天要买一把吉他”分类为 task/reminder/goal/focus 之一。' }
    ]
  });
  console.log(JSON.stringify({ hasResult: !!result, content: result.content, model: result.model, durationMs: result.durationMs }));
})().catch((err) => { console.error(err && err.stack ? err.stack : String(err)); process.exit(1); });
NODE`;
  try {
    for (const host of ['114.55.135.35', '116.62.6.179']) {
      await ssh.connect({ host, username: 'root', password: 'Zcqgfjf64805882', readyTimeout: 30000 });
      const res = await ssh.execCommand(script);
      console.log(`\\n>>> ${host}\\n[code] ${res.code}\\n[stdout]\\n${res.stdout}\\n[stderr]\\n${res.stderr}`);
      ssh.dispose();
    }
  } finally {
    try { ssh.dispose(); } catch (_) {}
  }
})().catch((err) => { console.error(err && err.stack ? err.stack : String(err)); process.exit(1); });
