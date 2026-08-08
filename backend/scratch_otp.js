const { Client } = require('pg');
require('dotenv').config();

if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL is required');
}

const client = new Client({ connectionString: process.env.DATABASE_URL });
client.connect().then(() => client.query("SELECT * FROM otps WHERE phone='0901234567' ORDER BY \"created_at\" DESC LIMIT 1"))
.then(res => { console.log(JSON.stringify(res.rows)); client.end(); })
.catch(err => { console.error(err); client.end(); });
