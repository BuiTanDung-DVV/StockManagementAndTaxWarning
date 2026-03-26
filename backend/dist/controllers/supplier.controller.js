"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.payables = exports.remove = exports.update = exports.create = exports.findOne = exports.findAll = void 0;
const supplier_service_1 = require("../services/supplier.service");
const supplierService = new supplier_service_1.SupplierService();
const findAll = async (req, res) => {
    try {
        res.json({ success: true, data: await supplierService.findAll(+(req.query.page || 1), +(req.query.limit || 20), req.query.search) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.findAll = findAll;
const findOne = async (req, res) => {
    try {
        res.json({ success: true, data: await supplierService.findById(+req.params.id) });
    }
    catch (e) {
        res.status(e.message === 'Supplier not found' ? 404 : 500).json({ success: false, message: e.message });
    }
};
exports.findOne = findOne;
const create = async (req, res) => {
    try {
        res.json({ success: true, data: await supplierService.create(req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.create = create;
const update = async (req, res) => {
    try {
        res.json({ success: true, data: await supplierService.update(+req.params.id, req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.update = update;
const remove = async (req, res) => {
    try {
        res.json({ success: true, data: await supplierService.remove(+req.params.id) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.remove = remove;
const payables = async (req, res) => {
    try {
        res.json({ success: true, data: await supplierService.getPayables(+req.params.id) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.payables = payables;
//# sourceMappingURL=supplier.controller.js.map