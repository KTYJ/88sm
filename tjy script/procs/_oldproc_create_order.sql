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
    p_member_id  IN  member.member_id%TYPE,
    p_staff_id   IN  staff.staff_id%TYPE, 
    p_branch_id  IN  branch.branch_id%TYPE,
    p_order_type IN  orders.order_type%TYPE,
    p_items      IN  order_item_list,      --the custom ADT, any number of (item_id, quantity) lines
    p_voucher_id IN  voucher.voucher_id%TYPE DEFAULT NULL  -- optional voucher
) IS
    v_order_id           orders.order_id%TYPE;
    v_stock              branch_stock.stock_quantity%TYPE;
    v_base_price         item.unit_price%TYPE;
    v_final_price        NUMBER(8,2);
    v_order_total        NUMBER := 0;
    v_point_id           point_history.point_redemption_id%TYPE;
    v_pickup_id          self_pickup.pickup_id%TYPE;

    -- Promotion rebate variables
    v_promo_discount_type  promotion_details.discount_type%TYPE;
    v_promo_discount_value promotion_details.discount_value%TYPE;

    -- Voucher variables (fetched here for discount calc; validation delegated to sp_redeem_voucher)
    v_voucher_type       voucher.voucher_type%TYPE;
    v_voucher_value      voucher.voucher_value%TYPE;
    v_voucher_discount   NUMBER := 0;

    e_insufficient_stock EXCEPTION;
    e_empty_order        EXCEPTION;
    e_member_required    EXCEPTION;
    
