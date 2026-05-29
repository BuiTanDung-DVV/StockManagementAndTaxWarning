import { AppDataSource } from '../config/db.config';
import { Product, Category, CostType, ProductCostItem, ProductBatch, UnitConversion, ProductPriceHistory } from '../product/entities';
import { InventoryMovement, InventoryStock, Warehouse } from '../inventory/entities';
import { Brackets } from 'typeorm';
import { COGSService } from './cogs.service';

export class ProductService {
    private productRepo = AppDataSource.getRepository(Product);
    private categoryRepo = AppDataSource.getRepository(Category);
    private costTypeRepo = AppDataSource.getRepository(CostType);
    private costItemRepo = AppDataSource.getRepository(ProductCostItem);
    private batchRepo = AppDataSource.getRepository(ProductBatch);
    private unitRepo = AppDataSource.getRepository(UnitConversion);
    private priceHistoryRepo = AppDataSource.getRepository(ProductPriceHistory);
    private stockRepo = AppDataSource.getRepository(InventoryStock);
    private movementRepo = AppDataSource.getRepository(InventoryMovement);
    private warehouseRepo = AppDataSource.getRepository(Warehouse);
    private cogsService = new COGSService();

    // === PRODUCT CRUD ===
    async findAllProducts(shopId: number, page = 1, limit = 20, search?: string) {
        const qb = this.productRepo.createQueryBuilder('p')
            .leftJoinAndSelect('p.category', 'category')
            .leftJoinAndSelect('p.costItems', 'costItems')
            .leftJoinAndSelect('costItems.costType', 'costType')
            .where('p.shopId = :shopId AND p.isActive = :isActive', { shopId, isActive: true });

        if (search) {
            qb.andWhere(new Brackets(sub => {
                sub.where('p.name LIKE :search', { search: `%${search}%` })
                   .orWhere('p.sku LIKE :search', { search: `%${search}%` })
                   .orWhere('p.barcode LIKE :search', { search: `%${search}%` });
            }));
        }

        const [items, total] = await qb.skip((page - 1) * limit)
                                       .take(limit)
                                       .orderBy('p.createdAt', 'DESC')
                                       .getManyAndCount();

        const itemsWithStock = await this.attachCurrentStock(items, shopId);
        return { items: itemsWithStock, total, page, limit, totalPages: Math.ceil(total / limit) };
    }

    async findProductById(shopId: number, id: number) {
        const product = await this.loadProductEntity(shopId, id);
        const [productWithStock] = await this.attachCurrentStock([product], shopId);
        return productWithStock;
    }

    async createProduct(shopId: number, dto: any) {
        const sku = String(dto.sku || '').trim() || `SKU${Date.now().toString().slice(-8)}`;
        const existsSku = await this.productRepo.findOne({ where: { sku, shopId } });
        if (existsSku) throw new Error('Mã SKU này đã tồn tại trong hệ thống');
        if (dto.barcode) {
            const existsBarcode = await this.productRepo.findOne({ where: { barcode: dto.barcode, shopId } });
            if (existsBarcode) throw new Error('Mã vạch này đã tồn tại trong hệ thống');
        }
        const openingQty = Number(dto.currentStock ?? dto.openingStock ?? 0);
        const providedWarehouseId = Number(dto.warehouseId || 0);
        const { currentStock, openingStock, warehouseId, ...productPayload } = dto;

        const product = this.productRepo.create({ ...productPayload, sku, shopId });
        let saved: Product;
        try {
            saved = await this.productRepo.save(product as any) as Product;
        } catch (e: any) {
            if (e.code === '23505' || (e.message && e.message.includes('unique constraint'))) {
                if (e.message && e.message.includes('barcode')) throw new Error('Mã vạch này đã tồn tại trong hệ thống');
                throw new Error('Mã SKU này đã tồn tại trong hệ thống');
            }
            throw e;
        }

        if (openingQty > 0) {
            const targetWarehouseId = providedWarehouseId > 0 ? providedWarehouseId : await this.ensureDefaultWarehouseId(shopId);
            await this.upsertOpeningStock(saved.id, targetWarehouseId, openingQty, shopId);
            await this.cogsService.addInventoryLot({
                productId: saved.id,
                quantity: openingQty,
                costPrice: Number(productPayload.costPrice || 0),
                notes: 'Opening stock on product creation',
                shopId,
            });
        }

        return this.findProductById(shopId, saved.id);
    }

