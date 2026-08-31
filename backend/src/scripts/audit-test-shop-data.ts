import { writeFile } from 'node:fs/promises';
import 'reflect-metadata';
import { AppDataSource } from '../config/db.config';
import {
  DataQualityFinding,
  TEST_SHOP_PROFILES,
  evaluateRealism,
  normalizeMetrics,
  numberValue,
  parseAsOfDate,
  parseTestShopIds,
  percentage,
  summarizeSeverity,
} from '../quality/test-shop-data.utils';

type CheckDefinition = {
  code: string;
  title: string;
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW';
  confidence: 'HIGH' | 'MEDIUM' | 'LOW';
  sql: string;
  risk: string;
  cause: string;
  remediation: string;
};

type CheckRow = {
  violations: string | number;
  population: string | number;
  evidence?: string | null;
};

type CoverageRow = Record<string, string | number | null>;

type MetricsRow = {
  totalOrders: string | number;
  validOrders: string | number;
  cancelledOrders: string | number;
  firstOrder: string | null;
  lastOrder: string | null;
  totalProducts: string | number;
  totalCustomers: string | number;
  totalSuppliers: string | number;
  totalInvoices: string | number;
  totalCashTransactions: string | number;
  totalJournalEntries: string | number;
  totalInventoryMovements: string | number;
  totalStockTakes: string | number;
  totalReceivables: string | number;
  totalPayables: string | number;
  totalReturns: string | number;
  totalInvoiceScans: string | number;
  totalDebtEvidences: string | number;
  latestBusinessDate: string | null;
};

type DailyRow = {
  activeDays: string | number;
  dateSpanDays: string | number;
  medianDailyOrders: string | number;
  p95DailyOrders: string | number;
  maxDailyOrders: string | number;
};

const argument = (name: string): string | undefined => {
  const prefix = `--${name}=`;
  return process.argv.find((value) => value.startsWith(prefix))?.slice(prefix.length);
};

const format = (argument('format') || 'table').toLowerCase();
const outputPath = argument('output');

