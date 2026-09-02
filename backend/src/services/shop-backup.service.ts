import { createHash } from 'crypto';
import { gunzipSync, gzipSync } from 'zlib';
import * as bcrypt from 'bcrypt';
import { EntityManager } from 'typeorm';
import { AppDataSource } from '../config/db.config';
import { User } from '../auth/entities';
import { ActivityLog, ShopBackupSnapshot } from '../system/entities';

const FORMAT_VERSION = 1;
export const MAX_BACKUP_BYTES = 25 * 1024 * 1024;
const MAX_UNCOMPRESSED_BYTES = 80 * 1024 * 1024;
const SENSITIVE_CONFIG_KEY_PATTERN =
    /(?:secret|token|password|api[_-]?key|private[_-]?key|database[_-]?url|connection[_-]?string)/i;

export const isSensitiveBackupConfigKey = (value: unknown) =>
    SENSITIVE_CONFIG_KEY_PATTERN.test(String(value || '').trim());

const parentFirstTables = [
    'categories', 'tags', 'cost_types', 'customers', 'suppliers', 'warehouses',
    'shipping_carriers', 'cash_accounts', 'products',
    'product_cost_items', 'product_batches', 'unit_conversions', 'product_price_history',
    'inventory_lots', 'inventory_stocks', 'inventory_movements',
    'purchase_orders', 'purchase_order_items', 'stock_takes', 'stock_take_items',
    'sales_orders', 'sales_order_items', 'sales_order_payments', 'sales_order_lot_deductions',
    'sales_returns', 'sales_return_items', 'receivables', 'debt_evidences',
    'debt_payment_history', 'payables', 'cash_transactions', 'budget_plans',
    'cashflow_forecasts', 'daily_closings', 'tax_obligations', 'journal_entries',
    'journal_lines', 'financial_ledger', 'invoices', 'invoice_items',
    'purchases_without_invoice', 'purchase_without_invoice_items', 'invoice_scans',
    'ai_knowledge_documents', 'system_configs',
] as const;

const childScope: Record<string, { parent: string; childKey: string; parentKey?: string }> = {
    purchase_order_items: { parent: 'purchase_orders', childKey: 'order_id' },
    stock_take_items: { parent: 'stock_takes', childKey: 'stock_take_id' },
    sales_order_lot_deductions: { parent: 'sales_orders', childKey: 'order_id' },
    journal_lines: { parent: 'journal_entries', childKey: 'journal_entry_id' },
    invoice_items: { parent: 'invoices', childKey: 'invoice_id' },
    purchase_without_invoice_items: { parent: 'purchases_without_invoice', childKey: 'purchase_id' },
};

export type BackupEnvelope = {
    manifest: { format: 'smartstock-shop-backup'; version: number; shopId: number; exportedAt: string; checksum: string };
    profile: Record<string, unknown> | null;
    tables: Record<string, unknown[]>;
};

export class ShopBackupError extends Error {
    constructor(message: string, public statusCode = 400) { super(message); }
}

export const shopBackupChecksum = (value: unknown) =>
    createHash('sha256').update(JSON.stringify(value)).digest('hex');

export const encodeShopBackup = (envelope: BackupEnvelope) =>
    gzipSync(Buffer.from(JSON.stringify(envelope), 'utf8'), { level: 9 });

