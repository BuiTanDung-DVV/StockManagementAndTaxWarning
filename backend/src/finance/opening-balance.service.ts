import { createHash } from 'crypto';
import type { DataSource, EntityManager } from 'typeorm';
import { lockShopMutation } from '../utils/shop-mutation-lock';
import { buildOpeningBalancePlan, OpeningBalanceActual, OpeningBalancePlanError, OpeningBalanceRequest,
    normalizeOpeningSourceLinks, openingAmountCents, openingCentsText, openingSumCents } from './opening-balance-plan.utils';
import { normalizeOpeningSnapshotInput, OpeningSnapshotInput, readOpeningBalanceSnapshot } from './opening-balance-snapshot.repository';

export type OpeningBalanceActor = { id: number; authVersion: number };
export type OpeningBalanceCommit = OpeningBalanceRequest & { operationId: string; expectedPlanHash: string };
type Plan = ReturnType<typeof buildOpeningBalancePlan>;
type PlanRow = Plan['rows'][number];
type Receipt = { batchId: number; operationId: string; actorId: number; committedAt: string; plan: Plan };
export class OpeningBalanceServiceError extends Error {
    constructor(public readonly code: string, message: string, public readonly status = 400,
        public readonly blockers: string[] = []) { super(message); }
}
const reject = (code: string, message: string, status = 400): never => {
    throw new OpeningBalanceServiceError(code, message, status);
};
const hash = (value: unknown) => createHash('sha256').update(JSON.stringify(value)).digest('hex');
function object(value: unknown, fields: string[]): asserts value is Record<string, unknown> {
    if (!value || typeof value !== 'object' || Array.isArray(value)
        || Object.keys(value).some(key => !fields.includes(key))) reject('INVALID_INPUT', 'Dữ liệu yêu cầu không hợp lệ.');
}
function money(value: unknown): string {
    if (typeof value !== 'string' && typeof value !== 'number') reject('INVALID_INPUT', 'Số tiền phải là số hoặc chuỗi số.');
    return openingCentsText(openingAmountCents(value));
}
function operation(value: unknown): asserts value is string {
    if (typeof value !== 'string' || !/^[a-f0-9]{32,64}$/.test(value)) reject('INVALID_OPERATION', 'Mã lượt ghi không hợp lệ.');
}

/** Application service for the opening-balance workflow.
 * The complete UI/readers and approved storage must be integrated before release.
 */
export class OpeningBalanceService {
    constructor(private readonly source: DataSource, private readonly clock = () => new Date()) {}

    async snapshot(actor: OpeningBalanceActor, input: OpeningSnapshotInput) {
        const now = this.clock();
        normalizeOpeningSnapshotInput(input, now);
        return this.source.transaction('REPEATABLE READ', async manager => {
            await this.configure(manager, true);
            await this.assertOwner(manager, actor, input.shopId, false);
            return readOpeningBalanceSnapshot(manager, input, now);
        });
    }

    async preview(actor: OpeningBalanceActor, input: OpeningBalanceRequest) {
        const now = this.clock(), request = this.normalize(input, now);
        return this.source.transaction('REPEATABLE READ', async manager => {
            await this.configure(manager, true);
            await this.assertOwner(manager, actor, request.shopId, false);
            const snapshot = await readOpeningBalanceSnapshot(manager, this.selection(request), now);
            if (snapshot.revision !== request.expectedRevision) reject('SNAPSHOT_CHANGED', 'Dữ liệu đã thay đổi; cần đối chiếu và xem trước lại.', 409);
            return { plan: buildOpeningBalancePlan(snapshot, request, now), labels: snapshot.labels };
        });
    }

    async status(actor: OpeningBalanceActor, shopId: number, operationId: string) {
        operation(operationId);
        return this.source.transaction('REPEATABLE READ', async manager => {
            await this.configure(manager, true);
            await this.assertOwner(manager, actor, shopId, false);
            await this.assertStorage(manager);
            return this.receipt(manager, actor, shopId, operationId);
        });
    }

