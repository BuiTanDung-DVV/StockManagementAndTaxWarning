import { AppDataSource } from '../config/db.config';
import { EntityManager } from 'typeorm';
import { InventoryMovement, InventoryStock, Warehouse } from '../inventory/entities';
import { InventoryLot } from '../inventory/lot.entity';
import { Product } from '../product/entities';
import { lockShopMutation } from '../utils/shop-mutation-lock';
import { COGSService } from './cogs.service';

const costing = new COGSService();

export class InventoryLoanError extends Error {}

async function eligibleProduct(manager: EntityManager, shopId: number, productId: number) {
    const product = await manager.findOneBy(Product, { id: productId, shopId, isActive: true });
    if (!product) throw new InventoryLoanError('Sản phẩm không còn khả dụng trong cửa hàng.');
    return product;
}

async function eligibleWarehouse(manager: EntityManager, shopId: number, warehouseId: number) {
    const warehouse = await manager.findOneBy(Warehouse, { id: warehouseId, shopId, isActive: true });
    if (!warehouse) throw new InventoryLoanError('Kho không còn khả dụng trong cửa hàng.');
}

type ShipmentInput = {
    quantity: number;
    operationId: string;
    warehouseId: number;
    lenderProductId?: number;
};

export async function shipInventoryLoan(shopId: number, userId: number, loanId: number, input: ShipmentInput) {
    return AppDataSource.transaction(async manager => {
        await lockShopMutation(manager, shopId);
        const [loan] = await manager.query(
            `SELECT l.*, CASE WHEN p.requester_shop_id = l.borrower_shop_id
                     THEN p.recipient_shop_id ELSE p.requester_shop_id END AS lender_shop_id
             FROM shop_inventory_loans l JOIN shop_inventory_partnerships p ON p.id = l.partnership_id
             WHERE l.id = $1 AND $2 IN (p.requester_shop_id, p.recipient_shop_id) FOR UPDATE OF l`,
            [loanId, shopId],
        );
        if (!loan || loan.canceled_at) throw new InventoryLoanError('Phiếu mượn không khả dụng.');
        const returning = shopId === loan.borrower_shop_id;
        const direction = returning ? 'RETURN' : 'LOAN';
        const previous = await manager.query(
            `SELECT id, direction, shipped_quantity, source_warehouse_id, destination_warehouse_id
             FROM shop_inventory_loan_shipments WHERE operation_id = $1 AND loan_id = $2`,
            [input.operationId, loanId],
        );
        if (previous.length) {
            const saved = previous[0];
            if (saved.direction !== direction || saved.shipped_quantity !== input.quantity
                || saved.source_warehouse_id !== input.warehouseId
                || (!returning && (input.lenderProductId !== loan.lender_product_id
                    || saved.destination_warehouse_id !== loan.borrower_warehouse_id))) {
                throw new InventoryLoanError('Mã thao tác đã được dùng cho dữ liệu khác.');
            }
            return { id: saved.id };
        }
        const [totals] = await manager.query(
            `SELECT COALESCE(SUM(s.shipped_quantity) FILTER (WHERE direction = 'LOAN'), 0)::int AS loan_sent,
                    COALESCE(SUM(r.received) FILTER (WHERE direction = 'LOAN'), 0)::int AS loan_received,
                    COALESCE(SUM(s.shipped_quantity) FILTER (WHERE direction = 'RETURN'), 0)::int AS return_sent,
                    MAX(s.source_warehouse_id) FILTER (WHERE direction = 'LOAN') AS lender_warehouse_id
             FROM shop_inventory_loan_shipments s
             LEFT JOIN LATERAL (
                 SELECT SUM(received_quantity) AS received
                 FROM shop_inventory_loan_receipts WHERE shipment_id = s.id
             ) r ON true WHERE s.loan_id = $1`,
            [loanId],
        );
        const limit = returning ? totals.loan_received - totals.return_sent : loan.requested_quantity;
        if ((!returning && totals.loan_sent > 0) || input.quantity > limit) {
            throw new InventoryLoanError('Số lượng xuất vượt số lượng còn được xử lý.');
        }
        const lenderProductId = returning ? loan.lender_product_id : input.lenderProductId;
        if (!lenderProductId) throw new InventoryLoanError('Chọn sản phẩm tương ứng ở bên cho mượn.');
        const borrowerProduct = await eligibleProduct(manager, loan.borrower_shop_id, loan.borrower_product_id);
        const lenderProduct = await eligibleProduct(manager, loan.lender_shop_id, lenderProductId);
        if (borrowerProduct.unit.trim().toLowerCase() !== lenderProduct.unit.trim().toLowerCase()) {
            throw new InventoryLoanError('Hai sản phẩm phải cùng đơn vị tính.');
        }
        const destination = returning ? totals.lender_warehouse_id : loan.borrower_warehouse_id;
        if (!destination) throw new InventoryLoanError('Chọn kho nhận hàng hoàn.');
        await eligibleWarehouse(manager, shopId, input.warehouseId);
        await eligibleWarehouse(manager, returning ? loan.lender_shop_id : loan.borrower_shop_id, destination);
        const productId = returning ? borrowerProduct.id : lenderProduct.id;
        const stock = await manager.findOne(InventoryStock, {
            where: { shopId, productId, warehouseId: input.warehouseId },
            lock: { mode: 'pessimistic_write' },
        });
        if (!stock || Number(stock.quantity) < input.quantity) {
            throw new InventoryLoanError('Kho xuất không đủ tồn khả dụng.');
        }
        const cost = await costing.calculateCOGS(productId, input.quantity, undefined, shopId, manager);
        if (cost.lotDeductions.reduce((sum, lot) => sum + lot.qty, 0) !== input.quantity) {
            throw new InventoryLoanError('Tồn và số lượng lô chưa khớp.');
        }
        const [batch] = await manager.query(
            'SELECT id FROM inventory_lots WHERE id = ANY($1::int[]) AND batch_id IS NOT NULL LIMIT 1',
            [cost.lotDeductions.map(lot => lot.lotId)],
        );
        if (batch) throw new InventoryLoanError('Hàng quản lý theo lô có hạn dùng chưa hỗ trợ xuất mượn.');
        await costing.commitLotDeductions(cost.lotDeductions, manager);
        stock.quantity = Number(stock.quantity) - input.quantity;
        stock.updatedAt = new Date();
        await manager.save(stock);
        const [saved] = await manager.query(
            `INSERT INTO shop_inventory_loan_shipments
                (loan_id, direction, source_warehouse_id, destination_warehouse_id, shipped_quantity, shipped_by, operation_id, unit_cost)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
            [loanId, direction, input.warehouseId, destination, input.quantity, userId, input.operationId, cost.unitCost],
        );
        if (!returning) {
            await manager.query('UPDATE shop_inventory_loans SET lender_product_id=$1 WHERE id=$2', [lenderProductId, loanId]);
        }
        await manager.save(InventoryMovement, {
            shopId, productId, warehouseId: input.warehouseId, movementType: 'OUT',
            quantity: input.quantity, referenceType: 'SHOP_LOAN', referenceId: loanId, createdBy: userId,
        });
        return saved;
    });
}

export async function receiveInventoryLoan(shopId: number, userId: number, shipmentId: number,
    input: { quantity: number; operationId: string }) {
    return AppDataSource.transaction(async manager => {
        await lockShopMutation(manager, shopId);
        const [shipment] = await manager.query(
            `SELECT s.*, l.borrower_shop_id, l.borrower_product_id, l.lender_product_id
             FROM shop_inventory_loan_shipments s JOIN shop_inventory_loans l ON l.id=s.loan_id
             JOIN shop_inventory_partnerships p ON p.id=l.partnership_id
             WHERE s.id=$1 AND $2 IN (p.requester_shop_id,p.recipient_shop_id)
               AND ((s.direction='LOAN' AND l.borrower_shop_id=$2)
                    OR (s.direction='RETURN' AND l.borrower_shop_id<>$2))
             FOR UPDATE OF l, s`,
            [shipmentId, shopId],
        );
        if (!shipment || shipment.unit_cost == null) {
            throw new InventoryLoanError('Lượt gửi không khả dụng hoặc cần đối chiếu giá vốn.');
        }
        const [previous] = await manager.query(
            'SELECT id, received_quantity FROM shop_inventory_loan_receipts WHERE shipment_id=$1 AND operation_id=$2',
            [shipmentId, input.operationId],
        );
        if (previous) {
            if (previous.received_quantity !== input.quantity) {
                throw new InventoryLoanError('Mã thao tác đã được dùng cho số lượng khác.');
            }
            return { id: previous.id };
        }
        const [total] = await manager.query(
            'SELECT COALESCE(SUM(received_quantity),0)::int AS qty FROM shop_inventory_loan_receipts WHERE shipment_id=$1',
            [shipmentId],
        );
        if (input.quantity > shipment.shipped_quantity - total.qty) {
            throw new InventoryLoanError('Số thực nhận vượt số hàng còn đang giao.');
        }
        const productId = shipment.direction === 'LOAN' ? shipment.borrower_product_id : shipment.lender_product_id;
        const warehouseId = shipment.destination_warehouse_id;
        await eligibleProduct(manager, shopId, productId);
        await eligibleWarehouse(manager, shopId, warehouseId);
        const stock = await manager.findOne(InventoryStock, {
            where: { shopId, productId, warehouseId }, lock: { mode: 'pessimistic_write' },
        }) ?? manager.create(InventoryStock, { shopId, productId, warehouseId, quantity: 0 });
        stock.quantity = Number(stock.quantity) + input.quantity;
        stock.updatedAt = new Date();
        await manager.save(stock);
        await costing.addInventoryLot({
            shopId, productId, quantity: input.quantity, costPrice: Number(shipment.unit_cost),
            notes: `Phiếu mượn #${shipment.loan_id}`,
        }, manager);
        const [saved] = await manager.query(
            `INSERT INTO shop_inventory_loan_receipts (shipment_id,received_quantity,received_by,operation_id)
             VALUES ($1,$2,$3,$4) RETURNING id`,
            [shipmentId, input.quantity, userId, input.operationId],
        );
        await manager.save(InventoryMovement, {
            shopId, productId, warehouseId, movementType: 'IN',
            quantity: input.quantity, referenceType: 'SHOP_LOAN', referenceId: shipment.loan_id, createdBy: userId,
        });
        return saved;
    });
}

