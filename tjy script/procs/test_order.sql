-- ============================================================================
-- Master Test Procedure for Proc 2: proc_place_order
-- Usage: 
--   EXEC test_create_order;    -- Show menu options
--   EXEC test_create_order(0); -- Run all tests
--   EXEC test_create_order(1); -- Run Test 1 only
-- ============================================================================

SET SERVEROUTPUT ON;
SET DEFINE OFF;
-- WHENEVER OSERROR EXIT FAILURE;

CREATE OR REPLACE PROCEDURE test_create_order (
    p_test_case IN NUMBER DEFAULT 0 -- 99 means print menu
) AS
    v_count NUMBER;
    v_error_msg VARCHAR2(4000);
    
    PROCEDURE cleanup_test_data IS
    BEGIN
        DELETE FROM redemption     WHERE voucher_id = 'V9001' OR order_id = 9001;
        DELETE FROM voucher        WHERE voucher_id = 'V9001';
        DELETE FROM promotion_details WHERE promotion_id = 9001;
        DELETE FROM promotion      WHERE promotion_id = 9001;
        DELETE FROM point_history  WHERE member_id = 9001;
        DELETE FROM self_pickup    WHERE order_id IN (SELECT order_id FROM orders WHERE branch_id = 9001) OR order_id = 9001;
        DELETE FROM order_item     WHERE order_id IN (SELECT order_id FROM orders WHERE branch_id = 9001) OR order_id = 9001;
        DELETE FROM orders         WHERE branch_id = 9001 OR order_id = 9001;
        DELETE FROM branch_stock   WHERE branch_id = 9001 OR item_id IN ('PT001','PT002','PT003');
        DELETE FROM staff          WHERE staff_id = 9001 OR branch_id = 9001;
        DELETE FROM branch         WHERE branch_id = 9001;
        DELETE FROM member         WHERE member_id = 9001 OR ic = '900101-14-0001' OR email = 'proc2.test@example.com';
        DELETE FROM item           WHERE item_id IN ('PT001','PT002','PT003');
        COMMIT;
    END cleanup_test_data;
    
    PROCEDURE setup_base_data IS
    BEGIN
        INSERT INTO branch VALUES (9001, '88SpeedMart Proc2 Test', 'No. 9001, Test Ave, KL');
        INSERT INTO member VALUES (9001, 'Proc Test Member', '900101-14-0001', 'proc2.test@example.com',
            'No. 9001 Test St', TO_DATE('1990-01-01','YYYY-MM-DD'), TO_DATE('2029-01-01','YYYY-MM-DD'), 0);
        INSERT INTO staff  VALUES (9001, 9001, 'Proc Test Staff', 'Cashier', '012-00000001');
        INSERT INTO item VALUES ('PT001', 'Proc Test Item 1', 'Desc 1', 10.00, 'Groceries');
        INSERT INTO item VALUES ('PT002', 'Proc Test Item 2', 'Desc 2', 20.00, 'Groceries');
        INSERT INTO item VALUES ('PT003', 'Proc Test Item 3', 'Desc 3', 30.00, 'Groceries');
        INSERT INTO branch_stock VALUES (9001, 'PT001', 50, SYSDATE);
        INSERT INTO branch_stock VALUES (9001, 'PT002', 10, SYSDATE);
        COMMIT;
    END setup_base_data;

