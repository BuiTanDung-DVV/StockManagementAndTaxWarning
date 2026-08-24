export interface TaxPolicy {
    fiscalYear: number;
    effectiveFrom: string;
    taxExemptionThreshold: number;
    warningRevenueThreshold: number;
    eInvoiceThreshold: number;
    sourceCode: string;
    sourceUrl: string;
}

export class TaxValidationError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'TaxValidationError';
    }
}

export const normalizeNonNegative = (value: number): number => {
    if (!Number.isFinite(value)) return 0;
    return Math.max(0, value);
};

export const normalizeTaxCode = (value?: string | null): string => {
    return (value ?? '').trim().replace(/\s+/g, '');
};

export const isValidVietnamTaxCode = (value?: string | null): boolean => {
    const taxCode = normalizeTaxCode(value);
    if (!/^\d{10}(?:-?\d{3})?$/.test(taxCode)) return false;

    // This value was previously used as an XML fallback. It must never make a
    // generated declaration look as if it belongs to a real taxpayer.
    return taxCode !== '0123456789'
        && taxCode !== '0123456789-001'
        && taxCode !== '0123456789001';
};

export const calculateOutstandingTax = (
    declared: number,
    paid: number,
): { owed: number; overpaid: number } => {
    const balance = normalizeNonNegative(declared) - normalizeNonNegative(paid);
    return {
        owed: Math.max(balance, 0),
        overpaid: Math.max(-balance, 0),
    };
};

export const requireValidTaxCode = (value?: string | null): string => {
    const taxCode = normalizeTaxCode(value);
    if (!isValidVietnamTaxCode(taxCode)) {
        throw new TaxValidationError(
            'Mã số thuế chưa hợp lệ. Vui lòng cập nhật hồ sơ cửa hàng trước khi xuất XML.',
        );
    }
    return taxCode;
};

export const validateTaxPeriod = (
    period: string,
    year: string,
    supportedFiscalYear: number,
): void => {
    if (!/^(?:0[1-9]|1[0-2]|Q[1-4])$/.test(period)) {
        throw new TaxValidationError(
            'Kỳ tính thuế phải là tháng 01-12 hoặc quý Q1-Q4.',
        );
    }
    if (!/^\d{4}$/.test(year) || Number(year) < 2000 || Number(year) > 2100) {
        throw new TaxValidationError('Năm tính thuế không hợp lệ.');
    }
    if (Number(year) !== supportedFiscalYear) {
        throw new TaxValidationError(
            `Hệ thống hiện chỉ có bộ quy tắc thuế đã xác minh cho năm ${supportedFiscalYear}.`,
        );
    }
};
