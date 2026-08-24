import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';

type Candidate = {
    shop_id: number;
    order_id: number;
    order_code: string;
    entry_date: Date;
    missing_bank_amount: string;
};

const REPAIR_TABLE = 'data_repair_20260824_debt_collection_journals';
const RUN_ID = 'debt-collection-112-20260824-v1';

function parseShopIds(): number[] {
    const argument = process.argv.find(value => value.startsWith('--shop-ids='));
    const ids = String(argument?.split('=')[1] || '')
        .split(',')
        .map(value => Number(value.trim()))
        .filter(value => Number.isInteger(value) && value > 0);
    if (ids.length === 0) {
        throw new Error('Thiếu --shop-ids=<id,id> hợp lệ');
    }
    return [...new Set(ids)];
}

async function loadCandidates(query: (sql: string, params?: unknown[]) => Promise<any[]>, shopIds: number[]): Promise<Candidate[]> {
    return query(`
        WITH payment_totals AS (
            SELECT
                o.shop_id,
                o.id AS order_id,
                o.order_code,
                MAX(p.paid_at) FILTER (WHERE UPPER(p.method) != 'CASH') AS entry_date,
                COALESCE(SUM(
                    CASE WHEN UPPER(p.method) != 'CASH' THEN p.amount ELSE 0 END
                ), 0) AS expected_bank_amount
            FROM sales_orders o
            JOIN sales_order_payments p
              ON p.order_id = o.id
             AND p.shop_id = o.shop_id
            WHERE o.shop_id = ANY($1)
              AND UPPER(COALESCE(o.status, '')) != 'CANCELLED'
            GROUP BY o.shop_id, o.id, o.order_code
        ), ledger_totals AS (
            SELECT
                e.shop_id,
                e.reference_id AS order_id,
                COALESCE(SUM(
                    CASE
                        WHEN l.account_code = '112' AND l.entry_type = 'DEBIT'
                        THEN l.amount
                        ELSE 0
                    END
                ), 0) AS ledger_bank_amount
            FROM journal_entries e
            JOIN journal_lines l ON l.journal_entry_id = e.id
            WHERE e.shop_id = ANY($1)
              AND e.is_voided = false
              AND e.reference_type IN ('SALES_ORDER', 'DEBT_COLLECTION')
            GROUP BY e.shop_id, e.reference_id
        )
        SELECT
            p.shop_id,
            p.order_id,
            p.order_code,
            p.entry_date,
            (p.expected_bank_amount - COALESCE(l.ledger_bank_amount, 0))::numeric(15, 2)
                AS missing_bank_amount
        FROM payment_totals p
        LEFT JOIN ledger_totals l
          ON l.shop_id = p.shop_id
         AND l.order_id = p.order_id
        WHERE p.expected_bank_amount - COALESCE(l.ledger_bank_amount, 0) > 1
        ORDER BY p.shop_id, p.order_id
    `, [shopIds]);
}

async function assertRepairShape(shopIds: number[]): Promise<void> {
    const rows = await AppDataSource.query(`
        WITH expected AS (
            SELECT
                o.shop_id,
                o.id AS order_id,
                COALESCE(SUM(CASE WHEN UPPER(p.method) = 'CASH' THEN p.amount ELSE 0 END), 0) AS cash_amount,
                COALESCE(SUM(CASE WHEN UPPER(p.method) != 'CASH' THEN p.amount ELSE 0 END), 0) AS bank_amount
            FROM sales_orders o
            LEFT JOIN sales_order_payments p
              ON p.order_id = o.id
             AND p.shop_id = o.shop_id
            WHERE o.shop_id = ANY($1)
              AND UPPER(COALESCE(o.status, '')) != 'CANCELLED'
            GROUP BY o.shop_id, o.id
        ), ledger AS (
            SELECT
                e.shop_id,
                e.reference_id AS order_id,
                COALESCE(SUM(CASE WHEN l.account_code = '111' AND l.entry_type = 'DEBIT' THEN l.amount ELSE 0 END), 0) AS cash_amount,
                COALESCE(SUM(CASE WHEN l.account_code = '112' AND l.entry_type = 'DEBIT' THEN l.amount ELSE 0 END), 0) AS bank_amount
            FROM journal_entries e
            JOIN journal_lines l ON l.journal_entry_id = e.id
            WHERE e.shop_id = ANY($1)
              AND e.is_voided = false
              AND e.reference_type IN ('SALES_ORDER', 'DEBT_COLLECTION')
            GROUP BY e.shop_id, e.reference_id
        )
        SELECT
            COUNT(*) FILTER (WHERE COALESCE(l.cash_amount, 0) > e.cash_amount + 1) AS cash_over,
            COUNT(*) FILTER (WHERE COALESCE(l.bank_amount, 0) > e.bank_amount + 1) AS bank_over,
            COUNT(*) FILTER (WHERE e.cash_amount > COALESCE(l.cash_amount, 0) + 1) AS cash_missing
        FROM expected e
        LEFT JOIN ledger l
          ON l.shop_id = e.shop_id
         AND l.order_id = e.order_id
    `, [shopIds]);
    const row = rows[0] || {};
    if (Number(row.cash_over) || Number(row.bank_over) || Number(row.cash_missing)) {
        throw new Error(
            'Dữ liệu có dạng sai lệch ngoài phạm vi backfill 112; dừng để tránh sửa nhầm',
        );
    }
}

