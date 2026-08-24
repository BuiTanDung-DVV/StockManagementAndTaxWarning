ALTER TABLE invoices
ADD COLUMN IF NOT EXISTS discount_amount DECIMAL(18,2) NOT NULL DEFAULT 0;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_invoices_discount_amount'
    ) THEN
        ALTER TABLE invoices
        ADD CONSTRAINT chk_invoices_discount_amount
        CHECK (discount_amount >= 0 AND discount_amount <= subtotal);
    END IF;
END $$;
