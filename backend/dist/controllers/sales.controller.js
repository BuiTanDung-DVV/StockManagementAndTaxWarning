"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createReturn = exports.addPayment = exports.cancel = exports.create = exports.findOne = exports.summary = exports.findAll = void 0;
const sales_service_1 = require("../services/sales.service");
const salesService = new sales_service_1.SalesService();
const findAll = async (req, res) => {
    try {
        res.json({ success: true, data: await salesService.findAll(+(req.query.page || 1), +(req.query.limit || 20)) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.findAll = findAll;
const summary = async (req, res) => {
    try {
        res.json({ success: true, data: await salesService.summary(req.query.from, req.query.to) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.summary = summary;
const findOne = async (req, res) => {
    try {
        res.json({ success: true, data: await salesService.findById(+req.params.id) });
    }
    catch (e) {
        if (e.message === 'Order not found')
            res.status(404).json({ success: false, message: e.message });
        else
            res.status(500).json({ success: false, message: e.message });
    }
};
exports.findOne = findOne;
const create = async (req, res) => {
    try {
        res.json({ success: true, data: await salesService.create(req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.create = create;
const cancel = async (req, res) => {
    try {
        res.json({ success: true, data: await salesService.cancel(+req.params.id) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.cancel = cancel;
const addPayment = async (req, res) => {
    try {
        res.json({ success: true, data: await salesService.addPayment(+req.params.id, req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.addPayment = addPayment;
const createReturn = async (req, res) => {
    try {
        res.json({ success: true, data: await salesService.createReturn(+req.params.id, req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createReturn = createReturn;
//# sourceMappingURL=sales.controller.js.map