const CORE_CHECKS: readonly CheckDefinition[] = [
  {
    code: 'SHOP_EXISTS',
    title: 'Cửa hàng tồn tại đúng phạm vi',
    severity: 'CRITICAL',
    confidence: 'HIGH',
    sql: `
      SELECT
        1 AS population,
        CASE WHEN EXISTS (SELECT 1 FROM shop_profiles WHERE id = $1)
          THEN 0 ELSE 1 END AS violations,
        COALESCE((SELECT shop_name FROM shop_profiles WHERE id = $1), 'missing') AS evidence
    `,
    risk: 'Không thể xác định dataset hoặc có nguy cơ chạy nhầm shop.',
    cause: 'Sai shop_id hoặc bản ghi hồ sơ cửa hàng bị thiếu.',
    remediation: 'Dừng xử lý và xác nhận lại shop_id; không tự tạo hồ sơ.',
  },
  {
    code: 'OWNER_MEMBERSHIP',
    title: 'Có đúng một owner đang hoạt động',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        1 AS population,
        CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END AS violations,
        COUNT(*)::text AS evidence
      FROM shop_members
      WHERE shop_id = $1
        AND member_type = 'OWNER'
        AND status = 'ACTIVE'
        AND is_active = true
    `,
    risk: 'Không có actor hợp lệ để ghi audit metadata và phân quyền có thể sai.',
    cause: 'Membership owner thiếu, trùng hoặc đã bị vô hiệu hóa.',
    remediation: 'Đưa vào danh sách cần xử lý thủ công; không tự gán owner.',
  },
  {
    code: 'PRODUCT_INVALID',
    title: 'Sản phẩm có giá, đơn vị và định mức hợp lệ',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM products WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(p.id::text, ', ' ORDER BY p.id) FILTER (WHERE p.id IS NOT NULL), '') AS evidence
      FROM products p
      WHERE p.shop_id = $1
        AND (
          COALESCE(BTRIM(p.name), '') = ''
          OR COALESCE(BTRIM(p.sku), '') = ''
          OR COALESCE(BTRIM(p.unit), '') = ''
          OR COALESCE(p.cost_price, 0) < 0
          OR COALESCE(p.selling_price, 0) <= 0
          OR p.selling_price < p.cost_price
          OR COALESCE(p.min_stock, 0) < 0
        )
    `,
    risk: 'Giá vốn, cảnh báo tồn và doanh thu có thể bị tính sai.',
    cause: 'Dữ liệu master thiếu hoặc giá trị ngoài miền nghiệp vụ.',
    remediation: 'Sửa từng sản phẩm có bằng chứng; không tự suy đoán giá bán/giá vốn.',
  },
  {
    code: 'PRODUCT_DUPLICATE_SKU',
    title: 'SKU không trùng trong cùng shop',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      WITH duplicate_skus AS (
        SELECT LOWER(BTRIM(sku)) AS sku
        FROM products
        WHERE shop_id = $1
        GROUP BY LOWER(BTRIM(sku))
        HAVING COUNT(*) > 1
      )
      SELECT
        (SELECT COUNT(*) FROM products WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(sku, ', ' ORDER BY sku), '') AS evidence
      FROM duplicate_skus
    `,
    risk: 'Các màn hàng hóa và tồn kho có thể gộp nhầm hai sản phẩm.',
    cause: 'SKU trùng do import hoặc sửa master không có ràng buộc đúng scope.',
    remediation: 'Khóa cập nhật SKU trùng và yêu cầu người phụ trách chọn mã chuẩn.',
  },
  {
    code: 'PRODUCT_CATEGORY_SCOPE',
    title: 'Sản phẩm tham chiếu danh mục cùng shop',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM products WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(p.id::text, ', ' ORDER BY p.id), '') AS evidence
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE p.shop_id = $1
        AND (p.category_id IS NULL OR c.shop_id IS DISTINCT FROM $1)
    `,
    risk: 'Lọc danh mục và báo cáo sản phẩm có thể lẫn dữ liệu shop khác.',
    cause: 'Foreign key có nhưng không kiểm tra business scope shop_id.',
    remediation: 'Chỉ gắn lại danh mục đã xác định cùng shop; bản ghi mơ hồ để xử lý thủ công.',
  },
  {
    code: 'CUSTOMER_MASTER',
    title: 'Khách hàng có mã và tên hợp lệ',
    severity: 'MEDIUM',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM customers WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(c.id::text, ', ' ORDER BY c.id), '') AS evidence
      FROM customers c
      WHERE c.shop_id = $1
        AND (COALESCE(BTRIM(c.code), '') = '' OR COALESCE(BTRIM(c.name), '') = '')
    `,
    risk: 'Lịch sử bán hàng, công nợ và chăm sóc khách hàng mất định danh.',
    cause: 'Import thiếu trường bắt buộc hoặc dữ liệu test placeholder.',
    remediation: 'Bổ sung từ hồ sơ nguồn nếu có; không tự đặt tên thật.',
  },
  {
    code: 'SUPPLIER_MASTER',
    title: 'Nhà cung cấp có mã và tên hợp lệ',
    severity: 'MEDIUM',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM suppliers WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(s.id::text, ', ' ORDER BY s.id), '') AS evidence
      FROM suppliers s
      WHERE s.shop_id = $1
        AND (COALESCE(BTRIM(s.code), '') = '' OR COALESCE(BTRIM(s.name), '') = '')
    `,
    risk: 'Đơn nhập và công nợ nhà cung cấp không thể truy vết đáng tin cậy.',
    cause: 'Import thiếu trường bắt buộc hoặc master chưa hoàn thiện.',
    remediation: 'Bổ sung từ chứng từ nguồn; không tự bịa thông tin nhà cung cấp.',
  },
  {
    code: 'SALES_ORDER_TOTAL',
    title: 'Tổng đơn bán khớp dòng hàng',
    severity: 'CRITICAL',
    confidence: 'HIGH',
    sql: `
      WITH invalid_orders AS (
        SELECT o.id
        FROM sales_orders o
        LEFT JOIN sales_order_items i ON i.order_id = o.id
        WHERE o.shop_id = $1
        GROUP BY o.id
        HAVING ABS(COALESCE(o.subtotal, 0) - COALESCE(SUM(i.subtotal), 0)) > 1
            OR ABS(COALESCE(o.total_amount, 0) - (
              COALESCE(o.subtotal, 0) - COALESCE(o.discount_amount, 0) + COALESCE(o.tax_amount, 0)
            )) > 1
      )
      SELECT
        (SELECT COUNT(*) FROM sales_orders WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(id::text, ', ' ORDER BY id), '') AS evidence
      FROM invalid_orders
    `,
    risk: 'Doanh thu, VAT, giá vốn và báo cáo bán hàng sai.',
    cause: 'Header và dòng hàng được ghi từ hai nguồn hoặc chiết khấu chưa phân bổ.',
    remediation: 'Chỉ đồng bộ từ chứng từ nguồn khi liên kết và công thức xác định chắc chắn.',
  },
  {
    code: 'SALES_ORDER_PAYMENT',
    title: 'Thanh toán đơn bán khớp paid_amount',
    severity: 'CRITICAL',
    confidence: 'HIGH',
    sql: `
      WITH invalid_orders AS (
        SELECT o.id
        FROM sales_orders o
        LEFT JOIN sales_order_payments p ON p.order_id = o.id AND p.shop_id = $1
        WHERE o.shop_id = $1
          AND UPPER(COALESCE(o.status, '')) <> 'CANCELLED'
        GROUP BY o.id
        HAVING o.paid_amount < 0
            OR o.paid_amount > o.total_amount
            OR ABS(COALESCE(o.paid_amount, 0) - COALESCE(SUM(p.amount), 0)) > 1
      )
      SELECT
        (SELECT COUNT(*) FROM sales_orders WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(id::text, ', ' ORDER BY id), '') AS evidence
      FROM invalid_orders
    `,
    risk: 'Công nợ, dòng tiền và trạng thái thanh toán bị sai.',
    cause: 'Payment thiếu/trùng, hoặc header được cập nhật không cùng transaction.',
    remediation: 'Đối chiếu payment theo order_id; không tự xóa payment trùng khi chưa có chứng từ.',
  },
  {
    code: 'SALES_ITEM_SCOPE',
    title: 'Dòng bán tham chiếu đúng order và product cùng shop',
    severity: 'CRITICAL',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM sales_order_items i JOIN sales_orders o ON o.id = i.order_id WHERE o.shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(i.id::text, ', ' ORDER BY i.id), '') AS evidence
      FROM sales_order_items i
      JOIN sales_orders o ON o.id = i.order_id
      LEFT JOIN products p ON p.id = i.product_id
      WHERE o.shop_id = $1
        AND (i.shop_id IS DISTINCT FROM $1 OR p.shop_id IS DISTINCT FROM $1 OR i.quantity <= 0)
    `,
    risk: 'Doanh thu và xuất kho có thể lấy sản phẩm/dữ liệu của shop khác.',
    cause: 'Thiếu kiểm tra scope ở tầng ghi hoặc import trực tiếp.',
    remediation: 'Khoanh vùng bản ghi và sửa bằng khóa liên kết chính xác; không đổi product_id theo tên.',
  },
  {
    code: 'PURCHASE_ORDER_TOTAL',
    title: 'Tổng đơn nhập khớp dòng hàng',
    severity: 'CRITICAL',
    confidence: 'HIGH',
    sql: `
      WITH invalid_orders AS (
        SELECT o.id
        FROM purchase_orders o
        LEFT JOIN purchase_order_items i ON i.order_id = o.id
        WHERE o.shop_id = $1
        GROUP BY o.id
        HAVING COUNT(i.id) = 0
            OR COUNT(i.id) FILTER (WHERE i.quantity <= 0 OR i.unit_price < 0 OR i.subtotal < 0) > 0
            OR ABS(COALESCE(o.subtotal, 0) - COALESCE(SUM(i.subtotal), 0)) > 1
            OR ABS(COALESCE(o.total_amount, 0) - (
              COALESCE(o.subtotal, 0) - COALESCE(o.discount_amount, 0) + COALESCE(o.tax_amount, 0)
            )) > 1
      )
      SELECT
        (SELECT COUNT(*) FROM purchase_orders WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(id::text, ', ' ORDER BY id), '') AS evidence
      FROM invalid_orders
    `,
    risk: 'Giá vốn, tồn kho và công nợ phải trả có thể bị tính sai.',
    cause: 'Header đơn nhập khác dòng hàng hoặc có dòng số lượng/giá trị không hợp lệ.',
    remediation: 'Đối chiếu purchase order với item và hóa đơn nguồn; không tự sửa khi thiếu chứng từ.',
  },
  {
    code: 'PURCHASE_ITEM_SCOPE',
    title: 'Dòng nhập tham chiếu sản phẩm cùng shop',
    severity: 'CRITICAL',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM purchase_order_items i JOIN purchase_orders o ON o.id = i.order_id WHERE o.shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(i.id::text, ', ' ORDER BY i.id), '') AS evidence
      FROM purchase_order_items i
      JOIN purchase_orders o ON o.id = i.order_id
      LEFT JOIN products p ON p.id = i.product_id
      WHERE o.shop_id = $1
        AND (p.id IS NULL OR p.shop_id IS DISTINCT FROM $1)
    `,
    risk: 'Nhập kho có thể ghi nhầm sản phẩm của cửa hàng khác.',
    cause: 'Dòng nhập không kiểm tra business scope của sản phẩm.',
    remediation: 'Đối chiếu theo product_id và chứng từ nhập; không đổi theo tên sản phẩm.',
  },
  {
    code: 'PURCHASE_ITEM_VALUES',
    title: 'Dòng nhập có số lượng và giá trị hợp lệ',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM purchase_order_items i JOIN purchase_orders o ON o.id = i.order_id WHERE o.shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(i.id::text, ', ' ORDER BY i.id), '') AS evidence
      FROM purchase_order_items i
      JOIN purchase_orders o ON o.id = i.order_id
      WHERE o.shop_id = $1
        AND (i.quantity <= 0 OR i.unit_price < 0 OR i.subtotal < 0)
    `,
    risk: 'Tồn và giá vốn có thể chứa dòng rỗng hoặc giá trị bất hợp lệ.',
    cause: 'Bộ sinh/import tạo dòng quantity bằng 0 hoặc không validate miền giá trị.',
    remediation: 'Đối chiếu chứng từ nhập; chỉ loại bỏ dòng rỗng khi có phê duyệt và lưu audit.',
  },
  {
    code: 'PAYMENT_SCOPE',
    title: 'Payment tham chiếu đúng đơn cùng shop',
    severity: 'CRITICAL',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM sales_order_payments WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(p.id::text, ', ' ORDER BY p.id), '') AS evidence
      FROM sales_order_payments p
      LEFT JOIN sales_orders o ON o.id = p.order_id
      WHERE p.shop_id = $1 AND (o.id IS NULL OR o.shop_id IS DISTINCT FROM $1 OR p.amount <= 0)
    `,
    risk: 'Tiền thu có thể được ghi vào nhầm cửa hàng hoặc nhầm đơn.',
    cause: 'Payment không được validate cùng shop_id với order.',
    remediation: 'Đưa bản ghi vào repair queue; không tự gán lại order_id.',
  },
  {
    code: 'RECEIVABLE_INTEGRITY',
    title: 'Công nợ phải thu hợp lệ và không vượt số tiền gốc',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM receivables WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(r.id::text, ', ' ORDER BY r.id), '') AS evidence
      FROM receivables r
      LEFT JOIN customers c ON c.id = r.customer_id
      LEFT JOIN sales_orders o ON o.id = r.order_id
      WHERE r.shop_id = $1
        AND (
          r.amount <= 0 OR r.paid_amount < 0 OR r.paid_amount > r.amount
          OR c.id IS NULL OR c.shop_id IS DISTINCT FROM $1
          OR (r.order_id IS NOT NULL AND (o.id IS NULL OR o.shop_id IS DISTINCT FROM $1))
        )
    `,
    risk: 'Sổ nợ và số dư khách hàng không phản ánh khoản phải thu thật.',
    cause: 'Công nợ mồ côi, thu vượt hoặc liên kết chéo shop.',
    remediation: 'Đối chiếu từng receivable với đơn và payment; không tự giảm số dư.',
  },
  {
    code: 'RECEIVABLE_BALANCE',
    title: 'Số dư khách hàng khớp công nợ mở',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM customers WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(c.id::text, ', ' ORDER BY c.id), '') AS evidence
      FROM customers c
      LEFT JOIN (
        SELECT customer_id, SUM(GREATEST(amount - paid_amount, 0)) AS remaining
        FROM receivables
        WHERE shop_id = $1 AND status NOT IN ('PAID', 'CANCELLED')
        GROUP BY customer_id
      ) r ON r.customer_id = c.id
      WHERE c.shop_id = $1
        AND ABS(COALESCE(c.balance, 0) - COALESCE(r.remaining, 0)) > 1
    `,
    risk: 'KPI công nợ và số dư khách hàng hiển thị khác nhau.',
    cause: 'Cache balance cập nhật không cùng transaction với receivable.',
    remediation: 'Tính lại từ receivable đã xác minh và ghi audit thay đổi.',
  },
  {
    code: 'DEBT_PAYMENT_SCOPE',
    title: 'Lịch sử thu nợ tham chiếu đúng công nợ cùng shop',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM debt_payment_history WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(h.id::text, ', ' ORDER BY h.id), '') AS evidence
      FROM debt_payment_history h
      LEFT JOIN receivables r ON r.id = h.receivable_id
      LEFT JOIN payables p ON p.id = h.payable_id
      WHERE h.shop_id = $1
        AND (
          h.amount <= 0
          OR (h.receivable_id IS NULL AND h.payable_id IS NULL)
          OR (h.receivable_id IS NOT NULL AND (r.id IS NULL OR r.shop_id IS DISTINCT FROM $1))
          OR (h.payable_id IS NOT NULL AND (p.id IS NULL OR p.shop_id IS DISTINCT FROM $1))
        )
    `,
    risk: 'Thu nợ/chi trả có thể làm sai số dư và nhật ký của cửa hàng.',
    cause: 'Lịch sử thanh toán mồ côi hoặc ghi nhầm shop_id.',
    remediation: 'Đối chiếu với chứng từ thu/chi và công nợ gốc; không tự gán lại khóa liên kết.',
  },
  {
    code: 'PAYABLE_INTEGRITY',
    title: 'Công nợ phải trả hợp lệ',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM payables WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(p.id::text, ', ' ORDER BY p.id), '') AS evidence
      FROM payables p
      LEFT JOIN suppliers s ON s.id = p.supplier_id
      LEFT JOIN purchase_orders po ON po.id = p.purchase_order_id
      WHERE p.shop_id = $1
        AND (
          p.amount <= 0 OR p.paid_amount < 0 OR p.paid_amount > p.amount
          OR s.id IS NULL OR s.shop_id IS DISTINCT FROM $1
          OR (p.purchase_order_id IS NOT NULL AND (po.id IS NULL OR po.shop_id IS DISTINCT FROM $1))
        )
    `,
    risk: 'Sổ phải trả và dòng tiền chi cho nhà cung cấp bị sai.',
    cause: 'Payable mồ côi, thu vượt hoặc liên kết chéo shop.',
    remediation: 'Đối chiếu payable với purchase order và lịch sử thanh toán.',
  },
  {
    code: 'INVENTORY_SCOPE',
    title: 'Tồn kho tham chiếu đúng sản phẩm và kho',
    severity: 'CRITICAL',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM inventory_stocks WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(s.id::text, ', ' ORDER BY s.id), '') AS evidence
      FROM inventory_stocks s
      LEFT JOIN products p ON p.id = s.product_id
      LEFT JOIN warehouses w ON w.id = s.warehouse_id
      WHERE s.shop_id = $1
        AND (s.quantity < 0 OR p.id IS NULL OR p.shop_id IS DISTINCT FROM $1
          OR w.id IS NULL OR w.shop_id IS DISTINCT FROM $1)
    `,
    risk: 'Tồn và giá trị tồn có thể bị cộng chéo shop hoặc âm.',
    cause: 'Cập nhật tồn không kiểm tra product/warehouse scope.',
    remediation: 'Khóa bản ghi lỗi và đối chiếu inventory_movements trước khi sửa.',
  },
  {
    code: 'INVENTORY_MOVEMENT_SCOPE',
    title: 'Biến động kho có sản phẩm và kho cùng shop',
    severity: 'CRITICAL',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM inventory_movements WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(m.id::text, ', ' ORDER BY m.id), '') AS evidence
      FROM inventory_movements m
      LEFT JOIN products p ON p.id = m.product_id
      LEFT JOIN warehouses w ON w.id = m.warehouse_id
      WHERE m.shop_id = $1
        AND (p.id IS NULL OR p.shop_id IS DISTINCT FROM $1
          OR w.id IS NULL OR w.shop_id IS DISTINCT FROM $1)
    `,
    risk: 'Tồn cuối kỳ có thể lấy nhầm sản phẩm hoặc kho của cửa hàng khác.',
    cause: 'Movement không kiểm tra business scope của product/warehouse.',
    remediation: 'Đối chiếu movement với chứng từ nguồn; không đổi khóa liên kết theo tên.',
  },
  {
    code: 'INVENTORY_MOVEMENT_VALUES',
    title: 'Biến động kho có loại và số lượng hợp lệ',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM inventory_movements WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(m.id::text, ', ' ORDER BY m.id), '') AS evidence
      FROM inventory_movements m
      WHERE m.shop_id = $1
        AND (m.quantity <= 0
          OR UPPER(COALESCE(m.movement_type, '')) NOT IN ('IN', 'OUT', 'RETURN', 'ADJUSTMENT'))
    `,
    risk: 'Lịch sử nhập/xuất có thể tạo tồn sai hoặc không thể truy nguyên.',
    cause: 'Movement có quantity bằng 0/âm hoặc loại nghiệp vụ ngoài miền cho phép.',
    remediation: 'Đối chiếu movement với chứng từ nguồn; không tự bù hoặc xóa số lượng.',
  },
  {
    code: 'STOCK_TAKE_INTEGRITY',
    title: 'Kiểm kê hoàn tất có dòng và chênh lệch đúng công thức',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      WITH invalid_takes AS (
        SELECT s.id
        FROM stock_takes s
        LEFT JOIN stock_take_items i ON i.stock_take_id = s.id
        LEFT JOIN products p ON p.id = i.product_id
        LEFT JOIN warehouses w ON w.id = s.warehouse_id
        WHERE s.shop_id = $1
          AND UPPER(COALESCE(s.status, '')) NOT IN ('DRAFT', 'CANCELLED')
        GROUP BY s.id, s.warehouse_id, w.id, w.shop_id
        HAVING COUNT(i.id) = 0
            OR COUNT(i.id) FILTER (WHERE i.system_qty < 0 OR i.actual_qty < 0 OR i.difference <> i.actual_qty - i.system_qty) > 0
            OR COUNT(i.id) FILTER (WHERE p.id IS NULL OR p.shop_id IS DISTINCT FROM $1) > 0
            OR (s.warehouse_id IS NOT NULL AND (w.id IS NULL OR w.shop_id IS DISTINCT FROM $1))
      )
      SELECT
        (SELECT COUNT(*) FROM stock_takes WHERE shop_id = $1 AND UPPER(COALESCE(status, '')) NOT IN ('DRAFT', 'CANCELLED'))::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(id::text, ', ' ORDER BY id), '') AS evidence
      FROM invalid_takes
    `,
    risk: 'Chênh lệch kiểm kê có thể làm sai điều chỉnh tồn và giá vốn.',
    cause: 'Phiếu kiểm kê hoàn tất thiếu dòng hoặc không tính difference từ system/actual.',
    remediation: 'Đối chiếu biên bản kiểm kê thực tế trước khi điều chỉnh tồn; không tự thêm dòng.',
  },
  {
    code: 'INVENTORY_DUPLICATE_GRAIN',
    title: 'Tồn không trùng theo shop/kho/sản phẩm',
    severity: 'CRITICAL',
    confidence: 'HIGH',
    sql: `
      WITH duplicate_grain AS (
        SELECT product_id, warehouse_id
        FROM inventory_stocks
        WHERE shop_id = $1
        GROUP BY product_id, warehouse_id
        HAVING COUNT(*) > 1
      )
      SELECT
        (SELECT COUNT(*) FROM inventory_stocks WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(CONCAT(product_id, '/', warehouse_id), ', ' ORDER BY product_id, warehouse_id), '') AS evidence
      FROM duplicate_grain
    `,
    risk: 'Báo cáo tồn và cảnh báo dưới định mức có thể cộng trùng.',
    cause: 'Thiếu unique composite hoặc race condition khi upsert.',
    remediation: 'Hợp nhất có đối soát rồi mới bổ sung constraint; không tự xóa dòng.',
  },
  {
    code: 'INVENTORY_RECONCILIATION',
    title: 'Tồn hiện tại khớp nhập/xuất/trả',
    severity: 'CRITICAL',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(DISTINCT product_id || ':' || warehouse_id) FROM inventory_movements WHERE shop_id = $1)::int AS population,
        COUNT(*) FILTER (WHERE ABS(COALESCE(s.quantity, 0) - COALESCE(m.movement_quantity, 0)) > 0.001)::int AS violations,
        COALESCE(string_agg(CONCAT(COALESCE(s.product_id, m.product_id), '/', COALESCE(s.warehouse_id, m.warehouse_id), '=', COALESCE(s.quantity, 0), '/', COALESCE(m.movement_quantity, 0)), ', '), '') AS evidence
      FROM (
        SELECT product_id, warehouse_id, SUM(quantity) AS quantity
        FROM inventory_stocks WHERE shop_id = $1 GROUP BY product_id, warehouse_id
      ) s
      FULL JOIN (
        SELECT product_id, warehouse_id,
          SUM(CASE WHEN movement_type IN ('IN', 'RETURN') THEN quantity
                   WHEN movement_type = 'OUT' THEN -quantity ELSE quantity END) AS movement_quantity
        FROM inventory_movements WHERE shop_id = $1 GROUP BY product_id, warehouse_id
      ) m ON m.product_id = s.product_id AND m.warehouse_id = s.warehouse_id
    `,
    risk: 'Số tồn cuối kỳ không có căn cứ từ lịch sử nhập–xuất.',
    cause: 'Thiếu movement, sai loại movement hoặc cập nhật stock trực tiếp.',
    remediation: 'Đối chiếu theo product/warehouse và chỉ sửa từ chứng từ gốc.',
  },
  {
    code: 'LOT_STOCK_RECONCILIATION',
    title: 'Tồn tổng khớp tồn theo lô',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(DISTINCT product_id) FROM inventory_stocks WHERE shop_id = $1)::int AS population,
        COUNT(*) FILTER (WHERE ABS(COALESCE(s.quantity, 0) - COALESCE(l.quantity, 0)) > 0.001)::int AS violations,
        COALESCE(string_agg(CONCAT(COALESCE(s.product_id, l.product_id), '=', COALESCE(s.quantity, 0), '/', COALESCE(l.quantity, 0)), ', '), '') AS evidence
      FROM (
        SELECT product_id, SUM(quantity) AS quantity
        FROM inventory_stocks WHERE shop_id = $1 GROUP BY product_id
      ) s
      FULL JOIN (
        SELECT product_id, SUM(remaining_qty) AS quantity
        FROM inventory_lots WHERE shop_id = $1 GROUP BY product_id
      ) l ON l.product_id = s.product_id
    `,
    risk: 'Xuất bán theo lô và giá vốn bình quân có thể sai.',
    cause: 'Số dư lô không được cập nhật cùng tồn master.',
    remediation: 'Đối chiếu lot với purchase/movement; không bù số dư bằng tay.',
  },
  {
    code: 'COGS_RECONCILIATION',
    title: 'Giá vốn header khớp dòng bán',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      WITH invalid_orders AS (
        SELECT o.id
        FROM sales_orders o
        JOIN sales_order_items i ON i.order_id = o.id
        WHERE o.shop_id = $1 AND UPPER(COALESCE(o.status, '')) <> 'CANCELLED'
        GROUP BY o.id, o.total_cogs
        HAVING ABS(COALESCE(o.total_cogs, 0) - COALESCE(SUM(i.quantity * i.cost_price), 0)) > 1
            OR COUNT(*) FILTER (WHERE i.quantity > 0 AND COALESCE(i.cost_price, 0) <= 0) > 0
      )
      SELECT
        (SELECT COUNT(*) FROM sales_orders WHERE shop_id = $1 AND UPPER(COALESCE(status, '')) <> 'CANCELLED')::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(id::text, ', ' ORDER BY id), '') AS evidence
      FROM invalid_orders
    `,
    risk: 'Lợi nhuận gộp và tài khoản 632 bị sai.',
    cause: 'Cost snapshot thiếu hoặc khác công thức header.',
    remediation: 'Đối chiếu purchase/lot; không lấy lại giá vốn hiện tại thay cho snapshot lịch sử.',
  },
  {
    code: 'JOURNAL_BALANCE',
    title: 'Mọi bút toán chưa void cân bằng Nợ/Có',
    severity: 'CRITICAL',
    confidence: 'HIGH',
    sql: `
      WITH invalid_entries AS (
        SELECT e.id
        FROM journal_entries e
        LEFT JOIN journal_lines l ON l.journal_entry_id = e.id
        WHERE e.shop_id = $1 AND e.is_voided = false
        GROUP BY e.id
        HAVING ABS(COALESCE(SUM(CASE WHEN l.entry_type = 'DEBIT' THEN l.amount ELSE 0 END), 0)
                   - COALESCE(SUM(CASE WHEN l.entry_type = 'CREDIT' THEN l.amount ELSE 0 END), 0)) > 1
            OR COUNT(l.id) < 2
      )
      SELECT
        (SELECT COUNT(*) FROM journal_entries WHERE shop_id = $1 AND is_voided = false)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(id::text, ', ' ORDER BY id), '') AS evidence
      FROM invalid_entries
    `,
    risk: 'Sổ kép không đáng tin cậy và báo cáo tài chính có thể sai.',
    cause: 'Ghi journal thiếu dòng hoặc cập nhật một phần.',
    remediation: 'Rollback/rebuild từ chứng từ nguồn trong transaction; không tự thêm dòng cân bằng.',
  },
  {
    code: 'CASH_TRANSACTION_INTEGRITY',
    title: 'Giao dịch tiền có tài khoản và giá trị hợp lệ',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM cash_transactions WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(t.id::text, ', ' ORDER BY t.id), '') AS evidence
      FROM cash_transactions t
      LEFT JOIN cash_accounts a ON a.id = t.account_id
      WHERE t.shop_id = $1
        AND (
          t.amount <= 0
          OR UPPER(COALESCE(t.type, '')) NOT IN ('INCOME', 'EXPENSE')
          OR a.id IS NULL OR a.shop_id IS DISTINCT FROM $1
        )
    `,
    risk: 'Dòng tiền có thể không được phản ánh vào tài khoản tiền của shop.',
    cause: 'Giao dịch thiếu account_id, sai scope hoặc giá trị không hợp lệ.',
    remediation: 'Đối chiếu chứng từ thu/chi và tài khoản 111/112; không tự gán tài khoản.',
  },
  {
    code: 'CASH_ACCOUNT_BALANCE',
    title: 'Số dư tài khoản tiền khớp giao dịch',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM cash_accounts WHERE shop_id = $1)::int AS population,
        COUNT(*) FILTER (WHERE ABS(COALESCE(a.balance, 0) - COALESCE(t.expected_balance, 0)) > 1)::int AS violations,
        COALESCE(string_agg(a.id::text, ', ') FILTER (WHERE ABS(COALESCE(a.balance, 0) - COALESCE(t.expected_balance, 0)) > 1), '') AS evidence
      FROM cash_accounts a
      LEFT JOIN (
        SELECT account_id, SUM(CASE WHEN type = 'INCOME' THEN amount ELSE -amount END) AS expected_balance
        FROM cash_transactions WHERE shop_id = $1 GROUP BY account_id
      ) t ON t.account_id = a.id
      WHERE a.shop_id = $1
    `,
    risk: 'Dòng tiền và số dư tiền mặt/ngân hàng không khớp.',
    cause: 'Cash account balance là cache và không được cập nhật cùng transaction.',
    remediation: 'Tính lại từ giao dịch đã xác minh; ghi before/after vào audit log.',
  },
  {
    code: 'DAILY_CLOSING_CONTINUITY',
    title: 'Chốt quỹ liên tục giữa các ngày',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      WITH ordered AS (
        SELECT closing_date, opening_cash, LAG(closing_cash) OVER (ORDER BY closing_date) AS previous_closing
        FROM daily_closings WHERE shop_id = $1
      )
      SELECT
        (SELECT COUNT(*) FROM daily_closings WHERE shop_id = $1)::int AS population,
        COUNT(*) FILTER (WHERE previous_closing IS NOT NULL AND ABS(opening_cash - previous_closing) > 1)::int AS violations,
        COALESCE(string_agg(closing_date::text, ', ' ORDER BY closing_date) FILTER (WHERE previous_closing IS NOT NULL AND ABS(opening_cash - previous_closing) > 1), '') AS evidence
      FROM ordered
    `,
    risk: 'Số dư tiền mặt cuối ngày không nối được với ngày kế tiếp.',
    cause: 'Chốt quỹ được tạo riêng lẻ hoặc giao dịch bị backfill sau chốt.',
    remediation: 'Đối soát theo ngày nghiệp vụ Việt Nam; không tự sửa closing_cash nếu thiếu chứng từ.',
  },
  {
    code: 'RETURN_INTEGRITY',
    title: 'Hoàn hàng có dòng và không vượt số đã bán',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      WITH invalid_returns AS (
        SELECT r.id
        FROM sales_returns r
        LEFT JOIN sales_return_items ri ON ri.return_id = r.id
        LEFT JOIN sales_orders o ON o.id = r.order_id
        WHERE r.shop_id = $1
          AND UPPER(COALESCE(r.status, '')) NOT IN ('CANCELLED', 'REJECTED')
        GROUP BY r.id, o.id, o.shop_id
        HAVING COUNT(ri.id) = 0
            OR o.id IS NULL OR o.shop_id IS DISTINCT FROM $1
            OR EXISTS (
              SELECT 1
              FROM sales_return_items returned
              LEFT JOIN sales_order_items sold
                ON sold.order_id = r.order_id AND sold.product_id = returned.product_id
              WHERE returned.return_id = r.id
              GROUP BY returned.product_id
              HAVING SUM(returned.quantity) > COALESCE(SUM(sold.quantity), 0)
            )
      )
      SELECT
        (SELECT COUNT(*) FROM sales_returns WHERE shop_id = $1 AND UPPER(COALESCE(status, '')) NOT IN ('CANCELLED', 'REJECTED'))::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(id::text, ', ' ORDER BY id), '') AS evidence
      FROM invalid_returns
    `,
    risk: 'Đảo doanh thu, giá vốn và tồn kho không chính xác.',
    cause: 'Phiếu hoàn thiếu dòng hoặc không ràng buộc theo số lượng đã bán.',
    remediation: 'Đối chiếu từng dòng hoàn với order item; không tự giảm số lượng hoàn.',
  },
  {
    code: 'INVOICE_ITEMS',
    title: 'Hóa đơn có dòng và tổng tiền tự đối soát',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      WITH invalid_invoices AS (
        SELECT i.id
        FROM invoices i
        LEFT JOIN invoice_items ii ON ii.invoice_id = i.id
        LEFT JOIN products p ON p.id = ii.product_id
        WHERE i.shop_id = $1
        GROUP BY i.id
        HAVING COUNT(ii.id) = 0
            OR COUNT(ii.id) FILTER (WHERE ii.quantity <= 0 OR ii.unit_price < 0 OR ii.subtotal < 0) > 0
            OR COUNT(ii.id) FILTER (WHERE ii.product_id IS NOT NULL AND (
              p.id IS NULL OR p.shop_id IS DISTINCT FROM $1
            )) > 0
            OR ABS(COALESCE(i.subtotal, 0) - COALESCE(SUM(ii.subtotal), 0)) > 1
            OR ABS(COALESCE(i.tax_amount, 0) - COALESCE(SUM(ii.tax_amount), 0)) > 1
            OR ABS(COALESCE(i.total_amount, 0) - (
              COALESCE(i.subtotal, 0) - COALESCE(i.discount_amount, 0) + COALESCE(i.tax_amount, 0)
            )) > 1
      )
      SELECT
        (SELECT COUNT(*) FROM invoices WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(id::text, ', ' ORDER BY id), '') AS evidence
      FROM invalid_invoices
    `,
    risk: 'Drill-down, xuất hóa đơn và báo cáo thuế không có căn cứ độc lập.',
    cause: 'Header hóa đơn được import thiếu item hoặc thiếu discount_amount.',
    remediation: 'Chỉ backfill từ order cùng shop khi item/source subtotal xác định được.',
  },
  {
    code: 'INVOICE_SOURCE_SCOPE',
    title: 'Hóa đơn tham chiếu đúng chứng từ cùng shop',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM invoices WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(i.id::text, ', ' ORDER BY i.id), '') AS evidence
      FROM invoices i
      LEFT JOIN sales_orders so
        ON i.reference_type = 'SALES_ORDER' AND so.id = i.reference_id
      LEFT JOIN purchase_orders po
        ON i.reference_type = 'PURCHASE_ORDER' AND po.id = i.reference_id
      WHERE i.shop_id = $1
        AND (
          (i.reference_type = 'SALES_ORDER' AND (so.id IS NULL OR so.shop_id IS DISTINCT FROM $1))
          OR (i.reference_type = 'PURCHASE_ORDER' AND (po.id IS NULL OR po.shop_id IS DISTINCT FROM $1))
        )
    `,
    risk: 'Hóa đơn có thể lấy nhầm doanh thu/chi phí của cửa hàng khác.',
    cause: 'Reference id được ghi mà không kiểm tra shop_id của chứng từ nguồn.',
    remediation: 'Đưa vào repair queue; không đổi reference_id theo tên hoặc ngày.',
  },
  {
    code: 'PURCHASE_WITHOUT_INVOICE',
    title: 'Bảng kê mua không hóa đơn có dòng và số lượng hợp lệ',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      WITH invalid_documents AS (
        SELECT p.id
        FROM purchases_without_invoice p
        LEFT JOIN purchase_without_invoice_items i ON i.purchase_id = p.id
        WHERE p.shop_id = $1
        GROUP BY p.id
        HAVING COUNT(i.id) = 0
            OR COUNT(i.id) FILTER (WHERE i.quantity <= 0 OR i.unit_price < 0 OR i.subtotal < 0) > 0
            OR ABS(COALESCE(p.total_amount, 0) - COALESCE(SUM(i.subtotal), 0)) > 1
      )
      SELECT
        (SELECT COUNT(*) FROM purchases_without_invoice WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(id::text, ', ' ORDER BY id), '') AS evidence
      FROM invalid_documents
    `,
    risk: 'Tổng mua, tồn và báo cáo thuế từ hàng không hóa đơn bị sai.',
    cause: 'Dòng chứng từ thiếu hoặc quantity bằng 0/giá trị âm.',
    remediation: 'Chỉ sửa từ phiếu mua gốc; bản ghi không đủ nguồn phải giữ trạng thái cần xử lý.',
  },
  {
    code: 'TAX_OBLIGATION',
    title: 'Nghĩa vụ thuế không âm và không nộp vượt khai báo',
    severity: 'HIGH',
    confidence: 'HIGH',
    sql: `
      SELECT
        (SELECT COUNT(*) FROM tax_obligations WHERE shop_id = $1)::int AS population,
        COUNT(*)::int AS violations,
        COALESCE(string_agg(id::text, ', ' ORDER BY id), '') AS evidence
      FROM tax_obligations
      WHERE shop_id = $1
        AND (
          vat_declared < 0 OR pit_declared < 0 OR vat_paid < 0 OR pit_paid < 0
          OR vat_paid > vat_declared OR pit_paid > pit_declared
        )
    `,
    risk: 'KPI và trạng thái nghĩa vụ thuế hiển thị không hợp lệ.',
    cause: 'Import hoặc cập nhật obligation không kiểm tra miền giá trị.',
    remediation: 'Đối chiếu từ kỳ khai báo và payment; không tự suy đoán quy định pháp lý.',
  },
  {
    code: 'CORE_SHOP_SCOPE',
    title: 'Bảng nghiệp vụ lõi không có shop_id null',
    severity: 'CRITICAL',
    confidence: 'HIGH',
    sql: `
      SELECT
        1 AS population,
        CASE WHEN (
          SELECT COUNT(*) FROM products WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM customers WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM suppliers WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM sales_orders WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM sales_order_items WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM inventory_stocks WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM inventory_movements WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM cash_transactions WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM invoices WHERE shop_id IS NULL
        ) > 0 THEN 1 ELSE 0 END AS violations,
        ((
          SELECT COUNT(*) FROM products WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM customers WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM suppliers WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM sales_orders WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM sales_order_items WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM inventory_stocks WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM inventory_movements WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM cash_transactions WHERE shop_id IS NULL
        ) + (
          SELECT COUNT(*) FROM invoices WHERE shop_id IS NULL
        ))::text AS evidence
    `,
    risk: 'Query tổng hợp có thể rò dữ liệu hoặc không truy vết được shop.',
    cause: 'Dữ liệu legacy không có scope hoặc import thiếu shop_id.',
    remediation: 'Không tự gán shop_id; cần mapping được phê duyệt.',
  },
  {
    code: 'FUTURE_DATED',
    title: 'Không có dữ liệu nghiệp vụ sau mốc kiểm tra',
    severity: 'MEDIUM',
    confidence: 'HIGH',
    sql: `
      SELECT
        (
          SELECT COUNT(*) FROM sales_orders WHERE shop_id = $1 AND order_date::date > $2::date
        ) + (
          SELECT COUNT(*) FROM invoices WHERE shop_id = $1 AND invoice_date > $2::date
        ) + (
          SELECT COUNT(*) FROM cash_transactions WHERE shop_id = $1 AND transaction_date > $2::date
        ) + (
          SELECT COUNT(*) FROM daily_closings WHERE shop_id = $1 AND closing_date > $2::date
        ) AS population,
        (
          SELECT COUNT(*) FROM sales_orders WHERE shop_id = $1 AND order_date::date > $2::date
        ) + (
          SELECT COUNT(*) FROM invoices WHERE shop_id = $1 AND invoice_date > $2::date
        ) + (
          SELECT COUNT(*) FROM cash_transactions WHERE shop_id = $1 AND transaction_date > $2::date
        ) + (
          SELECT COUNT(*) FROM daily_closings WHERE shop_id = $1 AND closing_date > $2::date
        ) AS violations,
        $2::text AS evidence
    `,
    risk: 'Báo cáo tại mốc kiểm tra bị nhiễm dữ liệu tương lai.',
    cause: 'Seed/extension chạy vượt cutoff hoặc timezone không thống nhất.',
    remediation: 'Khoanh bản ghi tương lai; không xóa nếu chưa xác định nguồn tạo.',
  },
];

