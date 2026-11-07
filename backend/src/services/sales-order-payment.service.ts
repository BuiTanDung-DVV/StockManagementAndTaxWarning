import { withOrderDebtBalances } from '../finance/order-debt-balance.repository';
import { createHash, randomBytes } from 'node:crypto';
import { EntityManager } from 'typeorm';
import { AppDataSource } from '../config/db.config';
import { SalesOrder, SalesOrderPayment } from '../sales/entities';
import { Customer, DebtPaymentHistory, Receivable } from '../customer/entities';
import { ActivityLog } from '../system/entities';
import { DailyClosing } from '../finance/entities';
import { ShopMember } from '../shop/entities';
import { membershipHasAnyPermission } from '../middleware/permission.utils';
import { lockShopMutation } from '../utils/shop-mutation-lock';
import { vietnamDateKey } from '../finance/finance-period.utils';
import { openingAdjustedDebt, openingEffectCents, openingEffectValue, openingEffectText, readOpeningBalanceEffects } from '../finance/opening-balance-effects.repository';
import { normalizeSalesPayment, SalesPaymentError } from '../sales/sales-payment-input.utils';
import { paymentLedgerAccountCode } from '../sales/payment-ledger.utils';
import { FinanceService } from './finance.service';
import { PostingService } from './posting.service';
import { CustomerService } from './customer.service';
export { SalesPaymentError } from '../sales/sales-payment-input.utils';
export type SalesPaymentActor = { id: number; authVersion: number };

