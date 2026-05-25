import { Router } from 'express';
import * as taxConfigController from '../controllers/tax-config.controller';

const router = Router();

router.get('/tax/config', taxConfigController.getTaxConfig);
router.put('/tax/config', taxConfigController.updateTaxConfig);

export default router;
