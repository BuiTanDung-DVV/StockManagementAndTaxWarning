<div align="center">
  <img src="https://raw.githubusercontent.com/BuiTanDung-DVV/StockManagementAndTaxWarning/main/web/icons/Icon-192.png" alt="SmartStock Logo" width="120" height="120">

  # SmartStock & Tax Warning System

  **Enterprise-Grade Sales, Multi-Shop Inventory, Financial Accounting & AI-Grounded Tax Compliance Solution**

  [![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Node.js](https://img.shields.io/badge/Node.js-43853D?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
  [![TypeScript](https://img.shields.io/badge/TypeScript-007ACC?style=for-the-badge&logo=typescript&logoColor=white)](https://www.typescriptlang.org)
  [![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
  [![Google Gemini](https://img.shields.io/badge/Google%20Gemini%20AI-8E75C2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev/)
  [![Vercel](https://img.shields.io/badge/Vercel-000000?style=for-the-badge&logo=vercel&logoColor=white)](https://vercel.com)
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

  [Overview](#-overview) •
  [Key Features](#-key-features) •
  [Architecture](#-architecture) •
  [Tech Stack](#-tech-stack) •
  [Design System & UI/UX](#-design-system--uiux) •
  [BA Documents & Audits](#-business-analysis-ba--quality-audits) •
  [Getting Started](#-getting-started) •
  [Testing & Verification](#-automated-testing--data-integrity) •
  [Deployment](#-deployment)
</div>

---

## 🎯 Overview

**SmartStock & Tax Warning** is an end-to-end, enterprise-grade business management and tax compliance platform designed for small-and-medium enterprises (SMEs) and individual household businesses (*Hộ Kinh Doanh Cá Thể*) in Vietnam. 

The system solves critical operational pain points during the digital transition:
1. **Seamless Point-of-Sale (POS) & Dynamic VietQR Payments**: Accelerated checkout with automated barcode scanning and instant QR payment generation compliant with NAPAS standards.
2. **Deep Financial Bookkeeping & Cashflow Auditing**: Double-entry journal ledgers, daily shift closings, comprehensive debt aging reports, and cashflow forecasting.
3. **Legal Tax Grounding with Google Gemini AI**: RAG-based legal advisor synthesizing live store snapshots (inventory, revenue, receivables) with current Vietnamese Tax Circulars (Thông tư 88/2021/TT-BTC, Thông tư 40/2021/TT-BTC, Luật Quản lý thuế).
4. **Electronic Invoicing & Risk Auditing**: OCR input invoice scanning, e-invoice registry, and non-invoice expense tracking to mitigate tax inspection risks.
5. **Standardized HTKK XML Integration**: Export automated tax declaration files strictly compatible with General Department of Taxation software (Mẫu 01/CNKD).

Live Demo Application: **[https://smartstock-tax.vercel.app/](https://smartstock-tax.vercel.app/)**

---

## ✨ Key Features

### 🛒 1. Point of Sale (POS) & Smart Sales Management
* **Touch-Friendly POS Terminal**: Fast product search, barcode scanner integration, cart management, and draft orders.
* **Dynamic VietQR & NAPAS Integration**: Instant QR payment generation with amount, bank code, and order-specific payment memos. Automated QR code image parsing and verification via `jsqr` & `sharp`.
* **Returns & Refunds (Đổi trả hàng)**: Transparent workflow for item returns, reason tracking, and automated inventory / ledger reconciliations.
* **Thermal Printing & Invoicing**: Export thermal receipt templates (58mm/80mm) and PDF invoices via `printing`.

### 📦 2. Advanced Multi-Shop Inventory & Warehouse Control
* **Real-time Stock Tracking**: Real-time tracking across single or multiple warehouse locations (*All-shops mode*).
* **Lot & Expiry Tracking (Quản lý lô & Hạn sử dụng)**: FIFO cost calculation, near-expiry alerts, and low-stock threshold triggers.
* **XNT Accounting Report (Báo cáo Xuất - Nhập - Tồn)**: Formal opening/closing balance, inbound purchase, outbound sales, and variance tracking.
* **Stock-take (Kiểm kê kho)**: Multi-stage stock counting with progress tracking, discrepancy recording, and automated stock balance adjustments.
* **Product Catalog Presentation**: Toggle between interactive **Grid View** (with product images, stock status ribbons) and **Data-dense List View**. Cloudinary CDN cloud media synchronization.

### 🤖 3. Grounded AI Tax Advisor & Legal Knowledge Base
* **Store Context Snapshot RAG**: Feeds real-time operational metrics (daily revenue, inventory value, receivables, tax brackets) into the Google Gemini LLM context.
* **Verified Legal Grounding**: Automatically matches queries against Vietnamese tax laws, providing verifiable citations (articles, clauses, official decrees).
* **Knowledge Document Management**: Admin UI to upload, update, and manage legal policies and store tax advisory documents.

### 💼 4. Deep Financial Accounting & Receivables
* **Double-Entry Journal Ledger**: Full trace of cash, bank, revenue, expenses, and tax liabilities.
* **Daily Closing (Chốt sổ ca/ngày)**: Reconciliation of physical cash drawer, electronic bank transfers, sales returns, and cash discrepancies.
* **Debt Aging Analysis (Báo cáo Tuổi nợ)**:
  * **Customer Receivables Aging**: Grouped by 0–30, 31–60, 61–90, and 90+ days.
  * **Supplier Payables Aging**: Track upcoming supplier payments and credit terms.
* **Cashflow Forecast**: Predictive projection of cash inflows and outflows across rolling periods.
* **Expense & Salary Ledgers**: Record operational expenditures and staff payroll allocations.
* **Excel Data Export**: Deterministic CSV/Excel export service with **UTF-8 BOM** ensuring perfect Vietnamese character rendering in Microsoft Excel.

### 🧾 5. E-Invoicing, OCR Scanning & Tax Warning Engine
* **Input Invoice OCR Scanner**: Upload and extract seller information, tax codes, line items, and VAT totals from scanned purchase invoices.
* **Purchase Without Invoice (Hàng mua vào không hóa đơn)**: Track non-invoiced expenses to evaluate tax risk and deduction eligibility.
* **Automated Tax Calculator**: Dynamic calculation of VAT and PIT liabilities based on business activity tax rates according to Circular 40/2021/TT-BTC.
* **Tax Obligation Calendar**: Proactive deadline tracker with countdown indicators for quarterly and annual tax declarations.
* **HTKK XML Declaration Export**: Generates compliant XML files for direct submission to the national tax portal (Mẫu 01/CNKD).

### 🔐 6. RBAC & Multi-Shop Operations
* **Multi-tier Roles**: Granular permission boundaries for `Owner`, `Manager`, and `Staff`.
* **Onboarding & Member Approval Workflow**: New accounts request store membership and remain in `waiting_approval` state until authorized by the shop owner.
* **Audit Trail (Activity Log)**: System-wide logging of sensitive operations (price overrides, inventory corrections, voided invoices).
* **Store Configurations**: Custom receipt templates, shipping carrier settings, database backup and restoration.

---

## 🏛 Architecture

The project is structured as a **clean, modular monorepo** with a separated frontend client and domain-driven backend API.

```text
StockManagementAndTaxWarning/
├── backend/                             # Express.js REST API & Services
│   ├── database/                        # PostgreSQL schema & SQL migrations
│   ├── src/
│   │   ├── ai/                          # Legal grounding utils & shop context RAG
│   │   ├── auth/                        # JWT authentication & Google OAuth
│   │   ├── common/                      # Shared DTOs, interceptors, error guards
│   │   ├── config/                      # Database (TypeORM), env & Supabase config
│   │   ├── controllers/                 # HTTP controllers & route handlers
│   │   ├── customer/                    # Customer CRM & debt ledgers
│   │   ├── dashboard/                   # Aggregated KPI metrics & insights
│   │   ├── finance/                     # Ledgers, P&L, aging, cashflow forecast
│   │   ├── inventory/                   # Stock items, lots, XNT reports, stock-take
│   │   ├── middleware/                  # Auth guards, RBAC, helmet, rate-limiting
│   │   ├── party/ & supplier/           # Supplier management & procurement
│   │   ├── product/                     # Catalog, categories, tags, Cloudinary images
│   │   ├── quality/                     # Data reconciliation & validation scripts
│   │   ├── routes/                      # API endpoint definitions
│   │   ├── sales/                       # Orders, POS, returns, pricing policies
│   │   ├── scripts/                     # Seeders (3-year data), audit & migrations
│   │   ├── services/                    # Business logic & TypeORM repositories
│   │   ├── shop/                        # Shop profile, multi-shop scope, branches
│   │   ├── system/                      # VietQR parsing, settings, audit logs
│   │   └── tax/                         # Tax policy, obligation & HTKK XML generator
│   └── vercel.json                      # Vercel serverless deployment config
│
├── lib/                                 # Flutter Frontend Application
│   ├── core/                            # Shared infrastructure & utilities
│   │   ├── assets/                      # Asset registry & SVG motifs
│   │   ├── network/                     # Dio HTTP client & token interceptors
│   │   ├── router/                      # GoRouter config & permission guards
│   │   ├── theme/                       # Theme tokens (Dark/Light) & typography
│   │   ├── utils/                       # UTF-8 BOM Excel export, formatting
│   │   └── widgets/                     # Shared UI, Split-canvas Auth, FlChart widgets
│   └── features/                        # Feature-first modular presentation & state
│       ├── auth/                        # Login, Register, OTP verification, Approval
│       ├── customers/                   # Customer list, CRM, receivables
│       ├── dashboard/                   # Metric cards, pastel KPI insights, charts
│       ├── finance/                     # P&L, Debt aging, Cashflow, OCR, Ledgers
│       ├── inventory/                   # Stock, Purchase Orders, XNT, Stock-take
│       ├── products/                    # Catalog (Grid/List), Barcodes, Tags
│       ├── sales/                       # POS Screen, VietQR payment modal, Orders
│       ├── settings/                    # Tax config, VietQR setup, Staff, Logs
│       ├── shell/                       # Navigation shell, responsive sidebar
│       ├── suppliers/                   # Supplier directory & payables
│       └── tax/                         # Tax estimates, obligations, HTKK export
│
├── assets/                              # Offline fonts (Inter, Manrope), icons, Lottie
├── BA_DOCUMENTS/                        # 50+ Business requirements, audits & specs
├── scripts/                             # Antigravity automated visual audit scripts
└── DEMO Screen/                         # UI Design System references & benchmark mockups
```

---

## 💻 Tech Stack

### Frontend (Client)
* **Framework:** [Flutter](https://flutter.dev/) (Web, Windows, Android, iOS)
* **State Management:** [Riverpod](https://riverpod.dev/) (`flutter_riverpod`, `riverpod_annotation`)
* **Routing & Navigation:** [GoRouter](https://pub.dev/packages/go_router) with reactive route guards
* **Networking & Interceptors:** [Dio](https://pub.dev/packages/dio)
* **Data Visualization:** [FlChart](https://pub.dev/packages/fl_chart) (Interactive line, bar, donut charts)
* **Design & Icons:** [Hugeicons](https://pub.dev/packages/hugeicons), [Google Fonts](https://pub.dev/packages/google_fonts), [Shimmer](https://pub.dev/packages/shimmer), [Lottie](https://pub.dev/packages/lottie)
* **Printing & Hardware:** [Printing](https://pub.dev/packages/printing), [PDF](https://pub.dev/packages/pdf), [Image Picker](https://pub.dev/packages/image_picker)
* **Authentication:** Google Sign-In (`google_sign_in`), Secure Storage (`flutter_secure_storage`)

### Backend (Server)
* **Runtime:** [Node.js](https://nodejs.org/) (v18+) & [TypeScript](https://www.typescriptlang.org/)
* **Framework:** [Express.js](https://expressjs.com/) v5
* **ORM:** [TypeORM](https://typeorm.io/) with custom repository layers
* **Database:** PostgreSQL (Hosted on [Supabase](https://supabase.com/))
* **Generative AI & LLM:** [Google Gemini API](https://ai.google.dev/) (`@google/generative-ai`)
* **Computer Vision & Media:** [Cloudinary SDK](https://cloudinary.com/), [Sharp](https://sharp.pixelplumbing.com/), [jsQR](https://github.com/cozmo/jsQR)
* **Security:** [Helmet](https://helmetjs.github.io/), [express-rate-limit](https://github.com/express-rate-limit/express-rate-limit), [bcrypt](https://github.com/kelektiv/node.bcrypt.js), [jsonwebtoken](https://github.com/auth0/node-jsonwebtoken)
* **Validation & Data:** [Zod](https://zod.dev/), [xml2js](https://github.com/Leonidas-from-XIV/node-xml2js), [nodemailer](https://nodemailer.com/)

---

## 🎨 Design System & UI/UX

The application follows modern enterprise design principles outlined in [BA_DOCUMENTS/UI_COMPARISON_AND_SYSTEM_BENCHMARK.md](file:///d:/StockManagementAndTaxWarning/BA_DOCUMENTS/UI_COMPARISON_AND_SYSTEM_BENCHMARK.md):
1. **Calibrated Color Palette**: Soft pastel backgrounds for metric tiles (`#E0F2FE` revenue, `#FEF3C7` inventory, `#EDE9FE` tax indicators) providing clear visual hierarchy without cognitive fatigue.
2. **Typography**: Bundled local fonts (`Inter` and `Manrope`) guarantee offline availability and prevent Web font jumping (FOIT/FOUT).
3. **Responsive Viewport Standard**:
   * **Mobile (390×844)**: Touch-optimized compact views, bottom drawer sheets, sticky checkout bar.
   * **Tablet (768×1024)**: Adaptive side-sheet navigation, split screens.
   * **Desktop (1440×900)**: Multi-column layouts, data tables with frozen headers, expandable insight sidebars.
4. **Dual-Workspace Paradigm**: Clear separation between high-speed **POS Checkout** and deep **Back-office Management**.

---

## 📚 Business Analysis (BA) & Quality Audits

The repository maintains an extensive collection of formal software engineering documentation in the [BA_DOCUMENTS/](file:///d:/StockManagementAndTaxWarning/BA_DOCUMENTS/) directory:

* **Core Specifications:**
  * [01_BUSINESS_REQUIREMENT_DOCUMENT_BRD.md](file:///d:/StockManagementAndTaxWarning/BA_DOCUMENTS/01_BUSINESS_REQUIREMENT_DOCUMENT_BRD.md) — Core business goals & legal context.
  * [02_SYSTEM_REQUIREMENT_SPECIFICATION_SRS.md](file:///d:/StockManagementAndTaxWarning/BA_DOCUMENTS/02_SYSTEM_REQUIREMENT_SPECIFICATION_SRS.md) — Functional and non-functional requirements.
  * [03_DATA_DICTIONARY_AND_SCHEMA.md](file:///d:/StockManagementAndTaxWarning/BA_DOCUMENTS/03_DATA_DICTIONARY_AND_SCHEMA.md) — Comprehensive database schema dictionary.
  * [04_USER_ROLES_AND_RBAC_MATRIX.md](file:///d:/StockManagementAndTaxWarning/BA_DOCUMENTS/04_USER_ROLES_AND_RBAC_MATRIX.md) — Granular permission matrix across roles.
  * [05_TAX_COMPLIANCE_GUIDELINES.md](file:///d:/StockManagementAndTaxWarning/BA_DOCUMENTS/05_TAX_COMPLIANCE_GUIDELINES.md) — Detailed tax rules according to Circulars 88 & 40.
* **Design & Benchmarks:**
  * [UI_COMPARISON_AND_SYSTEM_BENCHMARK.md](file:///d:/StockManagementAndTaxWarning/BA_DOCUMENTS/UI_COMPARISON_AND_SYSTEM_BENCHMARK.md) — Comparison against industry leaders (KiotViet, Sapo, Odoo).
  * [AUTOMATED_TEST_WORKFLOW.md](file:///d:/StockManagementAndTaxWarning/BA_DOCUMENTS/AUTOMATED_TEST_WORKFLOW.md) — Specification for production visual audits.

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.11+)
* [Node.js](https://nodejs.org/) (v18.0+)
* [Git](https://git-scm.com/)

---

### 1. Backend Setup

```bash
# Navigate to backend directory
cd backend

# Install dependencies
npm install

# Setup environment configuration
cp .env.example .env
```

> **Configuration (`backend/.env`):**
> Configure `DATABASE_URL` (Supabase / Postgres), `JWT_SECRET`, `GEMINI_API_KEY`, and `CLOUDINARY_*` credentials.

```bash
# Apply verified migrations
npm run migrate:tax-policy
npm run migrate:payment-qr

# Optional: Seed realistic 3-year store dataset for testing
npm run seed:three-years

# Run backend development server
npm run dev
```
*The API server will run locally at `http://localhost:8080`.*

---

### 2. Frontend Setup

```bash
# Navigate back to project root
cd ..

# Fetch Flutter dependencies
flutter pub get

# Launch Flutter Web app
flutter run -d chrome
```

---

## 🧪 Automated Testing & Data Integrity

The project incorporates rigorous testing routines across both backend domain logic and frontend UI:

### Backend Tests & Reconciliation Scripts
```bash
cd backend

# Run 50+ critical P0 domain & security tests
npm run test:p0

# Audit store data integrity (COGS, inventory grain, tax basis)
npm run audit:data
npm run audit:xnt
npm run audit:invoices
```

### Frontend Automated Testing
```bash
# Run all unit and widget tests
flutter test

# Execute automated multi-viewport production test audit
node scripts/antigravity-test.mjs run
```

---

## ☁️ Deployment

### Production Infrastructure
* **Frontend Web Application:** Hosted on [Vercel](https://vercel.com) with automated builds (`flutter build web --release`).
* **Backend REST API:** Deployed as optimized Serverless Functions on Vercel (`backend/vercel.json`).
* **Cloud Database:** Hosted on [Supabase PostgreSQL](https://supabase.com/) with connection pooling.
* **Media Assets:** Hosted on [Cloudinary CDN](https://cloudinary.com/).

---

## 🛡️ License

This project is licensed under the **MIT License**. See the [LICENSE](file:///d:/StockManagementAndTaxWarning/LICENSE) file for more details.

<div align="center">
  <i>SmartStock & Tax Warning System — Built with ❤️ for SME digital transformation.</i>
</div>
