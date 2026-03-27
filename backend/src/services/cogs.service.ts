import { AppDataSource } from '../config/db.config';
import { InventoryLot } from '../inventory/lot.entity';
import { ShopProfile } from '../system/entities';
import { Product } from '../product/entities';

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
    async getCostingMethod(): Promise<'FIFO' | 'AVG'> {
        const shop = await this.shopRepo.findOne({ where: { id: 1 } });
        return (shop?.costingMethod === 'FIFO' ? 'FIFO' : 'AVG');
    }

    /**
     * Tính giá vốn cho một sản phẩm khi bán `quantity` đơn vị.
     * Trả về: { totalCost, unitCost, lotDeductions }
     * lotDeductions là danh sách các lô bị trừ (để cập nhật remaining_qty sau).
     */
    async calculateCOGS(productId: number, quantity: number, method?: 'FIFO' | 'AVG'): Promise<{
        totalCost: number;
        unitCost: number;
        lotDeductions: { lotId: number; qty: number; costPrice: number }[];
    }> {
        const costingMethod = method || await this.getCostingMethod();

        if (costingMethod === 'FIFO') {
            return this.calculateFIFO(productId, quantity);
        } else {
            return this.calculateAvg(productId, quantity);
        }
    }

    /** FIFO: Lấy lô cũ nhất trước */
    private async calculateFIFO(productId: number, quantity: number) {
        const lots = await this.lotRepo
            .createQueryBuilder('l')
            .where('l.product_id = :productId AND l.remaining_qty > 0', { productId })
            .orderBy('l.lot_date', 'ASC')
            .addOrderBy('l.id', 'ASC')
            .getMany();

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

        // Nếu còn thiếu (hết lô), fallback giá trung bình từ products.cost_price
        if (remaining > 0) {
            const product = await this.productRepo.findOne({ where: { id: productId } });
            const fallbackPrice = Number(product?.costPrice || 0);
            totalCost += remaining * fallbackPrice;
        }

        const unitCost = quantity > 0 ? totalCost / quantity : 0;
        return { totalCost, unitCost, lotDeductions };
    }

    /** Bình quân gia quyền: trung bình từ tất cả lô có tồn */
    private async calculateAvg(productId: number, quantity: number) {
        const avgResult = await this.lotRepo
            .createQueryBuilder('l')
            .select('SUM(l.remaining_qty * l.cost_price)', 'totalValue')
            .addSelect('SUM(l.remaining_qty)', 'totalQty')
            .where('l.product_id = :productId AND l.remaining_qty > 0', { productId })
            .getRawOne();

        const totalValue = Number(avgResult?.totalValue || 0);
        const totalQty = Number(avgResult?.totalQty || 0);

        let unitCost: number;
        if (totalQty > 0) {
            unitCost = totalValue / totalQty;
        } else {
            // Fallback: dùng cost_price từ products
            const product = await this.productRepo.findOne({ where: { id: productId } });
            unitCost = Number(product?.costPrice || 0);
        }

        const totalCost = unitCost * quantity;

        // Trừ lô theo FIFO (dù tính giá AVG, vẫn phải trừ remaining_qty)
        const lots = await this.lotRepo
            .createQueryBuilder('l')
            .where('l.product_id = :productId AND l.remaining_qty > 0', { productId })
            .orderBy('l.lot_date', 'ASC')
            .addOrderBy('l.id', 'ASC')
            .getMany();

        let remaining = quantity;
        const lotDeductions: { lotId: number; qty: number; costPrice: number }[] = [];
        for (const lot of lots) {
            if (remaining <= 0) break;
            const take = Math.min(remaining, lot.remainingQty);
            lotDeductions.push({ lotId: lot.id, qty: take, costPrice: Number(lot.costPrice) });
            remaining -= take;
        }

        return { totalCost, unitCost, lotDeductions };
    }

    /** Xác nhận trừ tồn kho lô sau khi bán thành công */
    async commitLotDeductions(deductions: { lotId: number; qty: number }[]) {
        for (const d of deductions) {
            await this.lotRepo
                .createQueryBuilder()
                .update(InventoryLot)
                .set({ remainingQty: () => `remaining_qty - ${d.qty}` })
                .where('id = :id AND remaining_qty >= :qty', { id: d.lotId, qty: d.qty })
                .execute();
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
    }) {
        const lot = this.lotRepo.create({
            productId: data.productId,
            initialQty: data.quantity,
            remainingQty: data.quantity,
            costPrice: data.costPrice,
            lotDate: new Date(),
            purchaseId: data.purchaseId,
            batchId: data.batchId,
            notes: data.notes,
        });
        const saved = await this.lotRepo.save(lot);

        // Cập nhật giá bình quân trên products.cost_price
        await this.updateAvgCostOnProduct(data.productId);

        return saved;
    }

    /** Cập nhật giá bình quân gia quyền trên sản phẩm */
    private async updateAvgCostOnProduct(productId: number) {
        const avgResult = await this.lotRepo
            .createQueryBuilder('l')
            .select('SUM(l.remaining_qty * l.cost_price) / NULLIF(SUM(l.remaining_qty), 0)', 'avgCost')
            .where('l.product_id = :productId AND l.remaining_qty > 0', { productId })
            .getRawOne();

        const avgCost = Number(avgResult?.avgCost || 0);
        if (avgCost > 0) {
            await this.productRepo.update(productId, { costPrice: avgCost });
        }
    }

    /** Giá bình quân gia quyền hiện tại */
    async getWeightedAvgCost(productId: number): Promise<number> {
        const avgResult = await this.lotRepo
            .createQueryBuilder('l')
            .select('SUM(l.remaining_qty * l.cost_price) / NULLIF(SUM(l.remaining_qty), 0)', 'avgCost')
            .where('l.product_id = :productId AND l.remaining_qty > 0', { productId })
            .getRawOne();

        if (Number(avgResult?.avgCost) > 0) return Number(avgResult.avgCost);

        // Fallback
        const product = await this.productRepo.findOne({ where: { id: productId } });
        return Number(product?.costPrice || 0);
    }

    /** Giá trị tồn kho theo sản phẩm hoặc toàn bộ */
    async getInventoryValuation(productId?: number) {
        const qb = this.lotRepo
            .createQueryBuilder('l')
            .select('l.product_id', 'productId')
            .addSelect('SUM(l.remaining_qty)', 'totalQty')
            .addSelect('SUM(l.remaining_qty * l.cost_price)', 'totalValue')
            .where('l.remaining_qty > 0')
            .groupBy('l.product_id');

        if (productId) {
            qb.andWhere('l.product_id = :productId', { productId });
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
    async getLotsByProduct(productId: number) {
        return this.lotRepo.find({
            where: { productId },
            order: { lotDate: 'ASC' },
        });
    }
}
