import { Router } from 'express';
import * as customerCtrl from '../controllers/customer.controller';
import { requirePermission } from '../middleware/permission.middleware';

const router = Router();

router.get('/customers', requirePermission('customers', 'view'), customerCtrl.findAll);
router.get('/customers/overdue-debts', requirePermission('customers', 'view'), customerCtrl.overdueDebts);
router.get('/customers/debt-aging', requirePermission('customers', 'view'), customerCtrl.debtAging);
router.get('/customer-receivables', requirePermission('customers', 'view'), customerCtrl.openReceivables);
router.post('/customers/evidence-upload/presign', requirePermission('customers', 'edit'), customerCtrl.createDebtEvidenceImageUpload);
router.post('/customers/evidence-upload/confirm', requirePermission('customers', 'edit'), customerCtrl.confirmDebtEvidenceImageUpload);
router.post('/customers/evidence-upload/delete', requirePermission('customers', 'edit'), customerCtrl.deleteDebtEvidenceImageUpload);
router.get('/customers/:id/evidence', requirePermission('customers', 'view'), customerCtrl.getDebtEvidence);
router.get('/customers/:id', requirePermission('customers', 'view'), customerCtrl.findOne);
router.post('/customers', requirePermission('customers', 'edit'), customerCtrl.create);
router.put('/customers/:id', requirePermission('customers', 'edit'), customerCtrl.update);
router.delete('/customers/:id', requirePermission('customers', 'full'), customerCtrl.remove);

// Receivables
router.get('/customers/:id/receivables', requirePermission('customers', 'view'), customerCtrl.receivables);
router.post('/customers/:id/receivables', requirePermission('customers', 'edit'), customerCtrl.createReceivable);

// Evidence and Payments (nested under receivables)
router.post('/customers/receivables/:receivableId/evidence', requirePermission('customers', 'edit'), customerCtrl.addEvidence);
router.delete('/customers/evidence/:evidenceId', requirePermission('customers', 'edit'), customerCtrl.removeEvidence);

export default router;
