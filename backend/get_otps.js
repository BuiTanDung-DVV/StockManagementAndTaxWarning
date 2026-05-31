const { Client } = require('pg');

const client = new Client({ connectionString: 'postgresql://postgres.tmvbmanqegzzlzdrahqv:YOsthmbfkOmB6nwp@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true' });

async function run() {
  await client.connect();
  try {
    console.log("Sending OTP to 0901112222...");
    await fetch('https://stock-management-and-tax-warning.vercel.app/api/auth/send-otp', { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({ phone: '0901112222' }) });
    
    console.log("Sending OTP to 0903334444...");
    await fetch('https://stock-management-and-tax-warning.vercel.app/api/auth/send-otp', { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({ phone: '0903334444' }) });
    
    // Wait for DB to be populated
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const otp1 = await client.query("SELECT otp_code FROM otps WHERE phone='0901112222' ORDER BY created_at DESC LIMIT 1");
    const otp2 = await client.query("SELECT otp_code FROM otps WHERE phone='0903334444' ORDER BY created_at DESC LIMIT 1");
    
    console.log("OTP for POS (0901112222):", otp1.rows[0]?.otp_code);
    console.log("OTP for FIN (0903334444):", otp2.rows[0]?.otp_code);
    
  } catch(e) {
    console.error(e);
  } finally {
    await client.end();
  }
}
run();
