drop index idx_orders_date;
drop index idx_stock_qty;
drop index idx_procurement_date;
drop index idx_subtotal;

CREATE INDEX idx_orders_date ON orders(order_date);
CREATE INDEX idx_stock_qty ON branch_stock(stock_quantity);
CREATE INDEX idx_procurement_date ON procurement(procurement_date);
CREATE INDEX idx_subtotal ON order_item(quantity * unit_price);
