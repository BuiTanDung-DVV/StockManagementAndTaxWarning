-- Safe only before any opening-balance receipt or effect has been used.
-- Once used, retain storage/readers and correct business figures with a new reconciliation.
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';
SET LOCAL search_path = public, pg_temp;
LOCK TABLE public.opening_balance_batches, public.opening_balance_adjustments IN ACCESS EXCLUSIVE MODE;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.opening_balance_batches)
        OR EXISTS (SELECT 1 FROM public.opening_balance_adjustments)
        OR EXISTS (SELECT 1 FROM public.journal_entries WHERE reference_type='OPENING_BALANCE')
        OR EXISTS (SELECT 1 FROM public.inventory_movements WHERE reference_type='OPENING_BALANCE') THEN
        RAISE EXCEPTION 'Opening balances already used; preserve storage and readers. No data changed.';
    END IF;
END $$;
DROP TABLE public.opening_balance_adjustments;
DROP TABLE public.opening_balance_batches;
DROP FUNCTION public.validate_opening_adjustment_reference();
COMMIT;
