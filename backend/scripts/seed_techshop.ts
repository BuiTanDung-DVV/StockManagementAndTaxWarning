import { AppDataSource } from '../src/config/db.config';
import * as bcrypt from 'bcrypt';

async function seedTechShop() {
    console.log('Initializing DB for TechShop Seed...');
    await AppDataSource.initialize();

    const shopName = 'TechShop - Điện máy & Công nghệ';
    
    // 1. Create Shop Profile
    const shopRes = await AppDataSource.query(`
        INSERT INTO shop_profiles (shop_name, shop_code, email, phone, business_sector)
        VALUES ($1, $2, $3, $4, $5) RETURNING id
    `, [shopName, 'TS01', 'contact@techshop.vn', '0901234567', 'TRADE']);
    const shopId = shopRes[0].id;
    console.log(`Created Shop ID: ${shopId}`);

    // 2. Create Roles with JSON Permissions
    const rolesData = [
        { name: 'Admin', isDefault: true, perms: { all: true } },
        { name: 'Manager', isDefault: false, perms: { dashboard: "view", pos: "full", products: "full", inventory: "full", customers: "full", finance: "view", employees: "view" } },
        { name: 'Sales', isDefault: false, perms: { pos: "full", products: "view", customers: "full" } },
        { name: 'Warehouse', isDefault: false, perms: { inventory: "full", products: "view" } },
        { name: 'Accountant', isDefault: false, perms: { finance: "full", invoices: "full", dashboard: "view" } }
    ];

    const rolesMap: Record<string, number> = {};
    for (const r of rolesData) {
        const res = await AppDataSource.query(`
            INSERT INTO shop_roles (shop_id, name, permissions, is_default)
            VALUES ($1, $2, $3, $4) RETURNING id
        `, [shopId, r.name, JSON.stringify(r.perms), r.isDefault]);
        rolesMap[r.name] = res[0].id;
    }
    console.log('Created Roles:', rolesMap);

    // 3. Create Users & Shop Members
    const usersData = [
        { username: 'admin', fullName: 'Nguyễn Văn Admin', roleName: 'Admin', type: 'OWNER' },
        { username: 'manager', fullName: 'Trần Quản Lý', roleName: 'Manager', type: 'EMPLOYEE' },
        { username: 'sales', fullName: 'Lê Bán Hàng', roleName: 'Sales', type: 'EMPLOYEE' },
        { username: 'warehouse', fullName: 'Phạm Thủ Kho', roleName: 'Warehouse', type: 'EMPLOYEE' },
        { username: 'accountant', fullName: 'Hoàng Kế Toán', roleName: 'Accountant', type: 'EMPLOYEE' }
    ];

    const passHash = bcrypt.hashSync('123456', 10);
    for (const u of usersData) {
        const uRes = await AppDataSource.query(`
            INSERT INTO users (username, password, full_name, role, account_type, is_active, is_onboarded)
            VALUES ($1, $2, $3, $4, 'SHOP', true, true) RETURNING id
        `, [u.username, passHash, u.fullName, u.type === 'OWNER' ? 'ADMIN' : 'STAFF']);
        
        await AppDataSource.query(`
            INSERT INTO shop_members (shop_id, user_id, role_id, member_type, status, is_active)
            VALUES ($1, $2, $3, $4, 'ACTIVE', true)
        `, [shopId, uRes[0].id, rolesMap[u.roleName], u.type]);
    }
    console.log('Created 5 Users with RBAC.');

    // 4. Create Warehouse
    const whRes = await AppDataSource.query(`
        INSERT INTO warehouses (shop_id, name, is_active)
        VALUES ($1, 'Kho Trung Tâm TechShop', true) RETURNING id
    `, [shopId]);
    const whId = whRes[0].id;

    // 5. Create Categories
    const cats = ['Điện thoại di động', 'Laptop & Macbook', 'Phụ kiện công nghệ', 'Đồng hồ thông minh'];
    const catMap: Record<string, number> = {};
    for (const c of cats) {
        const cRes = await AppDataSource.query(`
            INSERT INTO categories (shop_id, name, is_active)
            VALUES ($1, $2, true) RETURNING id
        `, [shopId, c]);
        catMap[c] = cRes[0].id;
    }

    // 6. Create Products & Inventory Stock
    const baseProductsData = [
        { name: 'iPhone 15 Pro Max', cat: 'Điện thoại di động', basePrice: 29990000, baseCost: 26000000, variants: ['256GB Titan Tự nhiên', '256GB Titan Đen', '512GB Titan Tự nhiên', '512GB Titan Trắng', '1TB Titan Xanh'] },
        { name: 'iPhone 15 Pro', cat: 'Điện thoại di động', basePrice: 24990000, baseCost: 22000000, variants: ['128GB Titan Đen', '256GB Titan Tự nhiên', '512GB Titan Trắng'] },
        { name: 'iPhone 14 Pro Max', cat: 'Điện thoại di động', basePrice: 23990000, baseCost: 20000000, variants: ['128GB Tím', '256GB Vàng', '512GB Bạc', '1TB Đen'] },
        { name: 'Samsung Galaxy S24 Ultra', cat: 'Điện thoại di động', basePrice: 31990000, baseCost: 27000000, variants: ['256GB Xám Titan', '512GB Vàng Titan', '1TB Đen Titan'] },
        { name: 'Samsung Galaxy Z Fold 5', cat: 'Điện thoại di động', basePrice: 35000000, baseCost: 30000000, variants: ['256GB Đen Phantom', '512GB Xanh Icy'] },
        { name: 'Samsung Galaxy Z Flip 5', cat: 'Điện thoại di động', basePrice: 21000000, baseCost: 18000000, variants: ['256GB Xanh Mint', '512GB Tím Lavender'] },
        { name: 'Macbook Pro M3 14 inch', cat: 'Laptop & Macbook', basePrice: 39990000, baseCost: 35000000, variants: ['16GB/512GB Bạc', '16GB/1TB Đen Không Gian'] },
        { name: 'Macbook Air M2 13 inch', cat: 'Laptop & Macbook', basePrice: 25000000, baseCost: 22000000, variants: ['8GB/256GB Midnight', '16GB/512GB Starlight'] },
        { name: 'Dell XPS 15 9530', cat: 'Laptop & Macbook', basePrice: 45000000, baseCost: 40000000, variants: ['i7/16GB/512GB/FHD+', 'i9/32GB/1TB/OLED'] },
        { name: 'AirPods Pro Gen 2', cat: 'Phụ kiện công nghệ', basePrice: 5500000, baseCost: 4500000, variants: ['MagSafe Type-C', 'MagSafe Lightning'] },
        { name: 'Apple Watch Series 9', cat: 'Đồng hồ thông minh', basePrice: 10500000, baseCost: 8500000, variants: ['Nhôm 41mm GPS', 'Nhôm 45mm GPS', 'Thép 45mm LTE'] },
        { name: 'Sạc dự phòng Anker', cat: 'Phụ kiện công nghệ', basePrice: 850000, baseCost: 500000, variants: ['10000mAh 20W', '20000mAh 30W'] },
        { name: 'Bàn phím cơ', cat: 'Phụ kiện công nghệ', basePrice: 2500000, baseCost: 1800000, variants: ['Logitech MX Mechanical', 'Keychron K2 Pro', 'Akko 3098B'] },
        { name: 'Chuột không dây', cat: 'Phụ kiện công nghệ', basePrice: 1500000, baseCost: 900000, variants: ['Logitech MX Master 3S', 'Logitech G Pro X Superlight', 'Razer DeathAdder V3'] },
        { name: 'Tai nghe Bluetooth', cat: 'Phụ kiện công nghệ', basePrice: 6500000, baseCost: 5000000, variants: ['Sony WH-1000XM5 Đen', 'Sony WH-1000XM5 Bạc', 'Sennheiser Momentum 4'] }
    ];

    const productsData = [];
    for (const base of baseProductsData) {
        for (const variant of base.variants) {
            productsData.push({
                name: `${base.name} - ${variant}`,
                cat: base.cat,
                price: base.basePrice + Math.floor(Math.random() * 5) * 500000,
                cost: base.baseCost + Math.floor(Math.random() * 5) * 400000,
                stock: 10 + Math.floor(Math.random() * 50)
            });
        }
    }
    
    // Fill up to 100+ items if needed
    for (let i = productsData.length; i < 110; i++) {
        productsData.push({
            name: `Phụ kiện ốp lưng / dán màn hình mã PK${i}`,
            cat: 'Phụ kiện công nghệ',
            price: 150000 + Math.floor(Math.random() * 10) * 10000,
            cost: 50000 + Math.floor(Math.random() * 5) * 10000,
            stock: 100 + Math.floor(Math.random() * 200)
        });
    }

    const prodMap = [];
    for (let i = 0; i < productsData.length; i++) {
        const p = productsData[i];
        const barcode = `TS${10000 + i}`;
        const pRes = await AppDataSource.query(`
            INSERT INTO products (shop_id, name, barcode, sku, category_id, selling_price, cost_price, is_active)
            VALUES ($1, $2, $3, $3, $4, $5, $6, true) RETURNING id
        `, [shopId, p.name, barcode, catMap[p.cat], p.price, p.cost]);
        const pId = pRes[0].id;
        prodMap.push({ id: pId, price: p.price, cost: p.cost });

        await AppDataSource.query(`
            INSERT INTO inventory_stocks (shop_id, warehouse_id, product_id, quantity, updated_at)
            VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
        `, [shopId, whId, pId, p.stock]);
    }
    console.log(`Created ${productsData.length} Products and Stocks.`);

    // 7. Create Customers
    const custIds = [];
    for (let i = 1; i <= 20; i++) {
        const cRes = await AppDataSource.query(`
            INSERT INTO customers (shop_id, code, name, phone, customer_type, is_active)
            VALUES ($1, $2, $3, $4, 'RETAIL', true) RETURNING id
        `, [shopId, `KH-TS-${i}`, `Khách hàng VIP ${i}`, `0988${100000 + i}`]);
        custIds.push(cRes[0].id);
    }

    // 8. Create Sales Orders & Cash Transactions
    const caRes = await AppDataSource.query(`
        INSERT INTO cash_accounts (shop_id, name, account_type, balance, is_active)
        VALUES ($1, 'Tiền mặt tại quầy', 'CASH', 0, true) RETURNING id
    `, [shopId]);
    const cashAccountId = caRes[0].id;

    let totalRevenue = 0;
    for (let i = 0; i < 200; i++) {
        const date = new Date();
        date.setDate(date.getDate() - Math.floor(Math.random() * 60)); // Random trong 60 ngày
        
        const custId = custIds[Math.floor(Math.random() * custIds.length)];
        
        const resOrder = await AppDataSource.query(`
            INSERT INTO sales_orders (shop_id, order_code, status, total_amount, order_date, customer_id, created_at, updated_at)
            VALUES ($1, $2, 'COMPLETED', 0, $3, $4, $3, $3) RETURNING id
        `, [shopId, `SO-TS-${Date.now().toString().slice(-5)}${i}`, date, custId]);
        const orderId = resOrder[0].id;

        let total = 0;
        const numItems = 1 + Math.floor(Math.random() * 4);
        for (let j = 0; j < numItems; j++) {
            const p = prodMap[Math.floor(Math.random() * prodMap.length)];
            const qty = 1 + Math.floor(Math.random() * 3);
            const lineTotal = qty * p.price;
            total += lineTotal;
            
            await AppDataSource.query(`
                INSERT INTO sales_order_items (order_id, shop_id, product_id, quantity, unit_price, subtotal)
                VALUES ($1, $2, $3, $4, $5, $6)
            `, [orderId, shopId, p.id, qty, p.price, lineTotal]);
        }
        
        await AppDataSource.query(`UPDATE sales_orders SET total_amount = $1, subtotal = $1 WHERE id = $2`, [total, orderId]);
        totalRevenue += total;

        await AppDataSource.query(`
            INSERT INTO cash_transactions (shop_id, transaction_code, account_id, type, category, amount, reference_type, reference_id, notes, transaction_date)
            VALUES ($1, $2, $3, 'IN', 'SALES', $4, 'SALES_ORDER', $5, $6, $7)
        `, [shopId, `CT-${Date.now().toString().slice(-6)}${i}`, cashAccountId, total, orderId, `Thu tiền đơn hàng ${orderId}`, date]);
    }
    
    await AppDataSource.query(`UPDATE cash_accounts SET balance = $1 WHERE id = $2`, [totalRevenue, cashAccountId]);
    console.log(`Created 200 Sales Orders. Total Revenue: ${totalRevenue}`);

    await AppDataSource.destroy();
    console.log('Seed completed successfully!');
}

seedTechShop().catch(e => console.error(e));
