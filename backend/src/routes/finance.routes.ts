import { Router } from 'express';
import * as financeCtrl from '../controllers/finance.controller';
import { requirePermission } from '../middleware/permission.middleware';

const router = Router();

// Cash Transactions
router.get('/cash-transactions', requirePermission('finance', 'view'), financeCtrl.getCashTransactions);
router.post('/cash-transactions', requirePermission('finance', 'edit'), financeCtrl.createCashTransaction);
router.put('/cash-transactions/:id', requirePermission('finance', 'edit'), financeCtrl.updateCashTransaction);
router.delete('/cash-transactions/:id', requirePermission('finance', 'edit'), financeCtrl.deleteCashTransaction);
router.get('/cash-transactions/summary', requirePermission('finance', 'view'), financeCtrl.getCashFlowSummary);
router.get('/cash-transactions/profit-loss', requirePermission('finance', 'view'), financeCtrl.getProfitLoss);
router.get('/cash-transactions/invoice-reconciliation', requirePermission('finance', 'view'), financeCtrl.getInvoiceReconciliation);
router.get('/cash-transactions/expenses-by-category', requirePermission('finance', 'view'), financeCtrl.getExpensesByCategory);

// Daily Closings
router.get('/daily-closings', requirePermission('finance', 'view'), financeCtrl.getDailyClosings);
router.get('/daily-closings/:date', requirePermission('finance', 'view'), financeCtrl.getDailyClosingByDate);
router.post('/daily-closings', requirePermission('finance', 'edit'), financeCtrl.createDailyClosing);

// Cash Accounts
router.get('/cash-accounts', requirePermission('finance', 'view'), financeCtrl.getCashAccounts);

// Cashflow Forecasts
router.get('/cashflow-forecasts', requirePermission('finance', 'view'), financeCtrl.getForecasts);
router.post('/cashflow-forecasts', requirePermission('finance', 'edit'), financeCtrl.createForecast);
router.put('/cashflow-forecasts/:id', requirePermission('finance', 'edit'), financeCtrl.updateForecast);
router.delete('/cashflow-forecasts/:id', requirePermission('finance', 'edit'), financeCtrl.deleteForecast);

// Budget Plans
router.get('/budget-plans', requirePermission('finance', 'view'), financeCtrl.getBudgetPlans);
router.post('/budget-plans', requirePermission('finance', 'edit'), financeCtrl.createBudgetPlan);
router.put('/budget-plans/:id', requirePermission('finance', 'edit'), financeCtrl.updateBudgetPlan);
router.delete('/budget-plans/:id', requirePermission('finance', 'edit'), financeCtrl.deleteBudgetPlan);

// Invoices
router.get('/invoices', requirePermission('finance', 'view'), financeCtrl.getInvoices);
router.get('/invoices/summary', requirePermission('finance', 'view'), financeCtrl.getInvoiceSummary);
router.get('/invoices/:id', requirePermission('finance', 'view'), financeCtrl.getInvoiceById);
router.post('/invoices', requirePermission('finance', 'edit'), financeCtrl.createInvoice);
router.put('/invoices/:id', requirePermission('finance', 'edit'), financeCtrl.updateInvoice);
router.delete('/invoices/:id', requirePermission('finance', 'edit'), financeCtrl.deleteInvoice);

// Tax Obligations
router.get('/tax-obligations', requirePermission('finance', 'view'), financeCtrl.getTaxObligations);
router.post('/tax-obligations', requirePermission('finance', 'edit'), financeCtrl.createTaxObligation);
router.put('/tax-obligations/:id', requirePermission('finance', 'edit'), financeCtrl.updateTaxObligation);
router.delete('/tax-obligations/:id', requirePermission('finance', 'edit'), financeCtrl.deleteTaxObligation);

// Purchases Without Invoice
router.get('/purchases-without-invoice', requirePermission('finance', 'view'), financeCtrl.getPurchasesWithoutInvoice);
router.post('/purchases-without-invoice', requirePermission('finance', 'edit'), financeCtrl.createPurchaseWithoutInvoice);
router.post('/purchases-without-invoice/:id/approve', requirePermission('finance', 'edit'), financeCtrl.approvePurchaseWithoutInvoice);
router.post('/purchases-without-invoice/:id/reject', requirePermission('finance', 'edit'), financeCtrl.rejectPurchaseWithoutInvoice);

export default router;
