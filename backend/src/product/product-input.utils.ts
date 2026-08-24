import { config } from '../config/env.config';
import { productImageKeyFromPublicUrl } from '../services/image-storage.service';

export class ProductInputError extends Error {}

type ProductInputOptions = {
    requireName?: boolean;
    allowOpeningStock?: boolean;
};

const editableFields = new Set([
    'name', 'sku', 'barcode', 'unit', 'costPrice', 'sellingPrice',
    'wholesalePrice', 'wholesaleMinQty', 'taxRate', 'supplierDiscount',
    'promoPrice', 'promoStart', 'promoEnd', 'minStock', 'description',
    'tags', 'imageUrl', 'currentStock', 'openingStock', 'warehouseId',
]);

const optionalMoneyFields = ['wholesalePrice', 'promoPrice'] as const;
const nonNegativeNumberFields = ['costPrice', 'sellingPrice', 'supplierDiscount'] as const;
const nonNegativeIntegerFields = [
    'wholesaleMinQty', 'minStock', 'currentStock', 'openingStock', 'warehouseId',
] as const;

function hasOwn(value: Record<string, unknown>, key: string) {
    return Object.prototype.hasOwnProperty.call(value, key);
}

function requiredText(value: unknown, label: string, maxLength: number) {
    const text = String(value ?? '').trim();
    if (!text) throw new ProductInputError(`${label} không được để trống`);
    if (text.length > maxLength) {
        throw new ProductInputError(`${label} không được vượt quá ${maxLength} ký tự`);
    }
    return text;
}

function optionalText(value: unknown, label: string, maxLength: number) {
    if (value === null || value === undefined || String(value).trim() === '') return null;
    return requiredText(value, label, maxLength);
}

function numberInRange(value: unknown, label: string, min: number, max: number) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
        throw new ProductInputError(`${label} không hợp lệ`);
    }
    return parsed;
}

function nonNegativeInteger(value: unknown, label: string) {
    const parsed = numberInRange(value, label, 0, Number.MAX_SAFE_INTEGER);
    if (!Number.isInteger(parsed)) throw new ProductInputError(`${label} phải là số nguyên`);
    return parsed;
}

function normalizeDate(value: unknown, label: string) {
    if (value === null || value === undefined || value === '') return null;
    const text = String(value).trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(text) || Number.isNaN(Date.parse(`${text}T00:00:00Z`))) {
        throw new ProductInputError(`${label} không hợp lệ`);
    }
    return text;
}

export function isOwnedProductImageUrl(shopId: number, value: unknown): boolean {
    if (value === null) return true;
    const raw = String(value || '').trim();
    if (!raw) return false;
    return productImageKeyFromPublicUrl(shopId, raw, config.cloudinaryCloudName) !== null;
}

export function normalizeProductInput(
    shopId: number,
    input: unknown,
    options: ProductInputOptions = {},
): Record<string, unknown> {
    if (!input || typeof input !== 'object' || Array.isArray(input)) {
        throw new ProductInputError('Dữ liệu sản phẩm không hợp lệ');
    }
    const raw = input as Record<string, unknown>;
    const unsupported = Object.keys(raw).filter((key) => !editableFields.has(key));
    if (unsupported.length) {
        throw new ProductInputError(`Trường sản phẩm không được phép: ${unsupported.join(', ')}`);
    }
    if (!options.allowOpeningStock && ['currentStock', 'openingStock', 'warehouseId'].some((key) => hasOwn(raw, key))) {
        throw new ProductInputError('Tồn kho chỉ được nhập khi tạo sản phẩm; hãy dùng nghiệp vụ kho để điều chỉnh');
    }

    const result: Record<string, unknown> = {};
    if (options.requireName || hasOwn(raw, 'name')) result.name = requiredText(raw.name, 'Tên sản phẩm', 200);
    if (hasOwn(raw, 'sku')) result.sku = optionalText(raw.sku, 'Mã SKU', 50);
    if (hasOwn(raw, 'barcode')) result.barcode = optionalText(raw.barcode, 'Mã vạch', 50);
    if (hasOwn(raw, 'unit')) result.unit = requiredText(raw.unit, 'Đơn vị tính', 20);
    if (hasOwn(raw, 'description')) result.description = optionalText(raw.description, 'Mô tả', 1000);

    for (const field of nonNegativeNumberFields) {
        if (hasOwn(raw, field)) result[field] = numberInRange(raw[field], field, 0, 1_000_000_000_000_000);
    }
    for (const field of optionalMoneyFields) {
        if (hasOwn(raw, field)) result[field] = raw[field] === null || raw[field] === ''
            ? null
            : numberInRange(raw[field], field, 0, 1_000_000_000_000_000);
    }
    for (const field of nonNegativeIntegerFields) {
        if (hasOwn(raw, field)) result[field] = nonNegativeInteger(raw[field], field);
    }
    if (hasOwn(raw, 'taxRate')) result.taxRate = numberInRange(raw.taxRate, 'Thuế suất', 0, 100);
    if (hasOwn(raw, 'promoStart')) result.promoStart = normalizeDate(raw.promoStart, 'Ngày bắt đầu khuyến mãi');
    if (hasOwn(raw, 'promoEnd')) result.promoEnd = normalizeDate(raw.promoEnd, 'Ngày kết thúc khuyến mãi');

    if (hasOwn(raw, 'tags')) {
        if (!Array.isArray(raw.tags) || raw.tags.length > 20) {
            throw new ProductInputError('Danh sách nhãn sản phẩm không hợp lệ');
        }
        result.tags = [...new Set(raw.tags.map((tag) => requiredText(tag, 'Nhãn sản phẩm', 100)))];
    }
    if (hasOwn(raw, 'imageUrl')) {
        if (!isOwnedProductImageUrl(shopId, raw.imageUrl)) {
            throw new ProductInputError('Ảnh sản phẩm không thuộc vùng lưu trữ của cửa hàng');
        }
        result.imageUrl = raw.imageUrl === null ? null : String(raw.imageUrl).trim();
    }
    return result;
}

