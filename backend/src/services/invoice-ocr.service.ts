import { GoogleGenerativeAI } from '@google/generative-ai';
import { AppDataSource } from '../config/db.config';
import { config } from '../config/env.config';
import { Invoice, InvoiceItem, InvoiceScan } from '../system/entities';
import { ImageStorageService, ProductImageUploadRequest } from './image-storage.service';
import { createHash } from 'node:crypto';
import { lockShopMutation } from '../utils/shop-mutation-lock';
import { ActivityLog } from '../system/entities';
import { PurchaseOrder } from '../inventory/entities';
import { InventoryService } from './inventory.service';
import { PurchaseWriteActor } from '../inventory/purchase-write-authorization';

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

type OcrFailureStage = 'PROVIDER' | 'JSON_PARSING' | 'VALIDATION';

export function invoiceOcrFailureDiagnostic(error: unknown, stage: OcrFailureStage) {
    const value = error as { status?: unknown; response?: { status?: unknown } } | null;
    const candidate = value?.status ?? value?.response?.status;
    const number = typeof candidate === 'number' || typeof candidate === 'string' ? Number(candidate) : NaN;
    const status = Number.isInteger(number) && number >= 100 && number <= 599 ? number : null;
    let code = 'PROVIDER_ERROR';
    if (stage === 'JSON_PARSING') code = 'INVALID_JSON';
    else if (stage === 'VALIDATION') code = 'INVALID_INVOICE';
    else if (status === 401 || status === 403) code = 'PROVIDER_ACCESS_DENIED';
    else if (status === 404) code = 'PROVIDER_NOT_FOUND';
    else if (status === 429) code = 'PROVIDER_RATE_LIMIT';
    else if (status !== null && status >= 500) code = 'PROVIDER_UNAVAILABLE';
    // Never log provider messages/URLs: they can contain API keys or invoice text.
    return { stage, code, status };
}

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
            || normalized.itemName.length > 200
            || normalized.unit.length > 20
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
        const invoice = scan.status === 'CONFIRMED' && scan.referenceType === 'INVOICE' && scan.referenceId
            ? await AppDataSource.getRepository(Invoice).findOne({ where: { id: scan.referenceId, shopId }, relations: ['items'] }) : null;
        const linkedPurchaseOrder = invoice?.referenceType === 'PURCHASE_ORDER' && invoice.referenceId
            ? await AppDataSource.getRepository(PurchaseOrder).findOne({ where: { id: invoice.referenceId, shopId }, select: ['id', 'orderCode', 'status'] }) : null;
        return Object.assign(scan, {
            invoice,
            linkedPurchaseOrder,
            canCreatePurchaseOrder: Boolean(invoice && invoice.invoiceType === 'IN' && !invoice.referenceType),
            canEditInvoice: Boolean(invoice && invoice.invoiceType === 'IN' && !invoice.referenceType && Number(invoice.discountAmount) === 0),
            editableData: invoice ? invoiceScanData(invoice) : null,
            invoiceRevision: invoice ? invoiceScanRevision(invoice) : null,
        });
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
            await lockShopMutation(manager, shopId);
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

    async updateConfirmedInvoice(shopId: number, id: number, userId: number, input: unknown) {
        const data = normalizeInvoiceOcrData(input);
        const expected = (input as Record<string, unknown>).invoiceRevision;
        if (typeof expected !== 'string' || !/^[a-f0-9]{64}$/.test(expected)) {
            throw new InvoiceOcrError('Mở lại phiếu quét để tải hóa đơn mới nhất', 409);
        }
        return AppDataSource.transaction(async manager => {
            await lockShopMutation(manager, shopId);
            const scan = await manager.getRepository(InvoiceScan).findOne({ where: { id, shopId }, lock: { mode: 'pessimistic_write' } });
            if (!scan || scan.status !== 'CONFIRMED' || scan.referenceType !== 'INVOICE' || !scan.referenceId) {
                throw new InvoiceOcrError('Phiếu quét chưa liên kết hóa đơn đã lưu', 409);
            }
            const invoice = await manager.getRepository(Invoice).findOne({ where: { id: scan.referenceId, shopId }, relations: ['items'] });
            if (!invoice) throw new InvoiceOcrError('Không tìm thấy hóa đơn đã lưu', 404);
            if (invoice.invoiceType !== 'IN' || invoice.referenceType || Number(invoice.discountAmount) !== 0) {
                throw new InvoiceOcrError('Hóa đơn này cần được sửa tại chứng từ nguồn', 409);
            }
            if (invoiceScanRevision(invoice) !== expected) throw new InvoiceOcrError('Hóa đơn đã được thay đổi. Tải lại trước khi sửa tiếp.', 409);
            const duplicate = await manager.getRepository(Invoice).findOne({ where: { shopId, invoiceType: 'IN', invoiceNumber: data.invoiceNumber } });
            if (duplicate && duplicate.id !== invoice.id) throw new InvoiceOcrError('Số hóa đơn này đã tồn tại trong cửa hàng', 409);
            const before = { invoiceNumber: invoice.invoiceNumber, totalAmount: invoice.totalAmount, itemCount: invoice.items.length };
            await manager.getRepository(InvoiceItem).delete({ invoice: { id: invoice.id } });
            Object.assign(invoice, {
                invoiceNumber: data.invoiceNumber, invoiceDate: new Date(`${data.invoiceDate}T00:00:00Z`),
                partnerName: data.partnerName, partnerTaxCode: data.partnerTaxCode || null, partnerAddress: data.partnerAddress || null,
                subtotal: data.subtotal, taxAmount: data.taxAmount, totalAmount: data.totalAmount,
                items: data.items.map(item => manager.create(InvoiceItem, { ...item, productId: null })),
            });
            const saved = await manager.save(Invoice, invoice);
            scan.confirmedData = JSON.stringify(data);
            scan.totalAmount = data.totalAmount;
            await manager.save(InvoiceScan, scan);
            await manager.getRepository(ActivityLog).save({
                shopId, userId, action: 'UPDATE', entityType: 'INVOICE', entityId: saved.id, entityName: saved.invoiceNumber,
                description: `Chỉnh sửa hóa đơn từ phiếu quét ${scan.scanCode}`,
                oldValue: JSON.stringify(before), newValue: JSON.stringify({ invoiceNumber: saved.invoiceNumber, totalAmount: saved.totalAmount, itemCount: data.items.length }),
            });
            return { scan, invoice: saved };
        });
    }

    async createPurchaseDraft(shopId: number, id: number, actor: PurchaseWriteActor, input: unknown) {
        if (!input || typeof input !== 'object' || Array.isArray(input)) throw new InvoiceOcrError('Dữ liệu phiếu nhập không hợp lệ');
        const { invoiceRevision, confirmNotPreviouslyReceived, ...draft } = input as Record<string, unknown>;
        if (confirmNotPreviouslyReceived !== true) throw new InvoiceOcrError('Xác nhận các hàng này chưa được ghi tăng kho trong ứng dụng');
        const runner = AppDataSource.createQueryRunner();
        await runner.connect(); await runner.startTransaction();
        try {
            await lockShopMutation(runner.manager, shopId);
            const scan = await runner.manager.getRepository(InvoiceScan).findOne({ where: { id, shopId }, lock: { mode: 'pessimistic_write' } });
            if (!scan || scan.status !== 'CONFIRMED' || scan.referenceType !== 'INVOICE' || !scan.referenceId) throw new InvoiceOcrError('Lưu và kiểm tra hóa đơn trước khi lập phiếu nhập', 409);
            const invoice = await runner.manager.getRepository(Invoice).findOne({ where: { id: scan.referenceId, shopId }, relations: ['items'] });
            if (!invoice || invoice.invoiceType !== 'IN') throw new InvoiceOcrError('Chỉ lập phiếu nhập từ hóa đơn đầu vào', 409);
            if (invoice.referenceType) throw new InvoiceOcrError('Hóa đơn đã liên kết chứng từ. Mở chứng từ đó để tránh nhập trùng.', 409);
            if (typeof invoiceRevision !== 'string' || invoiceRevision !== invoiceScanRevision(invoice)) throw new InvoiceOcrError('Hóa đơn đã thay đổi. Mở lại và đối chiếu trước khi lập phiếu nhập.', 409);
            const existing = await runner.manager.getRepository(PurchaseOrder).createQueryBuilder('po')
                .where('po.shopId = :shopId AND po.invoiceNumber = :number AND po.status <> :cancelled', { shopId, number: invoice.invoiceNumber, cancelled: 'CANCELLED' }).getOne();
            if (existing) throw new InvoiceOcrError(`Số hóa đơn đã được ghi trên phiếu nhập ${existing.orderCode}. Kiểm tra trước để tránh trùng kho.`, 409);
            const saved = await new InventoryService().createPurchaseOrder(shopId,
                { ...draft, invoiceNumber: invoice.invoiceNumber }, runner, actor);
            if (Math.abs(Number(saved.totalAmount) - Number(invoice.totalAmount)) > 1) throw new InvoiceOcrError('Tổng giá vốn nhập chưa khớp tổng hóa đơn (sai số tối đa 1 đồng). Kiểm tra đơn giá và quy đổi.');
            invoice.referenceType = 'PURCHASE_ORDER'; invoice.referenceId = saved.id;
            await runner.manager.save(Invoice, invoice);
            await runner.manager.getRepository(ActivityLog).save({ shopId, userId: actor.id, action: 'CREATE',
                entityType: 'PURCHASE_ORDER', entityId: saved.id, entityName: saved.orderCode,
                description: `Lập phiếu nhập chờ từ hóa đơn ${invoice.invoiceNumber}; chưa ghi kho hoặc công nợ`,
            });
            await runner.commitTransaction();
            return saved;
        } catch (error) { await runner.rollbackTransaction(); throw error; }
        finally { await runner.release(); }
    }

    private async process(scan: InvoiceScan, bytes: Buffer, mimeType: string) {
        if (!config.geminiApiKey) {
            console.warn('[invoice-ocr] processing failed', {
                shopId: scan.shopId, scanId: scan.id, model: 'gemini-3.5-flash-lite',
                attempts: 0, stage: 'CONFIGURATION', code: 'NOT_CONFIGURED', status: null,
            });
            scan.status = 'MANUAL_REQUIRED';
            scan.errorMessage = 'Dịch vụ nhận dạng chưa được cấu hình. Ảnh đã được giữ để bạn nhập tay.';
            return this.scanRepo.save(scan);
        }
        let stage: OcrFailureStage = 'PROVIDER';
        let attempts = 0;
        try {
            const genAI = new GoogleGenerativeAI(config.geminiApiKey);
            const model = genAI.getGenerativeModel({
                model: 'gemini-3.5-flash-lite',
                generationConfig: { responseMimeType: 'application/json', temperature: 0 },
            });
            const prompt = `Đọc hóa đơn mua hàng Việt Nam trong ảnh. Chỉ trả JSON theo cấu trúc: {"invoiceNumber":"", "invoiceDate":"YYYY-MM-DD", "partnerName":"", "partnerTaxCode":"", "partnerAddress":"", "items":[{"itemName":"", "unit":"", "quantity":0, "unitPrice":0, "subtotal":0, "taxRate":0, "taxAmount":0}], "subtotal":0, "taxAmount":0, "totalAmount":0, "confidence":0}. Không đoán trường không nhìn rõ; để chuỗi rỗng hoặc 0. confidence từ 0 đến 1.`;
            let lastError: any;
            for (let attempt = 0; attempt < 3; attempt++) {
                try {
                    stage = 'PROVIDER';
                    attempts++;
                    const response = await model.generateContent([prompt, { inlineData: { data: bytes.toString('base64'), mimeType } }]);
                    stage = 'JSON_PARSING';
                    const raw = JSON.parse(response.response.text());
                    stage = 'VALIDATION';
                    const parsed = normalizeInvoiceOcrData(raw);
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
        } catch (error) {
            console.warn('[invoice-ocr] processing failed', {
                shopId: scan.shopId, scanId: scan.id, model: 'gemini-3.5-flash-lite', attempts,
                ...invoiceOcrFailureDiagnostic(error, stage),
            });
            scan.status = 'MANUAL_REQUIRED';
            scan.errorMessage = 'Chưa thể đọc tự động lúc này. Ảnh đã được giữ để bạn nhập tay hoặc thử lại sau.';
            return this.scanRepo.save(scan);
        }
    }

}

export function invoiceScanData(invoice: Invoice): ParsedInvoice {
    return {
        invoiceNumber: invoice.invoiceNumber,
        invoiceDate: invoice.invoiceDate instanceof Date ? invoice.invoiceDate.toISOString().slice(0, 10) : String(invoice.invoiceDate).slice(0, 10),
        partnerName: invoice.partnerName, partnerTaxCode: invoice.partnerTaxCode || '', partnerAddress: invoice.partnerAddress || '',
        subtotal: Number(invoice.subtotal), taxAmount: Number(invoice.taxAmount), totalAmount: Number(invoice.totalAmount), confidence: 1,
        items: [...(invoice.items || [])].sort((a, b) => a.id - b.id).map(item => ({
            itemName: item.itemName, unit: item.unit, quantity: Number(item.quantity), unitPrice: Number(item.unitPrice),
            subtotal: Number(item.subtotal), taxRate: Number(item.taxRate), taxAmount: Number(item.taxAmount),
        })),
    };
}

export function invoiceScanRevision(invoice: Invoice) {
    return createHash('sha256').update(JSON.stringify(invoiceScanData(invoice))).digest('hex');
}
