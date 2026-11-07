import { In } from 'typeorm';
import { AppDataSource } from '../config/db.config';
import { ShopMember } from '../shop/entities';
import { permittedDashboardShopIds } from '../dashboard/action-access.utils';
import { readCurrentDebtSummary } from '../finance/current-debt-summary.repository';
import {
    DashboardActionItem,
    lowStockActionCopy,
    scorePriority,
    sortDashboardActionItems,
    taxConfigurationActionDetail,
    businessDateKey,
    debtReminderItems,
} from '../dashboard/action-center.utils';
import {
    taxPolicyService,
    TaxPolicyConfigurationError,
} from './tax-policy.service';

type ShopScope = number | number[];
interface DashboardActionResponse {
    asOf: string;
    items: DashboardActionItem[];
    healthySummary: DashboardActionItem[];
}

const dateKey = (value: unknown): string | null => {
    if (!value) return null;
    const date = value instanceof Date ? value : new Date(String(value));
    if (Number.isNaN(date.getTime())) return null;
    return date.toISOString().split('T')[0];
};

const isoTimestamp = (value: unknown): string | null => {
    if (!value) return null;
    const date = value instanceof Date ? value : new Date(String(value));
    return Number.isNaN(date.getTime()) ? null : date.toISOString();
};

const dayDifference = (later: Date, earlier: Date): number =>
    Math.max(0, Math.floor((later.getTime() - earlier.getTime()) / 86_400_000));

export class DashboardService {
    private async activeMemberships(
        userId: number,
        scope: ShopScope,
    ): Promise<ShopMember[]> {
        const requested = Array.isArray(scope) ? scope : [scope];
        if (!requested.length) return [];
        return AppDataSource.getRepository(ShopMember).find({
            where: {
                userId,
                shopId: In(requested),
                isActive: true,
                status: 'ACTIVE',
            },
            relations: ['role'],
        });
    }

