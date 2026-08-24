export class InventoryMasterInputError extends Error {}

export function normalizeWarehouseInput(input: unknown) {
    if (!input || typeof input !== 'object' || Array.isArray(input)) {
        throw new InventoryMasterInputError('Dữ liệu kho không hợp lệ');
    }
    const raw = input as Record<string, unknown>;
    const unknown = Object.keys(raw).filter((key) => !['name', 'address'].includes(key));
    if (unknown.length) throw new InventoryMasterInputError(`Trường kho không được phép: ${unknown.join(', ')}`);
    const name = String(raw.name || '').trim();
    const address = String(raw.address || '').trim();
    if (!name || name.length > 100) throw new InventoryMasterInputError('Tên kho không hợp lệ');
    if (address.length > 500) throw new InventoryMasterInputError('Địa chỉ kho không được vượt quá 500 ký tự');
    return { name, address: address || null };
}
