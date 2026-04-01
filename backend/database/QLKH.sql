-- =====================================================
-- Phần mềm Quản lý Bán hàng & Kho hàng
-- SQL Server Migration - All 34 Tables
-- =====================================================

USE master;
GO

-- Ngắt tất cả kết nối
DECLARE @SQL NVARCHAR(MAX) = '';
SELECT @SQL = @SQL + 'KILL ' + CAST(session_id AS VARCHAR(10)) + ';'
FROM sys.dm_exec_sessions
WHERE database_id = DB_ID('QLKH');
EXEC sp_executesql @SQL;
GO

-- Xóa database nếu tồn tại
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'QLKH')
BEGIN
    DROP DATABASE QLKH;
END
GO

-- Tạo database mới
CREATE DATABASE QLKH COLLATE Vietnamese_CI_AS;
GO

USE QLKH;
GO

-- 1. USERS
CREATE TABLE users (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    username        NVARCHAR(50) NOT NULL UNIQUE,
    password        NVARCHAR(255) NOT NULL,
    full_name       NVARCHAR(200) NOT NULL,
    email           NVARCHAR(100),
    phone           NVARCHAR(20),
    role            NVARCHAR(20) DEFAULT 'USER',
    account_type    VARCHAR(20) DEFAULT 'PERSONAL', -- 'SHOP' (hộ kinh doanh) | 'PERSONAL'
    avatar_url      NVARCHAR(1000),
    is_active       BIT DEFAULT 1,
    created_at      DATETIME2 DEFAULT GETDATE(),
    updated_at      DATETIME2 DEFAULT GETDATE()
);

-- 2. CATEGORIES
CREATE TABLE categories (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    name            NVARCHAR(100) NOT NULL UNIQUE,
    description     NVARCHAR(500),
    is_active       BIT DEFAULT 1
);

-- 3. PRODUCTS
CREATE TABLE products (
    id                      INT IDENTITY(1,1) PRIMARY KEY,
    sku                     NVARCHAR(50) NOT NULL UNIQUE,
    name                    NVARCHAR(200) NOT NULL,
    category_id             INT REFERENCES categories(id),
    unit                    NVARCHAR(20) DEFAULT N'Cái',
    cost_price              DECIMAL(18,2) DEFAULT 0,
    selling_price           DECIMAL(18,2) DEFAULT 0,
    wholesale_price         DECIMAL(18,2),
    wholesale_min_qty       INT,
    tax_rate                DECIMAL(5,2) DEFAULT 0,
    profit_margin           DECIMAL(5,2),
    supplier_discount       DECIMAL(18,2) DEFAULT 0,
    promo_price             DECIMAL(18,2),
    promo_start             DATE,
    promo_end               DATE,
    total_additional_cost   DECIMAL(18,2) DEFAULT 0,
    suggested_price         DECIMAL(18,2),
    min_stock               INT DEFAULT 0,
    image_url               NVARCHAR(500),
    barcode                 NVARCHAR(50),
    description             NVARCHAR(1000),
    is_active               BIT DEFAULT 1,
    created_at              DATETIME2 DEFAULT GETDATE(),
    updated_at              DATETIME2 DEFAULT GETDATE()
);

-- 4. COST_TYPES (Loại chi phí linh hoạt)
CREATE TABLE cost_types (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    name            NVARCHAR(100) NOT NULL UNIQUE,
    description     NVARCHAR(500),
    is_active       BIT DEFAULT 1,
    sort_order      INT DEFAULT 0,
    created_at      DATETIME2 DEFAULT GETDATE()
);

-- 5. PRODUCT_COST_ITEMS (Chi phí cấu thành giá bán)
CREATE TABLE product_cost_items (
    id                  INT IDENTITY(1,1) PRIMARY KEY,
    product_id          INT NOT NULL REFERENCES products(id),
    cost_type_id        INT NOT NULL REFERENCES cost_types(id),
    amount              DECIMAL(18,2) NOT NULL,
    calculation_type    NVARCHAR(20) DEFAULT 'FIXED',  -- FIXED | PERCENTAGE
    notes               NVARCHAR(200)
);

