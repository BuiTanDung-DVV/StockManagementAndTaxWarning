import { createHash } from 'node:crypto';
import { EntityManager, In, Repository } from 'typeorm';
import { AppDataSource } from '../config/db.config';
import { Category, Product, Tag } from '../product/entities';
import { normalizeProductInput, ProductInputError } from '../product/product-input.utils';
import { parseProductImportCsv, ProductImportCsvError, ProductImportCsvOptions } from '../product/product-import-csv.utils';
import { productCostSummary } from '../product/product-price.utils';
import { lockShopMutation } from '../utils/shop-mutation-lock';
import { ActivityLog } from '../system/entities';
import { ShopMember } from '../shop/entities';
import { membershipHasAnyPermission } from '../middleware/permission.utils';

export class ProductImportConflictError extends Error {}
export class ProductImportPermissionError extends Error {}
type ImportRequest = { operationId: string; expectedPlanHash: string; csv: unknown; options?: ProductImportCsvOptions };
type ImportResult = { shopId: number; operationId: string; total: number; created: number;
    updated: number; unchanged: number; replayed: boolean };

const key = (value: string) => value.trim().normalize('NFC').toLocaleLowerCase('vi');
const labels: Record<string, string> = {
    name: 'Tên sản phẩm', unit: 'Đơn vị', barcode: 'Mã vạch', costPrice: 'Giá nhập',
    sellingPrice: 'Giá bán', wholesalePrice: 'Giá bán sỉ', minStock: 'Mức tối thiểu',
    imageUrl: 'Ảnh', description: 'Mô tả', tags: 'Nhãn', categoryId: 'Danh mục',
    totalAdditionalCost: 'Tổng chi phí bổ sung', suggestedPrice: 'Giá đề xuất',
};
const money = new Set(['costPrice', 'sellingPrice', 'wholesalePrice', 'minStock']);

function revision(product: Product) {
    const fields = ['id', 'shopId', 'sku', 'name', 'unit', 'barcode', 'costPrice',
        'sellingPrice', 'wholesalePrice', 'minStock', 'imageUrl', 'description', 'tags', 'isActive',
        'supplierDiscount', 'taxRate', 'profitMargin', 'totalAdditionalCost', 'suggestedPrice'] as const;
    const snapshot = Object.fromEntries(fields.map(field => [field, product[field]]));
    return createHash('sha256').update(JSON.stringify({ ...snapshot,
        categoryId: product.category?.id || null, updatedAt: product.updatedAt,
        costs: (product.costItems || []).map(item => [item.id, item.amount, item.calculationType])
            .sort((a, b) => Number(a[0]) - Number(b[0])) })).digest('hex');
}

function masterMatch<T extends { name: string }>(rows: T[], name: string): T | undefined {
    const found = rows.filter(row => key(row.name) === key(name));
    return found.length === 1 ? found[0] : undefined;
}

export class ProductImportService {
    private products: Repository<Product>;
    private categories: Repository<Category>;
    private tags: Repository<Tag>;

    constructor(manager?: EntityManager) {
        const source = manager || AppDataSource;
        this.products = source.getRepository(Product);
        this.categories = source.getRepository(Category);
        this.tags = source.getRepository(Tag);
    }

