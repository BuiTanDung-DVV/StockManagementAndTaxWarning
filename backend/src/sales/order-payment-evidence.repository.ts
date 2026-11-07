import { EntityManager } from 'typeorm';
import { openingEffectCents, openingEffectValue } from '../finance/opening-balance-effects.repository';
import { normalizeSettledPaymentMethod } from './payment-ledger.utils';
import { SalesWriteError } from './sales-write-authorization';

type Evidence = { amount: unknown; method: unknown };
function grouped(rows: Evidence[]) {
    const result = new Map<string, bigint>();
    for (const row of rows) {
        let amount: bigint, method: string;
        try { amount = openingEffectCents(row.amount); method = normalizeSettledPaymentMethod(String(row.method)); }
        catch { throw new SalesWriteError('Lịch sử thu tiền có số tiền hoặc phương thức cần đối chiếu', 409); }
        if (amount <= 0n) throw new SalesWriteError('Lịch sử thu tiền có số tiền không hợp lệ', 409);
        if (method === 'BANK_TRANSFER') method = 'TRANSFER';
        if (method === 'CREDIT_CARD') method = 'CARD';
        result.set(method, (result.get(method) ?? 0n) + amount);
    }
    return result;
}
/** Use a complete receipt/cash source; never infer a missing channel from the order label. */
export async function readOrderPaymentEvidence(manager: EntityManager, shopId: number, orderId: number, paidAmount: unknown) {
    if (!manager.queryRunner?.isTransactionActive) throw new Error('Payment evidence requires an active transaction');
    const paid = openingEffectCents(paidAmount);
    const receipts: Evidence[] = await manager.query(`SELECT p.amount::text,p.method FROM sales_order_payments p
        JOIN sales_orders o ON o.id=p.order_id AND o.shop_id=$1
        WHERE p.order_id=$2 AND (p.shop_id=$1 OR p.shop_id IS NULL) ORDER BY p.id`, [shopId, orderId]);
    const cash: Evidence[] = await manager.query(`SELECT c.amount::text,c.payment_method AS method FROM cash_transactions c
        JOIN sales_orders o ON o.id=c.reference_id AND o.shop_id=$1
        WHERE c.reference_type='SALES_ORDER' AND c.reference_id=$2 AND c.type='INCOME'
        AND (c.shop_id=$1 OR c.shop_id IS NULL) ORDER BY c.id`, [shopId, orderId]);
    const a = grouped(receipts), b = grouped(cash);
    const sum = (rows: Map<string, bigint>) => [...rows.values()].reduce((total, amount) => total + amount, 0n);
    const at = sum(a), bt = sum(b);
    if (paid < 0n || at > paid || bt > paid || at !== paid && bt !== paid) throw new SalesWriteError('Chưa đủ lịch sử thu tiền để xác định khoản hoàn. Cần đối chiếu chứng từ thu trước khi hủy hoặc trả hàng.', 409);
    const complete = at === paid ? a : b, partial = at === paid ? b : a;
    if ([...partial].some(([method, amount]) => amount > (complete.get(method) ?? 0n))) throw new SalesWriteError('Phương thức thu tiền trên các nguồn chưa khớp; cần đối chiếu trước khi hoàn.', 409);
    return [...complete].map(([method, amount]) => ({ method, amount: openingEffectValue(amount) }));
}
