const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

process.env.CLOUDINARY_CLOUD_NAME = 'demo';

const {
  ProductInputError,
  isOwnedProductImageUrl,
  normalizeProductInput,
} = require('../dist/product/product-input.utils');

test('product input only returns explicitly editable fields', () => {
  const result = normalizeProductInput(12, {
    name: '  Xi măng PCB40  ',
    unit: 'Bao',
    costPrice: '72000',
    sellingPrice: 85000,
    currentStock: 15,
    tags: ['Bán chạy', 'Bán chạy'],
  }, { requireName: true, allowOpeningStock: true });

  assert.deepEqual(result, {
    name: 'Xi măng PCB40',
    unit: 'Bao',
    costPrice: 72000,
    sellingPrice: 85000,
    currentStock: 15,
    tags: ['Bán chạy'],
  });
});

test('product tag filter matches a complete tag instead of a substring', () => {
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'src', 'services', 'product.service.ts'),
    'utf8',
  );

  assert.match(source, /unnest\(string_to_array\(COALESCE\(p\.tags, ''\), ','\)\)/);
  assert.match(source, /LOWER\(BTRIM\(tag_value\.value\)\) = LOWER\(:tag\)/);
  assert.doesNotMatch(source, /p\.tags ILIKE :tag/);
});

test('product input rejects system and cross-shop fields', () => {
  assert.throws(
    () => normalizeProductInput(12, { name: 'Sản phẩm', shopId: 99 }),
    ProductInputError,
  );
  assert.throws(
    () => normalizeProductInput(12, { id: 1, isActive: false }),
    ProductInputError,
  );
});

test('product input validates prices, stock and tax rate', () => {
  assert.throws(() => normalizeProductInput(12, { costPrice: -1 }), ProductInputError);
  assert.throws(
    () => normalizeProductInput(12, { currentStock: 1.5 }, { allowOpeningStock: true }),
    ProductInputError,
  );
  assert.throws(() => normalizeProductInput(12, { currentStock: 1 }), ProductInputError);
  assert.throws(() => normalizeProductInput(12, { taxRate: 101 }), ProductInputError);
});

test('product image URL must be HTTPS Cloudinary storage owned by the shop', () => {
  const owned = 'https://res.cloudinary.com/demo/image/upload/v1/'
    + 'smartstock/shops/12/products/item.webp';
  assert.equal(isOwnedProductImageUrl(12, owned), true);
  assert.equal(isOwnedProductImageUrl(13, owned), false);
  assert.equal(isOwnedProductImageUrl(12, 'https://example.com/item.webp'), false);
  assert.equal(isOwnedProductImageUrl(12, null), true);
});
