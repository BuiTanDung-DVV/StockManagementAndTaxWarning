BEGIN;

CREATE TABLE IF NOT EXISTS public.ai_knowledge_documents (
    id SERIAL PRIMARY KEY,
    shop_id INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    category VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by INTEGER NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_knowledge_documents_shop_active
    ON public.ai_knowledge_documents (shop_id, is_active, created_at DESC);

COMMIT;
