export type RequestedShopScope =
    | { kind: 'single'; shopId: number }
    | { kind: 'all' };

export const parseRequestedShopScope = (
    value: unknown,
): RequestedShopScope | null => {
    if (typeof value !== 'string') return null;

    const normalized = value.trim();
    if (normalized === 'all') return { kind: 'all' };
    if (!/^[1-9]\d*$/.test(normalized)) return null;

    const shopId = Number(normalized);
    if (!Number.isSafeInteger(shopId)) return null;
    return { kind: 'single', shopId };
};
