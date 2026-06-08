import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { User } from '../auth/entities';
import { ShopProfile } from '../system/entities';
import { SalesService } from '../services/sales.service';
import { FinanceService } from '../services/finance.service';
import { Product } from '../product/entities';
import { Customer } from '../customer/entities';

async function seed() {
  await AppDataSource.initialize();
  console.log('✅ DB connected — generating 6 months of even sales and finance mock data...');

  const userRepo = AppDataSource.getRepository(User);
  const shopRepo = AppDataSource.getRepository(ShopProfile);
  const prodRepo = AppDataSource.getRepository(Product);
  const custRepo = AppDataSource.getRepository(Customer);
  
  const salesService = new SalesService();
  const financeService = new FinanceService();

  const { ShopMember } = require('../shop/entities');
  const memberRepo = AppDataSource.getRepository(ShopMember);
  const ownerMember: any = await memberRepo.findOne({ where: { memberType: 'OWNER' } });

  if (!ownerMember) {
    console.error('No owner found in database.');
    process.exit(1);
  }

  const owner = await userRepo.findOne({ where: { id: ownerMember.userId } });
  const shop = await shopRepo.findOne({ where: { id: ownerMember.shopId } });

  if (!owner || !shop) {
    console.error('Owner or shop not found.');
    process.exit(1);
  }

  const products = await prodRepo.find({ where: { shopId: shop.id } });
  const customers = await custRepo.find({ where: { shopId: shop.id } });

  if (products.length === 0 || customers.length === 0) {
    console.error('No products or customers found.');
    process.exit(1);
  }

  console.log(`Found ${products.length} products and ${customers.length} customers. Adding massive stock...`);

  const manager = AppDataSource.manager;

  for (const p of products) {
      await manager.query(`INSERT INTO product_batches (shop_id, product_id, batch_number, quantity, cost_price) VALUES ($1, $2, $3, $4, $5)`, [shop.id, p.id, 'BATCH-MASSIVE', 1000000, p.costPrice || 0]);
  }

  let salesCount = 0;
  let txCount = 0;

  const expenseCategories = ['Lương', 'Điện nước', 'Vận chuyển', 'Khác'];

  // Last 180 days
  for (let d = 180; d >= 0; d--) {
    // 3 to 4 orders a day -> 90 to 120 orders a month
    const ordersToday = Math.floor(Math.random() * 2) + 3; 

    for (let i = 0; i < ordersToday; i++) {
        const orderDate = new Date();
        orderDate.setDate(orderDate.getDate() - d);
        orderDate.setHours(Math.floor(Math.random() * 10) + 8); // 8 AM to 5 PM
        orderDate.setMinutes(Math.floor(Math.random() * 60));

        const itemCount = Math.floor(Math.random() * 5) + 1;
        const items = [];
        let subtotal = 0;

        for (let j = 0; j < itemCount; j++) {
            const p = products[Math.floor(Math.random() * products.length)];
            const qty = Math.floor(Math.random() * 5) + 1;
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
        
        const r = Math.random();
        const method = r < 0.6 ? 'CASH' : (r < 0.9 ? 'TRANSFER' : 'QR');

        // Only ~5% cancelled, the rest completed
        const status = Math.random() < 0.95 ? 'COMPLETED' : 'CANCELLED';

        const orderDto = {
            orderDate: orderDate.toISOString(),
            customerId: customer.id,
            items,
            discountAmount: 0,
            taxAmount: 0,
            paidAmount: subtotal,
            paymentMethod: method,
            status: status,
            notes: `Đơn hàng tự động sinh #${salesCount + 1}`,
            createdBy: owner.id
        };

        try {
            const order = await salesService.create(shop.id, orderDto);
            if (status === 'CANCELLED') {
                await salesService.cancel(shop.id, order.id);
            }
            salesCount++;
            
            if (salesCount % 100 === 0) {
                console.log(`Generated ${salesCount} sales orders...`);
            }
        } catch (e: any) {
            // Ignore stock shortage errors during seeding
            if (!e.message.includes('Insufficient stock')) {
                console.error('Error creating order:', e.message);
            }
        }
    }

    // Every day generate 1 expense
    const txDate = new Date();
    txDate.setDate(txDate.getDate() - d);
    txDate.setHours(Math.floor(Math.random() * 10) + 8);

    const category = expenseCategories[Math.floor(Math.random() * expenseCategories.length)];
    const amount = Math.floor(Math.random() * 10) * 200000 + 200000;

    try {
        await financeService.createCashTransaction(shop.id, {
            amount,
            type: 'EXPENSE',
            category: category,
            paymentMethod: Math.random() > 0.5 ? 'CASH' : 'TRANSFER',
            description: `Chi phí ${category} - ngày ${txDate.toLocaleDateString()}`,
            transactionDate: txDate,
            status: 'COMPLETED',
            createdBy: owner.id
        } as any, manager);
        txCount++;
    } catch(e: any) {
        console.error('Error creating expense:', e.message);
    }
  }

  console.log(`✅ Generated ${salesCount} sales orders (and related income transactions).`);
  console.log(`✅ Generated ${txCount} expense transactions.`);
  console.log('\n🎉 Sales & Finance Mock Data Seed completed successfully!');
  await AppDataSource.destroy();
}

seed().catch((err) => { 
  console.error('❌ Seed error:', err); 
  process.exit(1); 
});
