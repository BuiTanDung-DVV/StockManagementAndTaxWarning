-- Reviewed package only: production execution requires explicit approval.
-- Preserve every product row, price, image, tag and stock/ledger reference.
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';
LOCK TABLE public.products IN SHARE ROW EXCLUSIVE MODE;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.products'::regclass
          AND conname = 'UQ_c44ac33a05b144dd0d9ddcf9327'
          AND contype = 'u' AND pg_get_constraintdef(oid) = 'UNIQUE (sku)'
    ) THEN
        RAISE EXCEPTION 'Unexpected SKU constraint; stop and inspect schema';
    END IF;
    IF EXISTS (SELECT 1 FROM public.products GROUP BY shop_id, sku HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION 'Duplicate SKU within a shop; no schema changes applied';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.products
        WHERE is_active = true AND barcode IS NOT NULL AND barcode <> ''
        GROUP BY shop_id, barcode HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Duplicate active barcode within a shop; no schema changes applied';
    END IF;
END $$;

-- No IF NOT EXISTS: an unexpected/repeated index name must fail safely instead
-- of allowing an unknown index definition to replace the old guarantee.
CREATE UNIQUE INDEX uq_products_shop_sku ON public.products (shop_id, sku);
CREATE UNIQUE INDEX uq_products_shop_active_barcode ON public.products (shop_id, barcode)
    WHERE is_active = true AND barcode IS NOT NULL AND barcode <> '';
ALTER TABLE public.products DROP CONSTRAINT "UQ_c44ac33a05b144dd0d9ddcf9327";
COMMIT;
