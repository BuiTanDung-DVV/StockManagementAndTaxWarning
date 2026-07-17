# SmartStock-Tax Comprehensive QA & Concurrency Testing Report

**Date**: 2026-07-13
**Status**: Completed (Static Codebase Audit + Multi-Agent Concurrent Runtime Simulation)
**Application URL**: https://smartstock-tax.vercel.app/
**API Base URL**: https://stock-management-and-tax-warning.vercel.app/api/

---

## Executive Summary

This report presents the findings of a comprehensive quality assurance and security audit of the SmartStock-Tax application. The evaluation was performed in two phases:
1. **Static Codebase Audit**: Analyzing the Flutter web frontend and Node.js/TypeScript backend for structural bugs, logic flaws, font rendering issues, and edge-case exceptions.
2. **Multi-Agent Concurrent Runtime Simulation**: Running a Node.js simulation script (`simulate_concurrency.js`) against the live server to model parallel user actions (Owner, Manager, Cashier, Storekeeper), verifying real-time data synchronization, permission boundaries, and API input boundary safety.

In total, **16 key findings** were discovered:
- **3 Critical Severity**: Permission bypasses and OTP validation bypasses.
- **4 High Severity**: System crashes, database failures, and query exceptions.
- **9 Medium/Low Severity**: Double-submission bugs, UI rendering errors, and logic discrepancies.

---

## 1. Concurrency Simulation & Sync Verification Results

A concurrent multi-agent simulation was executed using a zero-dependency script that registered three new employees, joined them to the test shop, approved their roles, and ran parallel transactions:

- **Onboarding & Approval Flow**:
  - Registered Cashier (`sim_cashier_[ts]@vlxd.com`), Storekeeper (`sim_storekeeper_[ts]@vlxd.com`), and Manager (`sim_manager_[ts]@vlxd.com`).
  - Fetched registration OTPs dynamically from the PostgreSQL Supabase database to bypass SMS/Email sandbox boundaries.
  - Successfully submitted join requests to shop ID 34 (`Cửa Hàng VLXD & Nội Thất Kiến Tạo`).
  - Logs in as Owner (`admin@kientao.com`) and successfully approved the members.
- **Real-Time Data Sync**:
  - **Cashier POS Transaction**: Created a retail invoice for 50,000 VND. Verified that the Owner's revenue dashboard was immediately updated by exactly 50,000 VND.
  - **Storekeeper Stock Take**: Committed a physical inventory balance adjustment for product 666 (Xi măng Hà Tiên) from `0` to `50`. Verified that both the Cashier's product view and the Owner's inventory view immediately reflected `50` units.
  - **Manager Tagging**: Created a unique tag and associated it with a product. Verified that the tag was successfully registered and filtered.
- **Input Boundary Scanning**:
  - **Empty password login**: Correctly rejected with `401 Unauthorized`.
  - **Negative sales price**: Correctly rejected with `400 Bad Request` ("Unit price cannot be negative").
  - **Duplicate barcodes**: Creating a duplicate barcode returned `409 Conflict` ("Mã vạch này đã tồn tại").

---

## 2. Detailed Bug Log & Findings

### 2.1. Critical Severity Findings (Risk: Maximum)

#### Finding 2.1.1: Tax Configuration Route Bypass Vulnerability (New - Runtime Simulation)
*   **Location**: `backend/src/index.ts` (lines 79-81) & `backend/src/routes/tax-config.routes.ts`
*   **Description**: In the backend entry point, `apiRouter.use('/', taxConfigRoutes)` is registered before `apiRouter.use('/tax', taxRoutes)`. The route `GET /tax/config` defined in `tax-config.routes.ts` does not implement role or permission checks.
*   **Impact**: Because it is registered first and matches the path `/api/tax/config`, restricted roles (e.g. `CASHIER` or `STOREKEEPER`) can bypass the permission checking middleware of the main tax router and retrieve or update shop tax configurations with `200 OK`.
*   **Remediation**: Apply permission check middleware (`requirePermission('tax', 'full')`) to `tax-config.routes.ts` or merge it under the protected `/api/tax` router.

#### Finding 2.1.2: Authorization Bypass in "All Shops" Mode
*   **Location**: `backend/src/middleware/permission.middleware.ts` (lines 28-35)
*   **Description**: When the client passes the header `x-shop-id: 'all'`, the permission middleware checks if the user is a member of at least one shop, but then immediately invokes `next()`, skipping all specific role/level validation gates.
*   **Impact**: Any employee belonging to at least one shop can bypass the permission gates on all endpoints (settings, finance, HR) in "All shops" mode.
*   **Remediation**: The middleware must iterate and validate that the user has the required permission for all shops (or at least one of the active shops) rather than immediately calling `next()`.

