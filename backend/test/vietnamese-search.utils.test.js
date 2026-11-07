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
  const translate = value => [...value].map(char => {
    const index = params.viAccents.indexOf(char);
    return index < 0 ? char : params.viPlain[index];
  }).join('');
  assert.equal(translate('Đại LÝ GẠO').toLowerCase(), 'dai ly gao');
  assert.match(vietnameseSearchExpression('p.name'), /translate\(lower/);
  assert.match(vietnameseSearchExpression('p.name'), /p\.name/);
});

test('literal percent underscore and escape marker cannot broaden search', () => {
  assert.equal(vietnameseSearchParams('SKU_10% !').search, '%sku!_10!% !!%');
  assert.match(vietnameseSearchExpression('p.sku'), /ESCAPE '!'/);
});
