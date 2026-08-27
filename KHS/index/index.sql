-- ================================================================
-- INDEXES FOR INVENTORY TURNOVER ANALYSIS
-- ================================================================

CREATE INDEX idx_branch_stock_item
ON branch_stock(item_id);

CREATE INDEX idx_procurement_item
ON procurement(item_id);