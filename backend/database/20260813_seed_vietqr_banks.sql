BEGIN;

INSERT INTO system_configs (shop_id, config_key, config_value, description)
VALUES (
  NULL,
  'VIETQR_BANKS',
  '[{"id":"MB","name":"MB Bank"},{"id":"VCB","name":"Vietcombank"},{"id":"TCB","name":"Techcombank"},{"id":"ACB","name":"ACB"},{"id":"TPB","name":"TPBank"},{"id":"VPB","name":"VPBank"},{"id":"BIDV","name":"BIDV"},{"id":"VTB","name":"VietinBank"},{"id":"AGR","name":"Agribank"},{"id":"SHB","name":"SHB"},{"id":"STB","name":"Sacombank"},{"id":"HDB","name":"HDBank"},{"id":"MSB","name":"MSB"},{"id":"OCB","name":"OCB"},{"id":"LPB","name":"LPBank"},{"id":"EIB","name":"Eximbank"},{"id":"SCB","name":"SCB"},{"id":"NAB","name":"Nam A Bank"},{"id":"VAB","name":"VietABank"},{"id":"SEAB","name":"SeABank"},{"id":"BAB","name":"Bac A Bank"},{"id":"PVCB","name":"PVcomBank"},{"id":"KLB","name":"KienlongBank"},{"id":"ABB","name":"ABBank"},{"id":"WOO","name":"Woori Bank Việt Nam"},{"id":"CAKE","name":"CAKE by VPBank"},{"id":"UBANK","name":"Ubank by VPBank"}]',
  'Danh mục ngân hàng cho cấu hình thanh toán VietQR'
)
ON CONFLICT (config_key) WHERE shop_id IS NULL
DO UPDATE SET
  config_value = EXCLUDED.config_value,
  description = EXCLUDED.description,
  updated_at = CURRENT_TIMESTAMP;

COMMIT;
