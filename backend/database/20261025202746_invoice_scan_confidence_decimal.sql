-- Approved and applied to production as migration20261025202746.
-- Preserve all existing score values and other scan fields.
BEGIN;
SET LOCAL lock_timeout='3s';
SET LOCAL statement_timeout='30s';
LOCK TABLE public.invoice_scans IN ACCESS EXCLUSIVE MODE;
DO $migration$
DECLARE values_before text; other_fields_before text; rows_before bigint;
BEGIN
 IF (SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='invoice_scans' AND column_name='confidence_score') IS DISTINCT FROM 'integer' THEN RAISE EXCEPTION 'Expected integer confidence column; stop'; END IF;
 IF EXISTS(SELECT 1 FROM public.invoice_scans WHERE ABS(confidence_score::numeric)>=1000) THEN RAISE EXCEPTION 'Legacy score exceeds proposed range'; END IF;
 SELECT count(*),md5(string_agg(COALESCE(trim_scale(confidence_score::numeric)::text,'NULL'),'|' ORDER BY id)),md5(string_agg((to_jsonb(s)-'confidence_score')::text,'|' ORDER BY id)) INTO rows_before,values_before,other_fields_before FROM public.invoice_scans s;
 ALTER TABLE public.invoice_scans ALTER COLUMN confidence_score TYPE numeric(9,6) USING confidence_score::numeric(9,6);
 IF rows_before IS DISTINCT FROM (SELECT count(*) FROM public.invoice_scans) THEN RAISE EXCEPTION 'Unexpected row count change'; END IF;
 IF values_before IS DISTINCT FROM (SELECT md5(string_agg(COALESCE(trim_scale(confidence_score::numeric)::text,'NULL'),'|' ORDER BY id)) FROM public.invoice_scans) THEN RAISE EXCEPTION 'Confidence values changed'; END IF;
 IF other_fields_before IS DISTINCT FROM (SELECT md5(string_agg((to_jsonb(s)-'confidence_score')::text,'|' ORDER BY id)) FROM public.invoice_scans s) THEN RAISE EXCEPTION 'Other scan fields changed'; END IF;
END $migration$;
COMMIT;