async function queryOne<T>(sql: string, params: unknown[]): Promise<T> {
  const rows = await AppDataSource.query(sql, params) as T[];
  return rows[0] ?? ({} as T);
}

async function loadCoverage(shopId: number): Promise<CoverageRow> {
  return queryOne<CoverageRow>(`
    SELECT
      (SELECT COUNT(*)::int FROM products WHERE shop_id = $1) AS products,
      (SELECT COUNT(*)::int FROM categories WHERE shop_id = $1) AS categories,
      (SELECT COUNT(*)::int FROM tags WHERE shop_id = $1) AS tags,
      (SELECT COUNT(*)::int FROM cost_types WHERE shop_id = $1) AS costTypes,
      (SELECT COUNT(*)::int FROM product_cost_items WHERE shop_id = $1) AS productCostItems,
      (SELECT COUNT(*)::int FROM unit_conversions WHERE shop_id = $1) AS unitConversions,
      (SELECT COUNT(*)::int FROM product_price_history WHERE shop_id = $1) AS priceHistory,
      (SELECT COUNT(*)::int FROM product_batches WHERE shop_id = $1) AS productBatches,
      (SELECT COUNT(*)::int FROM inventory_lots WHERE shop_id = $1) AS inventoryLots,
      (SELECT COUNT(*)::int FROM stock_takes WHERE shop_id = $1) AS stockTakes,
      (SELECT COUNT(*)::int FROM purchase_orders WHERE shop_id = $1) AS purchaseOrders,
      (SELECT COUNT(*)::int FROM sales_orders WHERE shop_id = $1) AS salesOrders,
      (SELECT COUNT(*)::int FROM sales_returns WHERE shop_id = $1) AS salesReturns,
      (SELECT COUNT(*)::int FROM receivables WHERE shop_id = $1) AS receivables,
      (SELECT COUNT(*)::int FROM debt_evidences WHERE shop_id = $1) AS debtEvidences,
      (SELECT COUNT(*)::int FROM suppliers WHERE shop_id = $1) AS suppliers,
      (SELECT COUNT(*)::int FROM payables WHERE shop_id = $1) AS payables,
      (SELECT COUNT(*)::int FROM cash_transactions WHERE shop_id = $1) AS cashTransactions,
      (SELECT COUNT(*)::int FROM financial_ledger WHERE shop_id = $1) AS financialLedger,
      (SELECT COUNT(*)::int FROM journal_entries WHERE shop_id = $1) AS journalEntries,
      (SELECT COUNT(*)::int FROM daily_closings WHERE shop_id = $1) AS dailyClosings,
      (SELECT COUNT(*)::int FROM cashflow_forecasts WHERE shop_id = $1) AS cashflowForecasts,
      (SELECT COUNT(*)::int FROM budget_plans WHERE shop_id = $1) AS budgetPlans,
      (SELECT COUNT(*)::int FROM invoices WHERE shop_id = $1) AS invoices,
      (SELECT COUNT(*)::int FROM invoice_scans WHERE shop_id = $1) AS invoiceScans,
      (SELECT COUNT(*)::int FROM purchases_without_invoice WHERE shop_id = $1) AS purchasesWithoutInvoice,
      (SELECT COUNT(*)::int FROM tax_obligations WHERE shop_id = $1) AS taxObligations,
      (SELECT COUNT(*)::int FROM activity_logs WHERE shop_id = $1) AS activityLogs,
      (SELECT COUNT(*)::int FROM ai_knowledge_documents WHERE shop_id = $1) AS aiKnowledgeDocuments,
      (SELECT COUNT(*)::int FROM notifications n JOIN shop_members sm ON sm.user_id = n.user_id WHERE sm.shop_id = $1) AS notifications
  `, [shopId]);
}

