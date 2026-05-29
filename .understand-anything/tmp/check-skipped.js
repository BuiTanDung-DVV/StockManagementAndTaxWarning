const fs = require('fs');
const data = JSON.parse(fs.readFileSync('d:/SalesAndStockManagement/.understand-anything/tmp/ua-file-extract-results-7.json', 'utf8'));

console.log("Analyzed:", data.filesAnalyzed);
console.log("Skipped:", data.filesSkipped);
console.log("Missing from results:", data.results.map(r => r.path));
