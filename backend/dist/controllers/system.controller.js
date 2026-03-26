"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createPurchaseWithoutInvoice = exports.getPurchasesWithoutInvoice = exports.updateInvoiceScan = exports.createInvoiceScan = exports.getInvoiceScans = exports.scanInvoice = exports.createInvoice = exports.getInvoiceSummary = exports.getInvoiceById = exports.getInvoices = exports.getActivityLogs = exports.saveShopProfile = exports.getShopProfile = void 0;
const system_service_1 = require("../services/system.service");
const systemService = new system_service_1.SystemService();
const getShopProfile = async (req, res) => {
    try {
        res.json({ success: true, data: await systemService.getShopProfile() });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getShopProfile = getShopProfile;
const saveShopProfile = async (req, res) => {
    try {
        res.json({ success: true, data: await systemService.updateShopProfile(1, req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.saveShopProfile = saveShopProfile;
const getActivityLogs = async (req, res) => {
    try {
        res.json({ success: true, data: await systemService.getActivityLogs(+(req.query.page || 1), +(req.query.limit || 20)) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getActivityLogs = getActivityLogs;
const getInvoices = async (req, res) => {
    try {
        res.json({ success: true, data: await systemService.getInvoices(+(req.query.page || 1), +(req.query.limit || 20)) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getInvoices = getInvoices;
const getInvoiceById = async (req, res) => {
    try {
        res.json({ success: true, data: {} });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getInvoiceById = getInvoiceById;
const getInvoiceSummary = async (req, res) => {
    try {
        res.json({ success: true, data: {} });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getInvoiceSummary = getInvoiceSummary;
const createInvoice = async (req, res) => {
    try {
        res.json({ success: true, data: {} });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createInvoice = createInvoice;
const scanInvoice = async (req, res) => {
    try {
        res.json({ success: true, data: await systemService.scanInvoice(req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.scanInvoice = scanInvoice;
const getInvoiceScans = async (req, res) => {
    try {
        res.json({ success: true, data: [] });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getInvoiceScans = getInvoiceScans;
const createInvoiceScan = async (req, res) => {
    try {
        res.json({ success: true, data: {} });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createInvoiceScan = createInvoiceScan;
const updateInvoiceScan = async (req, res) => {
    try {
        res.json({ success: true, data: {} });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.updateInvoiceScan = updateInvoiceScan;
const getPurchasesWithoutInvoice = async (req, res) => {
    try {
        res.json({ success: true, data: await systemService.getPurchaseWithoutInvoice(+(req.query.page || 1), +(req.query.limit || 20)) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getPurchasesWithoutInvoice = getPurchasesWithoutInvoice;
const createPurchaseWithoutInvoice = async (req, res) => {
    try {
        res.json({ success: true, data: {} });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createPurchaseWithoutInvoice = createPurchaseWithoutInvoice;
//# sourceMappingURL=system.controller.js.map