    async history(actor: OpeningBalanceActor, shopId: number, beforeId?: number) {
        if (beforeId !== undefined && (!Number.isInteger(beforeId) || beforeId < 1 || beforeId > 2147483647)) {
            reject('INVALID_CURSOR', 'Mốc lịch sử không hợp lệ.');
        }
        return this.source.transaction('REPEATABLE READ', async manager => {
            await this.configure(manager, true);
            await this.assertOwner(manager, actor, shopId, false);
            await this.assertStorage(manager);
            const rows: Array<{ id: number; operation_id: string; as_of: string; created_at: Date;
                totals: Plan['totals']; adjustment_count: number; source_link_count: number | null }> = await manager.query(`SELECT id,operation_id,to_char(as_of,'YYYY-MM-DD') AS as_of,
                created_at,result->'plan'->'totals' AS totals,
                result->'plan'->'adjustmentCount' AS adjustment_count,result->'plan'->'sourceLinkCount' AS source_link_count
                FROM opening_balance_batches WHERE shop_id=$1 AND actor_id=$2
                AND ($3::integer IS NULL OR id<$3) ORDER BY id DESC LIMIT 21`, [shopId, actor.id, beforeId ?? null]);
            return { items: rows.slice(0, 20).map(row => ({ batchId: row.id, operationId: row.operation_id,
                asOf: row.as_of, committedAt: row.created_at, totals: row.totals, adjustmentCount: row.adjustment_count, sourceLinkCount: row.source_link_count ?? 0 })),
            nextBeforeId: rows.length > 20 ? rows[19].id : null };
        });
    }

    async commit(actor: OpeningBalanceActor, input: OpeningBalanceCommit) {
        const now = this.clock();
        object(input, ['shopId', 'asOf', 'expectedRevision', 'rows', 'sourceLinks', 'operationId', 'expectedPlanHash']);
        operation(input.operationId);
        if (typeof input.expectedPlanHash !== 'string' || !/^[a-f0-9]{64}$/.test(input.expectedPlanHash)) {
            reject('INVALID_PLAN', 'Cần xem trước đúng lượt đối chiếu trước khi xác nhận.');
        }
        const request = this.normalize({ shopId: input.shopId, asOf: input.asOf,
            expectedRevision: input.expectedRevision, rows: input.rows, sourceLinks: input.sourceLinks }, now);
        const requestHash = hash({ ...request, expectedPlanHash: input.expectedPlanHash });
        for (let attempt = 0; ; attempt++) {
            try {
                return await this.source.transaction('SERIALIZABLE', async manager => {
                    await this.configure(manager, false);
                    await lockShopMutation(manager, request.shopId);
                    await this.assertOwner(manager, actor, request.shopId, true);
                    await this.assertStorage(manager);
                    // Look up the receipt first: our own successful write changes the revision.
                    const saved = await this.receipt(manager, actor, request.shopId, input.operationId, requestHash);
                    if (saved) return { ...saved, replayed: true };
                    await this.lockObjects(manager, request);
                    const snapshot = await readOpeningBalanceSnapshot(manager, this.selection(request), now);
                    if (snapshot.revision !== request.expectedRevision) reject('SNAPSHOT_CHANGED', 'Dữ liệu đã thay đổi; cần đối chiếu và xem trước lại.', 409);
                    const plan = buildOpeningBalancePlan(snapshot, request, now);
                    if (plan.planHash !== input.expectedPlanHash) reject('PLAN_CHANGED', 'Kết quả đối chiếu đã đổi; hãy xem trước lại.', 409);
                    if (!plan.canCommit) throw new OpeningBalanceServiceError('PLAN_BLOCKED',
                        (plan.adjustmentCount || plan.sourceLinkCount) ? 'Cần xử lý các dòng chưa đủ căn cứ trước khi ghi.' : 'Không có chênh lệch cần ghi.', 409, plan.blockers);
                    const [batch] = await manager.query(`INSERT INTO opening_balance_batches
                        (shop_id,operation_id,actor_id,as_of,request_hash,plan_hash,snapshot_revision,result)
                        VALUES($1,$2,$3,$4,$5,$6,$7,'{}') RETURNING id`,
                    [request.shopId, input.operationId, actor.id, request.asOf, requestHash, plan.planHash, snapshot.revision]);
                    for (const source of plan.sourceLinks) {
                        const receivable = source.key.startsWith('customer:');
                        const table = receivable ? 'receivables' : 'payables';
                        const [debt] = await manager.query(`SELECT amount::text AS amount FROM ${table} WHERE shop_id=$1 AND id=$2`, [request.shopId, source.debtId]);
                        await this.adjustment(manager, request, plan.rows.find(row => row.key === source.key)!, Number(batch.id),
                            'LINKED_DOCUMENT', openingAmountCents(debt.amount), 0,
                            receivable ? { receivable: source.debtId } : { payable: source.debtId },
                            { existingDocument: true, businessDate: source.businessDate, reference: source.reference });
                    }
                    for (const row of plan.rows.filter(r => r.delta !== 0)) {
                        await this.applyRow(manager, request, row, Number(batch.id), actor.id);
                    }
                    await this.postJournal(manager, plan, Number(batch.id));
                    const result: Receipt = { batchId: Number(batch.id), operationId: input.operationId,
                        actorId: actor.id, committedAt: this.clock().toISOString(), plan };
                    await manager.query('UPDATE opening_balance_batches SET result=$1::jsonb WHERE shop_id=$2 AND id=$3',
                        [JSON.stringify(result), request.shopId, result.batchId]);
                    return { ...result, replayed: false };
                });
            } catch (error) {
                const { code, constraint } = error as { code?: string; constraint?: string };
                // Restart the entire transaction, never retry an isolated SQL statement.
                const receiptRace = code === '23505' && constraint === 'opening_balance_batches_shop_id_operation_id_key';
                if (attempt < 2 && (code === '40001' || code === '40P01' || receiptRace)) continue;
                if (code === '40001' || code === '40P01' || code === '55P03' || code === '57014' || receiptRace) {
                    reject('RETRY_SAME_OPERATION', 'Dữ liệu đang được xử lý. Tra kết quả hoặc thử lại cùng mã lượt ghi.', 409);
                }
                throw error;
            }
        }
    }