-- 6. PRODUCT_BATCHES (Lô hàng)
CREATE TABLE product_batches (
    id                  INT IDENTITY(1,1) PRIMARY KEY,
    product_id          INT NOT NULL REFERENCES products(id),
    batch_number        NVARCHAR(50) NOT NULL,
    manufacturing_date  DATE,
    expiry_date         DATE,
    quantity            INT DEFAULT 0,
    remaining_qty       INT DEFAULT 0,
    cost_price          DECIMAL(18,2),
    supplier_name       NVARCHAR(200),
    notes               NVARCHAR(500),
    is_active           BIT DEFAULT 1,
    created_at          DATETIME2 DEFAULT GETDATE()
);

-- 7. UNIT_CONVERSIONS (Quy đổi đơn vị)
CREATE TABLE unit_conversions (
    id                      INT IDENTITY(1,1) PRIMARY KEY,
    product_id              INT NOT NULL REFERENCES products(id),
    from_unit               NVARCHAR(30) NOT NULL,
    to_unit                 NVARCHAR(30) NOT NULL,
    conversion_rate         DECIMAL(18,4) NOT NULL,
    selling_price_per_unit  DECIMAL(18,2)
);

-- 8. PRODUCT_PRICE_HISTORY (Lịch sử thay đổi giá)
CREATE TABLE product_price_history (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(id),
    price_type      NVARCHAR(30) NOT NULL,  -- COST, SELLING, WHOLESALE, PROMO
    old_price       DECIMAL(18,2) NOT NULL,
    new_price       DECIMAL(18,2) NOT NULL,
    change_reason   NVARCHAR(500),
    changed_by      INT REFERENCES users(id),
    changed_at      DATETIME2 DEFAULT GETDATE()
);

-- 9. CUSTOMERS
CREATE TABLE customers (
    id                  INT IDENTITY(1,1) PRIMARY KEY,
    code                NVARCHAR(20) NOT NULL UNIQUE,
    name                NVARCHAR(200) NOT NULL,
    phone               NVARCHAR(20),
    email               NVARCHAR(100),
    address             NVARCHAR(500),
    tax_code            NVARCHAR(20),
    identity_number     NVARCHAR(20),       -- CMND/CCCD
    identity_image_url  NVARCHAR(1000),
    avatar_url          NVARCHAR(1000),
    date_of_birth       DATE,
    customer_type       NVARCHAR(20) DEFAULT 'RETAIL',  -- RETAIL, WHOLESALE, VIP
    zalo_phone          NVARCHAR(20),
    credit_limit        DECIMAL(18,2) DEFAULT 0,
    balance             DECIMAL(18,2) DEFAULT 0,
    notes               NVARCHAR(500),
    is_active           BIT DEFAULT 1,
    created_at          DATETIME2 DEFAULT GETDATE(),
    updated_at          DATETIME2 DEFAULT GETDATE()
);

-- 10. RECEIVABLES (Công nợ phải thu)
CREATE TABLE receivables (
    id                  INT IDENTITY(1,1) PRIMARY KEY,
    customer_id         INT NOT NULL REFERENCES customers(id),
    order_id            INT,
    amount              DECIMAL(18,2) NOT NULL,
    paid_amount         DECIMAL(18,2) DEFAULT 0,
    due_date            DATE NOT NULL,
    status              NVARCHAR(20) DEFAULT 'UNPAID',
    remaining_amount    AS (amount - paid_amount),  -- Computed column
    notes               NVARCHAR(500),
    debt_reason         NVARCHAR(500),
    witness_name        NVARCHAR(200),
    reminder_enabled    BIT DEFAULT 0,
    last_reminder_at    DATETIME2,
    created_at          DATETIME2 DEFAULT GETDATE(),
    updated_at          DATETIME2 DEFAULT GETDATE()
);

-- 11. DEBT_EVIDENCES (Bằng chứng nợ)
CREATE TABLE debt_evidences (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    receivable_id   INT REFERENCES receivables(id),
    payable_id      INT,
    type            NVARCHAR(20) NOT NULL,  -- PHOTO, SIGNATURE, AUDIO, DOCUMENT, CONTRACT
    file_url        NVARCHAR(1000) NOT NULL,
    file_name       NVARCHAR(200),
    file_size       BIGINT,
    description     NVARCHAR(500),
    uploaded_by     INT REFERENCES users(id),
    uploaded_at     DATETIME2 DEFAULT GETDATE()
);

