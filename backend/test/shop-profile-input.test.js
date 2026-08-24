const test = require('node:test');
const assert = require('node:assert/strict');

const { SystemService } = require('../dist/services/system.service.js');

test('shop profile ignores identity, scope and managed media fields from client', async () => {
  const profile = {
    id: 9,
    shopId: 34,
    shopName: 'Cũ',
    qrPaymentUrl: 'managed.webp',
  };
  const service = new SystemService();
  service.getShopProfile = async () => profile;
  service.profileRepo = { save: async (value) => value };

  await service.updateShopProfile(34, {
    id: 999,
    shopId: 999,
    shopName: 'Mới',
    qrPaymentUrl: 'attacker.webp',
  });

  assert.equal(profile.id, 9);
  assert.equal(profile.shopId, 34);
  assert.equal(profile.shopName, 'Mới');
  assert.equal(profile.qrPaymentUrl, 'managed.webp');
});

test('shop profile resolves bank name from database configuration', async () => {
  const profile = { id: 9, shopId: 34 };
  const service = new SystemService();
  service.getShopProfile = async () => profile;
  service.getPaymentBankOptions = async () => [
    { id: 'VCB', name: 'Vietcombank' },
  ];
  service.profileRepo = { save: async (value) => value };

  await service.updateShopProfile(34, {
    bankId: 'vcb',
    bankName: 'Tên giả từ client',
  });
  assert.equal(profile.bankId, 'VCB');
  assert.equal(profile.bankName, 'Vietcombank');

  await assert.rejects(
    () => service.updateShopProfile(34, { bankId: 'UNKNOWN' }),
    /không có trong danh mục DB/,
  );
});
