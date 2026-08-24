export type InvoiceQualityRawRow = {
    checkedInvoices?: string | number | null;
    missingItemInvoices?: string | number | null;
    headerTotalMismatchInvoices?: string | number | null;
    headerSubtotalMismatchInvoices?: string | number | null;
    unallocatedDiscountInvoices?: string | number | null;
    headerTaxMismatchInvoices?: string | number | null;
    invalidLineItems?: string | number | null;
    lineSubtotalMismatchItems?: string | number | null;
    lineTaxMismatchItems?: string | number | null;
    firstInvoiceDate?: string | Date | null;
    lastInvoiceDate?: string | Date | null;
};

const countValue = (value: string | number | null | undefined) => {
    const parsed = Number(value || 0);
    return Number.isSafeInteger(parsed) && parsed >= 0 ? parsed : 0;
};

const vietnamDateValue = (value: string | Date | null | undefined) => {
    if (!value) return null;
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) return null;
    return new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Asia/Ho_Chi_Minh',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
    }).format(date);
};

export const normalizeInvoiceDataQuality = (row: InvoiceQualityRawRow = {}) => {
    const checkedInvoices = countValue(row.checkedInvoices);
    const missingItemInvoices = countValue(row.missingItemInvoices);
    const headerTotalMismatchInvoices = countValue(row.headerTotalMismatchInvoices);
    const headerSubtotalMismatchInvoices = countValue(row.headerSubtotalMismatchInvoices);
    const unallocatedDiscountInvoices = countValue(row.unallocatedDiscountInvoices);
    const headerTaxMismatchInvoices = countValue(row.headerTaxMismatchInvoices);
    const invalidLineItems = countValue(row.invalidLineItems);
    const lineSubtotalMismatchItems = countValue(row.lineSubtotalMismatchItems);
    const lineTaxMismatchItems = countValue(row.lineTaxMismatchItems);
    const issueCount = missingItemInvoices +
        headerTotalMismatchInvoices +
        headerSubtotalMismatchInvoices +
        unallocatedDiscountInvoices +
        headerTaxMismatchInvoices +
        invalidLineItems +
        lineSubtotalMismatchItems +
        lineTaxMismatchItems;

    return {
        checkedInvoices,
        missingItemInvoices,
        headerTotalMismatchInvoices,
        headerSubtotalMismatchInvoices,
        unallocatedDiscountInvoices,
        headerTaxMismatchInvoices,
        invalidLineItems,
        lineSubtotalMismatchItems,
        lineTaxMismatchItems,
        issueCount,
        hasIssues: issueCount > 0,
        firstInvoiceDate: vietnamDateValue(row.firstInvoiceDate),
        lastInvoiceDate: vietnamDateValue(row.lastInvoiceDate),
    };
};
