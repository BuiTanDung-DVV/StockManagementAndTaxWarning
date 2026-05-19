-- ==============================================================================
-- Database Performance Optimization Script
-- Execute this script in your Supabase SQL Editor
-- This adds crucial indexes to significantly reduce CRUD latency (from 5s -> <1s)
-- ==============================================================================

-- 1. Enable pg_trgm for fast LIKE/ILIKE searches on text columns
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. Create Multi-Tenant Indexes (shop_id)
-- Almost all queries have `WHERE shop_id = ?`, so indexing these will avoid Seq Scans.

CREATE INDEX IF NOT EXISTS idx_users_shop_id ON public.users(shop_id);
CREATE INDEX IF NOT EXISTS idx_customers_shop_id ON public.customers(shop_id);
CREATE INDEX IF NOT EXISTS idx_receivables_shop_id ON public.receivables(shop_id);
CREATE INDEX IF NOT EXISTS idx_debt_evidences_shop_id ON public.debt_evidences(shop_id);
CREATE INDEX IF NOT EXISTS idx_debt_payment_histories_shop_id ON public.debt_payment_histories(shop_id);
CREATE INDEX IF NOT EXISTS idx_cash_accounts_shop_id ON public.cash_accounts(shop_id);
CREATE INDEX IF NOT EXISTS idx_cash_transactions_shop_id ON public.cash_transactions(shop_id);
CREATE INDEX IF NOT EXISTS idx_budget_plans_shop_id ON public.budget_plans(shop_id);
CREATE INDEX IF NOT EXISTS idx_cashflow_forecasts_shop_id ON public.cashflow_forecasts(shop_id);
CREATE INDEX IF NOT EXISTS idx_daily_closings_shop_id ON public.daily_closings(shop_id);
CREATE INDEX IF NOT EXISTS idx_invoices_shop_id ON public.invoices(shop_id);
CREATE INDEX IF NOT EXISTS idx_tax_obligations_shop_id ON public.tax_obligations(shop_id);
CREATE INDEX IF NOT EXISTS idx_warehouses_shop_id ON public.warehouses(shop_id);
CREATE INDEX IF NOT EXISTS idx_inventory_stocks_shop_id ON public.inventory_stocks(shop_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_shop_id ON public.inventory_movements(shop_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_shop_id ON public.purchase_orders(shop_id);
CREATE INDEX IF NOT EXISTS idx_stock_takes_shop_id ON public.stock_takes(shop_id);
CREATE INDEX IF NOT EXISTS idx_categories_shop_id ON public.categories(shop_id);
CREATE INDEX IF NOT EXISTS idx_products_shop_id ON public.products(shop_id);
CREATE INDEX IF NOT EXISTS idx_cost_types_shop_id ON public.cost_types(shop_id);
CREATE INDEX IF NOT EXISTS idx_product_batches_shop_id ON public.product_batches(shop_id);
CREATE INDEX IF NOT EXISTS idx_product_price_history_shop_id ON public.product_price_history(shop_id);
CREATE INDEX IF NOT EXISTS idx_sales_orders_shop_id ON public.sales_orders(shop_id);
CREATE INDEX IF NOT EXISTS idx_sales_returns_shop_id ON public.sales_returns(shop_id);
CREATE INDEX IF NOT EXISTS idx_shop_roles_shop_id ON public.shop_roles(shop_id);
CREATE INDEX IF NOT EXISTS idx_shop_members_shop_id ON public.shop_members(shop_id);
CREATE INDEX IF NOT EXISTS idx_notifications_shop_id ON public.notifications(shop_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_shop_id ON public.suppliers(shop_id);
CREATE INDEX IF NOT EXISTS idx_payables_shop_id ON public.payables(shop_id);
CREATE INDEX IF NOT EXISTS idx_shop_profiles_shop_id ON public.shop_profiles(shop_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_shop_id ON public.activity_logs(shop_id);

-- 3. Create Foreign Key Indexes
-- Helps with JOIN operations (e.g. JOIN inventory_stocks on product_id)
CREATE INDEX IF NOT EXISTS idx_inventory_stocks_product_id ON public.inventory_stocks(product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_stocks_warehouse_id ON public.inventory_stocks(warehouse_id);

CREATE INDEX IF NOT EXISTS idx_product_cost_items_product_id ON public.product_cost_items(product_id);
CREATE INDEX IF NOT EXISTS idx_product_cost_items_cost_type_id ON public.product_cost_items(cost_type_id);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_product_id ON public.inventory_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_items_po_id ON public.purchase_order_items(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_sales_order_items_so_id ON public.sales_order_items(sales_order_id);
CREATE INDEX IF NOT EXISTS idx_sales_order_payments_so_id ON public.sales_order_payments(sales_order_id);
CREATE INDEX IF NOT EXISTS idx_sales_return_items_return_id ON public.sales_return_items(sales_return_id);

CREATE INDEX IF NOT EXISTS idx_products_category_id ON public.products(category_id);

-- 4. Create GIN Indexes for faster fuzzy text searches (LIKE %...%)
CREATE INDEX IF NOT EXISTS idx_products_name_trgm ON public.products USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_products_sku_trgm ON public.products USING GIN (sku gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_products_barcode_trgm ON public.products USING GIN (barcode gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_customers_name_trgm ON public.customers USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_customers_phone_trgm ON public.customers USING GIN (phone gin_trgm_ops);

