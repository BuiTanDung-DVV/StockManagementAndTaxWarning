const { Client } = require('pg');
require('dotenv').config();

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL is required');
}

const client = new Client({ 
  connectionString: process.env.DATABASE_URL
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