    /** Read-only preview. Commit is deliberately separate and must revalidate
     * revisions, master data, scope and database uniqueness inside a transaction. */
    async previewCsv(shopId: number, csv: unknown, options?: ProductImportCsvOptions) {
        if (!Number.isSafeInteger(shopId) || shopId <= 0) {
            throw new ProductImportCsvError('Chọn một cửa hàng để nhập danh mục.');
        }
        const parsed = parseProductImportCsv(csv, options);
        const skus = [...new Set(parsed.rows.map(row => row.values.sku).filter((value): value is string => typeof value === 'string'))];
        const barcodes = [...new Set(parsed.rows.map(row => row.values.barcode).filter((value): value is string => typeof value === 'string'))];
        const [existing, barcodeOwners, categories, tags] = await Promise.all([
            skus.length ? this.products.find({ where: { shopId, sku: In(skus) }, relations: ['category', 'costItems'] }) : Promise.resolve<Product[]>([]),
            barcodes.length ? this.products.find({ where: { shopId, isActive: true, barcode: In(barcodes) },
                select: { id: true, sku: true, barcode: true } }) : Promise.resolve<Product[]>([]),
            this.categories.find({ where: { shopId, isActive: true } }),
            this.tags.find({ where: { shopId, type: 'product' } }),
        ]);
        const bySku = new Map(existing.map(product => [product.sku, product]));
        const rows = parsed.rows.map(row => {
            const errors = [...row.errors];
            const sku = String(row.values.sku || '');
            const product = bySku.get(sku);
            const raw: Record<string, unknown> = { ...row.values };
            const categoryName = raw.categoryName as string | undefined;
            delete raw.categoryName;
            let categoryId: number | undefined;
            if (product && !product.isActive) errors.push('SKU thuộc sản phẩm đã ngừng sử dụng; kiểm tra lại trong danh mục.');
            if (categoryName) {
                const category = masterMatch(categories, categoryName);
                if (!category) errors.push('Danh mục chưa có hoặc tên không duy nhất; chọn lại danh mục trong ứng dụng.');
                else categoryId = category.id;
            }
            if (Array.isArray(raw.tags)) {
                const canonical: string[] = [];
                for (const name of raw.tags) {
                    const tag = masterMatch(tags, String(name));
                    if (!tag) errors.push(`Nhãn chưa có hoặc tên không duy nhất: ${String(name)}.`);
                    else canonical.push(tag.name);
                }
                // Import appends selected master tags; blank cells never remove
                // the labels already attached to a product.
                raw.tags = [...new Map([...(product?.tags || []), ...canonical].map(name => [key(name), name])).values()];
            }
            if (product && raw.unit !== undefined) {
                if (key(String(raw.unit)) !== key(product.unit)) {
                    errors.push('Đơn vị khác sản phẩm hiện có; cần xử lý quy đổi trong chi tiết sản phẩm.');
                } else raw.unit = product.unit;
            }
            if (raw.barcode && barcodeOwners.some(owner => owner.barcode === raw.barcode && owner.id !== product?.id)) {
                errors.push('Mã vạch đang thuộc sản phẩm khác trong cửa hàng.');
            }
            let input: Record<string, unknown> = {};
            if (!errors.length) {
                try {
                    input = normalizeProductInput(shopId, raw, { requireName: !product });
                    if (categoryId !== undefined) input.categoryId = categoryId;
                    if (!product) {
                        input.unit ??= 'Cái'; input.costPrice ??= 0; input.sellingPrice ??= 0;
                    }
                    if (Object.prototype.hasOwnProperty.call(input, 'costPrice') &&
                        (!product || Number(input.costPrice) !== Number(product.costPrice))) {
                        const derived = productCostSummary({ ...product, ...input }, product?.costItems || []);
                        if (derived.suggestedPrice < 0) throw new ProductInputError('Giá nhập thấp hơn chiết khấu hiện có; kiểm tra lại giá.');
                        if (Object.values(derived).some(value => !Number.isSafeInteger(Math.round(value * 100)))) {
                            throw new ProductInputError('Chi phí hoặc giá đề xuất vượt phạm vi số tiền có thể nhập chính xác.');
                        }
                        Object.assign(input, derived);
                    }
                } catch (error) {
                    errors.push(error instanceof ProductInputError ? error.message : 'Dữ liệu sản phẩm không hợp lệ.');
                }
            }
            const changes = Object.entries(input).filter(([field, value]) => {
                if (field === 'sku') return false;
                const before = field === 'categoryId' ? product?.category?.id : (product as any)?.[field];
                if (money.has(field) && before !== undefined && before !== null && value !== null) {
                    return Number(before) !== Number(value);
                }
                return JSON.stringify(before ?? null) !== JSON.stringify(value ?? null);
            }).map(([field, value]) => ({ field, label: labels[field] || field,
                before: field === 'categoryId' ? product?.category?.id || null : (product as any)?.[field] ?? null,
                after: value }));
            return { line: row.line, sku, productId: product?.id || null,
                expectedRevision: product ? revision(product) : null,
                kind: errors.length ? 'ERROR' : !product ? 'CREATE' : changes.length ? 'UPDATE' : 'UNCHANGED',
                input, changes, errors };
        });
        const sourceHash = createHash('sha256').update(String(csv)).digest('hex');
        const planHash = createHash('sha256').update(JSON.stringify({ shopId, sourceHash,
            columns: parsed.columns, numberFormat: options?.numberFormat || 'decimal-dot',
            rows: rows.map(({ line, sku, productId, expectedRevision, kind, input }) =>
                ({ line, sku, productId, expectedRevision, kind, input })) })).digest('hex');
        return { shopId, sourceHash, planHash,
            headerLine: parsed.headerLine, headers: parsed.headers, columns: parsed.columns,
            ignoredHeaders: parsed.ignoredHeaders, numberFormat: options?.numberFormat || 'decimal-dot',
            summary: { total: rows.length, create: rows.filter(row => row.kind === 'CREATE').length,
                update: rows.filter(row => row.kind === 'UPDATE').length,
                unchanged: rows.filter(row => row.kind === 'UNCHANGED').length,
                errors: rows.filter(row => row.kind === 'ERROR').length },
            rows, writesApplied: false };
    }