async function applyRepair(shopIds: number[], candidates: Candidate[]): Promise<void> {
    await AppDataSource.transaction(async manager => {
        await manager.query(`
            CREATE TABLE IF NOT EXISTS ${REPAIR_TABLE} (
                id BIGSERIAL PRIMARY KEY,
                run_id VARCHAR(80) NOT NULL,
                shop_id INTEGER NOT NULL,
                order_id INTEGER NOT NULL,
                journal_entry_id INTEGER NOT NULL UNIQUE,
                amount NUMERIC(15, 2) NOT NULL,
                repaired_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
                UNIQUE (run_id, shop_id, order_id)
            )
        `);

        const insertedLines = await manager.query(`
            WITH payment_totals AS (
                SELECT
                    o.shop_id,
                    o.id AS order_id,
                    o.order_code,
                    MAX(p.paid_at) FILTER (WHERE UPPER(p.method) != 'CASH') AS entry_date,
                    COALESCE(SUM(
                        CASE WHEN UPPER(p.method) != 'CASH' THEN p.amount ELSE 0 END
                    ), 0) AS expected_bank_amount
                FROM sales_orders o
                JOIN sales_order_payments p
                  ON p.order_id = o.id
                 AND p.shop_id = o.shop_id
                WHERE o.shop_id = ANY($1)
                  AND UPPER(COALESCE(o.status, '')) != 'CANCELLED'
                GROUP BY o.shop_id, o.id, o.order_code
            ), ledger_totals AS (
                SELECT
                    e.shop_id,
                    e.reference_id AS order_id,
                    COALESCE(SUM(
                        CASE
                            WHEN l.account_code = '112' AND l.entry_type = 'DEBIT'
                            THEN l.amount
                            ELSE 0
                        END
                    ), 0) AS ledger_bank_amount
                FROM journal_entries e
                JOIN journal_lines l ON l.journal_entry_id = e.id
                WHERE e.shop_id = ANY($1)
                  AND e.is_voided = false
                  AND e.reference_type IN ('SALES_ORDER', 'DEBT_COLLECTION')
                GROUP BY e.shop_id, e.reference_id
            ), candidates AS (
                SELECT
                    p.shop_id,
                    p.order_id,
                    p.order_code,
                    p.entry_date,
                    (p.expected_bank_amount - COALESCE(l.ledger_bank_amount, 0))::numeric(15, 2)
                        AS missing_bank_amount
                FROM payment_totals p
                LEFT JOIN ledger_totals l
                  ON l.shop_id = p.shop_id
                 AND l.order_id = p.order_id
                WHERE p.expected_bank_amount - COALESCE(l.ledger_bank_amount, 0) > 1
                  AND NOT EXISTS (
                      SELECT 1
                      FROM ${REPAIR_TABLE} r
                      WHERE r.run_id = $2
                        AND r.shop_id = p.shop_id
                        AND r.order_id = p.order_id
                  )
            ), inserted_entries AS (
                INSERT INTO journal_entries (
                    shop_id, entry_date, reference_type, reference_id,
                    description, is_voided, created_at
                )
                SELECT
                    c.shop_id,
                    c.entry_date,
                    'DEBT_COLLECTION',
                    c.order_id,
                    'Bổ sung bút toán thu công nợ còn thiếu - Đơn ' || c.order_code,
                    false,
                    c.entry_date
                FROM candidates c
                RETURNING id, shop_id, reference_id, entry_date
            ), tracked AS (
                INSERT INTO ${REPAIR_TABLE} (
                    run_id, shop_id, order_id, journal_entry_id, amount
                )
                SELECT
                    $2,
                    c.shop_id,
                    c.order_id,
                    e.id,
                    c.missing_bank_amount
                FROM candidates c
                JOIN inserted_entries e
                  ON e.shop_id = c.shop_id
                 AND e.reference_id = c.order_id
                RETURNING journal_entry_id, amount
            )
            INSERT INTO journal_lines (
                journal_entry_id, account_code, amount, entry_type, created_at
            )
            SELECT t.journal_entry_id, '112', t.amount, 'DEBIT', e.entry_date
            FROM tracked t
            JOIN inserted_entries e ON e.id = t.journal_entry_id
            UNION ALL
            SELECT t.journal_entry_id, '131', t.amount, 'CREDIT', e.entry_date
            FROM tracked t
            JOIN inserted_entries e ON e.id = t.journal_entry_id
            RETURNING journal_entry_id
        `, [shopIds, RUN_ID]);
        if (insertedLines.length !== candidates.length * 2) {
            throw new Error(
                `Số dòng bút toán được tạo không khớp: ${insertedLines.length}/${candidates.length * 2}`,
            );
        }

        const remaining = await loadCandidates(
            (sql, params) => manager.query(sql, params),
            shopIds,
        );
        if (remaining.length > 0) {
            throw new Error(`Backfill chưa khép kín: còn ${remaining.length} đơn sai lệch`);
        }
    });
}

