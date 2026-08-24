export type SalesAccountingSplit = {
    netSales: number;
    taxAmount: number;
    totalAmount: number;
    paidAmount: number;
    receivableAmount: number;
};

export type SalesTaxLine = {
    subtotal: number;
    taxRate: number;
    taxAmount: number;
};

const roundMoney = (value: number): number => Math.round(value * 100) / 100;

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

export const calculateSalesTaxLines = (
    lines: Array<{ subtotal: number; taxRate: number }>,
    orderSubtotal: number,
    discountAmount: number,
): { lines: SalesTaxLine[]; taxAmount: number } => {
    if (!Number.isFinite(orderSubtotal) || orderSubtotal < 0) {
        throw new Error('Validation: Order subtotal must be a non-negative number');
    }
    if (!Number.isFinite(discountAmount) || discountAmount < 0 || discountAmount > orderSubtotal) {
        throw new Error('Validation: Discount must be between 0 and subtotal');
    }

    const calculatedLines = lines.map((line) => {
        const subtotal = Number(line.subtotal);
        const taxRate = Number(line.taxRate);
        if (!Number.isFinite(subtotal) || subtotal < 0) {
            throw new Error('Validation: Line subtotal must be a non-negative number');
        }
        if (!Number.isFinite(taxRate) || taxRate < 0 || taxRate > 100) {
            throw new Error('Validation: Product tax rate in database is invalid');
        }
        const taxableAmount = calculateAllocatedMerchandiseRevenue(
            subtotal,
            orderSubtotal,
            discountAmount,
        );
        return {
            subtotal,
            taxRate,
            taxAmount: roundMoney(taxableAmount * taxRate / 100),
        };
    });

    return {
        lines: calculatedLines,
        taxAmount: roundMoney(
            calculatedLines.reduce((sum, line) => sum + line.taxAmount, 0),
        ),
    };
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