export class SalesOrderPaymentService {
    private async permission(manager: EntityManager, shopId: number, actor: SalesPaymentActor) {
        if (!Number.isSafeInteger(shopId) || shopId <= 0 || !actor || !Number.isSafeInteger(actor.id) || actor.id <= 0 || !Number.isSafeInteger(actor.authVersion)) throw new SalesPaymentError('Phiên làm việc không hợp lệ', 401);
        const [user] = await manager.query('SELECT id,is_active,auth_version FROM users WHERE id=$1 FOR SHARE', [actor.id]);
        if (!user?.is_active || Number(user.auth_version) !== actor.authVersion) throw new SalesPaymentError('Phiên làm việc đã hết hiệu lực', 401);
        await manager.query('SELECT id FROM shop_members WHERE shop_id=$1 AND user_id=$2 FOR SHARE', [shopId, actor.id]);
        let member = await manager.findOne(ShopMember, { where: { shopId, userId: actor.id, isActive: true, status: 'ACTIVE' }, relations: ['role'] });
        if (member?.roleId && member.memberType !== 'OWNER') {
            await manager.query('SELECT id FROM shop_roles WHERE id=$1 AND shop_id=$2 FOR SHARE', [member.roleId, shopId]);
            member = await manager.findOne(ShopMember, { where: { id: member.id, shopId, isActive: true, status: 'ACTIVE' }, relations: ['role'] });
        }
        if (!member || !membershipHasAnyPermission(member, ['sales'], 'edit', shopId)) throw new SalesPaymentError('Bạn không có quyền ghi nhận thu tiền đơn bán', 403);
        return member;
    }
    private receipt(log: ActivityLog, orderId: number, actorId: number, hash?: string): any {
        if (log.userId !== actorId) throw new SalesPaymentError('Không có quyền xem lượt ghi nhận này', 403);
        let saved: any;
        try {
            saved = JSON.parse(log.newValue); const result = saved.result;
            if (!/^[a-f0-9]{64}$/.test(saved.requestHash) || result.shopId !== log.shopId || result.operationId !== log.entityName || result.id !== log.entityId || result.orderId !== orderId || result.order?.id !== orderId || result.order?.shopId !== log.shopId || result.replayed !== false ||
                !['id', 'customerId', 'receivableId', 'paymentHistoryId', 'cashTransactionId'].every(key => Number.isSafeInteger(result[key]) && result[key] > 0) ||
                !['amount', 'orderPaidAmount', 'receivablePaidAmount', 'remainingAmount', 'openingAdjustmentAmount'].every(key => Number.isFinite(result[key])) || result.amount <= 0 || result.remainingAmount < 0 || !/^\d{4}-\d{2}-\d{2}$/.test(result.paymentDate)) throw Error();
        } catch { throw new SalesPaymentError('Biên nhận cần được kiểm tra lại; không ghi lại bằng mã mới', 409); }
        if (hash && saved.requestHash !== hash) throw new SalesPaymentError('Mã lượt ghi nhận đã dùng cho nội dung khác', 409);
        return { ...saved.result, replayed: true };
    }
    async record(shopId: number, orderId: number, actor: SalesPaymentActor, raw: unknown, now = new Date()) {
        if (!Number.isSafeInteger(orderId) || orderId <= 0) throw new SalesPaymentError('Đơn bán không hợp lệ');
        const input = normalizeSalesPayment(raw, now), operationId = input.operationId ?? randomBytes(16).toString('hex');
        const hash = createHash('sha256').update(JSON.stringify({            
orderId, amount: openingEffectText(input.amountCents), method: input.method,
            paymentDate: input.explicitDate ? input.dateKey : null, notes: input.notes, referenceCode: input.referenceCode        
})).digest('hex');
        return AppDataSource.transaction(async manager => {
            await manager.query("SET LOCAL lock_timeout = '5s'"); await lockShopMutation(manager, shopId);
            const member = await this.permission(manager, shopId, actor), logs = manager.getRepository(ActivityLog);
            const previous = await logs.findOne({ where: { shopId, action: 'CREATE', entityType: 'SALES_ORDER_PAYMENT', entityName: operationId } });
            if (previous) return this.receipt(previous, orderId, actor.id, hash);
            if (member.memberType !== 'OWNER' && await manager.exists(DailyClosing, { where: { shopId, closingDate: input.dateKey as any } })) throw new SalesPaymentError('Ngày đã chốt sổ; cần OWNER xử lý điều chỉnh', 403);
            const order = await manager.findOne(SalesOrder, { where: { id: orderId, shopId }, lock: { mode: 'pessimistic_write' } });
            if (!order) throw new SalesPaymentError('Không tìm thấy đơn bán', 404);
            if (order.status === 'CANCELLED' || (order.returnStatus && !['NONE', 'PARTIAL_RETURN', 'FULL_RETURN', 'RETURNED'].includes(order.returnStatus))) throw new SalesPaymentError('Không thể thu thêm cho đơn đã hủy hoặc trả hàng');
            if (vietnamDateKey(new Date(order.orderDate)) > input.dateKey) throw new SalesPaymentError('Ngày thu tiền trước ngày lập đơn');
            const links = await manager.query('SELECT id,customer_id FROM receivables WHERE shop_id=$1 AND order_id=$2 FOR UPDATE', [shopId, orderId]);
            const [orderLink] = await manager.query('SELECT customer_id FROM sales_orders WHERE shop_id=$1 AND id=$2', [shopId, orderId]);
            if (links.length !== 1 || !Number(orderLink?.customer_id) || Number(links[0].customer_id) !== Number(orderLink.customer_id)) throw new SalesPaymentError('Đơn bán và công nợ chưa khớp; cần đối chiếu trước khi thu tiền', 409);
            const customer = await manager.findOne(Customer, { where: { id: Number(orderLink.customer_id), shopId } });
            const receivable = await manager.findOne(Receivable, { where: { id: Number(links[0].id), shopId } });
            if (receivable?.status === 'CANCELLED' && ['FULL_RETURN', 'RETURNED'].includes(order.returnStatus ?? '')) throw new SalesPaymentError('Đơn trả hàng đã hết dư nợ');
            if (!customer || !receivable || receivable.status === 'CANCELLED') throw new SalesPaymentError('Không tìm thấy khoản công nợ hợp lệ của đơn bán', 409);
            const balanceDate = vietnamDateKey(now);
            const effects = await readOpeningBalanceEffects(manager, { shopId, asOf: balanceDate, includeCash: false, payableIds: [], receivableIds: [receivable.id] });
            if ((effects.receivableDates.get(receivable.id) ?? '') > input.dateKey) throw new SalesPaymentError('Ngày thu tiền trước ngày khoản nợ có hiệu lực');
            const adjustment = effects.receivableCents.get(receivable.id) ?? 0n;
            const before = openingAdjustedDebt(receivable.amount, receivable.paidAmount, adjustment);
            const total = openingEffectCents(order.totalAmount), paid = openingEffectCents(order.paidAmount ?? 0);
            const returned = ['PARTIAL_RETURN', 'FULL_RETURN', 'RETURNED'].includes(order.returnStatus ?? '');
            if (returned) {
                const balance = (await withOrderDebtBalances(manager, 'SALES', [{ ...order, customer }], balanceDate))[0];
                if (!['RETURN_LEDGER', 'PARTIAL_RETURN_LEDGER'].includes(balance.debtBalanceBasis) || balance.remainingAmount == null) throw new SalesPaymentError('Công nợ sau trả hàng cần đối chiếu', 409);
                const lastReturnDate = 'lastReturnDate' in balance ? balance.lastReturnDate : undefined;
                if (lastReturnDate && lastReturnDate > input.dateKey) throw new SalesPaymentError('Ngày thu tiền trước ngày trả hàng');
            } else if (total - paid !== before.amountCents - before.paidCents) throw new SalesPaymentError('Số tiền đã thu của đơn và công nợ chưa khớp; cần đối chiếu', 409);
            if (before.remainingCents <= 0n) throw new SalesPaymentError('Đơn bán đã hết dư nợ');
            if (input.amountCents > before.remainingCents) throw new SalesPaymentError('Số tiền vượt phần còn phải thu sau điều chỉnh');
            receivable.paidAmount = openingEffectValue(before.paidCents + input.amountCents);
            const after = openingAdjustedDebt(receivable.amount, receivable.paidAmount, adjustment);
            receivable.status = after.remainingCents === 0n ? 'PAID' : 'PARTIAL'; await manager.save(Receivable, receivable);
            order.paidAmount = openingEffectValue(paid + input.amountCents);
            if (!returned) order.status = after.remainingCents === 0n ? 'DELIVERED' : 'PENDING';
            await manager.save(SalesOrder, order);
            const payment = await manager.save(SalesOrderPayment, manager.create(SalesOrderPayment, { shopId, order, amount: input.amount, method: input.method, notes: input.notes || undefined, referenceCode: input.referenceCode || undefined, paidAt: input.paymentDate }));
            const history = await manager.save(DebtPaymentHistory, manager.create(DebtPaymentHistory, { shopId, receivable, amount: input.amount, paymentMethod: input.method, paymentDate: input.paymentDate, notes: input.notes || undefined, recordedBy: actor.id }));
            const cash = await new FinanceService().createCashTransaction(shopId, {
                transactionCode: 'PT' + randomBytes(9).toString('hex'), type: 'INCOME', category: 'SALES', amount: input.amount, paymentMethod: input.method,
                referenceType: 'SALES_ORDER', referenceId: orderId,
                counterparty: customer.name, transactionDate: input.paymentDate, createdBy: actor.id,
                notes: [`Thu tiền đơn ${order.orderCode}`, input.referenceCode ? `Tham chiếu ${input.referenceCode}` : '', input.notes].filter(Boolean).join(' · '),
            }, manager);
            await new PostingService().postJournal(shopId, 'DEBT_COLLECTION', orderId, `Thu nợ khách hàng - Đơn ${order.orderCode}`, [
                { accountCode: paymentLedgerAccountCode(input.method), amount: input.amount, entryType: 'DEBIT' },
                { accountCode: '131', amount: input.amount, entryType: 'CREDIT' },
            ], manager, input.paymentDate);
            const balance = await new CustomerService().balanceInTransaction(manager, customer, balanceDate);
            await manager.update(Customer, { id: customer.id, shopId }, { balance });
            const result = {                
...payment, amount: input.amount, operationId, orderId, customerId: customer.id, receivableId: receivable.id, paymentHistoryId: history.id, cashTransactionId: cash.id,
                orderPaidAmount: Number(order.paidAmount), receivablePaidAmount: Number(receivable.paidAmount), remainingAmount: openingEffectValue(after.remainingCents),
                openingAdjustmentAmount: openingEffectValue(adjustment), paymentDate: input.dateKey, replayed: false            
};
            await logs.save(logs.create({                
shopId, userId: actor.id, action: 'CREATE', entityType: 'SALES_ORDER_PAYMENT', entityId: payment.id, entityName: operationId,
                newValue: JSON.stringify({ requestHash: hash, result }), description: `Ghi nhận thu tiền đơn ${order.orderCode}`            
}));
            return result;
        });
    }
    async status(shopId: number, orderId: number, actor: SalesPaymentActor, operationId: string) {
        if (!Number.isSafeInteger(orderId) || orderId <= 0 || !/^[A-Za-z0-9_-]{16,80}$/.test(operationId)) throw new SalesPaymentError('Mã tra cứu không hợp lệ');
        return AppDataSource.transaction(async manager => {
            await this.permission(manager, shopId, actor);
            const log = await manager.findOne(ActivityLog, { where: { shopId, action: 'CREATE', entityType: 'SALES_ORDER_PAYMENT', entityName: operationId } });
            return log ? { state: 'COMPLETED', result: this.receipt(log, orderId, actor.id) } : { state: 'UNKNOWN' };
        });
    }
}
