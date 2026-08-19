--inventory_turnover_rate
CREATE INDEX idx_orders_order_date
ON orders(order_date);

CREATE INDEX idx_procurement_item
ON procurement(item_id);

CREATE INDEX idx_branch_stock_item
ON branch_stock(item_id);


--supplier_item_sales
CREATE INDEX idx_procurement_supplier
ON procurement(supplier_id);

CREATE INDEX idx_procurement_item
ON procurement(item_id);


-- customer_loyalty
CREATE INDEX idx_orders_branch_member_date
ON orders(branch_id, member_id, order_date);


-- promotion performance
CREATE INDEX idx_order_item_item
ON order_item(item_id);