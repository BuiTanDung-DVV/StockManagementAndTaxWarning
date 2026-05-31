const http = require('http');

function apiCall(method, path, body = null, token = null, shopId = null) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    if (shopId) headers['x-shop-id'] = shopId;
    
    const options = {
      hostname: '127.0.0.1',
      port: 3000,
      path: `/api${path}`,
      method,
      headers,
    };
    
    const req = http.request(options, (res) => {
      let responseData = '';
      res.on('data', (chunk) => responseData += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(responseData);
          resolve({ status: res.statusCode, body: parsed });
        } catch {
          resolve({ status: res.statusCode, body: responseData });
        }
      });
    });
    
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

async function runTests() {
  const results = [];
  
  function log(tc, status, detail) {
    const icon = status === 'PASSED' ? '✅' : status === 'FAILED' ? '❌' : '⚠️';
    console.log(`${icon} ${tc}: ${status} - ${detail}`);
    results.push({ tc, status, detail });
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP 1: AUTH & ONBOARDING
  // ═══════════════════════════════════════════════════════════════
  console.log('\n═══ GROUP 1: AUTH & ONBOARDING ═══\n');

  // TC_LOGIN_001: Login with valid credentials
  let r = await apiCall('POST', '/auth/login', { username: '0988776655', password: '123456' });
  let token = null, shopId = null;
  if (r.status === 200 && r.body.success && r.body.data?.access_token) {
    token = r.body.data.access_token;
    shopId = r.body.data.shops?.[0]?.shopId;
    log('TC_LOGIN_001', 'PASSED', `Login OK, token received, shops: ${r.body.data.shops?.length}`);
  } else {
    log('TC_LOGIN_001', 'FAILED', `Status ${r.status}: ${JSON.stringify(r.body).substring(0, 200)}`);
  }

  // TC_LOGIN_002: Login with wrong password
  r = await apiCall('POST', '/auth/login', { username: '0988776655', password: 'wrongpass' });
  if (r.status === 401) {
    log('TC_LOGIN_002', 'PASSED', 'Invalid credentials correctly rejected with 401');
  } else {
    log('TC_LOGIN_002', 'FAILED', `Expected 401, got ${r.status}`);
  }

  // TC_LOGIN_EMPTY: Login with empty fields
  r = await apiCall('POST', '/auth/login', { username: '', password: '' });
  if (r.status === 401 || r.status === 400) {
    log('TC_LOGIN_EMPTY', 'PASSED', `Empty login rejected with ${r.status}`);
  } else {
    log('TC_LOGIN_EMPTY', 'FAILED', `Expected 401/400, got ${r.status}`);
  }

  // TC_LOGIN_003: Login with non-existent user
  r = await apiCall('POST', '/auth/login', { username: 'nonexistent_user_xyz', password: '123456' });
  if (r.status === 401) {
    log('TC_LOGIN_003', 'PASSED', 'Non-existent user rejected with 401');
  } else {
    log('TC_LOGIN_003', 'FAILED', `Expected 401, got ${r.status}`);
  }

  // TC_REG_EMPTY: Register with empty fields
  r = await apiCall('POST', '/auth/register', { username: '', password: '' });
  if (r.status >= 400) {
    log('TC_REG_EMPTY', 'PASSED', `Empty register rejected with ${r.status}: ${r.body.message}`);
  } else {
    log('TC_REG_EMPTY', 'FAILED', `Expected error, got ${r.status}`);
  }

  // TC_REG_DUP: Register with existing username
  r = await apiCall('POST', '/auth/register', { username: '0988776655', password: 'Test1234', accountType: 'SHOP' });
  if (r.status === 409) {
    log('TC_REG_DUP', 'PASSED', `Duplicate rejected with 409: ${r.body.message}`);
  } else {
    log('TC_REG_DUP', 'FAILED', `Expected 409, got ${r.status}: ${r.body.message}`);
  }

  // TC_OTP_SEND: Send OTP
  r = await apiCall('POST', '/auth/send-otp', { phone: '0909887766' });
  if (r.status === 200 && r.body.success) {
    log('TC_OTP_SEND', 'PASSED', `OTP sent, sandbox OTP: ${r.body.data?.otp}`);
  } else {
    log('TC_OTP_SEND', 'FAILED', `Status ${r.status}: ${r.body.message}`);
  }

  // TC_OTP_INVALID_FORMAT: Send OTP with invalid phone
  r = await apiCall('POST', '/auth/send-otp', { phone: 'abc' });
  if (r.status === 400) {
    log('TC_OTP_INVALID', 'PASSED', `Invalid phone rejected: ${r.body.message}`);
  } else {
    log('TC_OTP_INVALID', 'FAILED', `Expected 400, got ${r.status}`);
  }

  // TC_FP_EMPTY: Forgot password with empty
  r = await apiCall('POST', '/auth/forgot-password', { identifier: '' });
  if (r.status === 400) {
    log('TC_FP_EMPTY', 'PASSED', `Empty forgot-password rejected: ${r.body.message}`);
  } else {
    log('TC_FP_EMPTY', 'FAILED', `Expected 400, got ${r.status}: ${r.body.message}`);
  }

  // TC_FP_NOTFOUND: Forgot password with unknown user
  r = await apiCall('POST', '/auth/forgot-password', { identifier: '0000000000' });
  if (r.status === 404) {
    log('TC_FP_NOTFOUND', 'PASSED', `Unknown user rejected: ${r.body.message}`);
  } else {
    log('TC_FP_NOTFOUND', 'FAILED', `Expected 404, got ${r.status}: ${r.body.message}`);
  }

  // TC_REFRESH_INVALID: Refresh with bad token
  r = await apiCall('POST', '/auth/refresh-token', { refresh_token: 'invalid_token' });
  if (r.status === 401) {
    log('TC_REFRESH_INVALID', 'PASSED', `Invalid refresh token rejected`);
  } else {
    log('TC_REFRESH_INVALID', 'FAILED', `Expected 401, got ${r.status}`);
  }

  if (!token || !shopId) {
    console.log('\n⛔ Cannot proceed without valid token/shopId');
    return;
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP 2: PRODUCTS
  // ═══════════════════════════════════════════════════════════════
  console.log('\n═══ GROUP 2: PRODUCTS ═══\n');

  // TC_PROD_LIST: List products
  r = await apiCall('GET', '/products', null, token, shopId);
  if (r.status === 200) {
    const count = Array.isArray(r.body) ? r.body.length : r.body?.items?.length ?? '?';
    log('TC_PROD_LIST', 'PASSED', `Products listed: ${count} items`);
  } else {
    log('TC_PROD_LIST', 'FAILED', `Status ${r.status}`);
  }

  // TC_PROD_CREATE: Create a product
  const testProduct = {
    name: `QA Test Product ${Date.now()}`,
    sku: `QA-SKU-${Date.now()}`,
    barcode: `QA-BAR-${Date.now()}`,
    sellingPrice: 50000,
    unit: 'Cái',
    description: 'Test product from QA automation',
  };
  r = await apiCall('POST', '/products', testProduct, token, shopId);
  let productId = null;
  if (r.status === 200 || r.status === 201) {
    productId = r.body?.id;
    log('TC_PROD_CREATE', 'PASSED', `Product created with ID: ${productId}`);
  } else {
    log('TC_PROD_CREATE', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  // TC_PROD_DUP_SKU: Create product with duplicate SKU
  if (productId) {
    r = await apiCall('POST', '/products', { ...testProduct, barcode: `UNIQUE-${Date.now()}` }, token, shopId);
    if (r.status === 409 || r.status === 400 || r.status === 500) {
      log('TC_PROD_DUP_SKU', r.status === 409 ? 'PASSED' : 'FAILED', `Duplicate SKU: status ${r.status}, message: ${r.body?.message}`);
    } else {
      log('TC_PROD_DUP_SKU', 'FAILED', `Expected 409, got ${r.status}`);
    }
  }

  // TC_PROD_DETAIL: Get product detail
  if (productId) {
    r = await apiCall('GET', `/products/${productId}`, null, token, shopId);
    if (r.status === 200) {
      log('TC_PROD_DETAIL', 'PASSED', `Product detail fetched: ${r.body?.name}`);
    } else {
      log('TC_PROD_DETAIL', 'FAILED', `Status ${r.status}`);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP 3: CUSTOMERS
  // ═══════════════════════════════════════════════════════════════
  console.log('\n═══ GROUP 3: CUSTOMERS ═══\n');

  // TC_CUST_LIST: List customers
  r = await apiCall('GET', '/customers', null, token, shopId);
  if (r.status === 200) {
    const count = Array.isArray(r.body) ? r.body.length : '?';
    log('TC_CUST_LIST', 'PASSED', `Customers listed: ${count}`);
  } else {
    log('TC_CUST_LIST', 'FAILED', `Status ${r.status}`);
  }

  // TC_CUST_CREATE: Create customer
  const testCust = { name: `QA Customer ${Date.now()}`, phone: `09${Date.now().toString().slice(-8)}` };
  r = await apiCall('POST', '/customers', testCust, token, shopId);
  let customerId = null;
  if (r.status === 200 || r.status === 201) {
    customerId = r.body?.id;
    log('TC_CUST_CREATE', 'PASSED', `Customer created ID: ${customerId}`);
  } else {
    log('TC_CUST_CREATE', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP 4: SUPPLIERS
  // ═══════════════════════════════════════════════════════════════
  console.log('\n═══ GROUP 4: SUPPLIERS ═══\n');

  r = await apiCall('GET', '/suppliers', null, token, shopId);
  if (r.status === 200) {
    log('TC_SUPP_LIST', 'PASSED', `Suppliers listed`);
  } else {
    log('TC_SUPP_LIST', 'FAILED', `Status ${r.status}`);
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP 5: INVENTORY
  // ═══════════════════════════════════════════════════════════════
  console.log('\n═══ GROUP 5: INVENTORY ═══\n');

  r = await apiCall('GET', '/inventory/stocks', null, token, shopId);
  if (r.status === 200) {
    log('TC_INV_STOCKS', 'PASSED', `Inventory stocks fetched`);
  } else {
    log('TC_INV_STOCKS', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/inventory/low-stock', null, token, shopId);
  if (r.status === 200) {
    log('TC_INV_LOWSTOCK', 'PASSED', `Low stock items fetched`);
  } else {
    log('TC_INV_LOWSTOCK', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/inventory/purchase-orders', null, token, shopId);
  if (r.status === 200) {
    log('TC_INV_PO_LIST', 'PASSED', `Purchase orders listed`);
  } else {
    log('TC_INV_PO_LIST', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP 6: SALES
  // ═══════════════════════════════════════════════════════════════
  console.log('\n═══ GROUP 6: SALES ═══\n');

  r = await apiCall('GET', '/sales-orders', null, token, shopId);
  if (r.status === 200) {
    log('TC_SALES_LIST', 'PASSED', `Sales orders listed`);
  } else {
    log('TC_SALES_LIST', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/sales-orders/summary?from=2026-01-01&to=2026-12-31', null, token, shopId);
  if (r.status === 200) {
    log('TC_SALES_SUMMARY', 'PASSED', `Sales summary: revenue=${r.body?.totalRevenue}, orders=${r.body?.totalOrders}`);
  } else {
    log('TC_SALES_SUMMARY', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  // TC_POS_CREATE: Create a POS order (cash payment)
  if (productId) {
    const posOrder = {
      items: [{ productId, quantity: 1, unitPrice: 50000 }],
      paymentMethod: 'CASH',
      totalAmount: 50000,
    };
    r = await apiCall('POST', '/sales-orders', posOrder, token, shopId);
    let orderId = null;
    if (r.status === 200 || r.status === 201) {
      orderId = r.body?.id;
      log('TC_POS_CREATE', 'PASSED', `Order created ID: ${orderId}`);
    } else {
      log('TC_POS_CREATE', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
    }

    // TC_POS_DETAIL: Get order detail
    if (orderId) {
      r = await apiCall('GET', `/sales-orders/${orderId}`, null, token, shopId);
      if (r.status === 200) {
        log('TC_POS_DETAIL', 'PASSED', `Order detail fetched, status: ${r.body?.status}`);
      } else {
        log('TC_POS_DETAIL', 'FAILED', `Status ${r.status}`);
      }

      // TC_RETURN: Create return
      r = await apiCall('POST', `/sales-orders/${orderId}/returns`, { reason: 'QA Test Return', refundAmount: 50000, refundMethod: 'CASH', items: [{ productId, quantity: 1 }] }, token, shopId);
      if (r.status === 200 || r.status === 201) {
        log('TC_RETURN_CREATE', 'PASSED', `Return created successfully`);
      } else {
        log('TC_RETURN_CREATE', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP 7: FINANCE
  // ═══════════════════════════════════════════════════════════════
  console.log('\n═══ GROUP 7: FINANCE ═══\n');

  r = await apiCall('GET', '/cash-transactions?from=2026-01-01&to=2026-12-31', null, token, shopId);
  if (r.status === 200) {
    log('TC_FIN_CASH_TX', 'PASSED', `Cash transactions fetched`);
  } else {
    log('TC_FIN_CASH_TX', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/cash-transactions/profit-loss?from=2026-01-01&to=2026-12-31', null, token, shopId);
  if (r.status === 200) {
    log('TC_FIN_PNL', 'PASSED', `P&L report fetched`);
  } else {
    log('TC_FIN_PNL', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/daily-closings', null, token, shopId);
  if (r.status === 200) {
    log('TC_FIN_CLOSINGS', 'PASSED', `Daily closings listed`);
  } else {
    log('TC_FIN_CLOSINGS', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/cash-accounts', null, token, shopId);
  if (r.status === 200) {
    log('TC_FIN_ACCOUNTS', 'PASSED', `Cash accounts fetched`);
  } else {
    log('TC_FIN_ACCOUNTS', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/invoices', null, token, shopId);
  if (r.status === 200) {
    log('TC_FIN_INVOICES', 'PASSED', `Invoices listed`);
  } else {
    log('TC_FIN_INVOICES', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/tax-obligations', null, token, shopId);
  if (r.status === 200) {
    log('TC_FIN_TAX_OBL', 'PASSED', `Tax obligations listed`);
  } else {
    log('TC_FIN_TAX_OBL', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/purchases-without-invoice', null, token, shopId);
  if (r.status === 200) {
    log('TC_FIN_NO_INV', 'PASSED', `Purchases without invoice listed`);
  } else {
    log('TC_FIN_NO_INV', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP 8: TAX
  // ═══════════════════════════════════════════════════════════════
  console.log('\n═══ GROUP 8: TAX ═══\n');

  r = await apiCall('GET', '/tax/config', null, token, shopId);
  if (r.status === 200) {
    log('TC_TAX_CONFIG', 'PASSED', `Tax config: sector=${r.body?.businessSector}, vatReduction=${r.body?.applyVatReduction}`);
  } else {
    log('TC_TAX_CONFIG', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/tax/estimate?from=2026-01-01&to=2026-12-31', null, token, shopId);
  if (r.status === 200) {
    log('TC_TAX_ESTIMATE', 'PASSED', `Tax estimate fetched`);
  } else {
    log('TC_TAX_ESTIMATE', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/tax/export-htkk?from=2026-01-01&to=2026-12-31', null, token, shopId);
  if (r.status === 200) {
    const isXml = typeof r.body === 'string' && r.body.includes('HSoKhaiThue');
    log('TC_TAX_HTKK', isXml ? 'PASSED' : 'FAILED', `HTKK export: ${isXml ? 'Valid XML' : 'Not XML format'}`);
  } else {
    log('TC_TAX_HTKK', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP 9: SYSTEM & SETTINGS
  // ═══════════════════════════════════════════════════════════════
  console.log('\n═══ GROUP 9: SYSTEM & SETTINGS ═══\n');

  r = await apiCall('GET', '/my-shops', null, token);
  if (r.status === 200) {
    log('TC_MY_SHOPS', 'PASSED', `My shops fetched: ${Array.isArray(r.body) ? r.body.length : '?'} shops`);
  } else {
    log('TC_MY_SHOPS', 'FAILED', `Status ${r.status}`);
  }

  r = await apiCall('GET', '/activity-logs', null, token, shopId);
  if (r.status === 200) {
    log('TC_ACTIVITY_LOGS', 'PASSED', `Activity logs fetched`);
  } else {
    log('TC_ACTIVITY_LOGS', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/notifications', null, token);
  if (r.status === 200) {
    log('TC_NOTIFICATIONS', 'PASSED', `Notifications fetched`);
  } else {
    log('TC_NOTIFICATIONS', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/shop-profile', null, token, shopId);
  if (r.status === 200) {
    log('TC_SHOP_PROFILE', 'PASSED', `Shop profile fetched: ${r.body?.shopName}`);
  } else {
    log('TC_SHOP_PROFILE', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/shop-roles', null, token, shopId);
  if (r.status === 200) {
    log('TC_SHOP_ROLES', 'PASSED', `Shop roles listed`);
  } else {
    log('TC_SHOP_ROLES', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  r = await apiCall('GET', '/shop-members', null, token, shopId);
  if (r.status === 200) {
    log('TC_SHOP_MEMBERS', 'PASSED', `Shop members listed`);
  } else {
    log('TC_SHOP_MEMBERS', 'FAILED', `Status ${r.status}: ${r.body?.message}`);
  }

  // ═══════════════════════════════════════════════════════════════
  // GROUP 10: SECURITY - Unauthenticated access
  // ═══════════════════════════════════════════════════════════════
  console.log('\n═══ GROUP 10: SECURITY ═══\n');

  r = await apiCall('GET', '/products', null, null, null);
  if (r.status === 401 || r.status === 403) {
    log('TC_SEC_NOAUTH', 'PASSED', `Unauthenticated request blocked: ${r.status}`);
  } else {
    log('TC_SEC_NOAUTH', 'FAILED', `Expected 401/403, got ${r.status}`);
  }

  r = await apiCall('GET', '/sales-orders', null, 'invalid.jwt.token', shopId);
  if (r.status === 401 || r.status === 403) {
    log('TC_SEC_BADTOKEN', 'PASSED', `Bad token rejected: ${r.status}`);
  } else {
    log('TC_SEC_BADTOKEN', 'FAILED', `Expected 401/403, got ${r.status}`);
  }

  // ═══════════════════════════════════════════════════════════════
  // SUMMARY
  // ═══════════════════════════════════════════════════════════════
  console.log('\n═══════════════════════════════════════════');
  console.log('           TEST EXECUTION SUMMARY');
  console.log('═══════════════════════════════════════════');
  const passed = results.filter(r => r.status === 'PASSED').length;
  const failed = results.filter(r => r.status === 'FAILED').length;
  console.log(`Total: ${results.length} | ✅ Passed: ${passed} | ❌ Failed: ${failed}`);
  console.log('═══════════════════════════════════════════\n');
  
  if (failed > 0) {
    console.log('FAILED TESTS:');
    results.filter(r => r.status === 'FAILED').forEach(r => {
      console.log(`  ❌ ${r.tc}: ${r.detail}`);
    });
  }
}

runTests().catch(console.error);
