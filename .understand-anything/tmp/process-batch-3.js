const fs = require('fs');

const input = JSON.parse(fs.readFileSync('d:\\SalesAndStockManagement\\.understand-anything\\tmp\\ua-file-extract-results-3.json', 'utf8'));

const nodes = [];
const edges = [];

const fileTypes = {
  "backend/database/20260421_phase1_hkd_updates.sql": {
    summary: "Tệp SQL cập nhật cơ sở dữ liệu giai đoạn 1 cho HKD, định nghĩa bảng mua hàng không có hóa đơn.",
    tags: ["database", "migration"]
  },
  "backend/database/20260504_optimize_indexes.sql": {
    summary: "Tệp SQL tối ưu hóa hiệu suất cơ sở dữ liệu bằng cách tạo nhiều chỉ mục (indexes) cho các bảng.",
    tags: ["database", "migration", "optimization"]
  },
  "backend/database/20260524_create_journal_ledger.sql": {
    summary: "Tệp SQL tạo các bảng sổ nhật ký chung và chi tiết bút toán.",
    tags: ["database", "migration"]
  },
  "backend/database/20260525_create_financial_ledger.sql": {
    summary: "Tệp SQL định nghĩa bảng sổ cái tài chính.",
    tags: ["database", "migration"]
  },
  "backend/database/20260525_create_sales_order_lot_deductions.sql": {
    summary: "Tệp SQL tạo bảng quản lý khấu trừ lô hàng cho đơn bán hàng.",
    tags: ["database", "migration"]
  },
  "backend/database/20260525_create_tax_rules.sql": {
    summary: "Tệp SQL định nghĩa bảng quy tắc tính thuế.",
    tags: ["database", "migration"]
  },
  "backend/database/20260525_recreate_financial_ledger.sql": {
    summary: "Tệp SQL tạo lại bảng sổ cái tài chính với cấu trúc mới.",
    tags: ["database", "migration"]
  },
  "backend/database/QLKH.sql": {
    summary: "Tệp SQL schema chính khởi tạo toàn bộ cấu trúc cơ sở dữ liệu cho hệ thống quản lý bán hàng và kho.",
    tags: ["database", "schema-definition", "infrastructure"]
  }
};

input.results.forEach(res => {
  const filePath = res.path;
  const fileId = `file:${filePath}`;
  const info = fileTypes[filePath] || { summary: "Tệp cơ sở dữ liệu.", tags: ["database"] };
  
  let complexity = "simple";
  if (res.nonEmptyLines > 200) complexity = "complex";
  else if (res.nonEmptyLines > 50) complexity = "moderate";

  nodes.push({
    id: fileId,
    type: "file",
    name: filePath.split('/').pop(),
    filePath: filePath,
    summary: info.summary,
    tags: info.tags,
    complexity: complexity
  });

  const tableNames = new Set();
  
  if (res.definitions) {
    res.definitions.forEach((def, index) => {
      if (def.kind === "table") {
        let tableName = def.name;
        // Fix for parsing issue where name is 'public'
        if (tableName === "public") {
            if (filePath.includes("20260421_phase1")) tableName = "purchases_without_invoice";
            else if (filePath.includes("20260524_create_journal_ledger") && index === 0) tableName = "journal_entries";
            else if (filePath.includes("20260524_create_journal_ledger") && index === 1) tableName = "journal_lines";
            else if (filePath.includes("20260525_create_financial_ledger")) tableName = "financial_ledger";
            else if (filePath.includes("20260525_recreate_financial_ledger")) tableName = "financial_ledger_new";
            else tableName = `public_${index}`;
        }
        
        if (tableNames.has(tableName)) {
            tableName = `${tableName}_${index}`;
        }
        tableNames.add(tableName);
        
        const tableId = `table:${filePath}:${tableName}`;
        nodes.push({
          id: tableId,
          type: "table",
          name: tableName,
          filePath: filePath,
          summary: `Bảng dữ liệu ${tableName} được định nghĩa trong ${filePath.split('/').pop()}.`,
          tags: ["database", "table"],
          complexity: def.fields && def.fields.length > 10 ? "moderate" : "simple"
        });
        
        edges.push({
          source: fileId,
          target: tableId,
          type: "migrates",
          direction: "forward",
          weight: 0.7
        });
      }
    });
  }
});

const output = { nodes, edges };
const nodeCount = nodes.length;
const edgeCount = edges.length;
console.log(`Nodes: ${nodeCount}, Edges: ${edgeCount}`);

const outDir = 'd:\\SalesAndStockManagement\\.understand-anything\\intermediate';
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

if (nodeCount <= 60 && edgeCount <= 120) {
  fs.writeFileSync(`${outDir}\\batch-3.json`, JSON.stringify(output, null, 2));
  console.log('Wrote batch-3.json');
} else {
  const parts = Math.ceil(Math.max(nodeCount / 60, edgeCount / 120));
  console.log(`Splitting into ${parts} parts...`);
  
  const files = [...new Set(nodes.map(n => n.filePath).filter(Boolean))].sort();
  for (let k = 1; k <= parts; k++) {
     const partFiles = files.filter((_, i) => (i % parts) === (k - 1));
     
     const partNodes = nodes.filter(n => {
       const path = n.filePath || n.id.split(':')[1];
       return partFiles.includes(path);
     });
     
     const partNodeIds = new Set(partNodes.map(n => n.id));
     
     const partEdges = edges.filter(e => partNodeIds.has(e.source));
     
     const partOutput = { nodes: partNodes, edges: partEdges };
     fs.writeFileSync(`${outDir}\\batch-3-part-${k}.json`, JSON.stringify(partOutput, null, 2));
     console.log(`Wrote batch-3-part-${k}.json with ${partNodes.length} nodes and ${partEdges.length} edges`);
  }
}
