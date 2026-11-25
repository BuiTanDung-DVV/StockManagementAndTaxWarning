BEGIN;
SET LOCAL lock_timeout = '5s';

-- NULL means the opening value is the current value at original lot costs.
ALTER TABLE products ADD COLUMN average_inventory_value numeric(18, 2)
    CHECK (average_inventory_value >= 0);

-- Preserve the cost per unit used when an order is returned or a shipment is received.
ALTER TABLE sales_order_items
    ALTER COLUMN cost_price TYPE numeric(26, 10);
ALTER TABLE shop_inventory_loan_shipments
    ALTER COLUMN unit_cost TYPE numeric(26, 10);

COMMIT;