async function loadMetrics(shopId: number, asOf: string): Promise<{
  raw: MetricsRow;
  metrics: ReturnType<typeof normalizeMetrics>;
  paymentMix: Record<string, number>;
  customerTypeMix: Record<string, number>;
  weekdayMix: Record<string, number>;
  monthlyMix: Record<string, number>;
}> {
  const raw = await queryOne<MetricsRow>(`
    SELECT
      (SELECT COUNT(*)::int FROM sales_orders WHERE shop_id = $1 AND order_date::date <= $2::date) AS "totalOrders",
      (SELECT COUNT(*)::int FROM sales_orders WHERE shop_id = $1 AND order_date::date <= $2::date AND UPPER(COALESCE(status, '')) <> 'CANCELLED') AS "validOrders",
      (SELECT COUNT(*)::int FROM sales_orders WHERE shop_id = $1 AND order_date::date <= $2::date AND UPPER(COALESCE(status, '')) = 'CANCELLED') AS "cancelledOrders",
      (SELECT MIN(order_date)::date::text FROM sales_orders WHERE shop_id = $1 AND order_date::date <= $2::date) AS "firstOrder",
      (SELECT MAX(order_date)::date::text FROM sales_orders WHERE shop_id = $1 AND order_date::date <= $2::date) AS "lastOrder",
      (SELECT COUNT(*)::int FROM products WHERE shop_id = $1) AS "totalProducts",
      (SELECT COUNT(*)::int FROM customers WHERE shop_id = $1) AS "totalCustomers",
      (SELECT COUNT(*)::int FROM suppliers WHERE shop_id = $1) AS "totalSuppliers",
      (SELECT COUNT(*)::int FROM invoices WHERE shop_id = $1 AND invoice_date <= $2::date) AS "totalInvoices",
      (SELECT COUNT(*)::int FROM cash_transactions WHERE shop_id = $1 AND transaction_date <= $2::date) AS "totalCashTransactions",
      (SELECT COUNT(*)::int FROM journal_entries WHERE shop_id = $1 AND entry_date::date <= $2::date) AS "totalJournalEntries",
      (SELECT COUNT(*)::int FROM inventory_movements WHERE shop_id = $1 AND created_at::date <= $2::date) AS "totalInventoryMovements",
      (SELECT COUNT(*)::int FROM stock_takes WHERE shop_id = $1 AND stock_take_date <= $2::date) AS "totalStockTakes",
      (SELECT COUNT(*)::int FROM receivables WHERE shop_id = $1 AND created_at::date <= $2::date) AS "totalReceivables",
      (SELECT COUNT(*)::int FROM payables WHERE shop_id = $1 AND created_at::date <= $2::date) AS "totalPayables",
      (SELECT COUNT(*)::int FROM sales_returns WHERE shop_id = $1 AND return_date::date <= $2::date) AS "totalReturns",
      (SELECT COUNT(*)::int FROM invoice_scans WHERE shop_id = $1 AND scanned_at::date <= $2::date) AS "totalInvoiceScans",
      (SELECT COUNT(*)::int FROM debt_evidences WHERE shop_id = $1 AND uploaded_at::date <= $2::date) AS "totalDebtEvidences",
      GREATEST(
        COALESCE((SELECT MAX(order_date)::date FROM sales_orders WHERE shop_id = $1 AND order_date::date <= $2::date), '1900-01-01'::date),
        COALESCE((SELECT MAX(transaction_date) FROM cash_transactions WHERE shop_id = $1 AND transaction_date <= $2::date), '1900-01-01'::date),
        COALESCE((SELECT MAX(closing_date) FROM daily_closings WHERE shop_id = $1 AND closing_date <= $2::date), '1900-01-01'::date)
      )::text AS "latestBusinessDate"
  `, [shopId, asOf]);

  const daily = await queryOne<DailyRow>(`
    WITH daily AS (
      SELECT order_date::date AS day, COUNT(*) FILTER (WHERE UPPER(COALESCE(status, '')) <> 'CANCELLED')::int AS order_count
      FROM sales_orders
      WHERE shop_id = $1 AND order_date::date <= $2::date
      GROUP BY order_date::date
    )
    SELECT
      COUNT(*) FILTER (WHERE order_count > 0)::int AS "activeDays",
      COALESCE((MAX(day) - MIN(day) + 1), 0)::int AS "dateSpanDays",
      COALESCE(percentile_cont(0.5) WITHIN GROUP (ORDER BY order_count) FILTER (WHERE order_count > 0), 0) AS "medianDailyOrders",
      COALESCE(percentile_cont(0.95) WITHIN GROUP (ORDER BY order_count) FILTER (WHERE order_count > 0), 0) AS "p95DailyOrders",
      COALESCE(MAX(order_count), 0)::int AS "maxDailyOrders"
    FROM daily
  `, [shopId, asOf]);

  const customer = await queryOne<{ topShare: string | number }>(`
    WITH revenue AS (
      SELECT customer_id, SUM(total_amount) AS value
      FROM sales_orders
      WHERE shop_id = $1 AND order_date::date <= $2::date AND UPPER(COALESCE(status, '')) <> 'CANCELLED'
      GROUP BY customer_id
    ), ranked AS (
      SELECT value, ROW_NUMBER() OVER (ORDER BY value DESC) AS row_number, COUNT(*) OVER () AS total_customers
      FROM revenue
    )
    SELECT COALESCE(SUM(value) FILTER (WHERE row_number <= GREATEST(1, CEIL(total_customers * 0.2)))
      / NULLIF(SUM(value), 0) * 100, 0) AS "topShare"
    FROM ranked
  `, [shopId, asOf]);

  const product = await queryOne<{ topShare: string | number }>(`
    WITH revenue AS (
      SELECT i.product_id, SUM(i.subtotal) AS value
      FROM sales_order_items i
      JOIN sales_orders o ON o.id = i.order_id
      WHERE o.shop_id = $1 AND o.order_date::date <= $2::date AND UPPER(COALESCE(o.status, '')) <> 'CANCELLED'
      GROUP BY i.product_id
    ), ranked AS (
      SELECT value, ROW_NUMBER() OVER (ORDER BY value DESC) AS row_number, COUNT(*) OVER () AS total_products
      FROM revenue
    )
    SELECT COALESCE(SUM(value) FILTER (WHERE row_number <= GREATEST(1, CEIL(total_products * 0.2)))
      / NULLIF(SUM(value), 0) * 100, 0) AS "topShare"
    FROM ranked
  `, [shopId, asOf]);

  const profileKeywords = shopId === 34
    ? [
      'xi măng', 'gạch', 'thép', 'sắt', 'cát', 'đá', 'sơn', 'ống', 'vòi',
      'thiết bị phòng tắm', 'điện nước', 'vật liệu',
    ]
    : [
      'phân', 'hạt giống', 'giống', 'thuốc', 'bảo vệ thực vật', 'đất',
      'giá thể', 'chậu', 'nông nghiệp', 'vật tư nông nghiệp',
    ];
  const profileMatch = await queryOne<{ matched: string | number; total: string | number }>(`
    SELECT
      COUNT(*) FILTER (WHERE LOWER(CONCAT_WS(' ', p.name, c.name)) ILIKE ANY($2::text[]))::int AS matched,
      COUNT(*)::int AS total
    FROM products p
    LEFT JOIN categories c ON c.id = p.category_id
    WHERE p.shop_id = $1
  `, [shopId, profileKeywords.map((keyword) => `%${keyword}%`)]);

  const payments = await AppDataSource.query(`
    SELECT UPPER(COALESCE(p.method, 'UNKNOWN')) AS method, COALESCE(SUM(p.amount), 0) AS amount
    FROM sales_order_payments p
    JOIN sales_orders o ON o.id = p.order_id
    WHERE p.shop_id = $1 AND o.shop_id = $1 AND o.order_date::date <= $2::date
    GROUP BY UPPER(COALESCE(p.method, 'UNKNOWN'))
    ORDER BY method
  `, [shopId, asOf]) as Array<{ method: string; amount: string | number }>;

  const customerTypes = await AppDataSource.query(`
    SELECT UPPER(COALESCE(c.customer_type, 'UNKNOWN')) AS customer_type,
           COALESCE(SUM(o.total_amount), 0) AS revenue
    FROM sales_orders o
    LEFT JOIN customers c ON c.id = o.customer_id AND c.shop_id = o.shop_id
    WHERE o.shop_id = $1 AND o.order_date::date <= $2::date
      AND UPPER(COALESCE(o.status, '')) <> 'CANCELLED'
    GROUP BY UPPER(COALESCE(c.customer_type, 'UNKNOWN'))
    ORDER BY customer_type
  `, [shopId, asOf]) as Array<{ customer_type: string; revenue: string | number }>;

  const weekdays = await AppDataSource.query(`
    SELECT EXTRACT(ISODOW FROM order_date)::int AS weekday, COUNT(*)::int AS orders
    FROM sales_orders
    WHERE shop_id = $1 AND order_date::date <= $2::date AND UPPER(COALESCE(status, '')) <> 'CANCELLED'
    GROUP BY EXTRACT(ISODOW FROM order_date)::int
    ORDER BY weekday
  `, [shopId, asOf]) as Array<{ weekday: string | number; orders: string | number }>;

  const months = await AppDataSource.query(`
    SELECT TO_CHAR(order_date::date, 'YYYY-MM') AS month, COUNT(*)::int AS orders
    FROM sales_orders
    WHERE shop_id = $1 AND order_date::date <= $2::date AND UPPER(COALESCE(status, '')) <> 'CANCELLED'
    GROUP BY TO_CHAR(order_date::date, 'YYYY-MM')
    ORDER BY month
  `, [shopId, asOf]) as Array<{ month: string; orders: string | number }>;

  const totalPayments = payments.reduce((sum, row) => sum + numberValue(row.amount), 0);
  const paymentMix = Object.fromEntries(payments.map((row) => [
    row.method,
    percentage(row.amount, totalPayments),
  ]));
  const totalCustomerRevenue = customerTypes.reduce((sum, row) => sum + numberValue(row.revenue), 0);
  const customerTypeMix = Object.fromEntries(customerTypes.map((row) => [
    row.customer_type,
    percentage(row.revenue, totalCustomerRevenue),
  ]));
  const weekdayMix = Object.fromEntries(weekdays.map((row) => [
    String(row.weekday), numberValue(row.orders),
  ]));
  const monthlyMix = Object.fromEntries(months.map((row) => [
    row.month,
    numberValue(row.orders),
  ]));
  const monthlyValues = months.map((row) => numberValue(row.orders));
  const monthlyMean = monthlyValues.length
    ? monthlyValues.reduce((sum, value) => sum + value, 0) / monthlyValues.length
    : 0;
  const monthlyVariance = monthlyValues.length
    ? monthlyValues.reduce((sum, value) => sum + ((value - monthlyMean) ** 2), 0) / monthlyValues.length
    : 0;
  const metrics = normalizeMetrics({
    ...daily,
    ...raw,
    dailyCoverage: percentage(daily.activeDays, daily.dateSpanDays),
    cancelledOrderRate: percentage(raw.cancelledOrders, raw.totalOrders),
    activeMonths: months.length,
    monthlyOrderCv: monthlyMean > 0 ? (Math.sqrt(monthlyVariance) / monthlyMean) * 100 : 0,
    profileMatchRate: percentage(profileMatch.matched, profileMatch.total),
    creditOrderRate: await scalarPercentage(`
      SELECT COUNT(*) FILTER (WHERE paid_amount < total_amount)::numeric AS part,
             COUNT(*)::numeric AS whole
      FROM sales_orders
      WHERE shop_id = $1 AND order_date::date <= $2::date AND UPPER(COALESCE(status, '')) <> 'CANCELLED'
    `, shopId, asOf),
    returnRate: await scalarPercentage(`
      SELECT COUNT(DISTINCT r.id)::numeric AS part,
             NULLIF(COUNT(DISTINCT o.id), 0)::numeric AS whole
      FROM sales_orders o
      LEFT JOIN sales_returns r
        ON r.order_id = o.id AND r.shop_id = $1
        AND r.return_date::date <= $2::date
        AND UPPER(COALESCE(r.status, '')) NOT IN ('CANCELLED', 'REJECTED')
      WHERE o.shop_id = $1 AND o.order_date::date <= $2::date AND UPPER(COALESCE(o.status, '')) <> 'CANCELLED'
    `, shopId, asOf),
    cashPaymentRate: percentage(
      payments.filter((row) => row.method === 'CASH').reduce((sum, row) => sum + numberValue(row.amount), 0),
      totalPayments,
    ),
    invoiceCoverage: percentage(raw.totalInvoices, raw.validOrders),
    topCustomerRevenueShare: customer.topShare,
    topProductRevenueShare: product.topShare,
    fixedExpenseDayRate: await scalarPercentage(`
      SELECT COUNT(*) FILTER (WHERE EXTRACT(DAY FROM transaction_date) IN (5, 10, 18))::numeric AS part,
             COUNT(*)::numeric AS whole
      FROM cash_transactions
      WHERE shop_id = $1 AND transaction_date <= $2::date AND type = 'EXPENSE'
    `, shopId, asOf),
    businessMarkerCount: await scalarCount(`
      SELECT COUNT(*) FROM (
        SELECT id FROM sales_orders WHERE shop_id = $1 AND (notes ILIKE '%dữ liệu kiểm thử%' OR notes ILIKE '%test_dataset%' OR notes ILIKE '%mock%')
        UNION ALL SELECT id FROM cash_transactions WHERE shop_id = $1 AND (notes ILIKE '%dữ liệu kiểm thử%' OR notes ILIKE '%test_dataset%' OR notes ILIKE '%mock%')
        UNION ALL SELECT id FROM invoices WHERE shop_id = $1 AND (notes ILIKE '%dữ liệu kiểm thử%' OR notes ILIKE '%test_dataset%' OR notes ILIKE '%mock%')
        UNION ALL SELECT id FROM purchase_orders WHERE shop_id = $1 AND (notes ILIKE '%dữ liệu kiểm thử%' OR notes ILIKE '%test_dataset%' OR notes ILIKE '%mock%')
        UNION ALL SELECT id FROM purchases_without_invoice WHERE shop_id = $1 AND (notes ILIKE '%dữ liệu kiểm thử%' OR notes ILIKE '%test_dataset%' OR notes ILIKE '%mock%')
      ) marked
    `, shopId),
    attachmentMarkerCount: await scalarCount(`
      SELECT COUNT(*) FROM (
        SELECT id FROM invoice_scans
        WHERE shop_id = $1 AND (
          image_url ILIKE '%test_dataset%' OR image_url ILIKE '%mock%'
          OR COALESCE(notes, '') ILIKE '%test_dataset%' OR COALESCE(notes, '') ILIKE '%mock%'
          OR COALESCE(ocr_raw_text, '') ILIKE '%test_dataset%' OR COALESCE(ocr_raw_text, '') ILIKE '%mock%'
        )
        UNION ALL SELECT id FROM debt_evidences
        WHERE shop_id = $1 AND (
          file_url ILIKE '%test_dataset%' OR file_url ILIKE '%mock%'
          OR COALESCE(file_name, '') ILIKE '%test_dataset%' OR COALESCE(file_name, '') ILIKE '%mock%'
          OR COALESCE(description, '') ILIKE '%test_dataset%' OR COALESCE(description, '') ILIKE '%mock%'
        )
      ) marked_attachments
    `, shopId),
    datasetMarkerCount: await scalarCount(`
      SELECT COUNT(*) FROM activity_logs
      WHERE shop_id = $1 AND (
        entity_type IN ('DATASET', 'DATA_QUALITY_REPAIR')
        OR new_value ILIKE '%test_dataset%'
        OR new_value ILIKE '%mock%'
      )
    `, shopId),
  });

  return { raw, metrics, paymentMix, customerTypeMix, weekdayMix, monthlyMix };
}

