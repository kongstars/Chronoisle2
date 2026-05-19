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

async function cleanDatabase(dbUri) {
  try {
    const conn = await mongoose.createConnection(dbUri).asPromise();
    const User = conn.model('User', new mongoose.Schema({ userId: String, displayId: String }, { strict: false }));
    const SyncData = conn.model('SyncData', new mongoose.Schema({ userId: String }, { strict: false }));

    const users = await User.find({}, 'userId displayId');
    const syncs = await SyncData.find({}, 'userId');
    const knownUserIds = new Set(users.map((user) => user.userId));
    const orphanIds = [];

    syncs.forEach((sync) => {
      if (!knownUserIds.has(sync.userId)) {
        orphanIds.push(sync.userId);
      }
    });

    if (orphanIds.length === 0) {
      await conn.close();
      return;
    }

    console.log('orphan userIds on ' + dbUri + ': ' + orphanIds.join(','));
    for (const userId of orphanIds) {
      await conn.collection('planningsessions').deleteMany({ userId }).catch(() => {});
      await conn.collection('pregeneratedplans').deleteMany({ userId }).catch(() => {});
      await conn.collection('syncdatas').deleteMany({ userId }).catch(() => {});
      await conn.collection('telemetryevents').deleteMany({ userId }).catch(() => {});
      await conn.collection('usagerecords').deleteMany({ userId }).catch(() => {});
      await conn.collection('usagesummaries').deleteMany({ userId }).catch(() => {});
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
    await cleanDatabase('mongodb://127.0.0.1:27017/' + dbInfo.name);
  }
  await adminConn.close();
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
`;

    await ssh.execCommand(`cat > ${server.appDir}/clean_all.js <<'EOF'\n${serverScript}\nEOF`);
    const result = await ssh.execCommand(`cd "${server.appDir}" && node clean_all.js`);
    console.log(`${server.label} results:\n${result.stdout}`);
    if (result.stderr) {
      console.error(`${server.label} errors:\n${result.stderr}`);
    }
    await ssh.execCommand(`rm -f "${server.appDir}/clean_all.js"`);
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
