import { randomUUID } from 'crypto';
import { v2 as cloudinary } from 'cloudinary';
import { config } from '../config/env.config';

export const MAX_PRODUCT_IMAGE_BYTES = 5 * 1024 * 1024;
export const PRODUCT_IMAGE_TYPES = [
    'image/jpeg',
    'image/png',
    'image/webp',
] as const;

const allowedCloudinaryFormats = new Set(['jpg', 'jpeg', 'png', 'webp']);

export class ImageStorageError extends Error {
    constructor(
        message: string,
        public readonly statusCode: number,
    ) {
        super(message);
        this.name = 'ImageStorageError';
    }
}

export interface ProductImageUploadRequest {
    fileName: string;
    contentType: string;
    size: number;
}

export function validateProductImageUpload(
    input: ProductImageUploadRequest,
): ProductImageUploadRequest {
    const fileName = String(input.fileName || '').trim();
    const contentType = String(input.contentType || '').trim().toLowerCase();
    const size = Number(input.size);

    if (!fileName || fileName.length > 255) {
        throw new ImageStorageError('Tên tệp ảnh không hợp lệ', 400);
    }
    if (!PRODUCT_IMAGE_TYPES.includes(contentType as typeof PRODUCT_IMAGE_TYPES[number])) {
        throw new ImageStorageError('Chỉ hỗ trợ ảnh JPG, PNG hoặc WEBP', 400);
    }
    if (!Number.isInteger(size) || size <= 0 || size > MAX_PRODUCT_IMAGE_BYTES) {
        throw new ImageStorageError('Ảnh phải có dung lượng từ 1 byte đến 5 MB', 400);
    }

    return { fileName, contentType, size };
}

export function isOwnedProductImageKey(shopId: number, key: string): boolean {
    return key.startsWith(`smartstock/shops/${shopId}/products/`) &&
        !key.includes('..');
}

export function isOwnedShopPaymentQrKey(shopId: number, key: string): boolean {
    return key.startsWith(`smartstock/shops/${shopId}/payment-qr/`) &&
        !key.includes('..');
}

export function isOwnedDebtEvidenceImageKey(
    shopId: number,
    key: string,
): boolean {
    return key.startsWith(`smartstock/shops/${shopId}/debt-evidence/`) &&
        !key.includes('..');
}

export function cloudinaryPublicIdFromUrl(
    imageUrl: string,
    cloudName: string,
): string | null {
    if (!imageUrl || !cloudName) return null;

    try {
        const url = new URL(imageUrl);
        if (url.protocol !== 'https:' || url.hostname !== 'res.cloudinary.com') {
            return null;
        }

        const segments = url.pathname.split('/').filter(Boolean);
        if (
            segments[0] !== cloudName ||
            segments[1] !== 'image' ||
            segments[2] !== 'upload'
        ) {
            return null;
        }

        const versionIndex = segments.findIndex(
            (segment, index) => index >= 3 && /^v\d+$/.test(segment),
        );
        const publicIdSegments = versionIndex >= 0
            ? segments.slice(versionIndex + 1)
            : segments.slice(3);
        if (!publicIdSegments.length) return null;

        const last = publicIdSegments.length - 1;
        publicIdSegments[last] = publicIdSegments[last].replace(/\.[^.]+$/, '');
        return publicIdSegments.map(decodeURIComponent).join('/');
    } catch {
        return null;
    }
}

export function productImageKeyFromPublicUrl(
    shopId: number,
    imageUrl: string,
    cloudName: string,
): string | null {
    const key = cloudinaryPublicIdFromUrl(imageUrl, cloudName);
    return key && isOwnedProductImageKey(shopId, key) ? key : null;
}

export function shopPaymentQrKeyFromPublicUrl(
    shopId: number,
    imageUrl: string,
    cloudName: string,
): string | null {
    const key = cloudinaryPublicIdFromUrl(imageUrl, cloudName);
    return key && isOwnedShopPaymentQrKey(shopId, key) ? key : null;
}

export function debtEvidenceImageKeyFromPublicUrl(
    shopId: number,
    imageUrl: string,
    cloudName: string,
): string | null {
    const key = cloudinaryPublicIdFromUrl(imageUrl, cloudName);
    return key && isOwnedDebtEvidenceImageKey(shopId, key) ? key : null;
}

export class ImageStorageService {
    private configured = false;

    async createProductImageUpload(
        shopId: number,
        request: ProductImageUploadRequest,
    ) {
        return this.createSignedUpload(shopId, request, 'products');
    }

    async confirmProductImage(shopId: number, objectKey: string) {
        if (!isOwnedProductImageKey(shopId, String(objectKey || ''))) {
            throw new ImageStorageError('Đường dẫn ảnh không hợp lệ', 400);
        }
        return this.confirmImage(objectKey, 'Ảnh sản phẩm');
    }

    async createShopPaymentQrUpload(
        shopId: number,
        request: ProductImageUploadRequest,
    ) {
        return this.createSignedUpload(shopId, request, 'payment-qr');
    }

    async confirmShopPaymentQr(shopId: number, objectKey: string) {
        if (!isOwnedShopPaymentQrKey(shopId, String(objectKey || ''))) {
            throw new ImageStorageError('Đường dẫn QR không hợp lệ', 400);
        }
        return this.confirmImage(objectKey, 'Ảnh QR');
    }

    async createDebtEvidenceImageUpload(
        shopId: number,
        request: ProductImageUploadRequest,
    ) {
        return this.createSignedUpload(shopId, request, 'debt-evidence');
    }

