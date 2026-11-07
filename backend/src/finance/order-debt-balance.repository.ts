import type { EntityManager } from 'typeorm';
import { readOpeningBalanceEffects } from './opening-balance-effects.repository';
import { DebtOrder, OrderDebtRow, orderDebtBalance } from './order-debt-balance.utils';

/** Fetch a page's linked debts in bulk, within the caller's snapshot. */
export async function withOrderDebtBalances<T extends DebtOrder>(manager: EntityManager, kind: 'PURCHASE' | 'SALES', orders: T[], asOf: string) {
    if (!manager.queryRunner?.isTransactionActive) throw new Error('Order debt balance requires an active snapshot');
    const groups = new Map<number, T[]>();
    for (const order of orders) {
        if (!Number.isSafeInteger(order.shopId) || order.shopId <= 0 || !Number.isSafeInteger(order.id) || order.id <= 0) throw new Error('Phạm vi đơn hàng không hợp lệ');
        const group = groups.get(order.shopId) ?? []; group.push(order); groups.set(order.shopId, group);
    }
    const result = new Map<number, ReturnType<typeof orderDebtBalance>>();
    for (const [shopId, group] of groups) {
        const purchase = kind === 'PURCHASE';
        const table = purchase ? 'payables' : 'receivables';
        const orderColumn = purchase ? 'purchase_order_id' : 'order_id';
        const partyColumn = purchase ? 'supplier_id' : 'customer_id';
        const rows: OrderDebtRow[] = await manager.query(`SELECT id,shop_id,${orderColumn} AS order_id,${partyColumn} AS party_id,
            amount::text,paid_amount::text,status FROM ${table} WHERE shop_id=$1 AND ${orderColumn}=ANY($2::int[])`, [shopId, group.map(order => order.id)]);
        const ids = rows.map(row => Number(row.id));
        const effects = await readOpeningBalanceEffects(manager, {
            shopId, asOf, includeCash: false,
            payableIds: purchase ? ids : [], receivableIds: purchase ? [] : ids
        });
        const byOrder = new Map<number, OrderDebtRow[]>();
        for (const row of rows) { const list = byOrder.get(Number(row.order_id)) ?? []; list.push(row); byOrder.set(Number(row.order_id), list); }
        const returnedIds = kind === 'SALES' ? group.filter(order => ['PARTIAL_RETURN', 'FULL_RETURN', 'RETURNED'].includes(order.returnStatus ?? '')).map(order => order.id) : [];
        const returns = returnedIds.length ? await manager.query(`WITH proof AS (
            SELECT r.*, (SELECT COUNT(*) FROM journal_entries e WHERE e.shop_id=$1 AND e.reference_type='SALES_RETURN' AND e.reference_id=r.id AND NOT e.is_voided) AS journal_count,
                (SELECT COALESCE(SUM(l.amount),0) FROM journal_entries e JOIN journal_lines l ON l.journal_entry_id=e.id
                    WHERE e.shop_id=$1 AND e.reference_type='SALES_RETURN' AND e.reference_id=r.id AND NOT e.is_voided
                    AND l.entry_type='DEBIT' AND l.account_code IN ('511','3331','3388')) AS reversal
            FROM sales_returns r WHERE r.shop_id=$1 AND r.order_id=ANY($2::int[]) AND r.status='COMPLETED'
        ) SELECT order_id,count(*)::int AS count,sum(refund_amount)::text AS refunded_amount,
            bool_or(refund_shipping_fee) AS refund_shipping_fee,to_char(max(return_date),'YYYY-MM-DD') AS return_date,
            CASE WHEN bool_and(journal_count=1) THEN SUM(reversal)::text ELSE NULL END AS reversed_amount
            FROM proof GROUP BY order_id`, [shopId, returnedIds]) : [];
        const proofByOrder = new Map<number, DebtOrder['returnedProof']>(returns.map((row: any) => [Number(row.order_id), { count: row.count, refundedAmount: row.refunded_amount, refundShippingFee: row.refund_shipping_fee, returnDate: row.return_date, reversedAmount: row.reversed_amount ?? undefined }]));
        for (const order of group) result.set(order.id, orderDebtBalance(kind, { ...order, returnedProof: proofByOrder.get(order.id) }, byOrder.get(order.id) ?? [], effects, asOf));
    }
    return orders.map(order => ({ ...order, ...result.get(order.id)! }));
}
