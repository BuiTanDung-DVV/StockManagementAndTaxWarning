const test = require('node:test');
const assert = require('node:assert/strict');

const { SystemService } = require('../dist/services/system.service');

test('saving a new shop QR deletes the previous managed QR', async () => {
  const profile = {
    id: 12,
    qrPaymentUrl:
      'https://res.cloudinary.com/demo/image/upload/v1/'
      + 'smartstock/shops/12/payment-qr/old.webp',
  };
  const service = new SystemService();
  const deletedUrls = [];

  service.getShopProfile = async () => profile;
  service.profileRepo = { save: async (value) => value };
  service.imageStorageService = {
    downloadShopPaymentQrImage: async () => ({
      imageUrl: 'https://res.cloudinary.com/demo/image/upload/v1/'
        + 'smartstock/shops/12/payment-qr/new.webp',
      objectKey: 'smartstock/shops/12/payment-qr/new',
      bytes: Buffer.from('qr-image'),
    }),
    deleteShopPaymentQrByUrl: async (_shopId, imageUrl) => {
      deletedUrls.push(imageUrl);
      return { deleted: true };
    },
  };
  service.decodePaymentQrImage = async () => ({
    rawText: '000201...6304ABCD',
    bankBin: '970422',
    accountNumber: '123456789',
    accountName: 'NGUYEN VAN A',
    amount: null,
    message: null,
  });

  const result = await service.confirmAndReplaceShopPaymentQr(
    12,
    'smartstock/shops/12/payment-qr/new',
  );

  assert.equal(
    result.imageUrl,
    'https://res.cloudinary.com/demo/image/upload/v1/'
      + 'smartstock/shops/12/payment-qr/new.webp',
  );
  assert.equal(profile.qrPaymentUrl, result.imageUrl);
  assert.equal(profile.qrPaymentDetails.accountNumber, '123456789');
  assert.deepEqual(deletedUrls, [
    'https://res.cloudinary.com/demo/image/upload/v1/'
      + 'smartstock/shops/12/payment-qr/old.webp',
  ]);
});
