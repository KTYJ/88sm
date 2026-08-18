-- ============================================================================
-- Master Test Procedure for Proc 1: proc_pickup
-- Usage: 
--   EXEC test_confirm_pickup;    -- Show menu options
--   EXEC test_confirm_pickup(0); -- Run all tests
--   EXEC test_confirm_pickup(1); -- Run Test 1 only
-- ============================================================================

SET SERVEROUTPUT ON;
SET DEFINE OFF;

CREATE OR REPLACE PROCEDURE test_confirm_pickup (
    p_test_case IN NUMBER DEFAULT 99 -- 99 means print menu
) AS
    v_status VARCHAR2(50);
    v_time   VARCHAR2(50);
    
    e_invalid_status   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_invalid_status, -20638);
    
    e_wrong_order_type EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_wrong_order_type, -20639);
    
    e_not_found        EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_not_found, -20641);
    
    e_pickup_expired   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_pickup_expired, -20640);
    
    PROCEDURE cleanup_test_data IS
    BEGIN
        DELETE FROM self_pickup      WHERE order_id IN (9901, 9902, 9903, 9904);
        DELETE FROM delivery         WHERE order_id IN (9901, 9902, 9903, 9904);
        DELETE FROM orders           WHERE order_id IN (9901, 9902, 9903, 9904);
        DELETE FROM staff            WHERE staff_id = 999;
        DELETE FROM member           WHERE member_id = 999;
        DELETE FROM branch           WHERE branch_id = 999;
        COMMIT;
    END cleanup_test_data;
    
    PROCEDURE setup_base_data IS
    BEGIN
        INSERT INTO branch (branch_id, branch_name, address)
        VALUES (999, '88SpeedMart Test Branch', '999 Test Avenue, KL');
        
        INSERT INTO member (member_id, name, ic, email, address, date_of_birth, expiry_date, points_balance)
        VALUES (999, 'Test Tan', '950101-14-9999', 'test.tan@example.com', 'No. 999 Test Street',
                TO_DATE('1995-01-01','YYYY-MM-DD'), TO_DATE('2028-01-01','YYYY-MM-DD'), 100);
        
        INSERT INTO staff (staff_id, branch_id, staff_name, position, contact_no)
        VALUES (999, 999, 'Sample Sam', 'Cashier', '012-99999999');
        COMMIT;
    END setup_base_data;

