<div align="center">
  <img src="https://raw.githubusercontent.com/BuiTanDung-DVV/StockManagementAndTaxWarning/main/web/icons/Icon-192.png" alt="Logo" width="120" height="120">

  # SmartStock & Tax Warning System

  **Comprehensive Sales, Inventory, and Tax Management Solution**

  [![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Node.js](https://img.shields.io/badge/Node.js-43853D?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
  [![TypeScript](https://img.shields.io/badge/TypeScript-007ACC?style=for-the-badge&logo=typescript&logoColor=white)](https://www.typescriptlang.org)
  [![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
  [![Vercel](https://img.shields.io/badge/Vercel-000000?style=for-the-badge&logo=vercel&logoColor=white)](https://vercel.com)
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

  [Features](#-key-features) •
  [Architecture](#-architecture) •
  [Getting Started](#-getting-started) •
  [Tech Stack](#-tech-stack) •
  [Deployment](#-deployment)
</div>

---

## 🎯 Overview

**SmartStock & Tax Warning** is an enterprise-grade monorepo application designed for small to medium businesses (SMEs) and individual household businesses (Hộ Kinh Doanh). It seamlessly integrates POS (Point of Sale), advanced inventory tracking, finance ledgers, and automated tax obligation warnings based on regional compliance.

## ✨ Key Features

*   🛒 **Point of Sale (POS) & Sales Management:** 
    * Fast checkout process with barcode scanning support.
    * Order tracking, invoice generation, and sales returns management.
*   📦 **Advanced Inventory Control:** 
    * Track stock levels in real-time.
    * Lot tracking, FIFO cost calculation, and low-stock/expiring product alerts.
    * Purchase orders and stock-take management.
*   💼 **Finance & Ledgering:** 
    * Double-entry bookkeeping system (Journal Ledger).
    * Track Cost of Goods Sold (COGS), daily cashflow, and profit/loss statements.
*   📊 **Tax Warning & Compliance:** 
    * Automated estimation of Value Added Tax (VAT) and Personal Income Tax (PIT).
    * Export XML declarations compatible with HTKK (Mẫu 01/CNKD).
*   🔐 **Role-Based Access Control (RBAC):** 
    * Multi-tier access for Owners, Managers, and Staff members.

---

## 🏛 Architecture

The project is structured as a **Monorepo** containing both the Flutter frontend application and the Express.js backend API, allowing for streamlined development and deployment.

```text
StockManagementAndTaxWarning/
├── backend/                  # Node.js REST API
│   ├── src/                  
│   │   ├── config/           # Database & Environment configurations
│   │   ├── controllers/      # HTTP Request handlers
│   │   ├── middleware/       # JWT Auth, CORS, Error Handling
│   │   ├── routes/           # Express Route definitions
│   │   └── services/         # Core Business Logic & TypeORM Repositories
│   └── vercel.json           # Serverless Deployment Config
│
├── lib/                      # Flutter Frontend App
│   ├── core/                 # Shared utilities, routing (GoRouter), theme
│   └── features/             # Feature-based modular architecture
│       ├── auth/             # Authentication & Onboarding
│       ├── sales/            # POS & Order Management
│       ├── inventory/        # Stock, Purchase Orders
│       ├── finance/          # Cashflow, Ledger
│       └── tax/              # Tax Estimation & HTKK Export
│
├── android/, ios/, web/      # Flutter platform-specific wrappers
└── .env.example              # Example environment variables
```

---

## 💻 Tech Stack

### Frontend (Client)
- **Framework:** [Flutter](https://flutter.dev/) (Web, Android, iOS, Windows)
- **State Management:** [Riverpod](https://riverpod.dev/)
- **Routing:** [GoRouter](https://pub.dev/packages/go_router)
- **Networking:** [Dio](https://pub.dev/packages/dio)

### Backend (Server)
- **Runtime:** [Node.js](https://nodejs.org/)
- **Framework:** [Express.js](https://expressjs.com/)
- **Language:** TypeScript
- **ORM:** [TypeORM](https://typeorm.io/)
- **Database:** PostgreSQL (Hosted on [Supabase](https://supabase.com/))

---

## 🚀 Getting Started

### Prerequisites
Before you begin, ensure you have the following installed:
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19+)
*   [Node.js](https://nodejs.org/) (v18+)
*   [Git](https://git-scm.com/)

### 1. Backend Setup

```bash
# Navigate to the backend directory
cd backend

# Install dependencies
npm install

# Create environment configuration
cp .env.example .env
```
> Edit `.env` and fill in your `DATABASE_URL` and `JWT_SECRET`.

```bash
# Start the development server
npm run dev
```
*The API will run locally at `http://localhost:8080`.*

### 2. Frontend Setup

```bash
# Navigate to the project root (Flutter directory)
cd ..

# Install Flutter dependencies
flutter pub get

# Run the app on Chrome (Web) or Emulator
flutter run -d chrome
```

---

## ☁️ Deployment

### Backend (Vercel)
The backend is optimized for Vercel Serverless Functions.
1. Import the repository to Vercel.
2. Set the Root Directory to `backend/`.
3. Add the following Environment Variables in the Vercel Dashboard:
   - `DATABASE_URL`
   - `JWT_SECRET`
   - `ALLOWED_ORIGINS` (e.g., `https://your-frontend-domain.vercel.app`)

### Frontend (Vercel / Firebase Hosting)
To deploy the Flutter Web app:
```bash
flutter build web --release
```
Upload the contents of the `build/web` directory to your preferred hosting provider.

---

## 🛡️ License

This project is licensed under the **MIT License**. See the `LICENSE` file for more details.

<div align="center">
  <i>Built with ❤️ for SME digital transformation.</i>
</div>
