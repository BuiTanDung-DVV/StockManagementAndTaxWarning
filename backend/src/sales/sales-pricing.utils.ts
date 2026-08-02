type ProductPricing = {
    sellingPrice: unknown;
    wholesalePrice?: unknown;
    wholesaleMinQty?: unknown;
    promoPrice?: unknown;
    promoStart?: Date | string | null;
    promoEnd?: Date | string | null;
};

const VIETNAM_TIME_ZONE = 'Asia/Ho_Chi_Minh';

const vietnamDate = (value: Date): string => {
    const parts = new Intl.DateTimeFormat('en-CA', {
        timeZone: VIETNAM_TIME_ZONE,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
    }).formatToParts(value);
    const part = (type: 'year' | 'month' | 'day') =>
        parts.find((item) => item.type === type)?.value;
    return `${part('year')}-${part('month')}-${part('day')}`;
};

const dateOnly = (value: Date | string | null | undefined): string | null => {
    if (!value) return null;
    if (typeof value === 'string') {
        const match = value.match(/^\d{4}-\d{2}-\d{2}/);
        if (match) return match[0];
    }
    const parsed = value instanceof Date ? value : new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : vietnamDate(parsed);
};

const validMoney = (value: unknown): number | null => {
    const amount = Number(value);
    return Number.isFinite(amount) && amount >= 0 ? amount : null;
};

export function allowedUnitPrices(
    product: ProductPricing,
    quantity: number,
    orderDate = new Date(),
): number[] {
    const prices: number[] = [];
    const retailPrice = validMoney(product.sellingPrice);
    if (retailPrice !== null) prices.push(retailPrice);

    const wholesalePrice = validMoney(product.wholesalePrice);
    const wholesaleMinQty = Number(product.wholesaleMinQty);
    if (
        wholesalePrice !== null
        && Number.isFinite(wholesaleMinQty)
        && wholesaleMinQty > 0
        && quantity >= wholesaleMinQty
    ) {
        prices.push(wholesalePrice);
    }

    const promoPrice = validMoney(product.promoPrice);
    const today = vietnamDate(orderDate);
    const promoStart = dateOnly(product.promoStart);
    const promoEnd = dateOnly(product.promoEnd);
    const promoActive = (!promoStart || today >= promoStart)
        && (!promoEnd || today <= promoEnd);
    if (promoPrice !== null && promoActive) prices.push(promoPrice);

    return [...new Set(prices)];
}
export function assertAllowedUnitPrice(
    requestedPrice: unknown,
    product: ProductPricing,
    quantity: number,
    orderDate = new Date(),
): number {
    const price = validMoney(requestedPrice);
    if (price === null) {
        throw new Error('Validation: Unit price must be a non-negative number');
    }
    const allowedPrices = allowedUnitPrices(product, quantity, orderDate);
    const accepted = allowedPrices.some((candidate) =>
        Math.abs(candidate - price) <= 0.01,
    );
    if (!accepted) {
        throw new Error('Validation: Unit price does not match product pricing');
    }
    return price;
}
