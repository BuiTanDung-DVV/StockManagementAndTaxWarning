import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { parseTestShopIds } from '../quality/test-shop-data.utils';

type Executor = { query(sql: string, params?: unknown[]): Promise<any[]> };

const argument = (name: string): string | undefined => {
  const prefix = `--${name}=`;
  return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

const apply = process.argv.includes('--apply');
const runId = argument('run-id') || `repair-test-shop-customer-distribution-${new Date().toISOString().replace(/[-:.TZ]/g, '')}`;

function returningRows<T>(result: unknown): T[] {
  if (!Array.isArray(result)) return [];
  if (result.length === 2 && Array.isArray(result[0]) && typeof result[1] === 'number') {
    return result[0] as T[];
  }
  return result as T[];
}

function confirmationFor(shopIds: number[]): string {
  return `REALISM-CUSTOMER-${shopIds.join(',')}`;
}

function customerPrefix(shopId: number): string {
  return `KH${shopId.toString(36).toUpperCase()}`;
}

async function createAssignmentTable(executor: Executor, shopId: number, seed: string): Promise<void> {
  await executor.query(`
    CREATE TEMP TABLE customer_distribution_reassignment ON COMMIT DROP AS
    WITH customer_weights AS (
      SELECT
        c.id AS new_customer_id,
        CASE
          WHEN (((SUBSTRING(c.code FROM 4 FOR 4)::int - 1) / 5)::int) < 3 THEN 8.0
          WHEN (((SUBSTRING(c.code FROM 4 FOR 4)::int - 1) / 5)::int) < 4 THEN 3.0
          WHEN (((SUBSTRING(c.code FROM 4 FOR 4)::int - 1) / 5)::int) < 8 THEN 1.5
          WHEN (((SUBSTRING(c.code FROM 4 FOR 4)::int - 1) / 5)::int) < 12 THEN 1.0
          WHEN (((SUBSTRING(c.code FROM 4 FOR 4)::int - 1) / 5)::int) < 16 THEN 3.0
          ELSE 1.2
        END AS weight
      FROM customers c
      WHERE c.shop_id = $1
        AND c.is_active = true
        AND c.code LIKE $2 || '%'
        AND SUBSTRING(c.code FROM 4 FOR 4) ~ '^[0-9]{4}$'
        AND SUBSTRING(c.code FROM 4 FOR 4)::int BETWEEN 1 AND 100
    ), cumulative_weights AS (
      SELECT
        new_customer_id,
        weight,
        SUM(weight) OVER (ORDER BY new_customer_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS upper_bound,
        SUM(weight) OVER () AS total_weight
      FROM customer_weights
    ), totals AS (
      SELECT MAX(total_weight) AS total_weight
      FROM cumulative_weights
    ), order_slots AS (
      SELECT
        o.id AS order_id,
        o.customer_id AS old_customer_id,
        (
          MOD(ABS(hashtextextended(o.id::text || ':' || $3, 0)::numeric), 1000000)
          / 1000000.0
        ) * totals.total_weight AS slot
      FROM sales_orders o
      CROSS JOIN totals
      WHERE o.shop_id = $1
    )
    SELECT
      slots.order_id,
      slots.old_customer_id,
      weights.new_customer_id
    FROM order_slots slots
    JOIN cumulative_weights weights
      ON slots.slot >= weights.upper_bound - weights.weight
     AND slots.slot < weights.upper_bound
  `, [shopId, customerPrefix(shopId), seed]);
}

async function loadOwner(executor: Executor, shopId: number): Promise<number> {
  const rows = await executor.query(`
    SELECT user_id AS "userId"
    FROM shop_members
    WHERE shop_id = $1 AND member_type = 'OWNER' AND status = 'ACTIVE' AND is_active = true
    ORDER BY id
    LIMIT 1
  `, [shopId]);
  if (!rows[0]?.userId) throw new Error(`Shop ${shopId} không có owner ACTIVE để ghi audit`);
  return Number(rows[0].userId);
}

async function rebalanceShop(executor: Executor, shopId: number, seed: string, shouldApply: boolean): Promise<Record<string, unknown>> {
  await createAssignmentTable(executor, shopId, seed);
  const candidate = await executor.query(`
    SELECT
      COUNT(*)::int AS total_orders,
      COUNT(*) FILTER (WHERE old_customer_id IS DISTINCT FROM new_customer_id)::int AS changed_orders
    FROM customer_distribution_reassignment
  `);
  const counts = candidate[0] || { total_orders: 0, changed_orders: 0 };
  if (!shouldApply) {
    return { shopId, totalOrders: Number(counts.total_orders), proposedCustomerChanges: Number(counts.changed_orders) };
  }

  const changedOrdersResult = await executor.query(`
    UPDATE sales_orders o
    SET customer_id = reassignment.new_customer_id
    FROM customer_distribution_reassignment reassignment
    WHERE o.id = reassignment.order_id
      AND o.shop_id = $1
      AND o.customer_id IS DISTINCT FROM reassignment.new_customer_id
    RETURNING o.id
  `, [shopId]);
  const changedOrders = returningRows<{ id: number }>(changedOrdersResult).length;
  const changedReceivablesResult = await executor.query(`
    UPDATE receivables r
    SET customer_id = reassignment.new_customer_id
    FROM customer_distribution_reassignment reassignment
    WHERE r.order_id = reassignment.order_id
      AND r.shop_id = $1
      AND r.customer_id IS DISTINCT FROM reassignment.new_customer_id
    RETURNING r.id
  `, [shopId]);
  const changedReceivables = returningRows<{ id: number }>(changedReceivablesResult).length;
  const changedBalancesResult = await executor.query(`
    WITH expected AS (
      SELECT
        c.id,
        COALESCE(SUM(GREATEST(r.amount - r.paid_amount, 0)), 0) AS balance
      FROM customers c
      LEFT JOIN receivables r ON r.customer_id = c.id AND r.shop_id = c.shop_id
      WHERE c.shop_id = $1
      GROUP BY c.id
    )
    UPDATE customers c
    SET balance = expected.balance,
        updated_at = NOW()
    FROM expected
    WHERE c.id = expected.id
      AND c.balance IS DISTINCT FROM expected.balance
    RETURNING c.id
  `, [shopId]);
  const changedBalances = returningRows<{ id: number }>(changedBalancesResult).length;
  const ownerId = await loadOwner(executor, shopId);
  await executor.query(`
    INSERT INTO activity_logs (
      user_id, shop_id, action, entity_type, entity_id, entity_name,
      old_value, new_value, description, ip_address, created_at
    ) VALUES ($1, $2, 'UPDATE', 'DATA_QUALITY_REPAIR', NULL, $3, $4, $5, $6, NULL, NOW())
  `, [
    ownerId,
    shopId,
    runId,
    JSON.stringify({ runId, shopId, type: 'weighted_customer_distribution', seed, totalOrders: Number(counts.total_orders) }),
    JSON.stringify({
      runId,
      shopId,
      type: 'weighted_customer_distribution',
      policy: 'seed-customer-weights-v1',
      changedOrders,
      changedReceivables,
      changedBalances,
      preserved: ['order amounts', 'order dates', 'order items', 'payments', 'invoices', 'inventory', 'journals'],
    }),
    'Điều chỉnh phân bố khách hàng lịch sử theo trọng số test đã xác định; giữ nguyên giá trị giao dịch và liên kết chứng từ.',
  ]);
  return { shopId, totalOrders: Number(counts.total_orders), changedOrders, changedReceivables, changedBalances };
}

async function main(): Promise<void> {
  const shopIds = parseTestShopIds(argument('shop-ids'));
  const expectedConfirmation = confirmationFor(shopIds);
  if (apply && argument('confirm') !== expectedConfirmation) {
    throw new Error(`Ghi database yêu cầu --confirm=${expectedConfirmation}`);
  }
  const seed = argument('seed') || 'customer-weighted-v1';

  await AppDataSource.initialize();
  try {
    if (!apply) {
      const preview = [];
      for (const shopId of shopIds) {
        const runner = AppDataSource.createQueryRunner();
        await runner.connect();
        await runner.startTransaction();
        try {
          preview.push(await rebalanceShop(runner, shopId, seed, false));
          await runner.rollbackTransaction();
        } catch (error) {
          await runner.rollbackTransaction();
          throw error;
        } finally {
          await runner.release();
        }
      }
      console.table(preview);
      console.log(`Dry-run đến ${runId}: database không thay đổi.`);
      return;
    }

    const applied = [];
    for (const shopId of shopIds) {
      const runner = AppDataSource.createQueryRunner();
      await runner.connect();
      await runner.startTransaction();
      try {
        await runner.query('SELECT pg_advisory_xact_lock($1)', [20260902]);
        applied.push(await rebalanceShop(runner, shopId, seed, true));
        await runner.commitTransaction();
      } catch (error) {
        await runner.rollbackTransaction();
        throw error;
      } finally {
        await runner.release();
      }
    }
    console.table(applied);
  } finally {
    await AppDataSource.destroy();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? (error.stack || error.message) : error);
  process.exitCode = 1;
});
