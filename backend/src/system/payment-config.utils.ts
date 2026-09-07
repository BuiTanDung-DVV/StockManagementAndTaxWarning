export type PaymentBankOption = {
    id: string;
    name: string;
};

export const DEFAULT_PAYMENT_BANK_OPTIONS: PaymentBankOption[] = [
    { id: 'MB', name: 'MB Bank' },
    { id: 'VCB', name: 'Vietcombank' },
    { id: 'TCB', name: 'Techcombank' },
    { id: 'ACB', name: 'ACB' },
    { id: 'TPB', name: 'TPBank' },
    { id: 'VPB', name: 'VPBank' },
    { id: 'BIDV', name: 'BIDV' },
    { id: 'VTB', name: 'VietinBank' },
    { id: 'AGR', name: 'Agribank' },
    { id: 'SHB', name: 'SHB' },
    { id: 'STB', name: 'Sacombank' },
    { id: 'HDB', name: 'HDBank' },
    { id: 'MSB', name: 'MSB' },
    { id: 'OCB', name: 'OCB' },
    { id: 'LPB', name: 'LPBank' },
    { id: 'EIB', name: 'Eximbank' },
    { id: 'SCB', name: 'SCB' },
    { id: 'NAB', name: 'Nam A Bank' },
    { id: 'VAB', name: 'VietABank' },
    { id: 'SEAB', name: 'SeABank' },
    { id: 'BAB', name: 'Bac A Bank' },
    { id: 'PVCB', name: 'PVcomBank' },
    { id: 'KLB', name: 'KienlongBank' },
    { id: 'ABB', name: 'ABBank' },
    { id: 'WOO', name: 'Woori Bank Việt Nam' },
    { id: 'CAKE', name: 'CAKE by VPBank' },
    { id: 'UBANK', name: 'Ubank by VPBank' },
];

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