-- 12. DEBT_PAYMENT_HISTORY (Lịch sử trả nợ)
CREATE TABLE debt_payment_history (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    receivable_id   INT REFERENCES receivables(id),
    payable_id      INT,
    amount          DECIMAL(18,2) NOT NULL,
    payment_method  NVARCHAR(20) DEFAULT 'CASH',
    payment_date    DATETIME2 NOT NULL,
    evidence_url    NVARCHAR(1000),
    notes           NVARCHAR(500),
    recorded_by     INT REFERENCES users(id),
    created_at      DATETIME2 DEFAULT GETDATE()
);

-- 13. SUPPLIERS
CREATE TABLE suppliers (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    code            NVARCHAR(20) NOT NULL UNIQUE,
    name            NVARCHAR(200) NOT NULL,
    phone           NVARCHAR(20),
    email           NVARCHAR(100),
    address         NVARCHAR(500),
    tax_code        NVARCHAR(20),
    balance         DECIMAL(18,2) DEFAULT 0,
    contact_person  NVARCHAR(200),
    payment_term_days INT DEFAULT 0,
    bank_account    NVARCHAR(30),
    bank_name       NVARCHAR(100),
    notes           NVARCHAR(500),
    is_active       BIT DEFAULT 1,
    created_at      DATETIME2 DEFAULT GETDATE(),
    updated_at      DATETIME2 DEFAULT GETDATE()
);

-- 14. PAYABLES (Công nợ phải trả)
CREATE TABLE payables (
    id                  INT IDENTITY(1,1) PRIMARY KEY,
    supplier_id         INT NOT NULL REFERENCES suppliers(id),
    purchase_order_id   INT,
    amount              DECIMAL(18,2) NOT NULL,
    paid_amount         DECIMAL(18,2) DEFAULT 0,
    due_date            DATE NOT NULL,
    status              NVARCHAR(20) DEFAULT 'UNPAID',
    remaining_amount    AS (amount - paid_amount),
    notes               NVARCHAR(500),
    created_at          DATETIME2 DEFAULT GETDATE(),
    updated_at          DATETIME2 DEFAULT GETDATE()
);

-- 15. SALES_ORDERS
CREATE TABLE sales_orders (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    order_code      NVARCHAR(20) NOT NULL UNIQUE,
    customer_id     INT REFERENCES customers(id),
    order_date      DATETIME2 NOT NULL,
    status          NVARCHAR(20) DEFAULT 'PENDING',
    subtotal        DECIMAL(18,2) DEFAULT 0,
    discount_amount DECIMAL(18,2) DEFAULT 0,
    tax_amount      DECIMAL(18,2) DEFAULT 0,
    total_amount    DECIMAL(18,2) DEFAULT 0,
    total_cogs      DECIMAL(18,2) DEFAULT 0,
    paid_amount     DECIMAL(18,2) DEFAULT 0,
    payment_method  NVARCHAR(10) DEFAULT 'CASH',
    notes           NVARCHAR(500),
    return_status   NVARCHAR(20) DEFAULT 'NONE',
    hold_until      DATETIME2,
    qr_payment_ref  NVARCHAR(100),
    invoice_number  NVARCHAR(50),
    created_by      INT REFERENCES users(id),
    created_at      DATETIME2 DEFAULT GETDATE(),
    updated_at      DATETIME2 DEFAULT GETDATE()
);

-- 16. SALES_ORDER_ITEMS
CREATE TABLE sales_order_items (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    order_id        INT NOT NULL REFERENCES sales_orders(id),
    product_id      INT NOT NULL REFERENCES products(id),
    quantity        INT NOT NULL,
    unit_price      DECIMAL(18,2) NOT NULL,
    subtotal        DECIMAL(18,2) NOT NULL,
    cost_price      DECIMAL(18,2) DEFAULT 0,
    tax_rate        DECIMAL(5,2) DEFAULT 0,
    tax_amount      DECIMAL(18,2) DEFAULT 0
);

