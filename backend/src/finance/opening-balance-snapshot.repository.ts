import { createHash } from 'crypto';
import type { DataSource, EntityManager } from 'typeorm';
import { vietnamDateKey } from './finance-period.utils';
import { OpeningBalancePlanError, OpeningBalanceSnapshot, OpeningSourceLink, normalizeOpeningSourceLinks, openingAmountCents, openingCentsText, openingSumCents } from './opening-balance-plan.utils';

type Selection = { key: string; kind: 'CASH' | 'BANK' | 'STOCK' | 'RECEIVABLE' | 'PAYABLE'; id?: number; warehouse?: number };
type Row = Record<string, any>;
export type OpeningSnapshotInput = { shopId: number; asOf: string; keys: string[]; sourceLinks?: OpeningSourceLink[] };
export type OpeningSourceCandidate = { key: string; debtId: number; amount: string; paidAmount: string; recordedDate: string; businessDate?: string; reference?: string };
const invalid = (message: string): never => { throw new OpeningBalancePlanError(message); };
export function normalizeOpeningSnapshotInput(input: OpeningSnapshotInput, now = new Date()): Selection[] {
    if (!input || !Number.isInteger(input.shopId) || input.shopId < 1 || input.shopId > 2147483647) invalid('Chọn một cửa hàng để đối chiếu.');
    if (typeof input.asOf !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(input.asOf)) invalid('Ngày đối chiếu không hợp lệ.');
    const date = new Date(`${input.asOf}T00:00:00Z`);
    if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== input.asOf || input.asOf > vietnamDateKey(now)) invalid('Ngày đối chiếu phải hợp lệ và không sau hôm nay.');
    if (!Array.isArray(input.keys) || input.keys.length < 1 || input.keys.length > 500 || new Set(input.keys).size !== input.keys.length) invalid('Chọn từ 1 đến 500 đối tượng, không trùng.');
    normalizeOpeningSourceLinks(input.sourceLinks, input.keys, now);
    return input.keys.map(key => {
        if (key === 'cash' || key === 'bank') return { key, kind: key === 'cash' ? 'CASH' : 'BANK' } as Selection;
        const match = typeof key === 'string' ? /^(stock|customer|supplier):([1-9]\d*)(?::([1-9]\d*))?$/.exec(key) : null;
        if (!match || (match[1] === 'stock') !== Boolean(match[3])) invalid('Mã đối tượng đối chiếu không hợp lệ.');
        const id = Number(match![2]), warehouse = match![3] ? Number(match![3]) : undefined;
        if (!Number.isSafeInteger(id) || id > 2147483647 || (warehouse !== undefined && (!Number.isSafeInteger(warehouse) || warehouse > 2147483647))) invalid('Mã đối tượng vượt giới hạn.');
        return { key, kind: match![1] === 'stock' ? 'STOCK' : match![1] === 'customer' ? 'RECEIVABLE' : 'PAYABLE', id, warehouse } as Selection;
    }).sort((a, b) => a.key.localeCompare(b.key, 'en'));
}

/** One read-only repeatable snapshot. No HTTP route exposes this draft yet. */
export async function loadOpeningBalanceSnapshot(source: DataSource, input: OpeningSnapshotInput, now = new Date()) {
    normalizeOpeningSnapshotInput(input, now);
    return source.transaction('REPEATABLE READ', async manager => {
        await manager.query('SET TRANSACTION READ ONLY');
        await manager.query("SET LOCAL statement_timeout = '8000ms'");
        return readOpeningBalanceSnapshot(manager, input, now);
    });
}