export const validateShopBackupRelationships = (envelope: BackupEnvelope, expectedShopId: number) => {
    const allowedTables = new Set<string>(parentFirstTables);
    const tableNames = Object.keys(envelope.tables);
    const unknownTables = tableNames.filter(table => !allowedTables.has(table));
    if (unknownTables.length) throw new ShopBackupError('Tệp sao lưu chứa bảng không được hỗ trợ');

    for (const table of parentFirstTables) {
        const rows = envelope.tables[table];
        if (rows !== undefined && !Array.isArray(rows)) throw new ShopBackupError(`Dữ liệu bảng ${table} không hợp lệ`);
        const ids = new Set<unknown>();
        for (const value of rows || []) {
            if (!value || typeof value !== 'object' || Array.isArray(value)) throw new ShopBackupError(`Dữ liệu bảng ${table} không hợp lệ`);
            const row = value as Record<string, unknown>;
            if (row.id === undefined || row.id === null || ids.has(row.id)) throw new ShopBackupError(`Khóa dữ liệu bảng ${table} không hợp lệ`);
            ids.add(row.id);
            if (table === 'system_configs' && isSensitiveBackupConfigKey(row.config_key)) {
                throw new ShopBackupError('Tệp sao lưu chứa cấu hình nhạy cảm không được hỗ trợ');
            }
            if (!childScope[table] && Number(row.shop_id) !== expectedShopId) {
                throw new ShopBackupError(`Dữ liệu bảng ${table} không thuộc cửa hàng đang chọn`, 403);
            }
        }
    }

    for (const [table, relation] of Object.entries(childScope)) {
        const parentIds = new Set((envelope.tables[relation.parent] || []).map(value => (value as Record<string, unknown>).id));
        for (const value of envelope.tables[table] || []) {
            const row = value as Record<string, unknown>;
            if (!parentIds.has(row[relation.childKey])) throw new ShopBackupError(`Dữ liệu bảng ${table} bị thiếu liên kết`);
            if (row.shop_id !== undefined && Number(row.shop_id) !== expectedShopId) {
                throw new ShopBackupError(`Dữ liệu bảng ${table} không thuộc cửa hàng đang chọn`, 403);
            }
        }
    }

    if (envelope.profile) {
        const profileShopId = Number(envelope.profile.shop_id ?? envelope.profile.id);
        if (profileShopId !== expectedShopId) throw new ShopBackupError('Hồ sơ cửa hàng trong tệp không khớp', 403);
    }
};

export const decodeShopBackup = (bytes: Buffer, expectedShopId: number): BackupEnvelope => {
    if (!Buffer.isBuffer(bytes) || bytes.length === 0 || bytes.length > MAX_BACKUP_BYTES) throw new ShopBackupError('Tệp sao lưu phải nhỏ hơn 25 MB');
    let parsed: BackupEnvelope;
    try { parsed = JSON.parse(gunzipSync(bytes, { maxOutputLength: MAX_UNCOMPRESSED_BYTES }).toString('utf8')); }
    catch { throw new ShopBackupError('Tệp sao lưu bị hỏng hoặc không đúng định dạng'); }
    if (parsed?.manifest?.format !== 'smartstock-shop-backup' || parsed.manifest.version !== FORMAT_VERSION) throw new ShopBackupError('Phiên bản tệp sao lưu không được hỗ trợ');
    if (Number(parsed.manifest.shopId) !== expectedShopId) throw new ShopBackupError('Tệp sao lưu không thuộc cửa hàng đang chọn', 403);
    if (!parsed.tables || typeof parsed.tables !== 'object') throw new ShopBackupError('Tệp sao lưu thiếu dữ liệu');
    const actual = shopBackupChecksum({ profile: parsed.profile || null, tables: parsed.tables });
    if (actual !== parsed.manifest.checksum) throw new ShopBackupError('Checksum không khớp; tệp có thể đã bị thay đổi');
    validateShopBackupRelationships(parsed, expectedShopId);
    return parsed;
};

export class ShopBackupService {
    private snapshotRepo = AppDataSource.getRepository(ShopBackupSnapshot);

    async export(shopId: number, userId: number, password: unknown) {
        await this.verifyPassword(userId, password);
        const envelope = await this.buildEnvelope(shopId);
        const bytes = encodeShopBackup(envelope);
        if (bytes.length > MAX_BACKUP_BYTES) throw new ShopBackupError('Bản sao vượt quá giới hạn 25 MB', 413);
        return { bytes, fileName: `smartstock-shop-${shopId}-${new Date().toISOString().slice(0, 10)}.smartstock-backup.gz`, manifest: envelope.manifest };
    }

