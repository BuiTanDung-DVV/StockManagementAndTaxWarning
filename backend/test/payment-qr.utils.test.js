const test = require('node:test');
const assert = require('node:assert/strict');

const {
  parseVietQrPayload,
  paymentQrDisplayText,
} = require('../dist/system/payment-qr.utils.js');

function tlv(tag, value) {
  return `${tag}${String(value.length).padStart(2, '0')}${value}`;
}

function crc16(value) {
  let crc = 0xffff;
  for (const byte of Buffer.from(value, 'utf8')) {
    crc ^= byte << 8;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc & 0x8000) !== 0 ? ((crc << 1) ^ 0x1021) : crc << 1;
      crc &= 0xffff;
    }
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
}

function sampleVietQr() {
  const beneficiary = tlv('00', '970422') + tlv('01', '123456789');
  const merchant = tlv('00', 'A000000727') + tlv('01', beneficiary);
  const withoutCrc = [
    tlv('00', '01'),
    tlv('01', '12'),
    tlv('38', merchant),
    tlv('53', '704'),
    tlv('58', 'VN'),
    tlv('59', 'NGUYEN VAN A'),
    tlv('60', 'HANOI'),
    tlv('62', tlv('08', 'THANH TOAN')),
    '6304',
  ].join('');
  return withoutCrc + crc16(withoutCrc);
}

test('parses and presents a valid VietQR payload', () => {
  const details = parseVietQrPayload(sampleVietQr());
  assert.equal(details.bankBin, '970422');
  assert.equal(details.accountNumber, '123456789');
  assert.equal(details.accountName, 'NGUYEN VAN A');
  assert.match(paymentQrDisplayText(details), /Số tài khoản: 123456789/);
});

test('rejects unrelated and corrupted QR payloads', () => {
  assert.throws(() => parseVietQrPayload('https://example.com'), /không chứa mã QR/);
  const valid = sampleVietQr();
  assert.throws(() => parseVietQrPayload(`${valid.slice(0, -1)}0`), /bị lỗi/);
});
