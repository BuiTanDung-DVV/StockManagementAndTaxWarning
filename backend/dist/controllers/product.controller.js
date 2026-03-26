"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createCostType = exports.findAllCostTypes = exports.createCategory = exports.findAllCategories = exports.createConversion = exports.getConversions = exports.createBatch = exports.getBatches = exports.getPriceHistory = exports.removeCostItem = exports.addCostItem = exports.calculatePrice = exports.deleteProduct = exports.updateProduct = exports.createProduct = exports.findProductById = exports.findAllProducts = void 0;
const product_service_1 = require("../services/product.service");
const productService = new product_service_1.ProductService();
const findAllProducts = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.findAllProducts(+(req.query.page || 1), +(req.query.limit || 20), req.query.search) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.findAllProducts = findAllProducts;
const findProductById = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.findProductById(+req.params.id) });
    }
    catch (e) {
        res.status(e.message === 'Product not found' ? 404 : 500).json({ success: false, message: e.message });
    }
};
exports.findProductById = findProductById;
const createProduct = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.createProduct(req.body) });
    }
    catch (e) {
        res.status(e.message === 'SKU already exists' ? 409 : 500).json({ success: false, message: e.message });
    }
};
exports.createProduct = createProduct;
const updateProduct = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.updateProduct(+req.params.id, req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.updateProduct = updateProduct;
const deleteProduct = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.deleteProduct(+req.params.id) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.deleteProduct = deleteProduct;
const calculatePrice = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.calculateSuggestedPrice(+req.params.id) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.calculatePrice = calculatePrice;
const addCostItem = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.addCostItem(+req.params.id, req.body.costTypeId, req.body.amount, req.body.calculationType, req.body.notes) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.addCostItem = addCostItem;
const removeCostItem = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.removeCostItem(+req.params.itemId) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.removeCostItem = removeCostItem;
const getPriceHistory = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.getPriceHistory(+req.params.id) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getPriceHistory = getPriceHistory;
const getBatches = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.findBatches(+req.params.id) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getBatches = getBatches;
const createBatch = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.createBatch(+req.params.id, req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createBatch = createBatch;
const getConversions = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.findConversions(+req.params.id) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.getConversions = getConversions;
const createConversion = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.createConversion(+req.params.id, req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createConversion = createConversion;
const findAllCategories = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.findAllCategories() });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.findAllCategories = findAllCategories;
const createCategory = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.createCategory(req.body) });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.createCategory = createCategory;
const findAllCostTypes = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.findAllCostTypes() });
    }
    catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
};
exports.findAllCostTypes = findAllCostTypes;
const createCostType = async (req, res) => {
    try {
        res.json({ success: true, data: await productService.createCostType(req.body) });
    }
    catch (e) {
        res.status(e.message === 'Cost type name exists' ? 409 : 500).json({ success: false, message: e.message });
    }
};
exports.createCostType = createCostType;
//# sourceMappingURL=product.controller.js.map