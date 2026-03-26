import { Request, Response } from 'express';
import { ShopRoleService } from '../services/shop-role.service';

const svc = new ShopRoleService();

// shopId comes from query or defaults to 1
const shopId = (req: Request) => +(req.query.shopId || 1);

export const listRoles = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await svc.findAll(shopId(req)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const getRole = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await svc.findOne(+req.params.id) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const createRole = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await svc.create(shopId(req), req.body) }); }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const updateRole = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await svc.update(+req.params.id, req.body) }); }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const deleteRole = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await svc.remove(+req.params.id) }); }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};
