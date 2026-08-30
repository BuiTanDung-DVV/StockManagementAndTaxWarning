import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import { Invoice, InvoiceItem } from '../system/entities';
import { SalesOrder } from '../sales/entities';
import { FinanceService } from '../services/finance.service';
import { SalesService } from '../services/sales.service';

type SeedProduct = {
    id: number;
    name: string;
    unit: string;
    sellingPrice: number;
};

const argument = (name: string): string | undefined => {
    const prefix = `--${name}=`;
    return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

const parseDate = (value: string | undefined, name: string): Date => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value || '')) {
        throw new Error(`${name} phải có dạng YYYY-MM-DD`);
    }
    const date = new Date(`${value}T00:00:00+07:00`);
    if (Number.isNaN(date.getTime())) throw new Error(`${name} không hợp lệ`);
    return date;
};

const dateKey = (date: Date): string => new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
}).format(date);

const atVietnamTime = (date: Date, hour: number, minute: number): Date =>
    new Date(`${dateKey(date)}T${String(hour).padStart(2, '0')}:${String(minute)
        .padStart(2, '0')}:00+07:00`);

const addDays = (date: Date, days: number): Date =>
    new Date(date.getTime() + days * 86400000);

const roundMoney = (value: number): number => Math.round(value / 1000) * 1000;

async function createInvoiceForOrder(
    shopId: number,
    ownerId: number,
    orderId: number,
    partnerName: string,
): Promise<boolean> {
    return AppDataSource.transaction(async (manager) => {
        const invoiceRepo = manager.getRepository(Invoice);
        const existing = await invoiceRepo.findOne({
            where: {
                shopId,
                referenceType: 'SALES_ORDER',
                referenceId: orderId,
            },
        });
        if (existing) return false;

        const order = await manager.getRepository(SalesOrder).findOne({
            where: { id: orderId, shopId },
            relations: ['items', 'items.product'],
        });
        if (!order) throw new Error(`Không tìm thấy đơn ${orderId} để tạo hóa đơn`);

        const invoice = invoiceRepo.create({
            invoiceNumber: `HD${order.orderCode}`,
            shopId,
            invoiceSymbol: 'C26TSS',
            invoiceType: 'OUT',
            invoiceDate: order.orderDate,
            partnerName,
            referenceType: 'SALES_ORDER',
            referenceId: order.id,
            subtotal: Number(order.subtotal),
            discountAmount: Number(order.discountAmount || 0),
            taxAmount: Number(order.taxAmount || 0),
            totalAmount: Number(order.totalAmount),
            paymentMethod: order.paymentMethod,
            paymentStatus: Number(order.paidAmount) >= Number(order.totalAmount)
                ? 'PAID'
                : 'PARTIAL',
            notes: 'Hóa đơn dữ liệu kiểm thử cập nhật đến hiện tại',
            createdBy: ownerId,
        });
        const savedInvoice = await invoiceRepo.save(invoice);
        await manager.getRepository(InvoiceItem).insert(order.items.map((orderItem) => ({
            invoice: { id: savedInvoice.id } as Invoice,
            productId: orderItem.product.id,
            itemName: orderItem.product.name,
            unit: orderItem.product.unit,
            quantity: Number(orderItem.quantity),
            unitPrice: Number(orderItem.unitPrice),
            subtotal: Number(orderItem.subtotal),
            taxRate: Number(orderItem.taxRate || 0),
            taxAmount: Number(orderItem.taxAmount || 0),
        })));
        return true;
    });
}