/** Also reusable inside the eventual locked commit transaction. */
export async function readOpeningBalanceSnapshot(manager: EntityManager, input: OpeningSnapshotInput,
    now = new Date()): Promise<OpeningBalanceSnapshot & { labels: Record<string, string>; storageReady: boolean; sourceCandidates: OpeningSourceCandidate[] }> {
    const selected = normalizeOpeningSnapshotInput(input, now);
    const sourceLinks = normalizeOpeningSourceLinks(input.sourceLinks, input.keys, now);
    const sourceCandidates: OpeningSourceCandidate[] = [];
    const [storage] = await manager.query(`SELECT to_regclass('public.opening_balance_batches') IS NOT NULL
        AND to_regclass('public.opening_balance_adjustments') IS NOT NULL AS ready`);
    const storageReady = storage.ready === true;
    const gaps: string[] = storageReady ? [] : ['OPENING_STORAGE_NOT_READY'];
    const rowGaps: Record<string, string[]> = {}, labels: Record<string, string> = {}, versions: unknown[] = [];
    const rows: OpeningBalanceSnapshot['rows'] = [];
    const gap = (key: string, reason: string) => { (rowGaps[key] ??= []).push(reason); };
    let adjustments: Row[] = [];
    if (storageReady) {
        adjustments = await manager.query(`SELECT a.*, to_char(CASE WHEN a.effect_mode='LINKED_DOCUMENT'
            THEN COALESCE((a.source_details->>'businessDate')::date,b.as_of) ELSE b.as_of END,'YYYY-MM-DD') AS effective_date
            FROM opening_balance_adjustments a JOIN opening_balance_batches b ON b.id=a.batch_id AND b.shop_id=a.shop_id
            WHERE a.shop_id=$1 ORDER BY a.id`, [input.shopId]);
        versions.push(adjustments);
    }
    const amount = (value: unknown) => openingAmountCents(value ?? '0', true);
    const offset = (key: string, atDate: boolean) => adjustments.filter(a => a.object_key === key
        && a.effect_mode === 'BALANCE_OFFSET' && (!atDate || a.effective_date <= input.asOf))
        .map(a => amount(a.amount_delta));

    const walletKeys = selected.filter(s => s.kind === 'CASH' || s.kind === 'BANK');
    if (walletKeys.length) {
        const [cash] = await manager.query(`SELECT
            COALESCE(SUM(CASE WHEN transaction_date<$2::date AND COALESCE(payment_method,'CASH')='CASH'
              THEN CASE type WHEN 'INCOME' THEN amount WHEN 'EXPENSE' THEN -amount ELSE 0 END ELSE 0 END),0)::text AS cash,
            COALESCE(SUM(CASE WHEN transaction_date<$2::date AND COALESCE(payment_method,'CASH')<>'CASH'
              THEN CASE type WHEN 'INCOME' THEN amount WHEN 'EXPENSE' THEN -amount ELSE 0 END ELSE 0 END),0)::text AS bank,
            COUNT(*) FILTER(WHERE type NOT IN ('INCOME','EXPENSE') OR type IS NULL OR amount<0
              OR COALESCE(payment_method,'CASH') NOT IN ('CASH','TRANSFER','BANK_TRANSFER','QR','CARD','CREDIT_CARD','MOMO','ZALOPAY'))::int AS invalid,
            md5(COALESCE(string_agg(to_jsonb(t)::text,'|' ORDER BY id),'')) AS revision
            FROM cash_transactions t WHERE shop_id=$1`, [input.shopId, input.asOf]);
        versions.push(cash.revision);
        for (const selection of walletKeys) {
            rows.push({ key: selection.key, kind: selection.kind, amount: openingCentsText(openingSumCents([amount(cash[selection.key]), ...offset(selection.key, true)])) });
            labels[selection.key] = selection.kind === 'CASH' ? 'Tiền mặt' : 'Tiền gửi và chuyển khoản';
            if (cash.invalid > 0) gap(selection.key, 'Có giao dịch sai loại hoặc phương thức; chưa xác định được số dư.');
        }
        if (walletKeys.some(s => s.kind === 'CASH')) {
            const closings: Row[] = await manager.query(`SELECT *,to_char(closing_date,'YYYY-MM-DD') AS date_key FROM daily_closings WHERE shop_id=$1 ORDER BY closing_date,id`, [input.shopId]);
            versions.push(closings);
            if (closings.some(c => c.date_key >= input.asOf)) gap('cash', 'Có ngày đã chốt từ mốc đối chiếu; cần đối chiếu các phiếu chênh lệch để tránh cộng tiền hai lần.');
            const anchors = closings.filter(c => c.date_key < input.asOf);
            const anchor = anchors[anchors.length - 1];
            if (anchor) {
                const [carried] = await manager.query(`SELECT COALESCE(SUM(CASE type WHEN 'INCOME' THEN amount WHEN 'EXPENSE' THEN -amount ELSE 0 END),0)::text AS amount
                    FROM cash_transactions WHERE shop_id=$1 AND COALESCE(payment_method,'CASH')='CASH'
                    AND transaction_date>$2::date AND transaction_date<$3::date`, [input.shopId, anchor.date_key, input.asOf]);
                const sinceAnchor = adjustments.filter(a => a.object_key === 'cash'
                    && a.effect_mode === 'BALANCE_OFFSET'
                    && a.effective_date > anchor.date_key && a.effective_date <= input.asOf)
                    .map(a => amount(a.amount_delta));
                const anchored = openingSumCents([amount(anchor.closing_cash), amount(carried.amount), ...sinceAnchor]);
                const book = openingSumCents([amount(cash.cash), ...offset('cash', true)]);
                if (anchored !== book) gap('cash', 'Số tiền từ mốc kiểm quỹ khác sổ thu chi; cần đối chiếu nguồn trước khi bổ sung.');
            }
        }
    }

    const stockKeys = selected.filter(s => s.kind === 'STOCK');
    if (stockKeys.length) {
        const params = [input.shopId, input.asOf, stockKeys.map(s => s.id), stockKeys.map(s => s.warehouse)];
        const masters: Row[] = await manager.query(`SELECT k.product_id,k.warehouse_id,p.name,p.unit,w.name AS warehouse_name,
            COALESCE(SUM(s.quantity),0)::int AS current_quantity,COUNT(s.id)::int AS stock_rows,
            md5(to_jsonb(p)::text||to_jsonb(w)::text||COALESCE(string_agg(to_jsonb(s)::text,'|' ORDER BY s.id),'')) AS revision
            FROM unnest($2::int[],$3::int[]) k(product_id,warehouse_id)
            JOIN products p ON p.id=k.product_id AND p.shop_id=$1 AND p.is_active=true
            JOIN warehouses w ON w.id=k.warehouse_id AND w.shop_id=$1 AND w.is_active=true
            LEFT JOIN inventory_stocks s ON s.product_id=p.id AND s.warehouse_id=w.id AND s.shop_id=$1
            GROUP BY k.product_id,k.warehouse_id,p.id,w.id ORDER BY k.product_id,k.warehouse_id`, [input.shopId, stockKeys.map(s => s.id), stockKeys.map(s => s.warehouse)]);
        if (masters.length !== stockKeys.length) invalid('Hàng hoặc kho không thuộc cửa hàng, hoặc đã ngừng hoạt động.');
        const openingJoin = storageReady ? "LEFT JOIN opening_balance_batches ob ON m.reference_type='OPENING_BALANCE' AND ob.id=m.reference_id AND ob.shop_id=m.shop_id" : '';
        const openingDay = storageReady ? "WHEN 'OPENING_BALANCE' THEN ob.as_of" : '';
        const movementDay = `COALESCE(CASE m.reference_type
            WHEN 'PURCHASE_ORDER' THEN (po.order_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
            WHEN 'SALES_ORDER' THEN (so.order_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
            WHEN 'SALES_RETURN' THEN (sr.return_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date
            WHEN 'STOCK_TAKE' THEN st.stock_take_date
            WHEN 'PURCHASE_NO_INVOICE' THEN pw.purchase_date WHEN 'PURCHASE_WITHOUT_INVOICE' THEN pw.purchase_date ${openingDay}
            END,(m.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date)`;
        const atOpening = storageReady ? "m.reference_type='OPENING_BALANCE' AND ob.as_of=$2::date" : 'false';
        const movements: Row[] = await manager.query(`WITH m AS (
            SELECT m.*,${movementDay} AS day,
              (CASE m.reference_type WHEN 'PURCHASE_ORDER' THEN po.id IS NULL WHEN 'SALES_ORDER' THEN so.id IS NULL
                WHEN 'SALES_RETURN' THEN sr.id IS NULL WHEN 'STOCK_TAKE' THEN st.id IS NULL
                WHEN 'PURCHASE_NO_INVOICE' THEN pw.id IS NULL WHEN 'PURCHASE_WITHOUT_INVOICE' THEN pw.id IS NULL ELSE false END) AS missing_source,
              (CASE WHEN ${atOpening} THEN true ELSE ${movementDay}<$2::date END) AS before_opening
            FROM inventory_movements m JOIN unnest($3::int[],$4::int[]) k(product_id,warehouse_id)
              ON k.product_id=m.product_id AND k.warehouse_id=m.warehouse_id
            LEFT JOIN purchase_orders po ON m.reference_type='PURCHASE_ORDER' AND po.id=m.reference_id AND po.shop_id=m.shop_id
            LEFT JOIN sales_orders so ON m.reference_type='SALES_ORDER' AND so.id=m.reference_id AND so.shop_id=m.shop_id
            LEFT JOIN sales_returns sr ON m.reference_type='SALES_RETURN' AND sr.id=m.reference_id AND sr.shop_id=m.shop_id
            LEFT JOIN stock_takes st ON m.reference_type='STOCK_TAKE' AND st.id=m.reference_id AND st.shop_id=m.shop_id
            LEFT JOIN purchases_without_invoice pw ON m.reference_type IN ('PURCHASE_NO_INVOICE','PURCHASE_WITHOUT_INVOICE') AND pw.id=m.reference_id AND pw.shop_id=m.shop_id
            ${openingJoin} WHERE m.shop_id=$1)
            SELECT product_id,warehouse_id,
              COALESCE(SUM(CASE movement_type WHEN 'IN' THEN quantity WHEN 'RETURN' THEN quantity WHEN 'OUT' THEN -quantity ELSE 0 END),0)::int AS net_all,
              COALESCE(SUM(CASE WHEN NOT before_opening THEN CASE movement_type WHEN 'IN' THEN quantity WHEN 'RETURN' THEN quantity WHEN 'OUT' THEN -quantity ELSE 0 END ELSE 0 END),0)::int AS net_after,
              COUNT(*) FILTER(WHERE movement_type NOT IN ('IN','OUT','RETURN') OR movement_type IS NULL OR quantity<0 OR day IS NULL OR missing_source)::int AS invalid,
              md5(string_agg(to_jsonb(m)::text,'|' ORDER BY id)) AS revision
            FROM m GROUP BY product_id,warehouse_id ORDER BY product_id,warehouse_id`, params);
        const lots: Row[] = await manager.query(`SELECT l.*,po.warehouse_id AS source_warehouse,
            to_char((l.lot_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,'YYYY-MM-DD') AS date_key
            FROM inventory_lots l LEFT JOIN purchase_orders po ON po.id=l.purchase_id AND po.shop_id=l.shop_id
            WHERE l.shop_id=$1 AND l.product_id=ANY($2::int[]) ORDER BY l.lot_date,l.id`, [input.shopId, stockKeys.map(s => s.id)]);
        const locations: Row[] = await manager.query(`SELECT product_id,warehouse_id,SUM(quantity)::int AS quantity
            FROM inventory_stocks WHERE shop_id=$1 AND product_id=ANY($2::int[]) GROUP BY product_id,warehouse_id ORDER BY product_id,warehouse_id`, [input.shopId, stockKeys.map(s => s.id)]);
        versions.push(masters, movements, lots, locations);
        for (const s of stockKeys) {
            const master = masters.find(m => m.product_id === s.id && m.warehouse_id === s.warehouse)!;
            const movement = movements.find(m => m.product_id === s.id && m.warehouse_id === s.warehouse);
            const productLots = lots.filter(l => l.product_id === s.id);
            const activeLocations = locations.filter(l => l.product_id === s.id && l.quantity !== 0);
            const inferredWarehouse = activeLocations.length === 1 ? activeLocations[0].warehouse_id : undefined;
            if (master.stock_rows > 1) gap(s.key, 'Có nhiều dòng tồn cho cùng hàng/kho; cần đối chiếu trước khi ghi.');
            if (movement?.invalid) gap(s.key, 'Có chuyển động kho chưa xác định được dấu hoặc ngày nghiệp vụ.');
            if (master.current_quantity !== Number(movement?.net_all ?? 0)) gap(s.key, 'Tồn hiện tại không khớp lịch sử nhập/xuất; cần xác minh mốc tồn đã ghi.');
            const allStock = locations.filter(l => l.product_id === s.id).reduce((n, l) => n + l.quantity, 0);
            const allLots = productLots.reduce((n, l) => n + Number(l.remaining_qty), 0);
            if (allStock !== allLots) gap(s.key, 'Tổng tồn theo kho không khớp số lượng lô giá vốn.');
            const eligible = productLots.filter(l => {
                const opening = adjustments.find(a => a.kind === 'STOCK' && a.product_id === l.product_id && Number(a.source_details?.lotId) === l.id);
                const before = opening ? opening.effective_date <= input.asOf : l.date_key < input.asOf;
                const warehouse = l.source_warehouse ?? opening?.warehouse_id ?? (l.purchase_id ? undefined : inferredWarehouse);
                return Number(l.remaining_qty) > 0 && before && warehouse === s.warehouse;
            });
            rows.push({ key: s.key, kind: 'STOCK', quantity: master.current_quantity - Number(movement?.net_after ?? 0),
                currentQuantity: master.current_quantity, lots: eligible.map(l => ({ id: l.id, remainingQty: Number(l.remaining_qty), costPrice: String(l.cost_price) })) });
            labels[s.key] = `${master.name} · ${master.warehouse_name} · ${master.unit}`;
        }
    }

    await readDebts(manager, input, selected, adjustments, storageReady, rows, labels, gap, versions, sourceLinks, sourceCandidates);
    const orderedRows = rows.sort((a, b) => a.key.localeCompare(b.key, 'en'));
    const revision = createHash('sha256').update(JSON.stringify({ shopId: input.shopId, asOf: input.asOf, keys: selected.map(s => s.key), storageReady,
        rows: orderedRows, labels, rowGaps, versions, sourceLinks })).digest('hex');
    return { shopId: input.shopId, asOf: input.asOf, revision, gaps, rowGaps, rows: orderedRows, labels, storageReady, sourceLinks, sourceCandidates };
}

