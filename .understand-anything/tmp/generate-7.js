const fs = require('fs');

const data = {
  "nodes": [
    {
      "id": "file:backend/src/routes.ts",
      "type": "file",
      "name": "routes.ts",
      "filePath": "backend/src/routes.ts",
      "summary": "Tệp định tuyến trung tâm cho các API của hệ thống.",
      "tags": ["định-tuyến", "api", "entry-point"],
      "complexity": "moderate"
    },
    {
      "id": "file:backend/src/services/auth.service.ts",
      "type": "file",
      "name": "auth.service.ts",
      "filePath": "backend/src/services/auth.service.ts",
      "summary": "Dịch vụ xử lý xác thực người dùng, đăng nhập, đăng ký, cấp lại token và quản lý mật khẩu.",
      "tags": ["xác-thực", "service", "bảo-mật", "đăng-nhập", "otp"],
      "complexity": "moderate",
      "languageNotes": "Sử dụng các mẫu Dependency Injection và JWT cho xác thực."
    },
    {
      "id": "class:backend/src/services/auth.service.ts:AuthService",
      "type": "class",
      "name": "AuthService",
      "summary": "Lớp dịch vụ cốt lõi cung cấp các phương thức xác thực và quản lý tài khoản.",
      "tags": ["lớp-dịch-vụ", "xác-thực", "chuyên-môn"],
      "complexity": "moderate"
    },
    {
      "id": "file:backend/src/services/customer.service.ts",
      "type": "file",
      "name": "customer.service.ts",
      "filePath": "backend/src/services/customer.service.ts",
      "summary": "Dịch vụ quản lý thông tin khách hàng, theo dõi công nợ và các giao dịch thanh toán.",
      "tags": ["khách-hàng", "công-nợ", "service", "quản-lý", "thanh-toán"],
      "complexity": "moderate"
    },
    {
      "id": "class:backend/src/services/customer.service.ts:CustomerService",
      "type": "class",
      "name": "CustomerService",
      "summary": "Lớp quản lý nghiệp vụ liên quan đến khách hàng và sổ nợ.",
      "tags": ["lớp-dịch-vụ", "khách-hàng", "nghiệp-vụ"],
      "complexity": "moderate"
    },
    {
      "id": "file:backend/src/services/einvoice.service.ts",
      "type": "file",
      "name": "einvoice.service.ts",
      "filePath": "backend/src/services/einvoice.service.ts",
      "summary": "Dịch vụ tích hợp hóa đơn điện tử, cho phép phát hành và hủy hóa đơn qua nhà cung cấp.",
      "tags": ["hóa-đơn", "tích-hợp", "service", "thuế"],
      "complexity": "moderate"
    },
    {
      "id": "class:backend/src/services/einvoice.service.ts:MockEInvoiceProvider",
      "type": "class",
      "name": "MockEInvoiceProvider",
      "summary": "Nhà cung cấp hóa đơn giả lập để phục vụ kiểm thử và phát triển.",
      "tags": ["giả-lập", "kiểm-thử", "hóa-đơn"],
      "complexity": "simple"
    },
    {
      "id": "class:backend/src/services/einvoice.service.ts:EInvoiceService",
      "type": "class",
      "name": "EInvoiceService",
      "summary": "Lớp dịch vụ chính tương tác với API hóa đơn điện tử.",
      "tags": ["lớp-dịch-vụ", "tích-hợp", "hóa-đơn"],
      "complexity": "simple"
    },
    {
      "id": "file:backend/src/services/email.service.ts",
      "type": "file",
      "name": "email.service.ts",
      "filePath": "backend/src/services/email.service.ts",
      "summary": "Dịch vụ tiện ích hỗ trợ gửi email thông báo và mã OTP xác thực.",
      "tags": ["email", "thông-báo", "service", "tiện-ích"],
      "complexity": "simple"
    },
    {
      "id": "class:backend/src/services/email.service.ts:EmailService",
      "type": "class",
      "name": "EmailService",
      "summary": "Lớp cung cấp phương thức gửi email qua các dịch vụ SMTP.",
      "tags": ["lớp-dịch-vụ", "email", "tiện-ích"],
      "complexity": "simple"
    },
    {
      "id": "file:backend/src/services/finance.service.ts",
      "type": "file",
      "name": "finance.service.ts",
      "filePath": "backend/src/services/finance.service.ts",
      "summary": "Dịch vụ tài chính, quản lý dòng tiền, sổ quỹ, thu chi, báo cáo lãi lỗ và nghĩa vụ thuế.",
      "tags": ["tài-chính", "báo-cáo", "service", "dòng-tiền", "kế-toán"],
      "complexity": "complex"
    },
    {
      "id": "class:backend/src/services/finance.service.ts:FinanceService",
      "type": "class",
      "name": "FinanceService",
      "summary": "Lớp chứa logic nghiệp vụ phức tạp về sổ quỹ, báo cáo tài chính và giao dịch tiền mặt.",
      "tags": ["lớp-dịch-vụ", "tài-chính", "báo-cáo", "phức-tạp"],
      "complexity": "complex"
    }
  ],
  "edges": [
    {
      "source": "file:backend/src/services/auth.service.ts",
      "target": "class:backend/src/services/auth.service.ts:AuthService",
      "type": "contains",
      "direction": "forward",
      "weight": 1.0
    },
    {
      "source": "file:backend/src/services/auth.service.ts",
      "target": "class:backend/src/services/auth.service.ts:AuthService",
      "type": "exports",
      "direction": "forward",
      "weight": 0.8
    },
    {
      "source": "file:backend/src/services/customer.service.ts",
      "target": "class:backend/src/services/customer.service.ts:CustomerService",
      "type": "contains",
      "direction": "forward",
      "weight": 1.0
    },
    {
      "source": "file:backend/src/services/customer.service.ts",
      "target": "class:backend/src/services/customer.service.ts:CustomerService",
      "type": "exports",
      "direction": "forward",
      "weight": 0.8
    },
    {
      "source": "file:backend/src/services/einvoice.service.ts",
      "target": "class:backend/src/services/einvoice.service.ts:MockEInvoiceProvider",
      "type": "contains",
      "direction": "forward",
      "weight": 1.0
    },
    {
      "source": "file:backend/src/services/einvoice.service.ts",
      "target": "class:backend/src/services/einvoice.service.ts:MockEInvoiceProvider",
      "type": "exports",
      "direction": "forward",
      "weight": 0.8
    },
    {
      "source": "file:backend/src/services/einvoice.service.ts",
      "target": "class:backend/src/services/einvoice.service.ts:EInvoiceService",
      "type": "contains",
      "direction": "forward",
      "weight": 1.0
    },
    {
      "source": "file:backend/src/services/einvoice.service.ts",
      "target": "class:backend/src/services/einvoice.service.ts:EInvoiceService",
      "type": "exports",
      "direction": "forward",
      "weight": 0.8
    },
    {
      "source": "file:backend/src/services/email.service.ts",
      "target": "class:backend/src/services/email.service.ts:EmailService",
      "type": "contains",
      "direction": "forward",
      "weight": 1.0
    },
    {
      "source": "file:backend/src/services/email.service.ts",
      "target": "class:backend/src/services/email.service.ts:EmailService",
      "type": "exports",
      "direction": "forward",
      "weight": 0.8
    },
    {
      "source": "file:backend/src/services/finance.service.ts",
      "target": "class:backend/src/services/finance.service.ts:FinanceService",
      "type": "contains",
      "direction": "forward",
      "weight": 1.0
    },
    {
      "source": "file:backend/src/services/finance.service.ts",
      "target": "class:backend/src/services/finance.service.ts:FinanceService",
      "type": "exports",
      "direction": "forward",
      "weight": 0.8
    }
  ]
};

