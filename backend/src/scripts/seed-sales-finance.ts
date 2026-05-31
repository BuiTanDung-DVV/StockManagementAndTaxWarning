import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { ShopProfile } from '../system/entities';
import { User } from '../auth/entities';
import { Product } from '../product/entities';
import { Customer } from '../customer/entities';
import { Warehouse, InventoryStock } from '../inventory/entities';
import { SalesOrder, SalesOrderItem } from '../sales/entities';
import { JournalEntry, JournalLine } from '../finance/ledger.entity';
import { CashflowForecast } from '../finance/entities';

async function seedSalesFinance() {
  await AppDataSource.initialize();
  console.log('✅ Connected to DB for Sales and Finance seeding...');

  const shopRepo = AppDataSource.getRepository(ShopProfile);
  const userRepo = AppDataSource.getRepository(User);
  const prodRepo = AppDataSource.getRepository(Product);
  const custRepo = AppDataSource.getRepository(Customer);
  const warehouseRepo = AppDataSource.getRepository(Warehouse);
  const stockRepo = AppDataSource.getRepository(InventoryStock);
  const salesRepo = AppDataSource.getRepository(SalesOrder);
  const journalRepo = AppDataSource.getRepository(JournalEntry);
  const forecastRepo = AppDataSource.getRepository(CashflowForecast);

  // 1. Resolve Shop and Owner
  const shop = await shopRepo.findOne({ where: { shopName: 'Đại lý VTNN & VLXD Bình Minh' } });
  if (!shop) {
    throw new Error('Shop not found. Please run seed-fertilizer.ts first.');
  }
  console.log(`➜ Found Shop: ${shop.shopName} (ID: ${shop.id})`);

  const owner = await userRepo.findOne({ where: { username: 'chushop_binhminh' } });
  const products = await prodRepo.find({ where: { shopId: shop.id } });
  const customers = await custRepo.find({ where: { shopId: shop.id } });

  if (!products.length || !customers.length) {
    throw new Error('Products or Customers not found. Please run seed-fertilizer.ts first.');
  }

  // 2. Ensure Warehouse exists
  let warehouse = await warehouseRepo.findOne({ where: { shopId: shop.id } });
  if (!warehouse) {
    warehouse = warehouseRepo.create({
      name: 'Kho chính Bình Minh',
      shopId: shop.id,
      address: shop.address || 'Hải Dương',
      isActive: true
    });
    warehouse = await warehouseRepo.save(warehouse);
    console.log(`➜ Created Warehouse: ${warehouse.name}`);
  } else {
    console.log(`➜ Warehouse already exists: ${warehouse.name} (ID: ${warehouse.id})`);
  }

  // 3. Ensure Product Stocks exist with generous quantity
  console.log('➜ Populating product stocks...');
  for (const prod of products) {
    let stock = await stockRepo.findOne({ where: { shopId: shop.id, productId: prod.id, warehouseId: warehouse.id } });
    if (!stock) {
      stock = stockRepo.create({
        shopId: shop.id,
        productId: prod.id,
        warehouseId: warehouse.id,
        quantity: 5000,
        updatedAt: new Date()
      });
      await stockRepo.save(stock);
    } else {
      stock.quantity = 5000;
      await stockRepo.save(stock);
    }
  }
  console.log(`➜ Stock seeded for ${products.length} products.`);

  // 4. Seed Sales Orders and Journal Entries (double entry ledger)
  console.log('➜ Seeding 100+ Sales Orders...');
  
  // Clean existing sales orders and journal entries for this shop to avoid duplication
  const existingOrders = await salesRepo.find({ where: { shopId: shop.id } });
  if (existingOrders.length > 0) {
    console.log(`➜ Cleaning ${existingOrders.length} existing Sales Orders...`);
    await salesRepo.remove(existingOrders);
  }
  
  const existingJournals = await journalRepo.find({ where: { shopId: shop.id } });
  if (existingJournals.length > 0) {
    console.log(`➜ Cleaning ${existingJournals.length} existing Journal Entries...`);
    await journalRepo.remove(existingJournals);
  }

  const salesOrdersToSave: SalesOrder[] = [];
  const journalEntriesToSave: JournalEntry[] = [];

  const randomDate = (daysAgo: number) => {
    const d = new Date();
    d.setDate(d.getDate() - daysAgo);
    return d;
  };

  const getRandom = (arr: any[]) => arr[Math.floor(Math.random() * arr.length)];

  // Generate 120 sales orders distributed over the last 30 days
  for (let i = 1; i <= 120; i++) {
    const cust = getRandom(customers);
    const date = randomDate(Math.floor(Math.random() * 30));
    
    // Choose 1 to 4 random products
    const orderItems: SalesOrderItem[] = [];
    let subtotal = 0;
    let totalCogs = 0;
    const numItems = Math.floor(Math.random() * 3) + 1;
    
    // Track chosen products to avoid duplicates in the same order
    const chosenProductIds = new Set<number>();
    
    for (let j = 0; j < numItems; j++) {
      let prod = getRandom(products);
      while (chosenProductIds.has(prod.id)) {
        prod = getRandom(products);
      }
      chosenProductIds.add(prod.id);
      
      const qty = Math.floor(Math.random() * 8) + 1;
      const unitPrice = Number(prod.sellingPrice);
      const itemSubtotal = qty * unitPrice;
      const costPrice = Number(prod.costPrice);
      const itemCogs = qty * costPrice;
      
      subtotal += itemSubtotal;
      totalCogs += itemCogs;

      orderItems.push({
        shopId: shop.id,
        product: prod,
        quantity: qty,
        unitPrice,
        subtotal: itemSubtotal,
        costPrice,
        taxRate: 8,
        taxAmount: itemSubtotal * 0.08,
      } as SalesOrderItem);
    }

    const discountAmount = Math.random() > 0.8 ? Math.floor(Math.random() * 5) * 10000 : 0;
    const taxAmount = subtotal * 0.08;
    const totalAmount = subtotal - discountAmount + taxAmount;
    const paidAmount = Math.random() > 0.15 ? totalAmount : 0; // 85% paid, 15% unpaid

    // Create Sales Order Entity
    const orderCode = `DH-${date.getFullYear().toString().slice(-2)}${(date.getMonth() + 1).toString().padStart(2, '0')}${date.getDate().toString().padStart(2, '0')}-${i.toString().padStart(3, '0')}`;
    const order = salesRepo.create({
      orderCode,
      shopId: shop.id,
      customer: cust,
      orderDate: date,
      status: 'DELIVERED',
      subtotal,
      discountAmount,
      taxAmount,
      totalAmount,
      totalCogs,
      paidAmount,
      paymentMethod: Math.random() > 0.5 ? 'CASH' : 'TRANSFER',
      notes: `Đơn hàng bán lẻ #${i}`,
      createdBy: owner?.id || 1,
      items: orderItems,
      createdAt: date,
      updatedAt: date
    });

    salesOrdersToSave.push(order);
  }

  // Save sales orders (with items cascaded)
  const savedOrders = await salesRepo.save(salesOrdersToSave);
  console.log(`➜ Successfully saved ${savedOrders.length} Sales Orders and Items.`);

  // Create corresponding double-entry journal entries for P&L calculations
  console.log('➜ Creating ledger postings for sales orders...');
  for (const order of savedOrders) {
    const journalLines: JournalLine[] = [];
    const totalAmount = Number(order.totalAmount);
    const subtotal = Number(order.subtotal);
    const totalCogs = Number(order.totalCogs);

    // Revenue: CREDIT Account 511 (Doanh thu)
    const lineRev = new JournalLine();
    lineRev.accountCode = '511';
    lineRev.amount = subtotal;
    lineRev.entryType = 'CREDIT';
    journalLines.push(lineRev);

    // Cash/Receivables: DEBIT Account 111 (Tiền mặt) or 131 (Phải thu khách hàng)
    const lineCash = new JournalLine();
    lineCash.accountCode = order.paidAmount > 0 ? '111' : '131';
    lineCash.amount = totalAmount;
    lineCash.entryType = 'DEBIT';
    journalLines.push(lineCash);

    // COGS: DEBIT Account 632 (Giá vốn)
    const lineCogs = new JournalLine();
    lineCogs.accountCode = '632';
    lineCogs.amount = totalCogs;
    lineCogs.entryType = 'DEBIT';
    journalLines.push(lineCogs);

    // Inventory reduction: CREDIT Account 156 (Hàng hóa)
    const lineInv = new JournalLine();
    lineInv.accountCode = '156';
    lineInv.amount = totalCogs;
    lineInv.entryType = 'CREDIT';
    journalLines.push(lineInv);

    const entry = journalRepo.create({
      shopId: shop.id,
      entryDate: order.orderDate,
      referenceType: 'SALES_ORDER',
      referenceId: order.id,
      description: `Bán hàng - Đơn ${order.orderCode}`,
      isVoided: false,
      lines: journalLines,
      createdAt: order.orderDate
    });

    journalEntriesToSave.push(entry);
  }

  await journalRepo.save(journalEntriesToSave);
  console.log(`➜ Saved ${journalEntriesToSave.length} Journal Entries and postings.`);

  // 5. Seed Cashflow Forecasts for the next 30 days
  console.log('➜ Seeding Cashflow Forecast points...');
  const existingForecasts = await forecastRepo.find({ where: { shopId: shop.id } });
  if (existingForecasts.length > 0) {
    await forecastRepo.remove(existingForecasts);
  }

  const forecastsToSave = [];
  let currentBalance = 45000000; // Starting base cash balance: 45M VND

  for (let i = 1; i <= 15; i++) {
    const fDate = new Date();
    fDate.setDate(fDate.getDate() + (i * 2)); // Every 2 days
    
    const expectedIncome = Math.floor(Math.random() * 8 + 3) * 1000000;  // 3M to 10M VND
    const expectedExpense = Math.floor(Math.random() * 5 + 1) * 1000000; // 1M to 5M VND
    currentBalance += (expectedIncome - expectedExpense);

    const forecast = forecastRepo.create({
      shopId: shop.id,
      forecastDate: fDate,
      expectedIncome,
      expectedExpense,
      expectedBalance: currentBalance,
      notes: `Dự toán chu kỳ kinh doanh ngày ${fDate.getDate()}/${fDate.getMonth() + 1}`
    });
    
    forecastsToSave.push(forecast);
  }

  await forecastRepo.save(forecastsToSave);
  console.log(`➜ Seeded ${forecastsToSave.length} Cashflow Forecast points.`);

  console.log('\n🎉 ALL SALES AND FINANCE DATA SEEDED SUCCESSFULLY!');
  await AppDataSource.destroy();
}

seedSalesFinance().catch(err => {
  console.error('❌ Seeding error:', err);
  process.exit(1);
});