async function alignSeededBusinessDates(shopId: number): Promise<void> {
    await AppDataSource.transaction(async (manager) => {
        await manager.query(`
            UPDATE journal_entries journal
            SET entry_date = source_order.order_date,
                created_at = source_order.order_date
            FROM sales_orders source_order
            WHERE journal.shop_id = $1
              AND journal.reference_type = 'SALES_ORDER'
              AND journal.reference_id = source_order.id
              AND source_order.shop_id = $1
              AND source_order.order_code LIKE $2
        `, [shopId, `SOA${shopId}%`]);
        await manager.query(`
            UPDATE journal_lines line
            SET created_at = journal.entry_date
            FROM journal_entries journal
            WHERE line.journal_entry_id = journal.id
              AND journal.shop_id = $1
              AND journal.reference_type = 'SALES_ORDER'
              AND EXISTS (
                  SELECT 1
                  FROM sales_orders source_order
                  WHERE source_order.id = journal.reference_id
                    AND source_order.order_code LIKE $2
              )
        `, [shopId, `SOA${shopId}%`]);
        await manager.query(`
            UPDATE sales_order_payments payment
            SET paid_at = source_order.order_date
            FROM sales_orders source_order
            WHERE payment.order_id = source_order.id
              AND payment.shop_id = $1
              AND source_order.shop_id = $1
              AND source_order.order_code LIKE $2
        `, [shopId, `SOA${shopId}%`]);
        await manager.query(`
            UPDATE inventory_movements movement
            SET created_at = source_order.order_date
            FROM sales_orders source_order
            WHERE movement.reference_type = 'SALES_ORDER'
              AND movement.reference_id = source_order.id
              AND movement.shop_id = $1
              AND source_order.shop_id = $1
              AND source_order.order_code LIKE $2
        `, [shopId, `SOA${shopId}%`]);
        await manager.query(`
            UPDATE invoices invoice
            SET created_at = source_order.order_date
            FROM sales_orders source_order
            WHERE invoice.reference_type = 'SALES_ORDER'
              AND invoice.reference_id = source_order.id
              AND invoice.shop_id = $1
              AND source_order.shop_id = $1
              AND source_order.order_code LIKE $2
        `, [shopId, `SOA${shopId}%`]);
        await manager.query(`
            UPDATE journal_entries journal
            SET entry_date = cash_tx.transaction_date::timestamp
                AT TIME ZONE 'Asia/Ho_Chi_Minh',
                created_at = cash_tx.transaction_date::timestamp
                    AT TIME ZONE 'Asia/Ho_Chi_Minh'
            FROM cash_transactions cash_tx
            WHERE journal.shop_id = $1
              AND journal.reference_type = 'CASH_TRANSACTION'
              AND journal.reference_id = cash_tx.id
              AND cash_tx.shop_id = $1
              AND cash_tx.transaction_code LIKE $2
        `, [shopId, `TE${shopId}%`]);
    });
}

async function seedShop(
    shopId: number,
    from: Date,
    to: Date,
    ordersPerDay: number,
): Promise<Record<string, number>> {
    const [ownerRows, customerRows, productRows] = await Promise.all([
        AppDataSource.query(`
            SELECT user_id::int AS id
            FROM shop_members
            WHERE shop_id = $1
              AND member_type = 'OWNER'
              AND status = 'ACTIVE'
              AND is_active = true
            ORDER BY id
            LIMIT 1
        `, [shopId]),
        AppDataSource.query(`
            SELECT id::int, name
            FROM customers
            WHERE shop_id = $1 AND is_active = true
            ORDER BY id
        `, [shopId]),
        AppDataSource.query(`
            SELECT
                product.id::int,
                product.name,
                product.unit,
                product.selling_price::numeric AS "sellingPrice"
            FROM products product
            JOIN (
                SELECT product_id, SUM(quantity) AS quantity
                FROM inventory_stocks
                WHERE shop_id = $1
                GROUP BY product_id
            ) stock ON stock.product_id = product.id
            JOIN (
                SELECT product_id, SUM(remaining_qty) AS quantity
                FROM inventory_lots
                WHERE shop_id = $1
                GROUP BY product_id
            ) lot ON lot.product_id = product.id
            WHERE product.shop_id = $1
              AND product.is_active = true
              AND stock.quantity >= 12
              AND lot.quantity >= 12
              AND product.selling_price > 0
            ORDER BY product.id
        `, [shopId]),
    ]);
    if (!ownerRows.length || !customerRows.length || productRows.length < 12) {
        throw new Error(`Shop ${shopId} thiếu owner, khách hàng hoặc tồn khả dụng`);
    }

    const ownerId = Number(ownerRows[0].id);
    const products: SeedProduct[] = productRows.map((row: any) => ({
        id: Number(row.id),
        name: String(row.name),
        unit: String(row.unit),
        sellingPrice: Number(row.sellingPrice),
    }));
    const salesService = new SalesService();
    const financeService = new FinanceService();
    const result = {
        createdOrders: 0,
        skippedOrders: 0,
        createdInvoices: 0,
        createdExpenses: 0,
        createdClosings: 0,
    };

    for (let day = new Date(from), dayIndex = 0; day <= to; day = addDays(day, 1), dayIndex += 1) {
        const key = dateKey(day);
        const compactDate = key.slice(5).replace('-', '');
        for (let orderIndex = 0; orderIndex < ordersPerDay; orderIndex += 1) {
            const orderCode = `SOA${shopId}${compactDate}${orderIndex + 1}`;
            const [existing] = await AppDataSource.query(
                'SELECT id::int FROM sales_orders WHERE order_code = $1',
                [orderCode],
            );
            const customer = customerRows[(dayIndex * ordersPerDay + orderIndex)
                % customerRows.length];
            let orderId: number;
            if (existing) {
                orderId = Number(existing.id);
                result.skippedOrders += 1;
            } else {
                const lineCount = 1 + ((dayIndex + orderIndex) % 3);
                const items = Array.from({ length: lineCount }, (_, lineIndex) => {
                    const product = products[
                        (dayIndex * 7 + orderIndex * 11 + lineIndex * 17)
                        % products.length
                    ];
                    return {
                        productId: product.id,
                        quantity: 1 + ((dayIndex + orderIndex + lineIndex) % 3),
                        unitPrice: product.sellingPrice,
                    };
                });
                const gross = items.reduce(
                    (sum, item) => sum + item.quantity * item.unitPrice,
                    0,
                );
                const discountAmount = (dayIndex + orderIndex) % 5 === 0
                    ? roundMoney(gross * 0.02)
                    : 0;
                const paymentMethods = ['CASH', 'TRANSFER', 'QR'];
                const created = await salesService.create(shopId, {
                    orderCode,
                    orderDate: atVietnamTime(day, 8 + orderIndex * 3, 15),
                    items,
                    discountAmount,
                    settleInFull: true,
                    paymentMethod: paymentMethods[(dayIndex + orderIndex) % 3],
                    notes: 'Dữ liệu kiểm thử cập nhật đến hiện tại',
                    createdBy: ownerId,
                });
                orderId = Number(created.id);
                result.createdOrders += 1;
            }
            await AppDataSource.query(`
                UPDATE sales_orders
                SET customer_id = $1
                WHERE id = $2 AND shop_id = $3 AND customer_id IS NULL
            `, [Number(customer.id), orderId, shopId]);

            if (orderIndex === 0 && await createInvoiceForOrder(
                shopId,
                ownerId,
                orderId,
                String(customer.name),
            )) {
                result.createdInvoices += 1;
            }
        }

        const expenseCode = `TE${shopId}${compactDate}`;
        const [expenseExists] = await AppDataSource.query(
            'SELECT id FROM cash_transactions WHERE transaction_code = $1',
            [expenseCode],
        );
        if (!expenseExists) {
            const monthDay = Number(key.slice(-2));
            const category = monthDay === 5
                ? 'RENT'
                : monthDay === 10
                    ? 'SALARY'
                    : monthDay === 18
                        ? 'UTILITIES'
                        : 'DELIVERY';
            const amount = category === 'RENT'
                ? 18000000
                : category === 'SALARY'
                    ? 42000000
                    : category === 'UTILITIES'
                        ? 5600000
                        : 250000 + ((dayIndex * 37000 + shopId * 1000) % 430000);
            await financeService.createCashTransaction(shopId, {
                transactionCode: expenseCode,
                type: 'EXPENSE',
                category,
                amount,
                paymentMethod: category === 'DELIVERY' ? 'CASH' : 'TRANSFER',
                counterparty: category === 'DELIVERY'
                    ? 'Đơn vị giao nhận'
                    : 'Chi phí vận hành cửa hàng',
                referenceType: 'DATASET_EXTENSION',
                referenceId: Number(key.replaceAll('-', '')),
                transactionDate: day,
                notes: `Dữ liệu kiểm thử ngày ${key}`,
                createdBy: ownerId,
            });
            result.createdExpenses += 1;
        }

        const closing = await financeService.getDailyClosingByDate(shopId, key);
        if (!closing.closed) {
            await financeService.createDailyClosing(shopId, {
                closingDate: key as any,
                closingCash: Number(closing.expectedCash || 0),
                notes: 'Chốt ngày tự động cho dữ liệu kiểm thử',
                closedBy: ownerId,
            });
            result.createdClosings += 1;
        }
    }
    await alignSeededBusinessDates(shopId);
    return result;
}

