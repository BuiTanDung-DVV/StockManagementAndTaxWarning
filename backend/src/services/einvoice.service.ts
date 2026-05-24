import { Invoice } from '../finance/entities';
import { AppDataSource } from '../config/db.config';

export interface IEInvoiceProvider {
    issueInvoice(invoice: Invoice): Promise<{ success: boolean; invoiceSymbol?: string; invoiceNumber?: string; message?: string }>;
    cancelInvoice(invoiceSymbol: string, invoiceNumber: string, reason: string): Promise<{ success: boolean; message?: string }>;
}

export class MockEInvoiceProvider implements IEInvoiceProvider {
    async issueInvoice(invoice: Invoice) {
        // Simulate API call delay
        await new Promise(resolve => setTimeout(resolve, 500));
        
        return {
            success: true,
            invoiceSymbol: '1C26TMC',
            invoiceNumber: '0000' + Math.floor(Math.random() * 10000).toString().padStart(4, '0'),
            message: 'Đã phát hành hóa đơn thành công (Mock)',
        };
    }

    async cancelInvoice(invoiceSymbol: string, invoiceNumber: string, reason: string) {
        await new Promise(resolve => setTimeout(resolve, 500));
        return {
            success: true,
            message: 'Đã hủy hóa đơn (Mock)',
        };
    }
}

export class EInvoiceService {
    private provider: IEInvoiceProvider;
    private invoiceRepo = AppDataSource.getRepository(Invoice);

    constructor() {
        // In a real scenario, this would be injected or instantiated based on configuration
        this.provider = new MockEInvoiceProvider();
    }

    async issueInvoice(shopId: number, invoiceId: number) {
        const invoice = await this.invoiceRepo.findOne({ where: { id: invoiceId, shopId }, relations: ['items'] });
        if (!invoice) throw new Error('Hóa đơn không tồn tại');
        if (invoice.invoiceSymbol && invoice.invoiceNumber && !invoice.invoiceNumber.startsWith('HD')) {
            throw new Error('Hóa đơn này đã được phát hành');
        }

        const result = await this.provider.issueInvoice(invoice);
        if (result.success && result.invoiceSymbol && result.invoiceNumber) {
            invoice.invoiceSymbol = result.invoiceSymbol;
            invoice.invoiceNumber = result.invoiceNumber;
            await this.invoiceRepo.save(invoice);
        }

        return result;
    }
}
