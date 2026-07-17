# Context Document

## Mission & Objectives
Perform a comprehensive QA & UI/UX Testing of the SmartStock-Tax application (sales management and tax support application) located at `https://smartstock-tax.vercel.app/`.

## Scope & Requirements
The testing must cover the following three main areas:
1. **Authentication & Security:**
   - Account registration (`/register`) and OTP verification (`/verify-otp`).
   - Password Strength Meter (real-time strength feedback).
   - Real-time password matching status.
   - User login and password change inside Settings.
2. **Shop & Staff Management:**
   - "No shop" flow (Search and Join shop).
   - Branch switching and "All shops" (Tất cả cửa hàng - Tổng quát) dashboard view.
   - Staff approval in HR/Staff management.
3. **Core Features & UI/UX:**
   - Dashboard chart display.
   - Product tag management.
   - Vietnamese UTF-8 font display (no corrupted characters like `Tá»•ng quan`).
   - Button responsiveness.

## Tech Stack
- **Frontend:** Flutter Web (compiled to CanvasKit web renderer)
- **Backend:** Express.js, TypeScript, PostgreSQL (TypeORM, Supabase)
- **State Management:** Riverpod
- **Routing:** GoRouter

## Verification & Execution Approach
Since we are operating in `CODE_ONLY` network mode, we will:
1. Dissect and audit the local Flutter and Express.js codebase to locate and inspect the implementation of the target features.
2. Formulate test hypotheses and check the client-side logic (e.g. password strength validations, router configurations, font setup, font assets, canvas rendering flags, HTTP client requests, etc.) to verify correctness.
3. Review existing backend api tests (`backend/run_api_tests.js`) and database configurations.
4. Prepare a detailed QA Report synthesizing findings for all requirements.
