const { Client } = require('pg');
require('dotenv').config();

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  throw new Error('DATABASE_URL is required');
}

const client = new Client({
  connectionString,
});

async function getLatestOtp() {
  await client.connect();
  const res = await client.query("SELECT * FROM otps ORDER BY created_at DESC LIMIT 1");
  console.log(res.rows[0]);
  await client.end();
}
getLatestOtp().catch(console.error);
