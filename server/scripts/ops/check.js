const { NodeSSH } = require('node-ssh');
const { TEST_SERVER } = require('../shared/serverTargets');

async function run() {
  const ssh = new NodeSSH();

  try {
    await ssh.connect({
      host: TEST_SERVER.host,
      username: 'root',
      password: TEST_SERVER.password,
      readyTimeout: 30000
    });

    const command = [
      `mongosh --quiet "mongodb://127.0.0.1:27017/${TEST_SERVER.mongoDb}" --eval "printjson({ users: db.users.countDocuments({}), syncdatas: db.syncdatas.countDocuments({}) })"`,
      `mongo --quiet "${TEST_SERVER.mongoDb}" --eval "printjson({ users: db.users.countDocuments({}), syncdatas: db.syncdatas.countDocuments({}) })"`
    ].join(' 2>/dev/null || ');

    const result = await ssh.execCommand(command);
    console.log(result.stdout.trim());
    if (result.stderr) {
      console.log(result.stderr.trim());
    }
  } finally {
    ssh.dispose();
  }
}

run().catch((error) => {
  console.error(error && error.stack ? error.stack : String(error));
  process.exit(1);
});
