import { DataSource } from 'typeorm';
import { config } from './env.config';

import { AuditLogSubscriber } from '../system/audit-log.subscriber';

// Import tường minh các entities từ các modules tương ứng để tránh lỗi quét thư mục động trên Vercel Serverless
import { User } from '../auth/entities';
import { ShopRole, ShopMember, Notification } from '../shop/entities';
import { Customer, Receivable, DebtEvidence, DebtPaymentHistory } from '../customer/entities';
import { Supplier, Payable } from '../supplier/entities';
import { Category, Product, CostType, ProductCostItem, ProductBatch, UnitConversion, ProductPriceHistory } from '../product/entities';
import { Warehouse, InventoryStock, InventoryMovement, PurchaseOrder, PurchaseOrderItem, StockTake, StockTakeItem } from '../inventory/entities';
import { InventoryLot } from '../inventory/lot.entity';
import { SalesOrder, SalesOrderItem, SalesOrderPayment, SalesReturn, SalesReturnItem, SalesOrderLotDeduction } from '../sales/entities';
import { ShopProfile, ActivityLog, InvoiceScan, Invoice as SystemInvoice, InvoiceItem as SystemInvoiceItem } from '../system/entities';
import { FinancialLedger } from '../finance/entities/financial-ledger.entity';
import { JournalEntry, JournalLine } from '../finance/ledger.entity';
import { CashAccount, TaxRule, CashTransaction, BudgetPlan, CashflowForecast, DailyClosing, Invoice as FinanceInvoice, TaxObligation, PurchaseWithoutInvoice, PurchaseWithoutInvoiceItem } from '../finance/entities';

export const AppDataSource = new DataSource({
  type: 'postgres',
  ...(config.dbUrl 
    ? { url: config.dbUrl, ssl: { rejectUnauthorized: false } } 
    : {
        host: config.dbHost,
        database: config.dbDatabase,
      }),
  extra: {
    max: 10,
    connectionTimeoutMillis: 3000,
    idleTimeoutMillis: 10000,
  },
  synchronize: false, // Schema managed by Supabase — never auto-sync
  entities: [
    User, ShopRole, ShopMember, Notification, Customer, Receivable, DebtEvidence, DebtPaymentHistory,
    Supplier, Payable, Category, Product, CostType, ProductCostItem, ProductBatch, UnitConversion,
    ProductPriceHistory, Warehouse, InventoryStock, InventoryMovement, PurchaseOrder, PurchaseOrderItem,
    StockTake, StockTakeItem, InventoryLot, SalesOrder, SalesOrderItem, SalesOrderPayment, SalesReturn,
    SalesReturnItem, SalesOrderLotDeduction, ShopProfile, ActivityLog, InvoiceScan, SystemInvoice,
    SystemInvoiceItem, FinancialLedger, JournalEntry, JournalLine, CashAccount, TaxRule, CashTransaction,
    BudgetPlan, CashflowForecast, DailyClosing, FinanceInvoice, TaxObligation, PurchaseWithoutInvoice,
    PurchaseWithoutInvoiceItem
  ],
  migrations: [],
  subscribers: [AuditLogSubscriber],
});
