const test = require('node:test');
const assert = require('node:assert/strict');

const {
  foldVietnameseSearchText,
  vietnameseSearchExpression,
  vietnameseSearchParams,
} = require('../dist/common/vietnamese-search.utils');

test('Vietnamese search ignores accents and letter case', () => {
  assert.equal(foldVietnameseSearchText(' GẠCH '), 'gach');
  assert.equal(foldVietnameseSearchText('Nguyễn Đình'), 'nguyen dinh');
  assert.equal(foldVietnameseSearchText('Sơn chống thấm'), 'son chong tham');
});

test('database search uses the same folded keyword and translated column', () => {
  const params = vietnameseSearchParams('gạch');

  assert.equal(params.search, '%gach%');
  assert.equal(params.viAccents.length, params.viPlain.length);
  assert.match(vietnameseSearchExpression('p.name'), /translate\(lower/);
  assert.match(vietnameseSearchExpression('p.name'), /p\.name/);
});
