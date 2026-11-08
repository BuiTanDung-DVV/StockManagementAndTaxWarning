import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { InventoryService } from '../services/inventory.service';

interface SlowProductSpec {
  sku: string;
  name: string;
  unit: string;
  costPrice: number;
  sellingPrice: number;
  categoryId: number;
  minStock: number;
  warehouseId: number;
  currentStock: number;
  receivedDaysAgo: number;
  lastSoldDaysAgo?: number; // undefined if never sold
  soldQty?: number;
}

const SHOP_34_SPECS: SlowProductSpec[] = [
  {
    sku: 'VL-SLOW-01',
    name: 'Sơn chống thấm pha xi măng mẫu cũ 20kg',
    unit: 'Thùng',
    costPrice: 480000,
    sellingPrice: 650000,
    categoryId: 457,
    minStock: 5,
    warehouseId: 91,
    currentStock: 16,
    receivedDaysAgo: 65,
    lastSoldDaysAgo: 48,
    soldQty: 2,
  },
  {
    sku: 'VL-SLOW-02',
    name: 'Gạch men granite vân đá mờ 60x60 (tồn lô cũ)',
    unit: 'Hộp',
    costPrice: 195000,
    sellingPrice: 270000,
    categoryId: 454,
    minStock: 10,
    warehouseId: 91,
    currentStock: 35,
    receivedDaysAgo: 80,
    lastSoldDaysAgo: 56,
    soldQty: 5,
  },
  {
    sku: 'VL-SLOW-03',
    name: 'Keo dán gạch chống trượt chuyên dụng 25kg',
    unit: 'Bao',
    costPrice: 135000,
    sellingPrice: 185000,
    categoryId: 454,
    minStock: 5,
    warehouseId: 91,
    currentStock: 28,
    receivedDaysAgo: 50,
    // never sold
  },
  {
    sku: 'VL-SLOW-04',
    name: 'Ống luồn dây điện PVC chống cháy D20 (cây 2.92m)',
    unit: 'Cây',
    costPrice: 38000,
    sellingPrice: 55000,
    categoryId: 456,
    minStock: 20,
    warehouseId: 91,
    currentStock: 75,
    receivedDaysAgo: 70,
    lastSoldDaysAgo: 42,
    soldQty: 15,
  },
];

const SHOP_35_SPECS: SlowProductSpec[] = [
  {
    sku: 'NN-SLOW-01',
    name: 'Phân hữu cơ khoáng chuyên cây có múi 25kg',
    unit: 'Bao',
    costPrice: 260000,
    sellingPrice: 340000,
    categoryId: 461,
    minStock: 5,
    warehouseId: 92,
    currentStock: 22,
    receivedDaysAgo: 60,
    lastSoldDaysAgo: 45,
    soldQty: 3,
  },
  {
    sku: 'NN-SLOW-02',
    name: 'Thuốc trừ rầy rệp sinh học dạng nhũ dầu 500ml',
    unit: 'Chai',
    costPrice: 85000,
    sellingPrice: 120000,
    categoryId: 462,
    minStock: 10,
    warehouseId: 92,
    currentStock: 30,
    receivedDaysAgo: 45,
    // never sold
  },
  {
    sku: 'NN-SLOW-03',
    name: 'Hạt giống dưa lưới ruột cam F1 túi 100 hạt',
    unit: 'Gói',
    costPrice: 160000,
    sellingPrice: 215000,
    categoryId: 463,
    minStock: 5,
    warehouseId: 92,
    currentStock: 18,
    receivedDaysAgo: 75,
    lastSoldDaysAgo: 52,
    soldQty: 2,
  },
];

