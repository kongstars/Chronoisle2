const mongoose = require('mongoose');
const User = require('../../models/User');
const CreditAccount = require('../../models/CreditAccount');
const CreditTransaction = require('../../models/CreditTransaction');

async function grant() {
  const fs = require('fs');
  const envPathProd = __dirname + '/../../.env.production';
  const envPathDev = __dirname + '/../../.env.development';

  if (fs.existsSync(envPathProd)) {
    require('dotenv').config({ path: envPathProd, override: true });
  } else if (fs.existsSync(envPathDev)) {
    require('dotenv').config({ path: envPathDev, override: true });
  } else {
    require('dotenv').config({ override: true });
  }

  if (!process.env.MONGODB_URI) {
    console.error('No MONGODB_URI found.');
    process.exit(1);
  }

  await mongoose.connect(process.env.MONGODB_URI);
  console.log('Connected to DB:', process.env.MONGODB_URI.split('@')[1] || 'local');

  const now = Date.now();
  const vips = await User.find({
    membershipType: 'premium',
    membershipExpireAt: { $gt: now }
  });
  console.log(`Found ${vips.length} active premium users.`);

  let successCount = 0;
  for (const user of vips) {
    let account = await CreditAccount.findOne({ userId: user.userId });
    if (!account) {
      account = new CreditAccount({
        userId: user.userId,
        balance: 0,
        totalIssued: 0,
        totalConsumed: 0
      });
    }

    account.balance += 100;
    account.totalIssued += 100;
    await account.save();

    const tx = new CreditTransaction({
      userId: user.userId,
      amount: 100,
      balanceAfter: account.balance,
      type: 'earn',
      source: 'admin_grant',
      description: '系统批量赠送会员积分'
    });
    await tx.save();
    successCount++;
  }

  console.log(`Done. Successfully granted 100 credits to ${successCount} users.`);
  process.exit(0);
}

grant().catch((err) => {
  console.error('Error granting credits:', err);
  process.exit(1);
});
