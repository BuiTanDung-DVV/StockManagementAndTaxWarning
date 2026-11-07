-- Additive migration. Run in an explicitly approved environment only.
-- No document/stock/cash/debt changes; do not delete receipts to reclaim space.
BEGIN;
CREATE TABLE IF NOT EXISTS sync_operations (
    shop_id integer NOT NULL,
    user_id integer NOT NULL,
    operation_id varchar(64) NOT NULL,
    kind varchar(40) NOT NULL,
    request_hash varchar(64) NOT NULL,
    entity_id integer NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (shop_id, user_id, operation_id),
    CONSTRAINT sync_operation_id_format CHECK (operation_id ~ '^[a-f0-9]{32}$'),
    CONSTRAINT sync_operation_kind CHECK (kind IN ('CASH_TRANSACTION_CREATE', 'SALES_ORDER_CREATE', 'PURCHASE_ORDER_CREATE'))
);
-- Browser clients use the authenticated Express endpoint, never direct Data API.
-- A backend table-owner/service connection retains the existing DB access model.
ALTER TABLE sync_operations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE sync_operations FROM PUBLIC;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        REVOKE ALL ON TABLE sync_operations FROM anon;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        REVOKE ALL ON TABLE sync_operations FROM authenticated;
    END IF;
END $$;
COMMIT;
