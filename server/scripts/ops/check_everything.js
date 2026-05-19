const { NodeSSH } = require('node-ssh');
const { ALL_SERVERS } = require('../shared/serverTargets');

async function processServer(server) {
  const ssh = new NodeSSH();

  try {
    await ssh.connect({
      host: server.host,
      username: 'root',
      password: server.password,
      readyTimeout: 30000
    });

    const serverScript = `
const mongoose = require('mongoose');

async function inspectDatabase(dbUri) {
  try {
    const conn = await mongoose.createConnection(dbUri).asPromise();
    const User = conn.model('User', new mongoose.Schema({ userId: String, displayId: String, account: String }, { strict: false }));
    const SyncData = conn.model('SyncData', new mongoose.Schema({ userId: String }, { strict: false }));

    const collections = await conn.db.listCollections().toArray();
    const names = collections.map((collection) => collection.name);
    if (names.includes('users') || names.includes('syncdatas')) {
      console.log('\\n--- ' + dbUri + ' ---');
      const users = await User.find({});
      users.forEach((user) => console.log('user=' + user.displayId + ' account=' + user.account + ' userId=' + user.userId));
      const syncs = await SyncData.find({});
      syncs.forEach((sync) => console.log('sync userId=' + sync.userId));
    }

    await conn.close();
  } catch (error) {
    console.log(error.message);
  }
}

async function main() {
  const adminConn = await mongoose.createConnection('mongodb://127.0.0.1:27017/admin').asPromise();
  const dbs = await adminConn.db.admin().listDatabases();
  for (const dbInfo of dbs.databases) {
    if (['admin', 'local', 'config'].includes(dbInfo.name)) {
      continue;
    }
    await inspectDatabase('mongodb://127.0.0.1:27017/' + dbInfo.name);
  }
  await adminConn.close();
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
`;

    await ssh.execCommand(`cat > ${server.appDir}/check_all.js <<'EOF'\n${serverScript}\nEOF`);
    const result = await ssh.execCommand(`cd "${server.appDir}" && node check_all.js`);
    console.log(`${server.label} results:\n${result.stdout}`);
    await ssh.execCommand(`rm -f "${server.appDir}/check_all.js"`);
  } finally {
    ssh.dispose();
  }
}

async function main() {
  for (const server of ALL_SERVERS) {
    await processServer(server);
  }
}

main().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});
