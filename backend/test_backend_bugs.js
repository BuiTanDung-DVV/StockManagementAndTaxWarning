const http = require('http');

async function request(path, method = 'GET', body = null, token = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 8080,
      path: '/api' + path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      }
    };
    if (token) options.headers['Authorization'] = 'Bearer ' + token;
    if (token && typeof token === 'object') {
        options.headers['Authorization'] = 'Bearer ' + token.token;
        if (token.shopId) options.headers['x-shop-id'] = token.shopId.toString();
    }

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: data ? JSON.parse(data) : null });
        } catch(e) {
          resolve({ status: res.statusCode, data: data });
        }
      });
    });

    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function runTests() {
  const errors = [];
  const log = (msg) => console.log(msg);
  try {
    log("1. Auth & Shop Setup");
    const regRes = await request('/auth/register', 'POST', { phone: '0999999998', password: '123', fullName: 'Test' });
    const loginRes = await request('/auth/login', 'POST', { phone: '0999999998', password: '123' });
    const jwt = loginRes.data.data.token;
    
    const shopRes = await request('/system/shops', 'POST', { name: 'Test Shop', address: '123 Test', phone: '0999' }, jwt);
    let shopId = 1;
    if (shopRes.data && shopRes.data.data && shopRes.data.data.id) {
        shopId = shopRes.data.data.id;
    } else {
        const myShops = await request('/my-shops', 'GET', null, jwt);
        if (myShops.data && myShops.data.data && myShops.data.data.length > 0) {
            shopId = myShops.data.data[0].shopId;
        }
    }
    const auth = { token: jwt, shopId };

    log("2. Test BUG-009: Purchase without invoice GET (No 500 Error)");
    const pwiGet = await request('/purchases-without-invoice', 'GET', null, auth);
    if (pwiGet.status === 500) errors.push(`BUG-009: /purchases-without-invoice GET returned 500: ${JSON.stringify(pwiGet.data)}`);

    log("3. Test Inventory Stock Take `takeDate` mapping");
    const stPost = await request('/stock-takes', 'POST', { takeDate: '2026-05-20', items: [] }, auth);
    if (stPost.status === 500 && stPost.data && stPost.data.message && stPost.data.message.includes('stock_take_date violates not-null')) {
        errors.push('Inventory stock take mapping failed');
    }

    log("4. Test Finance Invoice `type` mapping");
    const invPost = await request('/invoices', 'POST', { type: 'OUT', partnerName: 'Test' }, auth);
    if (invPost.status === 500 && invPost.data && invPost.data.message && invPost.data.message.includes('invoice_type violates not-null')) {
        errors.push('Finance invoice type mapping failed');
    }

    log("5. Test Customer DELETE route 404 fix");
    const custPost = await request('/customers', 'POST', { name: 'Test Customer', phone: '011111' }, auth);
    if (custPost.data?.data?.id) {
        const custDel = await request(`/customers/${custPost.data.data.id}`, 'DELETE', null, auth);
        if (custDel.status === 404) errors.push(`Customer DELETE route 404: ${JSON.stringify(custDel.data)}`);
    }

    log("6. Test Sales Order PUT route 404 fix");
    const salesPost = await request('/sales-orders', 'POST', { customerId: 1, items: [] }, auth);
    if (salesPost.data?.data?.id) {
        const salesPut = await request(`/sales-orders/${salesPost.data.data.id}`, 'PUT', { status: 'COMPLETED' }, auth);
        if (salesPut.status === 404) errors.push(`Sales Order PUT route 404: ${JSON.stringify(salesPut.data)}`);
    }

    if (errors.length > 0) {
        console.error("FAILED AUTOMATED TESTS:", errors);
        process.exit(1);
    } else {
        console.log("ALL API TESTS PASSED SUCCESSFULLY!");
    }
  } catch(e) {
    console.error("FATAL ERROR", e);
    process.exit(1);
  }
}
runTests();
