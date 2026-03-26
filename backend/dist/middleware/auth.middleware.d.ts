import { Request, Response, NextFunction } from 'express';
export interface AuthRequest extends Request {
    user?: any;
}
export declare const authenticateJwt: (req: AuthRequest, res: Response, next: NextFunction) => Response<any, Record<string, any>> | undefined;
