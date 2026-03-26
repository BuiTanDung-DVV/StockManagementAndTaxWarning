import { Request, Response } from 'express';
import { FinanceService } from '../services/finance.service';

const financeService = new FinanceService();

export const getCashTransactions = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getCashTransactions(+(req.query.page || 1), +(req.query.limit || 20), req.query.type as string, req.query.from as string, req.query.to as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createCashTransaction = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.createCashTransaction(req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getCashFlowSummary = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getCashFlowSummary(req.query.period as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getProfitLoss = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getProfitLoss(req.query.from as string, req.query.to as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getExpensesByCategory = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getExpensesByCategory(req.query.from as string, req.query.to as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getDailyClosings = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getDailyClosings(+(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getDailyClosingByDate = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getDailyClosingByDate(req.params.date) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createDailyClosing = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.createDailyClosing(req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getCashAccounts = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getCashAccounts() }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getForecasts = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getForecasts() }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createForecast = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.createForecast(req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const updateForecast = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.updateForecast(+req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const deleteForecast = async (req: Request, res: Response) => {
    try { await financeService.deleteForecast(+req.params.id); res.json({ success: true, data: null }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getBudgetPlans = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getBudgetPlans() }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createBudgetPlan = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.createBudgetPlan(req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const updateBudgetPlan = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.updateBudgetPlan(+req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const deleteBudgetPlan = async (req: Request, res: Response) => {
    try { await financeService.deleteBudgetPlan(+req.params.id); res.json({ success: true, data: null }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

// Invoices
export const getInvoices = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getInvoices(+(req.query.page || 1), +(req.query.limit || 20), req.query.type as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getInvoiceSummary = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getInvoiceSummary(req.query.from as string, req.query.to as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getInvoiceById = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getInvoiceById(+req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createInvoice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.createInvoice(req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

// Tax Obligations
export const getTaxObligations = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getTaxObligations() }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createTaxObligation = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.createTaxObligation(req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

// Purchases Without Invoice
export const getPurchasesWithoutInvoice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.getPurchasesWithoutInvoice(+(req.query.page || 1), +(req.query.limit || 20)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createPurchaseWithoutInvoice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await financeService.createPurchaseWithoutInvoice(req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