    async updateProduct(shopId: number, id: number, dto: any) {
        const product = await this.loadProductEntity(shopId, id);
        if (dto.sku && dto.sku !== product.sku) {
            const existsSku = await this.productRepo.findOne({ where: { sku: dto.sku, shopId } });
            if (existsSku) throw new Error('Mã SKU này đã tồn tại trong hệ thống');
        }
        if (dto.barcode && dto.barcode !== product.barcode) {
            const existsBarcode = await this.productRepo.findOne({ where: { barcode: dto.barcode, shopId } });
            if (existsBarcode) throw new Error('Mã vạch này đã tồn tại trong hệ thống');
        }

        const { currentStock, openingStock, warehouseId, ...productPayload } = dto;
        Object.assign(product, productPayload);
        try {
            await this.productRepo.save(product);
        } catch (e: any) {
            if (e.code === '23505' || (e.message && e.message.includes('unique constraint'))) {
                if (e.message && e.message.includes('barcode')) throw new Error('Mã vạch này đã tồn tại trong hệ thống');
                throw new Error('Mã SKU này đã tồn tại trong hệ thống');
            }
            throw e;
        }

        const nextStock = currentStock ?? openingStock;
        if (nextStock !== undefined && nextStock !== null && nextStock !== '') {
            await this.setCurrentStock(
                product.id,
                Number(warehouseId || 0) || undefined,
                Number(nextStock),
                shopId,
            );
        }

        return this.findProductById(shopId, id);
    }

    async deleteProduct(shopId: number, id: number) {
        const product = await this.loadProductEntity(shopId, id);
        product.isActive = false;
        return this.productRepo.save(product);
    }

    // === PRICING ===
    async calculateSuggestedPrice(shopId: number, productId: number) {
        const product = await this.findProductById(shopId, productId);
        const costItems = await this.costItemRepo.find({ where: { product: { id: productId, shopId } as any, shopId } as any });

        let totalAdditional = 0;
        for (const item of costItems) {
            if (item.calculationType === 'FIXED') {
                totalAdditional += Number(item.amount);
            } else if (item.calculationType === 'PERCENTAGE') {
                totalAdditional += Number(product.costPrice) * Number(item.amount) / 100;
            }
        }

        const baseCost = Number(product.costPrice) - Number(product.supplierDiscount || 0) + totalAdditional;
        const afterTax = baseCost * (1 + Number(product.taxRate || 0) / 100);
        const suggested = afterTax * (1 + Number(product.profitMargin || 0) / 100);

        product.totalAdditionalCost = totalAdditional;
        product.suggestedPrice = Math.round(suggested);
        await this.productRepo.save(product);

        return { costPrice: product.costPrice, suggestedPrice: product.suggestedPrice };
    }

    // === COST TYPES ===
    async findAllCostTypes(shopId: number) { return this.costTypeRepo.find({ where: { isActive: true, shopId }, order: { sortOrder: 'ASC' } }); }
    async createCostType(shopId: number, dto: Partial<CostType>) {
        if (await this.costTypeRepo.findOne({ where: { name: dto.name as string, shopId } })) throw new Error('Cost type name exists');
        return this.costTypeRepo.save(this.costTypeRepo.create({ ...dto, shopId }));
    }

    // === COST ITEMS ===
    async addCostItem(shopId: number, productId: number, costTypeId: number, amount: number, calculationType = 'FIXED', notes?: string) {
        const product = await this.findProductById(shopId, productId);
        const costType = await this.costTypeRepo.findOne({ where: { id: costTypeId, shopId } });
        if (!costType) throw new Error('Cost type not found');
        const item = this.costItemRepo.create({ product, costType, amount, calculationType, notes, shopId });
        await this.costItemRepo.save(item);
        await this.calculateSuggestedPrice(shopId, productId);
        return item;
    }
    async removeCostItem(shopId: number, id: number) {
        const item = await this.costItemRepo.findOne({ where: { id, shopId }, relations: ['product'] });
        if (!item) throw new Error('Cost item not found');
        const productId = item.product.id;
        await this.costItemRepo.remove(item);
        await this.calculateSuggestedPrice(shopId, productId);
    }

    // === PRICE HISTORY ===
    async getPriceHistory(shopId: number, productId: number) { return this.priceHistoryRepo.find({ where: { product: { id: productId, shopId } as any, shopId } as any, order: { changedAt: 'DESC' } }); }
    
    // === BATCHES ===
    async findBatches(shopId: number, productId: number) { return this.batchRepo.find({ where: { product: { id: productId, shopId } as any, isActive: true, shopId } as any }); }
    async createBatch(shopId: number, productId: number, dto: Partial<ProductBatch>) {
        const product = await this.findProductById(shopId, productId);
        return this.batchRepo.save(this.batchRepo.create({ ...dto, product, shopId }));
    }

