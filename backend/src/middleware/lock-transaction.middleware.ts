import { Response, NextFunction } from 'express';
import { AppDataSource } from '../config/db.config';
import { DailyClosing, CashTransaction, Invoice, PurchaseWithoutInvoice } from '../finance/entities';
import { AuthRequest } from './auth.middleware';
import { ShopMember } from '../shop/entities';
import { SalesOrder } from '../sales/entities';
import { PurchaseOrder, StockTake } from '../inventory/entities';

/**
 * Middleware to check if the shop has already closed the day.
 * If closed, it prevents creating/updating/deleting transactions for that day.
 * OWNER members automatically bypass this check to allow emergency adjustments.
 */
export const lockTransactionMiddleware = async (req: AuthRequest, res: Response, next: NextFunction) => {
    // Only check mutating requests
    if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)) {
        try {
            const shopId = req.shopId;
            if (!shopId) return next();

            const userId = req.user?.sub;
            if (!userId) return next();

            if (!AppDataSource.isInitialized) {
                await AppDataSource.initialize();
            }

            // 1. Check if user is OWNER (OWNER is allowed to edit locked periods for emergency adjustments)
            const memberRepo = AppDataSource.getRepository(ShopMember);
            const member = await memberRepo.findOne({
                where: { userId, shopId, isActive: true },
            });

            if (member && member.memberType === 'OWNER') {
                return next();
            }

            // 2. Determine the date of the transaction
            let targetDate = new Date();
            let dateFound = false;
            
            // Try to extract date from common fields in the request body
            const bodyDate = req.body.transactionDate || req.body.orderDate || req.body.invoiceDate || req.body.stockTakeDate || req.body.purchaseDate || req.body.date;
            if (bodyDate) {
                targetDate = new Date(bodyDate);
                dateFound = true;
            }
            
            // If date is not provided (especially on PUT/PATCH/DELETE where body is minimal or empty)
            // look up the historical transaction date from the database using URL ID
            if (!dateFound) {
                const path = req.path;
                let id: number | null = null;

                const salesMatch = path.match(/^\/sales-orders\/(\d+)/);
                const purchaseMatch = path.match(/^\/purchase-orders\/(\d+)/);
                const stockTakeMatch = path.match(/^\/stock-takes\/(\d+)/);
                const cashTxMatch = path.match(/^\/cash-transactions\/(\d+)/);
                const invoiceMatch = path.match(/^\/invoices\/(\d+)/);
                const purchaseNoInvMatch = path.match(/^\/purchases-without-invoice\/(\d+)/);

                if (salesMatch) {
                    id = parseInt(salesMatch[1], 10);
                    const repo = AppDataSource.getRepository(SalesOrder);
                    const entity = await repo.findOne({ where: { id, shopId } });
                    if (entity && entity.orderDate) {
                        targetDate = new Date(entity.orderDate);
                        dateFound = true;
                    }
                } else if (purchaseMatch) {
                    id = parseInt(purchaseMatch[1], 10);
                    const repo = AppDataSource.getRepository(PurchaseOrder);
                    const entity = await repo.findOne({ where: { id, shopId } });
                    if (entity && entity.orderDate) {
                        targetDate = new Date(entity.orderDate);
                        dateFound = true;
                    }
                } else if (stockTakeMatch) {
                    id = parseInt(stockTakeMatch[1], 10);
                    const repo = AppDataSource.getRepository(StockTake);
                    const entity = await repo.findOne({ where: { id, shopId } });
                    if (entity && entity.stockTakeDate) {
                        targetDate = new Date(entity.stockTakeDate);
                        dateFound = true;
                    }
                } else if (cashTxMatch) {
                    id = parseInt(cashTxMatch[1], 10);
                    const repo = AppDataSource.getRepository(CashTransaction);
                    const entity = await repo.findOne({ where: { id, shopId } });
                    if (entity && entity.transactionDate) {
                        targetDate = new Date(entity.transactionDate);
                        dateFound = true;
                    }
                } else if (invoiceMatch) {
                    id = parseInt(invoiceMatch[1], 10);
                    const repo = AppDataSource.getRepository(Invoice);
                    const entity = await repo.findOne({ where: { id, shopId } });
                    if (entity && entity.invoiceDate) {
                        targetDate = new Date(entity.invoiceDate);
                        dateFound = true;
                    }
                } else if (purchaseNoInvMatch) {
                    id = parseInt(purchaseNoInvMatch[1], 10);
                    const repo = AppDataSource.getRepository(PurchaseWithoutInvoice);
                    const entity = await repo.findOne({ where: { id, shopId } });
                    if (entity && entity.purchaseDate) {
                        targetDate = new Date(entity.purchaseDate);
                        dateFound = true;
                    }
                }
            }

            // Format to YYYY-MM-DD for checking (using local date to avoid UTC timezone shift)
            const year = targetDate.getFullYear();
            const month = String(targetDate.getMonth() + 1).padStart(2, '0');
            const day = String(targetDate.getDate()).padStart(2, '0');
            const dateString = `${year}-${month}-${day}`;

            const closingRepo = AppDataSource.getRepository(DailyClosing);
            
            // Check if there's a daily closing for this date
            const closing = await closingRepo.createQueryBuilder('c')
                .where('c.shop_id = :shopId', { shopId })
                .andWhere('CAST(c.closing_date AS DATE) = :date', { date: dateString })
                .getOne();

            if (closing) {
                return res.status(403).json({
                    success: false,
                    message: `Ngày ${dateString} đã được chốt ca/khóa sổ. Không thể thêm hoặc sửa đổi giao dịch.`,
                });
            }
        } catch (error) {
            console.error('Error in lockTransactionMiddleware:', error);
            // On error, let it pass to avoid blocking entire flow, but log the error
        }
    }
    next();
};
