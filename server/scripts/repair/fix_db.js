
const mongoose = require('mongoose');

async function fix() {
  const envPathProd = __dirname + '/../../.env.production';
  const envPathDev = __dirname + '/../../.env.development';
  const fs = require('fs');
  if (fs.existsSync(envPathProd)) {
    require('dotenv').config({ path: envPathProd, override: true });
  } else if (fs.existsSync(envPathDev)) {
    require('dotenv').config({ path: envPathDev, override: true });
  } else {
    require('dotenv').config({ override: true });
  }
  
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('Connected to DB');

  const db = mongoose.connection.db;
  
  // Fix undefined totalEarned and totalSpent
  const result = await db.collection('creditaccounts').updateMany(
    { $or: [ { totalSpent: { $exists: false } }, { totalEarned: { $exists: false } } ] },
    { $set: { totalSpent: 0, totalEarned: 0 } }
  );
  
  // Also fix any NaN values just in case
  const result2 = await db.collection('creditaccounts').updateMany(
    { $or: [ { totalSpent: NaN }, { totalEarned: NaN } ] },
    { $set: { totalSpent: 0, totalEarned: 0 } }
  );
  
  console.log('Fixed undefined:', result.modifiedCount);
  console.log('Fixed NaN:', result2.modifiedCount);
  process.exit(0);
}
fix().catch(console.error);
