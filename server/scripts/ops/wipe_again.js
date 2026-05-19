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

async function wipe() {
  const adminConn = await mongoose.createConnection('mongodb://127.0.0.1:27017/admin').asPromise();
  const dbs = await adminConn.db.admin().listDatabases();

  for (const db of dbs.databases) {
    if (['admin', 'local', 'config'].includes(db.name)) {
      continue;
    }

    const conn = await mongoose.createConnection('mongodb://127.0.0.1:27017/' + db.name).asPromise();
    const User = conn.model('User', new mongoose.Schema({ displayId: String, userId: String }, { strict: false }));
    const SyncData = conn.model('SyncData', new mongoose.Schema({ userId: String }, { strict: false }));

    const targetUserIds = [];
    const user = await User.findOne({ displayId: '91537456' });
    if (user) {
      targetUserIds.push(user.userId);
      await User.deleteOne({ _id: user._id });
      console.log('Deleted 91537456 from ' + db.name);
    }

    const allUsers = await User.find({}, 'userId');
    const userIds = new Set(allUsers.map((item) => item.userId));
    const allSyncs = await SyncData.find({}, 'userId');
    for (const sync of allSyncs) {
      if (!userIds.has(sync.userId)) {
        targetUserIds.push(sync.userId);
      }
    }

    for (const userId of [...new Set(targetUserIds)]) {
      await conn.collection('planningsessions').deleteMany({ userId }).catch(() => {});
      await conn.collection('pregeneratedplans').deleteMany({ userId }).catch(() => {});
      await conn.collection('syncdatas').deleteMany({ userId }).catch(() => {});
      await conn.collection('telemetryevents').deleteMany({ userId }).catch(() => {});
      await conn.collection('usagerecords').deleteMany({ userId }).catch(() => {});
      await conn.collection('usagesummaries').deleteMany({ userId }).catch(() => {});
      console.log('Wiped data for userId ' + userId + ' in ' + db.name);
    }

    await conn.close();
  }

  await adminConn.close();
}

wipe().catch(() => process.exit(0));
`;

    await ssh.execCommand(`cat > ${server.appDir}/wipe.js <<'EOF'\n${serverScript}\nEOF`);
    const result = await ssh.execCommand(`cd "${server.appDir}" && node wipe.js`);
    console.log(`${server.label} wipe result:\n${result.stdout}`);
    await ssh.execCommand(`rm -f "${server.appDir}/wipe.js"`);
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
