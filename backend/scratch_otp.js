const { Client } = require('pg');
const client = new Client({ connectionString: 'postgresql://postgres.tmvbmanqegzzlzdrahqv:YOsthmbfkOmB6nwp@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true' });
client.connect().then(() => client.query("SELECT * FROM otps WHERE phone='0901234567' ORDER BY \"created_at\" DESC LIMIT 1"))
.then(res => { console.log(JSON.stringify(res.rows)); client.end(); })
.catch(err => { console.error(err); client.end(); });
