import { Router } from 'express';
import * as taxConfigController from '../controllers/tax-config.controller';

const router = Router();

router.get('/tax/config', taxConfigController.getTaxConfig);

export default router;
