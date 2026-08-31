import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import {
  numberValue,
  parseAsOfDate,
  parseTestShopIds,
} from '../quality/test-shop-data.utils';

type RepairCounts = {
  shopId: number;
  missingSalesInvoiceItems: number;
  missingPurchaseInvoiceItems: number;
  safeDiscountUpdates: number;
  safeTotalUpdates: number;
  unresolvedInvoiceIssues: number;
};

type RepairSnapshot = {
  invoices: number;
  invoiceItems: number;
  salesOrders: number;
  purchaseOrders: number;
  invoiceIssues: number;
};

type SqlExecutor = {
  query(sql: string, params?: any[]): Promise<any[]>;
};

const appExecutor: SqlExecutor = {
  query: (sql, params) => AppDataSource.query(sql, params),
};

const argument = (name: string): string | undefined => {
  const prefix = `--${name}=`;
  return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

const apply = process.argv.includes('--apply');
const runId = argument('run-id') || `repair-test-shops-${new Date().toISOString().replace(/[-:.TZ]/g, '')}`;
const asOf = parseAsOfDate(argument('as-of'));

async function queryOne<T>(executor: SqlExecutor, sql: string, params: any[]): Promise<T> {
  const rows = await executor.query(sql, params) as T[];
  return rows[0] ?? ({} as T);
}

async function getRepairCandidates(shopIds: number[]): Promise<RepairCounts[]> {
  const rows = await AppDataSource.query(`
    WITH missing AS (
      SELECT i.id, i.shop_id, i.reference_type, i.tax_amount
      FROM invoices i
      WHERE i.shop_id = ANY($1::int[])
        AND NOT EXISTS (SELECT 1 FROM invoice_items ii WHERE ii.invoice_id = i.id)
    ), safe_sales AS (
      SELECT m.shop_id, m.id
      FROM missing m
      JOIN sales_orders o ON m.reference_type = 'SALES_ORDER'
        AND o.id = (SELECT reference_id FROM invoices WHERE id = m.id)
        AND o.shop_id = m.shop_id
      WHERE EXISTS (
        SELECT 1 FROM sales_order_items oi
        JOIN products p ON p.id = oi.product_id AND p.shop_id = m.shop_id
        WHERE oi.order_id = o.id
      )
        AND NOT EXISTS (
          SELECT 1 FROM sales_order_items oi
          LEFT JOIN products p ON p.id = oi.product_id AND p.shop_id = m.shop_id
          WHERE oi.order_id = o.id AND (
            oi.quantity <= 0 OR oi.unit_price < 0 OR oi.subtotal < 0
            OR oi.tax_amount < 0 OR p.id IS NULL
          )
        )
    ), safe_purchase AS (
      SELECT m.shop_id, m.id
      FROM missing m
      JOIN purchase_orders o ON m.reference_type = 'PURCHASE_ORDER'
        AND o.id = (SELECT reference_id FROM invoices WHERE id = m.id)
        AND o.shop_id = m.shop_id
      WHERE EXISTS (
        SELECT 1 FROM purchase_order_items oi
        JOIN products p ON p.id = oi.product_id AND p.shop_id = m.shop_id
        WHERE oi.order_id = o.id AND oi.quantity > 0
      )
        AND COALESCE(m.tax_amount, 0) = 0
        AND COALESCE(o.tax_amount, 0) = 0
        AND NOT EXISTS (
          SELECT 1 FROM purchase_order_items oi
          LEFT JOIN products p ON p.id = oi.product_id AND p.shop_id = m.shop_id
          WHERE oi.order_id = o.id AND (
            oi.quantity <= 0 OR oi.unit_price < 0 OR oi.subtotal < 0 OR p.id IS NULL
          )
        )
    ), discount_safe AS (
      SELECT i.shop_id, i.id
      FROM invoices i
      JOIN sales_orders o ON i.reference_type = 'SALES_ORDER'
        AND o.id = i.reference_id AND o.shop_id = i.shop_id
      LEFT JOIN invoice_items ii ON ii.invoice_id = i.id
      WHERE i.shop_id = ANY($1::int[]) AND o.discount_amount > 0
      GROUP BY i.shop_id, i.id, i.subtotal, o.subtotal, o.discount_amount
      HAVING ABS(COALESCE(SUM(ii.subtotal), 0) - o.subtotal) <= 1
    )
    SELECT
      s.id AS "shopId",
      (SELECT COUNT(*) FROM safe_sales WHERE shop_id = s.id)::int AS "missingSalesInvoiceItems",
      (SELECT COUNT(*) FROM safe_purchase WHERE shop_id = s.id)::int AS "missingPurchaseInvoiceItems",
      (SELECT COUNT(*) FROM discount_safe WHERE shop_id = s.id
        AND EXISTS (
          SELECT 1 FROM invoices i JOIN sales_orders o
            ON o.id = i.reference_id AND o.shop_id = i.shop_id
          WHERE i.id = discount_safe.id
            AND (ABS(COALESCE(i.discount_amount, 0) - o.discount_amount) > 1
              OR ABS(i.subtotal - o.subtotal) > 1)
        ))::int AS "safeDiscountUpdates"
    FROM unnest($1::int[]) s(id)
    ORDER BY s.id
  `, [shopIds]) as Array<Record<string, string | number>>;

  return rows.map((row) => ({
    shopId: numberValue(row.shopId),
    missingSalesInvoiceItems: numberValue(row.missingSalesInvoiceItems),
    missingPurchaseInvoiceItems: numberValue(row.missingPurchaseInvoiceItems),
    safeDiscountUpdates: numberValue(row.safeDiscountUpdates),
    safeTotalUpdates: 0,
    unresolvedInvoiceIssues: 0,
  }));
}

async function loadRemainingInvoiceIssues(executor: SqlExecutor, shopId: number): Promise<number> {
  const row = await queryOne<{ count: string | number }>(executor, `
    SELECT COUNT(*)::int AS count
    FROM (
      SELECT i.id
      FROM invoices i
      LEFT JOIN invoice_items ii ON ii.invoice_id = i.id
      LEFT JOIN products p ON p.id = ii.product_id
      WHERE i.shop_id = $1
      GROUP BY i.id
      HAVING COUNT(ii.id) = 0
          OR COUNT(ii.id) FILTER (WHERE ii.quantity <= 0 OR ii.unit_price < 0 OR ii.subtotal < 0) > 0
          OR COUNT(ii.id) FILTER (WHERE ii.product_id IS NOT NULL AND (
            p.id IS NULL OR p.shop_id IS DISTINCT FROM i.shop_id
          )) > 0
          OR ABS(COALESCE(i.subtotal, 0) - COALESCE(SUM(ii.subtotal), 0)) > 1
          OR ABS(COALESCE(i.tax_amount, 0) - COALESCE(SUM(ii.tax_amount), 0)) > 1
          OR ABS(COALESCE(i.total_amount, 0) - (
            COALESCE(i.subtotal, 0) - COALESCE(i.discount_amount, 0) + COALESCE(i.tax_amount, 0)
          )) > 1
    ) invalid_invoices
  `, [shopId]);
  return numberValue(row.count);
}

async function loadRepairSnapshot(executor: SqlExecutor, shopId: number): Promise<RepairSnapshot> {
  const row = await queryOne<{
    invoices: string | number;
    invoiceItems: string | number;
    salesOrders: string | number;
    purchaseOrders: string | number;
  }>(executor, `
    SELECT
      (SELECT COUNT(*) FROM invoices WHERE shop_id = $1)::int AS invoices,
      (SELECT COUNT(*) FROM invoice_items ii JOIN invoices i ON i.id = ii.invoice_id WHERE i.shop_id = $1)::int AS "invoiceItems",
      (SELECT COUNT(*) FROM sales_orders WHERE shop_id = $1)::int AS "salesOrders",
      (SELECT COUNT(*) FROM purchase_orders WHERE shop_id = $1)::int AS "purchaseOrders"
  `, [shopId]);
  return {
    invoices: numberValue(row.invoices),
    invoiceItems: numberValue(row.invoiceItems),
    salesOrders: numberValue(row.salesOrders),
    purchaseOrders: numberValue(row.purchaseOrders),
    invoiceIssues: await loadRemainingInvoiceIssues(executor, shopId),
  };
}

async function insertSafeInvoiceItems(
  executor: SqlExecutor,
  shopIds: number[],
): Promise<{ sales: number; purchase: number }> {
  const sales = await executor.query(`
    INSERT INTO invoice_items (
      invoice_id, product_id, item_name, unit, quantity, unit_price, subtotal, tax_rate, tax_amount
    )
    SELECT
      invoice.id, source_item.product_id, product.name, product.unit,
      source_item.quantity, source_item.unit_price, source_item.subtotal, source_item.tax_rate, source_item.tax_amount
    FROM invoices invoice
    JOIN sales_orders source_order
      ON invoice.reference_type = 'SALES_ORDER'
     AND source_order.id = invoice.reference_id
     AND source_order.shop_id = invoice.shop_id
    JOIN sales_order_items source_item ON source_item.order_id = source_order.id
    JOIN products product ON product.id = source_item.product_id AND product.shop_id = invoice.shop_id
    WHERE invoice.shop_id = ANY($1::int[])
      AND NOT EXISTS (SELECT 1 FROM invoice_items current_item WHERE current_item.invoice_id = invoice.id)
      AND NOT EXISTS (
        SELECT 1 FROM sales_order_items invalid_item
        LEFT JOIN products invalid_product
          ON invalid_product.id = invalid_item.product_id
         AND invalid_product.shop_id = invoice.shop_id
        WHERE invalid_item.order_id = source_order.id
          AND (
            invalid_item.quantity <= 0 OR invalid_item.unit_price < 0
            OR invalid_item.subtotal < 0 OR invalid_item.tax_amount < 0
            OR invalid_product.id IS NULL
          )
      )
    RETURNING invoice_id
  `, [shopIds]) as Array<{ invoice_id: number }>;

  const purchase = await executor.query(`
    INSERT INTO invoice_items (
      invoice_id, product_id, item_name, unit, quantity, unit_price, subtotal, tax_rate, tax_amount
    )
    SELECT
      invoice.id, source_item.product_id, product.name, product.unit,
      source_item.quantity, source_item.unit_price, source_item.subtotal, 0, 0
    FROM invoices invoice
    JOIN purchase_orders source_order
      ON invoice.reference_type = 'PURCHASE_ORDER'
     AND source_order.id = invoice.reference_id
     AND source_order.shop_id = invoice.shop_id
    JOIN purchase_order_items source_item ON source_item.order_id = source_order.id
    JOIN products product ON product.id = source_item.product_id AND product.shop_id = invoice.shop_id
    WHERE invoice.shop_id = ANY($1::int[])
      AND source_item.quantity > 0
      AND COALESCE(invoice.tax_amount, 0) = 0
      AND COALESCE(source_order.tax_amount, 0) = 0
      AND NOT EXISTS (SELECT 1 FROM invoice_items current_item WHERE current_item.invoice_id = invoice.id)
      AND NOT EXISTS (
        SELECT 1 FROM purchase_order_items invalid_item
        LEFT JOIN products invalid_product
          ON invalid_product.id = invalid_item.product_id
         AND invalid_product.shop_id = invoice.shop_id
        WHERE invalid_item.order_id = source_order.id
          AND (
            invalid_item.quantity <= 0 OR invalid_item.unit_price < 0
            OR invalid_item.subtotal < 0 OR invalid_product.id IS NULL
          )
      )
    RETURNING invoice_id
  `, [shopIds]) as Array<{ invoice_id: number }>;
  return { sales: new Set(sales.map((row) => row.invoice_id)).size, purchase: new Set(purchase.map((row) => row.invoice_id)).size };
}

async function updateSafeInvoiceHeaders(
  executor: SqlExecutor,
  shopIds: number[],
): Promise<{ discounts: number; totals: number }> {
  const discountRows = await executor.query(`
    WITH safe AS (
      SELECT invoice.id, source_order.subtotal, source_order.discount_amount, invoice.tax_amount
      FROM invoices invoice
      JOIN sales_orders source_order
        ON invoice.reference_type = 'SALES_ORDER'
       AND source_order.id = invoice.reference_id
       AND source_order.shop_id = invoice.shop_id
      JOIN invoice_items item ON item.invoice_id = invoice.id
      WHERE invoice.shop_id = ANY($1::int[])
      GROUP BY invoice.id, source_order.subtotal, source_order.discount_amount, invoice.tax_amount
      HAVING ABS(COALESCE(SUM(item.subtotal), 0) - source_order.subtotal) <= 1
    )
    UPDATE invoices invoice
    SET subtotal = safe.subtotal,
        discount_amount = safe.discount_amount,
        total_amount = safe.subtotal - safe.discount_amount + safe.tax_amount
    FROM safe
    WHERE invoice.id = safe.id
      AND (ABS(invoice.subtotal - safe.subtotal) > 1
        OR ABS(COALESCE(invoice.discount_amount, 0) - safe.discount_amount) > 1
        OR ABS(invoice.total_amount - (safe.subtotal - safe.discount_amount + safe.tax_amount)) > 1)
    RETURNING invoice.id
  `, [shopIds]) as Array<{ id: number }>;

  const totalRows = await executor.query(`
    WITH safe AS (
      SELECT invoice.id, invoice.subtotal, invoice.discount_amount, invoice.tax_amount
      FROM invoices invoice
      JOIN invoice_items item ON item.invoice_id = invoice.id
      WHERE invoice.shop_id = ANY($1::int[])
      GROUP BY invoice.id
      HAVING ABS(COALESCE(SUM(item.subtotal), 0) - invoice.subtotal) <= 1
         AND ABS(COALESCE(SUM(item.tax_amount), 0) - invoice.tax_amount) <= 1
    )
    UPDATE invoices invoice
    SET total_amount = safe.subtotal - COALESCE(safe.discount_amount, 0) + COALESCE(safe.tax_amount, 0)
    FROM safe
    WHERE invoice.id = safe.id
      AND ABS(invoice.total_amount - (safe.subtotal - COALESCE(safe.discount_amount, 0) + COALESCE(safe.tax_amount, 0))) > 1
    RETURNING invoice.id
  `, [shopIds]) as Array<{ id: number }>;
  return { discounts: discountRows.length, totals: totalRows.length };
}

async function writeRepairMetadata(
  executor: SqlExecutor,
  shopId: number,
  counts: RepairCounts,
  before: RepairSnapshot,
  after: RepairSnapshot,
): Promise<void> {
  const owner = await queryOne<{ userId: number }>(executor, `
    SELECT user_id AS "userId"
    FROM shop_members
    WHERE shop_id = $1 AND member_type = 'OWNER' AND status = 'ACTIVE' AND is_active = true
    ORDER BY id LIMIT 1
  `, [shopId]);
  if (!owner.userId) throw new Error(`Shop ${shopId} không có owner hoạt động để ghi audit metadata`);
  await executor.query(`
    INSERT INTO activity_logs (
      user_id, shop_id, action, entity_type, entity_id, entity_name,
      old_value, new_value, description, ip_address, created_at
    ) VALUES ($1, $2, 'UPDATE', 'DATA_QUALITY_REPAIR', NULL, $3, $4, $5, $6, NULL, NOW())
  `, [
    owner.userId,
    shopId,
    runId,
    JSON.stringify({ version: 'TEST_SHOP_DATA_QUALITY_V1', status: 'before', asOf, runId, snapshot: before, candidates: counts }),
    JSON.stringify({
      version: 'TEST_SHOP_DATA_QUALITY_V1',
      status: apply ? 'applied' : 'dry-run',
      asOf,
      runId,
      snapshot: after,
      changes: {
        invoiceItemsInserted: after.invoiceItems - before.invoiceItems,
        invoiceIssuesResolved: before.invoiceIssues - after.invoiceIssues,
        ...counts,
      },
    }),
    'Đối soát và sửa tăng dần dữ liệu test an toàn theo liên kết chứng từ',
  ]);
}

async function main(): Promise<void> {
  const shopIds = parseTestShopIds(argument('shop-ids'));
  if (apply && argument('confirm') !== `REPAIR-${shopIds.join(',')}`) {
    throw new Error(`Ghi database yêu cầu --confirm=REPAIR-${shopIds.join(',')}`);
  }

  await AppDataSource.initialize();
  try {
    if (!apply) {
      const before = await getRepairCandidates(shopIds);
      for (const row of before) {
        const snapshot = await loadRepairSnapshot(appExecutor, row.shopId);
        row.unresolvedInvoiceIssues = snapshot.invoiceIssues;
      }
      console.table(before);
      console.log(`Dry-run đến ${asOf}: database không thay đổi. Dùng --apply --confirm=REPAIR-34,35 sau khi xem audit baseline.`);
      return;
    }

    const applied = [];
    for (const shopId of shopIds) {
      const [before] = await getRepairCandidates([shopId]);
      const beforeSnapshot = await loadRepairSnapshot(appExecutor, shopId);
      const runner = AppDataSource.createQueryRunner();
      await runner.connect();
      await runner.startTransaction();
      try {
        await runner.query('SELECT pg_advisory_xact_lock($1)', [20260831]);
        const inserted = await insertSafeInvoiceItems(runner, [shopId]);
        const updated = await updateSafeInvoiceHeaders(runner, [shopId]);
        const counts: RepairCounts = {
          ...before,
          safeDiscountUpdates: updated.discounts,
          safeTotalUpdates: updated.totals,
          unresolvedInvoiceIssues: await loadRemainingInvoiceIssues(runner, shopId),
        };
        const afterSnapshot = await loadRepairSnapshot(runner, shopId);
        await writeRepairMetadata(runner, shopId, counts, beforeSnapshot, afterSnapshot);
        await runner.commitTransaction();
        applied.push({
          runId,
          shopId,
          asOf,
          before: beforeSnapshot,
          after: afterSnapshot,
          insertedSalesInvoiceItems: inserted.sales,
          insertedPurchaseInvoiceItems: inserted.purchase,
          updatedDiscountInvoices: updated.discounts,
          updatedTotalInvoices: updated.totals,
          unresolvedInvoiceIssues: counts.unresolvedInvoiceIssues,
        });
      } catch (error) {
        await runner.rollbackTransaction();
        throw error;
      } finally {
        await runner.release();
      }
    }
    console.table(applied);
    if (applied.some((row) => row.unresolvedInvoiceIssues > 0)) {
      console.log('Repair chỉ xử lý các bản ghi có nguồn xác định; các lỗi còn lại cần xem report audit, không tự điền.');
    }
  } finally {
    await AppDataSource.destroy();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? (error.stack || error.message) : error);
  process.exitCode = 1;
});
