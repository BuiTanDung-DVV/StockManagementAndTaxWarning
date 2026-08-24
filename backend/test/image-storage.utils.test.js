const test = require('node:test');
const assert = require('node:assert/strict');
const { getMetadataArgsStorage } = require('typeorm');
const { Product } = require('../dist/product/entities');
const { ShopProfile } = require('../dist/system/entities');

const {
  MAX_PRODUCT_IMAGE_BYTES,
  isOwnedProductImageKey,
  isOwnedShopPaymentQrKey,
  isOwnedDebtEvidenceImageKey,
  debtEvidenceImageKeyFromPublicUrl,
  productImageKeyFromPublicUrl,
  shopPaymentQrKeyFromPublicUrl,
  validateProductImageUpload,
} = require('../dist/services/image-storage.service');

test('accepts supported product images within 4 MB', () => {
  assert.deepEqual(
    validateProductImageUpload({
      fileName: 'bon-cau.webp',
      contentType: 'image/webp',
      size: 1024,
    }),
    {
      fileName: 'bon-cau.webp',
      contentType: 'image/webp',
      size: 1024,
    },
  );
});

test('rejects unsupported or oversized product images', () => {
  assert.throws(
    () =>
      validateProductImageUpload({
        fileName: 'script.svg',
        contentType: 'image/svg+xml',
        size: 1024,
      }),
    /JPG, PNG hoặc WEBP/,
  );
  assert.throws(
    () =>
      validateProductImageUpload({
        fileName: 'large.jpg',
        contentType: 'image/jpeg',
        size: MAX_PRODUCT_IMAGE_BYTES + 1,
      }),
    /4 MB/,
  );
});

test('only allows product image keys owned by the active shop', () => {
  assert.equal(
    isOwnedProductImageKey(12, 'smartstock/shops/12/products/image'),
    true,
  );
  assert.equal(
    isOwnedProductImageKey(12, 'smartstock/shops/13/products/image'),
    false,
  );
  assert.equal(
    isOwnedProductImageKey(12, 'smartstock/shops/12/products/../image'),
    false,
  );
});

test('extracts only the active shop image key from the configured public URL', () => {
  assert.equal(
    productImageKeyFromPublicUrl(
      12,
      'https://res.cloudinary.com/demo/image/upload/v123/'
        + 'smartstock/shops/12/products/bon-cau.webp',
      'demo',
    ),
    'smartstock/shops/12/products/bon-cau',
  );
  assert.equal(
    productImageKeyFromPublicUrl(
      12,
      'https://res.cloudinary.com/demo/image/upload/v123/'
        + 'smartstock/shops/13/products/image.webp',
      'demo',
    ),
    null,
  );
  assert.equal(
    productImageKeyFromPublicUrl(
      12,
      'https://tracking.example/smartstock/shops/12/products/image.webp',
      'demo',
    ),
    null,
  );
});

test('payment QR keys are isolated by shop', () => {
  const key = 'smartstock/shops/12/payment-qr/payment';
  assert.equal(isOwnedShopPaymentQrKey(12, key), true);
  assert.equal(isOwnedShopPaymentQrKey(13, key), false);
  assert.equal(
    shopPaymentQrKeyFromPublicUrl(
      12,
      `https://res.cloudinary.com/demo/image/upload/v123/${key}.webp`,
      'demo',
    ),
    key,
  );
});

test('debt evidence image keys are isolated by shop', () => {
  const key = 'smartstock/shops/12/debt-evidence/receipt';
  assert.equal(isOwnedDebtEvidenceImageKey(12, key), true);
  assert.equal(isOwnedDebtEvidenceImageKey(13, key), false);
  assert.equal(
    debtEvidenceImageKeyFromPublicUrl(
      12,
      `https://res.cloudinary.com/demo/image/upload/v123/${key}.webp`,
      'demo',
    ),
    key,
  );
});

test('nullable media URL columns keep an explicit PostgreSQL type', () => {
  const columns = getMetadataArgsStorage().columns;
  const productImage = columns.find(
    (column) => column.target === Product && column.propertyName === 'imageUrl',
  );
  const shopQr = columns.find(
    (column) =>
      column.target === ShopProfile && column.propertyName === 'qrPaymentUrl',
  );

  assert.equal(productImage?.options.type, 'varchar');
  assert.equal(shopQr?.options.type, 'varchar');
});
