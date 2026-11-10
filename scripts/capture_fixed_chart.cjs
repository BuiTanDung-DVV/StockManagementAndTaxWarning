const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

const OUTPUT_DIR = path.resolve('.playwright-mcp');
const ARTIFACT_DIR = 'C:/Users/tandu/.gemini/antigravity/brain/26301458-475e-4303-bb0a-1942a7addb00';

async function capture() {
  const browser = await chromium.launch({
    channel: 'msedge',
    headless: true,
  });

  const page = await browser.newPage({
    viewport: { width: 390, height: 844 },
  });

  console.log('1. Đăng nhập...');
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
  await page.waitForTimeout(3000);

  console.log('2. Mở trang sales trên mobile...');
  await page.goto('http://127.0.0.1:8080/#/sales');
  
  // Đợi cho đến khi text "Doanh thu" xuất hiện trong semantics (nghĩa là đã load xong data)
  console.log('3. Đợi data load hoàn tất...');
  await page.waitForFunction(() => {
    return document.body.innerText.includes('Doanh thu & LN gộp') || 
           document.body.innerText.includes('Doanh thu & lợi nhuận') ||
           document.body.innerText.includes('Doanh thu thuần');
  }, { timeout: 30000 }).catch(() => console.log('Timeout waiting for text, proceeding...'));
  
  await page.waitForTimeout(4000);

  const shotPath = path.join(OUTPUT_DIR, 'chart_fixed_mobile.png');
  await page.screenshot({ path: shotPath, scale: 'css' });
  console.log('✓ Chụp ảnh chart_fixed_mobile.png');

  await browser.close();

  const dest = path.join(ARTIFACT_DIR, 'chart_fixed_mobile.png');
  fs.copyFileSync(shotPath, dest);
  console.log('✓ Đã sao chép sang artifact:', dest);
}

capture().catch(err => {
  console.error(err);
  process.exit(1);
});
