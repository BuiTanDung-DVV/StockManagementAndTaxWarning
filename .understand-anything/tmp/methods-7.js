const fs = require('fs');
const data = JSON.parse(fs.readFileSync('d:/SalesAndStockManagement/.understand-anything/tmp/ua-file-extract-results-7.json', 'utf8'));

data.results.forEach(file => {
  console.log(`\n=== File: ${file.path} ===`);
  (file.classes || []).forEach(c => {
    console.log(`Class ${c.name} [${c.startLine}-${c.endLine}]:`);
    (c.methods || []).forEach(m => {
       const lines = m.endLine - m.startLine + 1;
       console.log(`  - ${m.name} [${m.startLine}-${m.endLine}] (${lines} lines)`);
    });
  });
});
