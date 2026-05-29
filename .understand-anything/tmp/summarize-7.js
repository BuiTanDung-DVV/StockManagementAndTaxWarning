const fs = require('fs');
const data = JSON.parse(fs.readFileSync('d:/SalesAndStockManagement/.understand-anything/tmp/ua-file-extract-results-7.json', 'utf8'));

data.results.forEach(file => {
  console.log(`\n=== File: ${file.path} ===`);
  console.log(`Metrics: ${JSON.stringify(file.metrics)}`);
  console.log(`Functions: ${(file.functions || []).map(f => f.name + '('+f.startLine+'-'+f.endLine+')').join(', ')}`);
  console.log(`Classes: ${(file.classes || []).map(c => c.name + '['+c.startLine+'-'+c.endLine+']').join(', ')}`);
  console.log(`Exports: ${(file.exports || []).map(e => e.name).join(', ')}`);
});