BEGIN
    IF p_test_case = 99 THEN
        DBMS_OUTPUT.PUT_LINE('============================================================================');
        DBMS_OUTPUT.PUT_LINE('Test Suite Options for proc_place_order');
        DBMS_OUTPUT.PUT_LINE('============================================================================');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_create_order(0);  -- Run All Tests');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_create_order(1);  -- TEST 1: Normal order (2 items, member, promo, voucher)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_create_order(2);  -- TEST 2: Guest order (no member, 1 item)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_create_order(3);  -- TEST 3: Insufficient stock (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_create_order(4);  -- TEST 4: Empty order items (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_create_order(5);  -- TEST 5: Invalid item / Missing stock row (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_create_order(6);  -- TEST 6: Guest attempts to use voucher (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_create_order(7);  -- TEST 7: Expired voucher (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_create_order(8);  -- TEST 8: Voucher already redeemed (should fail)');
        DBMS_OUTPUT.PUT_LINE('============================================================================');
        RETURN;
    END IF;

    DBMS_OUTPUT.PUT_LINE('============================================================================');
    DBMS_OUTPUT.PUT_LINE('Starting Test Suite for proc_place_order');
    DBMS_OUTPUT.PUT_LINE('============================================================================');

    -- ============================================================================
    -- TEST 1: Normal Order
    -- ============================================================================
    IF p_test_case IN (0, 1) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 1: Normal order (2 items, member, promo on PT001, RM5 voucher) ===');
        cleanup_test_data();
        setup_base_data();
        
        -- Active promotion: 10% off PT001
        INSERT INTO promotion (promotion_id, promotion_name, description, status, start_date, end_date)
        VALUES (9001, 'Test Promo', '10% off PT001', 'Active', SYSDATE - 1, SYSDATE + 7);
        INSERT INTO promotion_details (promotion_id, item_id, discount_type, discount_value)
        VALUES (9001, 'PT001', 'Percentage', 10);
        
        -- Valid voucher: RM 5 off
        INSERT INTO voucher (voucher_id, voucher_type, voucher_value, description, exp_date)
        VALUES ('V9001', 'Amount', 5.00, 'Test Voucher RM5', SYSDATE + 30);
        COMMIT;

        BEGIN
            proc_place_order(9001, 9001, 9001, 'In Store', order_item_list(order_item_type('PT001', 3), order_item_type('PT002', 2)), 'V9001');
            DBMS_OUTPUT.PUT_LINE('Test 1 Passed: Procedure executed successfully.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 1 Failed: Unexpected error - ' || SQLERRM);
        END;
        cleanup_test_data();
    END IF;

    -- ============================================================================
    -- TEST 2: Guest Order Placement
    -- ============================================================================
    IF p_test_case IN (0, 2) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 2: Guest order (no member, 1 item) ===');
        cleanup_test_data();
        setup_base_data();

        BEGIN
            proc_place_order(NULL, 9001, 9001, 'In Store', order_item_list(order_item_type('PT001', 1)));
            DBMS_OUTPUT.PUT_LINE('Test 2 Passed: Procedure executed successfully for guest.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 2 Failed: Unexpected error - ' || SQLERRM);
        END;
        cleanup_test_data();
    END IF;

    -- ============================================================================
    -- TEST 3: Insufficient Stock Failure
    -- ============================================================================
    IF p_test_case IN (0, 3) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 3: Insufficient stock (should fail) ===');
        cleanup_test_data();
        setup_base_data();
        
        -- Override stock to 0
        UPDATE branch_stock SET stock_quantity = 0 WHERE branch_id = 9001 AND item_id = 'PT003';
        COMMIT;

        BEGIN
            proc_place_order(9001, 9001, 9001, 'In Store', order_item_list(order_item_type('PT003', 5)));
            DBMS_OUTPUT.PUT_LINE('Test 3 Failed: Should have raised insufficient stock error.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 3 Passed with expected error: ' || SQLERRM);
        END;
        cleanup_test_data();
    END IF;

    -- ============================================================================
    -- TEST 4: Empty Order Failure
    -- ============================================================================
    IF p_test_case IN (0, 4) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 4: Empty order items (should fail) ===');
        cleanup_test_data();
        setup_base_data();

        BEGIN
            proc_place_order(9001, 9001, 9001, 'In Store', order_item_list());
            DBMS_OUTPUT.PUT_LINE('Test 4 Failed: Should have raised empty order error.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 4 Passed with expected error: ' || SQLERRM);
        END;
        cleanup_test_data();
    END IF;

    -- ============================================================================
    -- TEST 5: Invalid Item Failure
    -- ============================================================================
    IF p_test_case IN (0, 5) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 5: Invalid item / Missing stock row (should fail) ===');
        cleanup_test_data();
        setup_base_data();

        BEGIN
            proc_place_order(9001, 9001, 9001, 'Delivery', order_item_list(order_item_type('NOTEXIST', 1)));
            DBMS_OUTPUT.PUT_LINE('Test 5 Failed: Should have raised invalid item error.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 5 Passed with expected error: ' || SQLERRM);
        END;
        cleanup_test_data();
    END IF;

    -- ============================================================================
    -- TEST 6: Guest Voucher Failure
    -- ============================================================================
    IF p_test_case IN (0, 6) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 6: Guest attempts to use voucher (should fail) ===');
        cleanup_test_data();
        setup_base_data();
        
        INSERT INTO voucher (voucher_id, voucher_type, voucher_value, description, exp_date)
        VALUES ('V9001', 'Amount', 5.00, 'Test Voucher', SYSDATE + 30);
        COMMIT;

        BEGIN
            proc_place_order(NULL, 9001, 9001, 'In Store', order_item_list(order_item_type('PT001', 1)), 'V9001');
            DBMS_OUTPUT.PUT_LINE('Test 6 Failed: Should have raised member required error.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 6 Passed with expected error: ' || SQLERRM);
        END;
        cleanup_test_data();
    END IF;

    -- ============================================================================
    -- TEST 7: Expired Voucher Failure
    -- ============================================================================
    IF p_test_case IN (0, 7) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 7: Expired voucher (should fail) ===');
        cleanup_test_data();
        setup_base_data();

        INSERT INTO voucher (voucher_id, voucher_type, voucher_value, description, exp_date)
        VALUES ('V9001', 'Amount', 5.00, 'Test Voucher', SYSDATE - 1);
        COMMIT;

        BEGIN
            proc_place_order(9001, 9001, 9001, 'In Store', order_item_list(order_item_type('PT001', 1)), 'V9001');
            DBMS_OUTPUT.PUT_LINE('Test 7 Failed: Should have raised expired voucher error.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 7 Passed with expected error: ' || SQLERRM);
        END;
        cleanup_test_data();
    END IF;

    -- ============================================================================
    -- TEST 8: Voucher Already Redeemed Failure
    -- ============================================================================
    IF p_test_case IN (0, 8) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 8: Voucher already redeemed (should fail) ===');
        cleanup_test_data();
        setup_base_data();

        INSERT INTO voucher (voucher_id, voucher_type, voucher_value, description, exp_date)
        VALUES ('V9001', 'Amount', 5.00, 'Test Voucher', SYSDATE + 30);

        -- Create a dummy past order and redemption record for this member and voucher
        INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
        VALUES (9001, 9001, 9001, 9001, SYSDATE - 2, 'In Store');

        INSERT INTO redemption (redemption_id, voucher_id, order_id, redeemed_date)
        VALUES (9001, 'V9001', 9001, SYSDATE - 2);
        COMMIT;

        BEGIN
            proc_place_order(9001, 9001, 9001, 'In Store', order_item_list(order_item_type('PT001', 1)), 'V9001');
            DBMS_OUTPUT.PUT_LINE('Test 8 Failed: Should have raised voucher redeemed error.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 8 Passed with expected error: ' || SQLERRM);
        END;
        cleanup_test_data();
    END IF;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '============================================================================');
    DBMS_OUTPUT.PUT_LINE('All specified tests completed.');
    DBMS_OUTPUT.PUT_LINE('============================================================================');
END;
/

-- WHENEVER OSERROR CONTINUE;
