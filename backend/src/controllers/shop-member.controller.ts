import { Request, Response } from 'express';
import { ShopMemberService } from '../services/shop-member.service';
import { AuthRequest } from '../middleware/auth.middleware';

const svc = new ShopMemberService();

const shopId = (req: Request) => +(req.query.shopId || 1);

export const listMembers = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await svc.findAll(shopId(req)) }); }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};

export const inviteMember = async (req: Request, res: Response) => {
    try {
        const { username, roleId } = req.body;
        res.json({ success: true, data: await svc.invite(shopId(req), username, roleId) });
    }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const updateMemberRole = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await svc.updateRole(+req.params.id, req.body.roleId) }); }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

export const removeMember = async (req: Request, res: Response) => {
    try { res.json({ success: true, data: await svc.remove(+req.params.id) }); }
    catch (e: any) { res.status(400).json({ success: false, message: e.message }); }
};

/** For shop switching — returns all shops the logged-in user belongs to */
export const getMyShops = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user?.sub;
        res.json({ success: true, data: await svc.getUserShops(userId) });
    }
    catch (e: any) { res.status(500).json({ success: false, message: e.message }); }
};
