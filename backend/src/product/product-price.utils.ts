type PriceInput = { costPrice?: unknown; supplierDiscount?: unknown; taxRate?: unknown; profitMargin?: unknown };
type CostInput = { amount: unknown; calculationType: string };

/** Same formula used by the product price calculator and import preview. */
export function productCostSummary(product: PriceInput, costs: CostInput[]) {
    let totalAdditionalCost = 0;
    for (const item of costs) {
        if (item.calculationType === 'FIXED') totalAdditionalCost += Number(item.amount);
        else if (item.calculationType === 'PERCENTAGE') {
            totalAdditionalCost += Number(product.costPrice) * Number(item.amount) / 100;
        }
    }
    const baseCost = Number(product.costPrice) - Number(product.supplierDiscount || 0) + totalAdditionalCost;
    const suggestedPrice = Math.round(baseCost * (1 + Number(product.taxRate || 0) / 100)
        * (1 + Number(product.profitMargin || 0) / 100));
    if (!Number.isFinite(totalAdditionalCost) || !Number.isFinite(suggestedPrice)) {
        throw new Error('Invalid product price calculation');
    }
    return { totalAdditionalCost, suggestedPrice };
}