function masterText(value: unknown, label: string, max: number): string;
function masterText(value: unknown, label: string, max: number, required: false): string | null;
function masterText(value: unknown, label: string, max: number, required = true): string | null {
    const normalized = String(value ?? '').trim();
    if (!normalized && required) throw new ProductInputError(`${label} không được để trống`);
    if (normalized.length > max) throw new ProductInputError(`${label} không được vượt quá ${max} ký tự`);
    return normalized || null;
}

function masterObject(input: unknown, allowed: string[]) {
    if (!input || typeof input !== 'object' || Array.isArray(input)) throw new ProductInputError('Dữ liệu không hợp lệ');
    const raw = input as Record<string, unknown>;
    const unknown = Object.keys(raw).filter((key) => !allowed.includes(key));
    if (unknown.length) throw new ProductInputError(`Trường không được phép: ${unknown.join(', ')}`);
    return raw;
}

export function normalizeCategoryInput(input: unknown) {
    const raw = masterObject(input, ['name', 'description']);
    return { name: masterText(raw.name, 'Tên danh mục', 100), description: masterText(raw.description, 'Mô tả', 500, false) };
}

export function normalizeCostTypeInput(input: unknown) {
    const raw = masterObject(input, ['name', 'description', 'sortOrder']);
    const sortOrder = raw.sortOrder === undefined ? 0 : Number(raw.sortOrder);
    if (!Number.isSafeInteger(sortOrder) || sortOrder < 0) throw new ProductInputError('Thứ tự hiển thị không hợp lệ');
    return { name: masterText(raw.name, 'Tên loại chi phí', 100), description: masterText(raw.description, 'Mô tả', 500, false), sortOrder };
}

export function normalizeBatchInput(input: unknown) {
    const raw = masterObject(input, ['batchNumber', 'manufacturingDate', 'expiryDate', 'quantity', 'costPrice', 'supplierName', 'notes']);
    return {
        batchNumber: masterText(raw.batchNumber, 'Mã lô', 50),
        manufacturingDate: normalizeDate(raw.manufacturingDate, 'Ngày sản xuất'),
        expiryDate: normalizeDate(raw.expiryDate, 'Hạn sử dụng'),
        quantity: nonNegativeInteger(raw.quantity, 'Số lượng lô'),
        costPrice: raw.costPrice === undefined || raw.costPrice === null ? null : numberInRange(raw.costPrice, 'Giá vốn lô', 0, 1_000_000_000_000_000),
        supplierName: masterText(raw.supplierName, 'Nhà cung cấp', 200, false),
        notes: masterText(raw.notes, 'Ghi chú', 500, false),
    };
}

export function normalizeUnitConversionInput(input: unknown) {
    const raw = masterObject(input, ['fromUnit', 'toUnit', 'conversionRate', 'sellingPricePerUnit']);
    return {
        fromUnit: masterText(raw.fromUnit, 'Đơn vị nguồn', 30),
        toUnit: masterText(raw.toUnit, 'Đơn vị đích', 30),
        conversionRate: numberInRange(raw.conversionRate, 'Tỷ lệ quy đổi', Number.EPSILON, 1_000_000_000),
        sellingPricePerUnit: raw.sellingPricePerUnit === undefined || raw.sellingPricePerUnit === null ? null : numberInRange(raw.sellingPricePerUnit, 'Giá bán theo đơn vị', 0, 1_000_000_000_000_000),
    };
}

export function normalizeCostItemInput(costTypeId: unknown, amount: unknown, calculationType: unknown, notes: unknown) {
    const parsedCostTypeId = Number(costTypeId);
    if (!Number.isSafeInteger(parsedCostTypeId) || parsedCostTypeId <= 0) throw new ProductInputError('Loại chi phí không hợp lệ');
    const type = String(calculationType || 'FIXED').trim().toUpperCase();
    if (!['FIXED', 'PERCENTAGE'].includes(type)) throw new ProductInputError('Cách tính chi phí không hợp lệ');
    return {
        costTypeId: parsedCostTypeId,
        amount: numberInRange(amount, 'Giá trị chi phí', 0, type === 'PERCENTAGE' ? 100 : 1_000_000_000_000_000),
        calculationType: type,
        notes: masterText(notes, 'Ghi chú', 200, false),
    };
}