    async confirmDebtEvidenceImage(shopId: number, objectKey: string) {
        if (!isOwnedDebtEvidenceImageKey(shopId, String(objectKey || ''))) {
            throw new ImageStorageError('Đường dẫn chứng từ không hợp lệ', 400);
        }
        return this.confirmImage(objectKey, 'Ảnh chứng từ');
    }

    async deleteDebtEvidenceImage(shopId: number, objectKey: string) {
        if (!isOwnedDebtEvidenceImageKey(shopId, String(objectKey || ''))) {
            throw new ImageStorageError('Đường dẫn chứng từ không hợp lệ', 400);
        }
        return this.destroy(objectKey);
    }

    async deleteDebtEvidenceImageByUrl(
        shopId: number,
        imageUrl?: string | null,
    ) {
        const objectKey = debtEvidenceImageKeyFromPublicUrl(
            shopId,
            String(imageUrl || ''),
            config.cloudinaryCloudName,
        );
        if (!objectKey) return { deleted: false };
        return this.destroy(objectKey);
    }

    async deleteProductImage(shopId: number, objectKey: string) {
        if (!isOwnedProductImageKey(shopId, String(objectKey || ''))) {
            throw new ImageStorageError('Đường dẫn ảnh không hợp lệ', 400);
        }
        return this.destroy(objectKey);
    }

    async deleteProductImageByUrl(shopId: number, imageUrl?: string | null) {
        const objectKey = productImageKeyFromPublicUrl(
            shopId,
            String(imageUrl || ''),
            config.cloudinaryCloudName,
        );
        if (!objectKey) return { deleted: false };
        return this.destroy(objectKey);
    }

    async deleteShopPaymentQrByUrl(shopId: number, imageUrl?: string | null) {
        const objectKey = shopPaymentQrKeyFromPublicUrl(
            shopId,
            String(imageUrl || ''),
            config.cloudinaryCloudName,
        );
        if (!objectKey) return { deleted: false };
        return this.destroy(objectKey);
    }

    async deleteShopPaymentQr(shopId: number, objectKey: string) {
        if (!isOwnedShopPaymentQrKey(shopId, String(objectKey || ''))) {
            throw new ImageStorageError('Đường dẫn QR không hợp lệ', 400);
        }
        return this.destroy(objectKey);
    }

    private createSignedUpload(
        shopId: number,
        request: ProductImageUploadRequest,
        scope: 'products' | 'payment-qr' | 'debt-evidence',
    ) {
        validateProductImageUpload(request);
        this.configure();

        const timestamp = Math.floor(Date.now() / 1000);
        const publicId = `smartstock/shops/${shopId}/${scope}/${randomUUID()}`;
        const signature = cloudinary.utils.api_sign_request(
            {
                public_id: publicId,
                timestamp,
            },
            config.cloudinaryApiSecret,
        );

        return {
            uploadUrl:
                `https://api.cloudinary.com/v1_1/${config.cloudinaryCloudName}/image/upload`,
            objectKey: publicId,
            expiresIn: 300,
            maxSize: MAX_PRODUCT_IMAGE_BYTES,
            fields: {
                api_key: config.cloudinaryApiKey,
                timestamp: String(timestamp),
                signature,
                public_id: publicId,
            },
        };
    }

    private async confirmImage(objectKey: string, label: string) {
        this.configure();
        let resource: any;
        try {
            resource = await cloudinary.api.resource(objectKey, {
                resource_type: 'image',
                type: 'upload',
            });
        } catch {
            throw new ImageStorageError(
                `Không tìm thấy ${label.toLowerCase()} vừa tải lên`,
                400,
            );
        }

        const size = Number(resource.bytes || 0);
        const format = String(resource.format || '').toLowerCase();
        const pixels = Number(resource.width || 0) * Number(resource.height || 0);
        if (
            size <= 0 ||
            size > MAX_PRODUCT_IMAGE_BYTES ||
            !allowedCloudinaryFormats.has(format) ||
            pixels <= 0 ||
            pixels > 20_000_000
        ) {
            await this.safeDestroy(objectKey);
            throw new ImageStorageError(
                `${label} không hợp lệ, quá 5 MB hoặc có độ phân giải quá lớn`,
                400,
            );
        }

        return {
            imageUrl: String(resource.secure_url),
            objectKey,
            contentType: `image/${format === 'jpg' ? 'jpeg' : format}`,
            size,
            width: Number(resource.width),
            height: Number(resource.height),
        };
    }

    private async destroy(objectKey: string) {
        this.configure();
        await cloudinary.uploader.destroy(objectKey, {
            resource_type: 'image',
            invalidate: true,
        });
        return { deleted: true };
    }

    private configure() {
        if (this.configured) return;

        const missing = [
            ['CLOUDINARY_CLOUD_NAME', config.cloudinaryCloudName],
            ['CLOUDINARY_API_KEY', config.cloudinaryApiKey],
            ['CLOUDINARY_API_SECRET', config.cloudinaryApiSecret],
        ].filter(([, value]) => !value).map(([name]) => name);
        if (missing.length) {
            throw new ImageStorageError(
                `Lưu trữ ảnh chưa được cấu hình (${missing.join(', ')})`,
                503,
            );
        }

        cloudinary.config({
            cloud_name: config.cloudinaryCloudName,
            api_key: config.cloudinaryApiKey,
            api_secret: config.cloudinaryApiSecret,
            secure: true,
        });
        this.configured = true;
    }

    private async safeDestroy(objectKey: string) {
        try {
            await this.destroy(objectKey);
        } catch {
            // Cleanup is best effort when validation fails.
        }
    }
}
