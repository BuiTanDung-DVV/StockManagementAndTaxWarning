-- 20260525_create_financial_ledger.sql

CREATE TABLE IF NOT EXISTS public.financial_ledger (
    id SERIAL PRIMARY KEY,
    transaction_type VARCHAR(10) NOT NULL CHECK (transaction_type IN ('IN', 'OUT')),
    amount DECIMAL(15,2) NOT NULL,
    reference_id VARCHAR(50),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_financial_ledger_type ON public.financial_ledger(transaction_type);
CREATE INDEX IF NOT EXISTS idx_financial_ledger_ref ON public.financial_ledger(reference_id);
