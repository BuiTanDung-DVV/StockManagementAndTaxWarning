const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const {
  AiShopContextError,
  requireAiShopId,
} = require('../dist/ai/ai-shop-context.utils');
const aiServiceSource = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'services', 'ai.service.ts'),
  'utf8',
);

test('AI only accepts a concrete positive shop id', () => {
  assert.equal(requireAiShopId(34), 34);
  assert.equal(requireAiShopId('35'), 35);
});

test('AI never falls back to the first shop in aggregate context', () => {
  for (const value of [undefined, null, '', 'all', 0, -1, 1.5]) {
    assert.throws(() => requireAiShopId(value), AiShopContextError);
  }
});

test('AI service does not log API key presence or length', () => {
  assert.doesNotMatch(aiServiceSource, /GEMINI_API_KEY check|key\.length/);
});

test('AI uses database-backed net sales and fails safe without legal sources', () => {
  assert.match(aiServiceSource, /new SalesService\(\)/);
  assert.match(aiServiceSource, /this\.salesService\.summary\(/);
  assert.doesNotMatch(aiServiceSource, /SUM\(o\.subtotal - o\.discount_amount\)/);
  assert.doesNotMatch(aiServiceSource, /Quy định mặc định: Áp dụng Thông tư/);
  assert.match(aiServiceSource, /Không được tự khẳng định quy định, ngưỡng hoặc nghĩa vụ pháp lý/);
  assert.match(aiServiceSource, /CHƯA THỂ TRUY VẤN DB/);
  assert.match(aiServiceSource, /không được suy diễn thành 0 hoặc trạng thái an toàn/);
  assert.match(aiServiceSource, /Chưa ghi nhận cảnh báo trong phạm vi đã kiểm tra/);
  assert.doesNotMatch(aiServiceSource, /Cửa hàng vận hành ổn định/);
  assert.match(aiServiceSource, /generateWithGoogleSearch/);
  assert.match(aiServiceSource, /legalGroundingService\.extractTrustedSources/);
  assert.match(aiServiceSource, /insufficient_sources/);
  assert.match(aiServiceSource, /TÀI LIỆU TRI THỨC ĐÃ CẤU HÌNH/);
});
