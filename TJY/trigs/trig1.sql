SET DEFINE OFF;

-- =============================================================================
-- TRIGGER 1: trg_stock_deduct
-- by TAN JIN YUAN
-- Description: Automatically deducts stock quantity from branch_stock whenever
--              a new order_item line is inserted. Includes full consistency 
--              checks for order existence, item validity, branch stock 
--              record presence, quantity validity, and stock availability.
-- =============================================================================
DROP TRIGGER trg_stock_deduct;
CREATE OR REPLACE TRIGGER trg_stock_deduct
AFTER INSERT ON order_item
FOR EACH ROW
DECLARE
    v_branch_id     orders.branch_id%TYPE;
    v_current_stock branch_stock.stock_quantity%TYPE;
    v_item_count    NUMBER;
BEGIN
    -- 1. Check quantity validity
    IF :NEW.quantity IS NULL OR :NEW.quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20014, 'Order item quantity must be greater than zero.');
    END IF;

    -- 2. Verify that the order exists and retrieve its branch_id
    BEGIN
        SELECT branch_id INTO v_branch_id
        FROM   orders
        WHERE  order_id = :NEW.order_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20010, 'Invalid order_id (' || :NEW.order_id || ') — record does not exist in orders table.');
    END;

    -- 3. Verify that the item exists in master item table
    SELECT COUNT(*) INTO v_item_count
    FROM   item
    WHERE  item_id = :NEW.item_id;

    IF v_item_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'Invalid item_id (' || :NEW.item_id || ') — record does not exist in item master table.');
    END IF;

    -- 4. Verify that the item/branch stock record exists and retrieve current stock
    BEGIN
        SELECT stock_quantity INTO v_current_stock
        FROM   branch_stock
        WHERE  branch_id = v_branch_id AND item_id = :NEW.item_id
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20012, 'Item ' || :NEW.item_id || ' is not assigned or stocked at branch ' || v_branch_id || '.');
    END;

    -- 5. Verify that current stock is sufficient for this deduction
    IF v_current_stock < :NEW.quantity THEN
        RAISE_APPLICATION_ERROR(-20013, 'Insufficient stock for item ' || :NEW.item_id || 
            ' at branch ' || v_branch_id || '. Available: ' || v_current_stock || ', Required: ' || :NEW.quantity || '.');
    END IF;

    -- 6. Perform stock deduction
    UPDATE branch_stock
    SET    stock_quantity = stock_quantity - :NEW.quantity
    WHERE  branch_id = v_branch_id
    AND    item_id   = :NEW.item_id;
    DBMS_OUTPUT.PUT_LINE('trg_stock_deduct: Stock for item ' || :NEW.item_id || ' at branch ' || v_branch_id || ' deducted successfully.');

END trg_stock_deduct;
/
