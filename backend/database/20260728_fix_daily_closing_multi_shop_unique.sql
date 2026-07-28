BEGIN;

ALTER TABLE public.daily_closings
    DROP CONSTRAINT IF EXISTS "UQ_07596ead3c6cbbc37265aee9210";

ALTER TABLE public.daily_closings
    DROP CONSTRAINT IF EXISTS "UQ_1ca64a37bd53b3db6958c1911a9";

ALTER TABLE public.daily_closings
    ADD CONSTRAINT "UQ_daily_closings_shop_date"
    UNIQUE (shop_id, closing_date);

COMMIT;
