const test = require('node:test');
const assert = require('node:assert/strict');

const {
  classifyLegalSource,
  isLegalDocumentQuestion,
  rankAndDedupeLegalSources,
} = require('../dist/ai/legal-grounding.utils');

test('detects questions that require current legal documents', () => {
  assert.equal(isLegalDocumentQuestion('Hộ kinh doanh phải kê khai thuế thế nào?'), true);
  assert.equal(isLegalDocumentQuestion('Thông tư này còn hiệu lực không?'), true);
  assert.equal(isLegalDocumentQuestion('tai lieu moi nhat ve thue ho kinh doanh'), true);
  assert.equal(isLegalDocumentQuestion('Sản phẩm nào sắp hết kho?'), false);
});

test('accepts only HTTPS official and TVPL legal sources', () => {
  assert.equal(classifyLegalSource('https://vbpl.vn/TW/Pages/vbpq-toanvan.aspx?ItemID=1').sourceKind, 'official');
  assert.equal(classifyLegalSource('https://vanban.chinhphu.vn/?docid=1').sourceKind, 'official');
  assert.equal(classifyLegalSource('https://thuvienphapluat.vn/van-ban/test.aspx').sourceKind, 'tvpl');
  assert.equal(classifyLegalSource('http://vbpl.vn/not-secure'), null);
  assert.equal(classifyLegalSource('https://vbpl.vn.attacker.example/document'), null);
  assert.equal(classifyLegalSource('https://example.com/blog'), null);
});

test('prioritizes national and official sources before TVPL and removes duplicates', () => {
  const results = rankAndDedupeLegalSources([
    { title: 'Bản tham khảo', url: 'https://thuvienphapluat.vn/van-ban/a.aspx' },
    { title: 'Cổng Chính phủ', url: 'https://vanban.chinhphu.vn/?docid=2' },
    { title: 'CSDL quốc gia', url: 'https://vbpl.vn/TW/Pages/vbpq.aspx?ItemID=3' },
    { title: 'Trùng', url: 'https://vbpl.vn/TW/Pages/vbpq.aspx?ItemID=3#top' },
  ]);

  assert.deepEqual(results.map(item => item.sourceKind), ['official', 'official', 'tvpl']);
  assert.equal(results[0].domain, 'vbpl.vn');
  assert.equal(results.length, 3);
});
