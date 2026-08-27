import express = require('express');
import { requirePermission } from '../middleware/permission.middleware';
import * as dashboardController from '../controllers/dashboard.controller';

const router = express.Router();

router.get(
    '/dashboard/action-items',
    requirePermission(
        ['dashboard', 'inventory', 'customers', 'finance'],
        'view',
        { allowAllShops: true },
    ),
    dashboardController.getActionItems,
);

export default router;

