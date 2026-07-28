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

async function main(): Promise<void> {
  await AppDataSource.initialize();
  try {
    const schemaRows = await AppDataSource.query(`
      SELECT
        TO_REGCLASS('public.ai_knowledge_documents') IS NOT NULL AS "aiKnowledgeReady",
        TO_REGCLASS('public.journal_entries') IS NOT NULL AS "journalReady",
        TO_REGCLASS('public.inventory_movements') IS NOT NULL AS "inventoryReady"
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
    console.table(schemaRows);
  } finally {
    await AppDataSource.destroy();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