#### Finding 2.1.3: OTP Registration Bypass
*   **Location**: `backend/src/services/auth.service.ts` (lines 41-57)
*   **Description**: The registration endpoint verifies OTP only if the username matches phone or email formats (`if (isPhone || isEmail)`).
*   **Impact**: Providing a plain alphanumeric username (e.g., `admin`) skips the OTP verification checks entirely, letting users register without validating their contact details.
*   **Remediation**: Force all identifiers to adhere to valid phone or email structures and enforce OTP validation.

---

## 2.2. High Severity Findings (Risk: High)

#### Finding 2.2.1: TypeORM Missing Relation Bug on Pending Requests (New - Runtime Simulation)
*   **Location**: `backend/src/services/shop-member.service.ts` (line 45) & `backend/src/shop/entities.ts`
*   **Description**: Fetching pending requests calls `this.memberRepo.find({ where: { status: 'PENDING' }, relations: ['user', 'shop'] })`. However, the `ShopMember` entity does not have a relation property named `shop`.
*   **Impact**: Calling `GET /api/shop-members/pending` crashes with `500 Internal Server Error` ("Property \"shop\" was not found in \"ShopMember\""). Owners are unable to load the pending requests list.
*   **Remediation**: Remove `'shop'` from the relations array in `findAllPending()`, or define a proper ManyToOne relation to `ShopProfile` in the `ShopMember` entity.

#### Finding 2.2.2: Ephemeral Parameter Loss on `/verify-otp`
*   **Location**: `lib/core/router/app_router.dart` (lines 203-214) & `lib/features/auth/presentation/otp_verification_screen.dart`
*   **Description**: GoRouter defines the `/verify-otp` route utilizing `state.extra` to retrieve registration details. Because `state.extra` is ephemeral, page refreshes or deep links reset it to `null`.
*   **Impact**: Registering and then refreshing the OTP screen yields an empty email. Submitting OTP calls `/auth/register` with empty fields, causing DB corruption or crashes.
*   **Remediation**: Pass parameters in query parameters (`/verify-otp?email=...`) or persist them in a local state provider, and redirect to `/register` if state is lost.

#### Finding 2.2.3: "All Shops" Mode Database Write Crash
*   **Location**: `backend/src/middleware/auth.middleware.ts` & `backend/src/controllers/*`
*   **Description**: In "All Shops" mode, `req.shopId` is `undefined`. Several controllers query or write using `(req as any).shopId` directly.
*   **Impact**:
    1. **Empty Views**: TypeORM converts `undefined` to `WHERE shop_id IS NULL`, causing empty dashboards.
    2. **Write Crashes**: Creating any resource (product, customer) in "All shops" mode passes `null` to a `NOT NULL` DB column, throwing a constraint crash.
*   **Remediation**: Use `getShopId(req)` helper, use `In(shopIds)` queries for list endpoints, and strictly reject write requests when `isAllShops` is true.

#### Finding 2.2.4: fl_chart Layout Assertion Crash
*   **Location**: `lib/core/widgets/chart_widgets.dart` (line 273)
*   **Description**: If there is only one data point for a filtered period, `maxX` is evaluated as `0.0`. Since `minX` is also `0`, `maxX == minX`.
*   **Impact**: The `fl_chart` library throws an assertion exception (`maxX > minX` is violated), causing the dashboard screen to crash (Red screen).
*   **Remediation**: Ensure `maxX` is always strictly greater than `minX` (e.g., `maxX = maxLen > 1 ? (maxLen - 1).toDouble() : 1.0`).

---

## 2.3. Medium & Low Severity Findings (Risk: Moderate)

#### Finding 2.3.1: Insecure Cross-Shop Role Assignment
*   **Location**: `backend/src/services/shop-member.service.ts`
*   **Description**: The backend does not check if the assigned `roleId` belongs to the target `shopId`.
*   **Impact**: Malicious shop managers can assign roles belonging to other shops to override/inherit unauthorized permissions.
*   **Remediation**: Query `ShopRole` repository to verify that `roleId` belongs to the target `shopId` before saving.

#### Finding 2.3.2: Double Submission & Race Condition in OTP Screen
*   **Location**: `lib/features/auth/presentation/otp_verification_screen.dart` (lines 254-259)
*   **Description**: When the OTP input length hits 6 characters, `_verifyAndRegister()` is triggered. It lacks an `_isLoading` guard at the beginning of the function.
*   **Impact**: Rapid typing or double clicking sends concurrent registration API calls, causing SQL unique constraint crashes.
*   **Remediation**: Add `if (_isLoading) return;` at the beginning of all async UI button callbacks.

