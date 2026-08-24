const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('frontend image upload never receives Cloudinary credentials', () => {
  const root = path.join(__dirname, '..', '..');
  const apiClient = fs.readFileSync(
    path.join(root, 'lib', 'core', 'network', 'api_client.dart'),
    'utf8',
  );
  const productProvider = fs.readFileSync(
    path.join(root, 'lib', 'features', 'products', 'providers', 'product_provider.dart'),
    'utf8',
  );

  assert.doesNotMatch(apiClient, /postSignedImageUpload|api\.cloudinary\.com/);
  assert.doesNotMatch(productProvider, /api_key|signature|presign/);
  assert.match(apiClient, /postImage\(/);
});

test('frontend payment configuration loads business options from backend', () => {
  const root = path.join(__dirname, '..', '..');
  const provider = fs.readFileSync(
    path.join(root, 'lib', 'features', 'settings', 'providers', 'system_provider.dart'),
    'utf8',
  );
  const screen = fs.readFileSync(
    path.join(root, 'lib', 'features', 'settings', 'presentation', 'payment_config_screen.dart'),
    'utf8',
  );

  assert.match(provider, /get\('\/payment-banks'\)/);
  assert.match(screen, /paymentBanksProvider/);
  assert.doesNotMatch(screen, /_vietqrBanks/);
  assert.doesNotMatch(screen, /\{'id': 'VCB', 'name': 'Vietcombank'\}/);
});

test('frontend source never contains backend secret names or database credentials', () => {
  const root = path.join(__dirname, '..', '..');
  const frontendRoot = path.join(root, 'lib');
  const files = [];
  const visit = (directory) => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const target = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(target);
      else if (entry.isFile() && entry.name.endsWith('.dart')) files.push(target);
    }
  };
  visit(frontendRoot);
  const source = files.map(file => fs.readFileSync(file, 'utf8')).join('\n');

  assert.doesNotMatch(source, /DATABASE_URL|CLOUDINARY_API_SECRET|GEMINI_API_KEY|JWT_SECRET|REFRESH_TOKEN_SECRET|OTP_SECRET/);
  assert.doesNotMatch(source, /postgres(?:ql)?:\/\//i);
});

test('tax reference content is loaded from backend instead of embedded in screens', () => {
  const root = path.join(__dirname, '..', '..');
  const declarationScreen = fs.readFileSync(
    path.join(root, 'lib', 'features', 'finance', 'presentation', 'tax_declaration_screen.dart'),
    'utf8',
  );
  const supportScreen = fs.readFileSync(
    path.join(root, 'lib', 'features', 'settings', 'presentation', 'tax_support_screen.dart'),
    'utf8',
  );
  const provider = fs.readFileSync(
    path.join(root, 'lib', 'features', 'finance', 'providers', 'tax_reference_provider.dart'),
    'utf8',
  );

  assert.match(provider, /get\('\/tax-reference-data'\)/);
  assert.doesNotMatch(declarationScreen, /'form': '01\/CNKD'/);
  assert.doesNotMatch(supportScreen, /'url': 'https:\/\/www\.gdt\.gov\.vn'/);
});

test('AI knowledge UI distinguishes database errors from an empty library', () => {
  const root = path.join(__dirname, '..', '..');
  const provider = fs.readFileSync(
    path.join(root, 'lib', 'features', 'settings', 'providers', 'ai_knowledge_provider.dart'),
    'utf8',
  );
  const screen = fs.readFileSync(
    path.join(root, 'lib', 'features', 'settings', 'presentation', 'ai_knowledge_management_screen.dart'),
    'utf8',
  );

  assert.match(provider, /AsyncNotifierProvider<AiKnowledgeNotifier, List<AiDocument>>/);
  assert.match(provider, /get\('\/ai-knowledge'\)/);
  assert.doesNotMatch(provider, /sampleDocuments|defaultDocuments|localDocuments/);
  assert.match(screen, /docsAsync\.hasError/);
  assert.match(screen, /Không thể tải kho tài liệu AI từ cơ sở dữ liệu/);
  assert.match(screen, /ref\.invalidate\(aiKnowledgeProvider\)/);
});