BEGIN
    IF p_items IS NULL OR p_items.COUNT = 0 THEN
        RAISE e_empty_order;
    END IF;

    -- =========================================================================
    -- Voucher pre-fetch (type + value needed for discount calc later)
    -- Full validation (expiry, one-use) delegated to sp_redeem_voucher
    -- =========================================================================
    IF p_voucher_id IS NOT NULL THEN
        -- Voucher redemption requires a member
        IF p_member_id IS NULL THEN
            RAISE e_member_required;
        END IF;

        -- Fetch voucher type + value for discount calculation
        -- (NO_DATA_FOUND if voucher does not exist)
        SELECT voucher_type, voucher_value
        INTO   v_voucher_type, v_voucher_value
        FROM   voucher
        WHERE  voucher_id = p_voucher_id;
    END IF;

    -- =========================================================================
    -- Pass 1: validate and lock stock for every line before inserting anything
    -- =========================================================================
    FOR i IN 1 .. p_items.COUNT LOOP
        SELECT stock_quantity INTO v_stock
        FROM   branch_stock
        WHERE  branch_id = p_branch_id AND item_id = p_items(i).item_id
        FOR UPDATE;
 
        IF v_stock < p_items(i).quantity THEN
            RAISE e_insufficient_stock;
        END IF;
    END LOOP;
 
    -- Auto-generate new order_id without sequence
    SELECT NVL(MAX(order_id), 0) + 1 INTO v_order_id FROM orders;
 
    INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
    VALUES (v_order_id, p_member_id, p_staff_id, p_branch_id, SYSDATE, p_order_type);
    
    -- Insert pickup record after orders insert if Self Pickup
    IF p_order_type = 'Self Pickup' THEN
        SELECT NVL(MAX(pickup_id), 0) + 1 INTO v_pickup_id FROM self_pickup;

        INSERT INTO self_pickup (
            pickup_id, 
            order_id, 
            pickup_datetime, 
            pickup_status, 
            pickup_exp_date
        ) VALUES (
            v_pickup_id,
            v_order_id, 
            NULL,                              -- not picked up yet
            'Preparing',                       -- default initial status
            NULL                               -- expiry date set when status becomes Ready
        );
    END IF;

    -- =========================================================================
    -- Pass 2: insert order_item rows with promotion rebate applied per item
    -- (trg_stock_deduct fires per row)
    -- =========================================================================
    FOR i IN 1 .. p_items.COUNT LOOP
        -- Get base price
        SELECT unit_price INTO v_base_price
        FROM   item
        WHERE  item_id = p_items(i).item_id;

        v_final_price := v_base_price;

        -- Check for active promotion on this item at order date
        BEGIN
            SELECT pd.discount_type, pd.discount_value
            INTO   v_promo_discount_type, v_promo_discount_value
            FROM   promotion_details pd
            JOIN   promotion p ON p.promotion_id = pd.promotion_id
            WHERE  pd.item_id       = p_items(i).item_id
            AND    p.status         = 'Active'
            AND    SYSDATE BETWEEN p.start_date AND p.end_date
            AND    ROWNUM = 1;  -- take first match if multiple promotions

            -- Apply promotion rebate
            IF v_promo_discount_type = 'Percentage' THEN
                v_final_price := v_base_price * (1 - v_promo_discount_value / 100);
            ELSIF v_promo_discount_type = 'Amount' THEN
                v_final_price := v_base_price - v_promo_discount_value;
            END IF;

            -- Floor at 0 (price cannot go negative)
            IF v_final_price < 0 THEN
                v_final_price := 0;
            END IF;

            DBMS_OUTPUT.PUT_LINE('  Promotion applied on item ' || p_items(i).item_id ||
                ': ' || v_promo_discount_value ||
                CASE v_promo_discount_type WHEN 'Percentage' THEN '%' ELSE ' RM' END ||
                ' off (RM' || TO_CHAR(v_base_price,'999.99') || ' -> RM' || TO_CHAR(v_final_price,'999.99') || ')');

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;  -- no active promotion for this item, use base price
        END;

        INSERT INTO order_item (order_id, item_id, quantity, unit_price)
        VALUES (v_order_id, p_items(i).item_id, p_items(i).quantity, v_final_price);

        v_order_total := v_order_total + (v_final_price * p_items(i).quantity);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('  Subtotal after promotion rebates: RM' || TO_CHAR(v_order_total, '9,999.99'));

    -- =========================================================================
    -- Apply voucher: delegate validation + redemption insert to sp_redeem_voucher,
    -- then calculate and apply discount on total here.
    -- NOTE: sp_redeem_voucher issues its own COMMIT.
    -- =========================================================================
    IF p_voucher_id IS NOT NULL THEN
        -- sp_redeem_voucher validates expiry, member existence, order ownership,
        -- one-time-use rule, and inserts the redemption record.
        sp_redeem_voucher(p_voucher_id, v_order_id, p_member_id);

        -- Calculate discount (voucher_type + value fetched earlier)
        IF v_voucher_type = 'Percentage' THEN
            v_voucher_discount := v_order_total * (v_voucher_value / 100);
        ELSIF v_voucher_type = 'Amount' THEN
            v_voucher_discount := v_voucher_value;
        END IF;

        -- Discount cannot exceed order total
        IF v_voucher_discount > v_order_total THEN
            v_voucher_discount := v_order_total;
        END IF;

        v_order_total := v_order_total - v_voucher_discount;

        DBMS_OUTPUT.PUT_LINE('  Voucher ' || p_voucher_id || ' applied: -RM' ||
            TO_CHAR(v_voucher_discount, '9,999.99') || ' | Final total: RM' ||
            TO_CHAR(v_order_total, '9,999.99'));
    END IF;

    -- =========================================================================
    -- Award points (on final total after all discounts)
    -- =========================================================================
    IF p_member_id IS NOT NULL AND TRUNC(v_order_total) > 0 THEN
        -- Auto-generate new point_redemption_id without sequence
        SELECT NVL(MAX(point_redemption_id), 0) + 1 INTO v_point_id FROM point_history;

        -- trg_points_balance (Task 6) fires here and updates member.points_balance
        INSERT INTO point_history (point_redemption_id, member_id, amount, transaction_type, redemption_date)
        VALUES (v_point_id, p_member_id, TRUNC(v_order_total), 'Earned', SYSDATE);
    END IF;
 
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Order ' || v_order_id || ' placed with ' || p_items.COUNT ||
                          ' item line(s). Total: RM' || TO_CHAR(v_order_total, '9,999.99'));
 
EXCEPTION
    WHEN e_empty_order THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20006, 'Order must contain at least one item.');
    WHEN e_member_required THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20009, 'A member ID is required to redeem a voucher.');
    WHEN e_insufficient_stock THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001,
            'Insufficient stock for one or more items at branch ' || p_branch_id || '.');
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20002,
            'Invalid item/branch/voucher - no matching record found.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/
 