import { Request, Response } from 'express';
export declare const findAll: (req: Request, res: Response) => Promise<void>;
export declare const findOne: (req: Request, res: Response) => Promise<void>;
export declare const create: (req: Request, res: Response) => Promise<void>;
export declare const update: (req: Request, res: Response) => Promise<void>;
export declare const remove: (req: Request, res: Response) => Promise<void>;
export declare const payables: (req: Request, res: Response) => Promise<void>;
