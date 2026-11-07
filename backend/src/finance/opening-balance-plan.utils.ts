import { createHash } from 'crypto';
import { vietnamDateKey } from './finance-period.utils';

// Calculation contract for the opening-balance feature. Not a write endpoint.
// The snapshot must be obtained/validated by the server in one consistent read;
// it must never be accepted from a client's request as the recorded balance.
type Kind = 'CASH' | 'BANK' | 'STOCK' | 'RECEIVABLE' | 'PAYABLE';
type Debt = { id: number; remaining: string; availableToAdjust: string };
type Lot = { id: number; remainingQty: number; costPrice: string };
export type OpeningSourceLink = { key: string; debtId: number; businessDate: string; reference: string };
export type OpeningBalanceSnapshot = {
    shopId: number;
    asOf: string; // Opening of this Vietnam business day, before its transactions.
    revision: string;
    gaps: string[]; // Historical reconstruction/closing-anchor issues block commit.
    rowGaps?: Record<string, string[]>;
    sourceLinks?: OpeningSourceLink[];
    rows: Array<{
        key: string;
        kind: Kind;
        amount?: string;
        quantity?: number;
        currentQuantity?: number;
        lots?: Lot[]; // Eligible, currently available lots in server FIFO order.
        debts?: Debt[];
    }>;
};
export type OpeningBalanceActual = {
    key: string;
    actual: string | number;
    unitCost?: string | number; // Only for stock that is being added.
    dueDate?: string; // Explicit payment deadline for a newly recorded debt.
    allocations?: Array<{ debtId: number; amount: string | number }>;
};
export type OpeningBalanceRequest = {
    shopId: number;
    asOf: string;
    expectedRevision: string;
    rows: OpeningBalanceActual[];
    sourceLinks?: OpeningSourceLink[];
};
export class OpeningBalancePlanError extends Error {}
const fail = (message: string): never => { throw new OpeningBalancePlanError(message); };
// JournalLine uses numeric(15,2), narrower than the cash ledger's numeric(18,2).
const maximumPostingCents = 999999999999999n;
const safe = (value: bigint): number => {
    if (value > maximumPostingCents || value < -maximumPostingCents) {
        fail('Số tiền vượt giới hạn ghi sổ của hệ thống.');
    }
    return Number(value);
};
const add = (a: number, b: number) => safe(BigInt(a) + BigInt(b));
const cents = (value: unknown, signed = false): number => {
    const text = String(value);
    if (!(signed ? /^-?\d+(?:\.\d{1,2})?$/ : /^\d+(?:\.\d{1,2})?$/).test(text)) {
        fail('Nhập số tiền không âm, tối đa hai chữ số thập phân và không phân nhóm.');
    }
    const [whole, decimal = ''] = text.replace(/^-/, '').split('.');
    const amount = BigInt(whole) * 100n + BigInt(decimal.padEnd(2, '0'));
    return safe(text.startsWith('-') ? -amount : amount);
};
const quantity = (value: unknown, signed = false): number => {
    if (typeof value !== 'number' || !Number.isSafeInteger(value) || Math.abs(value) > 2147483647 || (!signed && value < 0)) {
        fail('Số lượng phải là số nguyên trong giới hạn cho phép.');
    }
    return value as number;
};
const validDate = (value: string) => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
    const date = new Date(`${value}T00:00:00Z`);
    return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
};

export function normalizeOpeningSourceLinks(value: unknown, keys: readonly string[], now = new Date()): OpeningSourceLink[] {
    if (value === undefined) return [];
    if (!Array.isArray(value) || value.length > 500) fail('Mỗi lượt chỉ xác minh tối đa 500 khoản nợ.');
    const seen = new Set<string>();
    return (value as unknown[]).map(item => {
        if (!item || typeof item !== 'object' || Array.isArray(item)
            || Object.keys(item).some(key => !['key', 'debtId', 'businessDate', 'reference'].includes(key))) {
            fail('Thông tin nguồn công nợ không hợp lệ.');
        }
        const source = item as OpeningSourceLink;
        const identity = `${source.key}:${source.debtId}`;
        if (typeof source.key !== 'string' || !/^(customer|supplier):[1-9]\d*$/.test(source.key)
            || !keys.includes(source.key) || !Number.isInteger(source.debtId) || source.debtId < 1 || source.debtId > 2147483647
            || seen.has(identity)) fail('Chọn đúng khoản nợ của đối tượng đang đối chiếu, không trùng.');
        if (typeof source.businessDate !== 'string' || !validDate(source.businessDate) || source.businessDate > vietnamDateKey(now)) {
            fail('Ngày phát sinh thực tế của khoản nợ phải hợp lệ và không sau hôm nay.');
        }
        if (typeof source.reference !== 'string' || source.reference.trim().length < 3 || source.reference.trim().length > 300) {
            fail('Ghi nguồn đối chiếu công nợ từ 3 đến 300 ký tự, ví dụ sổ hoặc chứng từ cũ.');
        }
        seen.add(identity);
        return { key: source.key, debtId: source.debtId, businessDate: source.businessDate, reference: source.reference.trim() };
    }).sort((a, b) => a.key.localeCompare(b.key, 'en') || a.debtId - b.debtId);
}

