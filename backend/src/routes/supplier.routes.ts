import { Router } from 'express';
import * as supplierCtrl from '../controllers/supplier.controller';

const router = Router();

router.get('/suppliers', supplierCtrl.findAll);
router.get('/suppliers/:id', supplierCtrl.findOne);
router.post('/suppliers', supplierCtrl.create);
router.put('/suppliers/:id', supplierCtrl.update);
router.get('/suppliers/:id/payables', supplierCtrl.payables);

export default router;