-- 17. SALES_ORDER_PAYMENTS (Thanh toán hỗn hợp)
CREATE TABLE sales_order_payments (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    order_id        INT NOT NULL REFERENCES sales_orders(id),
    amount          DECIMAL(18,2) NOT NULL,
    method          NVARCHAR(20) DEFAULT 'CASH',  -- CASH, TRANSFER, MOMO, ZALOPAY, QR
    reference_code  NVARCHAR(100),
    notes           NVARCHAR(200),
    paid_at         DATETIME2 DEFAULT GETDATE()
);

-- 18. SALES_RETURNS
CREATE TABLE sales_returns (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    return_code     NVARCHAR(20) NOT NULL UNIQUE,
    order_id        INT NOT NULL REFERENCES sales_orders(id),
    return_date     DATETIME2 NOT NULL,
    reason          NVARCHAR(500) NOT NULL,
    refund_amount   DECIMAL(18,2) DEFAULT 0,
    refund_method   NVARCHAR(20) DEFAULT 'CASH',
    status          NVARCHAR(20) DEFAULT 'PENDING',
    processed_by    INT REFERENCES users(id),
    notes           NVARCHAR(500),
    created_at      DATETIME2 DEFAULT GETDATE()
);

-- 19. SALES_RETURN_ITEMS
CREATE TABLE sales_return_items (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    return_id       INT NOT NULL REFERENCES sales_returns(id),
    product_id      INT NOT NULL REFERENCES products(id),
    quantity        INT NOT NULL,
    unit_price      DECIMAL(18,2) NOT NULL,
    subtotal        DECIMAL(18,2) NOT NULL,
    reason          NVARCHAR(200)
);

-- 20. WAREHOUSES
CREATE TABLE warehouses (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    name            NVARCHAR(100) NOT NULL UNIQUE,
    address         NVARCHAR(500),
    is_active       BIT DEFAULT 1
);

-- 21. INVENTORY_STOCKS
CREATE TABLE inventory_stocks (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(id),
    warehouse_id    INT NOT NULL REFERENCES warehouses(id),
    quantity        INT DEFAULT 0,
    updated_at      DATETIME2 DEFAULT GETDATE()
);

-- 22. INVENTORY_MOVEMENTS
CREATE TABLE inventory_movements (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(id),
    warehouse_id    INT NOT NULL REFERENCES warehouses(id),
    movement_type   NVARCHAR(20) NOT NULL,  -- IN, OUT, ADJUSTMENT, RETURN
    quantity        INT NOT NULL,
    reference_type  NVARCHAR(20),
    reference_id    INT,
    cost_price      DECIMAL(18,2) DEFAULT 0,
    notes           NVARCHAR(500),
    created_by      INT REFERENCES users(id),
    created_at      DATETIME2 DEFAULT GETDATE()
);

-- 23. PURCHASE_ORDERS
CREATE TABLE purchase_orders (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    order_code      NVARCHAR(20) NOT NULL UNIQUE,
    supplier_id     INT NOT NULL REFERENCES suppliers(id),
    warehouse_id    INT REFERENCES warehouses(id),
    order_date      DATETIME2 NOT NULL,
    payment_due_date DATE,
    invoice_number  NVARCHAR(50),
    status          NVARCHAR(20) DEFAULT 'PENDING',
    subtotal        DECIMAL(18,2) DEFAULT 0,
    discount_amount DECIMAL(18,2) DEFAULT 0,
    tax_amount      DECIMAL(18,2) DEFAULT 0,
    total_amount    DECIMAL(18,2) DEFAULT 0,
    paid_amount     DECIMAL(18,2) DEFAULT 0,
    notes           NVARCHAR(500),
    created_by      INT REFERENCES users(id),
    created_at      DATETIME2 DEFAULT GETDATE()
);

-- 24. PURCHASE_ORDER_ITEMS
CREATE TABLE purchase_order_items (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    order_id        INT NOT NULL REFERENCES purchase_orders(id),
    product_id      INT NOT NULL REFERENCES products(id),
    quantity        INT NOT NULL,
    unit_price      DECIMAL(18,2) NOT NULL,
    subtotal        DECIMAL(18,2) NOT NULL
);

