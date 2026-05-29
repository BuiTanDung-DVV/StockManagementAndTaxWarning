const fs = require('fs');
const data = JSON.parse(fs.readFileSync('d:/SalesAndStockManagement/.understand-anything/tmp/ua-file-extract-results-7.json', 'utf8'));

data.results.forEach(file => {
  (file.classes || []).forEach(c => {
    console.log(`Class ${c.name}: methods =`, c.methods);
  });
});