    private normalize(input: OpeningBalanceRequest, now: Date): OpeningBalanceRequest {
        object(input, ['shopId', 'asOf', 'expectedRevision', 'rows', 'sourceLinks']);
        if (!Array.isArray(input.rows)) reject('INVALID_INPUT', 'Cần chọn các dòng đối chiếu.');
        normalizeOpeningSnapshotInput(this.selection(input), now);
        if (typeof input.expectedRevision !== 'string' || !/^[a-f0-9]{64}$/.test(input.expectedRevision)) {
            reject('INVALID_REVISION', 'Cần đọc lại số liệu đối chiếu.');
        }
        const rows = input.rows.map(row => {
            object(row, ['key', 'actual', 'unitCost', 'dueDate', 'allocations']);
            const result: OpeningBalanceActual = { key: row.key, actual: row.actual };
            if (row.key.startsWith('stock:')) {
                if ((typeof row.actual !== 'string' || !/^\d+$/.test(row.actual))
                    && (typeof row.actual !== 'number' || !Number.isInteger(row.actual))) reject('INVALID_INPUT', 'Số lượng phải là số nguyên không âm.');
                result.actual = Number(row.actual);
                if (!Number.isInteger(result.actual) || result.actual < 0 || result.actual > 2147483647) reject('INVALID_INPUT', 'Số lượng vượt giới hạn.');
            } else result.actual = money(row.actual);
            if (row.unitCost !== undefined) result.unitCost = money(row.unitCost);
            if (row.dueDate !== undefined) {
                if (typeof row.dueDate !== 'string') reject('INVALID_INPUT', 'Hạn trả không hợp lệ.');
                result.dueDate = row.dueDate;
            }
            if (row.allocations !== undefined) {
                if (!Array.isArray(row.allocations) || row.allocations.length > 500) reject('INVALID_INPUT', 'Phân bổ công nợ không hợp lệ.');
                result.allocations = row.allocations.map(allocation => {
                    object(allocation, ['debtId', 'amount']);
                    if (!Number.isInteger(allocation.debtId) || allocation.debtId <= 0 || allocation.debtId > 2147483647) reject('INVALID_INPUT', 'Mã khoản nợ không hợp lệ.');
                    return { debtId: allocation.debtId, amount: money(allocation.amount) };
                }).sort((a, b) => a.debtId - b.debtId);
            }
            return result;
        }).sort((a, b) => a.key.localeCompare(b.key, 'en'));
        return { shopId: input.shopId, asOf: input.asOf, expectedRevision: input.expectedRevision, rows,
            sourceLinks: normalizeOpeningSourceLinks(input.sourceLinks, rows.map(row => row.key), now) };
    }

