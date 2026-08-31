export type DataQualitySeverity = 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';
export type DataQualityConfidence = 'HIGH' | 'MEDIUM' | 'LOW';

export type DataQualityFinding = {
  code: string;
  shopId: number;
  title: string;
  severity: DataQualitySeverity;
  confidence: DataQualityConfidence;
  violations: number;
  population: number;
  rate: number;
  evidence: string;
  risk: string;
  cause: string;
  remediation: string;
};

export type RealismMetrics = {
  totalProducts: number;
  activeDays: number;
  activeMonths: number;
  dateSpanDays: number;
  totalOrders: number;
  validOrders: number;
  cancelledOrders: number;
  cancelledOrderRate: number;
  medianDailyOrders: number;
  p95DailyOrders: number;
  maxDailyOrders: number;
  monthlyOrderCv: number;
  profileMatchRate: number;
  dailyCoverage: number;
  creditOrderRate: number;
  returnRate: number;
  cashPaymentRate: number;
  invoiceCoverage: number;
  topCustomerRevenueShare: number;
  topProductRevenueShare: number;
  fixedExpenseDayRate: number;
  businessMarkerCount: number;
  datasetMarkerCount: number;
  attachmentMarkerCount: number;
};

export const TEST_SHOP_IDS = [34, 35] as const;

export const TEST_SHOP_PROFILES: Record<number, 'construction' | 'agriculture'> = {
  34: 'construction',
  35: 'agriculture',
};

const isPositiveInteger = (value: number): boolean => Number.isSafeInteger(value) && value > 0;

export function parseTestShopIds(raw: string | undefined = '34,35'): number[] {
  const values = (raw || '')
    .split(',')
    .map((value) => Number(value.trim()))
    .filter(isPositiveInteger);
  const unique = [...new Set(values)];
  if (!unique.length || unique.some((value) => !TEST_SHOP_IDS.includes(value as 34 | 35))) {
    throw new Error('Chỉ cho phép shop test 34 và 35. Dùng --shop-ids=34,35.');
  }
  return TEST_SHOP_IDS.filter((shopId) => unique.includes(shopId));
}

export function parseAsOfDate(raw: string | undefined, fallback = '2026-08-31'): string {
  const value = raw || fallback;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new Error('--as-of phải có dạng YYYY-MM-DD');
  }
  const [year, month, day] = value.split('-').map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (parsed.getUTCFullYear() !== year || parsed.getUTCMonth() !== month - 1 || parsed.getUTCDate() !== day) {
    throw new Error(`--as-of không hợp lệ: ${value}`);
  }
  return value;
}

