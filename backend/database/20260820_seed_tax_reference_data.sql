BEGIN;

INSERT INTO system_configs (shop_id, config_key, config_value, description)
VALUES
(
  NULL,
  'TAX_DECLARATION_FORMS',
  '[{"code":"01/CNKD","name":"Tờ khai thuế HKD/CNKD","description":"Dành cho HKD nộp thuế theo phương pháp kê khai","status":"READY","iconKey":"description"},{"code":"01/BK-STK","name":"Bảng kê sổ tay khoán","description":"Bảng kê chi tiết theo sổ tay khoán","status":"READY","iconKey":"list"},{"code":"01/TKN-CNKD","name":"Tờ khai thuế khoán","description":"Dành cho HKD nộp thuế khoán","status":"DRAFT","iconKey":"article"}]',
  'Danh mục biểu mẫu kê khai do backend tải từ DB; cần rà soát theo văn bản đang hiệu lực'
),
(
  NULL,
  'TAX_SUPPORT_LINKS',
  '[{"title":"Cổng thông tin Cục Thuế","description":"Tin chính sách, thủ tục và phần mềm chính thức","url":"https://www.gdt.gov.vn","iconKey":"authority","colorRole":"PRIMARY"},{"title":"Thuế điện tử","description":"Khai và nộp thuế điện tử trên cổng chính thức","url":"https://thuedientu.gdt.gov.vn","iconKey":"support","colorRole":"SUCCESS"},{"title":"Tra cứu hóa đơn","description":"Tra cứu hóa đơn điện tử của Cục Thuế","url":"https://hoadondientu.gdt.gov.vn/tra-cuu/tra-cuu-hoa-don","iconKey":"receipt","colorRole":"WARNING"}]',
  'Danh mục liên kết hỗ trợ thuế chính thức được kiểm tra allowlist ở backend'
)
ON CONFLICT (config_key) WHERE shop_id IS NULL
DO UPDATE SET
  config_value = EXCLUDED.config_value,
  description = EXCLUDED.description,
  updated_at = CURRENT_TIMESTAMP;

COMMIT;
