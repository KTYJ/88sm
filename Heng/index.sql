-- ==========================================
-- INDEXES
-- ==========================================

DROP INDEX idx_orders_branch;
DROP INDEX idx_orders_member;
DROP INDEX idx_procurement_branch_item;
DROP INDEX idx_member_expiry;
DROP INDEX idx_pointhistory_member;

CREATE INDEX idx_orders_branch ON orders(branch_id);
CREATE INDEX idx_orders_member ON orders(member_id);
CREATE INDEX idx_member_expiry ON member(expiry_date);
CREATE INDEX idx_procurement_branch_item ON procurement(branch_id, item_id);
CREATE INDEX idx_pointhistory_member ON point_history(member_id);
