import { AppDataSource } from '../config/db.config';
import { ShippingCarrier } from '../system/entities';

export class ShippingCarrierInputError extends Error {}

export function normalizeShippingCarrierInput(input: unknown) {
    if (!input || typeof input !== 'object' || Array.isArray(input)) {
        throw new ShippingCarrierInputError('Dữ liệu đơn vị vận chuyển không hợp lệ');
    }
    const raw = input as Record<string, unknown>;
    const name = String(raw.name || '').trim();
    const code = String(raw.code || '').trim().toUpperCase();
    const phone = String(raw.phone || '').trim() || null;
    const trackingUrlTemplate = String(raw.trackingUrlTemplate || '').trim() || null;
    const defaultFee = Number(raw.defaultFee ?? 0);
    if (!name || name.length > 120) throw new ShippingCarrierInputError('Tên đơn vị vận chuyển không hợp lệ');
    if (!/^[A-Z0-9_-]{2,30}$/.test(code)) throw new ShippingCarrierInputError('Mã chỉ gồm chữ, số, gạch ngang hoặc gạch dưới');
    if (phone && !/^[0-9+().\s-]{6,20}$/.test(phone)) throw new ShippingCarrierInputError('Số điện thoại không hợp lệ');
    if (!Number.isFinite(defaultFee) || defaultFee < 0 || defaultFee > 1_000_000_000) {
        throw new ShippingCarrierInputError('Phí mặc định không hợp lệ');
    }
    if (trackingUrlTemplate) {
        let parsed: URL;
        try { parsed = new URL(trackingUrlTemplate.replace('{trackingCode}', 'TEST')); }
        catch { throw new ShippingCarrierInputError('Mẫu URL tra cứu không hợp lệ'); }
        if (!['https:', 'http:'].includes(parsed.protocol)) {
            throw new ShippingCarrierInputError('URL tra cứu chỉ hỗ trợ HTTP hoặc HTTPS');
        }
    }
    return {
        name,
        code,
        phone,
        trackingUrlTemplate,
        defaultFee,
        isActive: raw.isActive === undefined ? true : Boolean(raw.isActive),
    };
}

export class ShippingCarrierService {
    private repo = AppDataSource.getRepository(ShippingCarrier);

    async list(shopId: number, includeInactive = false) {
        const qb = this.repo.createQueryBuilder('carrier')
            .where('carrier.shop_id = :shopId', { shopId })
            .orderBy('carrier.is_active', 'DESC')
            .addOrderBy('carrier.name', 'ASC');
        if (!includeInactive) qb.andWhere('carrier.is_active = true');
        return qb.getMany();
    }

    async create(shopId: number, dto: unknown) {
        const input = normalizeShippingCarrierInput(dto);
        await this.assertCode(shopId, input.code);
        return this.repo.save(this.repo.create({ ...input, shopId }));
    }

    async update(shopId: number, id: number, dto: unknown) {
        const carrier = await this.repo.findOne({ where: { id, shopId } });
        if (!carrier) throw new Error('Shipping carrier not found');
        const input = normalizeShippingCarrierInput(dto);
        await this.assertCode(shopId, input.code, id);
        Object.assign(carrier, input);
        return this.repo.save(carrier);
    }

    async deactivate(shopId: number, id: number) {
        const carrier = await this.repo.findOne({ where: { id, shopId } });
        if (!carrier) throw new Error('Shipping carrier not found');
        carrier.isActive = false;
        await this.repo.save(carrier);
        return { id, isActive: false };
    }

    private async assertCode(shopId: number, code: string, excludeId?: number) {
        const qb = this.repo.createQueryBuilder('carrier')
            .where('carrier.shop_id = :shopId AND carrier.code = :code', { shopId, code });
        if (excludeId) qb.andWhere('carrier.id != :excludeId', { excludeId });
        if (await qb.getOne()) throw new ShippingCarrierInputError('Mã đơn vị vận chuyển đã tồn tại');
    }
}
