import { createHash, randomBytes } from 'node:crypto';
import { EntityManager } from 'typeorm';
import { AppDataSource } from '../config/db.config';
import { Payable, Supplier } from '../supplier/entities';
import { DebtPaymentHistory } from '../customer/entities';
import { PurchaseOrder } from '../inventory/entities';
import { DailyClosing } from '../finance/entities';
import { ActivityLog } from '../system/entities';
import { ShopMember } from '../shop/entities';
import { membershipHasAnyPermission } from '../middleware/permission.utils';
import { lockShopMutation } from '../utils/shop-mutation-lock';
import { vietnamDateKey } from '../finance/finance-period.utils';
import { openingAdjustedDebt, openingEffectCents, openingEffectValue, openingEffectText, readOpeningBalanceEffects } from '../finance/opening-balance-effects.repository';
import { paymentLedgerAccountCode } from '../sales/payment-ledger.utils';
import { FinanceService } from './finance.service';
import { PostingService } from './posting.service';
import { SupplierService } from './supplier.service';
import { normalizeSupplierPayment, SupplierPaymentError } from '../supplier/supplier-payment-input.utils';
export { SupplierPaymentError } from '../supplier/supplier-payment-input.utils';

export type SupplierPaymentActor = { id: number; authVersion: number };
type PaymentResult = {
    shopId: number; operationId: string; payableId: number; supplierId: number;
    paymentHistoryId: number; cashTransactionId: number; amount: number; paidAmount: number; remaining: number;
    openingAdjustmentAmount: number; paymentDate: string; replayed: boolean
};

export class SupplierPaymentService {
    private async permission(manager: EntityManager, shopId: number, actor: SupplierPaymentActor) {
        if (!Number.isSafeInteger(shopId) || shopId <= 0 || !Number.isSafeInteger(actor.id) || actor.id <= 0 || !Number.isSafeInteger(actor.authVersion)) {
            throw new SupplierPaymentError('Phiên làm việc không hợp lệ', 401);
        }
        const [user] = await manager.query('SELECT id,is_active,auth_version FROM users WHERE id=$1 FOR SHARE', [actor.id]);
        if (!user?.is_active || Number(user.auth_version) !== actor.authVersion) throw new SupplierPaymentError('Phiên làm việc đã hết hiệu lực', 401);
        await manager.query('SELECT id FROM shop_members WHERE shop_id=$1 AND user_id=$2 FOR SHARE', [shopId, actor.id]);
        let member = await manager.findOne(ShopMember, { where: { shopId, userId: actor.id, isActive: true, status: 'ACTIVE' }, relations: ['role'] });
        if (member?.roleId && member.memberType !== 'OWNER') {
            await manager.query('SELECT id FROM shop_roles WHERE id=$1 AND shop_id=$2 FOR SHARE', [member.roleId, shopId]);
            member = await manager.findOne(ShopMember, { where: { id: member.id, shopId, isActive: true, status: 'ACTIVE' }, relations: ['role'] });
        }
        if (!member || !membershipHasAnyPermission(member, ['finance'], 'edit', shopId)) throw new SupplierPaymentError('Bạn không có quyền ghi nhận chi tiền', 403);
        return member;
    }

    private receipt(log: ActivityLog, actorId: number, requestHash?: string): PaymentResult {
        if (log.userId !== actorId) throw new SupplierPaymentError('Không có quyền xem lượt ghi nhận này', 403);
        let saved: { requestHash: string; result: PaymentResult };
        try {
            saved = JSON.parse(log.newValue);
            const result = saved.result;
            if (!/^[a-f0-9]{64}$/.test(saved.requestHash) || result.shopId !== log.shopId || result.operationId !== log.entityName ||
                result.paymentHistoryId !== log.entityId || result.replayed !== false ||
                ![result.payableId, result.supplierId, result.paymentHistoryId, result.cashTransactionId].every(id => Number.isSafeInteger(id) && id > 0) ||
                ![result.amount, result.paidAmount, result.remaining, result.openingAdjustmentAmount].every(Number.isFinite)) throw Error();
        } catch { throw new SupplierPaymentError('Biên nhận cần được kiểm tra lại; không ghi lại bằng mã mới', 409); }
        if (requestHash && saved.requestHash !== requestHash) throw new SupplierPaymentError('Mã lượt ghi nhận đã dùng cho nội dung khác', 409);
        return { ...saved.result, replayed: true };
    }

