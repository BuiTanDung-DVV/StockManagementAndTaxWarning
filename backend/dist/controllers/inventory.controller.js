"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createStockTake = exports.createPurchaseOrder = exports.getPurchaseOrders = exports.getExpiringProducts = exports.getXntReport = exports.createWarehouse = exports.getWarehouses = exports.getMovements = exports.getLowStock = exports.getStock = void 0;
const inventory_service_1 = require("../services/inventory.service");
const inventoryService = new inventory_service_1.InventoryService();
const getStock = async (req, res) => {
    try {
        res.json({ success: true, data: await inventoryService.getStock(+(req.query.page || 1), +(req.query.limit || 20)) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getStock = getStock;
const getLowStock = async (req, res) => {
    try {
        const threshold = req.query.threshold ? +(req.query.threshold) : undefined;
        res.json({ success: true, data: await inventoryService.getLowStock(threshold) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getLowStock = getLowStock;
const getMovements = async (req, res) => {
    try {
        res.json({ success: true, data: await inventoryService.getMovements(+(req.query.page || 1), +(req.query.limit || 20)) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getMovements = getMovements;
const getWarehouses = async (req, res) => {
    try {
        res.json({ success: true, data: await inventoryService.getWarehouses() });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getWarehouses = getWarehouses;
const createWarehouse = async (req, res) => {
    try {
        res.json({ success: true, data: await inventoryService.createWarehouse(req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createWarehouse = createWarehouse;
const getXntReport = async (req, res) => {
    try {
        const { from, to, warehouseId } = req.query;
        res.json({
            success: true,
            data: await inventoryService.getXntReport(from, to, warehouseId ? +(warehouseId) : undefined)
        });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getXntReport = getXntReport;
const getExpiringProducts = async (req, res) => {
    try {
        const daysAhead = req.query.daysAhead ? +(req.query.daysAhead) : 30;
        res.json({ success: true, data: await inventoryService.getExpiringProducts(daysAhead) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getExpiringProducts = getExpiringProducts;
const getPurchaseOrders = async (req, res) => {
    try {
        res.json({ success: true, data: await inventoryService.getPurchaseOrders(+(req.query.page || 1), +(req.query.limit || 20)) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getPurchaseOrders = getPurchaseOrders;
const createPurchaseOrder = async (req, res) => {
    try {
        res.json({ success: true, data: await inventoryService.createPurchaseOrder(req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createPurchaseOrder = createPurchaseOrder;
const createStockTake = async (req, res) => {
    try {
        res.json({ success: true, data: await inventoryService.createStockTake(req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createStockTake = createStockTake;
//# sourceMappingURL=inventory.controller.js.map