async function rollbackRepair(shopIds: number[]): Promise<void> {
    if (!process.argv.includes('--confirm=ROLLBACK-111112-20260824')) {
        throw new Error('Rollback cần --confirm=ROLLBACK-111112-20260824');
    }
    await AppDataSource.transaction(async manager => {
        const tableRows = await manager.query(
            `SELECT TO_REGCLASS('public.${REPAIR_TABLE}') AS table_name`,
        );
        if (!tableRows[0]?.table_name) return;
        const tracked = await manager.query(`
            SELECT journal_entry_id
            FROM ${REPAIR_TABLE}
            WHERE run_id = $1 AND shop_id = ANY($2)
        `, [RUN_ID, shopIds]);
        const entryIds = tracked.map((row: { journal_entry_id: number | string }) => (
            Number(row.journal_entry_id)
        ));
        if (entryIds.length > 0) {
            await manager.query(
                'DELETE FROM journal_entries WHERE id = ANY($1)',
                [entryIds],
            );
        }
        await manager.query(`
            DELETE FROM ${REPAIR_TABLE}
            WHERE run_id = $1 AND shop_id = ANY($2)
        `, [RUN_ID, shopIds]);
        console.log(`Đã hoàn tác ${entryIds.length} bút toán của đợt ${RUN_ID}.`);
    });
}

async function main(): Promise<void> {
    const shopIds = parseShopIds();
    const apply = process.argv.includes('--apply');
    const rollback = process.argv.includes('--rollback');
    if (apply && rollback) throw new Error('Không dùng đồng thời --apply và --rollback');

    await AppDataSource.initialize();
    try {
        if (rollback) {
            await rollbackRepair(shopIds);
            return;
        }

        await assertRepairShape(shopIds);
        const candidates = await loadCandidates(
            (sql, params) => AppDataSource.query(sql, params),
            shopIds,
        );
        const summary = shopIds.map(shopId => {
            const rows = candidates.filter(row => Number(row.shop_id) === shopId);
            return {
                shopId,
                orders: rows.length,
                missingBankAmount: rows.reduce(
                    (sum, row) => sum + Number(row.missing_bank_amount),
                    0,
                ),
            };
        });
        console.table(summary);
        if (!apply) {
            console.log('Chỉ xem trước. Thêm --apply để ghi database.');
            return;
        }
        await applyRepair(shopIds, candidates);
        console.log(`Đã bổ sung ${candidates.length} bút toán và lưu dấu vết ${RUN_ID}.`);
    } finally {
        await AppDataSource.destroy();
    }
}

main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
});
