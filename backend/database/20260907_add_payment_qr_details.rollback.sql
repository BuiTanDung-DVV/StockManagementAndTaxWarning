BEGIN;

ALTER TABLE shop_profiles
  DROP COLUMN IF EXISTS qr_payment_details,
  DROP COLUMN IF EXISTS qr_payment_payload;

COMMIT;
