import { Router } from 'express';
import * as productCtrl from '../controllers/product.controller';
import { requirePermission } from '../middleware/permission.middleware';

const router = Router();

// Products
router.get('/products', requirePermission('products', 'view'), productCtrl.findAllProducts);
router.post('/products', requirePermission('products', 'edit'), productCtrl.createProduct);
router.get('/products/:id', requirePermission('products', 'view'), productCtrl.findProductById);
router.put('/products/:id', requirePermission('products', 'edit'), productCtrl.updateProduct);
router.delete('/products/:id', requirePermission('products', 'edit'), productCtrl.deleteProduct);

// Product calculations
router.post('/products/:id/calculate-price', requirePermission('products', 'edit'), productCtrl.calculatePrice);

// Product Cost Items
router.post('/products/:id/cost-items', requirePermission('products', 'edit'), productCtrl.addCostItem);
router.delete('/products/cost-items/:itemId', requirePermission('products', 'edit'), productCtrl.removeCostItem);

// Product Price History
router.get('/products/:id/price-history', requirePermission('products', 'view'), productCtrl.getPriceHistory);

// Product Batches
router.get('/products/:id/batches', requirePermission('products', 'view'), productCtrl.getBatches);
router.post('/products/:id/batches', requirePermission('products', 'edit'), productCtrl.createBatch);

// Product Conversions
router.get('/products/:id/conversions', requirePermission('products', 'view'), productCtrl.getConversions);
router.post('/products/:id/conversions', requirePermission('products', 'edit'), productCtrl.createConversion);

// Categories
router.get('/categories', requirePermission('products', 'view'), productCtrl.findAllCategories);
router.post('/categories', requirePermission('products', 'edit'), productCtrl.createCategory);

// Cost Types
router.get('/cost-types', requirePermission('products', 'view'), productCtrl.findAllCostTypes);
router.post('/cost-types', requirePermission('products', 'edit'), productCtrl.createCostType);

export default router;
