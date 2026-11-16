BEGIN;

-- shop_id is the application scope used by shop_members, products and warehouses.
CREATE TABLE shop_inventory_partnerships (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    requester_shop_id integer NOT NULL,
    recipient_shop_id integer NOT NULL,
    requested_by integer NOT NULL REFERENCES users(id),
    resolved_by integer REFERENCES users(id),
    status varchar(12) NOT NULL DEFAULT 'PENDING',
    created_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    CHECK (requester_shop_id <> recipient_shop_id),
    CHECK (status IN ('PENDING', 'ACTIVE', 'REJECTED', 'CLOSED')),
    CHECK (
        (status = 'PENDING' AND resolved_by IS NULL AND resolved_at IS NULL)
        OR (status <> 'PENDING' AND resolved_by IS NOT NULL AND resolved_at IS NOT NULL)
    )
);

CREATE UNIQUE INDEX shop_inventory_partnerships_open_pair
    ON shop_inventory_partnerships (
        LEAST(requester_shop_id, recipient_shop_id),
        GREATEST(requester_shop_id, recipient_shop_id)
    ) WHERE status IN ('PENDING', 'ACTIVE');

-- One loan per matched product pair. Return shipments reference this loan.
CREATE TABLE shop_inventory_loans (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    partnership_id integer NOT NULL REFERENCES shop_inventory_partnerships(id),
    borrower_shop_id integer NOT NULL,
    borrower_product_id integer NOT NULL REFERENCES products(id),
    lender_product_id integer REFERENCES products(id),
    borrower_warehouse_id integer NOT NULL REFERENCES warehouses(id),
    requested_quantity integer NOT NULL CHECK (requested_quantity > 0),
    requested_by integer NOT NULL REFERENCES users(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    canceled_at timestamptz,
    canceled_by integer REFERENCES users(id),
    CHECK ((canceled_at IS NULL) = (canceled_by IS NULL))
);

CREATE INDEX shop_inventory_loans_partnership
    ON shop_inventory_loans (partnership_id, id DESC);

-- One outbound loan shipment and any number of return shipments.
CREATE TABLE shop_inventory_loan_shipments (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    loan_id integer NOT NULL REFERENCES shop_inventory_loans(id),
    direction varchar(6) NOT NULL CHECK (direction IN ('LOAN', 'RETURN')),
    source_warehouse_id integer NOT NULL REFERENCES warehouses(id),
    destination_warehouse_id integer NOT NULL REFERENCES warehouses(id),
    shipped_quantity integer NOT NULL CHECK (shipped_quantity > 0),
    shipped_by integer NOT NULL REFERENCES users(id),
    shipped_at timestamptz NOT NULL DEFAULT now(),
    operation_id uuid NOT NULL UNIQUE,
    CHECK (source_warehouse_id <> destination_warehouse_id)
);

CREATE UNIQUE INDEX shop_inventory_loan_single_outbound
    ON shop_inventory_loan_shipments (loan_id) WHERE direction = 'LOAN';

CREATE INDEX shop_inventory_loan_shipments_loan
    ON shop_inventory_loan_shipments (loan_id, id);

CREATE TABLE shop_inventory_loan_receipts (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shipment_id integer NOT NULL REFERENCES shop_inventory_loan_shipments(id),
    received_quantity integer NOT NULL CHECK (received_quantity > 0),
    received_by integer NOT NULL REFERENCES users(id),
    received_at timestamptz NOT NULL DEFAULT now(),
    operation_id uuid NOT NULL UNIQUE
);

CREATE INDEX shop_inventory_loan_receipts_shipment
    ON shop_inventory_loan_receipts (shipment_id, id);

-- Express will enforce membership and write stock and shipment records together.
ALTER TABLE shop_inventory_partnerships ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_inventory_loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_inventory_loan_shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_inventory_loan_receipts ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON shop_inventory_partnerships, shop_inventory_loans,
    shop_inventory_loan_shipments, shop_inventory_loan_receipts FROM PUBLIC;

DO $$
DECLARE
    api_role text;
BEGIN
    FOR api_role IN SELECT rolname FROM pg_roles WHERE rolname IN ('anon', 'authenticated')
    LOOP
        EXECUTE format(
            'REVOKE ALL ON shop_inventory_partnerships, shop_inventory_loans,
             shop_inventory_loan_shipments, shop_inventory_loan_receipts FROM %I',
            api_role
        );
    END LOOP;
END $$;

COMMIT;
