const { Client } = require('pg');

const client = new Client({ 
  connectionString: 'postgresql://postgres.tmvbmanqegzzlzdrahqv:YOsthmbfkOmB6nwp@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true' 
});

async function run() {
  await client.connect();
  try {
    const res = await client.query("SELECT phone, otp_code, expires_at, created_at FROM otps ORDER BY created_at DESC LIMIT 5");
    console.log("=== LATEST OTP CODES ===");
    res.rows.forEach(row => {
      console.log(`Phone: ${row.phone} | OTP: ${row.otp_code} | Expires: ${row.expires_at} | Created: ${row.created_at}`);
    });
  } catch(e) {
    console.error(e);
  } finally {
    await client.end();
  }
}
run();
