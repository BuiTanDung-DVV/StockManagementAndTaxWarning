const { Client } = require('pg');
const client = new Client({ connectionString: 'postgresql://postgres.tmvbmanqegzzlzdrahqv:YOsthmbfkOmB6nwp@aws-1-ap-southeast-1.pooler.supabase.com:6543/postgres?pgbouncer=true' });

async function checkData() {
  await client.connect();
  try {
    const shops = await client.query("SELECT * FROM shop_profiles LIMIT 5");
    console.log("=== Recent Shops ===");
    console.table(shops.rows);

    const products = await client.query("SELECT shop_id, COUNT(*) as count FROM products GROUP BY shop_id");
    console.log("\n=== Products by Shop ===");
    console.table(products.rows);

    const customers = await client.query("SELECT shop_id, COUNT(*) as count FROM customers GROUP BY shop_id");
    console.log("\n=== Customers by Shop ===");
    console.table(customers.rows);

    const orders = await client.query("SELECT shop_id, COUNT(*) as count FROM sales_orders GROUP BY shop_id");
    console.log("\n=== Sales Orders by Shop ===");
    console.table(orders.rows);

    const inventory = await client.query("SELECT shop_id, COUNT(*) as count FROM inventory_movements GROUP BY shop_id");
    console.log("\n=== Inventory Tx by Shop ===");
    console.table(inventory.rows);

    const cash = await client.query("SELECT shop_id, COUNT(*) as count FROM cash_transactions GROUP BY shop_id");
    console.log("\n=== Cash Tx by Shop ===");
    console.table(cash.rows);

  } catch (err) {
    console.error(err);
  } finally {
    await client.end();
  }
}
checkData();
