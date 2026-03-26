/**
 * Seed script — insert sample data for all finance entities.
 * Run: npx ts-node src/seed.ts
 */
import 'reflect-metadata';
import { AppDataSource } from './config/db.config';
import { CashAccount, CashTransaction, BudgetPlan, CashflowForecast, DailyClosing, Invoice, TaxObligation, PurchaseWithoutInvoice } from './finance/entities';

async function seed() {
  // Force sync so new entity tables/columns are created
  Object.assign(AppDataSource.options, { synchronize: true });
  await AppDataSource.initialize();
  console.log('✅ DB connected — seeding...');

  const txRepo     = AppDataSource.getRepository(CashTransaction);
  const acctRepo   = AppDataSource.getRepository(CashAccount);
  const invRepo    = AppDataSource.getRepository(Invoice);

  const taxRepo    = AppDataSource.getRepository(TaxObligation);
  const pwiRepo    = AppDataSource.getRepository(PurchaseWithoutInvoice);
  const budgetRepo = AppDataSource.getRepository(BudgetPlan);
  const fcRepo     = AppDataSource.getRepository(CashflowForecast);
  const dcRepo     = AppDataSource.getRepository(DailyClosing);

  const today = new Date();
  const d = (offset: number) => {
    const dt = new Date(today); dt.setDate(dt.getDate() + offset);
    return dt.toISOString().split('T')[0];
  };


  // 1. Cash Account
  let acct = await acctRepo.findOneBy({ name: 'Quỹ tiền mặt' });
  if (!acct) {
    acct = acctRepo.create({ name: 'Quỹ tiền mặt', accountType: 'CASH', balance: 50000000 });
    acct = await acctRepo.save(acct);
    console.log('  ➜ CashAccount created');
  }

  // 2. Cash Transactions (income + expense)
  const txCount = await txRepo.count();
  if (txCount === 0) {
    const txs = [
      { transactionCode: 'TX-001', type: 'INCOME',  category: 'SALES',     amount: 15000000, counterparty: 'Khách lẻ',        transactionDate: d(0),  notes: 'Bán hàng tại quầy' },
      { transactionCode: 'TX-002', type: 'INCOME',  category: 'SALES',     amount: 8500000,  counterparty: 'Cửa hàng Minh',   transactionDate: d(-1), notes: 'Đơn sỉ' },
      { transactionCode: 'TX-003', type: 'INCOME',  category: 'SALES',     amount: 12000000, counterparty: 'Nguyễn Văn An',   transactionDate: d(-2), notes: 'Thanh toán đơn hàng DH-301' },
      { transactionCode: 'TX-004', type: 'EXPENSE', category: 'PURCHASE',  amount: 20000000, counterparty: 'NCC Phúc Thịnh',  transactionDate: d(-1), notes: 'Nhập hàng đợt 03/2026' },
      { transactionCode: 'TX-005', type: 'EXPENSE', category: 'SALARY',    amount: 8000000,  counterparty: 'Trần Thị Bích',   transactionDate: d(-3), notes: 'Lương tháng 3' },
      { transactionCode: 'TX-006', type: 'EXPENSE', category: 'RENT',      amount: 5000000,  counterparty: 'Chủ nhà',         transactionDate: d(-5), notes: 'Tiền thuê mặt bằng T3' },
      { transactionCode: 'TX-007', type: 'EXPENSE', category: 'UTILITIES', amount: 1200000,  counterparty: 'EVN',             transactionDate: d(-4), notes: 'Tiền điện T3' },
      { transactionCode: 'TX-008', type: 'INCOME',  category: 'SALES',     amount: 6500000,  counterparty: 'Khách lẻ',        transactionDate: d(-3), notes: 'Bán hàng online' },
      { transactionCode: 'TX-009', type: 'EXPENSE', category: 'OTHER',     amount: 800000,   counterparty: 'Grab Express',    transactionDate: d(-2), notes: 'Phí vận chuyển' },
      { transactionCode: 'TX-010', type: 'INCOME',  category: 'SALES',     amount: 4500000,  counterparty: 'Lê Hoàng',        transactionDate: d(0),  notes: 'Đơn DH-305' },
    ];
    for (const t of txs) {
      await txRepo.save(txRepo.create(t));
    }
    console.log(`  ➜ ${txs.length} CashTransactions created`);
  }

  // 3. Invoices
  const invCount = await invRepo.count();
  if (invCount === 0) {
    const invoices = [
      { invoiceNumber: 'HD-0001', type: 'OUT', partnerName: 'Cửa hàng Minh',   partnerTaxId: '0312345678', amount: 8500000,  vatAmount: 850000,  invoiceDate: d(-1) },
      { invoiceNumber: 'HD-0002', type: 'OUT', partnerName: 'Nguyễn Văn An',    partnerTaxId: undefined,    amount: 12000000, vatAmount: 1200000, invoiceDate: d(-2) },
      { invoiceNumber: 'HD-0003', type: 'IN',  partnerName: 'NCC Phúc Thịnh',   partnerTaxId: '0398765432', amount: 20000000, vatAmount: 2000000, invoiceDate: d(-1) },
      { invoiceNumber: 'HD-0004', type: 'OUT', partnerName: 'Lê Hoàng',         partnerTaxId: undefined,    amount: 4500000,  vatAmount: 450000,  invoiceDate: d(0) },
      { invoiceNumber: 'HD-0005', type: 'IN',  partnerName: 'Điện lực HCM',     partnerTaxId: '0301234567', amount: 1200000,  vatAmount: 120000,  invoiceDate: d(-4) },
    ];
    for (const inv of invoices) {
      await invRepo.save(invRepo.create(inv));
    }
    console.log(`  ➜ ${invoices.length} Invoices created`);
  }

  // 4. Tax Obligations
  const taxCount = await taxRepo.count();
  if (taxCount === 0) {
    const quarter = `Q${Math.ceil((today.getMonth() + 1) / 3)}/${today.getFullYear()}`;
    const prevQuarter = `Q${Math.ceil((today.getMonth() + 1) / 3) - 1 || 4}/${Math.ceil((today.getMonth() + 1) / 3) - 1 ? today.getFullYear() : today.getFullYear() - 1}`;
    const taxes = [
      { period: prevQuarter, vatDeclared: 3500000,  pitDeclared: 1200000,  vatPaid: 3500000, pitPaid: 1200000, status: 'done' },
      { period: quarter,     vatDeclared: 2500000,  pitDeclared: 900000,   vatPaid: 0,       pitPaid: 0,       status: 'pending' },
    ];
    for (const t of taxes) {
      await taxRepo.save(taxRepo.create(t));
    }
    console.log(`  ➜ ${taxes.length} TaxObligations created`);
  }

  // 6. Purchases Without Invoice
  const pwiCount = await pwiRepo.count();
  if (pwiCount === 0) {
    const purchases = [
      { code: 'BK-001', sellerName: 'Chị Ba chợ Bình Tây', sellerIdNumber: '079200012345', amount: 3500000, itemCount: 15, purchaseDate: d(-2), signed: true,  hasReceipt: true },
      { code: 'BK-002', sellerName: 'Anh Tư vựa trái cây', sellerIdNumber: '079200054321', amount: 1800000, itemCount: 8,  purchaseDate: d(-5), signed: true,  hasReceipt: false },
      { code: 'BK-003', sellerName: 'Cô Năm rau sạch',     sellerIdNumber: undefined,      amount: 950000,  itemCount: 5,  purchaseDate: d(0),  signed: false, hasReceipt: false },
    ];
    for (const p of purchases) {
      await pwiRepo.save(pwiRepo.create(p));
    }
    console.log(`  ➜ ${purchases.length} PurchasesWithoutInvoice created`);
  }

  // 7. Budget Plan
  const bpCount = await budgetRepo.count();
  if (bpCount === 0) {
    const startOfMonth = new Date(today.getFullYear(), today.getMonth(), 1).toISOString().split('T')[0];
    const endOfMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0).toISOString().split('T')[0];
    await budgetRepo.save(budgetRepo.create({
      name: `Ngân sách T${today.getMonth() + 1}/${today.getFullYear()}`,
      period: 'MONTHLY',
      startDate: startOfMonth,
      endDate: endOfMonth,
      plannedIncome: 50000000,
      plannedExpense: 35000000,
      actualIncome: 46500000,
      actualExpense: 35000000,
    }));
    console.log('  ➜ BudgetPlan created');
  }

  // 8. Cashflow Forecasts
  const fcCount = await fcRepo.count();
  if (fcCount === 0) {
    for (let i = 1; i <= 5; i++) {
      await fcRepo.save(fcRepo.create({
        forecastDate: d(i),
        expectedIncome: 10000000 + i * 2000000,
        expectedExpense: 8000000 + i * 1000000,
        expectedBalance: 2000000 + i * 1000000,
      }));
    }
    console.log('  ➜ 5 CashflowForecasts created');
  }

  // 9. Daily Closing (yesterday)
  const dcCount = await dcRepo.count();
  if (dcCount === 0) {
    await dcRepo.save(dcRepo.create({
      closingDate: d(-1),
      openingCash: 50000000,
      closingCash: 53300000,
      expectedCash: 53500000,
      cashDifference: -200000,
      totalSales: 8500000,
      totalIncome: 8500000,
      totalExpense: 5200000,
      orderCount: 12,
      closedAt: new Date(),
    }));
    console.log('  ➜ DailyClosing created');
  }

  console.log('\n🎉 Seed completed!');
  await AppDataSource.destroy();
}

seed().catch((err) => { console.error('❌ Seed error:', err); process.exit(1); });
