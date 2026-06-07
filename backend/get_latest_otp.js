const { Client } = require('pg');

const connectionString = 'postgresql://postgres.tmvbmanqegzzlzdrahqv:YOsthmbfkOmB6nwp@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true';

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
