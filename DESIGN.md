# Design System: Smart Stock & Tax Management

## 1. Visual Theme & Atmosphere
A restrained, data-dense, and highly functional interface optimized for professional B2B software. The atmosphere is clinical yet sharp — like a well-lit modern accounting firm. The layout prioritizes information density and readability ("Cockpit Dense") over excessive negative space, while maintaining a predictable, symmetrical grid structure for rapid data scanning. Motion is functional and restrained, serving only to confirm user actions or guide attention.

## 2. Color Palette & Roles
- **Canvas White** (`#F9FAFB`) — Primary background surface for the application frame.
- **Pure Surface** (`#FFFFFF`) — Card and container fill, used to elevate content blocks above the canvas.
- **Charcoal Ink** (`#18181B`) — Primary text, Zinc-950 depth for headings and high-priority data points.
- **Muted Steel** (`#71717A`) — Secondary text, table headers, descriptions, and metadata.
- **Whisper Border** (`rgba(226,232,240,0.8)`) — Card borders, table dividers, and 1px structural lines.
- **Cobalt Accent** (`#2563EB`) — Single primary accent for CTAs, active states, focus rings, and primary data visualizations.
- **Emerald Success** (`#10B981`) — Semantic positive indicators (profit, completed orders).
- **Crimson Danger** (`#EF4444`) — Semantic negative indicators (low stock warnings, losses).

## 3. Typography Rules
- **Display/Headlines:** `Geist` — Track-tight, controlled scale, weight-driven hierarchy. Used for section titles and massive KPIs.
- **Body:** `Geist` — Relaxed leading, neutral secondary color for standard interface text.
- **Mono:** `Geist Mono` or `JetBrains Mono` — MANDATORY for all financial numbers, stock quantities, SKU codes, timestamps, and tabular data to ensure vertical alignment.
- **Banned:** `Inter` and any generic serif fonts (`Times New Roman`, `Georgia`). Serifs are strictly banned in this dashboard context.

## 4. Component Stylings
- **Buttons:** Flat, geometric, no outer glow. Tactile -1px translate on active press. Solid Cobalt fill for primary actions; subtle gray background for secondary actions.
- **Cards:** Crisp, moderately rounded corners (0.5rem - 0.75rem). Use a 1px `Whisper Border` instead of heavy drop shadows to separate cards from the canvas. High-density data regions should replace cards with simple border-top dividers or subtle zebra-striping.
- **Inputs & Forms:** Label strictly above the input. Focus ring strictly in Cobalt Accent. Error text in Crimson below the input. No floating or animated labels.
- **Data Tables:** Dense padding (max 12px vertical). Right-aligned numeric columns. Sticky headers. 
- **Loaders:** Skeletal shimmer matching exact layout dimensions. No generic circular spinners.
- **Empty States:** Composed, subtle illustrated compositions — not just "No data" text. Provide an immediate primary CTA to populate the empty state (e.g., "Add your first product").

## 5. Layout Principles
- Strict grid-first responsive architecture.
- Multi-column dashboard widgets (e.g., 2 or 3 columns of metric cards) must cleanly wrap into a single column below 768px.
- No overlapping elements — every element occupies its own clear spatial zone. No absolute-positioned floating content obscuring data.
- Vertical section gaps are restrained but clear (`1.5rem` to `2.5rem`).
- The generic "3 equal cards horizontally" feature row is BANNED — use an asymmetric grid (e.g., 2-column with a wider left pane for complex charts and a narrower right pane for activity feeds).

## 6. Motion & Interaction
- **Functional Spring Physics:** `stiffness: 120, damping: 20` for rapid, snappy, non-distracting UI feedback.
- Hardware-accelerated transforms only (animate `transform` and `opacity`, never `height` or `top`).
- Hover states on table rows should use a subtle background tint (`#F1F5F9`) instantly, without slow crossfades.

## 7. Anti-Patterns (BANNED)
- NO emojis anywhere in the interface.
- NO `Inter` font.
- NO pure black (`#000000`).
- NO neon glows, outer glows, or heavy drop shadows.
- NO purple or magenta accents (unless explicitly requested for brand).
- NO excessive gradient text on headers.
- NO 3-column equal grids for primary dashboard layouts.
- NO fake round numbers (`99.99%`, `50%`) in mockups; use realistic financial data shapes (`12,450,000 đ`).
- NO generic placeholder names ("John Doe", "Acme"); use context-aware Vietnamese placeholders ("Nguyễn Văn A", "Cửa hàng Quận 1").
- NO AI copywriting clichés ("Elevate your inventory", "Seamless tax management"). Keep language dry, professional, and utility-focused.
- NO filler UI text like "Scroll to explore".
