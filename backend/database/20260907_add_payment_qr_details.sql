BEGIN;

ALTER TABLE shop_profiles
  ADD COLUMN IF NOT EXISTS qr_payment_payload TEXT,
  ADD COLUMN IF NOT EXISTS qr_payment_details JSONB;

COMMIT;