async function scalarCount(sql: string, shopId: number): Promise<number> {
  const row = await queryOne<{ count: string | number }>(sql, [shopId]);
  return numberValue(row.count);
}

async function scalarPercentage(sql: string, shopId: number, asOf: string): Promise<number> {
  const row = await queryOne<{ part: string | number; whole: string | number }>(sql, [shopId, asOf]);
  return percentage(row.part, row.whole);
}

async function runCheck(
  check: CheckDefinition,
  shopId: number,
  asOf: string,
): Promise<DataQualityFinding | null> {
  const params = check.sql.includes('$2')
    ? [shopId, asOf]
    : check.sql.includes('$1')
      ? [shopId]
      : [];
  const row = await queryOne<CheckRow>(check.sql, params);
  const violations = numberValue(row.violations);
  if (violations <= 0) return null;
  const population = numberValue(row.population);
  return {
    code: check.code,
    shopId,
    title: check.title,
    severity: check.severity,
    confidence: check.confidence,
    violations,
    population,
    rate: percentage(violations, population),
    evidence: String(row.evidence || ''),
    risk: check.risk,
    cause: check.cause,
    remediation: check.remediation,
  };
}

async function main(): Promise<void> {
  const shopIds = parseTestShopIds(argument('shop-ids'));
  const asOf = parseAsOfDate(argument('as-of'));
  if (!['table', 'json'].includes(format)) {
    throw new Error('--format chỉ nhận table hoặc json');
  }

  await AppDataSource.initialize();
  try {
    const shops = [];
    for (const shopId of shopIds) {
      const profileRow = await queryOne<{
        id: number;
        shopName: string;
        shopCode: string | null;
        businessSector: string | null;
      }>(`
        SELECT id, shop_name AS "shopName", shop_code AS "shopCode", business_sector AS "businessSector"
        FROM shop_profiles WHERE id = $1
      `, [shopId]);
      const checkFindings: DataQualityFinding[] = [];
      for (const check of CORE_CHECKS) {
        const finding = await runCheck(check, shopId, asOf);
        if (finding) checkFindings.push(finding);
      }
      const loadedMetrics = await loadMetrics(shopId, asOf);
      const realismFindings = evaluateRealism(shopId, loadedMetrics.metrics);
      const findings = [...checkFindings, ...realismFindings];
      const status = summarizeSeverity(findings);
      shops.push({
        shopId,
        expectedProfile: TEST_SHOP_PROFILES[shopId],
        shopName: profileRow.shopName || null,
        shopCode: profileRow.shopCode || null,
        businessSector: profileRow.businessSector || null,
        status,
        coverage: await loadCoverage(shopId),
        metrics: loadedMetrics.metrics,
        rawMetrics: loadedMetrics.raw,
        distributions: {
          paymentMixPct: loadedMetrics.paymentMix,
          customerTypeMixPct: loadedMetrics.customerTypeMix,
          weekdayOrders: loadedMetrics.weekdayMix,
          monthlyOrders: loadedMetrics.monthlyMix,
        },
        findings,
      });
    }

    const report = {
      reportVersion: 'TEST_SHOP_DATA_QUALITY_V1',
      generatedAt: new Date().toISOString(),
      asOf,
      scope: shopIds,
      grain: 'Một shop test; các bảng fact được đối soát theo order/item/payment, product/warehouse, invoice/item và journal/line.',
      assumptions: [
        'Shop 34 là hồ sơ construction; shop 35 là hồ sơ agriculture.',
        'Tệp ảnh/chứng từ không được xem là bằng chứng thật nếu có marker TEST_DATASET.',
        'Tỷ lệ thuế chỉ là dữ liệu fixture, không phải kết luận pháp lý.',
      ],
      shops,
      summary: {
        status: shops.some((shop) => shop.status === 'FAIL') ? 'FAIL' : shops.some((shop) => shop.status === 'WARNING') ? 'WARNING' : 'PASS',
        findingCount: shops.reduce((sum, shop) => sum + shop.findings.length, 0),
        criticalHighCount: shops.reduce(
          (sum, shop) => sum + shop.findings.filter((finding) => finding.severity === 'CRITICAL' || finding.severity === 'HIGH').length,
          0,
        ),
      },
    };

    if (outputPath) {
      await writeFile(outputPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
    }
    if (format === 'json') {
      console.log(JSON.stringify(report, null, 2));
    } else {
      console.table(shops.map((shop) => ({
        shopId: shop.shopId,
        profile: shop.expectedProfile,
        status: shop.status,
        products: shop.rawMetrics.totalProducts,
        orders: shop.metrics.totalOrders,
        validOrders: shop.metrics.validOrders,
        invoices: shop.rawMetrics.totalInvoices,
        lastOrder: shop.rawMetrics.lastOrder,
        findings: shop.findings.length,
      })));
      const findings = shops.flatMap((shop) => shop.findings.map((finding) => ({
        shopId: finding.shopId,
        severity: finding.severity,
        code: finding.code,
        violations: finding.violations,
        ratePct: finding.rate,
        evidence: finding.evidence,
      })));
      if (findings.length) console.table(findings);
      console.log(`Audit ${report.summary.status}: ${report.summary.findingCount} findings; ${report.summary.criticalHighCount} critical/high.`);
      if (outputPath) console.log(`JSON report: ${outputPath}`);
    }
    if (report.summary.status === 'FAIL') process.exitCode = 2;
  } finally {
    await AppDataSource.destroy();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? (error.stack || error.message) : error);
  process.exitCode = 1;
});
