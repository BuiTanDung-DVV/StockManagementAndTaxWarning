export class XntExportInputError extends Error {}
type Query = { from?: unknown; to?: unknown; warehouseId?: unknown };
const dateKey = (value: unknown): value is string => {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
    const parsed = new Date(`${value}T00:00:00Z`);
    return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
};

export function normalizeXntExportQuery(input: Query) {
    if (!dateKey(input.from) || !dateKey(input.to) || input.from > input.to) {
        throw new XntExportInputError('Khoảng ngày xuất nhập–xuất–tồn không hợp lệ.');
    }
    let warehouseId: number | undefined;
    if (input.warehouseId !== undefined) {
        if (typeof input.warehouseId !== 'string' || !/^[1-9]\d*$/.test(input.warehouseId) ||
            !Number.isSafeInteger(Number(input.warehouseId))) throw new XntExportInputError('Kho không hợp lệ.');
        warehouseId = Number(input.warehouseId);
    }
    return { from: input.from, to: input.to, warehouseId };
}

/** Validate each product, never total quantities of different units. */
export function summarizeXntExport(items: Array<Record<string, any>>) {
    const ids = new Set<number>();
    const counts = { recordCount: items.length, openingSkuCount: 0, importedSkuCount: 0, exportedSkuCount: 0, closingSkuCount: 0 };
    for (const row of items) {
        if (!Number.isSafeInteger(row.id) || row.id <= 0 || ids.has(row.id) ||
            ['sku', 'name', 'unit'].some(field => typeof row[field] !== 'string' || !row[field].trim())) {
            throw new Error('Invalid XNT product');
        }
        ids.add(row.id);
        const quantities = [row.openingStock, row.totalImport, row.totalExport, row.closingStock];
        if (quantities.some(value => !Number.isSafeInteger(value)) || row.totalImport < 0 || row.totalExport < 0 ||
            !Number.isSafeInteger(row.openingStock + row.totalImport) ||
            row.openingStock + row.totalImport - row.totalExport !== row.closingStock) {
            throw new Error('Invalid XNT quantity reconciliation');
        }
        if (row.openingStock > 0) counts.openingSkuCount++;
        if (row.totalImport > 0) counts.importedSkuCount++;
        if (row.totalExport > 0) counts.exportedSkuCount++;
        if (row.closingStock > 0) counts.closingSkuCount++;
    }
    return counts;
}
