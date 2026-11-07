-- SmartStock opening-balance receipts and append-only effects.
-- No existing business rows are changed. Run only after package approval.
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';
SET LOCAL search_path = public, pg_temp;
CREATE TABLE opening_balance_batches (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shop_id integer NOT NULL REFERENCES shop_profiles(id),
    operation_id varchar(64) NOT NULL CHECK (operation_id ~ '^[a-f0-9]{32,64}$'),
    actor_id integer NOT NULL REFERENCES users(id),
    as_of date NOT NULL,
    request_hash varchar(64) NOT NULL CHECK (request_hash ~ '^[a-f0-9]{64}$'),
    plan_hash varchar(64) NOT NULL CHECK (plan_hash ~ '^[a-f0-9]{64}$'),
    snapshot_revision varchar(64) NOT NULL CHECK (snapshot_revision ~ '^[a-f0-9]{64}$'),
    result jsonb NOT NULL CHECK (jsonb_typeof(result) = 'object'),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (shop_id, operation_id),
    UNIQUE (shop_id, id)
);
CREATE INDEX opening_batches_shop_date_idx ON opening_balance_batches(shop_id, as_of, id);
CREATE INDEX opening_batches_actor_idx ON opening_balance_batches(actor_id);

CREATE TABLE opening_balance_adjustments (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shop_id integer NOT NULL,
    batch_id integer NOT NULL,
    object_key varchar(100) NOT NULL,
    kind varchar(20) NOT NULL CHECK (kind IN ('CASH','BANK','STOCK','RECEIVABLE','PAYABLE')),
    effect_mode varchar(20) NOT NULL CHECK (effect_mode IN ('BALANCE_OFFSET','LINKED_DOCUMENT','STOCK_MOVEMENT')),
    amount_delta numeric(15,2) NOT NULL DEFAULT 0,
    quantity_delta integer NOT NULL DEFAULT 0,
    product_id integer REFERENCES products(id),
    warehouse_id integer REFERENCES warehouses(id),
    receivable_id integer REFERENCES receivables(id),
    payable_id integer REFERENCES payables(id),
    source_details jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(source_details) = 'object'),
    FOREIGN KEY (shop_id, batch_id) REFERENCES opening_balance_batches(shop_id, id) ON DELETE RESTRICT,
    CHECK ((kind='CASH' AND object_key='cash') OR (kind='BANK' AND object_key='bank')
      OR (kind='STOCK' AND object_key='stock:'||product_id::text||':'||warehouse_id::text)
      OR (kind='RECEIVABLE' AND object_key ~ '^customer:[1-9][0-9]*$')
      OR (kind='PAYABLE' AND object_key ~ '^supplier:[1-9][0-9]*$')),
    CHECK (
      (kind IN ('CASH','BANK') AND effect_mode='BALANCE_OFFSET' AND amount_delta<>0 AND quantity_delta=0
       AND product_id IS NULL AND warehouse_id IS NULL AND receivable_id IS NULL AND payable_id IS NULL)
      OR
      (kind='STOCK' AND effect_mode='STOCK_MOVEMENT' AND quantity_delta<>0 AND (amount_delta=0 OR sign(amount_delta)=sign(quantity_delta))
       AND product_id IS NOT NULL AND warehouse_id IS NOT NULL AND receivable_id IS NULL AND payable_id IS NULL)
      OR
      (kind='RECEIVABLE' AND receivable_id IS NOT NULL AND payable_id IS NULL AND product_id IS NULL AND warehouse_id IS NULL
       AND quantity_delta=0 AND ((effect_mode='LINKED_DOCUMENT' AND amount_delta>0) OR (effect_mode='BALANCE_OFFSET' AND amount_delta<0)))
      OR
      (kind='PAYABLE' AND payable_id IS NOT NULL AND receivable_id IS NULL AND product_id IS NULL AND warehouse_id IS NULL
       AND quantity_delta=0 AND ((effect_mode='LINKED_DOCUMENT' AND amount_delta>0) OR (effect_mode='BALANCE_OFFSET' AND amount_delta<0)))
    )
);
CREATE INDEX opening_adjustments_batch_idx ON opening_balance_adjustments(shop_id, batch_id);
CREATE INDEX opening_adjustments_object_idx ON opening_balance_adjustments(shop_id, object_key, batch_id);
CREATE INDEX opening_adjustments_receivable_idx ON opening_balance_adjustments(receivable_id) WHERE receivable_id IS NOT NULL;
CREATE INDEX opening_adjustments_payable_idx ON opening_balance_adjustments(payable_id) WHERE payable_id IS NOT NULL;
CREATE INDEX opening_adjustments_product_idx ON opening_balance_adjustments(product_id) WHERE product_id IS NOT NULL;
CREATE INDEX opening_adjustments_warehouse_idx ON opening_balance_adjustments(warehouse_id) WHERE warehouse_id IS NOT NULL;
CREATE UNIQUE INDEX opening_receivable_document_once_idx ON opening_balance_adjustments(receivable_id) WHERE effect_mode='LINKED_DOCUMENT' AND receivable_id IS NOT NULL;
CREATE UNIQUE INDEX opening_payable_document_once_idx ON opening_balance_adjustments(payable_id) WHERE effect_mode='LINKED_DOCUMENT' AND payable_id IS NOT NULL;

CREATE FUNCTION validate_opening_adjustment_reference() RETURNS trigger
LANGUAGE plpgsql SET search_path=public,pg_temp AS $$
BEGIN
  IF NEW.kind='STOCK' AND NOT EXISTS (
    SELECT 1 FROM public.products p JOIN public.warehouses w ON w.id=NEW.warehouse_id AND w.shop_id=NEW.shop_id
    WHERE p.id=NEW.product_id AND p.shop_id=NEW.shop_id
  ) THEN RAISE EXCEPTION 'Opening stock source belongs to another shop' USING ERRCODE='23514'; END IF;
  IF NEW.kind='RECEIVABLE' AND NOT EXISTS (
    SELECT 1 FROM public.receivables d WHERE d.id=NEW.receivable_id AND d.shop_id=NEW.shop_id
      AND NEW.object_key='customer:'||d.customer_id::text
  ) THEN RAISE EXCEPTION 'Opening receivable source does not match shop/party' USING ERRCODE='23514'; END IF;
  IF NEW.kind='PAYABLE' AND NOT EXISTS (
    SELECT 1 FROM public.payables d WHERE d.id=NEW.payable_id AND d.shop_id=NEW.shop_id
      AND NEW.object_key='supplier:'||d.supplier_id::text
  ) THEN RAISE EXCEPTION 'Opening payable source does not match shop/party' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER opening_adjustment_reference_guard BEFORE INSERT OR UPDATE ON opening_balance_adjustments
FOR EACH ROW EXECUTE FUNCTION validate_opening_adjustment_reference();

ALTER TABLE opening_balance_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE opening_balance_adjustments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON opening_balance_batches, opening_balance_adjustments FROM PUBLIC;
REVOKE ALL ON SEQUENCE opening_balance_batches_id_seq, opening_balance_adjustments_id_seq FROM PUBLIC;
DO $$
DECLARE client_role text;
BEGIN
  FOREACH client_role IN ARRAY ARRAY['anon','authenticated'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname=client_role) THEN
      EXECUTE format('REVOKE ALL ON opening_balance_batches, opening_balance_adjustments FROM %I', client_role);
      EXECUTE format('REVOKE ALL ON SEQUENCE opening_balance_batches_id_seq, opening_balance_adjustments_id_seq FROM %I', client_role);
    END IF;
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.validate_opening_adjustment_reference() FROM PUBLIC;
COMMIT;