    async record(shopId: number, payableId: number, actor: SupplierPaymentActor, raw: unknown, now = new Date()): Promise<PaymentResult> {
        if (!Number.isSafeInteger(payableId) || payableId <= 0) throw new SupplierPaymentError('Khoản phải trả không hợp lệ');
        const input = normalizeSupplierPayment(raw, now);
        const requestHash = createHash('sha256').update(JSON.stringify({
            payableId, amount: openingEffectText(input.amountCents),
            method: input.method, paymentDate: input.dateKey, notes: input.notes
        })).digest('hex');
        return AppDataSource.transaction(async manager => {
            await manager.query("SET LOCAL lock_timeout = '5s'");
            await lockShopMutation(manager, shopId);
            const member = await this.permission(manager, shopId, actor);
            const logs = manager.getRepository(ActivityLog);
            const previous = await logs.findOne({ where: { shopId, action: 'CREATE', entityType: 'SUPPLIER_PAYMENT', entityName: input.operationId } });
            if (previous) return this.receipt(previous, actor.id, requestHash);
            if (member.memberType !== 'OWNER' && await manager.exists(DailyClosing, { where: { shopId, closingDate: input.dateKey as any } })) {
                throw new SupplierPaymentError('Ngày đã chốt sổ; cần OWNER xử lý điều chỉnh', 403);
            }
            const payable = await manager.findOne(Payable, { where: { id: payableId, shopId }, lock: { mode: 'pessimistic_write' } });
            if (!payable) throw new SupplierPaymentError('Không tìm thấy khoản phải trả', 404);
            if (payable.status === 'CANCELLED') throw new SupplierPaymentError('Khoản phải trả đã hủy');
            const supplier = await manager.findOne(Supplier, { where: { id: payable.supplierId, shopId } });
            if (!supplier) throw new SupplierPaymentError('Không tìm thấy nhà cung cấp trong cửa hàng', 404);
            const balanceDate = vietnamDateKey(now);
            const effects = await readOpeningBalanceEffects(manager, { shopId, asOf: balanceDate, includeCash: false, receivableIds: [], payableIds: [payable.id] });
            if ((effects.payableDates.get(payable.id) ?? '') > input.dateKey) throw new SupplierPaymentError('Ngày trả tiền trước ngày khoản nợ có hiệu lực');
            const adjustment = effects.payableCents.get(payable.id) ?? 0n;
            const before = openingAdjustedDebt(payable.amount, payable.paidAmount, adjustment);
            if (before.remainingCents <= 0n) throw new SupplierPaymentError('Khoản phải trả đã hết dư nợ');
            if (input.amountCents > before.remainingCents) throw new SupplierPaymentError('Số tiền vượt phần còn phải trả');
            if (Number(payable.purchaseOrderId) > 0) {
                const order = await manager.findOne(PurchaseOrder, { where: { id: payable.purchaseOrderId, shopId, supplierId: supplier.id }, lock: { mode: 'pessimistic_write' } });
                if (!order || order.status !== 'COMPLETED' || vietnamDateKey(new Date(order.orderDate)) > input.dateKey ||
                    openingEffectCents(order.totalAmount) !== before.amountCents || openingEffectCents(order.paidAmount) !== before.paidCents) {
                    throw new SupplierPaymentError('Đơn nhập liên kết chưa khớp khoản nợ; cần đối chiếu trước khi ghi nhận', 409);
                }
                await manager.update(PurchaseOrder, { id: order.id, shopId }, { paidAmount: openingEffectValue(before.paidCents + input.amountCents) });
            }
            payable.paidAmount = openingEffectValue(before.paidCents + input.amountCents);
            const after = openingAdjustedDebt(payable.amount, payable.paidAmount, adjustment);
            payable.status = after.remainingCents === 0n ? 'PAID' : 'PARTIAL';
            await manager.save(Payable, payable);
            const history = await manager.save(DebtPaymentHistory, manager.create(DebtPaymentHistory, {
                shopId, payableId,
                amount: input.amount, paymentMethod: input.method, paymentDate: input.paymentDate, notes: input.notes || undefined, recordedBy: actor.id
            }));
            const cash = await new FinanceService().createCashTransaction(shopId, {
                transactionCode: 'PC' + randomBytes(9).toString('hex'),
                type: 'EXPENSE', category: 'PURCHASE', amount: input.amount, paymentMethod: input.method,
                referenceType: 'SUPPLIER_PAYMENT', referenceId: history.id, transactionDate: input.paymentDate,
                counterparty: supplier.name, notes: input.notes || `Trả nợ nhà cung cấp ${supplier.name}`,
                createdBy: actor.id
            }, manager);
            await new PostingService().postJournal(shopId, 'SUPPLIER_PAYMENT', history.id, `Trả nợ nhà cung cấp ${supplier.name}`,
                [{ accountCode: '331', amount: input.amount, entryType: 'DEBIT' },
                { accountCode: paymentLedgerAccountCode(input.method), amount: input.amount, entryType: 'CREDIT' }], manager, input.paymentDate);
            const balance = await new SupplierService().balanceInTransaction(manager, supplier, balanceDate);
            await manager.update(Supplier, { id: supplier.id, shopId }, { balance });
            const result: PaymentResult = {
                shopId, operationId: input.operationId, payableId, supplierId: supplier.id,
                paymentHistoryId: history.id, cashTransactionId: cash.id, amount: input.amount, paidAmount: Number(payable.paidAmount),
                remaining: openingEffectValue(after.remainingCents), openingAdjustmentAmount: openingEffectValue(adjustment), paymentDate: input.dateKey, replayed: false
            };
            await logs.save(logs.create({
                shopId, userId: actor.id, action: 'CREATE', entityType: 'SUPPLIER_PAYMENT', entityName: input.operationId,
                entityId: history.id, newValue: JSON.stringify({ requestHash, result }), description: `Ghi nhận trả nợ ${supplier.name}`
            }));
            return result;
        });
    }

    async status(shopId: number, actor: SupplierPaymentActor, operationId: string) {
        if (!/^[A-Za-z0-9_-]{16,80}$/.test(operationId)) throw new SupplierPaymentError('Mã lượt ghi nhận không hợp lệ');
        return AppDataSource.transaction(async manager => {
            await this.permission(manager, shopId, actor);
            const log = await manager.findOne(ActivityLog, { where: { shopId, action: 'CREATE', entityType: 'SUPPLIER_PAYMENT', entityName: operationId } });
            return log ? { state: 'COMPLETED', result: this.receipt(log, actor.id) } : { state: 'UNKNOWN' };
        });
    }
}