async function main(): Promise<void> {
    const shopIds = (argument('shop-ids') || '')
        .split(',')
        .map((value) => Number(value.trim()))
        .filter((value) => Number.isSafeInteger(value) && value > 0);
    const from = parseDate(argument('from'), '--from');
    const to = parseDate(argument('to'), '--to');
    const ordersPerDay = Number(argument('orders-per-day') || 3);
    if (!shopIds.length || from > to || !Number.isInteger(ordersPerDay)
        || ordersPerDay < 1 || ordersPerDay > 6) {
        throw new Error('Tham số shop, kỳ hoặc số đơn mỗi ngày không hợp lệ');
    }
    if (!process.argv.includes('--apply')) {
        throw new Error('Thêm --apply để xác nhận ghi dữ liệu kiểm thử');
    }

    await AppDataSource.initialize();
    try {
        await AppDataSource.query(`
            INSERT INTO system_configs (
                shop_id, config_key, config_value, description
            )
            VALUES (
                NULL,
                'DAILY_CLOSING_EXPLANATION_THRESHOLD',
                '50000',
                'Mức chênh lệch két bắt buộc giải trình khi chốt ngày'
            )
            ON CONFLICT (config_key) WHERE shop_id IS NULL
            DO UPDATE SET
                config_value = EXCLUDED.config_value,
                description = EXCLUDED.description
        `);
        const rows = [];
        for (const shopId of shopIds) {
            rows.push({
                shopId,
                ...(await seedShop(shopId, from, to, ordersPerDay)),
            });
        }
        console.table(rows);
    } finally {
        await AppDataSource.destroy();
    }
}

main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
});
