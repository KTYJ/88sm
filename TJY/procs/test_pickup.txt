-- ============================================================================
-- Master Test Procedure for Proc 1: proc_pickup
-- Usage:
--   EXEC test_pickup;    -- Show menu options
--   EXEC test_pickup(0); -- Run all tests
--   EXEC test_pickup(1); -- Run Test 1 only
-- ============================================================================
SET SERVEROUTPUT ON;
SET DEFINE OFF;

CREATE OR REPLACE PROCEDURE test_pickup (
    p_test_case IN NUMBER DEFAULT 0 -- 99 means print menu
) AS
    -- Real DB IDs resolved once at procedure start
    v_member_id  member.member_id%TYPE;
    v_staff_id   staff.staff_id%TYPE;
    v_branch_id  branch.branch_id%TYPE;

    v_status     VARCHAR2(50);
    v_time       VARCHAR2(50);
    v_order_id   orders.order_id%TYPE;
    v_pickup_id  self_pickup.pickup_id%TYPE;

    e_invalid_status   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_invalid_status, -20638);

    e_wrong_order_type EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_wrong_order_type, -20639);

    e_not_found        EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_not_found, -20641);

    e_pickup_expired   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_pickup_expired, -20640);

BEGIN
    -- Resolve real IDs from DB
    SELECT MIN(member_id) INTO v_member_id FROM member;
    SELECT MIN(branch_id) INTO v_branch_id FROM branch;
    SELECT MIN(staff_id)  INTO v_staff_id  FROM staff WHERE branch_id = v_branch_id;

    -- Commit any pending work before tests
    COMMIT;

    IF p_test_case = 99 THEN
        DBMS_OUTPUT.PUT_LINE('============================================================================');
        DBMS_OUTPUT.PUT_LINE('Test Suite Options for proc_pickup');
        DBMS_OUTPUT.PUT_LINE('============================================================================');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_pickup(0);  -- Run All Tests');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_pickup(1);  -- TEST 1: Flexible status update (Preparing -> Ready -> Rescheduled)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_pickup(2);  -- TEST 2: Valid Pickup Completion (Status -> Completed with timestamp)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_pickup(3);  -- TEST 3: Expired Pickup Window on Completion (marks Expired)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_pickup(4);  -- TEST 4: Invalid Status Value (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_pickup(5);  -- TEST 5: Wrong Order Type (Delivery/In Store) (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_pickup(6);  -- TEST 6: Invalid / Non-existent Order ID (should fail)');
        DBMS_OUTPUT.PUT_LINE('============================================================================');
        RETURN;
    END IF;

    DBMS_OUTPUT.PUT_LINE('============================================================================');
    DBMS_OUTPUT.PUT_LINE('Starting Test Suite for proc_pickup');
    DBMS_OUTPUT.PUT_LINE('  Using member_id=' || v_member_id || '  staff_id=' || v_staff_id || '  branch_id=' || v_branch_id);
    DBMS_OUTPUT.PUT_LINE('============================================================================');

    -- ============================================================================
    -- TEST 1: Flexible Status Modification (Preparing -> Ready -> Rescheduled)
    -- ============================================================================
    IF p_test_case IN (0, 1) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 1: Flexible Status Modification ===');

        -- Create a real Self Pickup order
        SELECT seq_order_id.NEXTVAL  INTO v_order_id  FROM dual;
        SELECT seq_pickup_id.NEXTVAL INTO v_pickup_id FROM dual;

        INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
        VALUES (v_order_id, v_member_id, v_staff_id, v_branch_id, SYSDATE, 'Self Pickup');

        INSERT INTO self_pickup (pickup_id, order_id, pickup_datetime, pickup_status, pickup_exp_date)
        VALUES (v_pickup_id, v_order_id, NULL, 'Preparing', SYSTIMESTAMP + INTERVAL '3' DAY);
        COMMIT;

        DBMS_OUTPUT.PUT_LINE('  (Setup: created order ' || v_order_id || ', pickup ' || v_pickup_id || ')');

        BEGIN
            proc_pickup(v_order_id, 'Ready');
            proc_pickup(v_order_id, 'Rescheduled', SYSTIMESTAMP + INTERVAL '5' DAY);

            SELECT pickup_status,
                   NVL(TO_CHAR(pickup_exp_date, 'YYYY-MM-DD HH24:MI:SS'), 'NULL')
            INTO v_status, v_time
            FROM self_pickup WHERE order_id = v_order_id;

            DBMS_OUTPUT.PUT_LINE('--> Verify Order ' || v_order_id || ' Status: ' || v_status ||
                                 ', Expiry Date: ' || v_time);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 1 Failed: ' || SQLERRM);
        END;
    END IF;

    -- ============================================================================
    -- TEST 2: Valid Pickup Completion (Status -> Completed with timestamp)
    -- ============================================================================
    IF p_test_case IN (0, 2) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 2: Valid Pickup Completion ===');

        SELECT seq_order_id.NEXTVAL  INTO v_order_id  FROM dual;
        SELECT seq_pickup_id.NEXTVAL INTO v_pickup_id FROM dual;

        INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
        VALUES (v_order_id, v_member_id, v_staff_id, v_branch_id, SYSDATE, 'Self Pickup');

        INSERT INTO self_pickup (pickup_id, order_id, pickup_datetime, pickup_status, pickup_exp_date)
        VALUES (v_pickup_id, v_order_id, NULL, 'Ready', SYSTIMESTAMP + INTERVAL '3' DAY);
        COMMIT;

        DBMS_OUTPUT.PUT_LINE('  (Setup: created order ' || v_order_id || ', pickup ' || v_pickup_id || ')');

        BEGIN
            proc_pickup(v_order_id, 'Completed');

            SELECT pickup_status, TO_CHAR(pickup_datetime, 'YYYY-MM-DD HH24:MI:SS')
            INTO v_status, v_time
            FROM self_pickup WHERE order_id = v_order_id;

            DBMS_OUTPUT.PUT_LINE('--> Verify Order ' || v_order_id || ' Status: ' || v_status || ', Time: ' || v_time);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 2 Failed: ' || SQLERRM);
        END;
    END IF;

    -- ============================================================================
    -- TEST 3: Expired Pickup Window on Completion (marks Expired)
    -- ============================================================================
    IF p_test_case IN (0, 3) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 3: Expired Pickup Window on Completion ===');

        SELECT seq_order_id.NEXTVAL  INTO v_order_id  FROM dual;
        SELECT seq_pickup_id.NEXTVAL INTO v_pickup_id FROM dual;

        INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
        VALUES (v_order_id, v_member_id, v_staff_id, v_branch_id, SYSDATE, 'Self Pickup');

        -- Expiry set 1 day in the past
        INSERT INTO self_pickup (pickup_id, order_id, pickup_datetime, pickup_status, pickup_exp_date)
        VALUES (v_pickup_id, v_order_id, NULL, 'Ready', SYSTIMESTAMP - INTERVAL '1' DAY);
        COMMIT;

        DBMS_OUTPUT.PUT_LINE('  (Setup: created expired order ' || v_order_id || ', pickup ' || v_pickup_id || ')');

        BEGIN
            proc_pickup(v_order_id, 'Completed');
        EXCEPTION
            WHEN e_pickup_expired THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
                SELECT pickup_status, TO_CHAR(pickup_exp_date, 'YYYY-MM-DD HH24:MI:SS')
                INTO v_status, v_time
                FROM self_pickup WHERE order_id = v_order_id;
                DBMS_OUTPUT.PUT_LINE('--> Verify Order ' || v_order_id || ' Status: ' || v_status || ', Exp Date: ' || v_time);
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('--> Caught Unexpected Error: ' || SQLERRM);
        END;
    END IF;

    -- ============================================================================
    -- TEST 4: Invalid Status Value (should fail)
    -- ============================================================================
    IF p_test_case IN (0, 4) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 4: Invalid Status Value ===');

        SELECT seq_order_id.NEXTVAL  INTO v_order_id  FROM dual;
        SELECT seq_pickup_id.NEXTVAL INTO v_pickup_id FROM dual;

        INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
        VALUES (v_order_id, v_member_id, v_staff_id, v_branch_id, SYSDATE, 'Self Pickup');

        INSERT INTO self_pickup (pickup_id, order_id, pickup_datetime, pickup_status, pickup_exp_date)
        VALUES (v_pickup_id, v_order_id, NULL, 'Preparing', SYSTIMESTAMP + INTERVAL '3' DAY);
        COMMIT;

        DBMS_OUTPUT.PUT_LINE('  (Setup: created order ' || v_order_id || ', pickup ' || v_pickup_id || ')');

        BEGIN
            proc_pickup(v_order_id, 'Shipped'); -- Invalid status
        EXCEPTION
            WHEN e_invalid_status THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('--> Caught Unexpected Error: ' || SQLERRM);
        END;
    END IF;

    -- ============================================================================
    -- TEST 5: Wrong Order Type - In Store (should fail)
    -- ============================================================================
    IF p_test_case IN (0, 5) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 5: Wrong Order Type ''In Store'' ===');

        SELECT seq_order_id.NEXTVAL INTO v_order_id FROM dual;

        INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
        VALUES (v_order_id, v_member_id, v_staff_id, v_branch_id, SYSDATE, 'In Store');
        COMMIT;

        DBMS_OUTPUT.PUT_LINE('  (Setup: created In Store order ' || v_order_id || ')');

        BEGIN
            proc_pickup(v_order_id, 'Completed');
        EXCEPTION
            WHEN e_wrong_order_type THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('--> Caught Unexpected Error: ' || SQLERRM);
        END;
    END IF;

    -- ============================================================================
    -- TEST 6: Non-existent Order ID (should fail)
    -- ============================================================================
    IF p_test_case IN (0, 6) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 6: Non-existent Order ID (Order 99999999) ===');

        BEGIN
            proc_pickup(99999999, 'Completed');
        EXCEPTION
            WHEN e_not_found THEN
                DBMS_OUTPUT.PUT_LINE(SQLERRM);
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('--> Caught Unexpected Error: ' || SQLERRM);
        END;
    END IF;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '============================================================================');
    DBMS_OUTPUT.PUT_LINE('All specified tests completed.');
    DBMS_OUTPUT.PUT_LINE('============================================================================');
END;
/