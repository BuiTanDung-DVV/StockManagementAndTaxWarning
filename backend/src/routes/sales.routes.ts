import { Router } from 'express';
import * as salesCtrl from '../controllers/sales.controller';

const router = Router();

router.get('/sales-orders', salesCtrl.findAll);
router.get('/sales-orders/summary', salesCtrl.summary);
router.get('/sales-orders/:id', salesCtrl.findOne);
router.post('/sales-orders', salesCtrl.create);
router.post('/sales-orders/:id/cancel', salesCtrl.cancel);
router.post('/sales-orders/:id/payments', salesCtrl.addPayment);
router.post('/sales-orders/:id/returns', salesCtrl.createReturn);

export default router;
