import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { User } from '../auth/entities';
import { ShopProfile } from '../system/entities';
import { SalesService } from '../services/sales.service';
import { FinanceService } from '../services/finance.service';
import { Product } from '../product/entities';
import { Customer } from '../customer/entities';
import { SalesOrder } from '../sales/entities';

async function seed() {
  await AppDataSource.initialize();
  console.log('✅ DB connected — generating sales and finance mock data...');

  const userRepo = AppDataSource.getRepository(User);
  const shopRepo = AppDataSource.getRepository(ShopProfile);
  const prodRepo = AppDataSource.getRepository(Product);
  const custRepo = AppDataSource.getRepository(Customer);
  
  const salesService = new SalesService();
  const financeService = new FinanceService();

  const owner = await userRepo.findOne({ where: { username: 'chushop_binhminh' } });
  if (!owner) {
    console.error('Owner chushop_binhminh not found. Run seed-fertilizer.ts first.');
    process.exit(1);
  }

  const shop = await shopRepo.findOne({ where: { shopName: 'Đại lý VTNN & VLXD Bình Minh' } });
  if (!shop) {
    console.error('Shop not found. Run seed-fertilizer.ts first.');
    process.exit(1);
  }

  const products = await prodRepo.find({ where: { shopId: shop.id } });
  const customers = await custRepo.find({ where: { shopId: shop.id } });

  if (products.length === 0 || customers.length === 0) {
    console.error('No products or customers found. Run seed-fertilizer.ts first.');
    process.exit(1);
  }

  console.log(`Found ${products.length} products and ${customers.length} customers. Generating data for last 60 days...`);

  let salesCount = 0;
  let txCount = 0;

  // Generate 50 sales orders over the last 60 days
  for (let i = 0; i < 50; i++) {
    // Random date within last 60 days
    const orderDate = new Date();
    orderDate.setDate(orderDate.getDate() - Math.floor(Math.random() * 60));
    orderDate.setHours(Math.floor(Math.random() * 10) + 8); // 8 AM to 5 PM

    // Select 1 to 5 random products
    const itemCount = Math.floor(Math.random() * 5) + 1;
    const items = [];
    let subtotal = 0;

    for (let j = 0; j < itemCount; j++) {
      const p = products[Math.floor(Math.random() * products.length)];
      const qty = Math.floor(Math.random() * 10) + 1;
      const price = Number(p.sellingPrice);
      items.push({
        productId: p.id,
        quantity: qty,
        unitPrice: price,
        taxRate: 0,
        taxAmount: 0
      });
      subtotal += qty * price;
    }

    const customer = customers[Math.floor(Math.random() * customers.length)];
    
    // Mix of payment methods
    const r = Math.random();
    const method = r < 0.6 ? 'CASH' : (r < 0.9 ? 'TRANSFER' : 'QR');

    const status = Math.random() < 0.9 ? 'COMPLETED' : 'CANCELLED';

    const orderDto = {
      orderDate: orderDate.toISOString(),
      customerId: customer.id,
      items,
      discountAmount: 0,
      taxAmount: 0,
      paidAmount: subtotal, // fully paid
      paymentMethod: method,
      status: status,
      notes: `Đơn hàng tự động sinh #${i+1}`
    };

    try {
        const order = await salesService.create(shop.id, orderDto);
        if (status === 'CANCELLED') {
            await salesService.cancel(shop.id, order.id);
        }
        salesCount++;
    } catch (e: any) {
        // Ignore stock shortage errors during seeding
        if (!e.message.includes('Insufficient stock')) {
            console.error('Error creating order:', e.message);
        }
    }
  }

  console.log(`✅ Generated ${salesCount} sales orders (and related income transactions).`);

  // Generate some expenses
  const expenseCategories = ['Lương', 'Điện nước', 'Vận chuyển', 'Khác'];
  
  // Fake manager context
  const manager = AppDataSource.manager;

  for (let i = 0; i < 30; i++) {
    const txDate = new Date();
    txDate.setDate(txDate.getDate() - Math.floor(Math.random() * 60));
    txDate.setHours(Math.floor(Math.random() * 10) + 8);

    const category = expenseCategories[Math.floor(Math.random() * expenseCategories.length)];
    // Random amount 500k to 10M
    const amount = Math.floor(Math.random() * 20) * 500000 + 500000;

    await financeService.createCashTransaction(shop.id, {
        amount,
        type: 'EXPENSE',
        category: category,
        paymentMethod: Math.random() > 0.5 ? 'CASH' : 'TRANSFER',
        description: `Chi phí ${category} - mục ${i+1}`,
        transactionDate: txDate,
        status: 'COMPLETED'
    } as any, manager);
    txCount++;
  }

  console.log(`✅ Generated ${txCount} expense transactions.`);

  console.log('\n🎉 Sales & Finance Mock Data Seed completed successfully!');
  await AppDataSource.destroy();
}

seed().catch((err) => { 
  console.error('❌ Seed error:', err); 
  process.exit(1); 
});
