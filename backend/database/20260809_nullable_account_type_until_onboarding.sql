BEGIN;

ALTER TABLE users
  ALTER COLUMN account_type DROP DEFAULT,
  ALTER COLUMN account_type DROP NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'users_account_type_allowed'
      AND conrelid = 'users'::regclass
  ) THEN
    ALTER TABLE users
      ADD CONSTRAINT users_account_type_allowed
      CHECK (account_type IS NULL OR account_type IN ('SHOP', 'PERSONAL'));
  END IF;
END
$$;

COMMIT;
