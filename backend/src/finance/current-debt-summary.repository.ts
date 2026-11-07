import type { EntityManager } from 'typeorm';
import { openingDebtEffectRows, openingEffectCents, openingEffectValue, readOpeningBalanceEffects } from './opening-balance-effects.repository';

export type CurrentDebtKind = 'RECEIVABLE' | 'PAYABLE';

/** Aggregate current effective debt in the caller's snapshot, before reminders. */
export async function readCurrentDebtSummary(manager: EntityManager, kind: CurrentDebtKind, shopIds: number[], asOf: string) {
    if (!manager.queryRunner?.isTransactionActive) throw new Error('Current debt summary requires an active snapshot');
    if (!['RECEIVABLE', 'PAYABLE'].includes(kind) || shopIds.some(id => !Number.isSafeInteger(id) || id <= 0)) {
        throw new Error('Phạm vi tổng hợp công nợ không hợp lệ');
    }
    const totals: Record<string, unknown> = { total_amount: 0, total_count: 0, source_updated_at: null };
    const cents = new Map<string, bigint>();
    const periods = ['overdue', 'today', 'soon'] as const;
    for (const period of periods) {
        totals[`${period}_count`] = 0; totals[`${period}_amount`] = 0; totals[`${period}_due_at`] = null;
    }
    let adjustedSource = false;
    for (const shopId of new Set(shopIds)) {
        const effects = await readOpeningBalanceEffects(manager, {
            shopId, asOf, includeCash: false,
            receivableIds: kind === 'RECEIVABLE' ? undefined : [], payableIds: kind === 'PAYABLE' ? undefined : [],
        });
        const offsets = openingDebtEffectRows(effects, kind);
        adjustedSource ||= offsets.length > 0;
        // Both names are internal constants, never request-controlled SQL.
        const table = kind === 'PAYABLE' ? 'payables' : 'receivables';
        const [row] = await manager.query(`WITH effective AS (
            SELECT d.amount,d.paid_amount,d.due_date,d.updated_at,
                GREATEST(d.amount-COALESCE(d.paid_amount,0)+COALESCE(e.adjustment_amount,0),0) AS remaining
            FROM ${table} d
            LEFT JOIN jsonb_to_recordset($2::jsonb) AS e(id integer,adjustment_amount numeric,opening_date date) ON e.id=d.id
            WHERE d.shop_id=$1 AND UPPER(COALESCE(d.status,'')) <> 'CANCELLED'
                AND (e.opening_date IS NULL OR e.opening_date <= $3::date)
        ) SELECT
            COALESCE(BOOL_OR(amount IS NULL OR amount<0 OR COALESCE(paid_amount,0)<0),false) AS invalid_data,
            COALESCE(SUM(remaining),0)::text AS total_amount, COUNT(*) FILTER(WHERE remaining>0)::int AS total_count,
            ${periods.map(period => {
                const condition = period === 'overdue' ? 'due_date < $3::date' : period === 'today' ? 'due_date = $3::date' : 'due_date > $3::date AND due_date <= $3::date+7';
                return `COUNT(*) FILTER(WHERE remaining>0 AND ${condition})::int AS ${period}_count,
                    COALESCE(SUM(remaining) FILTER(WHERE remaining>0 AND ${condition}),0)::text AS ${period}_amount,
                    to_char(MIN(due_date) FILTER(WHERE remaining>0 AND ${condition}),'YYYY-MM-DD') AS ${period}_due_at`;
            }).join(',')}, MAX(updated_at) AS source_updated_at FROM effective`, [shopId, JSON.stringify(offsets), asOf]);
        if (!row || row.invalid_data !== false) throw new Error('Dữ liệu công nợ cần đối chiếu trước khi tổng hợp');
        for (const key of ['total', ...periods]) {
            const amount = openingEffectCents(row[`${key}_amount`]);
            const count = row[`${key}_count`];
            if (amount < 0n || !Number.isSafeInteger(count) || count < 0) throw new Error('Tổng hợp công nợ không hợp lệ');
            cents.set(key, (cents.get(key) ?? 0n) + amount);
            totals[`${key}_amount`] = openingEffectValue(cents.get(key)!);
            const combinedCount = Number(totals[`${key}_count`]) + count;
            if (!Number.isSafeInteger(combinedCount)) throw new Error('Số khoản nợ vượt giới hạn hiển thị');
            totals[`${key}_count`] = combinedCount;
            if (key !== 'total') {
                const date = row[`${key}_due_at`];
                if (count > 0 && (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date))) throw new Error('Ngày đến hạn công nợ không hợp lệ');
                if (date && (!totals[`${key}_due_at`] || date < String(totals[`${key}_due_at`]))) totals[`${key}_due_at`] = date;
            }
        }
        const updated = row.source_updated_at ? new Date(row.source_updated_at).toISOString() : null;
        if (updated && (!totals.source_updated_at || updated > String(totals.source_updated_at))) totals.source_updated_at = updated;
    }
    // Base-row timestamps alone cannot date a separate opening adjustment.
    if (adjustedSource) totals.source_updated_at = null;
    return totals;
}
