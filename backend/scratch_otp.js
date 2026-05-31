const { Client } = require('pg');
const client = new Client({ connectionString: 'REDACTED_DATABASE_URL' });
client.connect().then(() => client.query("SELECT * FROM otps WHERE phone='0901234567' ORDER BY \"created_at\" DESC LIMIT 1"))
.then(res => { console.log(JSON.stringify(res.rows)); client.end(); })
.catch(err => { console.error(err); client.end(); });
