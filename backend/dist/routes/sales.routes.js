"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const salesCtrl = require("../controllers/sales.controller");
const router = (0, express_1.Router)();
router.get('/sales-orders', salesCtrl.findAll);
router.get('/sales-orders/summary', salesCtrl.summary);
router.get('/sales-orders/:id', salesCtrl.findOne);
router.post('/sales-orders', salesCtrl.create);
router.post('/sales-orders/:id/cancel', salesCtrl.cancel);
router.post('/sales-orders/:id/payments', salesCtrl.addPayment);
router.post('/sales-orders/:id/returns', salesCtrl.createReturn);
exports.default = router;
//# sourceMappingURL=sales.routes.js.map