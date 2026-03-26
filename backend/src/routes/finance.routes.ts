import { Router } from 'express';
import * as financeCtrl from '../controllers/finance.controller';

const router = Router();

// Cash Transactions
router.get('/cash-transactions', financeCtrl.getCashTransactions);
router.post('/cash-transactions', financeCtrl.createCashTransaction);
router.get('/cash-transactions/summary', financeCtrl.getCashFlowSummary);
router.get('/cash-transactions/profit-loss', financeCtrl.getProfitLoss);
router.get('/cash-transactions/expenses-by-category', financeCtrl.getExpensesByCategory);

// Daily Closings
router.get('/daily-closings', financeCtrl.getDailyClosings);
router.get('/daily-closings/:date', financeCtrl.getDailyClosingByDate);
router.post('/daily-closings', financeCtrl.createDailyClosing);

// Cash Accounts
router.get('/cash-accounts', financeCtrl.getCashAccounts);

// Cashflow Forecasts
router.get('/cashflow-forecasts', financeCtrl.getForecasts);
router.post('/cashflow-forecasts', financeCtrl.createForecast);
router.put('/cashflow-forecasts/:id', financeCtrl.updateForecast);
router.delete('/cashflow-forecasts/:id', financeCtrl.deleteForecast);

// Budget Plans
router.get('/budget-plans', financeCtrl.getBudgetPlans);
router.post('/budget-plans', financeCtrl.createBudgetPlan);
router.put('/budget-plans/:id', financeCtrl.updateBudgetPlan);
router.delete('/budget-plans/:id', financeCtrl.deleteBudgetPlan);

// Invoices
router.get('/invoices', financeCtrl.getInvoices);
router.get('/invoices/summary', financeCtrl.getInvoiceSummary);
router.get('/invoices/:id', financeCtrl.getInvoiceById);
router.post('/invoices', financeCtrl.createInvoice);


// Tax Obligations
router.get('/tax-obligations', financeCtrl.getTaxObligations);
router.post('/tax-obligations', financeCtrl.createTaxObligation);

// Purchases Without Invoice
router.get('/purchases-without-invoice', financeCtrl.getPurchasesWithoutInvoice);
router.post('/purchases-without-invoice', financeCtrl.createPurchaseWithoutInvoice);

export default router;
