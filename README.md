# 📦 Sales & Stock Management System (with Tax Warning)

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/node.js-6DA55F?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![Express.js](https://img.shields.io/badge/express.js-%23404d59.svg?style=for-the-badge&logo=express&logoColor=%2361DAFB)](https://expressjs.com)
[![TypeScript](https://img.shields.io/badge/typescript-%23007ACC.svg?style=for-the-badge&logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![PostgreSQL](https://img.shields.io/badge/postgresql-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Vercel](https://img.shields.io/badge/vercel-%23000000.svg?style=for-the-badge&logo=vercel&logoColor=white)](https://vercel.com)

Hệ thống quản lý bán hàng, tồn kho và cảnh báo thuế tích hợp toàn diện. Dự án được thiết kế dưới dạng **Monorepo** bao gồm ứng dụng di động Flutter (Frontend) và máy chủ Node.js/TypeScript (Backend API).

---

## 🚀 Các Tính Năng Chính

*   **Quản Lý Kho Hàng**: Nhập kho, xuất kho, kiểm kê và quản lý lô sản phẩm (Lot Tracking), ngày hết hạn.
*   **Quản Lý Bán Hàng**: Lập hóa đơn bán hàng, ghi nhận doanh thu và quản lý trả hàng (Sales Returns).
*   **Tài Chính & Kế Toán**: Ghi nhận sổ nhật ký chung (Journal Ledger), doanh thu, giá vốn hàng bán (COGS).
*   **Cảnh Báo Thuế**: Tính toán thuế suất và tự động đưa ra cảnh báo cho các hộ kinh doanh cá thể hoặc doanh nghiệp.
*   **Bảo Mật Phân Quyền**: Cơ chế phân quyền theo vai trò (RBAC - Role-Based Access Control) chặt chẽ giữa Chủ cửa hàng (Owner) và Nhân viên (Staff).

---

## 📁 Cấu Trúc Dự Án (Monorepo)

```text
D:\SalesAndStockManagement
├── android/ & ios/ & web/       # Các thư mục cấu hình nền tảng di động & web của Flutter
├── assets/                       # Thư mục chứa hình ảnh, fonts, tài nguyên chung
├── lib/                          # Mã nguồn Flutter Frontend (Clean Architecture)
│   ├── core/                     # Cấu hình hệ thống (Theme, Router, Network, Widgets chung)
│   └── features/                 # Các Module nghiệp vụ (Auth, Product, Stock, Finance...)
├── backend/                      # Mã nguồn Node.js / Express Backend API
│   ├── src/                      # Source code chính của Backend
│   │   ├── config/               # Cấu hình cơ sở dữ liệu và biến môi trường
│   │   ├── controllers/          # Tầng xử lý logic yêu cầu HTTP
│   │   ├── middleware/           # Middleware (Auth JWT, CORS, RBAC, Context)
│   │   ├── routes/               # Định tuyến các endpoint API
│   │   └── services/             # Tầng xử lý nghiệp vụ chính (Business Logic)
│   ├── dev-scripts/              # [Mới] Scripts phát triển và dọn dẹp DB local (được Gitignore)
│   ├── vercel.json               # Cấu hình triển khai Serverless trên Vercel
│   └── package.json              # Khai báo thư viện và script backend
├── .gitignore                    # Quản lý các tệp tin loại trừ khỏi Git
└── README.md                     # Tài liệu giới thiệu dự án
```

---

## 🛠️ Hướng Dẫn Cài Đặt & Chạy Local

### 1. Cấu hình Backend

1.  Di chuyển vào thư mục backend:
    ```bash
    cd backend
    ```
2.  Cài đặt các gói thư viện:
    ```bash
    npm install
    ```
3.  Tạo tệp `.env` dựa trên cấu hình mẫu:
    ```env
    PORT=8080
    DATABASE_URL=postgresql://user:password@host:port/database
    JWT_SECRET=your_jwt_secret_key_here
    ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173
    ```
4.  Khởi chạy Backend ở chế độ phát triển (Development):
    ```bash
    npm run dev
    ```

### 2. Cấu hình Frontend (Flutter)

1.  Quay lại thư mục gốc dự án:
    ```bash
    cd ..
    ```
2.  Tải các package Dart:
    ```bash
    flutter pub get
    ```
3.  Khởi chạy ứng dụng Flutter ở môi trường Development:
    ```bash
    flutter run --dart-define-from-file=env/dev.json
    ```

### 3. Build & Deploy Bản Beta

Để đóng gói thành ứng dụng cài đặt (APK cho Android, EXE cho Windows) với môi trường Production, chạy lệnh sau:
```bash
# Build cho Android (Tạo file APK)
flutter build apk --release --dart-define-from-file=env/prod.json

# Build cho Windows (Tạo file .exe)
flutter build windows --release --dart-define-from-file=env/prod.json
```

## ☁️ Cấu Hình Triển Khai (Vercel)

Khi triển khai Backend lên Vercel, bạn cần cấu hình các biến môi trường sau trong **Vercel Dashboard** (Settings > Environment Variables):

*   `DATABASE_URL`: Đường dẫn kết nối CSDL PostgreSQL (Supabase).
*   `JWT_SECRET`: Chuỗi khóa bảo mật dùng để ký và xác thực JWT token.
*   `ALLOWED_ORIGINS`: Danh sách tên miền Frontend được phép gọi API (ví dụ: `https://frontend.vercel.app`), cách nhau bởi dấu phẩy.
*   `DB_SYNC`: Thiết lập thành `false` ở môi trường Production.

---

## 📄 Giấy phép (License)

Dự án này được cấp phép theo tiêu chuẩn **MIT License**.

