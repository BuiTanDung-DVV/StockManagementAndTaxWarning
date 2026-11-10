const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const OUTPUT_DIR = path.resolve('.playwright-mcp');

async function captureAll() {
  console.log('--- BẮT ĐẦU CHỤP KIỂM THỬ ĐẦY ĐỦ ---');
  const browser = await chromium.launch({
    channel: 'msedge',
    headless: true,
  });

  const page = await browser.newPage({
    viewport: { width: 1280, height: 800 },
  });

  console.log('1. Mở trang login...');
  await page.goto('https://smartstock-tax.vercel.app/', { waitUntil: 'commit', timeout: 45000 });
  await page.waitForFunction(() => !!document.querySelector('flt-semantics-placeholder'), { timeout: 30000 });
  await page.waitForTimeout(2000);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1500);

  console.log('2. Nhập email & mật khẩu...');
  await page.locator('input[aria-label*="Gmail"]').fill('admin@kientao.com');
  await page.locator('input[type="password"]').fill('123456');
  await page.waitForTimeout(500);

  console.log('3. Bấm Đăng nhập và đợi auth hoàn tất...');
  await page.locator('flt-semantics[role="button"]:has-text("Đăng nhập")').click();
  
  // Wait until navigated away from login
  await page.waitForURL(url => !url.href.includes('login'), { timeout: 30000 });
  console.log('✓ Đăng nhập thành công! URL hiện tại:', page.url());
  await page.waitForTimeout(4000);

  console.log('--- CHỤP MÀN HÌNH DESKTOP ---');

  // 1. Dashboard Desktop
  await page.screenshot({ path: path.join(OUTPUT_DIR, 'desktop_dashboard.png'), scale: 'css' });
  console.log('✓ Desktop Dashboard');

  // 2. Sales
  await page.goto('https://smartstock-tax.vercel.app/#/sales');
  await page.waitForTimeout(4000);
  await page.screenshot({ path: path.join(OUTPUT_DIR, 'desktop_sales.png'), scale: 'css' });
  console.log('✓ Desktop Sales');

  // 3. Inventory
  await page.goto('https://smartstock-tax.vercel.app/#/inventory');
  await page.waitForTimeout(4000);
  await page.screenshot({ path: path.join(OUTPUT_DIR, 'desktop_inventory.png'), scale: 'css' });
  console.log('✓ Desktop Inventory');

  // 4. Cashflow Forecast
  await page.goto('https://smartstock-tax.vercel.app/#/cashflow-forecast');
  await page.waitForTimeout(4000);
  await page.screenshot({ path: path.join(OUTPUT_DIR, 'desktop_cashflow.png'), scale: 'css' });
  console.log('✓ Desktop Cashflow');

  // 5. Budget Plans
  await page.goto('https://smartstock-tax.vercel.app/#/budget-plans');
  await page.waitForTimeout(4000);
  await page.screenshot({ path: path.join(OUTPUT_DIR, 'desktop_budget.png'), scale: 'css' });
  console.log('✓ Desktop Budget');

  // 6. Tax Estimate
  await page.goto('https://smartstock-tax.vercel.app/#/tax-estimate');
  await page.waitForTimeout(4000);
  await page.screenshot({ path: path.join(OUTPUT_DIR, 'desktop_tax.png'), scale: 'css' });
  console.log('✓ Desktop Tax Estimate');

  console.log('--- CHUYỂN SANG MOBILE (390x844) ---');
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(2000);

  // 7. Mobile Dashboard
  await page.goto('https://smartstock-tax.vercel.app/#/');
  await page.waitForTimeout(4000);
  await page.screenshot({ path: path.join(OUTPUT_DIR, 'mobile_dashboard.png'), scale: 'css' });
  console.log('✓ Mobile Dashboard');

  // 8. Mobile Cashflow
  await page.goto('https://smartstock-tax.vercel.app/#/cashflow-forecast');
  await page.waitForTimeout(4000);
  await page.screenshot({ path: path.join(OUTPUT_DIR, 'mobile_cashflow.png'), scale: 'css' });
  console.log('✓ Mobile Cashflow');

  // 9. Mobile Tax
  await page.goto('https://smartstock-tax.vercel.app/#/tax-estimate');
  await page.waitForTimeout(4000);
  await page.screenshot({ path: path.join(OUTPUT_DIR, 'mobile_tax.png'), scale: 'css' });
  console.log('✓ Mobile Tax');

  await browser.close();
  console.log('--- HOÀN TẤT TOÀN BỘ CHỤP ẢNH ---');
}

captureAll().catch(console.error);