    private async inventoryItems(shopIds: number[], now: Date) {
        const items: DashboardActionItem[] = [];
        const healthy: DashboardActionItem[] = [];
        if (!shopIds.length) return { items, healthy };

        const stockRows = await AppDataSource.query(`
            SELECT
                COUNT(*) FILTER (WHERE current_quantity <= 0) AS out_count,
                COUNT(*) FILTER (
                    WHERE current_quantity > 0 AND current_quantity <= min_stock
                ) AS low_count,
                COALESCE(SUM(GREATEST(min_stock - current_quantity, 0)), 0) AS deficit,
                MAX(source_updated_at) AS source_updated_at
            FROM (
                SELECT
                    p.id,
                    COALESCE(p.min_stock, 0)::numeric AS min_stock,
                    COALESCE(SUM(s.quantity), 0)::numeric AS current_quantity,
                    GREATEST(MAX(p.updated_at), MAX(s.updated_at)) AS source_updated_at
                FROM products p
                LEFT JOIN inventory_stocks s
                    ON s.product_id = p.id AND s.shop_id = p.shop_id
                WHERE p.shop_id = ANY($1::int[])
                  AND p.is_active = TRUE
                GROUP BY p.id, p.min_stock
            ) stock_state
        `, [shopIds]);
        const stock = stockRows[0] || {};
        const outCount = Number(stock.out_count || 0);
        const lowCount = Number(stock.low_count || 0);
        const deficit = Number(stock.deficit || 0);

        if (outCount > 0) {
            items.push({
                actionKey: 'INVENTORY_OUT_OF_STOCK',
                severity: 'CRITICAL',
                priorityScore: scorePriority({ affectedCount: outCount, stockDeficit: deficit }),
                title: `${outCount} sản phẩm đã hết hàng`,
                detail: 'Cần kiểm tra tồn thực tế và bổ sung hàng theo định mức từng sản phẩm',
                badge: 'Khẩn cấp',
                count: outCount,
                sourceUpdatedAt: isoTimestamp(stock.source_updated_at),
            });
        }
        if (lowCount > 0) {
            const copy = lowStockActionCopy(lowCount);
            items.push({
                actionKey: 'INVENTORY_LOW_STOCK',
                severity: 'WARNING',
                priorityScore: scorePriority({ affectedCount: lowCount, stockDeficit: deficit }),
                title: copy.title,
                detail: copy.detail,
                badge: 'Cần xử lý',
                count: lowCount,
                sourceUpdatedAt: isoTimestamp(stock.source_updated_at),
            });
        }
        if (outCount === 0 && lowCount === 0) {
            healthy.push({
                actionKey: 'INVENTORY_HEALTHY',
                severity: 'HEALTHY',
                priorityScore: 0,
                title: 'Tồn kho trong định mức',
                detail: 'Không phát hiện sản phẩm hết hàng hoặc chạm định mức đã thiết lập',
                badge: 'Đang ổn định',
                count: 0,
                sourceUpdatedAt: isoTimestamp(stock.source_updated_at),
            });
        }

        const expiryConfig = await AppDataSource.query(`
            SELECT config_value
            FROM system_configs
            WHERE config_key = 'INVENTORY_EXPIRY_WARNING_DAYS'
              AND (shop_id = ANY($1::int[]) OR shop_id IS NULL)
            ORDER BY shop_id DESC NULLS LAST
            LIMIT 1
        `, [shopIds]);
        const configuredDays = Number(expiryConfig[0]?.config_value);
        const warningDays = Number.isSafeInteger(configuredDays) && configuredDays > 0 ? configuredDays : 7;
        const expiryRows = await AppDataSource.query(`
            SELECT
                COUNT(*) FILTER (WHERE expiry_date < $2::date) AS expired_count,
                COUNT(*) FILTER (
                    WHERE $3::int IS NOT NULL
                      AND expiry_date >= $2::date
                      AND expiry_date <= ($2::date + $3::int)
                ) AS expiring_count,
                MIN(expiry_date)::text AS nearest_expiry,
                MAX(created_at) AS source_updated_at
            FROM product_batches
            WHERE shop_id = ANY($1::int[])
              AND is_active = TRUE
              AND quantity > 0
              AND expiry_date IS NOT NULL
        `, [shopIds, businessDateKey(now), warningDays]);
        const expiry = expiryRows[0] || {};
        const expiredCount = Number(expiry.expired_count || 0);
        const expiringCount = Number(expiry.expiring_count || 0);
        const nearestExpiry = dateKey(expiry.nearest_expiry);
        if (expiredCount > 0) {
            items.push({
                actionKey: 'INVENTORY_EXPIRED_BATCHES',
                severity: 'CRITICAL',
                priorityScore: scorePriority({ affectedCount: expiredCount }),
                title: `${expiredCount} lô hàng đã hết hạn`,
                detail: 'Cần khóa xuất bán và xử lý lô theo quy trình kho',
                badge: 'Khẩn cấp',
                count: expiredCount,
                dueAt: nearestExpiry,
                sourceUpdatedAt: isoTimestamp(expiry.source_updated_at),
            });
        }
        if (expiringCount > 0) {
            items.push({
                actionKey: 'INVENTORY_EXPIRING_BATCHES',
                severity: 'WARNING',
                priorityScore: scorePriority({ affectedCount: expiringCount }),
                title: `${expiringCount} lô sắp hết hạn`,
                detail: `Sẽ hết hạn trong ${warningDays} ngày theo thời gian cảnh báo đã cấu hình`,
                badge: 'Cần xử lý',
                count: expiringCount,
                dueAt: nearestExpiry,
                sourceUpdatedAt: isoTimestamp(expiry.source_updated_at),
            });
        }
        return { items, healthy };
    }

    private async debtItems(kind: 'RECEIVABLE' | 'PAYABLE', shopIds: number[], now: Date) {
        const items: DashboardActionItem[] = [];
        const healthy: DashboardActionItem[] = [];
        if (!shopIds.length) return { items, healthy };
        const row = await AppDataSource.transaction('REPEATABLE READ', manager =>
            readCurrentDebtSummary(manager, kind, shopIds, businessDateKey(now)));
        // PostgreSQL date values may arrive as Date objects; normalize before building copy.
        for (const key of ['overdue_due_at', 'today_due_at', 'soon_due_at']) row[key] = dateKey(row[key]);
        items.push(...debtReminderItems(kind, row, businessDateKey(now)).map(item => ({
            ...item, sourceUpdatedAt: isoTimestamp(row.source_updated_at),
        })));
        if (!items.length) healthy.push({
            actionKey: `${kind}_HEALTHY`, severity: 'HEALTHY', priorityScore: 0,
            title: kind === 'PAYABLE' ? 'Không có khoản phải trả đến hạn trong 7 ngày' : 'Không có khoản phải thu đến hạn trong 7 ngày',
            detail: 'Không phát hiện khoản còn dư nợ quá hạn, đến hạn hôm nay hoặc trong 7 ngày tới',
            badge: 'Đã kiểm tra', count: 0,
        });
        return { items, healthy };
    }

