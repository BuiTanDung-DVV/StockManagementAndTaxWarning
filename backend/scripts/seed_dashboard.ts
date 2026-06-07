import { AppDataSource } from '../src/config/db.config';

async function seedShop(shopId: number) {
    console.log(`Seeding data for Shop ID: ${shopId}`);
    
    // 1. Warehouse
    let wh = await AppDataSource.query(`SELECT id FROM warehouses WHERE shop_id = $1 LIMIT 1`, [shopId]);
    let whId;
    if (wh.length === 0) {
        const res = await AppDataSource.query(`INSERT INTO warehouses (shop_id, name, address, is_active) VALUES ($1, 'Kho Trung Tâm', '123 Đường Chính', true) RETURNING id`, [shopId]);
        whId = res[0].id;
    } else {
        whId = wh[0].id;
    }

    // 2. Categories
    const catNames = ['Vật tư phân bón', 'Thuốc bảo vệ thực vật', 'Gạch ốp lát', 'Thiết bị vệ sinh'];
    const catIds = [];
    for (const name of catNames) {
        let cat = await AppDataSource.query(`SELECT id FROM categories WHERE shop_id = $1 AND name = $2 LIMIT 1`, [shopId, name]);
        let cId;
        if (cat.length === 0) {
            const res = await AppDataSource.query(`INSERT INTO categories (shop_id, name, is_active) VALUES ($1, $2, true) RETURNING id`, [shopId, name]);
            cId = res[0].id;
        } else {
            cId = cat[0].id;
        }
        catIds.push(cId);
    }

    // 3. Products
    const prodNames = [
        { name: 'Phân bón NPK Phú Mỹ 16-16-8', cat: catIds[0], price: 550000, cost: 500000, stock: 150 },
        { name: 'Lân vi sinh Lâm Thao', cat: catIds[0], price: 200000, cost: 170000, stock: 300 },
        { name: 'Thuốc diệt cỏ cháy siêu tốc', cat: catIds[1], price: 120000, cost: 95000, stock: 45 },
        { name: 'Thuốc trừ sâu rầy', cat: catIds[1], price: 85000, cost: 60000, stock: 120 },
        { name: 'Gạch ốp lát 60x60 bóng kiếng', cat: catIds[2], price: 180000, cost: 150000, stock: 800 },
        { name: 'Gạch ốp tường 30x60', cat: catIds[2], price: 150000, cost: 120000, stock: 400 },
        { name: 'Bồn cầu khối cao cấp', cat: catIds[3], price: 2500000, cost: 1800000, stock: 15 }
    ];

    const prodIds = [];
    for (let i = 0; i < prodNames.length; i++) {
        const item = prodNames[i];
        let p = await AppDataSource.query(`SELECT id FROM products WHERE shop_id = $1 AND name = $2 LIMIT 1`, [shopId, item.name]);
        let pId;
        if (p.length === 0) {
            const res = await AppDataSource.query(`
                INSERT INTO products (shop_id, name, sku, category_id, selling_price, cost_price, is_active) 
                VALUES ($1, $2, $3, $4, $5, $6, true) RETURNING id
            `, [shopId, item.name, `SKU-${shopId}-${i + 1}`, item.cat, item.price, item.cost]);
            pId = res[0].id;
            
            await AppDataSource.query(`
                INSERT INTO inventory_stocks (shop_id, warehouse_id, product_id, quantity, updated_at)
                VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
            `, [shopId, whId, pId, item.stock]);
        } else {
            pId = p[0].id;
        }
        prodIds.push({ id: pId, price: item.price });
    }

    // 4. Sales Orders (Revenue)
    for (let i = 0; i < 20; i++) {
        const date = new Date();
        date.setDate(date.getDate() - Math.floor(Math.random() * 30)); // random within 30 days
        
        const resOrder = await AppDataSource.query(`
            INSERT INTO sales_orders (shop_id, order_code, status, total_amount, order_date, created_at, updated_at)
            VALUES ($1, $2, 'COMPLETED', 0, $3, $3, $3) RETURNING id
        `, [shopId, `SO${shopId}-${Date.now().toString().slice(-5)}${i}`, date]);
        const orderId = resOrder[0].id;

        let total = 0;
        const numItems = 2 + (i % 2);
        for (let j = 0; j < numItems; j++) {
            const p = prodIds[(i + j) % prodIds.length];
            const qty = 5 + Math.floor(Math.random() * 10);
            const lineTotal = qty * p.price;
            total += lineTotal;
            
            await AppDataSource.query(`
                INSERT INTO sales_order_items (order_id, shop_id, product_id, quantity, unit_price, subtotal)
                VALUES ($1, $2, $3, $4, $5, $6)
            `, [orderId, shopId, p.id, qty, p.price, lineTotal]);
        }
        
        await AppDataSource.query(`UPDATE sales_orders SET total_amount = $1, subtotal = $1 WHERE id = $2`, [total, orderId]);

        // Cash flow logic
        const ca = await AppDataSource.query(`SELECT id FROM cash_accounts WHERE shop_id = $1 LIMIT 1`, [shopId]);
        if (ca.length > 0) {
            await AppDataSource.query(`
                INSERT INTO cash_transactions (shop_id, account_id, type, amount, category, reference_type, reference_id, transaction_date)
                VALUES ($1, $2, 'IN', $3, 'Bán hàng', 'sales_order', $4, $5)
            `, [shopId, ca[0].id, total, orderId, date]);
        }
    }
    
    console.log(`Finished seeding Shop ID: ${shopId}`);
}

async function run() {
    await AppDataSource.initialize();
    try {
        await seedShop(22);
        await seedShop(23);
    } catch (e) {
        console.error(e);
    }
    await AppDataSource.destroy();
}

run();
