export type SalesAccountingSplit = {
    netSales: number;
    taxAmount: number;
    totalAmount: number;
    paidAmount: number;
    receivableAmount: number;
};

export const calculateAllocatedMerchandiseRevenue = (
    lineSubtotal: number,
    orderSubtotal: number,
    discountAmount: number,
): number => {
    const values = [lineSubtotal, orderSubtotal, discountAmount];
    if (values.some((value) => !Number.isFinite(value) || value < 0)) {
        throw new Error('Validation: Sales allocation amounts must be non-negative numbers');
    }
    if (discountAmount > orderSubtotal) {
        throw new Error('Validation: Discount exceeds subtotal');
    }
    if (orderSubtotal === 0) return 0;
    return lineSubtotal * (1 - discountAmount / orderSubtotal);
};

export const buildAllocatedMerchandiseRevenueSql = (
    lineSubtotalExpression: string,
    orderAlias: string,
): string => {
    if (
        !/^[A-Za-z_][A-Za-z0-9_.]*$/.test(lineSubtotalExpression)
        || !/^[A-Za-z_][A-Za-z0-9_]*$/.test(orderAlias)
    ) {
        throw new Error('Validation: Invalid sales allocation SQL identifier');
    }
    return `CASE
        WHEN COALESCE(${orderAlias}.subtotal, 0) <= 0 THEN 0
        ELSE ${lineSubtotalExpression} * GREATEST(
            0,
            1 - COALESCE(${orderAlias}.discount_amount, 0) / ${orderAlias}.subtotal
        )
    END`;
};

export const calculateSalesAccountingSplit = (
    subtotal: number,
    discountAmount: number,
    taxAmount: number,
    paidAmount: number,
): SalesAccountingSplit => {
    const values = [subtotal, discountAmount, taxAmount, paidAmount];
    if (values.some((value) => !Number.isFinite(value) || value < 0)) {
        throw new Error('Validation: Sales accounting amounts must be non-negative numbers');
    }
    if (discountAmount > subtotal) {
        throw new Error('Validation: Discount exceeds subtotal');
    }
    const netSales = subtotal - discountAmount;
    const totalAmount = netSales + taxAmount;
    if (paidAmount > totalAmount) {
        throw new Error('Validation: Paid amount exceeds order total');
    }
    return {
        netSales,
        taxAmount,
        totalAmount,
        paidAmount,
        receivableAmount: totalAmount - paidAmount,
    };
};
