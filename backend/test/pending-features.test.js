const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  assertDeliveryStatusTransition,
  calculateShippingReturnAllocation,
} = require('../dist/sales/sales-accounting.utils');
const {
  normalizeShippingCarrierInput,
} = require('../dist/services/shipping-carrier.service');
const {
  normalizeInvoiceOcrData,
} = require('../dist/services/invoice-ocr.service');
const {
  decodeShopBackup,
  encodeShopBackup,
  shopBackupChecksum,
  isSensitiveBackupConfigKey,
  validateShopBackupRelationships,
} = require('../dist/services/shop-backup.service');
const {
  invoiceScanImageKeyFromPublicUrl,
} = require('../dist/services/image-storage.service');

test('customer shipping is refunded only when explicitly selected', () => {
  const base = {
    subtotal: 1_000_000,
    discountAmount: 100_000,
    taxAmount: 90_000,
    paidAmount: 1_045_000,
    shippingFee: 50_000,
    shippingFeePayer: 'CUSTOMER',
    shippingTaxRate: 10,
  };
  assert.deepEqual(calculateShippingReturnAllocation({
    ...base,
    refundShippingFee: false,
  }), {
    merchandiseTotal: 990_000,
    shippingTaxAmount: 5_000,
    customerShippingCharge: 55_000,
    refundShippingFee: false,
    refundedShippingAmount: 0,
    refundAmount: 990_000,
    unpaidShipping: 55_000,
  });
  assert.equal(calculateShippingReturnAllocation({
    ...base,
    refundShippingFee: true,
  }).refundAmount, 1_045_000);
  const partial = calculateShippingReturnAllocation({
    ...base,
    paidAmount: 1_000_000,
    refundShippingFee: true,
  });
  assert.equal(partial.refundedShippingAmount, 10_000);
  assert.equal(partial.unpaidShipping, 45_000);
  assert.equal(partial.refundAmount, 1_000_000);
});

test('shop-paid shipping never becomes a customer refund', () => {
  const result = calculateShippingReturnAllocation({
    subtotal: 100_000,
    discountAmount: 0,
    taxAmount: 10_000,
    paidAmount: 110_000,
    shippingFee: 25_000,
    shippingFeePayer: 'SHOP',
    shippingTaxRate: 10,
    refundShippingFee: true,
  });
  assert.equal(result.refundShippingFee, false);
  assert.equal(result.refundedShippingAmount, 0);
  assert.equal(result.refundAmount, 110_000);
});

test('delivery workflow cannot move backwards or cancel after delivery', () => {
  assert.equal(assertDeliveryStatusTransition('PENDING', 'IN_TRANSIT'), 'IN_TRANSIT');
  assert.equal(assertDeliveryStatusTransition('IN_TRANSIT', 'DELIVERED'), 'DELIVERED');
  assert.equal(assertDeliveryStatusTransition('DELIVERED', 'RETURNED'), 'RETURNED');
  assert.throws(() => assertDeliveryStatusTransition('DELIVERED', 'CANCELLED'), /transition/);
  assert.throws(() => assertDeliveryStatusTransition('CANCELLED', 'PENDING'), /transition/);
});

test('delivery completion locks the order and posts the shop expense once', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'sales.service.ts'),
    'utf8',
  );
  const updateOrder = source.slice(
    source.indexOf('async updateOrder('),
    source.indexOf('async addPayment('),
  );
  assert.match(updateOrder, /lock: \{ mode: 'pessimistic_write' \}/);
  assert.match(updateOrder, /!order\.shippingExpenseTransactionId/);
  assert.match(updateOrder, /transactionCode: `DL\$\{shopId\}\$\{order\.id\}`/);
});

test('shipping carrier input is normalized and blocks unsafe tracking URLs', () => {
  assert.deepEqual(normalizeShippingCarrierInput({
    name: ' Giao Hàng Nhanh ',
    code: ' ghn ',
    defaultFee: '25000',
    trackingUrlTemplate: 'https://example.vn/track/{trackingCode}',
  }), {
    name: 'Giao Hàng Nhanh',
    code: 'GHN',
    phone: null,
    trackingUrlTemplate: 'https://example.vn/track/{trackingCode}',
    defaultFee: 25000,
    isActive: true,
  });
  assert.throws(
    () => normalizeShippingCarrierInput({
      name: 'X',
      code: 'XX',
      trackingUrlTemplate: 'javascript:alert(1)',
    }),
    /HTTP hoặc HTTPS/,
  );
});