export function numberValue(value: unknown): number {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

export function percentage(part: unknown, whole: unknown): number {
  const denominator = numberValue(whole);
  if (denominator <= 0) return 0;
  return Number(((numberValue(part) / denominator) * 100).toFixed(2));
}

export function normalizeMetrics(row: Record<string, unknown>): RealismMetrics {
  return {
    totalProducts: numberValue(row.totalProducts),
    activeDays: numberValue(row.activeDays),
    activeMonths: numberValue(row.activeMonths),
    dateSpanDays: numberValue(row.dateSpanDays),
    totalOrders: numberValue(row.totalOrders),
    validOrders: numberValue(row.validOrders),
    cancelledOrders: numberValue(row.cancelledOrders),
    cancelledOrderRate: numberValue(row.cancelledOrderRate),
    medianDailyOrders: numberValue(row.medianDailyOrders),
    p95DailyOrders: numberValue(row.p95DailyOrders),
    maxDailyOrders: numberValue(row.maxDailyOrders),
    monthlyOrderCv: numberValue(row.monthlyOrderCv),
    profileMatchRate: numberValue(row.profileMatchRate),
    dailyCoverage: numberValue(row.dailyCoverage),
    creditOrderRate: numberValue(row.creditOrderRate),
    returnRate: numberValue(row.returnRate),
    cashPaymentRate: numberValue(row.cashPaymentRate),
    invoiceCoverage: numberValue(row.invoiceCoverage),
    topCustomerRevenueShare: numberValue(row.topCustomerRevenueShare),
    topProductRevenueShare: numberValue(row.topProductRevenueShare),
    fixedExpenseDayRate: numberValue(row.fixedExpenseDayRate),
    businessMarkerCount: numberValue(row.businessMarkerCount),
    datasetMarkerCount: numberValue(row.datasetMarkerCount),
    attachmentMarkerCount: numberValue(row.attachmentMarkerCount),
  };
}

export function evaluateRealism(
  shopId: number,
  metrics: RealismMetrics,
): DataQualityFinding[] {
  const findings: DataQualityFinding[] = [];
  const add = (
    code: string,
    title: string,
    severity: DataQualitySeverity,
    violations: number,
    population: number,
    evidence: string,
    risk: string,
    cause: string,
    remediation: string,
  ) => {
    if (violations <= 0) return;
    findings.push({
      code,
      shopId,
      title,
      severity,
      confidence: 'MEDIUM',
      violations,
      population,
      rate: percentage(violations, population),
      evidence,
      risk,
      cause,
      remediation,
    });
  };

  add(
    'REALISM_DAILY_SPIKE',
    'Phân bố số đơn theo ngày có đỉnh bất thường',
    'MEDIUM',
    metrics.p95DailyOrders > 35 || metrics.maxDailyOrders > 60 ? 1 : 0,
    Math.max(metrics.activeDays, 1),
    `P50=${metrics.medianDailyOrders}, P95=${metrics.p95DailyOrders}, max=${metrics.maxDailyOrders}`,
    'Biểu đồ doanh thu và năng lực cửa hàng có thể bị phóng đại bởi một số ngày sinh dữ liệu quá dày.',
    'Bộ sinh dữ liệu dùng số đơn cố định cộng nhiễu hoặc mở rộng đột ngột theo ngày.',
    'Điều chỉnh theo ngày trong tuần, mùa vụ và xác suất ngày thấp điểm; giữ lại seed có kiểm soát.',
  );
  add(
    'REALISM_LOW_DAILY_VARIATION',
    'Dữ liệu ngày có biến động quá thấp',
    'MEDIUM',
    metrics.activeDays >= 30 && metrics.p95DailyOrders <= metrics.medianDailyOrders && metrics.medianDailyOrders > 0 ? 1 : 0,
    Math.max(metrics.activeDays, 1),
    `P50=${metrics.medianDailyOrders}, P95=${metrics.p95DailyOrders}, ngày hoạt động=${metrics.activeDays}`,
    'KPI xu hướng, ngày cao điểm và dự báo dòng tiền sẽ thiếu giá trị trình diễn.',
    'Số đơn/ngày được phân bổ gần như đồng đều.',
    'Bổ sung ngày thấp điểm, cuối tuần và mùa vụ theo từng ngành hàng.',
  );
  add(
    'REALISM_PROFILE_ALIGNMENT',
    'Danh mục sản phẩm chưa khớp hồ sơ ngành của shop',
    'MEDIUM',
    metrics.totalProducts >= 12 && metrics.profileMatchRate < 40 ? 1 : 0,
    Math.max(metrics.totalProducts, 1),
    `${metrics.profileMatchRate.toFixed(2)}% sản phẩm khớp từ khóa hồ sơ ngành`,
    'Dữ liệu demo có thể tạo biểu đồ và Pareto không đúng bối cảnh kinh doanh.',
    'Master sản phẩm được sao chép hoặc đặt tên chung, không bám hồ sơ shop.',
    'Rà soát từng sản phẩm theo nguồn; chỉ đổi tên/nhóm khi có căn cứ nghiệp vụ.',
  );
  add(
    'REALISM_MONTHLY_FLATNESS',
    'Phân bố đơn theo tháng quá phẳng',
    'LOW',
    metrics.activeMonths >= 6 && metrics.monthlyOrderCv < 8 ? 1 : 0,
    Math.max(metrics.activeMonths, 1),
    `${metrics.activeMonths} tháng hoạt động, hệ số biến thiên=${metrics.monthlyOrderCv.toFixed(2)}%`,
    'Xu hướng mùa vụ và dự báo dòng tiền ít có giá trị kiểm thử.',
    'Số đơn/ngày được mở rộng gần đều qua các tháng.',
    'Điều chỉnh theo mùa của từng ngành, chỉ khi có dữ liệu nguồn hoặc quy ước fixture được duyệt.',
  );
  add(
    'REALISM_CUSTOMER_UNIFORMITY',
    'Doanh thu phân bổ quá đều giữa khách hàng',
    'MEDIUM',
    metrics.topCustomerRevenueShare < 35 && metrics.validOrders >= 30 ? 1 : 0,
    Math.max(metrics.validOrders, 1),
    `Top 20% khách hàng chiếm ${metrics.topCustomerRevenueShare.toFixed(2)}% doanh thu`,
    'Phân tích khách hàng thân thiết, bán sỉ và công nợ không phản ánh hành vi thực tế.',
    'Khách hàng được chọn luân phiên hoặc ngẫu nhiên gần như đồng đều.',
    'Dùng nhóm khách hàng có trọng số: khách sỉ/thường xuyên mua nhiều hơn khách lẻ.',
  );
  add(
    'REALISM_PRODUCT_UNIFORMITY',
    'Doanh thu phân bổ quá đều giữa sản phẩm',
    'MEDIUM',
    metrics.topProductRevenueShare < 50 && metrics.validOrders >= 30 ? 1 : 0,
    Math.max(metrics.validOrders, 1),
    `Top 20% sản phẩm chiếm ${metrics.topProductRevenueShare.toFixed(2)}% doanh thu`,
    'Pareto sản phẩm, cảnh báo tồn chậm và quyết định nhập hàng có thể gây hiểu nhầm.',
    'Sản phẩm được chọn không đủ trọng số theo nhóm bán chạy/chậm.',
    'Thiết lập trọng số theo nhóm hàng và kiểm tra lại tồn cuối kỳ.',
  );
  add(
    'REALISM_FIXED_EXPENSE_CADENCE',
    'Chi phí vận hành tập trung bất thường vào ngày cố định',
    'LOW',
    metrics.fixedExpenseDayRate > 80 ? 1 : 0,
    100,
    `${metrics.fixedExpenseDayRate.toFixed(2)}% giao dịch chi rơi vào ngày 05/10/18`,
    'Biểu đồ dòng tiền có các đỉnh nhân tạo và không giống quy trình chi phí thực tế.',
    'Bộ sinh chi phí dùng ngày cố định trong tháng.',
    'Giữ ngày đến hạn của tiền thuê/lương nhưng phân tán chi phí giao nhận, điện nước và chi phí khác.',
  );
  add(
    'REALISM_LOW_PAYMENT_MIX',
    'Phân bố phương thức thanh toán quá nghèo',
    'LOW',
    metrics.validOrders >= 30 && (metrics.cashPaymentRate < 10 || metrics.cashPaymentRate > 80) ? 1 : 0,
    Math.max(metrics.validOrders, 1),
    `Thanh toán tiền mặt chiếm ${metrics.cashPaymentRate.toFixed(2)}%`,
    'Đối chiếu tiền mặt/ngân hàng và demo QR không đại diện cho vận hành bình thường.',
    'Một phương thức thanh toán chiếm ưu thế do cách sinh dữ liệu.',
    'Giữ tỷ trọng tiền mặt, chuyển khoản và QR trong dải hợp lý, đồng thời đối soát journal 111/112.',
  );
  add(
    'REALISM_NO_CREDIT_OR_RETURN',
    'Thiếu biến thể bán chịu hoặc hoàn hàng',
    'MEDIUM',
    metrics.validOrders >= 100 && (metrics.creditOrderRate === 0 || metrics.returnRate === 0) ? 1 : 0,
    Math.max(metrics.validOrders, 1),
    `Bán chịu=${metrics.creditOrderRate.toFixed(2)}%, hoàn=${metrics.returnRate.toFixed(2)}%`,
    'Không thể đánh giá đầy đủ công nợ, thu nợ, hoàn tiền và đảo tồn.',
    'Bộ dữ liệu chỉ mô phỏng giao dịch hoàn tất.',
    'Bổ sung tỷ lệ nhỏ bán chịu, trả một phần, hoàn/hủy; mọi bản ghi phải có liên kết và đối soát.',
  );
  add(
    'REALISM_BUSINESS_MARKERS',
    'Ghi chú nghiệp vụ còn marker test',
    'MEDIUM',
    metrics.businessMarkerCount,
    Math.max(metrics.totalOrders, 1),
    `Phát hiện ${metrics.businessMarkerCount} marker trong trường nghiệp vụ`,
    'Người dùng có thể hiểu nhầm dữ liệu thử nghiệm là giao dịch vận hành thật.',
    'Script seed/extension ghi trực tiếp cụm “Dữ liệu kiểm thử”, “mẫu” hoặc “TEST_DATASET”.',
    'Giữ nguồn gốc trong metadata/audit log; chỉ chuẩn hóa ghi chú hiển thị khi xác định đúng bản ghi seed.',
  );
  add(
    'REALISM_ATTACHMENT_MARKERS',
    'Tệp đính kèm còn marker dữ liệu test',
    'MEDIUM',
    metrics.attachmentMarkerCount,
    Math.max(metrics.attachmentMarkerCount, 1),
    `Phát hiện ${metrics.attachmentMarkerCount} marker trong dữ liệu ảnh/chứng từ`,
    'Người dùng có thể hiểu nhầm ảnh/chứng từ mô phỏng là bằng chứng vận hành thật.',
    'Tệp fixture hoặc metadata OCR được tạo cho bộ kiểm thử.',
    'Không tạo thêm tệp giả; chỉ giữ nguồn gốc trong metadata và thay bằng tệp thật khi có người dùng cung cấp.',
  );

  return findings;
}

export function summarizeSeverity(findings: DataQualityFinding[]): 'PASS' | 'WARNING' | 'FAIL' {
  if (findings.some((finding) => finding.severity === 'CRITICAL' || finding.severity === 'HIGH')) {
    return 'FAIL';
  }
  return findings.length ? 'WARNING' : 'PASS';
}
