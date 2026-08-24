BEGIN;

CREATE TABLE IF NOT EXISTS system_configs (
  id SERIAL PRIMARY KEY,
  shop_id INTEGER,
  config_key VARCHAR(100) NOT NULL,
  config_value TEXT NOT NULL,
  description VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DO $$
DECLARE
  constraint_name TEXT;
BEGIN
  SELECT c.conname INTO constraint_name
  FROM pg_constraint c
  JOIN pg_class t ON t.oid = c.conrelid
  WHERE t.relname = 'system_configs'
    AND c.contype = 'u'
    AND pg_get_constraintdef(c.oid) = 'UNIQUE (config_key)'
  LIMIT 1;
  IF constraint_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE system_configs DROP CONSTRAINT %I', constraint_name);
  END IF;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_system_configs_global_key
  ON system_configs (config_key)
  WHERE shop_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_system_configs_shop_key
  ON system_configs (shop_id, config_key)
  WHERE shop_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS configuration_migration_backups (
  id BIGSERIAL PRIMARY KEY,
  migration_code VARCHAR(100) NOT NULL,
  snapshot JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO configuration_migration_backups (migration_code, snapshot)
SELECT
  '20260813_verified_tax_policy',
  jsonb_build_object(
    'systemConfigs', COALESCE((
      SELECT jsonb_agg(to_jsonb(config_row))
      FROM system_configs config_row
      WHERE config_row.shop_id IS NULL
        AND config_row.config_key IN (
          'TAX_FISCAL_YEAR',
          'TAX_EFFECTIVE_FROM',
          'TAX_REVENUE_TIER_1',
          'TAX_REVENUE_TIER_2',
          'WARNING_REVENUE_THRESHOLD',
          'TAX_EXEMPTION_THRESHOLD',
          'E_INVOICE_THRESHOLD',
          'VAT_REDUCTION_ACTIVE',
          'VAT_REDUCTION_RATE',
          'VAT_REDUCTION_SCOPE',
          'CASH_PURCHASE_LIMIT',
          'TAX_POLICY_SOURCE_CODE',
          'TAX_POLICY_SOURCE_URL'
        )
    ), '[]'::jsonb),
    'taxRules', COALESCE((
      SELECT jsonb_agg(to_jsonb(rule_row))
      FROM tax_rules rule_row
      WHERE rule_row.industry_code IN ('BAN_LE', 'SAN_XUAT', 'DICH_VU', 'KHAC')
    ), '[]'::jsonb)
  );

DELETE FROM system_configs
WHERE shop_id IS NULL
  AND config_key IN (
    'TAX_FISCAL_YEAR',
    'TAX_EFFECTIVE_FROM',
    'TAX_REVENUE_TIER_1',
    'TAX_REVENUE_TIER_2',
    'WARNING_REVENUE_THRESHOLD',
    'TAX_EXEMPTION_THRESHOLD',
    'E_INVOICE_THRESHOLD',
    'VAT_REDUCTION_ACTIVE',
    'VAT_REDUCTION_RATE',
    'VAT_REDUCTION_SCOPE',
    'CASH_PURCHASE_LIMIT',
    'TAX_POLICY_SOURCE_CODE',
    'TAX_POLICY_SOURCE_URL'
  );

INSERT INTO system_configs (shop_id, config_key, config_value, description)
VALUES
  (NULL, 'TAX_FISCAL_YEAR', '2026', 'Năm hiệu lực của bộ quy tắc thuế'),
  (NULL, 'TAX_EFFECTIVE_FROM', '2026-01-01', 'Ngày bắt đầu hiệu lực'),
  (NULL, 'TAX_REVENUE_TIER_1', '250000000', 'Mốc theo dõi nội bộ 1'),
  (NULL, 'TAX_REVENUE_TIER_2', '500000000', 'Mốc theo dõi nội bộ 2'),
  (NULL, 'WARNING_REVENUE_THRESHOLD', '900000000', 'Mốc cảnh báo trước ngưỡng chịu thuế'),
  (NULL, 'TAX_EXEMPTION_THRESHOLD', '1000000000', 'Ngưỡng doanh thu năm không chịu thuế GTGT/TNCN'),
  (NULL, 'E_INVOICE_THRESHOLD', '1000000000', 'Ngưỡng doanh thu áp dụng hóa đơn điện tử theo quy định'),
  (NULL, 'VAT_REDUCTION_ACTIVE', 'false', 'Có áp dụng giảm tỷ lệ GTGT toàn cửa hàng hay không'),
  (NULL, 'VAT_REDUCTION_RATE', '0', 'Tỷ lệ giảm áp dụng toàn cửa hàng'),
  (NULL, 'VAT_REDUCTION_SCOPE', 'PRODUCT_LEVEL_NOT_SUPPORTED', 'Phạm vi áp dụng chính sách giảm thuế'),
  (NULL, 'CASH_PURCHASE_LIMIT', '20000000', 'Ngưỡng cảnh báo giao dịch mua thanh toán tiền mặt'),
  (NULL, 'TAX_POLICY_SOURCE_CODE', '141/2026/NĐ-CP', 'Mã văn bản pháp lý đã xác minh'),
  (NULL, 'TAX_POLICY_SOURCE_URL', 'https://vanban.chinhphu.vn/?classid=1&docid=217960&pageid=27160&typegroupid=4', 'Nguồn chính thức');

DELETE FROM tax_rules
WHERE industry_code IN ('BAN_LE', 'SAN_XUAT', 'DICH_VU', 'KHAC')
  AND effective_from >= TIMESTAMP '2026-01-01'
  AND effective_from < TIMESTAMP '2027-01-01';

INSERT INTO tax_rules (
  industry_code,
  name,
  vat_rate,
  pit_rate,
  effective_from,
  effective_to
)
VALUES
  ('BAN_LE', 'Phân phối, cung cấp hàng hóa', 1.00, 0.50, '2026-01-01', NULL),
  ('SAN_XUAT', 'Sản xuất, vận tải, xây dựng có bao thầu nguyên vật liệu', 3.00, 1.50, '2026-01-01', NULL),
  ('DICH_VU', 'Dịch vụ, xây dựng không bao thầu nguyên vật liệu', 5.00, 2.00, '2026-01-01', NULL),
  ('KHAC', 'Hoạt động kinh doanh khác', 2.00, 1.00, '2026-01-01', NULL);

COMMIT;
