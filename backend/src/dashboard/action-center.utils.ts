export type DashboardActionSeverity =
    | 'CRITICAL'
    | 'WARNING'
    | 'INFO'
    | 'HEALTHY';

export interface DashboardActionItem {
    actionKey: string;
    severity: DashboardActionSeverity;
    priorityScore: number;
    title: string;
    detail: string;
    badge: string;
    count?: number;
    amount?: number;
    dueAt?: string | null;
    sourceUpdatedAt?: string | null;
}

export const lowStockActionCopy = (count: number): {
    title: string;
    detail: string;
} => ({
    title: `${count} sản phẩm đã chạm hoặc thấp hơn định mức tồn`,
    detail: 'Cần kiểm tra tồn thực tế và lập đơn nhập hàng phù hợp',
});

export const taxConfigurationActionDetail = (): string =>
    'Thiếu hoặc sai thông tin chính sách thuế. Vào Cài đặt thuế để kiểm tra năm áp dụng, ngày hiệu lực, các ngưỡng và nguồn tham chiếu';

const severityRank: Record<DashboardActionSeverity, number> = {
    CRITICAL: 4,
    WARNING: 3,
    INFO: 2,
    HEALTHY: 1,
};

const finiteNonNegative = (value: number): number =>
    Number.isFinite(value) ? Math.max(0, value) : 0;

export const scorePriority = ({
    daysOverdue = 0,
    affectedCount = 0,
    affectedAmount = 0,
    stockDeficit = 0,
}: {
    daysOverdue?: number;
    affectedCount?: number;
    affectedAmount?: number;
    stockDeficit?: number;
}): number => {
    const overdueScore = Math.min(400, finiteNonNegative(daysOverdue) * 8);
    const countScore = Math.min(200, finiteNonNegative(affectedCount) * 10);
    const amountScore = Math.min(
        250,
        Math.log10(finiteNonNegative(affectedAmount) + 1) * 30,
    );
    const deficitScore = Math.min(150, finiteNonNegative(stockDeficit) * 5);
    return Math.round(overdueScore + countScore + amountScore + deficitScore);
};

const dueTimestamp = (value?: string | null): number => {
    if (!value) return Number.POSITIVE_INFINITY;
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : Number.POSITIVE_INFINITY;
};

export const sortDashboardActionItems = <T extends DashboardActionItem>(
    items: T[],
): T[] => [...items].sort((left, right) => {
    const severityDifference =
        severityRank[right.severity] - severityRank[left.severity];
    if (severityDifference !== 0) return severityDifference;

    const scoreDifference = right.priorityScore - left.priorityScore;
    if (scoreDifference !== 0) return scoreDifference;

    const dueDifference = dueTimestamp(left.dueAt) - dueTimestamp(right.dueAt);
    if (dueDifference !== 0) return dueDifference;

    return left.actionKey.localeCompare(right.actionKey);
});
