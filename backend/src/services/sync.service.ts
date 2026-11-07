import { AppDataSource } from '../config/db.config';
import { SyncOperation } from '../sync/entities';
import { normalizeSyncInput, SyncInputError, syncPermissions } from '../sync/sync-input';
import { membershipHasAnyPermission } from '../middleware/permission.utils';
import { lockShopMutation } from '../utils/shop-mutation-lock';
import { assertPastOrToday } from '../utils/business-date';
import { vietnamDateKey } from '../finance/finance-period.utils';
import { ShopMember } from '../shop/entities';
import { DailyClosing } from '../finance/entities';
import { FinanceService } from './finance.service';
import { SalesService } from './sales.service';
import { InventoryService } from './inventory.service';
import { config } from '../config/env.config';
import { findDuplicateCandidates, verifyDuplicateDecision } from '../sync/duplicate-review';
import { ActivityLog } from '../system/entities';

export class SyncService {
    async apply(shopId: number, userId: number, body: unknown) {
        const input = normalizeSyncInput(body);
        if (input.actorId !== userId) {
            throw new SyncInputError('Tài khoản đăng nhập khác tài khoản đã ghi dữ liệu. Chưa đồng bộ.', 403);
        }
        const runner = AppDataSource.createQueryRunner();
        try {
            await runner.connect();
            await runner.startTransaction();
            const manager = runner.manager;
            await lockShopMutation(manager, shopId);
            // Recheck membership inside the transaction as the queued write may
            // be days old. The route also checks the current feature permission.
            const member = await manager.findOne(ShopMember, {
                where: { shopId, userId, isActive: true, status: 'ACTIVE' },
            });
            if (!member || !membershipHasAnyPermission(member, [syncPermissions[input.kind]], 'edit', shopId)) {
                throw new SyncInputError('Bạn không còn quyền ghi nghiệp vụ này trong cửa hàng.', 403);
            }
            const repo = manager.getRepository(SyncOperation);
            const key = { shopId, userId, operationId: input.operationId };
            const receipt = await repo.findOne({ where: key });
            if (receipt) {
                if (receipt.requestHash !== input.requestHash || receipt.kind !== input.kind) {
                    throw new SyncInputError('Mã đồng bộ đã được dùng cho nội dung khác. Giữ bản ghi để kiểm tra.', 409);
                }
                await runner.commitTransaction();
                return { operationId: input.operationId, kind: receipt.kind, entityId: receipt.entityId, replayed: true };
            }
            const date = assertPastOrToday(input.payload.transactionDate ?? input.payload.orderDate, 'Ngày chứng từ');
            const closing = await manager.getRepository(DailyClosing).createQueryBuilder('c')
                .where('c.shop_id = :shopId', { shopId })
                .andWhere('CAST(c.closing_date AS DATE) = :date', { date: vietnamDateKey(date) }).getOne();
            if (closing && member.memberType !== 'OWNER') {
                throw new SyncInputError('Ngày chứng từ đã chốt sổ. Bản ghi được giữ trên thiết bị để xử lý.', 409);
            }
            const candidates = await findDuplicateCandidates(manager, shopId, input);
            // A changed/expired review must be shown again. Never trust the
            // client's candidate IDs, or a decision from a different payload.
            const decision = (body as any).reviewDecision;
            let existingId: number | null = null;
            if (candidates.length || decision) {
                existingId = verifyDuplicateDecision(input, shopId, userId, candidates, decision, config.accessTokenSecret);
            }
            if (existingId !== null) {
                await repo.save(repo.create({ ...key, kind: input.kind, requestHash: input.requestHash, entityId: existingId }));
                await manager.save(ActivityLog, { shopId, userId, action: 'LINK_EXISTING',
                    entityType: input.kind, entityId: existingId,
                    description: 'Người dùng đối chiếu ghi chép cục bộ và chọn dùng giao dịch đã có.',
                    newValue: JSON.stringify({ operationId: input.operationId, requestHash: input.requestHash }) });
                await runner.commitTransaction();
                return { operationId: input.operationId, kind: input.kind, entityId: existingId, replayed: false, usedExisting: true };
            }
            const dto = { ...input.payload, createdBy: userId };
            let document: { id: number };
            switch (input.kind) {
                case 'CASH_TRANSACTION_CREATE':
                    document = await new FinanceService().createCashTransaction(shopId, dto, manager);
                    break;
                case 'SALES_ORDER_CREATE':
                    document = await new SalesService().create(shopId, dto, runner);
                    break;
                case 'PURCHASE_ORDER_CREATE':
                    document = await new InventoryService().createPurchaseOrder(shopId, input.payload, runner);
                    break;
            }
            if (decision?.action === 'createNew') {
                await manager.save(ActivityLog, { shopId, userId, action: 'CREATE_DISTINCT',
                    entityType: input.kind, entityId: document.id,
                    description: 'Người dùng đối chiếu và xác nhận đây là nghiệp vụ khác, cần ghi thêm.',
                    newValue: JSON.stringify({ operationId: input.operationId,
                        reviewedEntityIds: candidates.slice(0, 20).map(c => c.id) }) });
            }
            await repo.save(repo.create({ ...key, kind: input.kind, requestHash: input.requestHash, entityId: document.id }));
            await runner.commitTransaction();
            return { operationId: input.operationId, kind: input.kind, entityId: document.id, replayed: false };
        } catch (error) {
            if (runner.isTransactionActive) await runner.rollbackTransaction();
            throw error;
        } finally {
            await runner.release();
        }
    }
}
