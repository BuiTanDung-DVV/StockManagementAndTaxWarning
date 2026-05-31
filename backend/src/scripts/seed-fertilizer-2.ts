/**
 * Seed script 2 — Generate mock Invoices, Cash Transactions, and Activity Logs
 * Run: node -r ts-node/register src/scripts/seed-fertilizer-2.ts
 */
import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { User } from '../auth/entities';
import { ShopProfile, Invoice, InvoiceItem, ActivityLog } from '../system/entities';
import { Product } from '../product/entities';
import { Customer } from '../customer/entities';
import { Supplier } from '../supplier/entities';
import { CashTransaction } from '../finance/entities';

async function seed2() {
  await AppDataSource.initialize();
  console.log('✅ DB connected — generating remaining 100+ items...');

  const shopRepo = AppDataSource.getRepository(ShopProfile);
  const prodRepo = AppDataSource.getRepository(Product);
  const custRepo = AppDataSource.getRepository(Customer);
  const suppRepo = AppDataSource.getRepository(Supplier);
  const invRepo = AppDataSource.getRepository(Invoice);
  const txRepo = AppDataSource.getRepository(CashTransaction);
  const logRepo = AppDataSource.getRepository(ActivityLog);
  const userRepo = AppDataSource.getRepository(User);

  const shop = await shopRepo.findOne({ where: { shopName: 'Đại lý VTNN & VLXD Bình Minh' } });
  if (!shop) throw new Error('Shop not found. Run seed-fertilizer.ts first.');

  const owner = await userRepo.findOne({ where: { username: 'chushop_binhminh' } });
  
  const products = await prodRepo.find({ where: { shopId: shop.id } });
  const customers = await custRepo.find({ where: { shopId: shop.id } });
  const suppliers = await suppRepo.find({ where: { shopId: shop.id } });

  if (!products.length || !customers.length || !suppliers.length) {
      throw new Error('Missing products, customers, or suppliers.');
  }

  // Helper to get random item
  const getRandom = (arr: any[]) => arr[Math.floor(Math.random() * arr.length)];
  const randomDate = (startDaysAgo: number) => {
    const d = new Date();
    d.setDate(d.getDate() - Math.floor(Math.random() * startDaysAgo));
    return d;
  };

  // 1. Create 100 OUT Invoices (Sales)
  const outInvCount = await invRepo.count({ where: { shopId: shop.id, invoiceType: 'OUT' } });
  if (outInvCount < 100) {
    const invoices = [];
    for (let i = 1; i <= 100; i++) {
      const cust = getRandom(customers);
      const items = [];
      let totalAmount = 0;
      
      const numItems = Math.floor(Math.random() * 5) + 1;
      for(let j=0; j<numItems; j++) {
        const p = getRandom(products);
        const qty = Math.floor(Math.random() * 10) + 1;
        const amount = qty * Number(p.sellingPrice);
        items.push({
            product: p,
            itemName: p.name,
            unit: p.unit,
            quantity: qty,
            unitPrice: Number(p.sellingPrice),
            subtotal: amount
        });
        totalAmount += amount;
      }

      invoices.push({
        shopId: shop.id,
        invoiceNumber: `HD-OUT-${Date.now()}-${i}`,
        invoiceType: 'OUT',
        invoiceDate: randomDate(30),
        partnerName: cust.name,
        partnerTaxCode: cust.taxCode,
        partnerAddress: cust.address,
        subtotal: totalAmount,
        taxAmount: totalAmount * 0.08,
        totalAmount: totalAmount * 1.08,
        paymentMethod: Math.random() > 0.5 ? 'CASH' : 'TRANSFER',
        paymentStatus: Math.random() > 0.2 ? 'PAID' : 'UNPAID',
        createdBy: owner?.id,
        items: items
      });
    }
    for(let i=0; i<invoices.length; i+=10) {
       await invRepo.save(invoices.slice(i, i+10).map(inv => invRepo.create(inv)));
    }
    console.log('  ➜ 100 Sales Invoices created');
  }

  // 2. Create 100 IN Invoices (Purchases)
  const inInvCount = await invRepo.count({ where: { shopId: shop.id, invoiceType: 'IN' } });
  if (inInvCount < 100) {
    const invoices = [];
    for (let i = 1; i <= 100; i++) {
      const supp = getRandom(suppliers);
      const items = [];
      let totalAmount = 0;
      
      const numItems = Math.floor(Math.random() * 5) + 1;
      for(let j=0; j<numItems; j++) {
        const p = getRandom(products);
        const qty = Math.floor(Math.random() * 50) + 10;
        const amount = qty * Number(p.costPrice);
        items.push({
            product: p,
            itemName: p.name,
            unit: p.unit,
            quantity: qty,
            unitPrice: Number(p.costPrice),
            subtotal: amount
        });
        totalAmount += amount;
      }

      invoices.push({
        shopId: shop.id,
        invoiceNumber: `HD-IN-${Date.now()}-${i}`,
        invoiceType: 'IN',
        invoiceDate: randomDate(30),
        partnerName: supp.name,
        partnerTaxCode: supp.taxCode,
        partnerAddress: supp.address,
        subtotal: totalAmount,
        taxAmount: totalAmount * 0.1, // 10% VAT
        totalAmount: totalAmount * 1.1,
        paymentMethod: 'TRANSFER',
        paymentStatus: Math.random() > 0.5 ? 'PAID' : 'PARTIAL',
        createdBy: owner?.id,
        items: items
      });
    }
    for(let i=0; i<invoices.length; i+=10) {
       await invRepo.save(invoices.slice(i, i+10).map(inv => invRepo.create(inv)));
    }
    console.log('  ➜ 100 Purchase Invoices created');
  }

  // 3. Create 100 Cash Transactions
  const txCount = await txRepo.count({ where: { shopId: shop.id } });
  if (txCount < 100) {
    const txs = [];
    for (let i = 1; i <= 100; i++) {
      const isIncome = Math.random() > 0.4;
      txs.push({
        shopId: shop.id,
        transactionCode: `PTC-${Date.now().toString().slice(-8)}-${i.toString().padStart(3, '0')}`,
        type: isIncome ? 'INCOME' : 'EXPENSE',
        category: isIncome ? 'SALES' : (Math.random() > 0.5 ? 'PURCHASE' : 'UTILITIES'),
        amount: Math.floor(Math.random() * 5000) * 1000 + 100000,
        paymentMethod: Math.random() > 0.5 ? 'CASH' : 'TRANSFER',
        counterparty: isIncome ? getRandom(customers).name : getRandom(suppliers).name,
        transactionDate: randomDate(30),
        notes: isIncome ? `Thu tiền khách hàng ${i}` : `Chi trả nhà cung cấp ${i}`
      });
    }
    for(let i=0; i<txs.length; i+=20) {
        await txRepo.save(txs.slice(i, i+20).map(t => txRepo.create(t)));
    }
    console.log('  ➜ 100 Cash Transactions created');
  }

  // 4. Create 100 Activity Logs
  const logCount = await logRepo.count({ where: { shopId: shop.id } });
  if (logCount < 100) {
    const logs = [];
    const actions = ['CREATE', 'UPDATE', 'DELETE', 'LOGIN'];
    const entities = ['Product', 'Invoice', 'Customer', 'Supplier'];
    for (let i = 1; i <= 100; i++) {
      logs.push({
        shopId: shop.id,
        userId: owner?.id || 1,
        action: getRandom(actions),
        entityType: getRandom(entities),
        entityId: Math.floor(Math.random() * 100) + 1,
        entityName: `Bản ghi mô phỏng #${i}`,
        details: '{"mock": true}',
        ipAddress: '127.0.0.1',
        createdAt: randomDate(10)
      });
    }
    for(let i=0; i<logs.length; i+=20) {
        await logRepo.save(logs.slice(i, i+20).map(l => logRepo.create(l)));
    }
    console.log('  ➜ 100 Activity Logs created');
  }

  console.log('\n🎉 Phase 2 Seed completed successfully!');
  await AppDataSource.destroy();
}

seed2().catch((err) => { 
  console.error('❌ Seed error:', err); 
  process.exit(1); 
});
