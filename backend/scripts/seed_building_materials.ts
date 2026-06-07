import { AppDataSource } from '../src/config/db.config';
import * as bcrypt from 'bcrypt';

async function seedData() {
    console.log('Initializing DB for Multi-Shop Seed...');
    await AppDataSource.initialize();

    const passHash = bcrypt.hashSync('123456', 10);

    // ==========================================
    // 1. Create Users
    // ==========================================
    const globalUsers = [
        { username: 'admin', email: 'admin@kientao.com', fullName: 'Nguyễn Văn Chủ', roleName: 'Admin', type: 'OWNER' },
        { username: 'manager', email: 'manager@kientao.com', fullName: 'Trần Quản Lý Chung', roleName: 'Manager', type: 'EMPLOYEE' }
    ];

    const shop1Users = [
        { username: 'sales1', email: 'sales@vlxd.com', fullName: 'Lê Bán Hàng VLXD', roleName: 'Sales', type: 'EMPLOYEE' },
        { username: 'warehouse1', email: 'warehouse@vlxd.com', fullName: 'Phạm Thủ Kho VLXD', roleName: 'Warehouse', type: 'EMPLOYEE' },
        { username: 'accountant1', email: 'accountant@vlxd.com', fullName: 'Hoàng Kế Toán VLXD', roleName: 'Accountant', type: 'EMPLOYEE' }
    ];

    const shop2Users = [
        { username: 'sales2', email: 'sales@nongnghiep.com', fullName: 'Đào Bán Hàng Phân Bón', roleName: 'Sales', type: 'EMPLOYEE' },
        { username: 'warehouse2', email: 'warehouse@nongnghiep.com', fullName: 'Lý Thủ Kho Phân Bón', roleName: 'Warehouse', type: 'EMPLOYEE' },
        { username: 'accountant2', email: 'accountant@nongnghiep.com', fullName: 'Ngô Kế Toán Phân Bón', roleName: 'Accountant', type: 'EMPLOYEE' }
    ];

    const allUsersData = [...globalUsers, ...shop1Users, ...shop2Users];
    const createdUsers: any = {};
    for (const u of allUsersData) {
        const uRes = await AppDataSource.query(`
            INSERT INTO users (username, password, full_name, phone, role, account_type, is_active, is_onboarded)
            VALUES ($1, $2, $3, $4, $5, 'SHOP', true, true) RETURNING id
        `, [u.email, passHash, u.fullName, '0900000000', u.type === 'OWNER' ? 'ADMIN' : 'STAFF']);
        createdUsers[u.username] = { id: uRes[0].id, type: u.type, roleName: u.roleName };
    }
    console.log('Created Users.');

    const seedShop = async (
        shopName: string, shopCode: string, sector: string,
        whName: string, 
        categories: string[], 
        baseProductsData: any[],
        numOrders: number, prefix: string,
        assignedUsers: string[]
    ) => {
        // Shop Profile
        const shopRes = await AppDataSource.query(`
            INSERT INTO shop_profiles (shop_name, shop_code, email, phone, business_sector)
            VALUES ($1, $2, $3, $4, $5) RETURNING id
        `, [shopName, shopCode, `contact@${shopCode.toLowerCase()}.com`, '0909123456', sector]);
        const shopId = shopRes[0].id;
        console.log(`Created Shop: ${shopName} (ID: ${shopId})`);

        // Roles
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

        // Shop Members
        for (const username of assignedUsers) {
            const u = createdUsers[username];
            await AppDataSource.query(`
                INSERT INTO shop_members (shop_id, user_id, role_id, member_type, status, is_active)
                VALUES ($1, $2, $3, $4, 'ACTIVE', true)
            `, [shopId, u.id, rolesMap[u.roleName], u.type]);
        }

        // Warehouse
        const whRes = await AppDataSource.query(`
            INSERT INTO warehouses (shop_id, name, is_active)
            VALUES ($1, $2, true) RETURNING id
        `, [shopId, whName]);
        const whId = whRes[0].id;

        // Categories
        const catMap: Record<string, number> = {};
        for (const c of categories) {
            const cRes = await AppDataSource.query(`
                INSERT INTO categories (shop_id, name, is_active)
                VALUES ($1, $2, true) RETURNING id
            `, [shopId, c]);
            catMap[c] = cRes[0].id;
        }

        // Products
        const productsData = [];
        for (const base of baseProductsData) {
            for (const variant of base.variants) {
                productsData.push({
                    name: `${base.name} - ${variant}`,
                    cat: base.cat,
                    price: base.basePrice + Math.floor(Math.random() * 5) * (base.basePrice * 0.05),
                    cost: base.baseCost + Math.floor(Math.random() * 5) * (base.baseCost * 0.05),
                    stock: 50 + Math.floor(Math.random() * 500)
                });
            }
        }

        const prodMap = [];
        for (let i = 0; i < productsData.length; i++) {
            const p = productsData[i];
            const barcode = `${prefix}${10000 + i}`;
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

        // Customers
        const custIds = [];
        for (let i = 1; i <= 20; i++) {
            const cRes = await AppDataSource.query(`
                INSERT INTO customers (shop_id, code, name, phone, customer_type, is_active)
                VALUES ($1, $2, $3, $4, 'RETAIL', true) RETURNING id
            `, [shopId, `KH-${prefix}-${i}`, `Khách hàng ${prefix} ${i}`, `0988${100000 + i}`]);
            custIds.push(cRes[0].id);
        }

        // Sales Orders
        const caRes = await AppDataSource.query(`
            INSERT INTO cash_accounts (shop_id, name, account_type, balance, is_active)
            VALUES ($1, 'Tiền mặt tại quầy', 'CASH', 0, true) RETURNING id
        `, [shopId]);
        const cashAccountId = caRes[0].id;

        let totalRevenue = 0;
        for (let i = 0; i < numOrders; i++) {
            const date = new Date();
            date.setDate(date.getDate() - Math.floor(Math.random() * 180));
            const custId = custIds[Math.floor(Math.random() * custIds.length)];
            
            const resOrder = await AppDataSource.query(`
                INSERT INTO sales_orders (shop_id, order_code, status, total_amount, order_date, customer_id, created_at, updated_at)
                VALUES ($1, $2, 'COMPLETED', 0, $3, $4, $3, $3) RETURNING id
            `, [shopId, `SO-${prefix}-${Date.now().toString().slice(-5)}${i}`, date, custId]);
            const orderId = resOrder[0].id;

            let total = 0;
            const numItems = 1 + Math.floor(Math.random() * 5);
            for (let j = 0; j < numItems; j++) {
                const p = prodMap[Math.floor(Math.random() * prodMap.length)];
                const qty = 1 + Math.floor(Math.random() * 50);
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
    };

    // ==========================================
    // Seed Shop 1: VLXD
    // ==========================================
    const vlxdCategories = ['Vật liệu thô', 'Gạch ốp lát', 'Thiết bị vệ sinh', 'Đồ điện nước'];
    const vlxdProducts = [
        { name: 'Xi măng', cat: 'Vật liệu thô', basePrice: 85000, baseCost: 75000, variants: ['Hà Tiên Đa Dụng (Bao 50kg)', 'Nghi Sơn (Bao 50kg)'] },
        { name: 'Thép cuộn', cat: 'Vật liệu thô', basePrice: 15000, baseCost: 13500, variants: ['Hòa Phát Phi 6', 'Hòa Phát Phi 8'] },
        { name: 'Cát xây dựng', cat: 'Vật liệu thô', basePrice: 350000, baseCost: 280000, variants: ['Cát san lấp (Khối)', 'Cát tô (Khối)'] },
        { name: 'Gạch lát nền', cat: 'Gạch ốp lát', basePrice: 180000, baseCost: 140000, variants: ['Viglacera 60x60 (Thùng)', 'Đồng Tâm 80x80 (Thùng)'] },
        { name: 'Bồn cầu 1 khối', cat: 'Thiết bị vệ sinh', basePrice: 3500000, baseCost: 2500000, variants: ['Inax AC-900VRN', 'Toto MS885DT8'] },
        { name: 'Ống nhựa PVC', cat: 'Đồ điện nước', basePrice: 45000, baseCost: 35000, variants: ['Bình Minh Phi 21 (Cây)', 'Bình Minh Phi 27 (Cây)'] }
    ];
    await seedShop('Cửa Hàng VLXD & Nội Thất Kiến Tạo', 'VL01', 'TRADE', 'Kho Tổng VLXD', vlxdCategories, vlxdProducts, 150, 'VL', ['admin', 'manager', 'sales1', 'warehouse1', 'accountant1']);

    // ==========================================
    // Seed Shop 2: Phân bón
    // ==========================================
    const nngCategories = ['Phân bón Vô cơ', 'Phân bón Hữu cơ', 'Thuốc bảo vệ thực vật', 'Dụng cụ nông nghiệp'];
    const nngProducts = [
        { name: 'Phân NPK', cat: 'Phân bón Vô cơ', basePrice: 800000, baseCost: 650000, variants: ['Phú Mỹ 16-16-8 (Bao 50kg)', 'Đầu Trâu 20-20-15 (Bao 50kg)', 'Cà Mau 15-15-15 (Bao 50kg)'] },
        { name: 'Phân Ure (Đạm)', cat: 'Phân bón Vô cơ', basePrice: 550000, baseCost: 450000, variants: ['Đạm Cà Mau (Bao 50kg)', 'Đạm Phú Mỹ (Bao 50kg)', 'Đạm Ninh Bình (Bao 50kg)'] },
        { name: 'Phân Lân', cat: 'Phân bón Vô cơ', basePrice: 200000, baseCost: 150000, variants: ['Lân Lâm Thao (Bao 50kg)', 'Lân Văn Điển (Bao 50kg)'] },
        { name: 'Phân Kali', cat: 'Phân bón Vô cơ', basePrice: 600000, baseCost: 500000, variants: ['Kali Miểng (Bao 50kg)', 'Kali Bột (Bao 50kg)'] },
        { name: 'Phân Hữu Cơ', cat: 'Phân bón Hữu cơ', basePrice: 150000, baseCost: 100000, variants: ['Phân Bò Ủ Hoai (Bao 20kg)', 'Phân Trùn Quế Sfarm (Bao 10kg)', 'Phân Gà Vi Sinh (Bao 25kg)'] },
        { name: 'Thuốc Trừ Sâu', cat: 'Thuốc bảo vệ thực vật', basePrice: 85000, baseCost: 60000, variants: ['Regent 800WG (Gói 1g)', 'Radiant 60SC (Chai 100ml)', 'Tasieu 5WG (Gói 10g)'] },
        { name: 'Thuốc Trừ Nấm', cat: 'Thuốc bảo vệ thực vật', basePrice: 120000, baseCost: 85000, variants: ['Antracol 70WP (Gói 100g)', 'Ridomil Gold 68WG (Gói 100g)', 'Anvil 5SC (Chai 1L)'] },
        { name: 'Dụng cụ Nông nghiệp', cat: 'Dụng cụ nông nghiệp', basePrice: 150000, baseCost: 100000, variants: ['Cuốc thép rèn', 'Xẻng cán gỗ', 'Bình xịt thuốc 20L Dudaco', 'Bạt phủ nông nghiệp (Cuộn)'] }
    ];
    await seedShop('Đại Lý Phân Bón & VTNN Kiến Tạo', 'NN01', 'TRADE', 'Kho Phân Bón', nngCategories, nngProducts, 100, 'NN', ['admin', 'manager', 'sales2', 'warehouse2', 'accountant2']);

    await AppDataSource.destroy();
    console.log('Seed completed successfully for both shops!');
}

seedData().catch(e => {
    console.error(e);
    process.exit(1);
});
