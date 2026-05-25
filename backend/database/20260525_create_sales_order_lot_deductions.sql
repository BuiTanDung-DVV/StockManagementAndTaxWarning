CREATE TABLE sales_order_lot_deductions (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES sales_orders(id) ON DELETE CASCADE,
    order_item_id INT REFERENCES sales_order_items(id) ON DELETE CASCADE,
    lot_id INT REFERENCES inventory_lots(id),
    quantity INT NOT NULL
);
