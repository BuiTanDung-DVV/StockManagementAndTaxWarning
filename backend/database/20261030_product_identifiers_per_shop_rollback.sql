-- Restore only if no cross-shop SKU reuse occurred after the migration.
-- Never rename/delete products to force rollback.
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';
LOCK TABLE public.products IN SHARE ROW EXCLUSIVE MODE;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.products GROUP BY sku HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION 'SKU reused across shops; rollback requires separate review, no data changed';
    END IF;
END $$;
ALTER TABLE public.products ADD CONSTRAINT "UQ_c44ac33a05b144dd0d9ddcf9327" UNIQUE (sku);
DROP INDEX public.uq_products_shop_active_barcode;
DROP INDEX public.uq_products_shop_sku;
COMMIT;
