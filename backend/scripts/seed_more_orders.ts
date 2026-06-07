import { AppDataSource } from '../src/config/db.config';

async function seedMoreOrders() {
    console.log('Initializing DB...');
    await AppDataSource.initialize();

    const shops = await AppDataSource.query(`SELECT id, shop_code FROM shop_profiles WHERE shop_code IN ('VL01', 'NN01')`);
    
    for (const shop of shops) {
        console.log(`Seeding more orders for shop ${shop.shop_code}...`);
        const shopId = shop.id;
        
        // Find customers
        const customers = await AppDataSource.query(`SELECT id FROM customers WHERE shop_id = $1`, [shopId]);
        if (!customers.length) {
            console.log(`No customers found for shop ${shop.shop_code}, skipping.`);
            continue;
        }
        const custIds = customers.map((c: any) => c.id);

        // Find products
        const products = await AppDataSource.query(`SELECT id, selling_price as price FROM products WHERE shop_id = $1`, [shopId]);
        if (!products.length) {
            console.log(`No products found for shop ${shop.shop_code}, skipping.`);
            continue;
        }

        // Find cash account
        const cashAccounts = await AppDataSource.query(`SELECT id FROM cash_accounts WHERE shop_id = $1 LIMIT 1`, [shopId]);
        const cashAccountId = cashAccounts[0]?.id;

        let totalRevenue = 0;
        const numOrders = 200; // Add 200 more orders

        for (let i = 0; i < numOrders; i++) {
            const date = new Date();
            date.setDate(date.getDate() - Math.floor(Math.random() * 180));
            const custId = custIds[Math.floor(Math.random() * custIds.length)];
            
            const resOrder = await AppDataSource.query(`
                INSERT INTO sales_orders (shop_id, order_code, status, total_amount, order_date, customer_id, created_at, updated_at)
                VALUES ($1, $2, 'COMPLETED', 0, $3, $4, $3, $3) RETURNING id
            `, [shopId, `SO-ADD-${Date.now().toString().slice(-5)}${i}`, date, custId]);
            const orderId = resOrder[0].id;

            let total = 0;
            const numItems = 1 + Math.floor(Math.random() * 5);
            for (let j = 0; j < numItems; j++) {
                const p = products[Math.floor(Math.random() * products.length)];
                const qty = 1 + Math.floor(Math.random() * 50);
                const lineTotal = qty * Number(p.price);
                total += lineTotal;
                
                await AppDataSource.query(`
                    INSERT INTO sales_order_items (order_id, shop_id, product_id, quantity, unit_price, subtotal)
                    VALUES ($1, $2, $3, $4, $5, $6)
                `, [orderId, shopId, p.id, qty, p.price, lineTotal]);
            }
            
            await AppDataSource.query(`UPDATE sales_orders SET total_amount = $1, subtotal = $1 WHERE id = $2`, [total, orderId]);
            totalRevenue += total;

            if (cashAccountId) {
                await AppDataSource.query(`
                    INSERT INTO cash_transactions (shop_id, transaction_code, account_id, type, category, amount, reference_type, reference_id, notes, transaction_date)
                    VALUES ($1, $2, $3, 'IN', 'SALES', $4, 'SALES_ORDER', $5, $6, $7)
                `, [shopId, `CT-ADD-${Date.now().toString().slice(-5)}${i}`, cashAccountId, total, orderId, `Thu tiền đơn hàng bổ sung ${orderId}`, date]);
            }
        }
        
        if (cashAccountId) {
            await AppDataSource.query(`UPDATE cash_accounts SET balance = balance + $1 WHERE id = $2`, [totalRevenue, cashAccountId]);
        }
        console.log(`Added ${numOrders} orders and updated revenue.`);
    }

    await AppDataSource.destroy();
    console.log('Seeded more orders successfully!');
}

seedMoreOrders().catch(console.error);