#### Finding 2.3.3: Tag Substring Collisions & Deserialization Bugs
*   **Location**: `backend/src/services/product.service.ts` (line 37) & `backend/src/product/entities.ts`
*   **Description**: Tags are stored as a `simple-array` (comma-separated string). The query filters with `ILIKE %tag%`.
*   **Impact**:
    1. **Collisions**: Filtering for `"VIP"` returns products containing `"VIPER"`.
    2. **Corruption**: Creating a tag with a comma splits it into two separate tags on retrieval.
*   **Remediation**: Replace `simple-array` with a dedicated `Tag` entity/table or use PostgreSQL array operators (`ANY`).

#### Finding 2.3.4: Raw TextStyles causing Vietnamese character fallbacks
*   **Location**: `lib/core/widgets/chart_widgets.dart` (lines 241, 405, 439, 538)
*   **Description**: Chart labels use raw `TextStyle()` objects rather than inheriting font configurations from the theme (Outfit/Inter).
*   **Impact**: Vietnamese diacritics fail to render on browsers lacking system fonts, causing character corruption.
*   **Remediation**: Explicitly use `GoogleFonts.outfit()` or inherit styles from `Theme.of(context)`.

#### Finding 2.3.5: Lack of Backend Password Strength Validation
*   **Location**: `backend/src/services/auth.service.ts` & `backend/src/services/profile.service.ts`
*   **Description**: The backend does not validate password complexity on registration and password changes.
*   **Impact**: Bypassing the frontend allows users to set weak passwords (e.g. `"1"`) through API tools.
*   **Remediation**: Add a backend password strength validation helper.

#### Finding 2.3.6: OTP Brute-Force Vulnerability
*   **Location**: `backend/src/services/auth.service.ts`
*   **Description**: The OTP validation checks for expiration but does not limit the number of failed attempts.
*   **Impact**: Attackers can brute-force the 6-digit OTP code within the 2-minute window.
*   **Remediation**: Track and limit failed verification attempts to 5 per phone/email before lockout.

#### Finding 2.3.7: Inconsistent Phone Number Regex Patterns
*   **Location**: `backend/src/services/auth.service.ts` (line 21 & line 178)
*   **Description**: Registration validates phone format with `/^(0|\+84)\d{8,9}$/` (9-10 digits), while the OTP sender validates with `/^(0|\+84)\d{8,11}$/`.
*   **Impact**: Users with 11-12 digit phone numbers receive OTP but fail registration.
*   **Remediation**: Unify regex patterns using a single validator.

#### Finding 2.3.8: Shop Code Null Display in Search UI
*   **Location**: `backend/src/services/auth.service.ts` & `join_shop_dialog.dart`
*   **Description**: The public `/auth/search-shops` endpoint projects out `shopCode` for security, but the frontend UI tries to read it, rendering `"Mã: null"`.
*   **Impact**: Users cannot see or verify the shop's ID code when searching and applying.
*   **Remediation**: Expose a redacted or non-sensitive hash, or select the code safely for display if shop is public.

#### Finding 2.3.9: Consent-free Staff Direct Invitation
*   **Location**: `backend/src/services/shop-member.service.ts` (lines 77-84)
*   **Description**: Direct invitations immediately create an `ACTIVE` shop relationship without employee approval.
*   **Impact**: Shop owners can forcefully associate users to their shops without their consent.
*   **Remediation**: Change membership status to `PENDING` by default and require the employee to accept.

---

## 3. Recommended Remediation Roadmap

1.  **Immediate Security Hotfixes**:
    *   Fix the router declaration order in `index.ts` so `taxRoutes` handles tax configurations under permission checks, or add `requirePermission` middleware to `taxConfigRoutes`.
    *   Fix `permission.middleware.ts` to perform multi-shop permission array validation when `x-shop-id` is `'all'`.
2.  **Liveness & Stability Fixes**:
    *   Update `shop-member.service.ts` to remove `'shop'` relation from pending requests query to fix the 500 error on HR approvals.
    *   Add query parameters or local storage to `/verify-otp` to resolve parameter loss on page refresh.
    *   Handle `maxLen == 1` in chart widgets to prevent fl_chart assertions.
3.  **Data Integrity & Robustness**:
    *   Replace `simple-array` tags with structured relationships.
    *   Add backend validation for password strength and role check domains.
