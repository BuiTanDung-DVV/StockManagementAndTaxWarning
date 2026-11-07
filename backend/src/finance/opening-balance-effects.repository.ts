import type { EntityManager } from 'typeorm';

export interface OpeningBalanceEffects {
    storageReady: boolean;
    cashCents: bigint;
    bankCents: bigint;
    receivableCents: Map<number, bigint>;
    payableCents: Map<number, bigint>;
    receivableDates: Map<number, string>;
    payableDates: Map<number, string>;
}

export interface OpeningEffectsSelection {
    shopId: number;
    asOf: string;
    includeCash?: boolean;
    receivableIds?: readonly number[];
    payableIds?: readonly number[];
}

/** Exact internal arithmetic; the API conversion is explicit and bounded. */
export function openingEffectCents(value: unknown): bigint {
    const text = String(value);
    if (!/^-?\d+(?:\.\d{1,2})?$/.test(text) || text.length > 40) {
        throw new Error('Số tiền không hợp lệ hoặc có quá hai chữ số thập phân.');
    }
    const [whole, fraction = ''] = text.replace(/^-/, '').split('.');
    const cents = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'));
    return text.startsWith('-') ? -cents : cents;
}

export function openingEffectValue(cents: bigint): number {
    if (cents > BigInt(Number.MAX_SAFE_INTEGER) || cents < BigInt(Number.MIN_SAFE_INTEGER)) {
        throw new Error('Số dư vượt giới hạn số tiền có thể hiển thị chính xác.');
    }
    const value = Number(cents) / 100;
    if (openingEffectCents(String(value)) !== cents) throw new Error('Số dư không thể chuyển đổi mà giữ nguyên từng xu.');
    return value;
}

export function openingEffectText(cents: bigint): string {
    const value = cents < 0n ? -cents : cents;
    return `${cents < 0n ? '-' : ''}${value / 100n}.${String(value % 100n).padStart(2,'0')}`;
}

export function openingDebtEffectRows(effects: OpeningBalanceEffects, kind: 'RECEIVABLE' | 'PAYABLE') {
    const offsets = kind === 'RECEIVABLE' ? effects.receivableCents : effects.payableCents;
    const dates = kind === 'RECEIVABLE' ? effects.receivableDates : effects.payableDates;
    return [...new Set([...offsets.keys(),...dates.keys()])].map(id => ({
        id, adjustment_amount:openingEffectText(offsets.get(id) ?? 0n), opening_date:dates.get(id) ?? null,
    }));
}

export function openingAdjustedDebt(amount: unknown, paid: unknown, adjustmentCents = 0n) {
    const amountCents = openingEffectCents(amount);
    const paidCents = openingEffectCents(paid ?? 0);
    if (amountCents < 0n || paidCents < 0n) throw new Error('Giá trị khoản nợ hoặc số đã thanh toán không hợp lệ.');
    const rawRemaining = amountCents - paidCents + adjustmentCents;
    return {
        amountCents, paidCents, adjustmentCents,
        remainingCents: rawRemaining > 0n ? rawRemaining : 0n,
        // Keep this separate from actual receipts/payments.
        closedByAdjustment: rawRemaining <= 0n && adjustmentCents < 0n && paidCents < amountCents,
    };
}

function validate(input: OpeningEffectsSelection) {
    if (!Number.isInteger(input.shopId) || input.shopId <= 0 || input.shopId > 2147483647) throw new Error('Cửa hàng không hợp lệ.');
    const date = new Date(`${input.asOf}T00:00:00Z`);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(input.asOf) || !Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== input.asOf) {
        throw new Error('Ngày số dư không hợp lệ.');
    }
    for (const ids of [input.receivableIds, input.payableIds]) {
        if (ids !== undefined && (!Array.isArray(ids) || ids.some(id => !Number.isInteger(id) || id <= 0 || id > 2147483647))) {
            throw new Error('Mã khoản nợ không hợp lệ.');
        }
    }
}

