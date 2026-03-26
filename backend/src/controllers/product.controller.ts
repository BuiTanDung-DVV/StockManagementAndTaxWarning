import { Request, Response } from 'express';
import { ProductService } from '../services/product.service';

const productService = new ProductService();

export const findAllProducts = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.findAllProducts(+(req.query.page || 1), +(req.query.limit || 20), req.query.search as string) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const findProductById = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.findProductById(+req.params.id) }); }
    catch (e: any) { res.status(e.message === 'Product not found' ? 404 : 500).json({ success: false, message: e.message }); }
};
export const createProduct = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.createProduct(req.body) }); }
    catch (e: any) { res.status(e.message === 'SKU already exists' ? 409 : 500).json({ success: false, message: e.message }); }
};
export const updateProduct = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.updateProduct(+req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const deleteProduct = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.deleteProduct(+req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const calculatePrice = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.calculateSuggestedPrice(+req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const addCostItem = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.addCostItem(+req.params.id, req.body.costTypeId, req.body.amount, req.body.calculationType, req.body.notes) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const removeCostItem = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.removeCostItem(+req.params.itemId) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getPriceHistory = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.getPriceHistory(+req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getBatches = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.findBatches(+req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createBatch = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.createBatch(+req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const getConversions = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.findConversions(+req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createConversion = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.createConversion(+req.params.id, req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const findAllCategories = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.findAllCategories() }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createCategory = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.createCategory(req.body) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const findAllCostTypes = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.findAllCostTypes() }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
export const createCostType = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await productService.createCostType(req.body) }); }
    catch (e: any) { res.status(e.message === 'Cost type name exists' ? 409 : 500).json({ success: false, message: e.message }); }
};
