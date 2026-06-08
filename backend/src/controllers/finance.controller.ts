import { Request, Response } from 'express';
import { FinanceService } from '../services/finance.service';
import { AuthRequest } from '../middleware/auth.middleware';

const financeService = new FinanceService();



export const getCashTransactions = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getCashTransactions((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20), req.query.type as string, req.query.from as string, req.query.to as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createCashTransaction = async (req: Request, res: Response) => {
    try { 
        req.body.createdBy = (req as any).user?.sub;
        res.json({ success: true, data: await financeService.createCashTransaction((req as any).shopId, req.body) }); 
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const updateCashTransaction = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.updateCashTransaction((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) { res.status(e.message === 'Cash transaction not found' ? 404 : 500).json({ success: false, message: e.message }); }
};
export const deleteCashTransaction = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.deleteCashTransaction((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
const getShopId = (req: any) => req.isAllShops ? req.shopIds : req.shopId;

export const getCashFlowSummary = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getCashFlowSummary(getShopId(req), req.query.period as string, req.query.from as string, req.query.to as string, (req as any).user?.sub, (req as any).isOwner) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getProfitLoss = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getProfitLoss((req as any).shopId, req.query.from as string, req.query.to as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getInvoiceReconciliation = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getInvoiceReconciliation((req as any).shopId, req.query.from as string, req.query.to as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getExpensesByCategory = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getExpensesByCategory((req as any).shopId, req.query.from as string, req.query.to as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getDailyClosings = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getDailyClosings((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getDailyClosingByDate = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getDailyClosingByDate((req as any).shopId, req.params.date) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createDailyClosing = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.createDailyClosing((req as any).shopId, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getCashAccounts = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getCashAccounts((req as any).shopId) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getForecasts = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getForecasts((req as any).shopId) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createForecast = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.createForecast((req as any).shopId, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const updateForecast = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.updateForecast((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const deleteForecast = async (req: Request, res: Response) => {
    try { await financeService.deleteForecast((req as any).shopId, +req.params.id); res.json({ success: true, data: null }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getBudgetPlans = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getBudgetPlans((req as any).shopId) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createBudgetPlan = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.createBudgetPlan((req as any).shopId, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const updateBudgetPlan = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.updateBudgetPlan((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const deleteBudgetPlan = async (req: Request, res: Response) => {
    try { await financeService.deleteBudgetPlan((req as any).shopId, +req.params.id); res.json({ success: true, data: null }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

// Invoices
export const getInvoices = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getInvoices((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20), req.query.type as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getInvoiceSummary = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getInvoiceSummary((req as any).shopId, req.query.from as string, req.query.to as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getInvoiceById = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getInvoiceById((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createInvoice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.createInvoice((req as any).shopId, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const updateInvoice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.updateInvoice((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) { res.status(e.message === 'Invoice not found' ? 404 : 500).json({ success: false, message: e.message }); }
};
export const deleteInvoice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.deleteInvoice((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

import { EInvoiceService } from '../services/einvoice.service';
const eInvoiceService = new EInvoiceService();

export const issueEInvoice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await eInvoiceService.issueInvoice((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

// Tax Obligations
export const getTaxObligations = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getTaxObligations((req as any).shopId) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createTaxObligation = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.createTaxObligation((req as any).shopId, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const updateTaxObligation = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.updateTaxObligation((req as any).shopId, +req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const deleteTaxObligation = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.deleteTaxObligation((req as any).shopId, +req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

// Purchases Without Invoice
export const getPurchasesWithoutInvoice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getPurchasesWithoutInvoice((req as any).shopId, +(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createPurchaseWithoutInvoice = async (req: AuthRequest, res: Response) => {
    try {
        res.json({
            success: true,
            data: await financeService.createPurchaseWithoutInvoice((req as any).shopId, {
                ...req.body,
                creatorUserId: req.user?.sub,
                creatorRole: req.user?.role,
                creatorAccountType: req.user?.accountType,
                requestIp: req.ip,
            }),
        });
    }
    catch (e: any) {
        if (String(e.message || '').startsWith('Validation:')) {
            res.status(400).json({ success: false, message: String(e.message).replace('Validation: ', '') });
            return;
        }
        res.status(500).json({ success: false, message: e.message });
    }
};

export const approvePurchaseWithoutInvoice = async (req: AuthRequest, res: Response) => {
    try {
        res.json({
            success: true,
            data: await financeService.updatePurchaseWithoutInvoiceApproval((req as any).shopId, +req.params.id, {
                decision: 'APPROVED',
                approvalNotes: req.body?.approvalNotes,
                approverUserId: req.user?.sub,
                approverAccountType: req.user?.accountType,
                requestIp: req.ip,
            }),
        });
    }
    catch (e: any) {
        if (String(e.message || '').startsWith('Validation:')) {
            res.status(400).json({ success: false, message: String(e.message).replace('Validation: ', '') });
            return;
        }
        res.status(500).json({ success: false, message: e.message });
    }
};

export const rejectPurchaseWithoutInvoice = async (req: AuthRequest, res: Response) => {
    try {
        res.json({
            success: true,
            data: await financeService.updatePurchaseWithoutInvoiceApproval((req as any).shopId, +req.params.id, {
                decision: 'REJECTED',
                approvalNotes: req.body?.approvalNotes,
                approverUserId: req.user?.sub,
                approverAccountType: req.user?.accountType,
                requestIp: req.ip,
            }),
        });
    }
    catch (e: any) {
        if (String(e.message || '').startsWith('Validation:')) {
            res.status(400).json({ success: false, message: String(e.message).replace('Validation: ', '') });
            return;
        }
        res.status(500).json({ success: false, message: e.message });
    }
};