    async validate(shopId: number, userId: number, password: unknown, bytes: Buffer) {
        await this.verifyPassword(userId, password);
        const envelope = decodeShopBackup(bytes, shopId);
        const currentCounts = await this.countCurrent(shopId);
        const incomingCounts = Object.fromEntries(parentFirstTables.map(table => [table, envelope.tables[table]?.length || 0]));
        const snapshot = await this.snapshotRepo.save(this.snapshotRepo.create({
            shopId,
            createdBy: userId,
            checksum: envelope.manifest.checksum,
            payloadGzip: bytes,
            status: 'VALIDATED',
        }));
        return { backupId: snapshot.id, manifest: envelope.manifest, currentCounts, incomingCounts };
    }

    async restore(shopId: number, userId: number, password: unknown, backupId: unknown) {
        await this.verifyPassword(userId, password);
        const id = String(backupId || '');
        const imported = await this.snapshotRepo.findOne({ where: { id, shopId, status: 'VALIDATED' } });
        if (!imported) throw new ShopBackupError('Bản sao đã kiểm tra không còn khả dụng', 404);
        const incoming = decodeShopBackup(imported.payloadGzip, shopId);

        return AppDataSource.transaction(async manager => {
            const before = await this.buildEnvelope(shopId, manager);
            const beforeBytes = encodeShopBackup(before);
            if (beforeBytes.length > MAX_BACKUP_BYTES) {
                throw new ShopBackupError('Dữ liệu hiện tại vượt quá 25 MB nên chưa thể tạo điểm hoàn tác', 413);
            }
            const rollback = await manager.getRepository(ShopBackupSnapshot).save({
                shopId,
                createdBy: userId,
                checksum: before.manifest.checksum,
                payloadGzip: beforeBytes,
                status: 'ROLLBACK_READY',
            });
            await this.replaceShopData(manager, shopId, incoming);
            imported.status = 'RESTORED';
            await manager.getRepository(ShopBackupSnapshot).save(imported);
            await manager.getRepository(ActivityLog).save({
                shopId,
                userId,
                action: 'IMPORT',
                entityType: 'SHOP_BACKUP',
                entityName: 'Khôi phục dữ liệu cửa hàng',
                description: `Khôi phục từ bản sao ${imported.id}; có thể hoàn tác bằng ${rollback.id}`,
            });
            return { restored: true, rollbackId: rollback.id };
        });
    }

    async rollback(shopId: number, userId: number, password: unknown, id: string) {
        await this.verifyPassword(userId, password);
        const snapshot = await this.snapshotRepo.findOne({ where: { id, shopId, status: 'ROLLBACK_READY' } });
        if (!snapshot) throw new ShopBackupError('Không tìm thấy điểm hoàn tác', 404);
        const envelope = decodeShopBackup(snapshot.payloadGzip, shopId);
        return AppDataSource.transaction(async manager => {
            await this.replaceShopData(manager, shopId, envelope);
            snapshot.status = 'ROLLED_BACK';
            await manager.getRepository(ShopBackupSnapshot).save(snapshot);
            await manager.getRepository(ActivityLog).save({
                shopId, userId, action: 'IMPORT', entityType: 'SHOP_BACKUP',
                entityName: 'Hoàn tác khôi phục', description: `Đã hoàn tác bằng snapshot ${id}`,
            });
            return { rolledBack: true };
        });
    }

    private async verifyPassword(userId: number, password: unknown) {
        const raw = String(password || '');
        if (!raw || raw.length > 200) throw new ShopBackupError('Vui lòng nhập lại mật khẩu');
        const user = await AppDataSource.getRepository(User).findOne({ where: { id: userId, isActive: true } });
        if (!user?.passwordHash || !(await bcrypt.compare(raw, user.passwordHash))) {
            throw new ShopBackupError('Mật khẩu xác nhận không đúng', 403);
        }
    }