-- 25. STOCK_TAKES (Kiểm kho)
CREATE TABLE stock_takes (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    stock_take_code NVARCHAR(20) NOT NULL UNIQUE,
    stock_take_date DATE NOT NULL,
    status          NVARCHAR(20) DEFAULT 'DRAFT',
    notes           NVARCHAR(500),
    created_by      INT REFERENCES users(id),
    approved_by     INT REFERENCES users(id),
    completed_at    DATETIME2,
    created_at      DATETIME2 DEFAULT GETDATE()
);

-- 26. STOCK_TAKE_ITEMS
CREATE TABLE stock_take_items (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    stock_take_id   INT NOT NULL REFERENCES stock_takes(id),
    product_id      INT NOT NULL REFERENCES products(id),
    system_qty      INT NOT NULL,
    actual_qty      INT NOT NULL,
    difference      INT DEFAULT 0,
    notes           NVARCHAR(200)
);

-- 27. CASH_ACCOUNTS
CREATE TABLE cash_accounts (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    name            NVARCHAR(100) NOT NULL,
    account_type    NVARCHAR(20) NOT NULL,
    balance         DECIMAL(18,2) DEFAULT 0,
    is_active       BIT DEFAULT 1
);

-- 28. CASH_TRANSACTIONS
CREATE TABLE cash_transactions (
    id                  INT IDENTITY(1,1) PRIMARY KEY,
    transaction_code    NVARCHAR(20) NOT NULL UNIQUE,
    type                NVARCHAR(10) NOT NULL,      -- INCOME, EXPENSE
    category            NVARCHAR(50) NOT NULL,
    amount              DECIMAL(18,2) NOT NULL,
    payment_method      NVARCHAR(10) DEFAULT 'CASH',
    account_id          INT REFERENCES cash_accounts(id),
    counterparty        NVARCHAR(200),
    reference_type      NVARCHAR(20),
    reference_id        INT,
    transaction_date    DATE NOT NULL,
    notes               NVARCHAR(500),
    receipt_image_url   NVARCHAR(1000),
    running_balance     DECIMAL(18,2),
    approved_by         INT REFERENCES users(id),
    created_by          INT REFERENCES users(id),
    created_at          DATETIME2 DEFAULT GETDATE()
);

-- 29. BUDGET_PLANS
CREATE TABLE budget_plans (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    name            NVARCHAR(200) NOT NULL,
    period          NVARCHAR(20) NOT NULL,
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    planned_income  DECIMAL(18,2) DEFAULT 0,
    planned_expense DECIMAL(18,2) DEFAULT 0,
    actual_income   DECIMAL(18,2) DEFAULT 0,
    actual_expense  DECIMAL(18,2) DEFAULT 0,
    notes           NVARCHAR(500),
    created_at      DATETIME2 DEFAULT GETDATE()
);

-- 30. CASHFLOW_FORECASTS
CREATE TABLE cashflow_forecasts (
    id                  INT IDENTITY(1,1) PRIMARY KEY,
    forecast_date       DATE NOT NULL,
    expected_income     DECIMAL(18,2) DEFAULT 0,
    expected_expense    DECIMAL(18,2) DEFAULT 0,
    expected_balance    DECIMAL(18,2) DEFAULT 0,
    notes               NVARCHAR(500),
    created_at          DATETIME2 DEFAULT GETDATE()
);

-- 31. DAILY_CLOSINGS (Chốt sổ cuối ngày)
CREATE TABLE daily_closings (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    closing_date    DATE NOT NULL UNIQUE,
    opening_cash    DECIMAL(18,2) DEFAULT 0,
    closing_cash    DECIMAL(18,2) DEFAULT 0,
    expected_cash   DECIMAL(18,2) DEFAULT 0,
    cash_difference DECIMAL(18,2) DEFAULT 0,
    total_sales     DECIMAL(18,2) DEFAULT 0,
    total_returns   DECIMAL(18,2) DEFAULT 0,
    total_income    DECIMAL(18,2) DEFAULT 0,
    total_expense   DECIMAL(18,2) DEFAULT 0,
    order_count     INT DEFAULT 0,
    notes           NVARCHAR(500),
    closed_by       INT REFERENCES users(id),
    closed_at       DATETIME2
);

