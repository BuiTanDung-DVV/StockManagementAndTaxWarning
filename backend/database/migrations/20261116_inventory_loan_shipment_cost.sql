BEGIN;

-- Existing shipments without a cost snapshot require reconciliation before receipt.
ALTER TABLE shop_inventory_loan_shipments
    ADD COLUMN unit_cost numeric(18, 2) CHECK (unit_cost >= 0);

COMMIT;