/**
 * Call within the same snapshot or shop mutation transaction as the base rows.
 * Missing draft storage means no opening entries exist. Query errors, corrupt
 * references or invalid amounts in existing storage are never treated as zero.
 */
export async function readOpeningBalanceEffects(manager: EntityManager, input: OpeningEffectsSelection): Promise<OpeningBalanceEffects> {
    validate(input);
    const [storage] = await manager.query(`SELECT to_regclass('public.opening_balance_batches') IS NOT NULL AS batches_ready,
        to_regclass('public.opening_balance_adjustments') IS NOT NULL AS adjustments_ready`);
    if (typeof storage?.batches_ready !== 'boolean' || typeof storage?.adjustments_ready !== 'boolean') {
        throw new Error('Không xác định được cấu trúc số dư ban đầu.');
    }
    if (storage?.batches_ready !== storage?.adjustments_ready) throw new Error('Cấu trúc số dư ban đầu chưa đầy đủ.');
    const result: OpeningBalanceEffects = {storageReady:storage?.batches_ready === true,cashCents:0n,bankCents:0n,
        receivableCents:new Map(),payableCents:new Map(),receivableDates:new Map(),payableDates:new Map()};
    if (!result.storageReady) return result;
    const rows = await manager.query(`SELECT a.kind,a.effect_mode,a.amount_delta::text,a.receivable_id,a.payable_id,
        to_char(CASE WHEN a.effect_mode='LINKED_DOCUMENT'
            THEN COALESCE((a.source_details->>'businessDate')::date,b.as_of) ELSE b.as_of END,'YYYY-MM-DD') AS effective_date,
        r.id AS scoped_receivable,p.id AS scoped_payable
        FROM opening_balance_adjustments a
        JOIN opening_balance_batches b ON b.id=a.batch_id AND b.shop_id=a.shop_id
        LEFT JOIN receivables r ON r.id=a.receivable_id AND r.shop_id=a.shop_id
        LEFT JOIN payables p ON p.id=a.payable_id AND p.shop_id=a.shop_id
        WHERE a.shop_id=$1 AND (
            (a.kind IN ('CASH','BANK') AND $3::boolean)
            OR (a.kind='RECEIVABLE' AND ($4::int[] IS NULL OR a.receivable_id=ANY($4::int[])))
            OR (a.kind='PAYABLE' AND ($5::int[] IS NULL OR a.payable_id=ANY($5::int[]))))
        AND (b.as_of <= $2::date OR a.effect_mode='LINKED_DOCUMENT') ORDER BY a.id`,
        [input.shopId,input.asOf,input.includeCash !== false,input.receivableIds ?? null,input.payableIds ?? null]);
    for (const row of rows) {
        const cents = openingEffectCents(row.amount_delta);
        if (row.kind === 'CASH' || row.kind === 'BANK') {
            if (row.effect_mode !== 'BALANCE_OFFSET') throw new Error('Nguồn điều chỉnh số dư tiền không hợp lệ.');
            if (row.kind === 'CASH') result.cashCents += cents;
            else result.bankCents += cents;
            continue;
        }
        const receivable = row.kind === 'RECEIVABLE';
        const id = Number(receivable ? row.receivable_id : row.payable_id);
        const scoped = Number(receivable ? row.scoped_receivable : row.scoped_payable);
        if (!Number.isInteger(id) || id <= 0 || scoped !== id) throw new Error('Điều chỉnh công nợ không khớp cửa hàng hoặc chứng từ.');
        const offsets = receivable ? result.receivableCents : result.payableCents;
        const dates = receivable ? result.receivableDates : result.payableDates;
        if (row.effect_mode === 'BALANCE_OFFSET') offsets.set(id,(offsets.get(id) ?? 0n) + cents);
        else if (row.effect_mode === 'LINKED_DOCUMENT') {
            if (dates.has(id)) throw new Error('Khoản nợ có nhiều nguồn số dư ban đầu.');
            dates.set(id,row.effective_date);
            // Its amount is already recorded in receivables/payables; do not add twice.
        } else throw new Error('Loại điều chỉnh công nợ không hợp lệ.');
    }
    return result;
}