-- 32. SHOP_PROFILES (Thông tin cửa hàng / HKD)
CREATE TABLE shop_profiles (
    id                      INT IDENTITY(1,1) PRIMARY KEY,
    shop_name               NVARCHAR(200) NOT NULL,
    logo_url                NVARCHAR(1000),
    phone                   NVARCHAR(20),
    address                 NVARCHAR(500),
    tax_code                NVARCHAR(20),
    bank_account            NVARCHAR(30),
    bank_name               NVARCHAR(100),
    account_holder          NVARCHAR(200),
    qr_payment_url          NVARCHAR(1000),
    receipt_footer          NVARCHAR(500),
    email                   NVARCHAR(100),
    website                 NVARCHAR(500),
    owner_name              NVARCHAR(200),
    owner_identity_number   NVARCHAR(20),
    business_license_number NVARCHAR(50)
);

-- 33. ACTIVITY_LOGS (Nhật ký hoạt động)
CREATE TABLE activity_logs (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    user_id         INT NOT NULL REFERENCES users(id),
    action          NVARCHAR(50) NOT NULL,
    entity_type     NVARCHAR(50) NOT NULL,
    entity_id       INT,
    entity_name     NVARCHAR(200),
    old_value       NVARCHAR(2000),
    new_value       NVARCHAR(2000),
    description     NVARCHAR(500),
    ip_address      NVARCHAR(50),
    created_at      DATETIME2 DEFAULT GETDATE()
);

-- 34. INVOICE_SCANS (Chụp hóa đơn OCR)
CREATE TABLE invoice_scans (
    id                  INT IDENTITY(1,1) PRIMARY KEY,
    scan_code           NVARCHAR(20) NOT NULL UNIQUE,
    image_url           NVARCHAR(1000) NOT NULL,
    image_thumbnail_url NVARCHAR(1000),
    invoice_type        NVARCHAR(20) DEFAULT 'PURCHASE',
    status              NVARCHAR(20) DEFAULT 'PENDING',
    ocr_raw_text        NVARCHAR(MAX),
    ocr_parsed_data     NVARCHAR(MAX),
    confirmed_data      NVARCHAR(MAX),
    confidence_score    INT,
    total_amount        DECIMAL(18,2),
    reference_type      NVARCHAR(30),
    reference_id        INT,
    ocr_engine          NVARCHAR(50) DEFAULT 'GOOGLE_VISION',
    scanned_by          INT REFERENCES users(id),
    scanned_at          DATETIME2 DEFAULT GETDATE(),
    confirmed_at        DATETIME2,
    notes               NVARCHAR(500)
);

-- 35. INVOICES (Hóa đơn đầu vào / đầu ra)
CREATE TABLE invoices (
    id                      INT IDENTITY(1,1) PRIMARY KEY,
    invoice_number          NVARCHAR(50) NOT NULL,
    invoice_symbol          NVARCHAR(20),
    invoice_type            NVARCHAR(10) NOT NULL,       -- IN (đầu vào), OUT (đầu ra)
    invoice_date            DATE NOT NULL,
    partner_name            NVARCHAR(200) NOT NULL,
    partner_tax_code        NVARCHAR(20),
    partner_address         NVARCHAR(500),
    partner_identity_number NVARCHAR(20),
    reference_type          NVARCHAR(30),                -- PURCHASE_ORDER, SALES_ORDER
    reference_id            INT,
    subtotal                DECIMAL(18,2) DEFAULT 0,
    tax_amount              DECIMAL(18,2) DEFAULT 0,
    total_amount            DECIMAL(18,2) DEFAULT 0,
    payment_method          NVARCHAR(20),
    payment_status          NVARCHAR(20) DEFAULT 'UNPAID', -- UNPAID, PARTIAL, PAID
    image_url               NVARCHAR(1000),
    notes                   NVARCHAR(500),
    created_by              INT REFERENCES users(id),
    created_at              DATETIME2 DEFAULT GETDATE()
);

-- 36. INVOICE_ITEMS (Chi tiết hóa đơn)
CREATE TABLE invoice_items (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    invoice_id      INT NOT NULL REFERENCES invoices(id),
    product_id      INT REFERENCES products(id),
    item_name       NVARCHAR(200) NOT NULL,
    unit            NVARCHAR(20) DEFAULT N'Cái',
    quantity        INT NOT NULL,
    unit_price      DECIMAL(18,2) NOT NULL,
    subtotal        DECIMAL(18,2) NOT NULL,
    tax_rate        DECIMAL(5,2) DEFAULT 0,
    tax_amount      DECIMAL(18,2) DEFAULT 0
);

