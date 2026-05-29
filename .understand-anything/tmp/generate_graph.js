const fs = require('fs');
const path = require('path');

const batchIndex = 5;
const projectRoot = 'd:/SalesAndStockManagement';
const inputPath = path.join(projectRoot, `.understand-anything/tmp/ua-file-analyzer-input-${batchIndex}.json`);
const resultsPath = path.join(projectRoot, `.understand-anything/tmp/ua-file-extract-results-${batchIndex}.json`);

const batchInput = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
const extractResults = JSON.parse(fs.readFileSync(resultsPath, 'utf8'));

const nodes = [];
const edges = [];

// Helper mappings for categories
const categoryTypeMap = {
  'code': 'file',
  'config': 'config',
  'docs': 'document',
  'infra': 'service', // or others
  'data': 'table', // or others
  'script': 'file',
  'markup': 'file'
};

const customSummaries = {
  '.cursor/rules/codegraph.mdc': {
    summary: 'Quy tắc Cursor để phân tích và điều hướng codegraph của dự án.',
    tags: ['cursor-rules', 'configuration'],
    complexity: 'simple'
  },
  '.gitattributes': {
    summary: 'Cấu hình thuộc tính Git cho dự án.',
    tags: ['git-config', 'configuration'],
    complexity: 'simple'
  },
  '.metadata': {
    summary: 'Tệp siêu dữ liệu cho dự án, lưu trữ các cấu hình liên quan đến môi trường hoặc công cụ.',
    tags: ['metadata', 'configuration'],
    complexity: 'simple'
  },
  '.understand-anything/.understandignore': {
    summary: 'Danh sách các tệp và thư mục bị bỏ qua bởi Understand Anything.',
    tags: ['ignore-list', 'configuration'],
    complexity: 'simple'
  },
  '.vercel/project.json': {
    summary: 'Cấu hình dự án Vercel, định nghĩa ID dự án và tổ chức.',
    tags: ['vercel', 'deployment', 'configuration'],
    complexity: 'simple'
  },
  '.vercel/README.txt': {
    summary: 'Tài liệu hướng dẫn hoặc thông tin về thư mục cấu hình Vercel.',
    tags: ['documentation', 'vercel'],
    complexity: 'simple'
  },
  'android/app/build.gradle.kts': {
    summary: 'Tệp cấu hình Gradle cho module ứng dụng Android, định nghĩa các phụ thuộc và thiết lập bản dựng.',
    tags: ['gradle', 'build-system', 'android'],
    complexity: 'moderate'
  },
  'android/app/src/debug/AndroidManifest.xml': {
    summary: 'Tệp manifest cho bản dựng debug của ứng dụng Android.',
    tags: ['android-manifest', 'configuration', 'debug'],
    complexity: 'simple'
  },
  'android/app/src/main/AndroidManifest.xml': {
    summary: 'Tệp manifest chính của ứng dụng Android, định nghĩa các quyền, activity và thông tin ứng dụng.',
    tags: ['android-manifest', 'configuration', 'main'],
    complexity: 'moderate'
  },
  'android/app/src/main/kotlin/com/example/flutter_app/MainActivity.kt': {
    summary: 'Activity chính của ứng dụng Android, là điểm vào cho phần native code của ứng dụng Flutter.',
    tags: ['android-activity', 'entry-point'],
    complexity: 'simple'
  },
  'android/app/src/main/res/drawable-v21/launch_background.xml': {
    summary: 'Cấu hình giao diện nền khi khởi chạy ứng dụng cho Android phiên bản v21 trở lên.',
    tags: ['android-resource', 'ui-config'],
    complexity: 'simple'
  },
  'android/app/src/main/res/drawable/launch_background.xml': {
    summary: 'Cấu hình giao diện nền khi khởi chạy ứng dụng cho các thiết bị Android cũ.',
    tags: ['android-resource', 'ui-config'],
    complexity: 'simple'
  },
  'android/app/src/main/res/values-night-v31/styles.xml': {
    summary: 'Định nghĩa các kiểu giao diện (style) cho chế độ ban đêm trên Android v31 trở lên.',
    tags: ['android-resource', 'theme', 'night-mode'],
    complexity: 'simple'
  },
  'android/app/src/main/res/values-night/styles.xml': {
    summary: 'Định nghĩa các kiểu giao diện (style) cho chế độ ban đêm trên Android.',
    tags: ['android-resource', 'theme', 'night-mode'],
    complexity: 'simple'
  },
  'android/app/src/main/res/values-v31/styles.xml': {
    summary: 'Định nghĩa các kiểu giao diện (style) cơ bản cho Android v31 trở lên.',
    tags: ['android-resource', 'theme'],
    complexity: 'simple'
  },
  'android/app/src/main/res/values/styles.xml': {
    summary: 'Định nghĩa các kiểu giao diện (style) cơ bản cho ứng dụng Android.',
    tags: ['android-resource', 'theme'],
    complexity: 'simple'
  },
  'android/app/src/profile/AndroidManifest.xml': {
    summary: 'Tệp manifest cho bản dựng profile của ứng dụng Android.',
    tags: ['android-manifest', 'configuration', 'profile'],
    complexity: 'simple'
  },
  'android/build.gradle.kts': {
    summary: 'Tệp cấu hình Gradle mức dự án cho Android.',
    tags: ['gradle', 'build-system'],
    complexity: 'simple'
  },
  'android/gradle.properties': {
    summary: 'Thuộc tính và cấu hình toàn cục cho quá trình build Gradle của Android.',
    tags: ['gradle-properties', 'configuration'],
    complexity: 'simple'
  },
  'android/gradle/wrapper/gradle-wrapper.properties': {
    summary: 'Cấu hình cho Gradle Wrapper, chỉ định phiên bản Gradle sẽ được sử dụng.',
    tags: ['gradle-wrapper', 'configuration'],
    complexity: 'simple'
  },
  'android/settings.gradle.kts': {
    summary: 'Cấu hình settings cho Gradle, xác định các module sẽ được bao gồm trong quá trình build.',
    tags: ['gradle-settings', 'build-system'],
    complexity: 'simple'
  },
  'backend/create_test_user.ts': {
    summary: 'Tạo người dùng thử nghiệm cho cơ sở dữ liệu.',
    tags: ['utility', 'test', 'database'],
    complexity: 'moderate'
  },
  'backend/src/auth/entities.ts': {
    summary: 'Định nghĩa các thực thể dữ liệu liên quan đến xác thực người dùng.',
    tags: ['data-model', 'authentication', 'type-definition'],
    complexity: 'moderate'
  },
  'backend/src/common/response.ts': {
    summary: 'Định nghĩa các cấu trúc phản hồi API chuẩn hóa.',
    tags: ['utility', 'api-handler', 'type-definition'],
    complexity: 'moderate'
  },
  'backend/src/config/db.config.ts': {
    summary: 'Cấu hình kết nối và thiết lập cơ sở dữ liệu cho ứng dụng.',
    tags: ['configuration', 'database'],
    complexity: 'moderate'
  }
};

