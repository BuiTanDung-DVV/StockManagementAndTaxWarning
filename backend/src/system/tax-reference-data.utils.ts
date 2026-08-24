export interface TaxDeclarationFormReference {
    code: string;
    name: string;
    description: string;
    status: 'READY' | 'DRAFT';
    iconKey: string;
}

export interface TaxSupportLinkReference {
    title: string;
    description: string;
    url: string;
    iconKey: string;
    colorRole: 'PRIMARY' | 'SUCCESS' | 'WARNING';
}

const text = (value: unknown, field: string, maxLength: number): string => {
    if (typeof value !== 'string') {
        throw new Error(`Cấu hình ${field} phải là chuỗi`);
    }
    const normalized = value.trim();
    if (!normalized || normalized.length > maxLength) {
        throw new Error(`Cấu hình ${field} không hợp lệ`);
    }
    return normalized;
};

const parseArray = (raw: string, key: string): unknown[] => {
    let value: unknown;
    try {
        value = JSON.parse(raw);
    } catch {
        throw new Error(`Cấu hình ${key} trong DB không phải JSON hợp lệ`);
    }
    if (!Array.isArray(value) || value.length === 0 || value.length > 50) {
        throw new Error(`Cấu hình ${key} trong DB phải là danh sách hợp lệ`);
    }
    return value;
};

export const parseTaxDeclarationForms = (raw: string): TaxDeclarationFormReference[] =>
    parseArray(raw, 'TAX_DECLARATION_FORMS').map((item, index) => {
        if (!item || typeof item !== 'object' || Array.isArray(item)) {
            throw new Error(`Biểu mẫu thuế thứ ${index + 1} không hợp lệ`);
        }
        const row = item as Record<string, unknown>;
        const status = text(row.status, 'status', 20).toUpperCase();
        if (status !== 'READY' && status !== 'DRAFT') {
            throw new Error(`Trạng thái biểu mẫu thuế thứ ${index + 1} không hợp lệ`);
        }
        return {
            code: text(row.code, 'code', 50),
            name: text(row.name, 'name', 200),
            description: text(row.description, 'description', 500),
            status,
            iconKey: text(row.iconKey, 'iconKey', 50),
        };
    });

const allowedTaxHosts = new Set([
    'www.gdt.gov.vn',
    'gdt.gov.vn',
    'thuedientu.gdt.gov.vn',
    'hoadondientu.gdt.gov.vn',
]);

export const parseTaxSupportLinks = (raw: string): TaxSupportLinkReference[] =>
    parseArray(raw, 'TAX_SUPPORT_LINKS').map((item, index) => {
        if (!item || typeof item !== 'object' || Array.isArray(item)) {
            throw new Error(`Liên kết thuế thứ ${index + 1} không hợp lệ`);
        }
        const row = item as Record<string, unknown>;
        const url = text(row.url, 'url', 1000);
        let parsedUrl: URL;
        try {
            parsedUrl = new URL(url);
        } catch {
            throw new Error(`URL liên kết thuế thứ ${index + 1} không hợp lệ`);
        }
        if (parsedUrl.protocol !== 'https:' || !allowedTaxHosts.has(parsedUrl.hostname)) {
            throw new Error(`URL liên kết thuế thứ ${index + 1} không thuộc tên miền cho phép`);
        }
        const colorRole = text(row.colorRole, 'colorRole', 20).toUpperCase();
        if (!['PRIMARY', 'SUCCESS', 'WARNING'].includes(colorRole)) {
            throw new Error(`Màu liên kết thuế thứ ${index + 1} không hợp lệ`);
        }
        return {
            title: text(row.title, 'title', 200),
            description: text(row.description, 'description', 500),
            url: parsedUrl.toString(),
            iconKey: text(row.iconKey, 'iconKey', 50),
            colorRole: colorRole as TaxSupportLinkReference['colorRole'],
        };
    });
