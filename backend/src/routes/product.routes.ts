import { Router } from 'express';
import * as productCtrl from '../controllers/product.controller';

const router = Router();

// Products
router.get('/products', productCtrl.findAllProducts);
router.post('/products', productCtrl.createProduct);
router.get('/products/:id', productCtrl.findProductById);
router.put('/products/:id', productCtrl.updateProduct);
router.delete('/products/:id', productCtrl.deleteProduct);

// Product calculations
router.post('/products/:id/calculate-price', productCtrl.calculatePrice);

// Product Cost Items
router.post('/products/:id/cost-items', productCtrl.addCostItem);
router.delete('/products/cost-items/:itemId', productCtrl.removeCostItem);

// Product Price History
router.get('/products/:id/price-history', productCtrl.getPriceHistory);

// Product Batches
router.get('/products/:id/batches', productCtrl.getBatches);
router.post('/products/:id/batches', productCtrl.createBatch);

// Product Conversions
router.get('/products/:id/conversions', productCtrl.getConversions);
router.post('/products/:id/conversions', productCtrl.createConversion);

// Categories
router.get('/categories', productCtrl.findAllCategories);
router.post('/categories', productCtrl.createCategory);

// Cost Types
router.get('/cost-types', productCtrl.findAllCostTypes);
router.post('/cost-types', productCtrl.createCostType);

export default router;
