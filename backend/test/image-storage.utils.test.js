const test = require('node:test');
const assert = require('node:assert/strict');

const {
  MAX_PRODUCT_IMAGE_BYTES,
  isOwnedProductImageKey,
  isOwnedShopPaymentQrKey,
  productImageKeyFromPublicUrl,
  shopPaymentQrKeyFromPublicUrl,
  validateProductImageUpload,
} = require('../dist/services/image-storage.service');

test('accepts supported product images within 5 MB', () => {
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
    /5 MB/,
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