    private async pendingPurchases(ownerIds: number[]) {
        if (!ownerIds.length) return [];
        const rows = await AppDataSource.query(`
            SELECT p.shop_id, s.shop_name, COUNT(*) AS count,
                   COALESCE(SUM(p.total_amount), 0) AS amount, MAX(p.created_at) AS updated_at
            FROM purchases_without_invoice p
            JOIN shop_profiles s ON s.id = p.shop_id
            WHERE p.shop_id = ANY($1::int[]) AND p.approval_status = 'PENDING'
            GROUP BY p.shop_id, s.shop_name
        `, [ownerIds]);
        return rows.map((row: Record<string, unknown>): DashboardActionItem => ({
            actionKey: `PURCHASE_APPROVAL_PENDING:${row.shop_id}`,
            shopId: Number(row.shop_id), severity: 'WARNING',
            priorityScore: scorePriority({ affectedCount: Number(row.count), affectedAmount: Number(row.amount) }),
            title: `${row.count} bảng kê mua hàng không hóa đơn chờ duyệt`,
            detail: `${row.shop_name} · kiểm tra chứng từ trước khi phê duyệt`,
            badge: 'Chờ duyệt', count: Number(row.count), amount: Number(row.amount),
            sourceUpdatedAt: isoTimestamp(row.updated_at),
        }));
    }