test('OCR data requires balanced totals and real invoice lines', () => {
  const parsed = normalizeInvoiceOcrData({
    invoiceNumber: 'HD-001',
    invoiceDate: '2026-09-01',
    partnerName: 'Nhà cung cấp A',
    items: [{ itemName: 'Xi măng', quantity: 2, unitPrice: 100, subtotal: 200 }],
    subtotal: 200,
    taxAmount: 20,
    totalAmount: 220,
    confidence: 2,
  });
  assert.equal(parsed.confidence, 1);
  assert.throws(
    () => normalizeInvoiceOcrData({ ...parsed, totalAmount: 999 }),
    /không cân đối/,
  );
  assert.throws(
    () => normalizeInvoiceOcrData({ ...parsed, invoiceDate: '2026-02-31' }),
    /không tồn tại/,
  );
  assert.throws(
    () => normalizeInvoiceOcrData({
      ...parsed,
      items: [{ ...parsed.items[0], subtotal: 190 }],
    }),
    /không hợp lệ/,
  );
  assert.throws(
    () => normalizeInvoiceOcrData({
      ...parsed,
      items: [{ ...parsed.items[0], quantity: 1, unitPrice: 200 }],
      subtotal: 202,
      totalAmount: 222,
    }),
    /không cân đối/,
  );
});

test('backup gzip round-trip verifies shop scope and checksum', () => {
  const payload = { profile: { shop_id: 34 }, tables: { products: [{ id: 1, shop_id: 34 }] } };
  const envelope = {
    manifest: {
      format: 'smartstock-shop-backup',
      version: 1,
      shopId: 34,
      exportedAt: '2026-09-01T00:00:00.000Z',
      checksum: shopBackupChecksum(payload),
    },
    ...payload,
  };
  assert.deepEqual(decodeShopBackup(encodeShopBackup(envelope), 34), envelope);
  assert.throws(() => decodeShopBackup(encodeShopBackup(envelope), 35), /không thuộc cửa hàng/);
  const tampered = {
    ...envelope,
    tables: { products: [{ id: 2, shop_id: 34 }] },
  };
  assert.throws(() => decodeShopBackup(encodeShopBackup(tampered), 34), /Checksum/);
});

test('backup validation rejects foreign rows and broken child relationships', () => {
  const makeEnvelope = (tables) => {
    const payload = { profile: { id: 34, shop_id: 34 }, tables };
    return {
      manifest: {
        format: 'smartstock-shop-backup',
        version: 1,
        shopId: 34,
        exportedAt: '2026-09-01T00:00:00.000Z',
        checksum: shopBackupChecksum(payload),
      },
      ...payload,
    };
  };
  assert.throws(
    () => validateShopBackupRelationships(makeEnvelope({ products: [{ id: 1, shop_id: 35 }] }), 34),
    /không thuộc cửa hàng/,
  );
  assert.throws(
    () => validateShopBackupRelationships(makeEnvelope({
      purchase_orders: [{ id: 10, shop_id: 34 }],
      purchase_order_items: [{ id: 20, order_id: 999 }],
    }), 34),
    /thiếu liên kết/,
  );
  assert.throws(
    () => validateShopBackupRelationships(makeEnvelope({ products: [], users: [] }), 34),
    /không được hỗ trợ/,
  );
  assert.equal(isSensitiveBackupConfigKey('VIETQR_BANKS'), false);
  assert.equal(isSensitiveBackupConfigKey('GEMINI_API_KEY'), true);
  assert.throws(
    () => validateShopBackupRelationships(makeEnvelope({
      system_configs: [{ id: 1, shop_id: 34, config_key: 'PRIVATE_TOKEN', config_value: 'hidden' }],
    }), 34),
    /cấu hình nhạy cảm/,
  );
});

test('invoice scan image URL must be Cloudinary media owned by the shop', () => {
  const url = 'https://res.cloudinary.com/demo/image/upload/v1/smartstock/shops/34/invoice-scans/a.jpg';
  assert.equal(
    invoiceScanImageKeyFromPublicUrl(34, url, 'demo'),
    'smartstock/shops/34/invoice-scans/a',
  );
  assert.equal(invoiceScanImageKeyFromPublicUrl(35, url, 'demo'), null);
});

test('migration has an explicit rollback and backup routes are owner-only', () => {
  const root = path.join(__dirname, '..', '..');
  const up = fs.readFileSync(path.join(root, 'backend', 'database', '20260901_complete_pending_features.sql'), 'utf8');
  const down = fs.readFileSync(path.join(root, 'backend', 'database', '20260901_complete_pending_features.rollback.sql'), 'utf8');
  const routes = fs.readFileSync(path.join(root, 'backend', 'src', 'routes', 'shop-backup.routes.ts'), 'utf8');
  assert.match(up, /CREATE TABLE IF NOT EXISTS shipping_carriers/);
  assert.match(up, /CREATE TABLE IF NOT EXISTS shop_backup_snapshots/);
  assert.match(up, /HAVING COUNT\(\*\) > 1/);
  assert.match(up, /RAISE EXCEPTION 'Không thể tạo unique danh mục theo cửa hàng/);
  assert.match(down, /DROP TABLE IF EXISTS shop_backup_snapshots/);
  assert.match(down, /DROP TABLE IF EXISTS shipping_carriers/);
  assert.match(down, /RAISE EXCEPTION 'Không thể rollback unique danh mục toàn hệ thống/);
  assert.equal((routes.match(/requireOwner/g) || []).length, 5);
});
