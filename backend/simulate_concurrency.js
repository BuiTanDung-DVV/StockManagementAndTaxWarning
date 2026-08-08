/**
 * Concurrency & Business Logic Simulation Test
 * File: backend/simulate_concurrency.js
 */

const { Client } = require('pg');
const { randomBytes } = require('crypto');
require('dotenv').config();

const BASE_URL = 'https://stock-management-and-tax-warning.vercel.app/api';
const DB_CONNECTION_STRING = process.env.DATABASE_URL;
const OWNER_USERNAME = process.env.SIM_OWNER_USERNAME;
const OWNER_PASSWORD = process.env.SIM_OWNER_PASSWORD;
if (!DB_CONNECTION_STRING || !OWNER_USERNAME || !OWNER_PASSWORD) {
  throw new Error('DATABASE_URL, SIM_OWNER_USERNAME and SIM_OWNER_PASSWORD are required');
}
const SHOP_ID = 34; // Cửa Hàng VLXD & Nội Thất Kiến Tạo
const SHOP_CODE = 'VL01';

// Generate timestamp for uniqueness
const timestamp = Date.now();
const generatedPassword = randomBytes(24).toString('base64url');

// Generate employee emails
const emails = {
  cashier: `sim_cashier_${timestamp}@vlxd.com`,
  storekeeper: `sim_storekeeper_${timestamp}@vlxd.com`,
  manager: `sim_manager_${timestamp}@vlxd.com`
};

const usersData = {
  cashier: {
    username: emails.cashier,
    email: emails.cashier,
    password: generatedPassword,
    fullName: `Simulated Cashier ${timestamp}`
  },
  storekeeper: {
    username: emails.storekeeper,
    email: emails.storekeeper,
    password: generatedPassword,
    fullName: `Simulated Storekeeper ${timestamp}`
  },
  manager: {
    username: emails.manager,
    email: emails.manager,
    password: generatedPassword,
    fullName: `Simulated Manager ${timestamp}`
  }
};

async function getLatestOtpFromDb(email) {
  const client = new Client({ connectionString: DB_CONNECTION_STRING });
  try {
    await client.connect();
    const res = await client.query(
      "SELECT otp_code FROM otps WHERE phone = $1 ORDER BY created_at DESC LIMIT 1",
      [email]
    );
    if (res.rows.length === 0) {
      throw new Error(`No OTP found for ${email}`);
    }
    return res.rows[0].otp_code;
  } finally {
    await client.end();
  }
}

async function request(endpoint, options = {}) {
  const url = `${BASE_URL}${endpoint}`;
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options.headers
    }
  });

  const text = await response.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch (e) {
    json = { success: false, raw: text };
  }

  return {
    status: response.status,
    ok: response.ok,
    data: json
  };
}

