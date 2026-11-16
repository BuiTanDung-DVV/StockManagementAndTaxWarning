BEGIN;

CREATE TABLE inventory_shelf_positions (
    shop_id integer NOT NULL REFERENCES shop_profiles(id),
    warehouse_id integer NOT NULL REFERENCES warehouses(id),
    product_id integer NOT NULL REFERENCES products(id),
    rack varchar(24) NOT NULL CHECK (btrim(rack) <> ''),
    level integer NOT NULL CHECK (level BETWEEN 1 AND 12),
    bin integer NOT NULL CHECK (bin BETWEEN 1 AND 16),
    PRIMARY KEY (shop_id, warehouse_id, product_id)
);

ALTER TABLE inventory_shelf_positions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON inventory_shelf_positions FROM PUBLIC;
DO $$
DECLARE
    api_role text;
BEGIN
    FOR api_role IN SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated')
    LOOP
        EXECUTE format('REVOKE ALL ON inventory_shelf_positions FROM %I', api_role);
    END LOOP;
END $$;

COMMIT;
