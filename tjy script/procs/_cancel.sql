-- ====================================================================
-- Proc 1: Cancel Pending Order
-- Purpose: To cancel an order, restore stock quantities, and remove 
--          associated order/delivery/redemption records.
-- ====================================================================
CREATE OR REPLACE PROCEDURE proc_cancel_order (p_order_id IN NUMBER) AS
    v_branch_id branch.branch_id%TYPE;
    v_item_id   item.item_id%TYPE;
    v_qty       order_item.quantity%TYPE;
    v_found BOOLEAN := FALSE;

    CURSOR c_items IS 
        SELECT item_id, quantity 
        FROM order_item 
        WHERE order_id = p_order_id;

BEGIN
    -- Fetch the branch associated with the order
    SELECT branch_id INTO v_branch_id 
    FROM orders 
    WHERE order_id = p_order_id;

    -- Loop through all items in the order and restore branch stock
    OPEN c_items;
    LOOP
        FETCH c_items INTO v_item_id, v_qty;
        EXIT WHEN c_items%NOTFOUND;
        
        UPDATE branch_stock 
        SET stock_quantity = stock_quantity + v_qty
        WHERE branch_id = v_branch_id AND item_id = v_item_id;
    END LOOP;
    CLOSE c_items;

    -- Delete dependent transaction records
    DELETE FROM delivery      WHERE order_id = p_order_id;
    DELETE FROM self_pickup   WHERE order_id = p_order_id;
    DELETE FROM redemption    WHERE order_id = p_order_id;
    DELETE FROM order_item    WHERE order_id = p_order_id;
    DELETE FROM orders        WHERE order_id = p_order_id;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Success: Order ' || p_order_id || ' cancelled and stock restored.');

EXCEPTION
    WHEN NO_DATA_FOUND THEN -- no rows select
        DBMS_OUTPUT.PUT_LINE('Error: Order ' || p_order_id || ' not found. No rows deleted');
    WHEN OTHERS THEN 
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM); 
        ROLLBACK;
END;
/

--EXEC proc_cancel_order(9999);