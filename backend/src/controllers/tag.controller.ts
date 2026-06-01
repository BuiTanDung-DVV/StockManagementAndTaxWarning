import { Request, Response } from 'express';
import { AppDataSource } from '../config/db.config';
import { Tag } from '../product/entities';

export class TagController {
    static async getAll(req: Request, res: Response) {
        try {
            const shopId = (req as any).shopId!;
            const tags = await AppDataSource.getRepository(Tag).find({ where: { shopId } });
            res.json({ success: true, data: tags });
        } catch (error) {
            console.error('Error fetching tags:', error);
            res.status(500).json({ success: false, message: 'Server Error' });
        }
    }

    static async create(req: Request, res: Response) {
        try {
            const shopId = (req as any).shopId!;
            const { name, color } = req.body;
            
            if (!name) {
                return res.status(400).json({ success: false, message: 'Tên nhãn không được để trống' });
            }

            const repo = AppDataSource.getRepository(Tag);
            const existing = await repo.findOne({ where: { shopId, name: name.trim() } });
            if (existing) {
                return res.status(400).json({ success: false, message: 'Nhãn này đã tồn tại' });
            }

            const tag = repo.create({ shopId, name: name.trim(), color: color || '#3B82F6' });
            await repo.save(tag);
            res.json({ success: true, data: tag });
        } catch (error) {
            console.error('Error creating tag:', error);
            res.status(500).json({ success: false, message: 'Server Error' });
        }
    }

    static async update(req: Request, res: Response) {
        try {
            const shopId = (req as any).shopId!;
            const id = parseInt(req.params.id);
            const { name, color } = req.body;

            const repo = AppDataSource.getRepository(Tag);
            const tag = await repo.findOne({ where: { id, shopId } });
            if (!tag) {
                return res.status(404).json({ success: false, message: 'Không tìm thấy nhãn' });
            }

            if (name) {
                const existing = await repo.findOne({ where: { shopId, name: name.trim() } });
                if (existing && existing.id !== tag.id) {
                    return res.status(400).json({ success: false, message: 'Tên nhãn đã tồn tại' });
                }
                tag.name = name.trim();
            }
            if (color) {
                tag.color = color;
            }

            await repo.save(tag);
            res.json({ success: true, data: tag });
        } catch (error) {
            console.error('Error updating tag:', error);
            res.status(500).json({ success: false, message: 'Server Error' });
        }
    }

    static async delete(req: Request, res: Response) {
        try {
            const shopId = (req as any).shopId!;
            const id = parseInt(req.params.id);
            
            const repo = AppDataSource.getRepository(Tag);
            const result = await repo.delete({ id, shopId });
            
            if (result.affected === 0) {
                return res.status(404).json({ success: false, message: 'Không tìm thấy nhãn' });
            }
            
            res.json({ success: true, message: 'Đã xóa nhãn' });
        } catch (error) {
            console.error('Error deleting tag:', error);
            res.status(500).json({ success: false, message: 'Server Error' });
        }
    }
}
