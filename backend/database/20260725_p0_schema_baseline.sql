BEGIN;

ALTER TABLE public.shop_profiles
  ADD COLUMN IF NOT EXISTS business_sector VARCHAR(50) DEFAULT 'TRADE',
  ADD COLUMN IF NOT EXISTS apply_vat_reduction BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS custom_vat_rate DECIMAL(5,2),
  ADD COLUMN IF NOT EXISTS custom_pit_rate DECIMAL(5,2);

CREATE TABLE IF NOT EXISTS public.otps (
  id SERIAL PRIMARY KEY,
  phone VARCHAR(255) NOT NULL,
  otp_code VARCHAR(10) NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.otps
  ALTER COLUMN phone TYPE VARCHAR(255);

CREATE INDEX IF NOT EXISTS idx_otps_phone_expires_at
  ON public.otps (phone, expires_at);

COMMIT;
