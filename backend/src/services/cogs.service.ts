import { AppDataSource } from '../config/db.config';
import { InventoryLot } from '../inventory/lot.entity';
import { ShopProfile } from '../system/entities';
import { Product } from '../product/entities';
import { EntityManager } from 'typeorm';
import { lockShopMutation } from '../utils/shop-mutation-lock';

/**
 * COGS Service — Tính giá vốn hàng bán theo FIFO hoặc Bình quân gia quyền (AVG).
 *
 * calculateCOGS: Tính giá vốn khi xuất bán (trừ tồn kho lô)
 * addInventoryLot: Tạo lô tồn kho khi nhập hàng
 * getWeightedAvgCost: Giá bình quân gia quyền hiện tại
 * getInventoryValuation: Giá trị tồn kho
 */
export class COGSService {
    private lotRepo = AppDataSource.getRepository(InventoryLot);
    private shopRepo = AppDataSource.getRepository(ShopProfile);
    private productRepo = AppDataSource.getRepository(Product);

    /** Lấy phương pháp tính giá vốn hiện tại */
    async getCostingMethod(shopId?: number, manager?: EntityManager): Promise<'FIFO' | 'AVG'> {
        if (!shopId) throw new Error('Validation: Shop is required for costing');
        const repo = manager ? manager.getRepository(ShopProfile) : this.shopRepo;
        const select = { costingMethod: true } as const;
        const shop = await repo.findOne({ where: { shopId }, select }) ??
            await repo.findOne({ where: { id: shopId }, select });
        if (!shop) throw new Error('Validation: Shop not found for costing');
        return shop.costingMethod === 'FIFO' ? 'FIFO' : 'AVG';
    }

    /**
     * Tính giá vốn cho một sản phẩm khi bán `quantity` đơn vị.
     * Trả về: { totalCost, unitCost, lotDeductions }
     * lotDeductions là danh sách các lô bị trừ (để cập nhật remaining_qty sau).
     */
    async calculateCOGS(productId: number, quantity: number, method?: 'FIFO' | 'AVG', shopId?: number, manager?: EntityManager): Promise<{
        totalCost: number;
        unitCost: number;
        lotDeductions: { lotId: number; qty: number; costPrice: number }[];
    }> {
        if (!shopId) throw new Error('Validation: Shop is required for costing');
        if (!Number.isFinite(quantity) || quantity <= 0) {
            throw new Error('Validation: COGS quantity must be greater than 0');
        }
        const costingMethod = method || await this.getCostingMethod(shopId, manager);

        if (costingMethod === 'FIFO') {
            return this.calculateFIFO(productId, quantity, shopId, manager);
        } else {
            return this.calculateAvg(productId, quantity, shopId, manager);
        }
    }

    /** FIFO: Lấy lô cũ nhất trước */
    private async calculateFIFO(productId: number, quantity: number, shopId?: number, manager?: EntityManager) {
        const qb = (manager ? manager.getRepository(InventoryLot) : this.lotRepo)
            .createQueryBuilder('l')
            .where('l.product_id = :productId AND l.remaining_qty > 0', { productId });
        if (shopId) qb.andWhere('l.shop_id = :shopId', { shopId });
        qb.orderBy('l.lot_date', 'ASC').addOrderBy('l.id', 'ASC');
        const lots = await qb.getMany();

        let remaining = quantity;
        let totalCost = 0;
        const lotDeductions: { lotId: number; qty: number; costPrice: number }[] = [];

        for (const lot of lots) {
            if (remaining <= 0) break;
            const take = Math.min(remaining, lot.remainingQty);
            totalCost += take * Number(lot.costPrice);
            lotDeductions.push({ lotId: lot.id, qty: take, costPrice: Number(lot.costPrice) });
            remaining -= take;
        }

        if (remaining > 0) {
            throw new Error(
                `Validation: Inventory lots for product ${productId} are short by ${remaining}`,
            );
        }

        const unitCost = quantity > 0 ? totalCost / quantity : 0;
        return { totalCost, unitCost, lotDeductions };
    }

    /** Bình quân gia quyền: trung bình từ tất cả lô có tồn */
    private async calculateAvg(productId: number, quantity: number, shopId: number, manager?: EntityManager) {
        const balance = await this.getAverageBalance(shopId, productId, manager ?? AppDataSource.manager);
        if (balance.quantity < quantity) {
            throw new Error(`Validation: Inventory lots for product ${productId} are short by ${quantity - balance.quantity}`);
        }
        const totalCost = quantity === balance.quantity
            ? balance.value
            : Math.round(balance.value * quantity / balance.quantity * 100) / 100;
        const unitCost = totalCost / quantity;

        // Trừ lô theo FIFO (dù tính giá AVG, vẫn phải trừ remaining_qty)
        const lotsQb = (manager ? manager.getRepository(InventoryLot) : this.lotRepo)
            .createQueryBuilder('l')
            .where('l.product_id = :productId AND l.remaining_qty > 0', { productId });
        if (shopId) lotsQb.andWhere('l.shop_id = :shopId', { shopId });
        lotsQb.orderBy('l.lot_date', 'ASC').addOrderBy('l.id', 'ASC');
        const lots = await lotsQb.getMany();

        let remaining = quantity;
        const lotDeductions: { lotId: number; qty: number; costPrice: number }[] = [];
        for (const lot of lots) {
            if (remaining <= 0) break;
            const take = Math.min(remaining, lot.remainingQty);
            lotDeductions.push({ lotId: lot.id, qty: take, costPrice: Number(lot.costPrice) });
            remaining -= take;
        }
        if (remaining > 0) {
            throw new Error(
                `Validation: Inventory lots for product ${productId} are short by ${remaining}`,
            );
        }

        return { totalCost, unitCost, lotDeductions };
    }

