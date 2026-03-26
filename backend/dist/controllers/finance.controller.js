"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteBudgetPlan = exports.updateBudgetPlan = exports.createBudgetPlan = exports.getBudgetPlans = exports.deleteForecast = exports.updateForecast = exports.createForecast = exports.getForecasts = exports.getCashAccounts = exports.createDailyClosing = exports.getDailyClosings = exports.getProfitLoss = exports.getCashFlowSummary = exports.createCashTransaction = exports.getCashTransactions = void 0;
const finance_service_1 = require("../services/finance.service");
const financeService = new finance_service_1.FinanceService();
const getCashTransactions = async (req, res) => {
    try {
        res.json({ success: true, data: await financeService.getCashTransactions(+(req.query.page || 1), +(req.query.limit || 20)) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getCashTransactions = getCashTransactions;
const createCashTransaction = async (req, res) => {
    try {
        res.json({ success: true, data: await financeService.createCashTransaction(req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createCashTransaction = createCashTransaction;
const getCashFlowSummary = async (req, res) => {
    try {
        res.json({ success: true, data: await financeService.getCashFlowSummary(req.query.period) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getCashFlowSummary = getCashFlowSummary;
const getProfitLoss = async (req, res) => {
    try {
        res.json({ success: true, data: await financeService.getProfitLoss(req.query.from, req.query.to) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getProfitLoss = getProfitLoss;
const getDailyClosings = async (req, res) => {
    try {
        res.json({ success: true, data: await financeService.getDailyClosings(+(req.query.page || 1), +(req.query.limit || 20)) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getDailyClosings = getDailyClosings;
const createDailyClosing = async (req, res) => {
    try {
        res.json({ success: true, data: await financeService.createDailyClosing(req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createDailyClosing = createDailyClosing;
const getCashAccounts = async (req, res) => {
    try {
        res.json({ success: true, data: await financeService.getCashAccounts() });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getCashAccounts = getCashAccounts;
const getForecasts = async (req, res) => {
    try {
        res.json({ success: true, data: await financeService.getForecasts() });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getForecasts = getForecasts;
const createForecast = async (req, res) => {
    try {
        res.json({ success: true, data: await financeService.createForecast(req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createForecast = createForecast;
const updateForecast = async (req, res) => {
    try {
        res.json({ success: true, data: await financeService.updateForecast(+req.params.id, req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.updateForecast = updateForecast;
const deleteForecast = async (req, res) => {
    try {
        await financeService.deleteForecast(+req.params.id);
        res.json({ success: true, data: null });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.deleteForecast = deleteForecast;
const getBudgetPlans = async (req, res) => {
    try {
        res.json({ success: true, data: await financeService.getBudgetPlans() });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getBudgetPlans = getBudgetPlans;
const createBudgetPlan = async (req, res) => {
    try {
        res.json({ success: true, data: await financeService.createBudgetPlan(req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createBudgetPlan = createBudgetPlan;
const updateBudgetPlan = async (req, res) => {
    try {
        res.json({ success: true, data: await financeService.updateBudgetPlan(+req.params.id, req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.updateBudgetPlan = updateBudgetPlan;
const deleteBudgetPlan = async (req, res) => {
    try {
        await financeService.deleteBudgetPlan(+req.params.id);
        res.json({ success: true, data: null });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.deleteBudgetPlan = deleteBudgetPlan;
//# sourceMappingURL=finance.controller.js.map