import { In } from 'typeorm';
import { AppDataSource } from '../config/db.config';
import { ShopMember } from '../shop/entities';
import { permittedDashboardShopIds } from '../dashboard/action-access.utils';
import {
    DashboardActionItem,
    lowStockActionCopy,
    scorePriority,
    sortDashboardActionItems,
    taxConfigurationActionDetail,
} from '../dashboard/action-center.utils';
import {
    taxPolicyService,
    TaxPolicyConfigurationError,
} from './tax-policy.service';

type ShopScope = number | number[];
type PermissionDomain = 'inventory' | 'customers' | 'finance';

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
    private async allowedShopIds(
        userId: number,
        scope: ShopScope,
        domain: PermissionDomain,
    ): Promise<number[]> {
        const requested = Array.isArray(scope) ? scope : [scope];
        if (!requested.length) return [];
        const members = await AppDataSource.getRepository(ShopMember).find({
            where: {
                userId,
                shopId: In(requested),
                isActive: true,
                status: 'ACTIVE',
            },
            relations: ['role'],
        });
        return permittedDashboardShopIds(members, domain);
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
                  AND COALESCE(p.min_stock, 0) > 0
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
                detail: 'Không có sản phẩm hết hàng hoặc chạm mức tồn tối thiểu',
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
        const warningDays = Number(expiryConfig[0]?.config_value);
        const hasWarningConfig = Number.isSafeInteger(warningDays) && warningDays > 0;
        const expiryRows = await AppDataSource.query(`
            SELECT
                COUNT(*) FILTER (WHERE expiry_date < $2::date) AS expired_count,
                COUNT(*) FILTER (
                    WHERE $3::int IS NOT NULL
                      AND expiry_date >= $2::date
                      AND expiry_date <= ($2::date + $3::int)
                ) AS expiring_count,
                MIN(expiry_date) AS nearest_expiry,
                MAX(created_at) AS source_updated_at
            FROM product_batches
            WHERE shop_id = ANY($1::int[])
              AND is_active = TRUE
              AND quantity > 0
              AND expiry_date IS NOT NULL
        `, [shopIds, dateKey(now), hasWarningConfig ? warningDays : null]);
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

    private async receivableItems(shopIds: number[], now: Date) {
        const items: DashboardActionItem[] = [];
        const healthy: DashboardActionItem[] = [];
        if (!shopIds.length) return { items, healthy };
        const rows = await AppDataSource.query(`
            SELECT
                COUNT(*) AS overdue_count,
                COALESCE(SUM(amount - COALESCE(paid_amount, 0)), 0) AS overdue_amount,
                MIN(due_date) AS oldest_due_at,
                MAX(updated_at) AS source_updated_at
            FROM receivables
            WHERE shop_id = ANY($1::int[])
              AND status NOT IN ('PAID', 'CANCELLED')
              AND due_date < $2::date
              AND (amount - COALESCE(paid_amount, 0)) > 0
        `, [shopIds, dateKey(now)]);
        const row = rows[0] || {};
        const count = Number(row.overdue_count || 0);
        const amount = Number(row.overdue_amount || 0);
        const dueAt = dateKey(row.oldest_due_at);
        const daysOverdue = dueAt ? dayDifference(now, new Date(`${dueAt}T00:00:00Z`)) : 0;
        if (count > 0) {
            items.push({
                actionKey: 'RECEIVABLE_OVERDUE',
                severity: 'CRITICAL',
                priorityScore: scorePriority({ daysOverdue, affectedCount: count, affectedAmount: amount }),
                title: `${count} khoản công nợ quá hạn`,
                detail: `${amount.toLocaleString('vi-VN')} đ · quá hạn lâu nhất ${daysOverdue} ngày`,
                badge: 'Khẩn cấp',
                count,
                amount,
                dueAt,
                sourceUpdatedAt: isoTimestamp(row.source_updated_at),
            });
        } else {
            healthy.push({
                actionKey: 'RECEIVABLE_HEALTHY',
                severity: 'HEALTHY',
                priorityScore: 0,
                title: 'Không có công nợ quá hạn',
                detail: 'Các khoản công nợ đang trong hạn hoặc đã thanh toán',
                badge: 'Đang ổn định',
                count: 0,
                sourceUpdatedAt: isoTimestamp(row.source_updated_at),
            });
        }
        return { items, healthy };
    }

    private async taxItems(shopIds: number[], now: Date) {
        const items: DashboardActionItem[] = [];
        const healthy: DashboardActionItem[] = [];
        if (!shopIds.length) return { items, healthy };

        for (const shopId of shopIds) {
            try {
                await taxPolicyService.getShopTaxConfiguration(shopId);
            } catch (error) {
                if (!(error instanceof TaxPolicyConfigurationError)) throw error;
                items.push({
                    actionKey: `TAX_CONFIG_INVALID:${shopId}`,
                    severity: 'WARNING',
                    priorityScore: scorePriority({ affectedCount: 1 }),
                    title: 'Cấu hình thuế chưa hợp lệ',
                    detail: taxConfigurationActionDetail(),
                    badge: 'Cần xử lý',
                    count: 1,
                });
            }
        }

        const dueWarningConfig = await AppDataSource.query(`
            SELECT config_value
            FROM system_configs
            WHERE config_key = 'TAX_OBLIGATION_WARNING_DAYS'
              AND (shop_id = ANY($1::int[]) OR shop_id IS NULL)
            ORDER BY shop_id DESC NULLS LAST
            LIMIT 1
        `, [shopIds]);
        const warningDays = Number(dueWarningConfig[0]?.config_value);
        const hasWarningConfig = Number.isSafeInteger(warningDays) && warningDays > 0;

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
                MIN(due_date) FILTER (WHERE due_date < $2::date) AS oldest_due_at,
                MIN(due_date) FILTER (WHERE due_date >= $2::date) AS nearest_due_at,
                MAX(created_at) AS source_updated_at
            FROM tax_obligations
            WHERE shop_id = ANY($1::int[])
              AND LOWER(status) NOT IN ('done', 'paid', 'cancelled')
              AND GREATEST(vat_declared + pit_declared - vat_paid - pit_paid, 0) > 0
        `, [shopIds, dateKey(now), hasWarningConfig ? warningDays : null]);
        const row = rows[0] || {};
        const overdueCount = Number(row.overdue_count || 0);
        const dueSoonCount = Number(row.due_soon_count || 0);
        const amount = Number(row.overdue_amount || 0);
        const overdueDueAt = dateKey(row.oldest_due_at);
        const daysOverdue = overdueDueAt
            ? dayDifference(now, new Date(`${overdueDueAt}T00:00:00Z`))
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
        const [inventoryShopIds, customerShopIds, financeShopIds] = await Promise.all([
            this.allowedShopIds(userId, scope, 'inventory'),
            this.allowedShopIds(userId, scope, 'customers'),
            this.allowedShopIds(userId, scope, 'finance'),
        ]);
        const [inventory, receivables, tax] = await Promise.all([
            this.inventoryItems(inventoryShopIds, now),
            this.receivableItems(customerShopIds, now),
            this.taxItems(financeShopIds, now),
        ]);
        return {
            asOf: now.toISOString(),
            items: sortDashboardActionItems([
                ...inventory.items,
                ...receivables.items,
                ...tax.items,
            ]),
            healthySummary: sortDashboardActionItems([
                ...inventory.healthy,
                ...receivables.healthy,
                ...tax.healthy,
            ]),
        };
    }
}