-- 37. PURCHASES_WITHOUT_INVOICE (Bảng kê thu mua không HĐ - Mẫu 01/TNDN)
CREATE TABLE purchases_without_invoice (
    id                      INT IDENTITY(1,1) PRIMARY KEY,
    record_code             NVARCHAR(20) NOT NULL UNIQUE,
    purchase_date           DATE NOT NULL,
    seller_name             NVARCHAR(200) NOT NULL,
    seller_identity_number  NVARCHAR(20) NOT NULL,
    seller_address          NVARCHAR(500),
    seller_phone            NVARCHAR(20),
    seller_signature_url    NVARCHAR(1000),
    total_amount            DECIMAL(18,2) NOT NULL,
    payment_method          NVARCHAR(20) DEFAULT 'CASH',
    payment_proof_url       NVARCHAR(1000),
    market_price_reference  DECIMAL(18,2),
    notes                   NVARCHAR(500),
    approved_by             INT REFERENCES users(id),
    created_by              INT REFERENCES users(id),
    created_at              DATETIME2 DEFAULT GETDATE()
);

-- 38. PURCHASE_WITHOUT_INVOICE_ITEMS (Chi tiết bảng kê thu mua)
CREATE TABLE purchase_without_invoice_items (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    purchase_id     INT NOT NULL REFERENCES purchases_without_invoice(id),
    item_name       NVARCHAR(200) NOT NULL,     -- Tên nông/lâm/thủy sản
    unit            NVARCHAR(20) DEFAULT N'Kg',
    quantity        INT NOT NULL,
    unit_price      DECIMAL(18,2) NOT NULL,
    subtotal        DECIMAL(18,2) NOT NULL
);

-- 39. TAX_OBLIGATIONS (Nghĩa vụ thuế)
CREATE TABLE tax_obligations (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    period          NVARCHAR(20) NOT NULL,           -- Q1/2026, Q2/2026...
    vat_declared    DECIMAL(18,2) DEFAULT 0,
    pit_declared    DECIMAL(18,2) DEFAULT 0,
    vat_paid        DECIMAL(18,2) DEFAULT 0,
    pit_paid        DECIMAL(18,2) DEFAULT 0,
    due_date        DATE NULL,                       -- deadline nộp thuế
    status          NVARCHAR(20) DEFAULT 'pending',  -- done, partial, pending, overdue
    created_at      DATETIME2 DEFAULT GETDATE()
);

-- =====================================================
-- INDEXES
-- =====================================================
CREATE INDEX IX_products_category ON products(category_id);
CREATE INDEX IX_products_barcode ON products(barcode);
CREATE INDEX IX_product_cost_items_product ON product_cost_items(product_id);
CREATE INDEX IX_product_batches_product ON product_batches(product_id);
CREATE INDEX IX_product_batches_expiry ON product_batches(expiry_date);
CREATE INDEX IX_customers_phone ON customers(phone);
CREATE INDEX IX_receivables_customer ON receivables(customer_id);
CREATE INDEX IX_receivables_status ON receivables(status);
CREATE INDEX IX_receivables_due_date ON receivables(due_date);
CREATE INDEX IX_payables_supplier ON payables(supplier_id);
CREATE INDEX IX_sales_orders_customer ON sales_orders(customer_id);
CREATE INDEX IX_sales_orders_date ON sales_orders(order_date);
CREATE INDEX IX_sales_orders_status ON sales_orders(status);
CREATE INDEX IX_sales_order_items_order ON sales_order_items(order_id);
CREATE INDEX IX_inventory_stocks_product ON inventory_stocks(product_id);
CREATE INDEX IX_inventory_movements_product ON inventory_movements(product_id);
CREATE INDEX IX_cash_transactions_date ON cash_transactions(transaction_date);
CREATE INDEX IX_cash_transactions_type ON cash_transactions(type);
CREATE INDEX IX_activity_logs_entity ON activity_logs(entity_type, entity_id);
CREATE INDEX IX_activity_logs_user ON activity_logs(user_id);
CREATE INDEX IX_invoice_scans_status ON invoice_scans(status);
CREATE INDEX IX_invoices_type ON invoices(invoice_type);
CREATE INDEX IX_invoices_date ON invoices(invoice_date);
CREATE INDEX IX_invoices_partner ON invoices(partner_tax_code);
CREATE INDEX IX_invoice_items_invoice ON invoice_items(invoice_id);
CREATE INDEX IX_pwi_date ON purchases_without_invoice(purchase_date);
CREATE INDEX IX_pwi_items_purchase ON purchase_without_invoice_items(purchase_id);
CREATE INDEX IX_purchase_orders_warehouse ON purchase_orders(warehouse_id);
CREATE INDEX IX_tax_obligations_period ON tax_obligations(period);