    private selection(request: OpeningBalanceRequest): OpeningSnapshotInput {
        return { shopId: request.shopId, asOf: request.asOf,
            keys: Array.isArray(request.rows) ? request.rows.map(r => r?.key) : [], sourceLinks: request.sourceLinks };
    }

    private async configure(manager: EntityManager, readOnly: boolean) {
        if (readOnly) await manager.query('SET TRANSACTION READ ONLY');
        await manager.query("SET LOCAL statement_timeout = '10000ms'");
        await manager.query("SET LOCAL lock_timeout = '4000ms'");
        await manager.query("SET LOCAL TIME ZONE 'UTC'");
    }

    private async assertOwner(manager: EntityManager, actor: OpeningBalanceActor, shopId: number, lock: boolean) {
        if (!actor || !Number.isInteger(actor.id) || actor.id < 1 || actor.id > 2147483647
            || !Number.isInteger(actor.authVersion) || actor.authVersion < 0
            || !Number.isInteger(shopId) || shopId < 1 || shopId > 2147483647) reject('INVALID_SCOPE', 'Phiên hoặc cửa hàng không hợp lệ.', 403);
        const rows = await manager.query(`SELECT m.id FROM shop_members m JOIN users u ON u.id=m.user_id
            WHERE m.shop_id=$1 AND m.user_id=$2 AND m.member_type='OWNER' AND m.status='ACTIVE'
            AND m.is_active=true AND u.is_active=true AND u.auth_version=$3 ${lock ? 'FOR SHARE OF m,u' : ''}`,
        [shopId, actor.id, actor.authVersion]);
        if (rows.length !== 1) reject('OWNER_REQUIRED', 'Chỉ chủ cửa hàng có phiên còn hiệu lực được đối chiếu số liệu ban đầu.', 403);
    }

    private async assertStorage(manager: EntityManager) {
        const [storage] = await manager.query(`SELECT to_regclass('public.opening_balance_batches') IS NOT NULL
            AND to_regclass('public.opening_balance_adjustments') IS NOT NULL AS ready`);
        if (!storage.ready) reject('STORAGE_NOT_READY', 'Chức năng số dư ban đầu chưa được triển khai đủ.', 503);
    }

    private async receipt(manager: EntityManager, actor: OpeningBalanceActor, shopId: number, operationId: string, requestHash?: string): Promise<Receipt | null> {
        const [saved] = await manager.query('SELECT actor_id,request_hash,result FROM opening_balance_batches WHERE shop_id=$1 AND operation_id=$2', [shopId, operationId]);
        if (!saved) return null;
        if (saved.actor_id !== actor.id || (requestHash !== undefined && saved.request_hash !== requestHash)) {
            reject('OPERATION_CONFLICT', 'Mã lượt ghi đã dùng cho yêu cầu khác. Không gửi lại với dữ liệu thay đổi.', 409);
        }
        if (!saved.result?.batchId || saved.result.operationId !== operationId) reject('INVALID_RECEIPT', 'Biên nhận chưa hợp lệ; không tự ghi lại.', 409);
        return saved.result as Receipt;
    }