    private async buildEnvelope(shopId: number, manager: EntityManager = AppDataSource.manager): Promise<BackupEnvelope> {
        const tables: Record<string, unknown[]> = {};
        for (const table of parentFirstTables) {
            if (!(await this.tableExists(manager, table))) { tables[table] = []; continue; }
            const child = childScope[table];
            tables[table] = child
                ? await manager.query(`SELECT child.* FROM ${table} child JOIN ${child.parent} parent ON parent.id = child.${child.childKey} WHERE parent.shop_id = $1 ORDER BY child.id`, [shopId])
                : table === 'system_configs'
                    ? (await manager.query(`SELECT * FROM system_configs WHERE shop_id = $1 ORDER BY id`, [shopId]))
                        .filter((row: Record<string, unknown>) => !isSensitiveBackupConfigKey(row.config_key))
                    : await manager.query(`SELECT * FROM ${table} WHERE shop_id = $1 ORDER BY id`, [shopId]);
        }
        const [profile] = await manager.query('SELECT * FROM shop_profiles WHERE shop_id = $1 OR id = $1 ORDER BY (shop_id = $1) DESC LIMIT 1', [shopId]);
        const base = { format: 'smartstock-shop-backup' as const, version: FORMAT_VERSION, shopId, exportedAt: new Date().toISOString() };
        const checksum = shopBackupChecksum({ profile: profile || null, tables });
        return { manifest: { ...base, checksum }, profile: profile || null, tables };
    }

    private async countCurrent(shopId: number) {
        const result: Record<string, number> = {};
        for (const table of parentFirstTables) {
            if (!(await this.tableExists(AppDataSource.manager, table))) { result[table] = 0; continue; }
            const child = childScope[table];
            const [row] = child
                ? await AppDataSource.query(`SELECT COUNT(*)::int count FROM ${table} child JOIN ${child.parent} parent ON parent.id = child.${child.childKey} WHERE parent.shop_id = $1`, [shopId])
                : await AppDataSource.query(`SELECT COUNT(*)::int count FROM ${table} WHERE shop_id = $1`, [shopId]);
            result[table] = Number(row?.count || 0);
        }
        return result;
    }

    private async replaceShopData(manager: EntityManager, shopId: number, envelope: BackupEnvelope) {
        for (const table of [...parentFirstTables].reverse()) {
            if (!(await this.tableExists(manager, table))) continue;
            const child = childScope[table];
            if (child) await manager.query(`DELETE FROM ${table} child USING ${child.parent} parent WHERE parent.id = child.${child.childKey} AND parent.shop_id = $1`, [shopId]);
            else await manager.query(`DELETE FROM ${table} WHERE shop_id = $1`, [shopId]);
        }
        for (const table of parentFirstTables) {
            if (!(await this.tableExists(manager, table))) continue;
            const rows = envelope.tables[table] || [];
            if (rows.length) {
                await manager.query(`INSERT INTO ${table} SELECT * FROM jsonb_populate_recordset(NULL::${table}, $1::jsonb)`, [JSON.stringify(rows)]);
                const [sequence] = await manager.query("SELECT pg_get_serial_sequence($1, 'id') AS name", [table]);
                if (sequence?.name) {
                    await manager.query(
                        `SELECT setval($1::regclass, GREATEST(COALESCE(MAX(id), 1), 1), COUNT(*) > 0) FROM ${table}`,
                        [sequence.name],
                    );
                }
            }
        }
        if (envelope.profile) {
            const p = envelope.profile as Record<string, unknown>;
            await manager.query(`UPDATE shop_profiles SET shop_name=$2, logo_url=$3, phone=$4, address=$5, tax_code=$6, bank_account=$7, bank_id=$8, bank_name=$9, account_holder=$10, qr_payment_url=$11, receipt_footer=$12, receipt_template_config=$13::jsonb, email=$14, website=$15 WHERE shop_id=$1 OR id=$1`, [
                shopId, p.shop_name, p.logo_url, p.phone, p.address, p.tax_code, p.bank_account, p.bank_id, p.bank_name, p.account_holder, p.qr_payment_url, p.receipt_footer, JSON.stringify(p.receipt_template_config || null), p.email, p.website,
            ]);
        }
    }

    private async tableExists(manager: EntityManager, table: string) {
        const [row] = await manager.query('SELECT to_regclass($1) IS NOT NULL AS exists', [`public.${table}`]);
        return Boolean(row?.exists);
    }
}
