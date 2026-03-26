import { Request, Response } from 'express';
export declare const findAll: (req: Request, res: Response) => Promise<void>;
export declare const summary: (req: Request, res: Response) => Promise<void>;
export declare const findOne: (req: Request, res: Response) => Promise<void>;
export declare const create: (req: Request, res: Response) => Promise<void>;
export declare const cancel: (req: Request, res: Response) => Promise<void>;
export declare const addPayment: (req: Request, res: Response) => Promise<void>;
export declare const createReturn: (req: Request, res: Response) => Promise<void>;