-- 40. SHOP PROFILES
CREATE TABLE shop_profiles (
    id                       INT IDENTITY(1,1) PRIMARY KEY,
    shop_name                NVARCHAR(200) NOT NULL,
    logo_url                 NVARCHAR(1000),
    phone                    NVARCHAR(20),
    address                  NVARCHAR(500),
    tax_code                 NVARCHAR(20),
    bank_id                  NVARCHAR(20),
    bank_account             NVARCHAR(30),
    bank_name                NVARCHAR(100),
    account_holder           NVARCHAR(200),
    qr_payment_url           NVARCHAR(1000),
    receipt_footer           NVARCHAR(500),
    email                    NVARCHAR(100),
    website                  NVARCHAR(500),
    owner_name               NVARCHAR(200),
    owner_identity_number    NVARCHAR(20),
    business_license_number  NVARCHAR(50),
    costing_method           VARCHAR(10) DEFAULT 'AVG'  -- FIFO | AVG
);

-- 41. SHOP ROLES (custom roles per shop)
CREATE TABLE shop_roles (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    shop_id     INT NOT NULL REFERENCES shop_profiles(id),
    name        NVARCHAR(100) NOT NULL,
    permissions NVARCHAR(MAX) NOT NULL, -- JSON: {"pos":"full","products":"view",...}
    is_default  BIT DEFAULT 0,
    created_at  DATETIME2 DEFAULT GETDATE()
);

-- 42. SHOP MEMBERS (user ↔ shop mapping)
CREATE TABLE shop_members (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    shop_id     INT NOT NULL REFERENCES shop_profiles(id),
    user_id     INT NOT NULL REFERENCES users(id),
    role_id     INT REFERENCES shop_roles(id),
    member_type VARCHAR(20) NOT NULL DEFAULT 'EMPLOYEE', -- 'OWNER' | 'EMPLOYEE'
    is_active   BIT DEFAULT 1,
    created_at  DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT UQ_shop_members UNIQUE (shop_id, user_id)
);

-- 43. NOTIFICATIONS
CREATE TABLE notifications (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    user_id     INT NOT NULL REFERENCES users(id),
    type        VARCHAR(30) NOT NULL, -- 'SHOP_INVITE','ROLE_CHANGE'
    title       NVARCHAR(200),
    message     NVARCHAR(500),
    data        NVARCHAR(MAX), -- JSON metadata
    is_read     BIT DEFAULT 0,
    created_at  DATETIME2 DEFAULT GETDATE()
);

-- 44. INVENTORY_LOTS (Lô tồn kho chi tiết cho FIFO/Bình quân)
CREATE TABLE inventory_lots (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    product_id      INT NOT NULL REFERENCES products(id),
    purchase_id     INT REFERENCES purchase_orders(id),
    batch_id        INT REFERENCES product_batches(id),
    lot_date        DATETIME2 NOT NULL DEFAULT GETDATE(),
    initial_qty     INT NOT NULL,
    remaining_qty   INT NOT NULL,
    cost_price      DECIMAL(18,2) NOT NULL,
    notes           NVARCHAR(200),
    created_at      DATETIME2 DEFAULT GETDATE()
);
CREATE INDEX IX_inventory_lots_product ON inventory_lots(product_id);
CREATE INDEX IX_inventory_lots_remaining ON inventory_lots(product_id, remaining_qty) WHERE remaining_qty > 0;

PRINT N'✅ Tạo thành công 44 bảng + indexes + seed data';
GO

Select * from shop_profiles;
Select * from users;
