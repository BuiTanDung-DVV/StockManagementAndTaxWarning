import { createHmac, timingSafeEqual } from 'crypto';
import type { EntityManager } from 'typeorm';
import { SyncInputError, normalizeSyncInput } from './sync-input';

type Input = ReturnType<typeof normalizeSyncInput>;
export type DuplicateCandidate = {
    id: number; code: string; date: string; amount: string;
    counterparty: string | null; notes: string | null; status: string;
    invoiceNumber?: string | null; items?: unknown;
};

// Heuristics produce a review, never an automatic merge or deletion. Queries
// are scoped to one shop and run under the same lock as the eventual write.
export async function findDuplicateCandidates(manager: EntityManager, shopId: number, input: Input): Promise<DuplicateCandidate[]> {
    const p = input.payload;
    if (input.kind === 'CASH_TRANSACTION_CREATE') {
        if (!Number.isFinite(Number(p.amount)) || Number(p.amount) <= 0) return [];
        return manager.query(`SELECT id, transaction_code AS code,
            TO_CHAR(transaction_date,'YYYY-MM-DD') AS date, amount::text AS amount,
            counterparty, notes, type AS status, payment_method AS "paymentMethod",
            category, reference_type AS "referenceType", reference_id AS "referenceId"
            FROM cash_transactions WHERE shop_id=$1 AND transaction_date=$2::date
            AND type=$3 AND amount=$4 ORDER BY id DESC LIMIT 21`,
        [shopId, p.transactionDate, p.type, p.amount]);
    }
    if (!Array.isArray(p.items) || !p.items.length) return [];
    if (p.items.some((item: unknown) => !item || typeof item !== 'object' || Array.isArray(item))) return [];
    const lines: number[][] = p.items.map((i: any) => [Number(i.productId), Number(i.quantity), Number(i.unitPrice)]);
    if (lines.some(line => line.some(n => !Number.isFinite(n)) || line[0] <= 0 || line[1] <= 0 || line[2] < 0)) return [];
    lines.sort((a, b) => a[0] - b[0] || a[1] - b[1] || a[2] - b[2]);
    const purchase = input.kind === 'PURCHASE_ORDER_CREATE';
    // Identifiers below are constants, never interpolated request values.
    const table = purchase ? 'purchase_orders' : 'sales_orders';
    const itemTable = purchase ? 'purchase_order_items' : 'sales_order_items';
    const partner = purchase ? 'supplier_id' : 'customer_id';
    const partnerTable = purchase ? 'suppliers' : 'customers';
    const partnerId = purchase ? p.supplierId : p.customerId ?? null;
    return manager.query(`SELECT o.id, o.order_code AS code,
        TO_CHAR(o.order_date,'YYYY-MM-DD') AS date, o.total_amount::text AS amount,
        c.name AS counterparty, o.notes, o.status, o.invoice_number AS "invoiceNumber",
        o.paid_amount::text AS "paidAmount", ${purchase ? 'o.warehouse_id AS "warehouseId"' : 'o.return_status AS "returnStatus", o.payment_method AS "paymentMethod"'},
        (SELECT jsonb_agg(jsonb_build_object('productId',i.product_id,'name',pr.name,'quantity',i.quantity,'unitPrice',i.unit_price)
          ORDER BY i.product_id,i.quantity,i.unit_price) FROM ${itemTable} i
          LEFT JOIN products pr ON pr.id=i.product_id AND pr.shop_id=o.shop_id WHERE i.order_id=o.id) AS items
        FROM ${table} o LEFT JOIN ${partnerTable} c ON c.id=o.${partner} AND c.shop_id=o.shop_id
        WHERE o.shop_id=$1 AND o.status <> 'CANCELLED' AND (
          ($5 <> '' AND lower(btrim(o.invoice_number))=$5 AND o.${partner} IS NOT DISTINCT FROM $3::integer)
          OR (CAST(o.order_date AS DATE)=$2::date AND o.${partner} IS NOT DISTINCT FROM $3::integer
            AND (SELECT jsonb_agg(jsonb_build_array(i.product_id,i.quantity,i.unit_price)
              ORDER BY i.product_id,i.quantity,i.unit_price) FROM ${itemTable} i WHERE i.order_id=o.id)=$4::jsonb))
        ORDER BY o.id DESC LIMIT 21`,
    [shopId, p.orderDate, partnerId, JSON.stringify(lines), String(p.invoiceNumber ?? '').trim().toLowerCase()]);
}

function signature(input: Input, shopId: number, actorId: number, candidates: DuplicateCandidate[], expires: number, secret: string) {
    return createHmac('sha256', secret).update(JSON.stringify({
        purpose: 'smartstock-duplicate-review-v1', shopId, actorId,
        operationId: input.operationId, requestHash: input.requestHash, candidates, expires,
    })).digest('hex');
}

export class SyncReviewRequired extends SyncInputError {
    readonly review: { candidates: DuplicateCandidate[]; truncated: boolean; guard: string; expiresAt: string };
    constructor(input: Input, shopId: number, actorId: number, candidates: DuplicateCandidate[], secret: string, now = Date.now()) {
        super('Có giao dịch tương tự trên cửa hàng. Kiểm tra trước khi ghi thêm.', 409);
        const expires = now + 10 * 60 * 1000;
        this.review = {
            candidates: candidates.slice(0, 20), truncated: candidates.length > 20,
            guard: `${expires}.${signature(input, shopId, actorId, candidates, expires, secret)}`,
            expiresAt: new Date(expires).toISOString(),
        };
    }
}

export function verifyDuplicateDecision(input: Input, shopId: number, actorId: number,
    candidates: DuplicateCandidate[], decision: any, secret: string, now = Date.now()): number | null {
    const invalid = () => new SyncReviewRequired(input, shopId, actorId, candidates, secret, now);
    if (!decision || typeof decision.guard !== 'string' || !['createNew', 'useExisting'].includes(decision.action)) throw invalid();
    const parts = decision.guard.split('.'), expires = Number(parts[0]);
    if (parts.length !== 2 || !Number.isSafeInteger(expires) || expires <= now || expires > now + 10 * 60 * 1000
        || !/^[a-f0-9]{64}$/.test(parts[1])) throw invalid();
    const expected = signature(input, shopId, actorId, candidates, expires, secret);
    if (!timingSafeEqual(Buffer.from(parts[1], 'hex'), Buffer.from(expected, 'hex'))) throw invalid();
    if (decision.action === 'createNew') return null;
    if (!Number.isSafeInteger(decision.entityId) || !candidates.slice(0, 20).some(c => c.id === decision.entityId)) throw invalid();
    return decision.entityId;
}
