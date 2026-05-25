import { Request, Response, NextFunction } from 'express';
import * as jwt from 'jsonwebtoken';
import { config } from '../config/env.config';

import { AppDataSource } from '../config/db.config';
import { ShopMember } from '../shop/entities';
import { requestContext } from './context.middleware';

export interface AuthRequest extends Request {
  user?: any;
  shopId?: number;
}

export const authenticateJwt = async (req: AuthRequest, res: Response, next: NextFunction) => {
  let token: string | undefined;
  const authHeader = req.headers.authorization;
  
  if (authHeader) {
    token = authHeader.split(' ')[1];
  } else if (req.query.token) {
    token = req.query.token as string;
  }

  if (!token) {
    return res.status(401).json({ success: false, message: 'Unauthorized' });
  }

  try {
    const decoded = jwt.verify(token, config.jwtSecret) as any;
    req.user = decoded;

    // Parse shop ID from header or query param (validation deferred to requireShopId)
    const shopIdValue = req.headers['x-shop-id'] || req.query.shopId;
    if (shopIdValue) {
      const shopId = parseInt(shopIdValue as string, 10);
      if (!isNaN(shopId)) {
        if (!AppDataSource.isInitialized) {
            await AppDataSource.initialize();
        }
        const memberRepo = AppDataSource.getRepository(ShopMember);
        const isMember = await memberRepo.findOne({ 
            where: { shopId, userId: decoded.sub, isActive: true } 
        });
        
        if (!isMember) {
          return res.status(403).json({ success: false, message: 'Forbidden: You do not have access to this shop' });
        }
        req.shopId = shopId;
      }
    }

    // Update AsyncLocalStorage context
    const ctx = requestContext.getStore();
    if (ctx) {
      ctx.userId = decoded.sub;
      if (req.shopId) {
        ctx.shopId = req.shopId;
      }
    }

    next();
  } catch (error) {
    res.status(401).json({ success: false, message: 'Unauthorized' });
  }
};

/**
 * Middleware that enforces shopId presence on all business routes.
 * Must be placed AFTER authenticateJwt in the middleware chain.
 * Rejects any request that does not carry a valid, verified shopId.
 */
export const requireShopId = (req: AuthRequest, res: Response, next: NextFunction) => {
  if (!req.shopId || isNaN(req.shopId)) {
    return res.status(400).json({
      success: false,
      message: 'Thiếu thông tin cửa hàng (x-shop-id header is required)',
    });
  }
  next();
};
