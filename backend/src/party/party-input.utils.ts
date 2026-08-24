export class PartyInputError extends Error {}

const customerFields = new Set([
    'name', 'phone', 'email', 'address', 'taxCode', 'identityNumber',
    'dateOfBirth', 'customerType', 'zaloPhone', 'creditLimit', 'notes', 'note',
    'tags',
]);

const supplierFields = new Set([
    'name', 'phone', 'email', 'address', 'taxCode', 'contactPerson',
    'contactName', 'paymentTermDays', 'bankAccount', 'bankName', 'notes',
    'note', 'tags',
]);

function own(value: Record<string, unknown>, key: string) {
    return Object.prototype.hasOwnProperty.call(value, key);
}

function objectInput(input: unknown) {
    if (!input || typeof input !== 'object' || Array.isArray(input)) {
        throw new PartyInputError('Dữ liệu không hợp lệ');
    }
    return input as Record<string, unknown>;
}

function rejectUnknown(raw: Record<string, unknown>, allowed: Set<string>) {
    const unknown = Object.keys(raw).filter((key) => !allowed.has(key));
    if (unknown.length) throw new PartyInputError(`Trường không được phép: ${unknown.join(', ')}`);
}

function text(value: unknown, label: string, max: number, required = false) {
    const normalized = String(value ?? '').trim();
    if (!normalized) {
        if (required) throw new PartyInputError(`${label} không được để trống`);
        return null;
    }
    if (normalized.length > max) throw new PartyInputError(`${label} không được vượt quá ${max} ký tự`);
    return normalized;
}

function email(value: unknown) {
    const normalized = text(value, 'Email', 100);
    if (normalized && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) {
        throw new PartyInputError('Email không hợp lệ');
    }
    return normalized;
}

function tags(value: unknown) {
    if (!Array.isArray(value) || value.length > 20) throw new PartyInputError('Danh sách nhãn không hợp lệ');
    return [...new Set(value.map((item) => text(item, 'Nhãn', 100, true) as string))];
}

function nonNegativeNumber(value: unknown, label: string) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed < 0 || parsed > 1_000_000_000_000_000) {
        throw new PartyInputError(`${label} không hợp lệ`);
    }
    return parsed;
}

function nonNegativeInteger(value: unknown, label: string) {
    const parsed = nonNegativeNumber(value, label);
    if (!Number.isInteger(parsed)) throw new PartyInputError(`${label} phải là số nguyên`);
    return parsed;
}

function date(value: unknown, label: string) {
    if (value === null || value === undefined || value === '') return null;
    const normalized = String(value).trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(normalized) || Number.isNaN(Date.parse(`${normalized}T00:00:00Z`))) {
        throw new PartyInputError(`${label} không hợp lệ`);
    }
    return normalized;
}

export function normalizeCustomerInput(input: unknown, requireName = false) {
    const raw = objectInput(input);
    rejectUnknown(raw, customerFields);
    const result: Record<string, unknown> = {};
    if (requireName || own(raw, 'name')) result.name = text(raw.name, 'Tên khách hàng', 200, true);
    if (own(raw, 'phone')) result.phone = text(raw.phone, 'Số điện thoại', 20);
    if (own(raw, 'email')) result.email = email(raw.email);
    if (own(raw, 'address')) result.address = text(raw.address, 'Địa chỉ', 500);
    if (own(raw, 'taxCode')) result.taxCode = text(raw.taxCode, 'Mã số thuế', 20);
    if (own(raw, 'identityNumber')) result.identityNumber = text(raw.identityNumber, 'Số định danh', 20);
    if (own(raw, 'dateOfBirth')) result.dateOfBirth = date(raw.dateOfBirth, 'Ngày sinh');
    if (own(raw, 'customerType')) {
        const type = String(raw.customerType || '').trim().toUpperCase();
        if (!['RETAIL', 'WHOLESALE', 'VIP'].includes(type)) throw new PartyInputError('Loại khách hàng không hợp lệ');
        result.customerType = type;
    }
    if (own(raw, 'zaloPhone')) result.zaloPhone = text(raw.zaloPhone, 'Số Zalo', 20);
    if (own(raw, 'creditLimit')) result.creditLimit = nonNegativeNumber(raw.creditLimit, 'Hạn mức tín dụng');
    if (own(raw, 'notes') || own(raw, 'note')) result.notes = text(raw.notes ?? raw.note, 'Ghi chú', 500);
    if (own(raw, 'tags')) result.tags = tags(raw.tags);
    return result;
}

export function normalizeSupplierInput(input: unknown, requireName = false) {
    const raw = objectInput(input);
    rejectUnknown(raw, supplierFields);
    const result: Record<string, unknown> = {};
    if (requireName || own(raw, 'name')) result.name = text(raw.name, 'Tên nhà cung cấp', 200, true);
    if (own(raw, 'phone')) result.phone = text(raw.phone, 'Số điện thoại', 20);
    if (own(raw, 'email')) result.email = email(raw.email);
    if (own(raw, 'address')) result.address = text(raw.address, 'Địa chỉ', 500);
    if (own(raw, 'taxCode')) result.taxCode = text(raw.taxCode, 'Mã số thuế', 20);
    if (own(raw, 'contactPerson') || own(raw, 'contactName')) {
        result.contactPerson = text(raw.contactPerson ?? raw.contactName, 'Người liên hệ', 200);
    }
    if (own(raw, 'paymentTermDays')) result.paymentTermDays = nonNegativeInteger(raw.paymentTermDays, 'Số ngày thanh toán');
    if (own(raw, 'bankAccount')) result.bankAccount = text(raw.bankAccount, 'Số tài khoản', 30);
    if (own(raw, 'bankName')) result.bankName = text(raw.bankName, 'Tên ngân hàng', 100);
    if (own(raw, 'notes') || own(raw, 'note')) result.notes = text(raw.notes ?? raw.note, 'Ghi chú', 500);
    if (own(raw, 'tags')) result.tags = tags(raw.tags);
    return result;
}
