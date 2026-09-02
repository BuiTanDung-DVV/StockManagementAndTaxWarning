BEGIN;

ALTER TABLE shop_profiles
  ADD COLUMN IF NOT EXISTS receipt_template_config jsonb;

ALTER TABLE invoice_scans
  ADD COLUMN IF NOT EXISTS error_message varchar(500);

CREATE TABLE IF NOT EXISTS shipping_carriers (
  id serial PRIMARY KEY,
  shop_id integer NOT NULL,
  name varchar(120) NOT NULL,
  code varchar(30) NOT NULL,
  phone varchar(20),
  tracking_url_template varchar(500),
  default_fee numeric(18,2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT shipping_carriers_shop_code_unique UNIQUE (shop_id, code),
  CONSTRAINT shipping_carriers_default_fee_check CHECK (default_fee >= 0)
);

CREATE INDEX IF NOT EXISTS idx_shipping_carriers_shop_active
  ON shipping_carriers (shop_id, is_active);

ALTER TABLE sales_orders
  ADD COLUMN IF NOT EXISTS shipping_carrier_id integer,
  ADD COLUMN IF NOT EXISTS tracking_code varchar(100),
  ADD COLUMN IF NOT EXISTS delivery_status varchar(20) NOT NULL DEFAULT 'NOT_REQUIRED',
  ADD COLUMN IF NOT EXISTS shipping_fee numeric(18,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS shipping_fee_payer varchar(20) NOT NULL DEFAULT 'SHOP',
  ADD COLUMN IF NOT EXISTS shipping_tax_rate numeric(5,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS shipping_expense_transaction_id integer;

ALTER TABLE sales_returns
  ADD COLUMN IF NOT EXISTS refund_shipping_fee boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS refunded_shipping_amount numeric(18,2) NOT NULL DEFAULT 0;

DO $$ BEGIN
  ALTER TABLE sales_orders ADD CONSTRAINT sales_orders_shipping_fee_check
    CHECK (shipping_fee >= 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE sales_orders ADD CONSTRAINT sales_orders_shipping_tax_rate_check
    CHECK (shipping_tax_rate >= 0 AND shipping_tax_rate <= 100);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE sales_orders ADD CONSTRAINT sales_orders_shipping_fee_payer_check
    CHECK (shipping_fee_payer IN ('SHOP', 'CUSTOMER'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE sales_orders ADD CONSTRAINT sales_orders_delivery_status_check
    CHECK (delivery_status IN ('NOT_REQUIRED', 'PENDING', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED', 'RETURNED'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE sales_returns ADD CONSTRAINT sales_returns_refunded_shipping_amount_check
    CHECK (refunded_shipping_amount >= 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE sales_orders ADD CONSTRAINT fk_sales_orders_shipping_carrier
    FOREIGN KEY (shipping_carrier_id) REFERENCES shipping_carriers(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE sales_orders ADD CONSTRAINT fk_sales_orders_shipping_expense
    FOREIGN KEY (shipping_expense_transaction_id) REFERENCES cash_transactions(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS shop_backup_snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id integer NOT NULL,
  created_by integer NOT NULL,
  checksum varchar(64) NOT NULL,
  payload_gzip bytea NOT NULL,
  status varchar(20) NOT NULL DEFAULT 'READY',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_shop_backup_snapshots_shop_created
  ON shop_backup_snapshots (shop_id, created_at DESC);

DO $$
DECLARE item record;
BEGIN
  IF EXISTS (
    SELECT 1
    FROM categories
    WHERE shop_id IS NOT NULL
    GROUP BY shop_id, lower(btrim(name))
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Không thể tạo unique danh mục theo cửa hàng: còn tên trùng không phân biệt hoa thường';
  END IF;

  FOR item IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'categories'::regclass
      AND contype = 'u'
      AND pg_get_constraintdef(oid) ILIKE '%(name)%'
  LOOP
    EXECUTE format('ALTER TABLE categories DROP CONSTRAINT %I', item.conname);
  END LOOP;
END $$;

DROP INDEX IF EXISTS categories_name_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_categories_shop_name_ci
  ON categories (shop_id, lower(btrim(name)))
  WHERE shop_id IS NOT NULL;

COMMIT;