BEGIN
    IF p_test_case = 99 THEN
        DBMS_OUTPUT.PUT_LINE('============================================================================');
        DBMS_OUTPUT.PUT_LINE('Test Suite Options for proc_pickup');
        DBMS_OUTPUT.PUT_LINE('============================================================================');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_confirm_pickup(0);  -- Run All Tests');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_confirm_pickup(1);  -- TEST 1: Flexible status update (Preparing -> Ready -> Rescheduled)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_confirm_pickup(2);  -- TEST 2: Valid Pickup Completion (Status -> Completed with timestamp)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_confirm_pickup(3);  -- TEST 3: Expired Pickup Window on Completion (marks Expired)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_confirm_pickup(4);  -- TEST 4: Invalid Status Value (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_confirm_pickup(5);  -- TEST 5: Wrong Order Type (Delivery/In Store) (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_confirm_pickup(6);  -- TEST 6: Invalid / Non-existent Order ID (should fail)');
        DBMS_OUTPUT.PUT_LINE('============================================================================');
        RETURN;
    END IF;

    DBMS_OUTPUT.PUT_LINE('============================================================================');
    DBMS_OUTPUT.PUT_LINE('Starting Test Suite for proc_pickup');
    DBMS_OUTPUT.PUT_LINE('============================================================================');

    -- ============================================================================
    -- TEST 1: Flexible Status Modification (Preparing -> Ready -> Rescheduled)
    -- ============================================================================
    IF p_test_case IN (0, 1) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 1: Flexible Status Modification (Order 9901) ===');
        cleanup_test_data();
        setup_base_data();
        
        INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
        VALUES (9901, 999, 999, 999, SYSDATE, 'Self Pickup');
        
        INSERT INTO self_pickup (pickup_id, order_id, pickup_datetime, pickup_status, pickup_exp_date)
        VALUES (9901, 9901, NULL, 'Preparing', SYSTIMESTAMP + INTERVAL '3' DAY);
        COMMIT;

        BEGIN
            -- Update to Ready (sets expiry to +3 days)
            proc_pickup(9901, 'Ready');
            
            -- Update to Rescheduled with custom date (+5 days)
            proc_pickup(9901, 'Rescheduled', SYSTIMESTAMP + INTERVAL '5' DAY);
            
            -- DBMS_OUTPUT.PUT_LINE('Test 1 Passed: Flexible statuses applied successfully.');
            
            -- Verify
            SELECT pickup_status, 
                   NVL(TO_CHAR(pickup_exp_date, 'YYYY-MM-DD HH24:MI:SS'), 'NULL')
            INTO v_status, v_time
            FROM self_pickup WHERE order_id = 9901;
            DBMS_OUTPUT.PUT_LINE('--> Verify Order 9901 Status: ' || v_status || 
                                 ', Expiry Date: ' || v_time);
        EXCEPTION
            WHEN OTHERS THEN
                -- DBMS_OUTPUT.PUT_LINE('Test 1 Failed: Unexpected error - ' || SQLERRM);
                NULL;
        END;
        cleanup_test_data();
    END IF;

    -- ============================================================================
    -- TEST 2: Valid Pickup Completion (Status -> Completed)
    -- ============================================================================
    IF p_test_case IN (0, 2) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 2: Valid Pickup Completion (Order 9901) ===');
        cleanup_test_data();
        setup_base_data();
        
        INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
        VALUES (9901, 999, 999, 999, SYSDATE, 'Self Pickup');
        
        INSERT INTO self_pickup (pickup_id, order_id, pickup_datetime, pickup_status, pickup_exp_date)
        VALUES (9901, 9901, NULL, 'Ready', SYSTIMESTAMP + INTERVAL '3' DAY);
        COMMIT;

        BEGIN
            proc_pickup(9901, 'Completed');
            -- DBMS_OUTPUT.PUT_LINE('Test 2 Passed: Pickup marked as Completed.');
            
            -- Verify
            SELECT pickup_status, TO_CHAR(pickup_datetime, 'YYYY-MM-DD HH24:MI:SS') 
            INTO v_status, v_time
            FROM self_pickup WHERE order_id = 9901;
            DBMS_OUTPUT.PUT_LINE('--> Verify Order 9901 Status: ' || v_status || ', Time: ' || v_time);
        EXCEPTION
            WHEN OTHERS THEN
                -- DBMS_OUTPUT.PUT_LINE('Test 2 Failed: Unexpected error - ' || SQLERRM);
                NULL;
        END;
        cleanup_test_data();
    END IF;

    -- ============================================================================
    -- TEST 3: Expired Self Pickup on Completion
    -- ============================================================================
    IF p_test_case IN (0, 3) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 3: Expired Self Pickup on Completion (Order 9903) ===');
        cleanup_test_data();
        setup_base_data();
        
        INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
        VALUES (9903, 999, 999, 999, SYSDATE, 'Self Pickup');
        
        -- Expired 1 day ago
        INSERT INTO self_pickup (pickup_id, order_id, pickup_datetime, pickup_status, pickup_exp_date)
        VALUES (9903, 9903, NULL, 'Ready', SYSTIMESTAMP - INTERVAL '1' DAY);
        COMMIT;

        BEGIN
            proc_pickup(9903, 'Completed');
        EXCEPTION
            WHEN e_pickup_expired THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
                -- Verify status was set to Expired in DB
                SELECT pickup_status, TO_CHAR(pickup_exp_date, 'YYYY-MM-DD HH24:MI:SS')
                INTO v_status, v_time
                FROM self_pickup WHERE order_id = 9903;
                DBMS_OUTPUT.PUT_LINE('--> Verify Order 9903 Status: ' || v_status || ', Exp Date: ' || v_time);
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('--> Caught Unexpected Error: ' || SQLERRM);
        END;
        cleanup_test_data();
    END IF;

    -- ============================================================================
    -- TEST 4: Invalid Status Value
    -- ============================================================================
    IF p_test_case IN (0, 4) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 4: Invalid Status Value (Order 9901) ===');
        cleanup_test_data();
        setup_base_data();
        
        INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
        VALUES (9901, 999, 999, 999, SYSDATE, 'Self Pickup');
        
        INSERT INTO self_pickup (pickup_id, order_id, pickup_datetime, pickup_status, pickup_exp_date)
        VALUES (9901, 9901, NULL, 'Preparing', SYSTIMESTAMP + INTERVAL '3' DAY);
        COMMIT;

        BEGIN
            proc_pickup(9901, 'Shipped'); -- Invalid status for pickup
        EXCEPTION
            WHEN e_invalid_status THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('--> Caught Unexpected Error: ' || SQLERRM);
        END;
        cleanup_test_data();
    END IF;

    -- ============================================================================
    -- TEST 5: Wrong Order Type (Delivery or In Store)
    -- ============================================================================
    IF p_test_case IN (0, 5) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 5: Wrong Order Type ''In Store'' (Order 9904) ===');
        cleanup_test_data();
        setup_base_data();
        
        INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
        VALUES (9904, 999, 999, 999, SYSDATE, 'In Store');
        COMMIT;

        BEGIN
            proc_pickup(9904, 'Completed');
        EXCEPTION
            WHEN e_wrong_order_type THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('--> Caught Unexpected Error: ' || SQLERRM);
        END;
        cleanup_test_data();
    END IF;

    -- ============================================================================
    -- TEST 6: Non-existent Order ID
    -- ============================================================================
    IF p_test_case IN (0, 6) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 6: Non-existent Order ID (Order 99999) ===');
        cleanup_test_data();
        setup_base_data();

        BEGIN
            proc_pickup(99999, 'Completed');
        EXCEPTION
            WHEN e_not_found THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('--> Caught Unexpected Error: ' || SQLERRM);
        END;
        cleanup_test_data();
    END IF;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '============================================================================');
    DBMS_OUTPUT.PUT_LINE('All specified tests completed.');
    DBMS_OUTPUT.PUT_LINE('============================================================================');
END;
/