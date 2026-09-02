import { GoogleGenerativeAI } from '@google/generative-ai';
import { AppDataSource } from '../config/db.config';
import { config } from '../config/env.config';
import { Invoice, InvoiceItem, InvoiceScan } from '../system/entities';
import { ImageStorageService, ProductImageUploadRequest } from './image-storage.service';

export class InvoiceOcrError extends Error {
    constructor(message: string, public statusCode = 400) { super(message); }
}

export type ParsedInvoice = {
    invoiceNumber: string;
    invoiceDate: string;
    partnerName: string;
    partnerTaxCode?: string;
    partnerAddress?: string;
    items: Array<{ itemName: string; unit: string; quantity: number; unitPrice: number; taxRate: number; taxAmount: number; subtotal: number }>;
    subtotal: number;
    taxAmount: number;
    totalAmount: number;
    confidence: number;
};

export function normalizeInvoiceOcrData(value: unknown): ParsedInvoice {
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new InvoiceOcrError('Dữ liệu hóa đơn không hợp lệ');
    const raw = value as Record<string, any>;
    const invoiceNumber = String(raw.invoiceNumber || '').trim();
    const invoiceDate = String(raw.invoiceDate || '').trim();
    const partnerName = String(raw.partnerName || '').trim();
    if (!invoiceNumber || invoiceNumber.length > 50 || !/^\d{4}-\d{2}-\d{2}$/.test(invoiceDate) || !partnerName || partnerName.length > 200) {
        throw new InvoiceOcrError('Vui lòng kiểm tra số hóa đơn, ngày và đối tác');
    }
    const [year, month, day] = invoiceDate.split('-').map(Number);
    const parsedDate = new Date(Date.UTC(year, month - 1, day));
    if (
        parsedDate.getUTCFullYear() !== year
        || parsedDate.getUTCMonth() !== month - 1
        || parsedDate.getUTCDate() !== day
    ) {
        throw new InvoiceOcrError('Ngày hóa đơn không tồn tại');
    }
    const items = Array.isArray(raw.items) ? raw.items.map((item: any) => {
        const normalized = {
            itemName: String(item.itemName || '').trim(), unit: String(item.unit || 'Cái').trim(),
            quantity: Number(item.quantity), unitPrice: Number(item.unitPrice), subtotal: Number(item.subtotal),
            taxRate: Number(item.taxRate || 0), taxAmount: Number(item.taxAmount || 0),
        };
        if (
            !normalized.itemName
            || normalized.itemName.length > 255
            || normalized.unit.length > 30
            || ![normalized.quantity, normalized.unitPrice, normalized.subtotal, normalized.taxRate, normalized.taxAmount].every(Number.isFinite)
            || normalized.quantity <= 0
            || normalized.unitPrice < 0
            || normalized.subtotal < 0
            || normalized.taxRate < 0
            || normalized.taxRate > 100
            || normalized.taxAmount < 0
            || Math.abs((normalized.quantity * normalized.unitPrice) - normalized.subtotal) > 1
        ) throw new InvoiceOcrError('Dòng hàng trong hóa đơn không hợp lệ');
        return normalized;
    }) : [];
    if (!items.length) throw new InvoiceOcrError('Hóa đơn phải có ít nhất một dòng hàng');
    const subtotal = Number(raw.subtotal), taxAmount = Number(raw.taxAmount), totalAmount = Number(raw.totalAmount);
    const lineSubtotal = items.reduce((sum, item) => sum + item.subtotal, 0);
    if (
        ![subtotal, taxAmount, totalAmount].every(Number.isFinite)
        || subtotal < 0
        || taxAmount < 0
        || totalAmount < 0
        || Math.abs(lineSubtotal - subtotal) > 1
        || Math.abs(subtotal + taxAmount - totalAmount) > 1
    ) throw new InvoiceOcrError('Tổng tiền hóa đơn không cân đối');
    const partnerTaxCode = String(raw.partnerTaxCode || '').trim();
    const partnerAddress = String(raw.partnerAddress || '').trim();
    if (partnerTaxCode.length > 20 || partnerAddress.length > 500) {
        throw new InvoiceOcrError('Thông tin đối tác vượt quá độ dài cho phép');
    }
    return { invoiceNumber, invoiceDate, partnerName, partnerTaxCode, partnerAddress, items, subtotal, taxAmount, totalAmount, confidence: Math.min(Math.max(Number(raw.confidence || 0), 0), 1) };
}

export class InvoiceOcrService {
    private scanRepo = AppDataSource.getRepository(InvoiceScan);
    private images = new ImageStorageService();

    async uploadAndProcess(shopId: number, userId: number, request: ProductImageUploadRequest, bytes: Buffer) {
        const uploaded = await this.images.uploadInvoiceScanImage(shopId, request, bytes);
        const scan = await this.scanRepo.save(this.scanRepo.create({
            shopId, scannedBy: userId, scanCode: `S${shopId}${Date.now().toString().slice(-12)}`,
            imageUrl: uploaded.imageUrl, invoiceType: 'PURCHASE', status: 'PROCESSING', ocrEngine: 'GEMINI',
        }));
        return this.process(scan, bytes, request.contentType);
    }

    async get(shopId: number, id: number) {
        const scan = await this.scanRepo.findOne({ where: { id, shopId } });
        if (!scan) throw new InvoiceOcrError('Không tìm thấy phiếu quét', 404);
        return scan;
    }

