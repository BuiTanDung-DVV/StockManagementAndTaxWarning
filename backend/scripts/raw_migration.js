const { Client } = require('pg');
require('dotenv').config();

async function main() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    connectionTimeoutMillis: 15000,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('Connecting to database...');
    await client.connect();
    console.log('Connected!');

    const tables = ['cash_transactions'];

    for (const table of tables) {
      const query = `ALTER TABLE "${table}" ADD COLUMN IF NOT EXISTS "tags" text;`;
      console.log(`Executing: ${query}`);
      await client.query(query);
    }
    
    console.log('All tables altered successfully.');
  } catch (error) {
    console.error('Error:', error);
  } finally {
    await client.end();
    console.log('Database connection closed.');
  }
}

main();