    private validateOperationId(value: unknown): asserts value is string {
        if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{16,80}$/.test(value)) {
            throw new ProductImportCsvError('Mã lượt nhập không hợp lệ.');
        }
    }

    private readReceipt(log: ActivityLog, actorId: number) {
        if (log.userId !== actorId) throw new ProductImportPermissionError('Không có quyền xem lượt nhập này.');
        try {
            const receipt = JSON.parse(log.newValue);
            const result = receipt.result as ImportResult;
            if (typeof receipt.requestHash !== 'string' || !/^[a-f0-9]{64}$/.test(receipt.requestHash) ||
                result.shopId !== log.shopId || result.operationId !== log.entityName ||
                ![result.total, result.created, result.updated, result.unchanged].every(value =>
                    Number.isSafeInteger(value) && value >= 0 && value <= 500) ||
                result.total !== result.created + result.updated + result.unchanged ||
                result.replayed !== false) throw new Error();
            return { requestHash: receipt.requestHash as string, result };
        } catch {
            throw new ProductImportConflictError('Kết quả lượt nhập cần được kiểm tra lại; không tự nhập lại bằng mã mới.');
        }
    }

    private async assertPermission(manager: EntityManager, shopId: number, actorId: number) {
        await manager.query('SELECT id FROM public.shop_members WHERE shop_id=$1 AND user_id=$2 FOR SHARE', [shopId, actorId]);
        const member = await manager.getRepository(ShopMember).findOne({
            where: { shopId, userId: actorId, isActive: true, status: 'ACTIVE' }, relations: ['role'],
        });
        if (member?.roleId && member.memberType !== 'OWNER') {
            await manager.query('SELECT id FROM public.shop_roles WHERE id=$1 AND shop_id=$2 FOR SHARE', [member.roleId, shopId]);
            // Re-read after taking the lock; a role may have changed while waiting.
            member.role = (await manager.getRepository(ShopMember).findOne({
                where: { id: member.id, shopId }, relations: ['role'],
            }))?.role!;
        }
        if (!member || !membershipHasAnyPermission(member, ['products'], 'edit', shopId)) {
            throw new ProductImportPermissionError('Quyền sửa sản phẩm đã thay đổi.');
        }
    }

    async commitCsv(shopId: number, actorId: number, request: ImportRequest): Promise<ImportResult> {
        if (!Number.isSafeInteger(shopId) || shopId <= 0 || !Number.isSafeInteger(actorId) || actorId <= 0) {
            throw new ProductImportPermissionError('Thông tin tài khoản hoặc cửa hàng không hợp lệ.');
        }
        this.validateOperationId(request?.operationId);
        if (typeof request.expectedPlanHash !== 'string' || !/^[a-f0-9]{64}$/.test(request.expectedPlanHash)) {
            throw new ProductImportCsvError('Cần xem trước tệp trước khi xác nhận.');
        }
        const parsed = parseProductImportCsv(request.csv, request.options);
        const requestHash = createHash('sha256').update(JSON.stringify({ csv: request.csv,
            columns: parsed.columns, headerLine: parsed.headerLine,
            numberFormat: request.options?.numberFormat || 'decimal-dot', planHash: request.expectedPlanHash })).digest('hex');
        try {
            return await AppDataSource.transaction('SERIALIZABLE', async manager => {
                await lockShopMutation(manager, shopId);
                await this.assertPermission(manager, shopId, actorId);
                const logs = manager.getRepository(ActivityLog);
                const previous = await logs.findOne({ where: { shopId, action: 'IMPORT',
                    entityType: 'PRODUCT_IMPORT', entityName: request.operationId } });
                if (previous) {
                    const receipt = this.readReceipt(previous, actorId);
                    if (receipt.requestHash !== requestHash) throw new ProductImportConflictError('Mã lượt nhập đã dùng cho nội dung khác.');
                    return { ...receipt.result, replayed: true };
                }
                const skus = parsed.rows.map(row => String(row.values.sku || ''));
                await manager.query('SELECT id FROM public.products WHERE shop_id=$1 AND sku=ANY($2::varchar[]) FOR UPDATE', [shopId, skus]);
                await manager.query('SELECT id FROM public.categories WHERE shop_id=$1 AND is_active=true FOR SHARE', [shopId]);
                await manager.query("SELECT id FROM public.tags WHERE shop_id=$1 AND type='product' FOR SHARE", [shopId]);
                const preview = await new ProductImportService(manager).previewCsv(shopId, request.csv, request.options);
                if (preview.summary.errors) throw new ProductImportCsvError('Tệp còn dòng lỗi; cần xem trước và sửa trước khi nhập.');
                if (preview.planHash !== request.expectedPlanHash) {
                    throw new ProductImportConflictError('Dữ liệu đã đổi từ lúc xem trước. Hãy xem trước lại; chưa có dòng nào được nhập.');
                }
                const products = manager.getRepository(Product);
                const additions = preview.rows.filter(row => row.kind === 'CREATE').map(row => {
                    const { categoryId, ...values } = row.input;
                    return products.create({ ...values, shopId,
                        ...(categoryId === undefined ? {} : { category: { id: Number(categoryId) } }),
                    } as Partial<Product>);
                });
                // TypeORM batches new rows into one INSERT instead of one network
                // round trip for each row. Existing products retain scoped updates.
                if (additions.length) await products.save(additions);
                for (const row of preview.rows) {
                    const { categoryId, ...values } = row.input;
                    const category = categoryId === undefined ? {} : { category: { id: Number(categoryId) } as Category };
                    if (row.kind === 'UPDATE') {
                        const updated = await products.update({ id: row.productId!, shopId }, { ...values, ...category } as Partial<Product>);
                        if (updated.affected !== 1) throw new ProductImportConflictError('Sản phẩm đã thay đổi; cần xem trước lại.');
                    }
                }
                const result: ImportResult = { shopId, operationId: request.operationId, total: preview.summary.total,
                    created: preview.summary.create, updated: preview.summary.update,
                    unchanged: preview.summary.unchanged, replayed: false };
                await logs.save(logs.create({ shopId, userId: actorId, action: 'IMPORT',
                    entityType: 'PRODUCT_IMPORT', entityName: request.operationId,
                    newValue: JSON.stringify({ requestHash, result }),
                    description: `Nhập danh mục: ${result.created} mới, ${result.updated} cập nhật, ${result.unchanged} không đổi.` }));
                return result;
            });
        } catch (error: any) {
            if (['23505', '40001', '40P01'].includes(error?.code)) {
                throw new ProductImportConflictError('Danh mục đã thay đổi hoặc có mã trùng. Hãy xem trước lại; không ghi một phần tệp.');
            }
            throw error;
        }
    }

    async findResult(shopId: number, actorId: number, operationId: unknown) {
        if (!Number.isSafeInteger(shopId) || shopId <= 0 || !Number.isSafeInteger(actorId) || actorId <= 0) {
            throw new ProductImportPermissionError('Thông tin tài khoản hoặc cửa hàng không hợp lệ.');
        }
        this.validateOperationId(operationId);
        const log = await AppDataSource.getRepository(ActivityLog).findOne({ where: {
            shopId, userId: actorId, action: 'IMPORT', entityType: 'PRODUCT_IMPORT', entityName: operationId,
        } });
        return log ? { state: 'COMPLETED', result: this.readReceipt(log, actorId).result }
            : { state: 'UNKNOWN' };
    }
}