    private async getAverageBalance(shopId: number, productId: number, manager: EntityManager) {
        const [row] = await manager.query(`
            SELECT COALESCE(SUM(l.remaining_qty), 0) AS quantity,
                   COALESCE(p.average_inventory_value, SUM(l.remaining_qty::numeric * l.cost_price), 0) AS value
            FROM products p LEFT JOIN inventory_lots l ON l.product_id=p.id AND l.shop_id=p.shop_id AND l.remaining_qty>0
            WHERE p.id=$1 AND p.shop_id=$2
            GROUP BY p.id, p.average_inventory_value
        `, [productId, shopId]);
        if (!row) throw new Error('Validation: Product does not belong to the active shop');
        return { quantity: Number(row.quantity), value: Number(row.value) };
    }

    /** Record a stock-value change before changing lot quantities, within the same transaction. */
    async recordAverageMovement(shopId: number, productId: number, quantityDelta: number,
        valueDelta: number | undefined, manager: EntityManager) {
        if (await this.getCostingMethod(shopId, manager) !== 'AVG') return;
        const before = await this.getAverageBalance(shopId, productId, manager);
        const quantity = before.quantity + quantityDelta;
        if (quantity < 0) throw new Error('Validation: Inventory lots are short');
        const delta = valueDelta ?? (quantityDelta * before.value / before.quantity);
        const value = quantity === 0 ? 0 : Math.round((before.value + delta) * 100) / 100;
        if (!Number.isFinite(value) || value < 0) throw new Error('Validation: Invalid inventory value');
        await manager.query(`
            UPDATE products SET average_inventory_value=$3,
                cost_price=CASE WHEN $4::numeric > 0 THEN ROUND($3::numeric / $4::numeric, 2) ELSE cost_price END
            WHERE id=$1 AND shop_id=$2
        `, [productId, shopId, value, quantity]);
    }

    /** Xác nhận trừ tồn kho lô sau khi bán thành công */
    async commitLotDeductions(deductions: { lotId: number; qty: number }[], manager?: EntityManager) {
        for (const d of deductions) {
            const qb = manager
                ? manager.createQueryBuilder().update(InventoryLot)
                : this.lotRepo.createQueryBuilder().update(InventoryLot);
            const result = await qb
                .set({ remainingQty: () => `remaining_qty - ${d.qty}` })
                .where('id = :id AND remaining_qty >= :qty', { id: d.lotId, qty: d.qty })
                .execute();
            if (result.affected !== 1) {
                throw new Error(`Validation: Inventory lot ${d.lotId} no longer has enough stock`);
            }
        }
    }

    /** Thêm lô tồn kho khi nhập hàng */
    async addInventoryLot(data: {
        productId: number;
        quantity: number;
        costPrice: number;
        purchaseId?: number;
        batchId?: number;
        notes?: string;
        shopId?: number;
        lotDate?: Date;
    }, manager?: EntityManager): Promise<InventoryLot> {
        if (!manager) {
            return AppDataSource.transaction(async transaction => {
                if (!data.shopId) throw new Error('Validation: Shop is required for inventory lot');
                await lockShopMutation(transaction, data.shopId);
                return this.addInventoryLot(data, transaction);
            });
        }
        if (!data.shopId) {
            throw new Error('Validation: Shop is required for inventory lot');
        }
        if (!Number.isFinite(data.quantity) || data.quantity <= 0) {
            throw new Error('Validation: Inventory lot quantity must be greater than 0');
        }
        if (!Number.isFinite(data.costPrice) || data.costPrice < 0) {
            throw new Error('Validation: Inventory lot cost must be non-negative');
        }
        const productRepo = manager
            ? manager.getRepository(Product)
            : this.productRepo;
        const productExists = await productRepo.exists({
            where: { id: data.productId, shopId: data.shopId },
        });
        if (!productExists) {
            throw new Error('Validation: Product does not belong to the active shop');
        }
        const repo = manager ? manager.getRepository(InventoryLot) : this.lotRepo;
        const lot = repo.create({
            productId: data.productId,
            initialQty: data.quantity,
            remainingQty: data.quantity,
            costPrice: data.costPrice,
            lotDate: data.lotDate || new Date(),
            purchaseId: data.purchaseId,
            batchId: data.batchId,
            notes: data.notes,
            shopId: data.shopId,
        });
        const method = await this.getCostingMethod(data.shopId, manager);
        if (method === 'AVG') {
            const cost = Math.round(data.costPrice * 100) / 100;
            await this.recordAverageMovement(data.shopId, data.productId, data.quantity, data.quantity * cost, manager);
        }
        const saved = await repo.save(lot);
        if (method === 'FIFO') await this.updateAvgCostOnProduct(data.productId, data.shopId, manager);

        return saved;
    }

