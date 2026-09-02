import { AppDataSource } from '../config/db.config';
import { Product, Category, CostType, ProductCostItem, ProductBatch, UnitConversion, ProductPriceHistory } from '../product/entities';
import { InventoryMovement, InventoryStock, Warehouse } from '../inventory/entities';
import { Brackets } from 'typeorm';
import { COGSService } from './cogs.service';
import { ImageStorageService } from './image-storage.service';
import {
    ProductInputError,
    normalizeBatchInput,
    normalizeCategoryInput,
    normalizeCostItemInput,
    normalizeCostTypeInput,
    normalizeProductInput,
    normalizeUnitConversionInput,
} from '../product/product-input.utils';
import {
    vietnameseSearchExpression,
    vietnameseSearchParams,
} from '../common/vietnamese-search.utils';

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
    private imageStorageService = new ImageStorageService();

    // === PRODUCT CRUD ===
    async findAllProducts(shopId: number, page = 1, limit = 20, search?: string, tag?: string) {
        const qb = this.productRepo.createQueryBuilder('p')
            .leftJoinAndSelect('p.category', 'category')
            .leftJoinAndSelect('p.costItems', 'costItems')
            .leftJoinAndSelect('costItems.costType', 'costType')
            .where('p.shopId = :shopId AND p.isActive = :isActive', { shopId, isActive: true });

        if (search?.trim()) {
            const searchParams = vietnameseSearchParams(search);
            qb.andWhere(new Brackets(sub => {
                sub.where(vietnameseSearchExpression('p.name'))
                   .orWhere(vietnameseSearchExpression('p.sku'))
                   .orWhere(vietnameseSearchExpression('p.barcode'));
            }), searchParams);
        }

        if (tag?.trim()) {
            qb.andWhere(
                `EXISTS (
                    SELECT 1
                    FROM unnest(string_to_array(COALESCE(p.tags, ''), ',')) AS tag_value(value)
                    WHERE LOWER(BTRIM(tag_value.value)) = LOWER(:tag)
                )`,
                { tag: tag.trim() },
            );
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
        const input = normalizeProductInput(shopId, dto, {
            requireName: true,
            allowOpeningStock: true,
        });
        const sku = String(input.sku || '').trim() || `SKU${Date.now().toString().slice(-8)}`;
        const existsSku = await this.productRepo.findOne({ where: { sku, shopId, isActive: true } });
        if (existsSku) throw new Error('Mã SKU này đã tồn tại trong hệ thống');
        if (input.barcode) {
            const existsBarcode = await this.productRepo.findOne({ where: { barcode: String(input.barcode), shopId, isActive: true } });
            if (existsBarcode) throw new Error('Mã vạch này đã tồn tại trong hệ thống');
        }
        const openingQty = Number(input.currentStock ?? input.openingStock ?? 0);
        const providedWarehouseId = Number(input.warehouseId || 0);
        const productPayload = { ...input };
        delete productPayload.currentStock;
        delete productPayload.openingStock;
        delete productPayload.warehouseId;

        const product = this.productRepo.create({ ...productPayload, sku, shopId });
        let saved: Product;
        try {
            saved = await this.productRepo.save(product as any) as Product;
        } catch (e: any) {
            const msg = (e.message || '').toLowerCase();
            if (e.code === '23505' || e.code === 'SQLITE_CONSTRAINT' || msg.includes('unique')) {
                if (msg.includes('barcode')) throw new Error('Mã vạch này đã tồn tại trong hệ thống');
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
        const input = normalizeProductInput(shopId, dto);
        const product = await this.loadProductEntity(shopId, id);
        const previousImageUrl = product.imageUrl;
        const imageWasChanged =
            Object.prototype.hasOwnProperty.call(input, 'imageUrl') &&
            input.imageUrl !== previousImageUrl;
        if (input.sku && String(input.sku).trim() !== product.sku) {
            const existsSku = await this.productRepo.findOne({ where: { sku: String(input.sku).trim(), shopId, isActive: true } });
            if (existsSku) throw new Error('Mã SKU này đã tồn tại trong hệ thống');
        }
        if (input.barcode && input.barcode !== product.barcode) {
            const existsBarcode = await this.productRepo.findOne({ where: { barcode: String(input.barcode), shopId, isActive: true } });
            if (existsBarcode) throw new Error('Mã vạch này đã tồn tại trong hệ thống');
        }

        const { currentStock, openingStock, warehouseId, ...productPayload } = input;
        Object.assign(product, productPayload);
        try {
            await this.productRepo.save(product);
        } catch (e: any) {
            const msg = (e.message || '').toLowerCase();
            if (e.code === '23505' || e.code === 'SQLITE_CONSTRAINT' || msg.includes('unique')) {
                if (msg.includes('barcode')) throw new Error('Mã vạch này đã tồn tại trong hệ thống');
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

        if (imageWasChanged && previousImageUrl) {
            try {
                await this.imageStorageService.deleteProductImageByUrl(
                    shopId,
                    previousImageUrl,
                );
            } catch {
                // Product update has succeeded; cleanup must not roll it back.
            }
        }

        return this.findProductById(shopId, id);
    }

    async deleteProduct(shopId: number, id: number) {
        const product = await this.loadProductEntity(shopId, id);
        const previousImageUrl = product.imageUrl;
        product.isActive = false;
        product.imageUrl = null;
        const saved = await this.productRepo.save(product);
        if (previousImageUrl) {
            try {
                await this.imageStorageService.deleteProductImageByUrl(
                    shopId,
                    previousImageUrl,
                );
            } catch {
                // The product is already deactivated; cleanup is best effort.
            }
        }
        return saved;
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
        const input = normalizeCostTypeInput(dto);
        if (await this.costTypeRepo.findOne({ where: { name: input.name as string, shopId } })) throw new Error('Cost type name exists');
        return this.costTypeRepo.save(this.costTypeRepo.create({ ...input, description: input.description ?? undefined, isActive: true, shopId }));
    }

    // === COST ITEMS ===
    async addCostItem(shopId: number, productId: number, costTypeId: number, amount: number, calculationType = 'FIXED', notes?: string) {
        const input = normalizeCostItemInput(costTypeId, amount, calculationType, notes);
        const product = await this.findProductById(shopId, productId);
        const costType = await this.costTypeRepo.findOne({ where: { id: input.costTypeId, shopId } });
        if (!costType) throw new Error('Cost type not found');
        const item = this.costItemRepo.create({ product, costType, amount: input.amount, calculationType: input.calculationType, notes: input.notes ?? undefined, shopId });
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
        const input = normalizeBatchInput(dto);
        return this.batchRepo.save(this.batchRepo.create({
            ...input,
            manufacturingDate: input.manufacturingDate ? new Date(`${input.manufacturingDate}T00:00:00Z`) : undefined,
            expiryDate: input.expiryDate ? new Date(`${input.expiryDate}T00:00:00Z`) : undefined,
            costPrice: input.costPrice ?? undefined,
            supplierName: input.supplierName ?? undefined,
            notes: input.notes ?? undefined,
            isActive: true,
            product,
            shopId,
        }));
    }

    // === UNIT CONVERSIONS ===
    async findConversions(shopId: number, productId: number) { return this.unitRepo.find({ where: { product: { id: productId, shopId } as any, shopId } as any }); }
    async createConversion(shopId: number, productId: number, dto: Partial<UnitConversion>) {
        const product = await this.findProductById(shopId, productId);
        const input = normalizeUnitConversionInput(dto);
        return this.unitRepo.save(this.unitRepo.create({ ...input, sellingPricePerUnit: input.sellingPricePerUnit ?? undefined, product, shopId }));
    }

    // === CATEGORIES ===
    async findAllCategories(shopId: number, search?: string, includeInactive = false) {
        const qb = this.categoryRepo.createQueryBuilder('category')
            .leftJoin('category.products', 'product', 'product.shop_id = :shopId', { shopId })
            .select('category')
            .addSelect('COUNT(product.id)', 'productCount')
            .where('category.shop_id = :shopId', { shopId })
            .groupBy('category.id')
            .orderBy('category.is_active', 'DESC')
            .addOrderBy('category.name', 'ASC');
        if (!includeInactive) qb.andWhere('category.is_active = true');
        if (search?.trim()) {
            qb.andWhere('LOWER(category.name) LIKE LOWER(:search)', { search: `%${search.trim()}%` });
        }
        const { entities, raw } = await qb.getRawAndEntities();
        return entities.map((item, index) => ({
            ...item,
            productCount: Number(raw[index]?.productCount || raw[index]?.productcount || 0),
        }));
    }
    async createCategory(shopId: number, dto: Partial<Category>) {
        const input = normalizeCategoryInput(dto);
        await this.assertCategoryNameAvailable(shopId, input.name);
        return this.categoryRepo.save(this.categoryRepo.create({ ...input, description: input.description ?? undefined, isActive: true, shopId }));
    }

    async updateCategory(shopId: number, id: number, dto: Partial<Category>) {
        const category = await this.categoryRepo.findOne({ where: { id, shopId } });
        if (!category) throw new Error('Category not found');
        const input = normalizeCategoryInput(dto);
        await this.assertCategoryNameAvailable(shopId, input.name, id);
        category.name = input.name;
        category.description = input.description ?? '';
        return this.categoryRepo.save(category);
    }

    async deleteCategory(
        shopId: number,
        id: number,
        input: { action?: unknown; replacementCategoryId?: unknown },
    ) {
        return AppDataSource.transaction(async manager => {
            const categoryRepo = manager.getRepository(Category);
            const category = await categoryRepo.findOne({ where: { id, shopId } });
            if (!category) throw new Error('Category not found');
            const productCount = await manager.getRepository(Product).count({
                where: { shopId, category: { id } } as any,
            });
            const action = String(input.action || '').trim().toLowerCase();
            if (productCount > 0 && input.replacementCategoryId !== undefined) {
                const replacementId = Number(input.replacementCategoryId);
                if (!Number.isSafeInteger(replacementId) || replacementId === id) {
                    throw new ProductInputError('Danh mục thay thế không hợp lệ');
                }
                const replacement = await categoryRepo.findOne({
                    where: { id: replacementId, shopId, isActive: true },
                });
                if (!replacement) throw new ProductInputError('Không tìm thấy danh mục thay thế');
                await manager.createQueryBuilder()
                    .update(Product)
                    .set({ category: replacement })
                    .where('shop_id = :shopId AND category_id = :id', { shopId, id })
                    .execute();
            } else if (productCount > 0 && action !== 'deactivate') {
                throw new ProductInputError('Danh mục đang được sử dụng; hãy chọn danh mục thay thế hoặc ngừng sử dụng');
            }
            category.isActive = false;
            await categoryRepo.save(category);
            return { id, isActive: false, reassignedProducts: input.replacementCategoryId !== undefined ? productCount : 0 };
        });
    }

    private async assertCategoryNameAvailable(shopId: number, name: string, excludeId?: number) {
        const qb = this.categoryRepo.createQueryBuilder('category')
            .where('category.shop_id = :shopId', { shopId })
            .andWhere('LOWER(TRIM(category.name)) = LOWER(TRIM(:name))', { name });
        if (excludeId) qb.andWhere('category.id != :excludeId', { excludeId });
        if (await qb.getOne()) throw new ProductInputError('Tên danh mục đã tồn tại trong cửa hàng');
    }

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
