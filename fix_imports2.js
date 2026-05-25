const fs = require('fs');
const files = [
  'lib/features/auth/presentation/onboarding_screen.dart',
  'lib/features/auth/presentation/register_screen.dart',
  'lib/features/auth/presentation/waiting_approval_screen.dart',
  'lib/features/customers/presentation/customer_form_screen.dart',
  'lib/features/finance/presentation/daily_closing_screen.dart',
  'lib/features/finance/presentation/debt_aging_screen.dart'
];
files.forEach(f => {
  let content = fs.readFileSync(f, 'utf8');
  if (!content.includes('toast_service.dart')) {
    content = content.replace(/^(import [^\n]+)/m, "$1\nimport '../../../core/utils/toast_service.dart';");
    fs.writeFileSync(f, content);
  }
});