async function readDebts(manager: EntityManager, input: OpeningSnapshotInput, selected: Selection[], adjustments: Row[], ready: boolean,
    rows: OpeningBalanceSnapshot['rows'], labels: Record<string, string>, gap: (key: string, reason: string) => void, versions: unknown[],
    sourceLinks: OpeningSourceLink[], candidates: OpeningSourceCandidate[]) {
    const accepted = new Set<string>();
    for (const type of ['RECEIVABLE', 'PAYABLE'] as const) {
        const keys = selected.filter(s => s.kind === type);
        if (!keys.length) continue;
        const receivable = type === 'RECEIVABLE', party = receivable ? 'customers' : 'suppliers';
        const table = receivable ? 'receivables' : 'payables', partyColumn = receivable ? 'customer_id' : 'supplier_id';
        const debtColumn = receivable ? 'receivable_id' : 'payable_id';
        const orderColumn = receivable ? 'order_id' : 'purchase_order_id', orderTable = receivable ? 'sales_orders' : 'purchase_orders';
        const parties: Row[] = await manager.query(`SELECT * FROM ${party} WHERE shop_id=$1 AND id=ANY($2::int[]) AND is_active=true ORDER BY id`, [input.shopId, keys.map(k => k.id)]);
        if (parties.length !== keys.length) invalid('Đối tác không thuộc cửa hàng, hoặc đã ngừng hoạt động.');
        const debts: Row[] = await manager.query(`SELECT d.*,o.order_date AS source_date,
            to_char((COALESCE(o.order_date,d.created_at) AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,'YYYY-MM-DD') AS business_day,
            to_char((d.updated_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date,'YYYY-MM-DD') AS changed_day,
            md5(to_jsonb(o)::text) AS source_revision,o.status AS source_status,${receivable ? 'o.return_status' : "'NONE'::text"} AS source_return_status,
            COALESCE(h.after_paid,0)::text AS after_paid,COALESCE(h.total_paid,0)::text AS total_paid,
            h.revision AS payment_revision,h.first_payment_day
            FROM ${table} d LEFT JOIN ${orderTable} o ON o.id=d.${orderColumn} AND o.shop_id=d.shop_id
            LEFT JOIN LATERAL (SELECT SUM(amount) FILTER(WHERE (payment_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date >= $3::date) AS after_paid,
              SUM(amount) AS total_paid,md5(COALESCE(string_agg(to_jsonb(h)::text,'|' ORDER BY h.id),'')) AS revision,
              to_char(MIN((payment_date AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Ho_Chi_Minh')::date),'YYYY-MM-DD') AS first_payment_day
              FROM debt_payment_history h WHERE h.shop_id=d.shop_id AND h.${debtColumn}=d.id) h ON true
            WHERE d.shop_id=$1 AND d.${partyColumn}=ANY($2::int[]) ORDER BY d.id`, [input.shopId, keys.map(k => k.id), input.asOf]);
        versions.push(parties, debts);
        for (const key of keys) {
            let total = 0;
            const sourceDebts: Array<{ id: number; remaining: string; availableToAdjust: string }> = [];
            for (const debt of debts.filter(d => d[partyColumn] === key.id)) {
                const ownAdjustments = ready ? adjustments.filter(a => Number(a[debtColumn]) === debt.id && a.kind === type) : [];
                let initial = ownAdjustments.find(a => a.effect_mode === 'LINKED_DOCUMENT');
                const source = sourceLinks.find(link => link.key === key.key && link.debtId === debt.id);
                const needsSource = !initial && !debt[orderColumn] && debt.business_day >= input.asOf && debt.status !== 'CANCELLED';
                if (source) {
                    if (!needsSource || source.businessDate > debt.business_day || openingAmountCents(debt.amount) <= 0) {
                        invalid('Chỉ xác minh khoản nợ nhập tay chưa có nguồn; ngày thực tế không sau ngày nhập vào ứng dụng.');
                    }
                    if ((debt.first_payment_day && source.businessDate > debt.first_payment_day)
                        || ownAdjustments.some(a => a.effect_mode === 'BALANCE_OFFSET' && source.businessDate > a.effective_date)) {
                        invalid('Ngày phát sinh không thể sau lần thanh toán hoặc điều chỉnh đã ghi.');
                    }
                    if (source.businessDate < input.asOf && openingAmountCents(debt.total_paid) !== openingAmountCents(debt.paid_amount)) {
                        invalid('Lịch sử thanh toán của khoản nợ chưa đủ để đối chiếu tại ngày cũ.');
                    }
                    initial = { effective_date: source.businessDate, source_details: { existingDocument: true } };
                    accepted.add(`${key.key}:${debt.id}`);
                }
                if (needsSource) candidates.push({ key: key.key, debtId: debt.id, amount: String(debt.amount), paidAmount: String(debt.paid_amount),
                    recordedDate: debt.business_day, ...(source ? { businessDate: source.businessDate, reference: source.reference } : {}) });
                const existing = initial ? (initial.source_details?.existingDocument
                    ? initial.effective_date < input.asOf : initial.effective_date <= input.asOf) : debt.business_day < input.asOf;
                if (needsSource && !source) gap(key.key, 'Có nợ nhập tay sau mốc nhưng chưa biết ngày phát sinh cũ; cần liên kết nguồn để tránh khai trùng.');
                if (!existing) continue;
                if (debt[orderColumn] && !debt.source_date) gap(key.key, 'Thiếu chứng từ nguồn để xác định ngày phát sinh nợ.');
                if (debt.source_status === 'CANCELLED' && debt.status !== 'CANCELLED') gap(key.key, 'Trạng thái nợ không khớp chứng từ đã hủy.');
                if (debt.source_return_status && debt.source_return_status !== 'NONE' && debt.changed_day >= input.asOf) gap(key.key, 'Có trả hàng thay đổi số nợ sau mốc; cần phục dựng giá trị trước trả hàng.');
                if (debt.status === 'CANCELLED') {
                    if (debt.changed_day >= input.asOf) gap(key.key, 'Khoản nợ đã hủy sau mốc; cần phục dựng số nợ trước khi hủy.');
                    continue;
                }
                const original = openingAmountCents(debt.amount), paid = openingAmountCents(debt.paid_amount), afterPaid = openingAmountCents(debt.after_paid);
                if (paid > original || afterPaid > paid || openingAmountCents(debt.total_paid) > paid) gap(key.key, 'Số tiền trả và lịch sử thanh toán không khớp.');
                const beforeOffset = openingSumCents(ownAdjustments.filter(a => a.effect_mode === 'BALANCE_OFFSET' && a.effective_date <= input.asOf).map(a => openingAmountCents(a.amount_delta, true)));
                const currentOffset = openingSumCents(ownAdjustments.filter(a => a.effect_mode === 'BALANCE_OFFSET').map(a => openingAmountCents(a.amount_delta, true)));
                const before = openingSumCents([original, -paid, afterPaid, beforeOffset]), current = openingSumCents([original, -paid, currentOffset]);
                if (before < 0 || current < 0) gap(key.key, 'Điều chỉnh công nợ vượt số còn nợ; không tự coi là bằng 0.');
                total = openingSumCents([total, Math.max(0, before)]);
                sourceDebts.push({ id: debt.id, remaining: openingCentsText(Math.max(0, before)), availableToAdjust: openingCentsText(Math.max(0, Math.min(before, current))) });
            }
            rows.push({ key: key.key, kind: type, amount: openingCentsText(total), debts: sourceDebts });
            labels[key.key] = String(parties.find(p => p.id === key.id)!.name);
        }
    }
    if (accepted.size !== sourceLinks.length) invalid('Nguồn công nợ không thuộc đúng đối tượng, cửa hàng hoặc không còn cần xác minh.');
}
