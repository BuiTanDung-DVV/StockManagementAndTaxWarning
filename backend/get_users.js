const { Client } = require('pg');

const client = new Client({ 
  connectionString: 'REDACTED_DATABASE_URL' 
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
