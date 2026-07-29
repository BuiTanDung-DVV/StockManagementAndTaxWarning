const test = require('node:test');
const assert = require('node:assert/strict');

const { ProductService } = require('../dist/services/product.service');

function createServiceWithProduct(product) {
  const service = new ProductService();
  const deletedUrls = [];

  service.loadProductEntity = async () => product;
  service.productRepo = {
    save: async (value) => value,
  };
  service.findProductById = async () => product;
  service.imageStorageService = {
    deleteProductImageByUrl: async (_shopId, imageUrl) => {
      deletedUrls.push(imageUrl);
      return { deleted: true };
    },
  };

  return { service, deletedUrls };
}

test('replacing the single product image deletes the previous Cloudinary image', async () => {
  const product = {
    id: 7,
    shopId: 12,
    sku: 'SKU-7',
    barcode: null,
    imageUrl: 'https://res.cloudinary.com/demo/image/upload/v1/'
      + 'smartstock/shops/12/products/old.webp',
    isActive: true,
  };
  const { service, deletedUrls } = createServiceWithProduct(product);

  await service.updateProduct(12, 7, {
    imageUrl: 'https://res.cloudinary.com/demo/image/upload/v1/'
      + 'smartstock/shops/12/products/new.webp',
  });

  assert.equal(
    product.imageUrl,
    'https://res.cloudinary.com/demo/image/upload/v1/'
      + 'smartstock/shops/12/products/new.webp',
  );
  assert.deepEqual(deletedUrls, [
    'https://res.cloudinary.com/demo/image/upload/v1/'
      + 'smartstock/shops/12/products/old.webp',
  ]);
});

test('deleting a product clears and deletes its current image', async () => {
  const product = {
    id: 8,
    shopId: 12,
    imageUrl: 'https://res.cloudinary.com/demo/image/upload/v1/'
      + 'smartstock/shops/12/products/current.webp',
    isActive: true,
  };
  const { service, deletedUrls } = createServiceWithProduct(product);

  await service.deleteProduct(12, 8);

  assert.equal(product.isActive, false);
  assert.equal(product.imageUrl, null);
  assert.deepEqual(deletedUrls, [
    'https://res.cloudinary.com/demo/image/upload/v1/'
      + 'smartstock/shops/12/products/current.webp',
  ]);
});
