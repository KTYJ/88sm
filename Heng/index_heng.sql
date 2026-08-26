-- ==========================================
-- INDEXES
-- ==========================================

BEGIN
	FOR index_name IN (
		SELECT column_value AS name
		FROM TABLE(sys.odcivarchar2list(
			'IDX_HENG_BRANCH_STOCK_ITEM',
			'IDX_HENG_ORDER_ITEM_ITEM'
		))
	) LOOP
		BEGIN
			EXECUTE IMMEDIATE 'DROP INDEX ' || index_name.name;
		EXCEPTION
			WHEN OTHERS THEN
				IF SQLCODE != -1418 THEN
					RAISE;
				END IF;
		END;
	END LOOP;
END;
/

-- Index 1: Branch stock by item
-- Description: Speeds up stock lookup and grouping by item_id.
-- Application: Supports Query 6.2 stock calculations for item pairs.
CREATE INDEX idx_heng_branch_stock_item
ON branch_stock(item_id);

-- Index 2: Order items by item and order
-- Description: Speeds up order-item lookup by item_id and order_id.
-- Application: Supports item-pair matching in Query 6.2.
CREATE INDEX idx_heng_order_item_item
ON order_item(item_id, order_id);
