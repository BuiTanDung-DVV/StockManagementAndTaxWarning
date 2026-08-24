export type PaymentBankOption = {
    id: string;
    name: string;
};

export function parsePaymentBankOptions(value: string): PaymentBankOption[] {
    let parsed: unknown;
    try {
        parsed = JSON.parse(value);
    } catch {
        throw new Error('Cấu hình VIETQR_BANKS trong DB không phải JSON hợp lệ');
    }

    if (!Array.isArray(parsed)) {
        throw new Error('Cấu hình VIETQR_BANKS trong DB phải là một danh sách');
    }

    const seenIds = new Set<string>();
    const banks = parsed.map((entry) => {
        if (!entry || typeof entry !== 'object') {
            throw new Error('Cấu hình VIETQR_BANKS chứa dòng không hợp lệ');
        }
        const id = String((entry as any).id || '').trim().toUpperCase();
        const name = String((entry as any).name || '').trim();
        if (!id || id.length > 20 || !name || name.length > 100) {
            throw new Error('Cấu hình VIETQR_BANKS thiếu mã hoặc tên ngân hàng');
        }
        if (seenIds.has(id)) {
            throw new Error(`Cấu hình VIETQR_BANKS trùng mã ${id}`);
        }
        seenIds.add(id);
        return { id, name };
    });

    if (banks.length === 0) {
        throw new Error('Cấu hình VIETQR_BANKS trong DB đang rỗng');
    }
    return banks;
}
