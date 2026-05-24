const { Client } = require('pg');

async function migrate() {
    const client = new Client({
        connectionString: 'postgresql://postgres.tmvbmanqegzzlzdrahqv:YOsthmbfkOmB6nwp@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true'
    });
    try {
        await client.connect();
        console.log("Connected to Supabase DB");

        await client.query(`
            ALTER TABLE purchase_without_invoice_items 
            ADD COLUMN IF NOT EXISTS product_name varchar(200);
        `);
        console.log("Added product_name");

        await client.query(`
            ALTER TABLE purchase_without_invoice_items 
            ADD COLUMN IF NOT EXISTS product_id integer;
        `);
        console.log("Added product_id");
        
        await client.query(`
            ALTER TABLE purchases_without_invoice 
            ADD COLUMN IF NOT EXISTS approval_status varchar(20) DEFAULT 'PENDING';
        `);
        console.log("Added approval_status");

        console.log("Migration successful");
    } catch (e) {
        console.error("Migration error:", e);
    } finally {
        await client.end();
    }
}

migrate();
