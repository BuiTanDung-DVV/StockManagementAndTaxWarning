import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';

type ShopAuditRow = {
  id: number;
  shopName: string;
  orders: number;
  products: number;
  customers: number;
  firstOrder: string | null;
  lastOrder: string | null;
  simulatedProducts: number;
  simulatedCustomers: number;
  generatedOrders: number;
  generatedTransactions: number;
  mockActivityLogs: number;
};

type ScreenCoverageRow = {
  shopId: number;
  products: number;
  categories: number;
  tags: number;
  costTypes: number;
  productCostItems: number;
  unitConversions: number;
  priceHistory: number;
  productBatches: number;
  inventoryLots: number;
  stockTakes: number;
  purchaseOrders: number;
  salesOrders: number;
  salesReturns: number;
  receivables: number;
  debtEvidences: number;
  suppliers: number;
  payables: number;
  cashTransactions: number;
  financialLedger: number;
  dailyClosings: number;
  cashflowForecasts: number;
  budgetPlans: number;
  invoices: number;
  invoiceScans: number;
  purchasesWithoutInvoice: number;
  taxObligations: number;
  activityLogs: number;
  aiKnowledgeDocuments: number;
  notifications: number;
};

async function main(): Promise<void> {
  await AppDataSource.initialize();
  try {
    const schemaRows = await AppDataSource.query(`
      SELECT
        TO_REGCLASS('public.ai_knowledge_documents') IS NOT NULL AS "aiKnowledgeReady",
        TO_REGCLASS('public.journal_entries') IS NOT NULL AS "journalReady",
        TO_REGCLASS('public.inventory_movements') IS NOT NULL AS "inventoryReady",
        NOT EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public'
            AND table_name = 'purchase_without_invoice_items'
            AND column_name = 'item_name'
            AND is_nullable = 'NO'
        ) AS "purchaseItemApiReady"
    `);
    const rows = await AppDataSource.query(`
      SELECT
        sp.id,
        sp.shop_name AS "shopName",
        (SELECT COUNT(*)::int FROM sales_orders so WHERE so.shop_id = sp.id) AS orders,
        (SELECT COUNT(*)::int FROM products p WHERE p.shop_id = sp.id) AS products,
        (SELECT COUNT(*)::int FROM customers c WHERE c.shop_id = sp.id) AS customers,
        (SELECT MIN(so.order_date)::date FROM sales_orders so WHERE so.shop_id = sp.id) AS "firstOrder",
        (SELECT MAX(so.order_date)::date FROM sales_orders so WHERE so.shop_id = sp.id) AS "lastOrder",
        (
          SELECT COUNT(*)::int FROM products p
          WHERE p.shop_id = sp.id
            AND (p.name LIKE 'Temp Product%' OR COALESCE(p.tags, '') LIKE '%sim_tag_%')
        ) AS "simulatedProducts",
        (
          SELECT COUNT(*)::int FROM customers c
          WHERE c.shop_id = sp.id AND c.name LIKE 'Simulated Customer%'
        ) AS "simulatedCustomers",
        (
          SELECT COUNT(*)::int FROM sales_orders so
          WHERE so.shop_id = sp.id
            AND (
              LOWER(COALESCE(so.notes, '')) LIKE '%tự động sinh%'
              OR LOWER(COALESCE(so.notes, '')) LIKE '%auto-generated%'
              OR LOWER(COALESCE(so.notes, '')) LIKE '%mô phỏng%'
              OR LOWER(COALESCE(so.notes, '')) LIKE '%mock%'
            )
        ) AS "generatedOrders",
        (
          SELECT COUNT(*)::int FROM cash_transactions ct
          WHERE ct.shop_id = sp.id
            AND (
              LOWER(COALESCE(ct.notes, '')) LIKE '%tự động%'
              OR LOWER(COALESCE(ct.notes, '')) LIKE '%mô phỏng%'
              OR LOWER(COALESCE(ct.notes, '')) LIKE '%mock%'
            )
        ) AS "generatedTransactions",
        (
          SELECT COUNT(*)::int FROM activity_logs al
          WHERE al.shop_id = sp.id
            AND (
              LOWER(COALESCE(al.new_value, '')) LIKE '%"mock":true%'
              OR LOWER(COALESCE(al.description, '')) LIKE '%mô phỏng%'
            )
        ) AS "mockActivityLogs"
      FROM shop_profiles sp
      ORDER BY sp.id
    `) as ShopAuditRow[];
    const coverageRows = await AppDataSource.query(`
      SELECT
        sp.id AS "shopId",
        (SELECT COUNT(*)::int FROM products x WHERE x.shop_id = sp.id) AS products,
        (SELECT COUNT(*)::int FROM categories x WHERE x.shop_id = sp.id) AS categories,
        (SELECT COUNT(*)::int FROM tags x WHERE x.shop_id = sp.id) AS tags,
        (SELECT COUNT(*)::int FROM cost_types x WHERE x.shop_id = sp.id) AS "costTypes",
        (SELECT COUNT(*)::int FROM product_cost_items x WHERE x.shop_id = sp.id) AS "productCostItems",
        (SELECT COUNT(*)::int FROM unit_conversions x WHERE x.shop_id = sp.id) AS "unitConversions",
        (SELECT COUNT(*)::int FROM product_price_history x WHERE x.shop_id = sp.id) AS "priceHistory",
        (SELECT COUNT(*)::int FROM product_batches x WHERE x.shop_id = sp.id) AS "productBatches",
        (SELECT COUNT(*)::int FROM inventory_lots x WHERE x.shop_id = sp.id) AS "inventoryLots",
        (SELECT COUNT(*)::int FROM stock_takes x WHERE x.shop_id = sp.id) AS "stockTakes",
        (SELECT COUNT(*)::int FROM purchase_orders x WHERE x.shop_id = sp.id) AS "purchaseOrders",
        (SELECT COUNT(*)::int FROM sales_orders x WHERE x.shop_id = sp.id) AS "salesOrders",
        (SELECT COUNT(*)::int FROM sales_returns x WHERE x.shop_id = sp.id) AS "salesReturns",
        (SELECT COUNT(*)::int FROM receivables x WHERE x.shop_id = sp.id) AS receivables,
        (SELECT COUNT(*)::int FROM debt_evidences x WHERE x.shop_id = sp.id) AS "debtEvidences",
        (SELECT COUNT(*)::int FROM suppliers x WHERE x.shop_id = sp.id) AS suppliers,
        (SELECT COUNT(*)::int FROM payables x WHERE x.shop_id = sp.id) AS payables,
        (SELECT COUNT(*)::int FROM cash_transactions x WHERE x.shop_id = sp.id) AS "cashTransactions",
        (SELECT COUNT(*)::int FROM financial_ledger x WHERE x.shop_id = sp.id) AS "financialLedger",
        (SELECT COUNT(*)::int FROM daily_closings x WHERE x.shop_id = sp.id) AS "dailyClosings",
        (SELECT COUNT(*)::int FROM cashflow_forecasts x WHERE x.shop_id = sp.id) AS "cashflowForecasts",
        (SELECT COUNT(*)::int FROM budget_plans x WHERE x.shop_id = sp.id) AS "budgetPlans",
        (SELECT COUNT(*)::int FROM invoices x WHERE x.shop_id = sp.id) AS invoices,
        (SELECT COUNT(*)::int FROM invoice_scans x WHERE x.shop_id = sp.id) AS "invoiceScans",
        (SELECT COUNT(*)::int FROM purchases_without_invoice x WHERE x.shop_id = sp.id) AS "purchasesWithoutInvoice",
        (SELECT COUNT(*)::int FROM tax_obligations x WHERE x.shop_id = sp.id) AS "taxObligations",
        (SELECT COUNT(*)::int FROM activity_logs x WHERE x.shop_id = sp.id) AS "activityLogs",
        (SELECT COUNT(*)::int FROM ai_knowledge_documents x WHERE x.shop_id = sp.id) AS "aiKnowledgeDocuments",
        (
          SELECT COUNT(*)::int
          FROM notifications n
          JOIN shop_members sm ON sm.user_id = n.user_id
          WHERE sm.shop_id = sp.id
        ) AS notifications
      FROM shop_profiles sp
      ORDER BY sp.id
    `) as ScreenCoverageRow[];

    console.table(rows.map((row) => ({
      id: Number(row.id),
      shop: row.shopName,
      orders: Number(row.orders),
      products: Number(row.products),
      customers: Number(row.customers),
      firstOrder: row.firstOrder,
      lastOrder: row.lastOrder,
      simulatedProducts: Number(row.simulatedProducts),
      simulatedCustomers: Number(row.simulatedCustomers),
      generatedOrders: Number(row.generatedOrders),
      generatedTransactions: Number(row.generatedTransactions),
      mockActivityLogs: Number(row.mockActivityLogs),
    })));
    console.log('Độ phủ dữ liệu cho các màn hình:');
    console.table(coverageRows.map((row) => Object.fromEntries(
      Object.entries(row).map(([key, value]) => [
        key,
        key === 'shopId' ? Number(value) : Number(value),
      ]),
    )));
    console.table(schemaRows);
  } finally {
    await AppDataSource.destroy();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
