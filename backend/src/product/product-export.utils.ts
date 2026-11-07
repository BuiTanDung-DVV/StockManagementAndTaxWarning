export class ProductExportInputError extends Error {}

export function normalizeProductExportFilters(raw: Record<string, unknown>) {
    if (Object.keys(raw).some(key => !['search', 'tag', 'categoryId', 'inStockOnly'].includes(key))) {
        throw new ProductExportInputError('Bộ lọc xuất sản phẩm không hợp lệ');
    }
    const text = (key: string, limit: number) => {
        if (raw[key] == null) return null;
        if (typeof raw[key] !== 'string' || (raw[key] as string).length > limit) {
            throw new ProductExportInputError('Từ khóa hoặc nhãn xuất không hợp lệ');
        }
        return (raw[key] as string).trim() || null;
    };
    const category = raw.categoryId;
    if (category != null && (typeof category !== 'string' || !/^(0|[1-9]\d*)$/.test(category) || !Number.isSafeInteger(Number(category)))) {
        throw new ProductExportInputError('Danh mục không hợp lệ');
    }
    if (raw.inStockOnly != null && raw.inStockOnly !== 'true' && raw.inStockOnly !== 'false') {
        throw new ProductExportInputError('Bộ lọc tồn kho không hợp lệ');
    }
    return { search: text('search', 200), tag: text('tag', 100), categoryId: category == null ? null : Number(category), inStockOnly: raw.inStockOnly === 'true' };
}

export type ProductExportFilters = ReturnType<typeof normalizeProductExportFilters>;
