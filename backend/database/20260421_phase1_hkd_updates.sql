-- Phase 1 HKD upgrades: itemized purchases without invoice (Form 01/TNDN)
-- Run in Supabase SQL editor before deploying backend changes.

create table if not exists public.purchase_without_invoice_items (
  id bigserial primary key,
  purchase_id bigint not null references public.purchases_without_invoice(id) on delete cascade,
  product_name varchar(200) not null,
  product_id bigint null,
  quantity numeric(18,3) not null default 0,
  unit_price numeric(18,2) not null default 0,
  subtotal numeric(18,2) not null default 0
);

create index if not exists idx_purchase_without_invoice_items_purchase_id
  on public.purchase_without_invoice_items(purchase_id);

alter table public.purchases_without_invoice
  add column if not exists approval_status varchar(20) not null default 'PENDING',
  add column if not exists approval_notes varchar(500) null,
  add column if not exists approved_at timestamp null;

alter table public.purchase_without_invoice_items
  add column if not exists product_id bigint null;

