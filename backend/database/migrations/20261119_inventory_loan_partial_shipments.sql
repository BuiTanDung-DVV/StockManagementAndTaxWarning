BEGIN;

-- The service locks the loan row before checking the remaining quantity and
-- keeps the same lender product and source warehouse across outbound shipments.
DROP INDEX IF EXISTS shop_inventory_loan_single_outbound;

COMMIT;
