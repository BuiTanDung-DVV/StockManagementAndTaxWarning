import jsQrModule = require('jsqr');
import sharpModule = require('sharp');

const jsQR = ((jsQrModule as unknown as { default?: typeof jsQrModule }).default ??
    jsQrModule) as unknown as typeof import('jsqr').default;
const sharp = ((sharpModule as unknown as { default?: typeof sharpModule }).default ??
    sharpModule) as unknown as typeof import('sharp').default;

export type PaymentQrDetails = {
    rawText: string;
    bankBin: string | null;
    accountNumber: string | null;
    accountName: string | null;
    amount: string | null;
    message: string | null;
};

type TlvMap = Map<string, string>;

function parseTlv(value: string): TlvMap {
    const result = new Map<string, string>();
    let offset = 0;
    while (offset + 4 <= value.length) {
        const tag = value.slice(offset, offset + 2);
        const lengthText = value.slice(offset + 2, offset + 4);
        if (!/^\d{2}$/.test(tag) || !/^\d{2}$/.test(lengthText)) break;
        const length = Number(lengthText);
        const start = offset + 4;
        const end = start + length;
        if (end > value.length) break;
        result.set(tag, value.slice(start, end));
        offset = end;
    }
    return result;
}

function crc16Ccitt(value: string): string {
    let crc = 0xffff;
    for (const byte of Buffer.from(value, 'utf8')) {
        crc ^= byte << 8;
        for (let bit = 0; bit < 8; bit += 1) {
            crc = (crc & 0x8000) !== 0 ? ((crc << 1) ^ 0x1021) : crc << 1;
            crc &= 0xffff;
        }
    }
    return crc.toString(16).toUpperCase().padStart(4, '0');
}

export function parseVietQrPayload(rawValue: string): PaymentQrDetails {
    const rawText = String(rawValue || '').trim();
    if (!rawText.startsWith('000201') || rawText.length > 2000) {
        throw new Error('Ảnh không chứa mã QR thanh toán ngân hàng hợp lệ');
    }
    const crcMarker = rawText.slice(-8, -4);
    const crcValue = rawText.slice(-4).toUpperCase();
    if (crcMarker !== '6304' || crc16Ccitt(rawText.slice(0, -4)) !== crcValue) {
        throw new Error('Mã QR thanh toán bị lỗi hoặc không đọc được đầy đủ');
    }

    const root = parseTlv(rawText);
    const merchantAccount = root.get('38');
    if (!merchantAccount || root.get('58') !== 'VN') {
        throw new Error('Ảnh không chứa mã VietQR/NAPAS hợp lệ');
    }
    const merchant = parseTlv(merchantAccount);
    if (merchant.get('00') !== 'A000000727') {
        throw new Error('Ảnh không chứa mã VietQR/NAPAS hợp lệ');
    }
    const beneficiary = parseTlv(merchant.get('01') || '');
    const additional = parseTlv(root.get('62') || '');

    return {
        rawText,
        bankBin: beneficiary.get('00') || null,
        accountNumber: beneficiary.get('01') || null,
        accountName: root.get('59') || null,
        amount: root.get('54') || null,
        message: additional.get('08') || additional.get('05') || null,
    };
}

export async function decodePaymentQrImage(bytes: Buffer): Promise<PaymentQrDetails> {
    const image = sharp(bytes, { failOn: 'error' });
    const metadata = await image.metadata();
    if (!metadata.width || !metadata.height || metadata.width * metadata.height > 20_000_000) {
        throw new Error('Ảnh QR có kích thước không hợp lệ');
    }
    const { data, info } = await image
        .ensureAlpha()
        .raw()
        .toBuffer({ resolveWithObject: true });
    const decoded = jsQR(new Uint8ClampedArray(data), info.width, info.height, {
        inversionAttempts: 'attemptBoth',
    });
    if (!decoded?.data) {
        throw new Error('Không tìm thấy mã QR trong ảnh');
    }
    return parseVietQrPayload(decoded.data);
}

export function paymentQrDisplayText(details: PaymentQrDetails): string {
    return [
        'QR thanh toán VietQR/NAPAS',
        details.bankBin ? `Mã ngân hàng: ${details.bankBin}` : null,
        details.accountNumber ? `Số tài khoản: ${details.accountNumber}` : null,
        details.accountName ? `Tên người nhận: ${details.accountName}` : null,
        details.amount ? `Số tiền: ${details.amount}` : null,
        details.message ? `Nội dung: ${details.message}` : null,
    ].filter(Boolean).join('\n');
}