async function seedShopSlowMoving(shopId: number, specs: SlowProductSpec[]) {
  console.log(`\n--- Bắt đầu tạo dữ liệu hàng tồn chậm cho Shop ${shopId} ---`);
  const now = new Date();

  // Find a customer for sales orders
  const customers = await AppDataSource.query(
    `SELECT id, name FROM customers WHERE shop_id = $1 LIMIT 1`,
    [shopId]
  );
  const customerId = customers.length > 0 ? customers[0].id : null;

  for (const spec of specs) {
    // 1. Clean up existing if rerun
    const existing = await AppDataSource.query(
      `SELECT id FROM products WHERE shop_id = $1 AND sku = $2`,
      [shopId, spec.sku]
    );
    if (existing.length > 0) {
      const pid = existing[0].id;
      console.log(`Đã tồn tại sản phẩm ${spec.sku} (id: ${pid}), đang dọn dẹp để tạo mới...`);
      // Find orders to delete
      const existingOrders = await AppDataSource.query(
        `SELECT DISTINCT order_id FROM sales_order_items WHERE product_id = $1`,
        [pid]
      );
      await AppDataSource.query(`DELETE FROM sales_order_items WHERE product_id = $1`, [pid]);
      for (const row of existingOrders) {
        if (row.order_id) {
          await AppDataSource.query(`DELETE FROM sales_orders WHERE id = $1`, [row.order_id]);
        }
      }
      await AppDataSource.query(`DELETE FROM inventory_movements WHERE product_id = $1`, [pid]);
      await AppDataSource.query(`DELETE FROM inventory_lots WHERE product_id = $1`, [pid]);
      await AppDataSource.query(`DELETE FROM inventory_stocks WHERE product_id = $1`, [pid]);
      await AppDataSource.query(`DELETE FROM products WHERE id = $1`, [pid]);
    }

    const receivedDate = new Date(now.getTime() - spec.receivedDaysAgo * 86400000);
    const initialQty = spec.currentStock + (spec.soldQty || 0);

    // 2. Insert product
    const insertProd = await AppDataSource.query(
      `INSERT INTO products (
        sku, name, unit, cost_price, selling_price, category_id, min_stock, shop_id, is_active, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, $9, $9) RETURNING id`,
      [
        spec.sku,
        spec.name,
        spec.unit,
        spec.costPrice,
        spec.sellingPrice,
        spec.categoryId,
        spec.minStock,
        shopId,
        receivedDate,
      ]
    );
    const productId = insertProd[0].id;

    // 3. Insert stock
    await AppDataSource.query(
      `INSERT INTO inventory_stocks (product_id, warehouse_id, quantity, updated_at, shop_id)
       VALUES ($1, $2, $3, $4, $5)`,
      [productId, spec.warehouseId, spec.currentStock, receivedDate, shopId]
    );

    // 4. Insert inventory movement IN
    await AppDataSource.query(
      `INSERT INTO inventory_movements (
        product_id, warehouse_id, movement_type, quantity, reference_type, notes, created_at, shop_id
      ) VALUES ($1, $2, 'IN', $3, 'PURCHASE', 'Nhập kho lô hàng mẫu ban đầu', $4, $5)`,
      [productId, spec.warehouseId, initialQty, receivedDate, shopId]
    );

    // 5. Insert inventory lot
    await AppDataSource.query(
      `INSERT INTO inventory_lots (
        product_id, initial_qty, remaining_qty, cost_price, notes, created_at, lot_date, shop_id
      ) VALUES ($1, $2, $3, $4, 'Lô hàng tồn chậm luân chuyển', $5, $5, $6)`,
      [productId, initialQty, spec.currentStock, spec.costPrice, receivedDate, shopId]
    );

    // 6. Historic sale if applicable
    if (spec.lastSoldDaysAgo && spec.soldQty) {
      const soldDate = new Date(now.getTime() - spec.lastSoldDaysAgo * 86400000);
      const skuNum = spec.sku.replace(/[^0-9]/g, '');
      const orderCode = `SO-SL${skuNum}-${Date.now().toString().slice(-6)}`;
      const subtotal = spec.soldQty * spec.sellingPrice;
      const cogs = spec.soldQty * spec.costPrice;

      const insertOrder = await AppDataSource.query(
        `INSERT INTO sales_orders (
          order_code, order_date, status, subtotal, discount_amount, tax_amount, total_amount, total_cogs,
          paid_amount, payment_method, customer_id, shop_id, notes, return_status, created_at, updated_at
        ) VALUES ($1, $2, 'COMPLETED', $3, 0, 0, $3, $4, $3, 'CASH', $5, $6, 'Đơn bán lẻ lịch sử', 'NONE', $2, $2)
        RETURNING id`,
        [orderCode, soldDate, subtotal, cogs, customerId, shopId]
      );
      const orderId = insertOrder[0].id;

      await AppDataSource.query(
        `INSERT INTO sales_order_items (
          order_id, product_id, quantity, unit_price, cost_price, subtotal, tax_rate, tax_amount, shop_id
        ) VALUES ($1, $2, $3, $4, $5, $6, 0, 0, $7)`,
        [orderId, productId, spec.soldQty, spec.sellingPrice, spec.costPrice, subtotal, shopId]
      );

      // Movement OUT
      await AppDataSource.query(
        `INSERT INTO inventory_movements (
          product_id, warehouse_id, movement_type, quantity, reference_type, reference_id, notes, created_at, shop_id
        ) VALUES ($1, $2, 'OUT', $3, 'SALES_ORDER', $4, 'Xuất bán hàng', $5, $6)`,
        [productId, spec.warehouseId, spec.soldQty, orderId, soldDate, shopId]
      );
    }

    console.log(`✓ Đã tạo thành công sản phẩm ${spec.sku}: ${spec.name} (Tồn: ${spec.currentStock} ${spec.unit})`);
  }
}

async function main() {
  await AppDataSource.initialize();

  await seedShopSlowMoving(34, SHOP_34_SPECS);
  await seedShopSlowMoving(35, SHOP_35_SPECS);

  console.log('\n--- Kiểm tra lại qua InventoryService.getSlowMovingProducts ---');
  const inventoryService = new InventoryService();

  const slow34 = await inventoryService.getSlowMovingProducts(34, 30);
  console.log(`\n[Shop 34] Tìm thấy ${slow34.length} sản phẩm tồn chậm:`);
  for (const item of slow34) {
    console.log(` - [${item.sku}] ${item.name}: Tồn ${item.currentStock} ${item.unit}, Vốn: ${Number(item.stockValue).toLocaleString('vi-VN')} đ, Ngày chưa bán: ${item.daysSinceLastSale ?? 'Chưa từng bán'}`);
  }

  const slow35 = await inventoryService.getSlowMovingProducts(35, 30);
  console.log(`\n[Shop 35] Tìm thấy ${slow35.length} sản phẩm tồn chậm:`);
  for (const item of slow35) {
    console.log(` - [${item.sku}] ${item.name}: Tồn ${item.currentStock} ${item.unit}, Vốn: ${Number(item.stockValue).toLocaleString('vi-VN')} đ, Ngày chưa bán: ${item.daysSinceLastSale ?? 'Chưa từng bán'}`);
  }

  await AppDataSource.destroy();
}

main().catch(console.error);
