import { AsyncLocalStorage } from 'async_hooks';
import { Request, Response, NextFunction } from 'express';

export interface RequestContext {
  userId?: number;
  shopId?: number;
  ipAddress?: string;
  userAgent?: string;
}

export const requestContext = new AsyncLocalStorage<RequestContext>();

export const contextMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const context: RequestContext = {
    ipAddress: req.ip,
    userAgent: req.headers['user-agent'],
  };

  requestContext.run(context, () => {
    next();
  });
};