export function buildOpeningBalancePlan(
    snapshot: OpeningBalanceSnapshot,
    request: OpeningBalanceRequest,
    now = new Date(),
) {
    if (!Number.isSafeInteger(snapshot.shopId) || snapshot.shopId <= 0
        || request.shopId !== snapshot.shopId || request.asOf !== snapshot.asOf) {
        fail('Cửa hàng hoặc ngày đối chiếu đã thay đổi.');
    }
    if (!validDate(request.asOf) || request.asOf > vietnamDateKey(now)) {
        fail('Ngày đối chiếu phải là hôm nay hoặc một ngày hợp lệ trong quá khứ.');
    }
    if (!/^[a-f0-9]{64}$/.test(snapshot.revision) || request.expectedRevision !== snapshot.revision) {
        fail('Dữ liệu đã thay đổi; cần đối chiếu và xem trước lại.');
    }
    if (!Array.isArray(request.rows) || request.rows.length < 1 || request.rows.length > 500) {
        fail('Mỗi lượt đối chiếu cần từ 1 đến 500 dòng.');
    }
    const recorded = new Map(snapshot.rows.map(row => [row.key, row]));
    if (recorded.size !== snapshot.rows.length) fail('Dữ liệu đối chiếu có dòng bị trùng.');
    const seen = new Set<string>();
    const sourceLinks = normalizeOpeningSourceLinks(request.sourceLinks, request.rows.map(row => row?.key), now);
    if (JSON.stringify(sourceLinks) !== JSON.stringify(snapshot.sourceLinks ?? [])) fail('Nguồn công nợ đã đổi; cần đọc lại số liệu.');
    const blockers = [...snapshot.gaps];
    const totals = { cashDeltaCents: 0, bankDeltaCents: 0, receivableDeltaCents: 0,
        payableDeltaCents: 0, stockValueDeltaCents: 0 };
    const rows = request.rows.map(actual => {
        if (!actual || typeof actual.key !== 'string' || seen.has(actual.key)) {
            fail('Một đối tượng chỉ được đối chiếu một lần trong cùng lượt.');
        }
        seen.add(actual.key);
        const before = recorded.get(actual.key);
        if (!before) fail('Đối tượng không thuộc dữ liệu đã đối chiếu của cửa hàng.');
        const baseline = before!;
        if (!['CASH', 'BANK', 'STOCK', 'RECEIVABLE', 'PAYABLE'].includes(baseline.kind)) {
            fail('Nhóm số liệu ban đầu không hợp lệ.');
        }
        if (baseline.kind === 'STOCK') {
            if (actual.dueDate !== undefined) fail('Chỉ khoản nợ bổ sung mới có hạn thanh toán.');
            if (actual.allocations !== undefined) fail('Không phân bổ công nợ cho hàng hóa.');
            const previous = quantity(baseline.quantity, true);
            const after = quantity(typeof actual.actual === 'string' && /^\d+$/.test(actual.actual)
                ? Number(actual.actual) : actual.actual);
            const delta = add(after, -previous);
            if (Math.abs(delta) > 2147483647) fail('Chênh lệch số lượng vượt giới hạn một lần ghi kho.');
            const current = quantity(baseline.currentQuantity, true);
            if (add(current, delta) > 2147483647) fail('Tồn hiện tại sau đối chiếu vượt giới hạn ghi kho.');
            if (current < 0) blockers.push(`${actual.key}: Tồn hiện tại đang âm; cần đối chiếu lịch sử và giá vốn lô trước khi ghi.`);
            if (add(current, delta) < 0) blockers.push(`${actual.key}: Lịch sử sau ngày đối chiếu làm tồn hiện tại bị âm.`);
            let valueDeltaCents = 0;
            const lotAllocations: Array<{ lotId: number; quantity: number; valueCents: number }> = [];
            if (delta > 0) {
                if (actual.unitCost === undefined) fail('Hàng bổ sung phải có giá vốn, kể cả giá vốn bằng 0.');
                valueDeltaCents = safe(BigInt(delta) * BigInt(cents(actual.unitCost)));
            } else {
                if (actual.unitCost !== undefined) fail('Giá vốn chỉ dùng khi bổ sung số lượng; không tự đổi giá vốn lô cũ.');
                let remaining = -delta;
                const lots = baseline.lots ?? [];
                const lotIds = new Set<number>();
                for (const lot of lots) {
                    if (!Number.isSafeInteger(lot.id) || lot.id <= 0 || lotIds.has(lot.id)) fail('Dữ liệu lô không hợp lệ.');
                    lotIds.add(lot.id);
                    const available = quantity(lot.remainingQty);
                    const cost = cents(lot.costPrice);
                    const taken = Math.min(remaining, available);
                    if (taken > 0) {
                        const valueCents = safe(BigInt(taken) * BigInt(cost));
                        lotAllocations.push({ lotId: lot.id, quantity: taken, valueCents });
                        valueDeltaCents = add(valueDeltaCents, -valueCents);
                        remaining -= taken;
                    }
                }
                if (remaining > 0) blockers.push(`${actual.key}: Không đủ lô hợp lệ để giảm tồn và xác định giá vốn.`);
            }
            totals.stockValueDeltaCents = add(totals.stockValueDeltaCents, valueDeltaCents);
            return { key: actual.key, kind: baseline.kind, before: previous, actual: after,
                delta, valueDeltaCents, lotAllocations, debtAllocations: [] };
        }
        if (actual.unitCost !== undefined) fail('Chỉ hàng hóa bổ sung mới có giá vốn.');
        const previous = cents(baseline.amount, baseline.kind === 'CASH' || baseline.kind === 'BANK');
        const after = cents(actual.actual);
        const delta = add(after, -previous);
        const debtAllocations: Array<{ debtId: number; amountCents: number }> = [];
        const isDebt = baseline.kind === 'RECEIVABLE' || baseline.kind === 'PAYABLE';
        if (isDebt && delta > 0) {
            if (typeof actual.dueDate !== 'string' || !validDate(actual.dueDate)) {
                fail('Khoản nợ bổ sung cần hạn thanh toán hợp lệ; không tự lấy ngày đối chiếu làm hạn trả.');
            }
        } else if (actual.dueDate !== undefined) fail('Chỉ khoản nợ bổ sung mới có hạn thanh toán.');
        if (actual.allocations !== undefined && (!isDebt || delta >= 0)) {
            fail('Chỉ phân bổ khoản nợ khi cần giảm số còn nợ.');
        }
        if (isDebt && delta < 0) {
            const debts = baseline.debts ?? [];
            const debtMap = new Map(debts.map(debt => [debt.id, debt]));
            if (debtMap.size !== debts.length) fail('Dữ liệu chứng từ công nợ bị trùng.');
            let sum = 0;
            const allocated = new Set<number>();
            for (const allocation of actual.allocations ?? []) {
                const debt = debtMap.get(allocation.debtId);
                if (!debt || allocated.has(allocation.debtId)) fail('Phân bổ phải trỏ tới khoản nợ thuộc đúng đối tượng, không trùng.');
                allocated.add(allocation.debtId);
                const amountCents = cents(allocation.amount);
                if (amountCents <= 0 || amountCents > cents(debt!.remaining)
                    || amountCents > cents(debt!.availableToAdjust)) {
                    fail('Số giảm vượt khoản nợ còn được phép điều chỉnh.');
                }
                sum = add(sum, amountCents);
                debtAllocations.push({ debtId: allocation.debtId, amountCents });
            }
            if (sum !== -delta) blockers.push(`${actual.key}: Chọn đúng khoản nợ để phân bổ đủ số cần giảm; không ghi thành đã thu hoặc đã trả.`);
        }
        const key = baseline.kind === 'CASH' ? 'cashDeltaCents' : baseline.kind === 'BANK'
            ? 'bankDeltaCents' : baseline.kind === 'RECEIVABLE' ? 'receivableDeltaCents' : 'payableDeltaCents';
        totals[key] = add(totals[key], delta);
        return { key: actual.key, kind: baseline.kind, before: previous, actual: after,
            delta, ...(isDebt && delta > 0 ? { dueDate: actual.dueDate! } : {}),
            valueDeltaCents: 0, lotAllocations: [], debtAllocations: debtAllocations.sort((a, b) => a.debtId - b.debtId) };
    }).sort((a, b) => a.key.localeCompare(b.key, 'en'));
    const adjustments = rows.filter(row => row.delta !== 0).length;
    for (const row of rows) {
        if (row.delta !== 0 || sourceLinks.some(link => link.key === row.key)) blockers.push(...(snapshot.rowGaps?.[row.key] ?? []).map(gap => `${row.key}: ${gap}`));
    }
    const netAssetDeltaCents = safe(BigInt(totals.cashDeltaCents) + BigInt(totals.bankDeltaCents)
        + BigInt(totals.stockValueDeltaCents) + BigInt(totals.receivableDeltaCents) - BigInt(totals.payableDeltaCents));
    const payload = { shopId: snapshot.shopId, asOf: snapshot.asOf, revision: snapshot.revision,
        rows, totals: { ...totals, netAssetDeltaCents }, blockers: [...new Set(blockers)].sort(),
        adjustmentCount: adjustments, sourceLinks, sourceLinkCount: sourceLinks.length, revenueDeltaCents: 0, periodCashFlowDeltaCents: 0 };
    return { ...payload, canCommit: (adjustments > 0 || sourceLinks.length > 0) && payload.blockers.length === 0,
        planHash: createHash('sha256').update(JSON.stringify(payload)).digest('hex') };
}

export const openingAmountCents = cents;
export const openingSumCents = (values: number[]): number => safe(values.reduce((sum, value) => sum + BigInt(value), 0n));
export function openingCentsText(value: number): string {
    const validated = BigInt(safe(BigInt(value)));
    const absolute = validated < 0n ? -validated : validated;
    return `${validated < 0n ? '-' : ''}${absolute / 100n}.${String(absolute % 100n).padStart(2, '0')}`;
}
