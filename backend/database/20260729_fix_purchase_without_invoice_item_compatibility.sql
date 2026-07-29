BEGIN;

ALTER TABLE public.purchase_without_invoice_items
    ADD COLUMN IF NOT EXISTS product_name varchar(200),
    ADD COLUMN IF NOT EXISTS shop_id integer,
    ADD COLUMN IF NOT EXISTS warehouse_id integer;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'purchase_without_invoice_items'
          AND column_name = 'item_name'
    ) THEN
        UPDATE public.purchase_without_invoice_items
        SET product_name = COALESCE(NULLIF(product_name, ''), item_name)
        WHERE product_name IS NULL OR product_name = '';

        ALTER TABLE public.purchase_without_invoice_items
            ALTER COLUMN item_name DROP NOT NULL;
    END IF;
END
$$;

ALTER TABLE public.purchase_without_invoice_items
    ALTER COLUMN product_name SET NOT NULL;

COMMIT;
