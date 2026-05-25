CREATE TABLE IF NOT EXISTS tax_rules (
    id SERIAL PRIMARY KEY,
    industry_code VARCHAR(10) NOT NULL,
    name VARCHAR(100) NOT NULL,
    vat_rate NUMERIC(4, 2) NOT NULL,
    pit_rate NUMERIC(4, 2) NOT NULL,
    effective_from TIMESTAMP NOT NULL,
    effective_to TIMESTAMP
);
