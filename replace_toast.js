const fs = require('fs');
const path = require('path');

function walk(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    isDirectory ? walk(dirPath, callback) : callback(path.join(dir, f));
  });
}

let changedFiles = 0;

walk('d:\\SalesAndStockManagement\\lib', (filePath) => {
  if (filePath.endsWith('.dart') && !filePath.includes('toast_service.dart')) {
    let content = fs.readFileSync(filePath, 'utf8');
    if (content.includes('ScaffoldMessenger.of(context).showSnackBar')) {
      let originalContent = content;
      
      const regex = /ScaffoldMessenger\.of\(context\)\.showSnackBar\s*\(\s*(?:const\s*)?SnackBar\s*\(\s*content\s*:\s*(?:const\s*)?Text\s*\(([\s\S]*?)\)\s*(?:,\s*backgroundColor\s*:\s*([^,\)]+))?[\s\S]*?\)\s*,?\s*\);?/g;
      
      content = content.replace(regex, (match, textContent, bgColor) => {
          let method = 'showSuccess'; // default
          let textStr = textContent.trim();
          
          if (textStr.toLowerCase().includes('lỗi') || textStr.toLowerCase().includes('error') || textStr.toLowerCase().includes('thất bại') || bgColor?.includes('danger') || bgColor?.includes('red') || bgColor?.includes('error')) {
              method = 'showError';
          }
          
          return `ToastService.${method}(${textStr});`;
      });
      
      if (content !== originalContent) {
          // Add import if not present
          if (!content.includes('ToastService')) {
              const depth = filePath.replace('d:\\SalesAndStockManagement\\lib\\', '').split('\\').length - 1;
              let prefix = '';
              for(let i=0; i<depth; i++) prefix += '../';
              if(prefix==='') prefix = './';
              const importStr = "import '" + prefix + "core/utils/toast_service.dart';\n";
              
              const lastImportIndex = content.lastIndexOf('import ');
              if (lastImportIndex !== -1) {
                  const endOfLine = content.indexOf('\n', lastImportIndex);
                  content = content.slice(0, endOfLine + 1) + importStr + content.slice(endOfLine + 1);
              } else {
                  content = importStr + content;
              }
          }
          
          fs.writeFileSync(filePath, content, 'utf8');
          changedFiles++;
          console.log('Replaced in: ' + filePath);
      }
    }
  }
});
console.log('Changed ' + changedFiles + ' files.');