    // === UNIT CONVERSIONS ===
    async findConversions(shopId: number, productId: number) { return this.unitRepo.find({ where: { product: { id: productId, shopId } as any, shopId } as any }); }
    async createConversion(shopId: number, productId: number, dto: Partial<UnitConversion>) {
        const product = await this.findProductById(shopId, productId);
        return this.unitRepo.save(this.unitRepo.create({ ...dto, product, shopId }));
    }

    // === CATEGORIES ===
    async findAllCategories(shopId: number) { return this.categoryRepo.find({ where: { isActive: true, shopId } }); }
    async createCategory(shopId: number, dto: Partial<Category>) { return this.categoryRepo.save(this.categoryRepo.create({ ...dto, shopId })); }

    private async loadProductEntity(shopId: number, id: number) {
        const product = await this.productRepo.findOne({
            where: { id, shopId },
            relations: ['category', 'costItems', 'costItems.costType'],
        });
        if (!product) throw new Error('Product not found');
        return product;
    }

    private async attachCurrentStock(items: Product[], shopId?: number) {
        if (!items.length) return items;

        const productIds = items.map((item) => item.id);
        const qb = this.stockRepo.createQueryBuilder('s')
            .select('s.product_id', 'productId')
            .addSelect('COALESCE(SUM(s.quantity), 0)', 'qty')
            .where('s.product_id IN (:...productIds)', { productIds });

        if (shopId) {
            qb.andWhere('s.shop_id = :shopId', { shopId });
        }

        const stockRows = await qb.groupBy('s.product_id').getRawMany();

        const stockMap = new Map<number, number>();
        for (const row of stockRows) {
            stockMap.set(Number(row.productId), Number(row.qty || 0));
        }

        return items.map((item: any) => ({
            ...item,
            currentStock: stockMap.get(item.id) ?? 0,
        }));
    }

    private async ensureDefaultWarehouseId(shopId: number) {
        let warehouse = await this.warehouseRepo.findOne({ where: { shopId } });
        if (!warehouse) {
            warehouse = await this.warehouseRepo.save(this.warehouseRepo.create({
                name: `Kho mac dinh ${shopId}`,
                isActive: true,
                shopId
            }));
        }
        return warehouse.id;
    }

    private async upsertOpeningStock(productId: number, warehouseId: number, quantity: number, shopId: number) {
        let stock = await this.stockRepo.findOne({ where: { productId, warehouseId, shopId } as any });
        if (!stock) {
            stock = this.stockRepo.create({
                productId,
                warehouseId,
                quantity: 0,
                updatedAt: new Date(),
                shopId
            });
        }
        stock.quantity = Number(stock.quantity || 0) + Number(quantity);
        stock.updatedAt = new Date();
        await this.stockRepo.save(stock);

        await this.movementRepo.save(this.movementRepo.create({
            productId,
            warehouseId,
            movementType: 'IN',
            quantity: Number(quantity),
            referenceType: 'OPENING',
            referenceId: productId,
            notes: 'Opening stock on product creation',
            shopId
        }));
    }

    private async setCurrentStock(productId: number, warehouseId: number | undefined, quantity: number, shopId: number) {
        const targetWarehouseId = warehouseId ?? await this.ensureDefaultWarehouseId(shopId);
        const warehouse = await this.warehouseRepo.findOne({ where: { id: targetWarehouseId, shopId, isActive: true } as any });
        if (!warehouse) throw new Error('Warehouse not found');

        let stock = await this.stockRepo.findOne({ where: { productId, warehouseId: targetWarehouseId, shopId } as any });
        if (!stock) {
            stock = this.stockRepo.create({
                productId,
                warehouseId: targetWarehouseId,
                quantity: 0,
                updatedAt: new Date(),
                shopId,
            });
        }

        const previousQty = Number(stock.quantity || 0);
        const nextQty = Number.isFinite(quantity) && quantity >= 0 ? quantity : 0;
        const difference = nextQty - previousQty;

        stock.quantity = nextQty;
        stock.updatedAt = new Date();
        await this.stockRepo.save(stock);

        if (difference !== 0) {
            await this.movementRepo.save(this.movementRepo.create({
                productId,
                warehouseId: targetWarehouseId,
                movementType: difference > 0 ? 'IN' : 'OUT',
                quantity: Math.abs(difference),
                referenceType: 'PRODUCT_ADJUSTMENT',
                referenceId: productId,
                notes: 'Stock adjusted from product update',
                shopId,
            }));
        }
    }
}
