import { AppDataSource } from '../config/db.config';
import { InventoryLot } from '../inventory/lot.entity';
import { ShopProfile } from '../system/entities';
import { Product } from '../product/entities';
import { EntityManager } from 'typeorm';

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
    async getCostingMethod(shopId?: number): Promise<'FIFO' | 'AVG'> {
        if (!shopId) throw new Error('Validation: Shop is required for costing');
        const shop = await this.shopRepo.findOne({ where: { id: shopId } });
        if (!shop) throw new Error('Validation: Shop not found for costing');
        return shop.costingMethod === 'FIFO' ? 'FIFO' : 'AVG';
    }

    /**
     * Tính giá vốn cho một sản phẩm khi bán `quantity` đơn vị.
     * Trả về: { totalCost, unitCost, lotDeductions }
     * lotDeductions là danh sách các lô bị trừ (để cập nhật remaining_qty sau).
     */
    async calculateCOGS(productId: number, quantity: number, method?: 'FIFO' | 'AVG', shopId?: number): Promise<{
        totalCost: number;
        unitCost: number;
        lotDeductions: { lotId: number; qty: number; costPrice: number }[];
    }> {
        if (!Number.isFinite(quantity) || quantity <= 0) {
            throw new Error('Validation: COGS quantity must be greater than 0');
        }
        const costingMethod = method || await this.getCostingMethod(shopId);

        if (costingMethod === 'FIFO') {
            return this.calculateFIFO(productId, quantity, shopId);
        } else {
            return this.calculateAvg(productId, quantity, shopId);
        }
    }

    /** FIFO: Lấy lô cũ nhất trước */
    private async calculateFIFO(productId: number, quantity: number, shopId?: number) {
        const qb = this.lotRepo
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
    private async calculateAvg(productId: number, quantity: number, shopId?: number) {
        const avgQb = this.lotRepo
            .createQueryBuilder('l')
            .select('SUM(l.remaining_qty * l.cost_price)', 'totalValue')
            .addSelect('SUM(l.remaining_qty)', 'totalQty')
            .where('l.product_id = :productId AND l.remaining_qty > 0', { productId });
        if (shopId) avgQb.andWhere('l.shop_id = :shopId', { shopId });
        const avgResult = await avgQb.getRawOne();

        const totalValue = Number(avgResult?.totalValue || 0);
        const totalQty = Number(avgResult?.totalQty || 0);

        if (totalQty < quantity) {
            throw new Error(
                `Validation: Inventory lots for product ${productId} are short by ${quantity - totalQty}`,
            );
        }
        const unitCost = totalValue / totalQty;

        const totalCost = unitCost * quantity;

        // Trừ lô theo FIFO (dù tính giá AVG, vẫn phải trừ remaining_qty)
        const lotsQb = this.lotRepo
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
    }, manager?: EntityManager) {
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
        const product = await productRepo.findOne({
            where: { id: data.productId, shopId: data.shopId },
        });
        if (!product) {
            throw new Error('Validation: Product does not belong to the active shop');
        }
        const repo = manager ? manager.getRepository(InventoryLot) : this.lotRepo;
        const lot = repo.create({
            productId: data.productId,
            initialQty: data.quantity,
            remainingQty: data.quantity,
            costPrice: data.costPrice,
            lotDate: new Date(),
            purchaseId: data.purchaseId,
            batchId: data.batchId,
            notes: data.notes,
            shopId: data.shopId,
        });
        const saved = await repo.save(lot);

        // Cập nhật giá bình quân trên products.cost_price
        await this.updateAvgCostOnProduct(data.productId, data.shopId, manager);

        return saved;
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
        const product = await this.productRepo.findOne({
            where: { id: productId, shopId },
        });
        if (!product) {
            throw new Error('Validation: Product does not belong to the active shop');
        }
        const qb = this.lotRepo
            .createQueryBuilder('l')
            .select('SUM(l.remaining_qty * l.cost_price) / NULLIF(SUM(l.remaining_qty), 0)', 'avgCost')
            .where('l.product_id = :productId AND l.remaining_qty > 0', { productId });
        if (shopId) qb.andWhere('l.shop_id = :shopId', { shopId });
        const avgResult = await qb.getRawOne();

        if (Number(avgResult?.avgCost) >= 0 && avgResult?.avgCost != null) {
            return Number(avgResult.avgCost);
        }
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

