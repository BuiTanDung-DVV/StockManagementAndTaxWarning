BEGIN;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM categories
    GROUP BY name
    HAVING COUNT(*) > 1
  ) THEN
    RAISE EXCEPTION 'Không thể rollback unique danh mục toàn hệ thống: tên danh mục đang trùng giữa các cửa hàng';
  END IF;
END $$;

DROP INDEX IF EXISTS uq_categories_shop_name_ci;
CREATE UNIQUE INDEX IF NOT EXISTS categories_name_key ON categories (name);

ALTER TABLE sales_orders DROP CONSTRAINT IF EXISTS fk_sales_orders_shipping_expense;
ALTER TABLE sales_orders DROP CONSTRAINT IF EXISTS fk_sales_orders_shipping_carrier;
ALTER TABLE sales_orders
  DROP COLUMN IF EXISTS shipping_expense_transaction_id,
  DROP COLUMN IF EXISTS shipping_tax_rate,
  DROP COLUMN IF EXISTS shipping_fee_payer,
  DROP COLUMN IF EXISTS shipping_fee,
  DROP COLUMN IF EXISTS delivery_status,
  DROP COLUMN IF EXISTS tracking_code,
  DROP COLUMN IF EXISTS shipping_carrier_id;

ALTER TABLE sales_returns
  DROP COLUMN IF EXISTS refunded_shipping_amount,
  DROP COLUMN IF EXISTS refund_shipping_fee;

DROP TABLE IF EXISTS shop_backup_snapshots;
DROP TABLE IF EXISTS shipping_carriers;
ALTER TABLE invoice_scans DROP COLUMN IF EXISTS error_message;
ALTER TABLE shop_profiles DROP COLUMN IF EXISTS receipt_template_config;

COMMIT;
