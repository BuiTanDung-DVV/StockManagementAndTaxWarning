import { AppDataSource } from '../config/db.config';
import { ShopRole } from '../shop/entities';

export class ShopRoleService {
    private repo = AppDataSource.getRepository(ShopRole);

    /** List all roles for a shop */
    async findAll(shopId: number) {
        return this.repo.find({ where: { shopId }, order: { createdAt: 'ASC' } });
    }

    /** Get one role by id */
    async findOne(shopId: number, id: number) {
        return this.repo.findOne({ where: { id, shopId } });
    }

    /** Create a new custom role */
    async create(shopId: number, dto: { name: string; permissions: Record<string, string> }) {
        const role = this.repo.create({
            shopId,
            name: dto.name,
            permissions: JSON.stringify(dto.permissions),
        });
        return this.repo.save(role);
    }

    /** Update role name and/or permissions */
    async update(shopId: number, id: number, dto: { name?: string; permissions?: Record<string, string> }) {
        const role = await this.repo.findOneByOrFail({ id, shopId });
        if (dto.name) role.name = dto.name;
        if (dto.permissions) role.permissions = JSON.stringify(dto.permissions);
        return this.repo.save(role);
    }

    /** Delete a role */
    async remove(shopId: number, id: number) {
        await this.repo.delete({ id, shopId });
        return { deleted: true };
    }
}