export function listInventoryLoans(shopId: number) {
    return AppDataSource.query(
        `SELECT l.id, l.requested_quantity AS "requestedQuantity", l.created_at AS "createdAt",
                l.canceled_at AS "canceledAt", (l.borrower_shop_id = $1) AS "borrowing",
                partner.shop_name AS "partnerName", product.name AS "productName", product.unit,
                COALESCE(shipments.items,'[]'::jsonb) AS shipments,
                COALESCE(shipments.outstanding,0)::int AS "outstandingQuantity"
         FROM shop_inventory_loans l
         JOIN shop_inventory_partnerships p ON p.id = l.partnership_id
         JOIN shop_profiles partner ON partner.id = CASE WHEN p.requester_shop_id = $1
                  THEN p.recipient_shop_id ELSE p.requester_shop_id END
         JOIN products product ON product.id = l.borrower_product_id
         LEFT JOIN LATERAL (
             SELECT jsonb_agg(jsonb_build_object(
                        'id', s.id, 'direction', s.direction, 'shippedQuantity', s.shipped_quantity,
                        'receivedQuantity', COALESCE(receipts.quantity, 0), 'shippedAt', s.shipped_at
                    ) ORDER BY s.id) AS items,
                    SUM(CASE WHEN s.direction = 'LOAN' THEN receipts.quantity ELSE -receipts.quantity END) AS outstanding
             FROM shop_inventory_loan_shipments s
             LEFT JOIN LATERAL (
                 SELECT SUM(received_quantity) AS quantity
                 FROM shop_inventory_loan_receipts WHERE shipment_id=s.id
             ) receipts ON true
             WHERE s.loan_id=l.id
         ) shipments ON true
         WHERE $1 IN (p.requester_shop_id, p.recipient_shop_id)
         ORDER BY l.id DESC LIMIT 100`,
        [shopId],
    );
}

export async function requestInventoryLoan(
    shopId: number,
    userId: number,
    input: { partnershipId: number; warehouseId: number; productId: number; quantity: number },
) {
    return AppDataSource.transaction(async manager => {
        const [partnership] = await manager.query(
            `SELECT id FROM shop_inventory_partnerships
             WHERE id = $1 AND status = 'ACTIVE' AND $2 IN (requester_shop_id, recipient_shop_id)
             FOR UPDATE`,
            [input.partnershipId, shopId],
        );
        if (!partnership) return null;

        const [loan] = await manager.query(
            `INSERT INTO shop_inventory_loans
                (partnership_id, borrower_shop_id, borrower_product_id, borrower_warehouse_id, requested_quantity, requested_by)
             SELECT $1, $2, p.id, w.id, $5, $6
             FROM products p
             JOIN warehouses w ON w.id = $4 AND w.shop_id = $2 AND w.is_active
             WHERE p.id = $3 AND p.shop_id = $2 AND p.is_active
             RETURNING id`,
            [partnership.id, shopId, input.productId, input.warehouseId, input.quantity, userId],
        );
        return loan ?? null;
    });
}
