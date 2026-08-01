BEGIN;

ALTER TABLE public.users
  ALTER COLUMN password DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS google_subject VARCHAR(255),
  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS failed_login_attempts INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS auth_version INTEGER NOT NULL DEFAULT 0;

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_google_subject
  ON public.users (google_subject)
  WHERE google_subject IS NOT NULL;

-- OTP cũ lưu dạng rõ nên phải hủy khi chuyển sang HMAC.
DELETE FROM public.otps;

ALTER TABLE public.otps
  ALTER COLUMN otp_code TYPE VARCHAR(64),
  ADD COLUMN IF NOT EXISTS purpose VARCHAR(20) NOT NULL DEFAULT 'REGISTER',
  ADD COLUMN IF NOT EXISTS attempts INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS consumed_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_otps_identifier_purpose_created
  ON public.otps (phone, purpose, created_at DESC);

CREATE TABLE IF NOT EXISTS public.refresh_sessions (
  id UUID PRIMARY KEY,
  family_id UUID NOT NULL,
  user_id INTEGER NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  token_hash VARCHAR(64) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  replaced_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_refresh_sessions_user_active
  ON public.refresh_sessions (user_id, expires_at)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_refresh_sessions_family
  ON public.refresh_sessions (family_id);

COMMIT;