    /** Keep lot quantities consistent with the physical stock adjustment. */
    async adjustForStockTake(shopId: number, productId: number, difference: number, date: Date, manager: EntityManager) {
        if (difference > 0) {
            const product = await manager.findOneByOrFail(Product, { id: productId, shopId });
            await this.addInventoryLot({ shopId, productId, quantity: difference,
                costPrice: Number(product.costPrice || 0), lotDate: date,
                notes: 'Điều chỉnh tăng theo kiểm kê' }, manager);
        } else if (difference < 0) {
            await this.recordAverageMovement(shopId, productId, difference, undefined, manager);
            const lots = await manager.getRepository(InventoryLot).createQueryBuilder('l')
                .where('l.shop_id = :shopId AND l.product_id = :productId AND l.remaining_qty > 0', { shopId, productId })
                .orderBy('l.lot_date', 'ASC').addOrderBy('l.id', 'ASC').getMany();
            let remaining = -difference;
            for (const lot of lots) {
                const take = Math.min(remaining, Number(lot.remainingQty));
                lot.remainingQty = Number(lot.remainingQty) - take;
                await manager.save(InventoryLot, lot);
                remaining -= take;
                if (remaining <= 0) break;
            }
            if (remaining > 0) throw new Error('Validation: Tồn lô không khớp tồn kho, cần đối soát trước khi hoàn tất kiểm kê');
            if (await this.getCostingMethod(shopId, manager) === 'FIFO') {
                await this.updateAvgCostOnProduct(productId, shopId, manager);
            }
        }
    }

    /** Cập nhật giá bình quân gia quyền trên sản phẩm */
    private async updateAvgCostOnProduct(productId: number, shopId?: number, manager?: EntityManager) {
        const qb = manager
            ? manager.createQueryBuilder(InventoryLot, 'l')
            : this.lotRepo.createQueryBuilder('l');
        qb.select('SUM(l.remaining_qty * l.cost_price) / NULLIF(SUM(l.remaining_qty), 0)', 'avgCost')
            .where('l.product_id = :productId AND l.remaining_qty > 0', { productId });
        if (shopId) qb.andWhere('l.shop_id = :shopId', { shopId });
        const avgResult = await qb.getRawOne();

        const avgCost = Number(avgResult?.avgCost || 0);
        if (avgCost > 0) {
            if (manager) {
                await manager.update(Product, productId, { costPrice: avgCost });
            } else {
                await this.productRepo.update(productId, { costPrice: avgCost });
            }
        }
    }

    /** Giá bình quân gia quyền hiện tại */
    async getWeightedAvgCost(productId: number, shopId?: number): Promise<number> {
        if (!shopId) throw new Error('Validation: Shop is required for costing');
        const balance = await this.getAverageBalance(shopId, productId, AppDataSource.manager);
        if (balance.quantity > 0) return balance.value / balance.quantity;
        throw new Error('Validation: Product has no remaining inventory lots');
    }

    /** Giá trị tồn kho theo sản phẩm hoặc toàn bộ */
    async getInventoryValuation(productId?: number, shopId?: number) {
        const qb = this.lotRepo
            .createQueryBuilder('l')
            .select('l.product_id', 'productId')
            .addSelect('SUM(l.remaining_qty)', 'totalQty')
            .addSelect('SUM(l.remaining_qty * l.cost_price)', 'totalValue')
            .where('l.remaining_qty > 0');

        if (shopId) qb.andWhere('l.shop_id = :shopId', { shopId });
        if (productId) qb.andWhere('l.product_id = :productId', { productId });

        qb.groupBy('l.product_id');

        if (shopId && await this.getCostingMethod(shopId) === 'AVG') {
            qb.innerJoin(Product, 'p', 'p.id=l.product_id AND p.shop_id=l.shop_id')
                .addGroupBy('p.average_inventory_value')
                .select('l.product_id', 'productId')
                .addSelect('SUM(l.remaining_qty)', 'totalQty')
                .addSelect('COALESCE(p.average_inventory_value, SUM(l.remaining_qty * l.cost_price))', 'totalValue');
        }
        const rows = await qb.getRawMany();
        const items = rows.map(r => ({
            productId: Number(r.productId),
            totalQty: Number(r.totalQty),
            totalValue: Number(r.totalValue),
            avgCost: Number(r.totalQty) > 0 ? Number(r.totalValue) / Number(r.totalQty) : 0,
        }));

        const grandTotal = items.reduce((s, i) => s + i.totalValue, 0);
        return { items, grandTotal };
    }

    /** Danh sách lô tồn kho theo sản phẩm */
    async getLotsByProduct(productId: number, shopId?: number) {
        const whereClause: any = { productId };
        if (shopId) whereClause.shopId = shopId;
        return this.lotRepo.find({
            where: whereClause,
            order: { lotDate: 'ASC' },
        });
    }
}