    private async taxItems(shopIds: number[], now: Date) {
        const items: DashboardActionItem[] = [];
        const healthy: DashboardActionItem[] = [];
        if (!shopIds.length) return { items, healthy };

        // Configuration validation and the due-date aggregate are independent.
        // Keep both fresh without forcing either branch to wait for the other.
        const [configurationWarnings, { rows, warningDays }] = await Promise.all([
            Promise.all(shopIds.map(async (shopId): Promise<DashboardActionItem | null> => {
                try {
                    await taxPolicyService.getShopTaxConfiguration(shopId);
                    return null;
                } catch (error) {
                    if (!(error instanceof TaxPolicyConfigurationError)) throw error;
                    return {
                        actionKey: `TAX_CONFIG_INVALID:${shopId}`,
                        severity: 'WARNING',
                        priorityScore: scorePriority({ affectedCount: 1 }),
                        title: 'Cấu hình thuế chưa hợp lệ',
                        detail: taxConfigurationActionDetail(),
                        badge: 'Cần xử lý',
                        count: 1,
                    };
                }
            })),
            (async () => {
                const dueWarningConfig = await AppDataSource.query(`
                    SELECT config_value
                    FROM system_configs
                    WHERE config_key = 'TAX_OBLIGATION_WARNING_DAYS'
                      AND (shop_id = ANY($1::int[]) OR shop_id IS NULL)
                    ORDER BY shop_id DESC NULLS LAST
                    LIMIT 1
                `, [shopIds]);
                const configuredDays = Number(dueWarningConfig[0]?.config_value);
                const warningDays = Number.isSafeInteger(configuredDays) && configuredDays > 0 ? configuredDays : 7;

                const rows = await AppDataSource.query(`
                    SELECT
                        COUNT(*) FILTER (WHERE due_date < $2::date) AS overdue_count,
                        COUNT(*) FILTER (
                            WHERE $3::int IS NOT NULL
                              AND due_date >= $2::date
                              AND due_date <= ($2::date + $3::int)
                        ) AS due_soon_count,
                        COALESCE(SUM(
                            GREATEST(vat_declared + pit_declared - vat_paid - pit_paid, 0)
                        ) FILTER (WHERE due_date < $2::date), 0) AS overdue_amount,
                        (MIN(due_date) FILTER (WHERE due_date < $2::date))::text AS oldest_due_at,
                        (MIN(due_date) FILTER (WHERE due_date >= $2::date))::text AS nearest_due_at,
                        MAX(created_at) AS source_updated_at
                    FROM tax_obligations
                    WHERE shop_id = ANY($1::int[])
                      AND LOWER(status) NOT IN ('done', 'paid', 'cancelled')
                      AND GREATEST(vat_declared + pit_declared - vat_paid - pit_paid, 0) > 0
                `, [shopIds, businessDateKey(now), warningDays]);
                return { rows, warningDays };
            })(),
        ]);
        items.push(...configurationWarnings.filter((item): item is DashboardActionItem => item !== null));
        const row = rows[0] || {};
        const overdueCount = Number(row.overdue_count || 0);
        const dueSoonCount = Number(row.due_soon_count || 0);
        const amount = Number(row.overdue_amount || 0);
        const overdueDueAt = dateKey(row.oldest_due_at);
        const daysOverdue = overdueDueAt
            ? dayDifference(new Date(`${businessDateKey(now)}T00:00:00Z`), new Date(`${overdueDueAt}T00:00:00Z`))
            : 0;
        if (overdueCount > 0) {
            items.push({
                actionKey: 'TAX_OBLIGATION_OVERDUE',
                severity: 'CRITICAL',
                priorityScore: scorePriority({ daysOverdue, affectedCount: overdueCount, affectedAmount: amount }),
                title: `${overdueCount} nghĩa vụ thuế quá hạn`,
                detail: `${amount.toLocaleString('vi-VN')} đ · quá hạn lâu nhất ${daysOverdue} ngày`,
                badge: 'Khẩn cấp',
                count: overdueCount,
                amount,
                dueAt: overdueDueAt,
                sourceUpdatedAt: isoTimestamp(row.source_updated_at),
            });
        }
        if (dueSoonCount > 0) {
            items.push({
                actionKey: 'TAX_OBLIGATION_DUE_SOON',
                severity: 'WARNING',
                priorityScore: scorePriority({ affectedCount: dueSoonCount }),
                title: `${dueSoonCount} nghĩa vụ thuế sắp đến hạn`,
                detail: `Đến hạn trong ${warningDays} ngày theo thời gian cảnh báo đã cấu hình`,
                badge: 'Cần xử lý',
                count: dueSoonCount,
                dueAt: dateKey(row.nearest_due_at),
                sourceUpdatedAt: isoTimestamp(row.source_updated_at),
            });
        }
        if (!items.some((item) => item.actionKey.startsWith('TAX_'))) {
            healthy.push({
                actionKey: 'TAX_HEALTHY',
                severity: 'HEALTHY',
                priorityScore: 0,
                title: 'Không có nghĩa vụ thuế cần xử lý ngay',
                detail: 'Cấu hình hợp lệ và chưa có khoản quá hạn hoặc sắp đến hạn',
                badge: 'Đang ổn định',
                count: 0,
                sourceUpdatedAt: isoTimestamp(row.source_updated_at),
            });
        }
        return { items, healthy };
    }

    async getActionItems(
        userId: number,
        scope: ShopScope,
        now = new Date(),
    ): Promise<DashboardActionResponse> {
        // Read the same current memberships once per request. Each domain still
        // applies its existing permission rules; nothing is cached across requests.
        const members = await this.activeMemberships(userId, scope);
        const inventoryShopIds = permittedDashboardShopIds(members, 'inventory');
        const customerShopIds = permittedDashboardShopIds(members, 'customers');
        const financeShopIds = permittedDashboardShopIds(members, 'finance');
        const ownerIds = members
            .filter(member => member.memberType === 'OWNER' && financeShopIds.includes(member.shopId))
            .map(member => member.shopId);
        const [inventory, receivables, payables, tax, approvals] = await Promise.all([
            this.inventoryItems(inventoryShopIds, now),
            this.debtItems('RECEIVABLE', customerShopIds, now),
            this.debtItems('PAYABLE', financeShopIds, now),
            this.taxItems(financeShopIds, now),
            this.pendingPurchases(ownerIds),
        ]);
        return {
            asOf: now.toISOString(),
            items: sortDashboardActionItems([
                ...inventory.items,
                ...receivables.items,
                ...payables.items,
                ...approvals,
                ...tax.items,
            ]),
            healthySummary: sortDashboardActionItems([
                ...inventory.healthy,
                ...receivables.healthy,
                ...payables.healthy,
                ...tax.healthy,
            ]),
        };
    }
}