test('AI knowledge compatibility routes enforce settings permissions', () => {
  const root = path.join(__dirname, '..');
  const routes = fs.readFileSync(
    path.join(root, 'src', 'routes', 'ai.routes.ts'),
    'utf8',
  );

  assert.match(routes, /get\([\s\S]*?'\/knowledge'[\s\S]*?requirePermission\('settings', 'view'\)/);
  assert.match(routes, /post\([\s\S]*?'\/knowledge'[\s\S]*?requirePermission\('settings', 'edit'\)/);
  assert.match(routes, /put\([\s\S]*?'\/knowledge\/:id'[\s\S]*?requirePermission\('settings', 'edit'\)/);
  assert.match(routes, /delete\([\s\S]*?'\/knowledge\/:id'[\s\S]*?requirePermission\('settings', 'edit'\)/);
});

test('settings data failures are not presented as database-backed defaults', () => {
  const root = path.join(__dirname, '..', '..');
  const costing = fs.readFileSync(
    path.join(root, 'lib', 'features', 'settings', 'providers', 'costing_provider.dart'),
    'utf8',
  );
  const notifications = fs.readFileSync(
    path.join(root, 'lib', 'features', 'settings', 'providers', 'notification_provider.dart'),
    'utf8',
  );

  assert.doesNotMatch(costing, /this\.method\s*=\s*'AVG'/);
  assert.match(costing, /method != 'AVG' && method != 'FIFO'/);
  assert.match(costing, /Không thể tải phương pháp tính giá vốn từ cơ sở dữ liệu/);
  assert.doesNotMatch(costing, /catch \(e\)[\s\S]{0,160}return \[\]/);
  assert.doesNotMatch(costing, /catch \(e\)[\s\S]{0,160}return \{\}/);

  assert.match(notifications, /data\['items'\] is! List/);
  assert.match(notifications, /Không thể tải thông báo từ cơ sở dữ liệu/);
  assert.match(notifications, /String\? errorMessage/);
});

test('shop loading failures never masquerade as no shops or select another shop', () => {
  const root = path.join(__dirname, '..', '..');
  const provider = fs.readFileSync(
    path.join(root, 'lib', 'features', 'settings', 'providers', 'shop_provider.dart'),
    'utf8',
  );
  const dashboard = fs.readFileSync(
    path.join(root, 'lib', 'features', 'dashboard', 'presentation', 'dashboard_screen.dart'),
    'utf8',
  );

  assert.match(provider, /Không thể tải danh sách cửa hàng từ cơ sở dữ liệu/);
  assert.match(provider, /if \(matches\.isEmpty\) return;/);
  assert.doesNotMatch(provider, /orElse: \(\) => activeShops\.first/);
  assert.match(dashboard, /shopState\.errorMessage != null/);
  assert.match(dashboard, /loadUserShops\(\)/);
  assert.doesNotMatch(dashboard, /onReload: \(\) => ref\.invalidate\(shopProvider\)/);
});

test('authentication never turns a membership database failure into an empty shop list', () => {
  const root = path.join(__dirname, '..');
  const service = fs.readFileSync(
    path.join(root, 'src', 'services', 'auth.service.ts'),
    'utf8',
  );

  assert.doesNotMatch(service, /private async getUserShops[\s\S]*?catch \{\s*return \[\];/);
  assert.match(
    service,
    /const shops = await this\.getUserShops\(user\.id\);[\s\S]*?const tokens = await this\.createSessionTokens/,
  );
});

test('AI legal context contains no hardcoded document fallback', () => {
  const root = path.join(__dirname, '..');
  const aiService = fs.readFileSync(
    path.join(root, 'src', 'services', 'ai.service.ts'),
    'utf8',
  );
  const tvplService = fs.readFileSync(
    path.join(root, 'src', 'services', 'tvpl-search.service.ts'),
    'utf8',
  );

  assert.doesNotMatch(aiService, /tvplSearchService|THAM KHẢO VĂN BẢN/);
  assert.doesNotMatch(tvplService, /getDefaultTvplTaxResults/);
  assert.doesNotMatch(tvplService, /88\/2021\/TT-BTC|123\/2020\/NĐ-CP|38\/2019\/QH14/);
});

test('core frontend reports invalid API contracts instead of fake empty data', () => {
  const root = path.join(__dirname, '..', '..');
  const sources = [
    ['sales', 'sales_provider.dart'],
    ['inventory', 'inventory_provider.dart'],
    ['finance', 'finance_provider.dart'],
    ['products', 'product_provider.dart'],
    ['products', 'tag_provider.dart'],
  ].map(([feature, file]) => fs.readFileSync(
    path.join(root, 'lib', 'features', feature, 'providers', file),
    'utf8',
  )).join('\n');

  assert.match(sources, /Dữ liệu tồn kho không hợp lệ/);
  assert.match(sources, /Dữ liệu tài chính không hợp lệ/);
  assert.match(sources, /Dữ liệu sản phẩm bán chạy không hợp lệ/);
  assert.match(sources, /Dữ liệu nhãn sản phẩm không hợp lệ/);
  assert.doesNotMatch(sources, /return res as List<dynamic>\? \? \[\]/);
});

test('shop search failures are visible instead of presented as no database result', () => {
  const root = path.join(__dirname, '..', '..');
  const provider = fs.readFileSync(
    path.join(root, 'lib', 'features', 'auth', 'providers', 'auth_provider.dart'),
    'utf8',
  );
  const onboarding = fs.readFileSync(
    path.join(root, 'lib', 'features', 'auth', 'presentation', 'onboarding_screen.dart'),
    'utf8',
  );
  const dialog = fs.readFileSync(
    path.join(root, 'lib', 'features', 'auth', 'presentation', 'widgets', 'join_shop_dialog.dart'),
    'utf8',
  );

  assert.match(provider, /Dữ liệu tìm kiếm cửa hàng không hợp lệ/);
  assert.doesNotMatch(provider, /searchShops[\s\S]{0,500}catch \(e\)[\s\S]{0,80}return \[\]/);
  assert.match(onboarding, /Không thể tải cửa hàng từ cơ sở dữ liệu/);
  assert.match(dialog, /Không thể tải cửa hàng từ cơ sở dữ liệu/);
});

test('core KPI providers reject incomplete database summaries instead of showing false zeroes', () => {
  const root = path.join(__dirname, '..', '..');
  const sales = fs.readFileSync(
    path.join(root, 'lib', 'features', 'sales', 'providers', 'sales_provider.dart'),
    'utf8',
  );
  const finance = fs.readFileSync(
    path.join(root, 'lib', 'features', 'finance', 'providers', 'finance_provider.dart'),
    'utf8',
  );

  assert.match(sales, /Dữ liệu tổng quan bán hàng không đầy đủ/);
  assert.match(sales, /'netSalesRevenue'/);
  assert.match(sales, /'timezone'/);
  assert.match(finance, /Dữ liệu tổng quan dòng tiền không đầy đủ/);
  assert.match(finance, /Dữ liệu báo cáo lãi lỗ không đầy đủ/);
  assert.match(finance, /_requireNumericFields/);
});

test('inventory KPI providers require database totals and ABC reconciliation fields', () => {
  const root = path.join(__dirname, '..', '..');
  const inventory = fs.readFileSync(
    path.join(root, 'lib', 'features', 'inventory', 'providers', 'inventory_provider.dart'),
    'utf8',
  );

  assert.match(inventory, /Dữ liệu tồn kho không đầy đủ/);
  assert.match(inventory, /'productTotal'/);
  assert.match(inventory, /Dữ liệu phân tích ABC không đầy đủ/);
  assert.match(inventory, /'classificationRevenue'/);
  assert.match(inventory, /'timezone'/);
});

test('receivable and payable providers reject incomplete database responses', () => {
  const root = path.join(__dirname, '..', '..');
  const customers = fs.readFileSync(
    path.join(root, 'lib', 'features', 'customers', 'providers', 'customer_provider.dart'),
    'utf8',
  );
  const suppliers = fs.readFileSync(
    path.join(root, 'lib', 'features', 'suppliers', 'providers', 'supplier_provider.dart'),
    'utf8',
  );

  assert.match(customers, /Dữ liệu tuổi nợ phải thu không đầy đủ/);
  assert.match(customers, /'overdueDebt'/);
  assert.match(customers, /Dữ liệu danh sách công nợ không hợp lệ/);
  assert.match(suppliers, /Dữ liệu tuổi nợ phải trả không đầy đủ/);
  assert.match(suppliers, /'totalOutstanding'/);
  assert.match(suppliers, /Dữ liệu nhà cung cấp không hợp lệ/);
});

test('finance tables and charts reject incomplete database contracts', () => {
  const root = path.join(__dirname, '..', '..');
  const finance = fs.readFileSync(
    path.join(root, 'lib', 'features', 'finance', 'providers', 'finance_provider.dart'),
    'utf8',
  );

  assert.match(finance, /Dữ liệu giao dịch tài chính không hợp lệ/);
  assert.match(finance, /Dữ liệu phân loại chi phí không đầy đủ/);
  assert.match(finance, /Dữ liệu lịch sử chốt ngày không hợp lệ/);
  assert.match(finance, /Dữ liệu tổng hợp hóa đơn không đầy đủ/);
  assert.match(finance, /extraNumericFields: const \['filteredAmountTotal'\]/);
});
