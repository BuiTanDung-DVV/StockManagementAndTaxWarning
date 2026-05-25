const fs = require('fs');
const files = [
  'lib/features/finance/presentation/invoice_list_screen.dart',
  'lib/features/finance/presentation/purchase_no_invoice_screen.dart',
  'lib/features/finance/presentation/salary_ledger_screen.dart',
  'lib/features/finance/presentation/tax_declaration_screen.dart',
  'lib/features/inventory/presentation/purchase_order_form_screen.dart',
  'lib/features/inventory/presentation/stock_take_form_screen.dart',
  'lib/features/products/presentation/product_form_screen.dart'
];
files.forEach(f => {
  let content = fs.readFileSync(f, 'utf8');
  if (!content.includes('toast_service.dart')) {
    content = content.replace(/^(import [^\n]+)/m, "$1\nimport '../../../core/utils/toast_service.dart';");
    fs.writeFileSync(f, content);
  }
});
