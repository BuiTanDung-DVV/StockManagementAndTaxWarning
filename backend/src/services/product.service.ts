import { AppDataSource } from '../config/db.config';
import { Product, Category, CostType, ProductCostItem, ProductBatch, UnitConversion, ProductPriceHistory } from '../product/entities';

export class ProductService {
    private productRepo = AppDataSource.getRepository(Product);
    private categoryRepo = AppDataSource.getRepository(Category);
    private costTypeRepo = AppDataSource.getRepository(CostType);
    private costItemRepo = AppDataSource.getRepository(ProductCostItem);
    private batchRepo = AppDataSource.getRepository(ProductBatch);
    private unitRepo = AppDataSource.getRepository(UnitConversion);
    private priceHistoryRepo = AppDataSource.getRepository(ProductPriceHistory);

    // === PRODUCT CRUD ===
    async findAllProducts(page = 1, limit = 20, search?: string) {
        const qb = this.productRepo.createQueryBuilder('p')
            .leftJoinAndSelect('p.category', 'category')
            .leftJoinAndSelect('p.costItems', 'costItems')
            .leftJoinAndSelect('costItems.costType', 'costType');

        if (search) {
            qb.where('p.name LIKE :search', { search: `%${search}%` })
              .orWhere('p.sku LIKE :search', { search: `%${search}%` })
              .orWhere('p.barcode LIKE :search', { search: `%${search}%` });
        }

        const [items, total] = await qb.skip((page - 1) * limit)
                                       .take(limit)
                                       .orderBy('p.createdAt', 'DESC')
                                       .getManyAndCount();

        return { items, total, page, limit, totalPages: Math.ceil(total / limit) };
    }

    async findProductById(id: number) {
        const product = await this.productRepo.findOne({
            where: { id }, relations: ['category', 'costItems', 'costItems.costType'],
        });
        if (!product) throw new Error('Product not found');
        return product;
    }

    async createProduct(dto: Partial<Product>) {
        const exists = await this.productRepo.findOne({ where: { sku: dto.sku as string } });
        if (exists) throw new Error('SKU already exists');
        const product = this.productRepo.create(dto);
        return this.productRepo.save(product);
    }

    async updateProduct(id: number, dto: Partial<Product>) {
        const product = await this.findProductById(id);
        Object.assign(product, dto);
        return this.productRepo.save(product);
    }

    async deleteProduct(id: number) {
        const product = await this.findProductById(id);
        product.isActive = false;
        return this.productRepo.save(product);
    }

    // === PRICING ===
    async calculateSuggestedPrice(productId: number) {
        const product = await this.findProductById(productId);
        const costItems = await this.costItemRepo.find({ where: { product: { id: productId } } });

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
    async findAllCostTypes() { return this.costTypeRepo.find({ where: { isActive: true }, order: { sortOrder: 'ASC' } }); }
    async createCostType(dto: Partial<CostType>) {
        if (await this.costTypeRepo.findOne({ where: { name: dto.name as string } })) throw new Error('Cost type name exists');
        return this.costTypeRepo.save(this.costTypeRepo.create(dto));
    }

    // === COST ITEMS ===
    async addCostItem(productId: number, costTypeId: number, amount: number, calculationType = 'FIXED', notes?: string) {
        const product = await this.findProductById(productId);
        const costType = await this.costTypeRepo.findOne({ where: { id: costTypeId } });
        if (!costType) throw new Error('Cost type not found');
        const item = this.costItemRepo.create({ product, costType, amount, calculationType, notes });
        await this.costItemRepo.save(item);
        await this.calculateSuggestedPrice(productId);
        return item;
    }
    async removeCostItem(id: number) {
        const item = await this.costItemRepo.findOne({ where: { id }, relations: ['product'] });
        if (!item) throw new Error('Cost item not found');
        const productId = item.product.id;
        await this.costItemRepo.remove(item);
        await this.calculateSuggestedPrice(productId);
    }

    // === PRICE HISTORY ===
    async getPriceHistory(productId: number) { return this.priceHistoryRepo.find({ where: { product: { id: productId } }, order: { changedAt: 'DESC' } }); }
    
    // === BATCHES ===
    async findBatches(productId: number) { return this.batchRepo.find({ where: { product: { id: productId }, isActive: true } }); }
    async createBatch(productId: number, dto: Partial<ProductBatch>) {
        const product = await this.findProductById(productId);
        return this.batchRepo.save(this.batchRepo.create({ ...dto, product }));
    }

    // === UNIT CONVERSIONS ===
    async findConversions(productId: number) { return this.unitRepo.find({ where: { product: { id: productId } } }); }
    async createConversion(productId: number, dto: Partial<UnitConversion>) {
        const product = await this.findProductById(productId);
        return this.unitRepo.save(this.unitRepo.create({ ...dto, product }));
    }

    // === CATEGORIES ===
    async findAllCategories() { return this.categoryRepo.find({ where: { isActive: true } }); }
    async createCategory(dto: Partial<Category>) { return this.categoryRepo.save(this.categoryRepo.create(dto)); }
}
