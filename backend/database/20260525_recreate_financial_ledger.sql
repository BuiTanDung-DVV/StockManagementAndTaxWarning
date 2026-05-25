-- 20260525_recreate_financial_ledger.sql

DROP TABLE IF EXISTS public.financial_ledger;

CREATE TABLE public.financial_ledger (
    id SERIAL PRIMARY KEY,
    shop_id INT NOT NULL,
    event_type VARCHAR(50) NOT NULL, -- 'SALE', 'CANCEL_SALE', 'PURCHASE', 'EXPENSE', 'SALARY', 'TAX_PAYMENT'
    amount NUMERIC(15, 2) NOT NULL,
    payment_method VARCHAR(30) NOT NULL, -- 'CASH', 'BANK_TRANSFER', 'QR_CODE'
    account_id INT, -- Liên kết cash_accounts
    reference_id INT, -- ID của đơn hàng, phiếu lương, hoặc chi phí
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INT
);

CREATE INDEX idx_financial_ledger_shop_id ON public.financial_ledger(shop_id);
CREATE INDEX idx_financial_ledger_event_type ON public.financial_ledger(event_type);
CREATE INDEX idx_financial_ledger_reference_id ON public.financial_ledger(reference_id);
