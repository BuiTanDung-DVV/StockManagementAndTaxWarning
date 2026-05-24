-- 20260524_create_journal_ledger.sql

-- Create Journal Entries table
CREATE TABLE IF NOT EXISTS public.journal_entries (
    id SERIAL PRIMARY KEY,
    shop_id INTEGER NOT NULL,
    entry_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    reference_type VARCHAR(50) NOT NULL, -- e.g. 'SALES_ORDER', 'PURCHASE_ORDER', 'CASH_RECEIPT'
    reference_id INTEGER NOT NULL,
    description TEXT,
    is_voided BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_journal_entries_shop_id ON public.journal_entries(shop_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_ref ON public.journal_entries(reference_type, reference_id);

-- Create Journal Lines table
CREATE TABLE IF NOT EXISTS public.journal_lines (
    id SERIAL PRIMARY KEY,
    journal_entry_id INTEGER NOT NULL REFERENCES public.journal_entries(id) ON DELETE CASCADE,
    account_code VARCHAR(50) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    entry_type VARCHAR(10) NOT NULL CHECK (entry_type IN ('DEBIT', 'CREDIT')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_journal_lines_entry_id ON public.journal_lines(journal_entry_id);
CREATE INDEX IF NOT EXISTS idx_journal_lines_account ON public.journal_lines(account_code);
