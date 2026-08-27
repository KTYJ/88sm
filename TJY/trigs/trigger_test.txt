-- =============================================================================
-- MINIMAL TRIGGER TEST SCRIPT (1 Negative Test Case for Each Trigger)
-- =============================================================================

-- TEST 1: trg_stock_deduct (Negative Test: Insufficient Stock -> Expects ORA-20013)
-- Attempts to order 999,999 units (exceeding stock) on an existing order
commit;

INSERT INTO order_item (order_id, item_id, quantity, unit_price)
VALUES ((SELECT MAX(order_id) FROM orders), (SELECT MIN(item_id) FROM item), 999999, 10.00);

-- TEST 2: trg_points_balance (Negative Test: Insufficient Points -> Expects ORA-20023)
-- Attempts to redeem 999,999 points (exceeding balance) for an existing member
INSERT INTO point_history (point_redemption_id, order_id, amount, transaction_type)
VALUES (999999, (SELECT MIN(order_id) FROM orders WHERE member_id IS NOT NULL), 999999, 'Used');

ROLLBACK;
