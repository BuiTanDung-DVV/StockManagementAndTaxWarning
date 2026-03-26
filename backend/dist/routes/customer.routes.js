"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const customerCtrl = require("../controllers/customer.controller");
const router = (0, express_1.Router)();
router.get('/customers', customerCtrl.findAll);
router.get('/customers/overdue-debts', customerCtrl.overdueDebts);
router.get('/customers/debt-aging', customerCtrl.debtAging);
router.get('/customers/:id', customerCtrl.findOne);
router.post('/customers', customerCtrl.create);
router.put('/customers/:id', customerCtrl.update);
router.get('/customers/:id/receivables', customerCtrl.receivables);
router.post('/customers/:id/receivables', customerCtrl.createReceivable);
router.post('/customers/receivables/:receivableId/evidence', customerCtrl.addEvidence);
router.post('/customers/receivables/:receivableId/payments', customerCtrl.addPayment);
exports.default = router;
//# sourceMappingURL=customer.routes.js.map