    private async lockObjects(manager: EntityManager, request: OpeningBalanceRequest) {
        const selected = normalizeOpeningSnapshotInput(this.selection(request), this.clock());
        const products = [...new Set(selected.filter(r => r.kind === 'STOCK').map(r => r.id!))];
        const warehouses = [...new Set(selected.filter(r => r.kind === 'STOCK').map(r => r.warehouse!))];
        if (products.length) {
            await manager.query('SELECT id FROM products WHERE shop_id=$1 AND id=ANY($2::int[]) ORDER BY id FOR UPDATE', [request.shopId, products]);
            await manager.query('SELECT id FROM warehouses WHERE shop_id=$1 AND id=ANY($2::int[]) ORDER BY id FOR SHARE', [request.shopId, warehouses]);
            for (const table of ['inventory_stocks', 'inventory_lots']) await manager.query(`SELECT id FROM ${table}
                WHERE shop_id=$1 AND product_id=ANY($2::int[]) ORDER BY id FOR UPDATE`, [request.shopId, products]);
        }
        for (const receivable of [true, false]) {
            const ids = selected.filter(r => r.kind === (receivable ? 'RECEIVABLE' : 'PAYABLE')).map(r => r.id!);
            if (!ids.length) continue;
            const party = receivable ? 'customers' : 'suppliers', debt = receivable ? 'receivables' : 'payables';
            const column = receivable ? 'customer_id' : 'supplier_id';
            await manager.query(`SELECT id FROM ${party} WHERE shop_id=$1 AND id=ANY($2::int[]) ORDER BY id FOR UPDATE`, [request.shopId, ids]);
            await manager.query(`SELECT id FROM ${debt} WHERE shop_id=$1 AND ${column}=ANY($2::int[]) ORDER BY id FOR UPDATE`, [request.shopId, ids]);
        }
    }

    private async adjustment(manager: EntityManager, request: OpeningBalanceRequest, row: PlanRow, batchId: number,
        mode: string, amountCents: number, quantity: number, refs: { product?: number; warehouse?: number; receivable?: number; payable?: number }, details: unknown) {
        await manager.query(`INSERT INTO opening_balance_adjustments
            (shop_id,batch_id,object_key,kind,effect_mode,amount_delta,quantity_delta,product_id,warehouse_id,receivable_id,payable_id,source_details)
            VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::jsonb)`, [request.shopId, batchId, row.key, row.kind, mode,
            openingCentsText(amountCents), quantity, refs.product ?? null, refs.warehouse ?? null,
            refs.receivable ?? null, refs.payable ?? null, JSON.stringify(details)]);
    }

