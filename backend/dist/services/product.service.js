"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProductService = void 0;
const db_config_1 = require("../config/db.config");
const entities_1 = require("../product/entities");
class ProductService {
    constructor() {
        this.productRepo = db_config_1.AppDataSource.getRepository(entities_1.Product);
        this.categoryRepo = db_config_1.AppDataSource.getRepository(entities_1.Category);
        this.costTypeRepo = db_config_1.AppDataSource.getRepository(entities_1.CostType);
        this.costItemRepo = db_config_1.AppDataSource.getRepository(entities_1.ProductCostItem);
        this.batchRepo = db_config_1.AppDataSource.getRepository(entities_1.ProductBatch);
        this.unitRepo = db_config_1.AppDataSource.getRepository(entities_1.UnitConversion);
        this.priceHistoryRepo = db_config_1.AppDataSource.getRepository(entities_1.ProductPriceHistory);
    }
    async findAllProducts(page = 1, limit = 20, search) {
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
    async findProductById(id) {
        const product = await this.productRepo.findOne({
            where: { id }, relations: ['category', 'costItems', 'costItems.costType'],
        });
        if (!product)
            throw new Error('Product not found');
        return product;
    }
    async createProduct(dto) {
        const exists = await this.productRepo.findOne({ where: { sku: dto.sku } });
        if (exists)
            throw new Error('SKU already exists');
        const product = this.productRepo.create(dto);
        return this.productRepo.save(product);
    }
    async updateProduct(id, dto) {
        const product = await this.findProductById(id);
        Object.assign(product, dto);
        return this.productRepo.save(product);
    }
    async deleteProduct(id) {
        const product = await this.findProductById(id);
        product.isActive = false;
        return this.productRepo.save(product);
    }
    async calculateSuggestedPrice(productId) {
        const product = await this.findProductById(productId);
        const costItems = await this.costItemRepo.find({ where: { product: { id: productId } } });
        let totalAdditional = 0;
        for (const item of costItems) {
            if (item.calculationType === 'FIXED') {
                totalAdditional += Number(item.amount);
            }
            else if (item.calculationType === 'PERCENTAGE') {
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
    async findAllCostTypes() { return this.costTypeRepo.find({ where: { isActive: true }, order: { sortOrder: 'ASC' } }); }
    async createCostType(dto) {
        if (await this.costTypeRepo.findOne({ where: { name: dto.name } }))
            throw new Error('Cost type name exists');
        return this.costTypeRepo.save(this.costTypeRepo.create(dto));
    }
    async addCostItem(productId, costTypeId, amount, calculationType = 'FIXED', notes) {
        const product = await this.findProductById(productId);
        const costType = await this.costTypeRepo.findOne({ where: { id: costTypeId } });
        if (!costType)
            throw new Error('Cost type not found');
        const item = this.costItemRepo.create({ product, costType, amount, calculationType, notes });
        await this.costItemRepo.save(item);
        await this.calculateSuggestedPrice(productId);
        return item;
    }
    async removeCostItem(id) {
        const item = await this.costItemRepo.findOne({ where: { id }, relations: ['product'] });
        if (!item)
            throw new Error('Cost item not found');
        const productId = item.product.id;
        await this.costItemRepo.remove(item);
        await this.calculateSuggestedPrice(productId);
    }
    async getPriceHistory(productId) { return this.priceHistoryRepo.find({ where: { product: { id: productId } }, order: { changedAt: 'DESC' } }); }
    async findBatches(productId) { return this.batchRepo.find({ where: { product: { id: productId }, isActive: true } }); }
    async createBatch(productId, dto) {
        const product = await this.findProductById(productId);
        return this.batchRepo.save(this.batchRepo.create({ ...dto, product }));
    }
    async findConversions(productId) { return this.unitRepo.find({ where: { product: { id: productId } } }); }
    async createConversion(productId, dto) {
        const product = await this.findProductById(productId);
        return this.unitRepo.save(this.unitRepo.create({ ...dto, product }));
    }
    async findAllCategories() { return this.categoryRepo.find({ where: { isActive: true } }); }
    async createCategory(dto) { return this.categoryRepo.save(this.categoryRepo.create(dto)); }
}
exports.ProductService = ProductService;
//# sourceMappingURL=product.service.js.map