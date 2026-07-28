import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';

type Severity = 'ERROR' | 'WARNING';

type ValidationResult = {
  name: string;
  severity: Severity;
  violations: number;
  detail?: string;
};

function parseShopId(): number {
  const argument = process.argv.find((value) => value.startsWith('--shop-id='));
  const shopId = Number(argument?.split('=')[1]);
  if (!Number.isInteger(shopId) || shopId <= 0) {
    throw new Error('Thiếu --shop-id=<id> hợp lệ');
  }
  return shopId;
}

async function count(sql: string, shopId: number): Promise<number> {
  const rows = await AppDataSource.query(sql, [shopId]);
  return Number(rows[0]?.violations || 0);
}

async function main(): Promise<void> {
  const shopId = parseShopId();
  await AppDataSource.initialize();
  try {
    const shopRows = await AppDataSource.query(
      'SELECT id, shop_name FROM shop_profiles WHERE id = $1',
      [shopId],
    );
    if (!shopRows.length) throw new Error(`Không tìm thấy cửa hàng id=${shopId}`);

    const results: ValidationResult[] = [];
    const add = async (
      name: string,
      severity: Severity,
      sql: string,
      detail?: string,
    ) => {
      results.push({
        name,
        severity,
        violations: await count(sql, shopId),
        detail,
      });
    };

    await add(
      'Tổng tiền đơn bán khớp dòng hàng',
      'ERROR',
      `
        SELECT COUNT(*) AS violations
        FROM (
          SELECT o.id
          FROM sales_orders o
          LEFT JOIN sales_order_items i ON i.order_id = o.id
          WHERE o.shop_id = $1
          GROUP BY o.id
          HAVING ABS(
            COALESCE(o.subtotal, 0) -
            COALESCE(SUM(i.subtotal), 0)
          ) > 1
          OR ABS(
            COALESCE(o.total_amount, 0) -
            (COALESCE(o.subtotal, 0) - COALESCE(o.discount_amount, 0) + COALESCE(o.tax_amount, 0))
          ) > 1
        ) invalid_orders
      `,
    );
    await add(
      'Số tiền đã trả của đơn hợp lệ',
      'ERROR',
      `
        SELECT COUNT(*) AS violations
        FROM sales_orders
        WHERE shop_id = $1
          AND (paid_amount < 0 OR paid_amount > total_amount)
      `,
    );
    await add(
      'Khoản phải thu không âm hoặc thu vượt',
      'ERROR',
      `
        SELECT COUNT(*) AS violations
        FROM receivables
        WHERE shop_id = $1
          AND (amount <= 0 OR paid_amount < 0 OR paid_amount > amount)
      `,
    );
    await add(
      'Số dư khách hàng khớp phải thu còn lại',
      'ERROR',
      `
        SELECT COUNT(*) AS violations
        FROM customers c
        LEFT JOIN (
          SELECT customer_id, SUM(GREATEST(amount - paid_amount, 0)) AS remaining
          FROM receivables
          WHERE shop_id = $1 AND status NOT IN ('PAID', 'CANCELLED')
          GROUP BY customer_id
        ) debt ON debt.customer_id = c.id
        WHERE c.shop_id = $1
          AND ABS(COALESCE(c.balance, 0) - COALESCE(debt.remaining, 0)) > 1
      `,
    );
    await add(
      'Số dư nhà cung cấp khớp phải trả còn lại',
      'ERROR',
      `
        SELECT COUNT(*) AS violations
        FROM suppliers s
        LEFT JOIN (
          SELECT supplier_id, SUM(GREATEST(amount - paid_amount, 0)) AS remaining
          FROM payables
          WHERE shop_id = $1 AND status NOT IN ('PAID', 'CANCELLED')
          GROUP BY supplier_id
        ) debt ON debt.supplier_id = s.id
        WHERE s.shop_id = $1
          AND ABS(COALESCE(s.balance, 0) - COALESCE(debt.remaining, 0)) > 1
      `,
    );
    await add(
      'Tồn hiện tại khớp tổng nhập xuất',
      'ERROR',
      `
        SELECT COUNT(*) AS violations
        FROM (
          SELECT
            COALESCE(s.product_id, m.product_id) AS product_id,
            COALESCE(s.warehouse_id, m.warehouse_id) AS warehouse_id,
            COALESCE(s.quantity, 0) AS stock_quantity,
            COALESCE(m.movement_quantity, 0) AS movement_quantity
          FROM (
            SELECT product_id, warehouse_id, SUM(quantity) AS quantity
            FROM inventory_stocks
            WHERE shop_id = $1
            GROUP BY product_id, warehouse_id
          ) s
          FULL JOIN (
            SELECT product_id, warehouse_id,
              SUM(
                CASE
                  WHEN movement_type IN ('IN', 'RETURN') THEN quantity
                  WHEN movement_type = 'OUT' THEN -quantity
                  ELSE quantity
                END
              ) AS movement_quantity
            FROM inventory_movements
            WHERE shop_id = $1
            GROUP BY product_id, warehouse_id
          ) m
            ON m.product_id = s.product_id
            AND m.warehouse_id = s.warehouse_id
        ) inventory_compare
        WHERE ABS(stock_quantity - movement_quantity) > 0.001
      `,
    );
    await add(
      'Mỗi bút toán cân bằng Nợ/Có',
      'ERROR',
      `
        SELECT COUNT(*) AS violations
        FROM (
          SELECT e.id
          FROM journal_entries e
          LEFT JOIN journal_lines l ON l.journal_entry_id = e.id
          WHERE e.shop_id = $1 AND e.is_voided = false
          GROUP BY e.id
          HAVING
            ABS(
              COALESCE(SUM(CASE WHEN l.entry_type = 'DEBIT' THEN l.amount ELSE 0 END), 0) -
              COALESCE(SUM(CASE WHEN l.entry_type = 'CREDIT' THEN l.amount ELSE 0 END), 0)
            ) > 1
            OR COUNT(l.id) < 2
        ) invalid_journals
      `,
    );
    await add(
      'Dòng đơn bán không tham chiếu chéo cửa hàng',
      'ERROR',
      `
        SELECT COUNT(*) AS violations
        FROM sales_order_items i
        JOIN sales_orders o ON o.id = i.order_id
        JOIN products p ON p.id = i.product_id
        WHERE i.shop_id = $1
          AND (o.shop_id != $1 OR p.shop_id != $1)
      `,
    );
    await add(
      'Tài khoản tiền khớp giao dịch',
      'ERROR',
      `
        SELECT COUNT(*) AS violations
        FROM cash_accounts a
        LEFT JOIN (
          SELECT account_id,
            SUM(CASE WHEN type = 'INCOME' THEN amount ELSE -amount END) AS expected_balance
          FROM cash_transactions
          WHERE shop_id = $1
          GROUP BY account_id
        ) tx ON tx.account_id = a.id
        WHERE a.shop_id = $1
          AND ABS(COALESCE(a.balance, 0) - COALESCE(tx.expected_balance, 0)) > 1
      `,
    );
    await add(
      'Chốt quỹ liên tục giữa các ngày',
      'ERROR',
      `
        SELECT COUNT(*) AS violations
        FROM (
          SELECT
            closing_date,
            opening_cash,
            LAG(closing_cash) OVER (ORDER BY closing_date) AS previous_closing
          FROM daily_closings
          WHERE shop_id = $1
        ) closings
        WHERE previous_closing IS NOT NULL
          AND ABS(opening_cash - previous_closing) > 1
      `,
    );
    await add(
      'Chốt quỹ không có chênh lệch ngoài giải trình',
      'WARNING',
      `
        SELECT COUNT(*) AS violations
        FROM daily_closings
        WHERE shop_id = $1
          AND ABS(COALESCE(cash_difference, 0)) > 1
          AND COALESCE(TRIM(notes), '') = ''
      `,
    );
    await add(
      'Lịch sử đơn bán không bị khuyết ngày',
      'WARNING',
      `
        SELECT COUNT(*) AS violations
        FROM (
          SELECT day::date
          FROM generate_series(
            (SELECT MIN(order_date)::date FROM sales_orders WHERE shop_id = $1),
            (SELECT MAX(order_date)::date FROM sales_orders WHERE shop_id = $1),
            interval '1 day'
          ) day
        ) calendar
        WHERE NOT EXISTS (
          SELECT 1
          FROM sales_orders o
          WHERE o.shop_id = $1 AND o.order_date::date = calendar.day
        )
      `,
      'Bộ dữ liệu 3 năm yêu cầu có hoạt động mỗi ngày.',
    );

    const periodRows = await AppDataSource.query(`
      SELECT
        MIN(order_date)::date AS "firstOrder",
        MAX(order_date)::date AS "lastOrder",
        COUNT(*)::int AS orders,
        COUNT(DISTINCT order_date::date)::int AS "activeDays"
      FROM sales_orders
      WHERE shop_id = $1
    `, [shopId]);

    console.log(`Đối soát dữ liệu: ${shopRows[0].shop_name} (ID ${shopId})`);
    console.table(results.map((result) => ({
      status: result.violations === 0 ? 'PASS' : result.severity,
      check: result.name,
      violations: result.violations,
      detail: result.detail || '',
    })));
    console.table(periodRows);

    const errors = results.filter(
      (result) => result.severity === 'ERROR' && result.violations > 0,
    );
    if (errors.length > 0) {
      throw new Error(`Đối soát thất bại: ${errors.length} nhóm lỗi nghiêm trọng`);
    }
  } finally {
    await AppDataSource.destroy();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
