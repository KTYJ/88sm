cl scr
SET DEFINE OFF;
-- =============================================================================
-- PROCEDURE 2: sp_place_order  (data manipulation + validation)
-- Places a new order with ANY NUMBER of item lines (p_items can hold 1, 5,
-- or 50 items - any amount). Stock for every line is validated up front so
-- the order is all-or-nothing: if any single item is short on stock, the
-- whole order is rejected and nothing is inserted.
-- Demonstrates: sequence use, FOR UPDATE row locking, PL/SQL collection
-- (nested table) iteration, custom exceptions, RAISE_APPLICATION_ERROR,
-- NO_DATA_FOUND handling.
-- =============================================================================
-- 1. Drop the dependent nested table type first
DROP TYPE order_item_list;

-- 2. Drop the base object type second
DROP TYPE order_item_type;

-- Object type for a single order line (item_id + quantity)
CREATE OR REPLACE TYPE order_item_type AS OBJECT (
    item_id  VARCHAR2(10),
    quantity NUMBER(6)
);
/
/*
An object type in Oracle is a user-defined type that groups related attributes together into a single structure.
In this procedure, order_item_type groups the item_id and quantity of each order item into one object.
An object type is preferred over a PL/SQL RECORD because the object type can be defined at the database level and used with a nested table type as a procedure parameter.
This allows multiple order items to be passed into proc_place_order conveniently using order_item_list, making it suitable for orders containing any number of item lines.
Table is a collection of objects. In our case, it is a collection of order_item_type objects.

*/

-- Create a custom ADT(object type)'table' (collection) of order_item_type
CREATE OR REPLACE TYPE order_item_list 
AS TABLE OF order_item_type;
/

CREATE OR REPLACE PROCEDURE proc_place_order (
    p_member_id        IN  member.member_id%TYPE,
    p_staff_id         IN  staff.staff_id%TYPE,
    p_branch_id        IN  branch.branch_id%TYPE,
    p_order_type       IN  orders.order_type%TYPE,
    p_items            IN  order_item_list,
    p_voucher_applied  IN  NUMBER DEFAULT 0
) IS
    v_order_id           orders.order_id%TYPE;
    v_stock              branch_stock.stock_quantity%TYPE;
    v_total_after_discount NUMBER(10,2);
    v_point_id           point_history.point_redemption_id%TYPE;

    e_insufficient_stock EXCEPTION;
    e_empty_order        EXCEPTION;

BEGIN
    IF p_items IS NULL OR p_items.COUNT = 0 THEN
        RAISE e_empty_order;
    END IF;

    -- Validate stock before inserting anything
    FOR i IN 1 .. p_items.COUNT LOOP
        SELECT stock_quantity INTO v_stock
        FROM   branch_stock
        WHERE  branch_id = p_branch_id AND item_id = p_items(i).item_id
        FOR UPDATE;

        IF v_stock < p_items(i).quantity THEN
            RAISE e_insufficient_stock;
        END IF;
    END LOOP;

    SELECT NVL(MAX(order_id), 0) + 1 INTO v_order_id FROM orders;

    INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
    VALUES (v_order_id, p_member_id, p_staff_id, p_branch_id, SYSDATE, p_order_type);

    -- Delegate item insertion and per-item calculation to the dedicated procedure
    sp_create_order_items(
        p_order_id    => v_order_id,
        p_order_items => p_items,
        p_use_voucher => p_voucher_applied
    );

    DBMS_OUTPUT.PUT_LINE('Order ' || v_order_id || ' placed with ' || p_items.COUNT ||
                          ' item line(s).');

EXCEPTION
    WHEN e_empty_order THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20006, 'Order must contain at least one item.');
    WHEN e_insufficient_stock THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001,
            'Insufficient stock for one or more items at branch ' || p_branch_id || '.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/