const methods = {
  "backend/src/services/auth.service.ts": {
    className: "AuthService",
    methods: [
      { name: "register", summary: "Đăng ký tài khoản người dùng mới." },
      { name: "login", summary: "Xác thực và cấp token cho phiên đăng nhập." },
      { name: "refreshToken", summary: "Cấp lại access token từ refresh token." },
      { name: "sendOtp", summary: "Gửi mã OTP xác nhận đến thiết bị hoặc email." },
      { name: "forgotPassword", summary: "Khởi tạo quy trình quên mật khẩu." },
      { name: "resetPassword", summary: "Đặt lại mật khẩu mới thông qua mã xác nhận." },
      { name: "searchShops", summary: "Tìm kiếm thông tin cửa hàng liên kết." },
      { name: "completeOnboarding", summary: "Hoàn tất các bước khởi tạo thông tin người dùng ban đầu." }
    ]
  },
  "backend/src/services/customer.service.ts": {
    className: "CustomerService",
    methods: [
      { name: "findAll", summary: "Lấy danh sách tất cả khách hàng." },
      { name: "findById", summary: "Truy xuất chi tiết một khách hàng theo ID." },
      { name: "create", summary: "Tạo mới hồ sơ khách hàng." },
      { name: "update", summary: "Cập nhật thông tin khách hàng." },
      { name: "remove", summary: "Xóa thông tin khách hàng khỏi hệ thống." },
      { name: "getReceivables", summary: "Lấy danh sách các khoản phải thu." },
      { name: "getDebtEvidence", summary: "Truy xuất các bằng chứng về công nợ của khách." },
      { name: "addPayment", summary: "Thêm giao dịch thanh toán cho công nợ." },
      { name: "getDebtAging", summary: "Phân tích tuổi nợ của các khoản chưa thanh toán." },
      { name: "getOverdueDebts", summary: "Lấy danh sách các khoản nợ đã quá hạn." }
    ]
  },
  "backend/src/services/finance.service.ts": {
    className: "FinanceService",
    methods: [
      { name: "getCashTransactions", summary: "Lấy danh sách các giao dịch tiền mặt." },
      { name: "createCashTransaction", summary: "Tạo mới một giao dịch thu hoặc chi tiền mặt." },
      { name: "getCashFlowSummary", summary: "Báo cáo tổng quan về lưu chuyển dòng tiền." },
      { name: "getProfitLoss", summary: "Báo cáo kết quả hoạt động kinh doanh (lãi/lỗ)." },
      { name: "getDailyClosings", summary: "Lấy danh sách chốt sổ quỹ hàng ngày." },
      { name: "getBudgetPlans", summary: "Truy xuất kế hoạch ngân sách dự kiến." },
      { name: "getTaxObligations", summary: "Lấy danh sách các nghĩa vụ thuế cần nộp." },
      { name: "getInvoices", summary: "Lấy danh sách hóa đơn tài chính." }
    ]
  }
};

for (const [filePath, info] of Object.entries(methods)) {
  for (const m of info.methods) {
    const fnId = `function:${filePath}:${m.name}`;
    data.nodes.push({
      "id": fnId,
      "type": "function",
      "name": m.name,
      "summary": m.summary,
      "tags": ["phương-thức", "xử-lý", "nghiệp-vụ"],
      "complexity": "moderate"
    });
    
    data.edges.push({
      "source": `class:${filePath}:${info.className}`,
      "target": fnId,
      "type": "contains",
      "direction": "forward",
      "weight": 1.0
    });
  }
}

fs.mkdirSync('d:/SalesAndStockManagement/.understand-anything/intermediate', { recursive: true });
fs.writeFileSync('d:/SalesAndStockManagement/.understand-anything/intermediate/batch-7.json', JSON.stringify(data, null, 2), 'utf8');
console.log(`Node count: ${data.nodes.length}`);
console.log(`Edge count: ${data.edges.length}`);
