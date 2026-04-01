"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.addPayment = exports.addEvidence = exports.getDebtEvidence = exports.debtAging = exports.overdueDebts = exports.createReceivable = exports.receivables = exports.remove = exports.update = exports.create = exports.findOne = exports.findAll = void 0;
const customer_service_1 = require("../services/customer.service");
const customerService = new customer_service_1.CustomerService();
const findAll = async (req, res) => {
    try {
        res.json({ success: true, data: await customerService.findAll(+(req.query.page || 1), +(req.query.limit || 20), req.query.search) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.findAll = findAll;
const findOne = async (req, res) => {
    try {
        res.json({ success: true, data: await customerService.findById(+req.params.id) });
    }
    catch (e) {
        res.status(e.message === 'Customer not found' ? 404 : 500).json({ success: false, message: e.message });
    }
};
exports.findOne = findOne;
const create = async (req, res) => {
    try {
        res.json({ success: true, data: await customerService.create(req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.create = create;
const update = async (req, res) => {
    try {
        res.json({ success: true, data: await customerService.update(+req.params.id, req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.update = update;
const remove = async (req, res) => {
    try {
        res.json({ success: true, data: await customerService.remove(+req.params.id) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.remove = remove;
const receivables = async (req, res) => {
    try {
        res.json({ success: true, data: await customerService.getReceivables(+req.params.id) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.receivables = receivables;
const createReceivable = async (req, res) => {
    try {
        res.json({ success: true, data: {} });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createReceivable = createReceivable;
const overdueDebts = async (req, res) => {
    try {
        res.json({ success: true, data: await customerService.getOverdueDebts() });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.overdueDebts = overdueDebts;
const debtAging = async (req, res) => {
    try {
        res.json({ success: true, data: await customerService.getDebtAging() });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.debtAging = debtAging;
const getDebtEvidence = async (req, res) => {
    try {
        res.json({ success: true, data: await customerService.getDebtEvidence(+req.params.id) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getDebtEvidence = getDebtEvidence;
const addEvidence = async (req, res) => {
    try {
        res.json({ success: true, data: {} });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.addEvidence = addEvidence;
const addPayment = async (req, res) => {
    try {
        res.json({ success: true, data: await customerService.addPayment(+req.params.id, +req.params.receivableId, req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.addPayment = addPayment;
//# sourceMappingURL=customer.controller.js.map