    private async applyRow(manager: EntityManager, request: OpeningBalanceRequest, row: PlanRow, batchId: number, actorId: number) {
        if (row.kind === 'CASH' || row.kind === 'BANK') {
            await this.adjustment(manager, request, row, batchId, 'BALANCE_OFFSET', row.delta, 0, {}, {});
        } else if (row.kind === 'STOCK') {
            const [, product, warehouse] = row.key.split(':').map(Number);
            const existing = await manager.query('SELECT id,quantity FROM inventory_stocks WHERE shop_id=$1 AND product_id=$2 AND warehouse_id=$3', [request.shopId, product, warehouse]);
            if (existing.length > 1) reject('STOCK_CONFLICT', 'Dòng tồn kho bị trùng.', 409);
            if (existing.length) await manager.query('UPDATE inventory_stocks SET quantity=quantity+$1,updated_at=now() WHERE id=$2 AND shop_id=$3', [row.delta, existing[0].id, request.shopId]);
            else await manager.query('INSERT INTO inventory_stocks(shop_id,product_id,warehouse_id,quantity,updated_at) VALUES($1,$2,$3,$4,now())', [request.shopId, product, warehouse, row.delta]);
            let lotId: number | undefined;
            if (row.delta > 0) {
                const input = request.rows.find(r => r.key === row.key)!;
                const [lot] = await manager.query(`INSERT INTO inventory_lots(shop_id,product_id,lot_date,initial_qty,remaining_qty,cost_price,notes)
                    VALUES($1,$2,$3::timestamptz AT TIME ZONE 'UTC',$4,$4,$5,$6) RETURNING id`,
                [request.shopId, product, `${request.asOf}T00:00:00+07:00`, row.delta, input.unitCost, `Số dư ban đầu #${batchId}`]);
                lotId = Number(lot.id);
            } else for (const allocation of row.lotAllocations) {
                const changed = await manager.query(`UPDATE inventory_lots SET remaining_qty=remaining_qty-$1
                    WHERE id=$2 AND shop_id=$3 AND product_id=$4 AND remaining_qty>=$1 RETURNING id`,
                [allocation.quantity, allocation.lotId, request.shopId, product]);
                if (changed[0].length !== 1) reject('LOT_CHANGED', 'Lô giá vốn đã thay đổi; cần xem trước lại.', 409);
            }
            await manager.query(`INSERT INTO inventory_movements(shop_id,product_id,warehouse_id,movement_type,quantity,reference_type,reference_id,notes,created_by)
                VALUES($1,$2,$3,$4,$5,'OPENING_BALANCE',$6,$7,$8)`, [request.shopId, product, warehouse, row.delta > 0 ? 'IN' : 'OUT',
                Math.abs(row.delta), batchId, `Đối chiếu đầu ngày ${request.asOf}`, actorId]);
            await this.adjustment(manager, request, row, batchId, 'STOCK_MOVEMENT', row.valueDeltaCents, row.delta,
                { product, warehouse }, { ...(lotId ? { lotId } : {}), lotAllocations: row.lotAllocations });
            await manager.query(`UPDATE products SET cost_price=COALESCE((SELECT ROUND(SUM(remaining_qty::numeric*cost_price)/NULLIF(SUM(remaining_qty),0),2)
                FROM inventory_lots WHERE shop_id=$1 AND product_id=$2 AND remaining_qty>0),cost_price) WHERE shop_id=$1 AND id=$2`, [request.shopId, product]);
        } else {
            const receivable = row.kind === 'RECEIVABLE', partyId = Number(row.key.split(':')[1]);
            const table = receivable ? 'receivables' : 'payables', party = receivable ? 'customers' : 'suppliers';
            const column = receivable ? 'customer_id' : 'supplier_id';
            if (row.delta > 0) {
                const [debt] = await manager.query(`INSERT INTO ${table}(shop_id,${column},amount,paid_amount,due_date,status,notes)
                    VALUES($1,$2,$3,0,$4,'UNPAID',$5) RETURNING id`, [request.shopId, partyId, openingCentsText(row.delta), row.dueDate, `Số dư ban đầu #${batchId}`]);
                await this.adjustment(manager, request, row, batchId, 'LINKED_DOCUMENT', row.delta, 0,
                    receivable ? { receivable: Number(debt.id) } : { payable: Number(debt.id) }, {});
            } else for (const allocation of row.debtAllocations) {
                await this.adjustment(manager, request, row, batchId, 'BALANCE_OFFSET', -allocation.amountCents, 0,
                    receivable ? { receivable: allocation.debtId } : { payable: allocation.debtId }, {});
            }
            await manager.query(`UPDATE ${party} SET balance=COALESCE(balance,0)+$1,updated_at=now() WHERE shop_id=$2 AND id=$3`, [openingCentsText(row.delta), request.shopId, partyId]);
        }
    }

    private async postJournal(manager: EntityManager, plan: Plan, batchId: number) {
        const totals = plan.totals;
        const signed = [{ account: '111', value: totals.cashDeltaCents }, { account: '112', value: totals.bankDeltaCents },
            { account: '156', value: totals.stockValueDeltaCents }, { account: '131', value: totals.receivableDeltaCents },
            { account: '331', value: -totals.payableDeltaCents }, { account: 'OPENING_BALANCE_CLEARING', value: -totals.netAssetDeltaCents }].filter(l => l.value !== 0);
        if (!signed.length) return; // Free stock still has its movement and receipt.
        if (openingSumCents(signed.map(l => l.value)) !== 0) throw new OpeningBalancePlanError('Bút toán số dư ban đầu không cân bằng.');
        const [entry] = await manager.query(`INSERT INTO journal_entries(shop_id,entry_date,reference_type,reference_id,description)
            VALUES($1,$2,'OPENING_BALANCE',$3,$4) RETURNING id`, [plan.shopId, `${plan.asOf}T00:00:00+07:00`, batchId, 'Đối chiếu số dư ban đầu; không phải thu nhập hoặc chi phí trong kỳ']);
        // Send decimal strings directly to numeric columns; no float conversion of large cents.
        await manager.query(`INSERT INTO journal_lines(journal_entry_id,account_code,amount,entry_type)
            SELECT $1,l.account,l.amount::numeric,l.direction FROM unnest($2::text[],$3::text[],$4::text[]) l(account,amount,direction)`,
        [entry.id, signed.map(l => l.account), signed.map(l => openingCentsText(Math.abs(l.value))), signed.map(l => l.value > 0 ? 'DEBIT' : 'CREDIT')]);
    }
}
