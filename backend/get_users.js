const { Client } = require('pg');

const client = new Client({ 
  connectionString: 'postgresql://postgres.tmvbmanqegzzlzdrahqv:YOsthmbfkOmB6nwp@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true' 
});

async function run() {
  await client.connect();
  try {
    const res = await client.query("SELECT id, username, phone, email, full_name, is_onboarded, is_active, role, account_type FROM users LIMIT 15");
    console.log("=== USERS IN DATABASE ===");
    console.table(res.rows);
  } catch(e) {
    console.error(e);
  } finally {
    await client.end();
  }
}
run();
