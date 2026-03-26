# AGENTS.md — Sales & Stock Management (Flutter + Express + TypeORM)

## Big picture (read these first)
- Flutter app in `lib/` talks to backend via `Dio` wrapper `lib/core/network/api_client.dart`.
  - Base URL: `http://10.0.2.2:8080/api` (Android emulator → host localhost).
  - **Contract**: backend typically returns `{ success, data, message }`; `ApiClient._extract()` returns only `data`.
- Backend is Express in `backend/src/index.ts`: mounts routers under `/api/*` and starts server on `config.port` (`backend/src/config/env.config.ts`, default `8080`).

## Backend conventions (Express + TypeORM + SQL Server)
- Layering:
  - Routes: `backend/src/routes/*.routes.ts` (define endpoints)
  - Controllers: `backend/src/controllers/*.controller.ts` (thin JSON wrapper)
  - Services: `backend/src/services/*.service.ts` (DB/business logic via TypeORM repos)
- Auth endpoints live at `/api/auth/*` (see `backend/src/routes/auth.routes.ts`):
  - `POST /auth/register`, `POST /auth/login`, `POST /auth/forgot-password`, `POST /auth/reset-password`
- JWT:
  - Middleware: `backend/src/middleware/auth.middleware.ts` expects `Authorization: Bearer <token>`.
  - Flutter saves token to `SharedPreferences` key `auth_token` (`ApiClient.saveToken/loadToken`).
- Database:
  - Config in `backend/src/config/db.config.ts` uses SQL Server + `msnodesqlv8` (Windows integrated auth).
  - Defaults: `DB_HOST=DAOVOVI`, `DB_DATABASE=QLKH` (`backend/src/config/env.config.ts`).
  - Schema reference: `backend/database/QLKH.sql`.

## Flutter conventions (Riverpod + go_router)
- App bootstrap: `lib/main.dart` creates `ApiClient`, loads token, and overrides `apiClientProvider`.
- Auth state: `lib/features/auth/providers/auth_provider.dart`.
  - Note: `AuthNotifier.login()` calls `/auth/login` and expects response `data` to include `access_token` + `user`.
- Routing is centralized in `lib/core/router/app_router.dart`.

## Dev workflows (Windows / PowerShell)
```powershell
# Flutter
Set-Location D:\SalesAndStockManagement
flutter pub get
flutter run

# Backend
Set-Location D:\SalesAndStockManagement\backend
npm install
npm run dev
```

### Fix: `EADDRINUSE :::8080` (port already used)
```powershell
netstat -ano | Select-String ":8080"
# find the PID in the last column, then:
taskkill /PID <PID> /F
```
Or change port via env var: set `PORT=8081` (and update `ApiClient.baseUrl` if needed).

## Response shape gotcha
- Keep responses consistent with Flutter extraction:
  - Prefer `res.json({ success: true, data: payload, message })`.
  - If you return `{ success: true, access_token: ... }` (like current `login`), Flutter will **not** see it unless wrapped inside `data`.

## Other docs
- Product/design notes: `SITE.md`, `DESIGN.md`.