async function main() {
  console.log('=== STARTING CONCURRENCY & BUSINESS LOGIC SIMULATION ===');
  console.log(`Generated Emails:\n- Cashier: ${emails.cashier}\n- Storekeeper: ${emails.storekeeper}\n- Manager: ${emails.manager}\n`);

  // -------------------------------------------------------------
  // Phase 1 & 2: Registration & OTP Verification
  // -------------------------------------------------------------
  console.log('--- Phase 1 & 2: Sending OTP & Registering Employees ---');
  const tokens = {};
  const memberRequestIds = {};

  for (const role of ['cashier', 'storekeeper', 'manager']) {
    const user = usersData[role];
    console.log(`[${role.toUpperCase()}] Sending OTP to ${user.email}...`);
    
    // Call send-otp
    const otpRes = await request('/auth/send-otp', {
      method: 'POST',
      body: JSON.stringify({ identifier: user.email })
    });
    
    if (!otpRes.ok) {
      throw new Error(`Failed to send OTP for ${role}: ${JSON.stringify(otpRes.data)}`);
    }
    console.log(`[${role.toUpperCase()}] OTP sent successfully.`);

    // Fetch OTP from DB
    console.log(`[${role.toUpperCase()}] Fetching OTP from DB...`);
    const otpCode = await getLatestOtpFromDb(user.email);
    console.log(`[${role.toUpperCase()}] Fetched OTP: ${otpCode}`);

    // Call register
    console.log(`[${role.toUpperCase()}] Completing registration with OTP...`);
    const regRes = await request('/auth/register', {
      method: 'POST',
      body: JSON.stringify({
        username: user.username,
        password: user.password,
        otpCode: otpCode,
        fullName: user.fullName
      })
    });

    if (!regRes.ok) {
      throw new Error(`Registration failed for ${role}: ${JSON.stringify(regRes.data)}`);
    }
    console.log(`[${role.toUpperCase()}] Registered successfully!`);

    // Log in to get initial token
    console.log(`[${role.toUpperCase()}] Logging in...`);
    const loginRes = await request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        username: user.username,
        password: user.password
      })
    });

    if (!loginRes.ok) {
      throw new Error(`Login failed for ${role}: ${JSON.stringify(loginRes.data)}`);
    }
    
    tokens[role] = loginRes.data.data.access_token;
    console.log(`[${role.toUpperCase()}] Logged in. Token retrieved.\n`);
  }

  // -------------------------------------------------------------
  // Phase 3: Search and Join Shop
  // -------------------------------------------------------------
  console.log('--- Phase 3: Search and Request to Join Shop ---');
  for (const role of ['cashier', 'storekeeper', 'manager']) {
    console.log(`[${role.toUpperCase()}] Searching for shop code '${SHOP_CODE}'...`);
    const searchRes = await request(`/shops/search?q=${SHOP_CODE}`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${tokens[role]}` }
    });

    if (!searchRes.ok || searchRes.data.data.length === 0) {
      throw new Error(`Shop search failed or shop not found for ${role}: ${JSON.stringify(searchRes.data)}`);
    }

    const shop = searchRes.data.data.find(s => s.shopCode === SHOP_CODE || s.id === SHOP_ID);
    if (!shop) {
      throw new Error(`Target shop with code ${SHOP_CODE} / ID ${SHOP_ID} not found in search results.`);
    }

    console.log(`[${role.toUpperCase()}] Found shop: "${shop.shopName}" (ID: ${shop.id}). Submitting join request...`);
    
    const joinRes = await request('/shop-members/request-join', {
      method: 'POST',
      headers: { Authorization: `Bearer ${tokens[role]}` },
      body: JSON.stringify({ shopId: shop.id })
    });

    if (!joinRes.ok) {
      throw new Error(`Join request failed for ${role}: ${JSON.stringify(joinRes.data)}`);
    }

    memberRequestIds[role] = joinRes.data.data.id;
    console.log(`[${role.toUpperCase()}] Join request submitted. Member Request ID: ${memberRequestIds[role]}\n`);
  }

  // -------------------------------------------------------------
  // Phase 4: Approval by Owner & Role Assignment
  // -------------------------------------------------------------
  console.log('--- Phase 4: Owner Log in, Retrieve and Approve Requests ---');
  
  // Log in as Owner
  console.log('Logging in as Owner...');
  const ownerLoginRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      username: OWNER_USERNAME,
      password: OWNER_PASSWORD
    })
  });

  if (!ownerLoginRes.ok) {
    throw new Error(`Owner login failed: ${JSON.stringify(ownerLoginRes.data)}`);
  }
  
  const ownerToken = ownerLoginRes.data.data.access_token;
  tokens.owner = ownerToken;
  console.log('Owner logged in.');

  // Retrieve pending requests
  console.log('Retrieving pending join requests (checking for known bug)...');
  const pendingRes = await request('/shop-members/pending', {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${ownerToken}`,
      'x-shop-id': String(SHOP_ID)
    }
  });

  if (!pendingRes.ok) {
    console.log(`[BUG DETECTED] Failed to fetch pending requests: ${JSON.stringify(pendingRes.data.message)}`);
    console.log('Falling back to stored join request IDs from Phase 3...');
  } else {
    console.log(`Found ${pendingRes.data.data.length} pending requests.`);
  }

  // Approve each request
  for (const role of ['cashier', 'storekeeper', 'manager']) {
    const memberId = memberRequestIds[role];
    console.log(`Approving request ID ${memberId} for ${role}...`);
    
    const approveRes = await request(`/shop-members/${memberId}/approve`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${ownerToken}`,
        'x-shop-id': String(SHOP_ID)
      }
    });

    if (!approveRes.ok) {
      throw new Error(`Failed to approve ${role} (ID ${memberId}): ${JSON.stringify(approveRes.data)}`);
    }
    console.log(`Request ID ${memberId} approved.`);
  }

  // Fetch shop roles to find the IDs dynamically
  console.log('\nFetching shop roles...');
  const rolesRes = await request('/shop-roles', {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${ownerToken}`,
      'x-shop-id': String(SHOP_ID)
    }
  });

  if (!rolesRes.ok) {
    throw new Error(`Failed to retrieve shop roles: ${JSON.stringify(rolesRes.data)}`);
  }

  const shopRoles = rolesRes.data.data;
  console.log('Shop roles retrieved:', shopRoles.map(r => ({ id: r.id, name: r.name })));

  const roleMappings = {
    manager: shopRoles.find(r => r.name.toLowerCase().includes('manager') || r.name.toLowerCase().includes('quản lý')),
    cashier: shopRoles.find(r => r.name.toLowerCase().includes('sales') || r.name.toLowerCase().includes('bán hàng')),
    storekeeper: shopRoles.find(r => r.name.toLowerCase().includes('warehouse') || r.name.toLowerCase().includes('thủ kho'))
  };

  // Adjust Sales Role permissions dynamically to include the "sales" permission key
  const salesRole = roleMappings.cashier;
  if (salesRole) {
    console.log(`Upgrading Sales Role (ID ${salesRole.id}) permissions to include "sales": "full"...`);
    const upgradeRes = await request(`/shop-roles/${salesRole.id}`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${ownerToken}`,
        'x-shop-id': String(SHOP_ID)
      },
      body: JSON.stringify({
        name: 'Sales',
        permissions: {
          pos: 'full',
          products: 'view',
          customers: 'full',
          sales: 'full'
        }
      })
    });
    if (!upgradeRes.ok) {
      throw new Error(`Failed to upgrade Sales Role permissions: ${JSON.stringify(upgradeRes.data)}`);
    }
    console.log('Sales Role permissions successfully updated.');
  }

  for (const role of ['cashier', 'storekeeper', 'manager']) {
    const targetRole = roleMappings[role];
    if (!targetRole) {
      throw new Error(`Could not find a matching role for ${role}`);
    }
    const memberId = memberRequestIds[role];
    console.log(`Assigning role "${targetRole.name}" (ID ${targetRole.id}) to member ID ${memberId}...`);
    
    const roleAssignRes = await request(`/shop-members/${memberId}/role`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${ownerToken}`,
        'x-shop-id': String(SHOP_ID)
      },
      body: JSON.stringify({ roleId: targetRole.id })
    });

    if (!roleAssignRes.ok) {
      throw new Error(`Failed to assign role to ${role}: ${JSON.stringify(roleAssignRes.data)}`);
    }
    console.log(`Role assigned successfully.\n`);
  }

  // -------------------------------------------------------------
  // Phase 5: Concurrent Operations (Data Sync)
  // -------------------------------------------------------------
  console.log('--- Phase 5: Concurrent Operations (Data Sync) ---');
  
  // Re-login employees to refresh their tokens/claims with shop scope
  console.log('Refreshing employee tokens by logging in again...');
  for (const role of ['cashier', 'storekeeper', 'manager']) {
    const user = usersData[role];
    const loginRes = await request('/auth/login', {
      method: 'POST',
      body: JSON.stringify({
        username: user.username,
        password: user.password
      })
    });
    if (!loginRes.ok) {
      throw new Error(`Re-login failed for ${role}: ${JSON.stringify(loginRes.data)}`);
    }
    tokens[role] = loginRes.data.data.access_token;
  }
  console.log('Tokens refreshed.');

  // Fetch initial Owner dashboard revenue to establish baseline
  console.log('Fetching initial Owner revenue dashboard summary...');
  const initRevenueRes = await request('/sales-orders/summary', {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${ownerToken}`,
      'x-shop-id': String(SHOP_ID)
    }
  });
  if (!initRevenueRes.ok) {
    throw new Error(`Failed to get initial revenue summary: ${JSON.stringify(initRevenueRes.data)}`);
  }
  const initialRevenue = Number(initRevenueRes.data.data.totalRevenue || 0);
  console.log(`Initial Owner Dashboard Revenue: ${initialRevenue} VND\n`);

  // Target Product IDs
  const saleProductId = 673; // Gạch lát nền - Đồng Tâm 80x80 (Thùng)
  const stockTakeProductId = 666; // Xi măng - Hà Tiên Đa Dụng (Bao 50kg)
  const tagProductId = 677; // Ống nhựa PVC - Bình Minh Phi 27 (Cây)
  const tagColor = '#10B981';
  const tagName = `sim_tag_${timestamp}`;

  console.log('Running concurrent operations in parallel...');

  const concurrentResults = await Promise.allSettled([
    // 1. Cashier flow: Create customer, then create sales invoice for 50,000 VND
    (async () => {
      console.log('[CONCURRENT: Cashier] Creating a new customer...');
      const customerRes = await request('/customers', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${tokens.cashier}`,
          'x-shop-id': String(SHOP_ID)
        },
        body: JSON.stringify({
          name: `Simulated Customer ${timestamp}`,
          phone: `09${String(timestamp).slice(-8)}`,
          address: '123 Test St'
        })
      });

      if (!customerRes.ok) {
        throw new Error(`Cashier failed to create customer: ${JSON.stringify(customerRes.data)}`);
      }
      
      const customerId = customerRes.data.data.id;
      console.log(`[CONCURRENT: Cashier] Customer created with ID ${customerId}. Creating sales invoice...`);

      const orderRes = await request('/sales-orders', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${tokens.cashier}`,
          'x-shop-id': String(SHOP_ID)
        },
        body: JSON.stringify({
          customerId: customerId,
          items: [
            {
              productId: saleProductId,
              quantity: 1,
              unitPrice: 50000
            }
          ],
          paymentMethod: 'CASH',
          paidAmount: 50000,
          status: 'COMPLETED'
        })
      });

      if (!orderRes.ok) {
        throw new Error(`Cashier failed to create sales order: ${JSON.stringify(orderRes.data)}`);
      }
      console.log('[CONCURRENT: Cashier] Sales order created successfully for 50,000 VND.');
      return { customerId, orderId: orderRes.data.data.id };
    })(),

    // 2. Storekeeper flow: Create stock take with discrepancy and commit it
    (async () => {
      console.log('[CONCURRENT: Storekeeper] Creating stock take...');
      const stockTakeRes = await request('/stock-takes', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${tokens.storekeeper}`,
          'x-shop-id': String(SHOP_ID)
        },
        body: JSON.stringify({
          status: 'DRAFT',
          stockTakeDate: new Date().toISOString(),
          notes: `Simulated stock take discrepancy ${timestamp}`,
          items: [
            {
              productId: stockTakeProductId,
              systemQty: 0,
              actualQty: 50,
              notes: 'Found missing stocks'
            }
          ]
        })
      });

      if (!stockTakeRes.ok) {
        throw new Error(`Storekeeper failed to create stock take: ${JSON.stringify(stockTakeRes.data)}`);
      }

      const stockTakeId = stockTakeRes.data.data.id;
      console.log(`[CONCURRENT: Storekeeper] Stock take created (ID ${stockTakeId}). Committing stock take...`);

      const commitRes = await request(`/stock-takes/${stockTakeId}`, {
        method: 'PUT',
        headers: {
          Authorization: `Bearer ${tokens.storekeeper}`,
          'x-shop-id': String(SHOP_ID)
        },
        body: JSON.stringify({
          status: 'COMPLETED'
        })
      });

      if (!commitRes.ok) {
        throw new Error(`Storekeeper failed to commit stock take: ${JSON.stringify(commitRes.data)}`);
      }
      console.log('[CONCURRENT: Storekeeper] Stock take committed. Stock levels adjusted.');
      return { stockTakeId };
    })(),

    // 3. Manager flow: Create tag, link to product, and filter products by tag
    (async () => {
      console.log('[CONCURRENT: Manager] Creating tag...');
      const tagRes = await request('/tags', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${tokens.manager}`,
          'x-shop-id': String(SHOP_ID)
        },
        body: JSON.stringify({
          name: tagName,
          color: tagColor,
          type: 'product'
        })
      });

      if (!tagRes.ok) {
        throw new Error(`Manager failed to create tag: ${JSON.stringify(tagRes.data)}`);
      }

      console.log(`[CONCURRENT: Manager] Tag "${tagName}" created. Linking to product ID ${tagProductId}...`);

      const linkRes = await request(`/products/${tagProductId}`, {
        method: 'PUT',
        headers: {
          Authorization: `Bearer ${tokens.manager}`,
          'x-shop-id': String(SHOP_ID)
        },
        body: JSON.stringify({
          tags: [tagName]
        })
      });

      if (!linkRes.ok) {
        throw new Error(`Manager failed to link tag: ${JSON.stringify(linkRes.data)}`);
      }

      console.log(`[CONCURRENT: Manager] Tag linked. Filtering products by tag "${tagName}"...`);

      const filterRes = await request(`/products?tag=${tagName}`, {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${tokens.manager}`,
          'x-shop-id': String(SHOP_ID)
        }
      });

      if (!filterRes.ok) {
        throw new Error(`Manager failed to filter by tag: ${JSON.stringify(filterRes.data)}`);
      }

      console.log('[CONCURRENT: Manager] Products successfully filtered by tag.');
      return { filtered: filterRes.data.data.items };
    })(),

    // 4. Owner flow: Poll dashboard revenue summary and stock counts
    (async () => {
      console.log('[CONCURRENT: Owner] Polling dashboard revenue summary...');
      const revenuePoll = await request('/sales-orders/summary', {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${tokens.owner}`,
          'x-shop-id': String(SHOP_ID)
        }
      });

      console.log('[CONCURRENT: Owner] Polling stock levels...');
      const stockPoll = await request('/inventory/stock', {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${tokens.owner}`,
          'x-shop-id': String(SHOP_ID)
        }
      });

      return {
        revenuePollOk: revenuePoll.ok,
        stockPollOk: stockPoll.ok
      };
    })()
  ]);

  // Log errors if any concurrent operation failed
  console.log('\nConcurrent operations results:');
  concurrentResults.forEach((res, i) => {
    if (res.status === 'rejected') {
      console.error(`Operation ${i + 1} failed:`, res.reason.message || res.reason);
    } else {
      console.log(`Operation ${i + 1} completed successfully.`);
    }
  });

  // Verify Data Sync results
  console.log('\n--- Verifying Data Sync ---');
  
  // Verification 1: Revenue increase
  console.log('Fetching final Owner revenue dashboard summary...');
  const finalRevenueRes = await request('/sales-orders/summary', {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${ownerToken}`,
      'x-shop-id': String(SHOP_ID)
    }
  });
  const finalRevenue = Number(finalRevenueRes.data.data.totalRevenue || 0);
  const revenueDiff = finalRevenue - initialRevenue;
  console.log(`Final Owner Dashboard Revenue: ${finalRevenue} VND (Diff: ${revenueDiff} VND)`);
  
  if (revenueDiff !== 50000) {
    console.error(`❌ ERROR: Revenue difference is ${revenueDiff} VND, expected exactly 50000 VND.`);
  } else {
    console.log(`✅ SUCCESS: Cashier's invoice amount is instantly reflected in Owner's revenue dashboard.`);
  }

  // Verification 2: Storekeeper stock update visible to Cashier/Owner
  console.log(`Checking stock level of product ID ${stockTakeProductId} from Cashier's view...`);
  const cashierProductView = await request(`/products/${stockTakeProductId}`, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${tokens.cashier}`,
      'x-shop-id': String(SHOP_ID)
    }
  });
  
  const cashierStock = Number(cashierProductView.data.data.currentStock ?? cashierProductView.data.data.stock ?? 0);
  console.log(`Cashier views stock of product ID ${stockTakeProductId}: ${cashierStock}`);

  console.log(`Checking stock level of product ID ${stockTakeProductId} from Owner's view...`);
  const ownerInventoryView = await request('/inventory/stock', {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${tokens.owner}`,
      'x-shop-id': String(SHOP_ID)
    }
  });
  
  const ownerStockRecord = ownerInventoryView.data.data.items ? ownerInventoryView.data.data.items.find(s => s.productId === stockTakeProductId) : null;
  const ownerStock = ownerStockRecord ? Number(ownerStockRecord.quantity || 0) : 0;
  console.log(`Owner views stock of product ID ${stockTakeProductId}: ${ownerStock}`);

  if (cashierStock !== 50 || ownerStock !== 50) {
    console.error(`❌ ERROR: Expected stock to be 50. Cashier saw ${cashierStock}, Owner saw ${ownerStock}.`);
  } else {
    console.log(`✅ SUCCESS: Storekeeper's stock levels are successfully updated and visible to Cashier and Owner.`);
  }

  // -------------------------------------------------------------
  // Phase 6: Permission Boundary Validation
  // -------------------------------------------------------------
  console.log('\n--- Phase 6: Permission Boundary Validation ---');
  const restrictedEndpoints = [
    '/shop-members',
    '/tax/config',
    '/tax/estimate',
    '/cash-transactions/profit-loss',
    '/tax/export-htkk'
  ];

  // Verify Cashier and Storekeeper are BLOCKED
  for (const role of ['cashier', 'storekeeper']) {
    console.log(`\nTesting permission boundaries for ${role.toUpperCase()} (expecting 403 or 401)...`);
    for (const ep of restrictedEndpoints) {
      const res = await request(ep, {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${tokens[role]}`,
          'x-shop-id': String(SHOP_ID)
        }
      });
      console.log(`GET ${ep} -> Status: ${res.status} (ok: ${res.ok})`);
      if (res.status !== 403 && res.status !== 401) {
        console.error(`❌ SECURITY BREACH: ${role.toUpperCase()} was able to access ${ep} with status ${res.status}!`);
      } else {
        console.log(`✅ Blocked successfully (Status: ${res.status}).`);
      }
    }
  }

  // Verify Owner and Manager are ALLOWED to settings & reports
  console.log('\nTesting permission boundaries for OWNER (expecting 200 OK)...');
  const ownerEndpoints = [
    '/shop-profile',
    '/tax/config',
    '/tax/estimate',
    '/cash-transactions/profit-loss',
    '/tax/export-htkk'
  ];
  for (const ep of ownerEndpoints) {
    const res = await request(ep, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${tokens.owner}`,
        'x-shop-id': String(SHOP_ID)
      }
    });
    console.log(`GET ${ep} -> Status: ${res.status} (ok: ${res.ok})`);
    if (!res.ok) {
      console.error(`❌ ERROR: Owner was blocked from accessing ${ep}!`);
    } else {
      console.log(`✅ Owner accessed ${ep} successfully.`);
    }
  }

  console.log('\nTesting permission boundaries for MANAGER (expecting 200 OK for reports)...');
  const managerEndpoints = [
    '/tax/config',
    '/tax/estimate',
    '/cash-transactions/profit-loss',
    '/tax/export-htkk'
  ];
  for (const ep of managerEndpoints) {
    const res = await request(ep, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${tokens.manager}`,
        'x-shop-id': String(SHOP_ID)
      }
    });
    console.log(`GET ${ep} -> Status: ${res.status} (ok: ${res.ok})`);
    if (!res.ok) {
      console.error(`❌ ERROR: Manager was blocked from accessing ${ep}!`);
    } else {
      console.log(`✅ Manager accessed ${ep} successfully.`);
    }
  }

  // -------------------------------------------------------------
  // Phase 7: Input Boundary Scan (Validation checks)
  // -------------------------------------------------------------
  console.log('\n--- Phase 7: Input Boundary Scan ---');
  
  // 1. Empty password login
  console.log('Submitting login with empty password (expecting 401)...');
  const emptyPwdRes = await request('/auth/login', {
    method: 'POST',
    body: JSON.stringify({
      username: 'admin@kientao.com',
      password: ''
    })
  });
  console.log(`Status: ${emptyPwdRes.status}, Message: ${emptyPwdRes.data.message}`);
  if (emptyPwdRes.status === 500) {
    console.error('❌ ERROR: Empty password crashed the server with 500!');
  } else if (emptyPwdRes.status === 401) {
    console.log('✅ Success: Login rejected with 401 Unauthorized.');
  } else {
    console.log(`⚠️ Note: Received status ${emptyPwdRes.status}`);
  }

  // 2. Negative price in sales order
  console.log('\nSubmitting sales order with negative price (expecting 400)...');
  const negPriceRes = await request('/sales-orders', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${tokens.cashier}`,
      'x-shop-id': String(SHOP_ID)
    },
    body: JSON.stringify({
      customerId: 1, // Any customer
      items: [
        {
          productId: saleProductId,
          quantity: 1,
          unitPrice: -50000
        }
      ],
      paymentMethod: 'CASH',
      paidAmount: -50000,
      status: 'COMPLETED'
    })
  });
  console.log(`Status: ${negPriceRes.status}, Message: ${negPriceRes.data.message}`);
  if (negPriceRes.status === 500) {
    console.error('❌ ERROR: Negative price crashed the server with 500!');
  } else if (negPriceRes.status === 400) {
    console.log('✅ Success: Negative price rejected with 400 Bad Request.');
  } else {
    console.log(`⚠️ Note: Received status ${negPriceRes.status}`);
  }

  // 3. Duplicate barcode creation
  console.log('\nSubmitting product creation with duplicate barcode (expecting 409)...');
  const tempBarcode = `bar_${timestamp}`;
  
  // Create first product with barcode
  console.log(`Creating first product with barcode "${tempBarcode}"...`);
  const firstProdRes = await request('/products', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${tokens.manager}`,
      'x-shop-id': String(SHOP_ID)
    },
    body: JSON.stringify({
      name: `Temp Product A ${timestamp}`,
      barcode: tempBarcode,
      sku: `SKUA_${timestamp}`,
      sellingPrice: 10000,
      costPrice: 5000,
      currentStock: 10
    })
  });
  
  if (!firstProdRes.ok) {
    console.error('Failed to create first product:', firstProdRes.data);
  } else {
    console.log('First product created successfully.');
  }

  // Try creating second product with identical barcode
  console.log(`Attempting to create second product with identical barcode "${tempBarcode}"...`);
  const secondProdRes = await request('/products', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${tokens.manager}`,
      'x-shop-id': String(SHOP_ID)
    },
    body: JSON.stringify({
      name: `Temp Product B ${timestamp}`,
      barcode: tempBarcode,
      sku: `SKUB_${timestamp}`,
      sellingPrice: 15000,
      costPrice: 8000,
      currentStock: 5
    })
  });
  
  console.log(`Status: ${secondProdRes.status}, Message: ${secondProdRes.data.message}`);
  if (secondProdRes.status === 500) {
    console.error('❌ ERROR: Duplicate barcode crashed the server with 500!');
  } else if (secondProdRes.status === 409) {
    console.log('✅ Success: Duplicate barcode rejected with 409 Conflict.');
  } else {
    console.log(`⚠️ Note: Received status ${secondProdRes.status}`);
  }

  console.log('\n=== CONCURRENCY & BUSINESS LOGIC SIMULATION COMPLETE ===');
}

main().catch(error => {
  console.error('Fatal Simulation Error:', error);
  process.exit(1);
});
