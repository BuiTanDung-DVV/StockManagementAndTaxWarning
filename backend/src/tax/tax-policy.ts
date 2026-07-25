export const CURRENT_TAX_POLICY = {
    fiscalYear: 2026,
    effectiveFrom: '2026-01-01',
    taxExemptionThreshold: 1_000_000_000,
    warningRevenueThreshold: 900_000_000,
    eInvoiceThreshold: 1_000_000_000,
    sourceCode: '141/2026/NĐ-CP',
    sourceUrl:
        'https://vanban.chinhphu.vn/?classid=1&docid=217960&pageid=27160&typegroupid=4',
} as const;

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
    return /^\d{10}(?:-?\d{3})?$/.test(normalizeTaxCode(value));
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

export const validateTaxPeriod = (period: string, year: string): void => {
    if (!/^(?:0[1-9]|1[0-2]|Q[1-4])$/.test(period)) {
        throw new TaxValidationError(
            'Kỳ tính thuế phải là tháng 01-12 hoặc quý Q1-Q4.',
        );
    }
    if (!/^\d{4}$/.test(year) || Number(year) < 2000 || Number(year) > 2100) {
        throw new TaxValidationError('Năm tính thuế không hợp lệ.');
    }
    if (Number(year) !== CURRENT_TAX_POLICY.fiscalYear) {
        throw new TaxValidationError(
            `Hệ thống hiện chỉ có bộ quy tắc thuế đã xác minh cho năm ${CURRENT_TAX_POLICY.fiscalYear}.`,
        );
    }
};
