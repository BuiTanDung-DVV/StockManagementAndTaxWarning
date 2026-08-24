BEGIN;

INSERT INTO system_configs (shop_id, config_key, config_value, description)
VALUES (
  NULL,
  'DAILY_CLOSING_EXPLANATION_THRESHOLD',
  '50000',
  'Mức chênh lệch két tiền mặt bắt buộc nhập giải trình khi chốt ngày'
)
ON CONFLICT (config_key) WHERE shop_id IS NULL
DO UPDATE SET
  config_value = EXCLUDED.config_value,
  description = EXCLUDED.description;

COMMIT;