    async retry(shopId: number, id: number) {
        const scan = await this.get(shopId, id);
        if (scan.status === 'CONFIRMED') throw new InvoiceOcrError('Phiếu quét đã được xác nhận');
        const image = await this.images.downloadInvoiceScanImage(shopId, scan.imageUrl);
        scan.status = 'PROCESSING';
        scan.errorMessage = null;
        await this.scanRepo.save(scan);
        return this.process(scan, image.bytes, image.contentType);
    }

    async confirm(shopId: number, id: number, userId: number, input: unknown) {
        const data = normalizeInvoiceOcrData(input);
        return AppDataSource.transaction(async manager => {
            const scan = await manager.getRepository(InvoiceScan).findOne({
                where: { id, shopId },
                lock: { mode: 'pessimistic_write' },
            });
            if (!scan) throw new InvoiceOcrError('Không tìm thấy phiếu quét', 404);
            if (scan.status === 'CONFIRMED') throw new InvoiceOcrError('Phiếu quét đã được xác nhận');
            const duplicate = await manager.getRepository(Invoice).findOne({
                where: { shopId, invoiceType: 'IN', invoiceNumber: data.invoiceNumber },
            });
            if (duplicate) throw new InvoiceOcrError('Số hóa đơn này đã tồn tại trong cửa hàng', 409);
            const invoice = manager.create(Invoice, {
                shopId,
                invoiceNumber: data.invoiceNumber,
                invoiceType: 'IN',
                invoiceDate: new Date(`${data.invoiceDate}T00:00:00Z`),
                partnerName: data.partnerName,
                partnerTaxCode: data.partnerTaxCode || undefined,
                partnerAddress: data.partnerAddress || undefined,
                subtotal: data.subtotal,
                taxAmount: data.taxAmount,
                totalAmount: data.totalAmount,
                discountAmount: 0,
                paymentStatus: 'UNPAID',
                imageUrl: scan.imageUrl,
                notes: 'Tạo từ ảnh quét và đã được người dùng kiểm tra',
                createdBy: userId,
                items: data.items.map(item => manager.create(InvoiceItem, { ...item, productId: null })),
            });
            const saved = await manager.save(Invoice, invoice);
            scan.status = 'CONFIRMED';
            scan.confirmedData = JSON.stringify(data);
            scan.confirmedAt = new Date();
            scan.referenceType = 'INVOICE';
            scan.referenceId = saved.id;
            scan.totalAmount = data.totalAmount;
            scan.errorMessage = null;
            await manager.save(InvoiceScan, scan);
            return { scan, invoice: saved };
        });
    }

    private async process(scan: InvoiceScan, bytes: Buffer, mimeType: string) {
        if (!config.geminiApiKey) {
            scan.status = 'MANUAL_REQUIRED';
            scan.errorMessage = 'Dịch vụ nhận dạng chưa được cấu hình. Ảnh đã được giữ để bạn nhập tay.';
            return this.scanRepo.save(scan);
        }
        try {
            const genAI = new GoogleGenerativeAI(config.geminiApiKey);
            const model = genAI.getGenerativeModel({
                model: 'gemini-2.5-flash',
                generationConfig: { responseMimeType: 'application/json', temperature: 0 },
            });
            const prompt = `Đọc hóa đơn mua hàng Việt Nam trong ảnh. Chỉ trả JSON theo cấu trúc: {"invoiceNumber":"", "invoiceDate":"YYYY-MM-DD", "partnerName":"", "partnerTaxCode":"", "partnerAddress":"", "items":[{"itemName":"", "unit":"", "quantity":0, "unitPrice":0, "subtotal":0, "taxRate":0, "taxAmount":0}], "subtotal":0, "taxAmount":0, "totalAmount":0, "confidence":0}. Không đoán trường không nhìn rõ; để chuỗi rỗng hoặc 0. confidence từ 0 đến 1.`;
            let lastError: any;
            for (let attempt = 0; attempt < 3; attempt++) {
                try {
                    const response = await model.generateContent([prompt, { inlineData: { data: bytes.toString('base64'), mimeType } }]);
                    const parsed = normalizeInvoiceOcrData(JSON.parse(response.response.text()));
                    scan.ocrParsedData = JSON.stringify(parsed);
                    scan.confidenceScore = parsed.confidence;
                    scan.totalAmount = parsed.totalAmount;
                    scan.status = parsed.confidence >= 0.75 ? 'REVIEW_REQUIRED' : 'MANUAL_REQUIRED';
                    scan.errorMessage = parsed.confidence >= 0.75 ? null : 'Một số thông tin chưa rõ. Vui lòng đối chiếu ảnh và nhập tay.';
                    return this.scanRepo.save(scan);
                } catch (error: any) {
                    lastError = error;
                    const status = Number(error?.status || error?.response?.status || 0);
                    if (attempt === 2 || (status && status !== 429 && status < 500)) break;
                    await new Promise(resolve => setTimeout(resolve, 400 * (2 ** attempt)));
                }
            }
            throw lastError;
        } catch {
            scan.status = 'MANUAL_REQUIRED';
            scan.errorMessage = 'Chưa thể đọc tự động lúc này. Ảnh đã được giữ để bạn nhập tay hoặc thử lại sau.';
            return this.scanRepo.save(scan);
        }
    }

}
