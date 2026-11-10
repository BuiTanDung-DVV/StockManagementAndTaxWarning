const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const OUTPUT_DIR = path.resolve('.playwright-mcp');
const ARTIFACT_DIR = 'C:/Users/tandu/.gemini/antigravity/brain/26301458-475e-4303-bb0a-1942a7addb00';

async function runVerification() {
  console.log('=== BẮT ĐẦU XÁC MINH GIAO DIỆN SAU KHI SỬA ===');
  
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  const browser = await chromium.launch({
    channel: 'msedge',
    headless: true,
  });

  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 },
  });
  const page = await context.newPage();

  console.log('1. Đăng nhập qua http://127.0.0.1:8080/...');
  await page.goto('http://127.0.0.1:8080/', { waitUntil: 'commit', timeout: 30000 });
  await page.waitForFunction(() => !!document.querySelector('flt-semantics-placeholder'), { timeout: 30000 });
  await page.waitForTimeout(2000);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1500);

  await page.locator('input[aria-label*="Gmail"]').fill('admin@kientao.com');
  await page.locator('input[type="password"]').fill('123456');
  await page.waitForTimeout(500);

  await page.locator('flt-semantics[role="button"]:has-text("Đăng nhập")').click();
  await page.waitForURL(url => !url.href.includes('login'), { timeout: 30000 });
  console.log('✓ Đăng nhập thành công! URL:', page.url());
  await page.waitForTimeout(4000);

  // 1. Kiểm tra Route /dashboard -> redirect về /
  console.log('2. Kiểm tra Route /dashboard redirect...');
  await page.goto('http://127.0.0.1:8080/#/dashboard');
  await page.waitForTimeout(3000);
  const currentUrl = page.url();
  console.log('✓ URL sau khi vào #/dashboard:', currentUrl);
  const shotDashboard = path.join(OUTPUT_DIR, 'verified_desktop_dashboard.png');
  await page.screenshot({ path: shotDashboard, scale: 'css' });
  console.log('✓ Chụp ảnh verified_desktop_dashboard.png');

  // 2. Kiểm tra Inventory Desktop & Mobile Subtitle
  console.log('3. Kiểm tra Quản lý kho (Desktop)...');
  await page.goto('http://127.0.0.1:8080/#/inventory');
  await page.waitForTimeout(4000);
  const shotInvDesktop = path.join(OUTPUT_DIR, 'verified_desktop_inventory.png');
  await page.screenshot({ path: shotInvDesktop, scale: 'css' });
  console.log('✓ Chụp ảnh verified_desktop_inventory.png');

  console.log('4. Kiểm tra Quản lý kho (Mobile 390x844)...');
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(2000);
  const shotInvMobile = path.join(OUTPUT_DIR, 'verified_mobile_inventory.png');
  await page.screenshot({ path: shotInvMobile, scale: 'css' });
  console.log('✓ Chụp ảnh verified_mobile_inventory.png');

  // 3. Kiểm tra Sales Mobile Title & Payment Methods
  console.log('5. Kiểm tra Bán hàng (Mobile 390x844)...');
  await page.goto('http://127.0.0.1:8080/#/sales');
  await page.waitForTimeout(4000);
  const shotSalesMobile = path.join(OUTPUT_DIR, 'verified_mobile_sales.png');
  await page.screenshot({ path: shotSalesMobile, scale: 'css' });
  console.log('✓ Chụp ảnh verified_mobile_sales.png');

  console.log('6. Kiểm tra Bán hàng (Desktop 1280x800)...');
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.waitForTimeout(2000);
  const shotSalesDesktop = path.join(OUTPUT_DIR, 'verified_desktop_sales.png');
  await page.screenshot({ path: shotSalesDesktop, scale: 'css' });
  console.log('✓ Chụp ảnh verified_desktop_sales.png');

  await browser.close();

  // Sao chép ảnh sang thư mục artifacts
  const images = [
    'verified_desktop_dashboard.png',
    'verified_desktop_inventory.png',
    'verified_mobile_inventory.png',
    'verified_mobile_sales.png',
    'verified_desktop_sales.png',
  ];

  for (const img of images) {
    const src = path.join(OUTPUT_DIR, img);
    const dest = path.join(ARTIFACT_DIR, img);
    if (fs.existsSync(src)) {
      fs.copyFileSync(src, dest);
      console.log(`✓ Đã sao chép sang artifact: ${dest}`);
    }
  }

  console.log('=== HOÀN TẤT XÁC MINH VÀ CHỤP ẢNH ===');
}

runVerification().catch(err => {
  console.error('Lỗi khi chạy xác minh:', err);
  process.exit(1);
});

