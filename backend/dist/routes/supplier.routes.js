"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const supplierCtrl = require("../controllers/supplier.controller");
const router = (0, express_1.Router)();
router.get('/suppliers', supplierCtrl.findAll);
router.get('/suppliers/:id', supplierCtrl.findOne);
router.post('/suppliers', supplierCtrl.create);
router.put('/suppliers/:id', supplierCtrl.update);
router.get('/suppliers/:id/payables', supplierCtrl.payables);
exports.default = router;
//# sourceMappingURL=supplier.routes.js.map