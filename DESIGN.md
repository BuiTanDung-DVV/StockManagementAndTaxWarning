# Design System: Quản lý Bán hàng & Kho hàng
**Target:** Hộ kinh doanh nhỏ lẻ tại Việt Nam
**Platforms:** Mobile-first (Flutter), Desktop, Web

## 1. Visual Theme & Atmosphere
Giao diện sạch sẽ, chuyên nghiệp nhưng gần gũi — dễ sử dụng cho chủ shop nhỏ không quen công nghệ. Phong cách **Clean Business Minimal** với card-based layout, thông tin rõ ràng, ưu tiên hiển thị số liệu quan trọng ngay đầu trang. Tone ấm áp, đáng tin cậy — không quá lạnh hay corporate.

## 2. Color Palette & Roles
- **Trust Blue (#2563EB):** Primary actions, active tabs, links — tạo cảm giác tin cậy, chuyên nghiệp
- **Growth Green (#16A34A):** Income, revenue, positive trends — thu nhập, tiền vào
- **Alert Red (#DC2626):** Expenses, warnings, overdue debts — chi phí, cảnh báo
- **Warm Amber (#F59E0B):** Pending status, low-stock alerts — trạng thái chờ
- **Soft Background (#F8FAFC):** Page background — nền nhẹ, dễ nhìn dài
- **Card White (#FFFFFF):** Card surfaces — nổi bật trên nền
- **Deep Text (#0F172A):** Headings, primary text — đậm, dễ đọc
- **Muted Text (#64748B):** Labels, secondary info — phụ, không gây rối mắt
- **Light Border (#E2E8F0):** Card borders, dividers — phân chia nhẹ nhàng

## 3. Typography Rules
- **Headings:** Inter 600 (Semibold), size 18-24px — rõ ràng, hiện đại
- **Body:** Inter 400 (Regular), size 14-16px — dễ đọc trên mobile
- **Numbers/Amounts:** Inter 700 (Bold), slightly larger — nhấn mạnh con số tiền
- **Labels:** Inter 400, 12-13px, uppercase tracking for section labels
- **Vietnamese text support:** Full diacritics rendering

## 4. Component Stylings
* **Buttons:** Generously rounded (8px), Trust Blue fill for primary, outlined for secondary. Height 44px+ for touch targets
* **Cards:** Gently rounded (12px), white surface, whisper-soft shadow (0 1px 3px rgba(0,0,0,0.1)). Slight hover elevation on desktop
* **Stats Cards:** Numbers large and bold (24-32px), label below in muted text, colored left border (4px) indicating type
* **Data Tables:** Alternating row backgrounds (#F8FAFC / #FFFFFF), clear headers, action buttons right-aligned
* **Inputs/Forms:** Rounded (8px), light gray border (#E2E8F0), 44px height, subtle focus ring in Trust Blue
* **Bottom Navigation:** 5 tabs with icons + Vietnamese labels, active tab in Trust Blue, inactive in Muted
* **Status Badges:** Pill-shaped, small, colored backgrounds with matching text

## 5. Layout Principles
- **Mobile:** Single column, generous padding (16px), sticky bottom nav
- **Desktop:** Sidebar navigation (240px) + main content area
- **Card grid:** 1 column mobile, 2-3 columns tablet, 4 columns desktop for stats
- **Whitespace:** 16px gap between cards, 24px section spacing
- **Charts:** Clean line/bar charts with Trust Blue as primary, Green/Red for income/expense

## 6. Design System Notes for Stitch Generation

**DESIGN SYSTEM (REQUIRED) — Copy this block into every Stitch prompt:**

Platform: Mobile, responsive. Theme: Light, clean business minimal.
Background: Soft Cloud Gray (#F8FAFC). Card surfaces: Pure White (#FFFFFF) with subtle shadow.
Primary Accent: Trust Blue (#2563EB) for buttons, active states, links.
Success/Income: Growth Green (#16A34A). Error/Expense: Alert Red (#DC2626). Warning: Warm Amber (#F59E0B).
Text Primary: Deep Slate (#0F172A). Text Secondary: Cool Gray (#64748B).
Borders: Light Steel (#E2E8F0). Typography: Inter font family, semibold headings, bold numbers.
Buttons: Rounded (8px), 44px height. Cards: Rounded (12px), soft shadow. Inputs: Rounded (8px), 44px height.
Bottom navigation with 5 tabs: Trang chủ, Bán hàng, Kho hàng, Tài chính, Tài khoản.
Vietnamese language for all labels and text.
