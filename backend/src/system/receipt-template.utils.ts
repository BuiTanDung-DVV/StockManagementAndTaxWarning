const flags: Record<string, boolean> = {
    showLogo: true, showShopInfo: true, showCustomer: true, showSku: true,
    showUnit: true, showItemNumber: false, showDiscount: true, showTax: true,
    showShipping: true, showPayment: true, showBalance: false, showNote: false,
    showQr: true, showFooter: true,
};

/** Validate only receipt presentation; totals and business records are untouched. */
export function normalizeReceiptTemplateConfig(value: unknown): Record<string, unknown> {
    const fail = (message: string): never => { throw new Error(`Validation: ${message}`); };
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
        return fail('Cấu hình phiếu in không hợp lệ');
    }
    const raw = value as Record<string, unknown>;
    const pick = (key: string, fallback: string, options: string[]) => {
        const v = raw[key] ?? fallback;
        if (typeof v !== 'string' || !options.includes(v)) return fail(`Tùy chọn ${key} không hợp lệ`);
        return v;
    };
    const paperSize = pick('paperSize', '80mm', ['80mm', 'A4']);
    const a4 = paperSize === 'A4';
    const text = (key: string, fallback: string, max: number, required = false) => {
        const v = raw[key] ?? fallback;
        if (typeof v !== 'string' || v.trim().length > max || (required && !v.trim())) {
            return fail(`Nội dung ${key} không hợp lệ`);
        }
        return v.trim();
    };
    const number = (key: string, fallback: number, min: number, max: number) => {
        const v = raw[key] ?? fallback;
        if (typeof v !== 'number' || !Number.isFinite(v) || v < min || v > max) {
            return fail(`${key} phải trong khoảng ${min}–${max}`);
        }
        return v;
    };
    const result: Record<string, unknown> = {
        paperSize,
        preset: pick('preset', 'standard', ['compact', 'standard', 'detailed']),
        title: text('title', 'PHIẾU BÁN HÀNG', 100, true),
        footer: text('footer', '', 500),
        logoSource: pick('logoSource', 'shop', ['shop', 'custom', 'none']),
        logoUrl: text('logoUrl', '', 1000),
        logoPosition: pick('logoPosition', 'center', ['left', 'center', 'right']),
        headerAlignment: pick('headerAlignment', 'center', ['left', 'center', 'right']),
        footerAlignment: pick('footerAlignment', 'center', ['left', 'center', 'right']),
        fontFamily: pick('fontFamily', 'noto', ['noto', 'inter']),
        fontSize: number('fontSize', a4 ? 10 : 8.5, 7, 13),
        titleSize: number('titleSize', a4 ? 18 : 12, 12, 24),
        lineSpacing: number('lineSpacing', 1, 0, 5),
        marginMm: number('marginMm', a4 ? 10 : 3.5, 2, 15),
        logoWidthMm: number('logoWidthMm', 20, 10, 50),
        logoHeightMm: number('logoHeightMm', 18, 8, 35),
        qrSizeMm: number('qrSizeMm', 30, 20, 45),
    };
    for (const [key, fallback] of Object.entries(flags)) {
        if (raw[key] !== undefined && typeof raw[key] !== 'boolean') return fail(`Tùy chọn ${key} phải là bật/tắt`);
        result[key] = raw[key] ?? fallback;
    }
    if (result.logoSource === 'custom' && !result.logoUrl) return fail('Vui lòng chọn logo riêng cho phiếu');
    if (result.logoSource !== 'custom') result.logoUrl = '';
    return result;
}
