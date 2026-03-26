import { Router } from 'express';
import * as customerCtrl from '../controllers/customer.controller';

const router = Router();

router.get('/customers', customerCtrl.findAll);
router.get('/customers/overdue-debts', customerCtrl.overdueDebts);
router.get('/customers/debt-aging', customerCtrl.debtAging);
router.get('/customers/:id', customerCtrl.findOne);
router.post('/customers', customerCtrl.create);
router.put('/customers/:id', customerCtrl.update);

// Receivables
router.get('/customers/:id/receivables', customerCtrl.receivables);
router.post('/customers/:id/receivables', customerCtrl.createReceivable);

// Evidence and Payments (nested under receivables)
router.post('/customers/receivables/:receivableId/evidence', customerCtrl.addEvidence);
router.post('/customers/receivables/:receivableId/payments', customerCtrl.addPayment);

export default router;
