const test = require('node:test');
const assert = require('node:assert/strict');

const {
  parseTaxDeclarationForms,
  parseTaxSupportLinks,
} = require('../dist/system/tax-reference-data.utils');

test('tax reference parsers accept validated DB JSON', () => {
  const forms = parseTaxDeclarationForms(JSON.stringify([{
    code: '01/CNKD',
    name: 'Tờ khai',
    description: 'Mô tả',
    status: 'READY',
    iconKey: 'description',
  }]));
  const links = parseTaxSupportLinks(JSON.stringify([{
    title: 'Cục Thuế',
    description: 'Cổng chính thức',
    url: 'https://www.gdt.gov.vn',
    iconKey: 'authority',
    colorRole: 'PRIMARY',
  }]));

  assert.equal(forms[0].code, '01/CNKD');
  assert.equal(links[0].url, 'https://www.gdt.gov.vn/');
});

test('tax support links reject untrusted hosts from DB', () => {
  assert.throws(
    () => parseTaxSupportLinks(JSON.stringify([{
      title: 'Giả mạo',
      description: 'Không hợp lệ',
      url: 'https://gdt.gov.vn.attacker.example/phishing',
      iconKey: 'authority',
      colorRole: 'PRIMARY',
    }])),
    /không thuộc tên miền cho phép/,
  );
});