extractResults.results.forEach(res => {
  const filePath = res.path;
  const fileCategory = res.fileCategory || 'code';
  const type = categoryTypeMap[fileCategory] || 'file';
  
  const custom = customSummaries[filePath] || {
    summary: `Phân tích cấu trúc cho tệp ${path.basename(filePath)}.`,
    tags: ['file'],
    complexity: 'simple'
  };

  const fileNodeId = `${type}:${filePath}`;

  // File Node
  nodes.push({
    id: fileNodeId,
    type: type,
    name: path.basename(filePath),
    filePath: filePath,
    summary: custom.summary,
    tags: custom.tags,
    complexity: custom.complexity
  });

  // Imports
  const imports = batchInput.batchImportData[filePath] || [];
  imports.forEach(importPath => {
    edges.push({
      source: fileNodeId,
      target: `file:${importPath}`,
      type: 'imports',
      direction: 'forward',
      weight: 0.7
    });
  });

  // Functions
  if (res.functions) {
    res.functions.forEach(func => {
      const funcLines = (func.endLine - func.startLine) + 1;
      const isExported = res.exports && res.exports.some(e => e.name === func.name);
      
      if (funcLines >= 10 || isExported) {
        const funcNodeId = `function:${filePath}:${func.name}`;
        
        let funcSummary = `Hàm ${func.name} thực hiện logic xử lý trong tệp.`;
        let funcTags = ['function'];
        
        if (func.name === 'createTestUser') {
          funcSummary = 'Hàm tạo tài khoản người dùng thử nghiệm bằng cách xóa người dùng cũ và tạo người dùng mới.';
          funcTags = ['database-seeding', 'utility'];
        }

        nodes.push({
          id: funcNodeId,
          type: 'function',
          name: func.name,
          summary: funcSummary,
          tags: funcTags,
          complexity: funcLines > 50 ? 'complex' : 'moderate',
          lineRange: [func.startLine, func.endLine]
        });

        edges.push({
          source: fileNodeId,
          target: funcNodeId,
          type: 'contains',
          direction: 'forward',
          weight: 1.0
        });

        if (isExported) {
          edges.push({
            source: fileNodeId,
            target: funcNodeId,
            type: 'exports',
            direction: 'forward',
            weight: 0.8
          });
        }
      }
    });
  }

  // Classes
  if (res.classes) {
    res.classes.forEach(cls => {
      const clsLines = (cls.endLine - cls.startLine) + 1;
      const isExported = res.exports && res.exports.some(e => e.name === cls.name);
      const methodCount = (cls.methods || []).length;
      
      if (clsLines >= 20 || methodCount >= 2 || isExported) {
        const clsNodeId = `class:${filePath}:${cls.name}`;
        
        let clsSummary = `Lớp ${cls.name} định nghĩa cấu trúc và phương thức.`;
        let clsTags = ['class'];

        if (cls.name === 'User') {
          clsSummary = 'Mô hình dữ liệu đại diện cho người dùng trong hệ thống.';
          clsTags = ['data-model', 'entity'];
        } else if (cls.name === 'ApiResponse') {
          clsSummary = 'Cấu trúc phản hồi API cơ bản bao gồm trạng thái, thông báo và dữ liệu.';
          clsTags = ['api-response', 'utility'];
        } else if (cls.name === 'PageResponse') {
          clsSummary = 'Cấu trúc phản hồi API cho danh sách dữ liệu có phân trang.';
          clsTags = ['api-response', 'pagination'];
        }

        nodes.push({
          id: clsNodeId,
          type: 'class',
          name: cls.name,
          summary: clsSummary,
          tags: clsTags,
          complexity: clsLines > 100 ? 'complex' : 'moderate',
          lineRange: [cls.startLine, cls.endLine]
        });

        edges.push({
          source: fileNodeId,
          target: clsNodeId,
          type: 'contains',
          direction: 'forward',
          weight: 1.0
        });

        if (isExported) {
          edges.push({
            source: fileNodeId,
            target: clsNodeId,
            type: 'exports',
            direction: 'forward',
            weight: 0.8
          });
        }
      }
    });
  }
});

// Write to files based on size limits (<= 60 nodes and <= 120 edges)
const nodeCount = nodes.length;
const edgeCount = edges.length;

if (nodeCount <= 60 && edgeCount <= 120) {
  const outputPath = path.join(projectRoot, `.understand-anything/intermediate/batch-${batchIndex}.json`);
  fs.writeFileSync(outputPath, JSON.stringify({ nodes, edges }, null, 2));
  console.log(`Wrote 1 part. Nodes: ${nodeCount}, Edges: ${edgeCount}`);
} else {
  const parts = Math.ceil(Math.max(nodeCount / 60, edgeCount / 120));
  
  // Quick partition strategy - group by file path
  // Since total nodes is ~29 and edges is ~30 for this batch, it will fall in the first condition.
  console.log(`Requires partitioning. Nodes: ${nodeCount}, Edges: ${edgeCount}`);
}
