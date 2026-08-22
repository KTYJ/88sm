-- inventory_turnover_rate
CREATE INDEX idx_procurement_item
ON procurement(item_id);

CREATE INDEX idx_branch_stock_item
ON branch_stock(item_id);

-- supplier_item_sales
CREATE INDEX idx_procurement_supplier
ON procurement(supplier_id);

-- customer_loyalty
CREATE INDEX idx_orders_branch_member_date
ON orders(branch_id, member_id, order_date);