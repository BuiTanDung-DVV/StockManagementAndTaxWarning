const http = require('http');

const data = JSON.stringify({
  refundAmount: 1000,
  refundMethod: 'CASH',
  reason: '',
  items: [{
    productId: 1,
    quantity: 1,
    unitPrice: 1000,
    subtotal: 1000,
    reason: ''
  }]
});

const options = {
  hostname: 'localhost',
  port: 3000,
  path: '/api/sales-orders/1/returns',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': data.length
  }
};

const req = http.request(options, (res) => {
  let body = '';
  res.on('data', (chunk) => body += chunk);
  res.on('end', () => console.log('Response:', res.statusCode, body));
});

req.on('error', (e) => console.error(e));
req.write(data);
req.end();
