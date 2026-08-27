-- ============================================================================
-- Master Test Procedure for Proc 2: proc_place_order
-- Usage:
--   EXEC test_order;     -- Show menu options
--   EXEC test_order(0);  -- Run all tests
--   EXEC test_order(1);  -- Run Test 1 only
-- ============================================================================

SET SERVEROUTPUT ON;
SET DEFINE OFF;

-- Insert a permanent 1% test voucher for TEST 1 (only if it doesn't exist yet)
BEGIN
    INSERT INTO voucher (voucher_id, voucher_type, voucher_value, description, exp_date)
    VALUES ('V-TEST-01', 'Percentage', 1, 'Test Voucher 1% Discount', SYSDATE + 365);
    COMMIT;
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN NULL; -- Already exists, skip
END;
/

CREATE OR REPLACE PROCEDURE test_order (
    p_test_case IN NUMBER DEFAULT 0 -- 99 means print menu
) AS
    -- Real DB IDs resolved once at procedure start
    v_member_id  member.member_id%TYPE;
    v_staff_id   staff.staff_id%TYPE;
    v_branch_id  branch.branch_id%TYPE;
    v_item1      item.item_id%TYPE := 'BA001';  -- has active promo (Summer Sale 10% off)
    v_item2      item.item_id%TYPE := 'COF001'; -- has active promo (Summer Sale RM5 off)
    v_promo_item item.item_id%TYPE := 'BA001';  -- item covered by Summer Sale promo

    v_error_msg VARCHAR2(4000);

BEGIN
    -- Resolve real IDs from DB
    SELECT MIN(member_id) INTO v_member_id FROM member;
    SELECT MIN(branch_id) INTO v_branch_id FROM branch;
    SELECT MIN(staff_id)  INTO v_staff_id  FROM staff WHERE branch_id = v_branch_id;

    -- Commit any pending transactions before starting tests
    COMMIT;

    IF p_test_case = 99 THEN
        DBMS_OUTPUT.PUT_LINE('============================================================================');
        DBMS_OUTPUT.PUT_LINE('Test Suite Options for proc_place_order');
        DBMS_OUTPUT.PUT_LINE('============================================================================');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_order(0);  -- Run All Tests');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_order(1);  -- TEST 1: Normal order (2 items, member, promo, voucher)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_order(2);  -- TEST 2: Guest order (no member, 1 item)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_order(3);  -- TEST 3: Insufficient stock (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_order(4);  -- TEST 4: Empty order items (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_order(5);  -- TEST 5: Invalid item / Missing stock row (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_order(6);  -- TEST 6: Guest to use voucher (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_order(7);  -- TEST 7: Expired voucher (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_order(8);  -- TEST 8: Voucher already redeemed (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_order(9);  -- TEST 9: Guest Delivery order (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_order(10); -- TEST 10: Guest Self Pickup order (should fail)');
        DBMS_OUTPUT.PUT_LINE('  EXEC test_order(11); -- TEST 11: VIP member order (verify 10% discount applied)');
        DBMS_OUTPUT.PUT_LINE('============================================================================');
        RETURN;
    END IF;

    DBMS_OUTPUT.PUT_LINE('============================================================================');
    DBMS_OUTPUT.PUT_LINE('Starting Test Suite for proc_place_order');
    DBMS_OUTPUT.PUT_LINE('  Using member_id=' || v_member_id || '  staff_id=' || v_staff_id || '  branch_id=' || v_branch_id);
    DBMS_OUTPUT.PUT_LINE('============================================================================');

    -- ============================================================================
    -- TEST 1: Normal Order (real member, Summer Sale promo on BA001/COF001, V-TEST-01 voucher)
    -- ============================================================================
    IF p_test_case IN (0, 1) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 1: Normal order (2 items, member, Summer Sale promo, 1% voucher) ===');

        BEGIN
            proc_place_order(
                p_member_id  => v_member_id,
                p_staff_id   => v_staff_id,
                p_branch_id  => v_branch_id,
                p_order_type => 'In Store',
                p_items      => order_item_list(
                                    order_item_type('BA001',   1),
                                    order_item_type('COF001',  1)
                                ),
                p_voucher_id => 'V-TEST-01'
            );
            DBMS_OUTPUT.PUT_LINE('Test 1 Passed: Procedure executed successfully.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 1 Failed: Unexpected error - ' || SQLERRM);
        END;
    END IF;

    -- ============================================================================
    -- TEST 2: Guest Order Placement
    -- ============================================================================
    IF p_test_case IN (0, 2) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 2: Guest order (no member, 1 item) ===');

        BEGIN
            proc_place_order(
                p_member_id  => NULL,
                p_staff_id   => v_staff_id,
                p_branch_id  => v_branch_id,
                p_order_type => 'In Store',
                p_items      => order_item_list(order_item_type('BA001', 1))
            );
            DBMS_OUTPUT.PUT_LINE('Test 2 Passed: Procedure executed successfully for guest.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 2 Failed: Unexpected error - ' || SQLERRM);
        END;
    END IF;

    -- ============================================================================
    -- TEST 3: Insufficient Stock Failure
    -- Temporarily sets stock to 0 for BA001 at this branch, then restores
    -- ============================================================================
    IF p_test_case IN (0, 3) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 3: Insufficient stock (should fail) ===');

        DECLARE
            v_orig_stock branch_stock.stock_quantity%TYPE;
        BEGIN
            -- Save and zero out stock
            SELECT stock_quantity INTO v_orig_stock
            FROM   branch_stock
            WHERE  branch_id = v_branch_id AND item_id = 'BA001';

            UPDATE branch_stock SET stock_quantity = 0
            WHERE  branch_id = v_branch_id AND item_id = 'BA001';
            COMMIT;

            BEGIN
                proc_place_order(
                    p_member_id  => v_member_id,
                    p_staff_id   => v_staff_id,
                    p_branch_id  => v_branch_id,
                    p_order_type => 'In Store',
                    p_items      => order_item_list(order_item_type('BA001', 999))
                );
                DBMS_OUTPUT.PUT_LINE('Test 3 Failed: Should have raised insufficient stock error.');
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('Test 3 Passed with expected error: ' || SQLERRM);
            END;

            -- Restore stock
            UPDATE branch_stock SET stock_quantity = v_orig_stock
            WHERE  branch_id = v_branch_id AND item_id = 'BA001';
            COMMIT;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('Test 3 Skipped: BA001 has no stock row at branch ' || v_branch_id || '.');
        END;
    END IF;

    -- ============================================================================
    -- TEST 4: Empty Order Failure
    -- ============================================================================
    IF p_test_case IN (0, 4) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 4: Empty order items (should fail) ===');

        BEGIN
            proc_place_order(
                p_member_id  => v_member_id,
                p_staff_id   => v_staff_id,
                p_branch_id  => v_branch_id,
                p_order_type => 'In Store',
                p_items      => order_item_list()
            );
            DBMS_OUTPUT.PUT_LINE('Test 4 Failed: Should have raised empty order error.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 4 Passed with expected error: ' || SQLERRM);
        END;
    END IF;

    -- ============================================================================
    -- TEST 5: Invalid Item Failure
    -- ============================================================================
    IF p_test_case IN (0, 5) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 5: Invalid item / Missing stock row (should fail) ===');

        BEGIN
            proc_place_order(
                p_member_id  => v_member_id,
                p_staff_id   => v_staff_id,
                p_branch_id  => v_branch_id,
                p_order_type => 'Delivery',
                p_items      => order_item_list(order_item_type('NOTEXIST', 1))
            );
            DBMS_OUTPUT.PUT_LINE('Test 5 Failed: Should have raised invalid item error.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 5 Passed with expected error: ' || SQLERRM);
        END;
    END IF;

    -- ============================================================================
    -- TEST 6: Guest Voucher Failure
    -- Uses V-TEST-06 (inserted permanently, no cleanup)
    -- ============================================================================
    IF p_test_case IN (0, 6) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 6: Guest attempts to use voucher (should fail) ===');

        BEGIN
            INSERT INTO voucher (voucher_id, voucher_type, voucher_value, description, exp_date)
            VALUES ('V-TEST-06', 'Amount', 5.00, 'Test Voucher (Guest test)', SYSDATE + 30);
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;

        BEGIN
            proc_place_order(
                p_member_id  => NULL,
                p_staff_id   => v_staff_id,
                p_branch_id  => v_branch_id,
                p_order_type => 'In Store',
                p_items      => order_item_list(order_item_type('BA001', 1)),
                p_voucher_id => 'V-TEST-06'
            );
            DBMS_OUTPUT.PUT_LINE('Test 6 Failed: Should have raised member required error.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 6 Passed with expected error: ' || SQLERRM);
        END;
    END IF;

    -- ============================================================================
    -- TEST 7: Expired Voucher Failure
    -- Uses V-TEST-07 (inserted permanently as expired)
    -- ============================================================================
    IF p_test_case IN (0, 7) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 7: Expired voucher (should fail) ===');

        BEGIN
            INSERT INTO voucher (voucher_id, voucher_type, voucher_value, description, exp_date)
            VALUES ('V-TEST-07', 'Amount', 5.00, 'Test Voucher (Expired)', SYSDATE - 1);
        EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
        END;

        BEGIN
            proc_place_order(
                p_member_id  => v_member_id,
                p_staff_id   => v_staff_id,
                p_branch_id  => v_branch_id,
                p_order_type => 'In Store',
                p_items      => order_item_list(order_item_type('BA001', 1)),
                p_voucher_id => 'V-TEST-07'
            );
            DBMS_OUTPUT.PUT_LINE('Test 7 Failed: Should have raised expired voucher error.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 7 Passed with expected error: ' || SQLERRM);
        END;
    END IF;

    -- ============================================================================
    -- TEST 8: Voucher Already Redeemed Failure
    -- Uses V-TEST-08. Creates a real past order for this member + redemption record.
    -- The past order is kept permanently (real data approach).
    -- ============================================================================
    IF p_test_case IN (0, 8) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 8: Voucher already redeemed (should fail) ===');

        DECLARE
            v_past_order_id orders.order_id%TYPE;
        BEGIN
            -- Insert V-TEST-08 voucher (permanent)
            BEGIN
                INSERT INTO voucher (voucher_id, voucher_type, voucher_value, description, exp_date)
                VALUES ('V-TEST-08', 'Amount', 5.00, 'Test Voucher (Already Redeemed)', SYSDATE + 30);
            EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
            END;

            -- Check if a past redemption already exists for this member + voucher
            SELECT COUNT(*) INTO v_past_order_id
            FROM   redemption r
            JOIN   orders o ON r.order_id = o.order_id
            WHERE  r.voucher_id = 'V-TEST-08'
            AND    o.member_id = v_member_id;

            IF v_past_order_id = 0 THEN
                -- Create a real past order to simulate prior redemption
                SELECT seq_order_id.NEXTVAL INTO v_past_order_id FROM dual;
                INSERT INTO orders (order_id, member_id, staff_id, branch_id, order_date, order_type)
                VALUES (v_past_order_id, v_member_id, v_staff_id, v_branch_id, SYSDATE - 2, 'In Store');
                INSERT INTO redemption (redemption_id, voucher_id, order_id, redeemed_date)
                VALUES (seq_redemption_id.NEXTVAL, 'V-TEST-08', v_past_order_id, SYSDATE - 2);
                COMMIT;
                DBMS_OUTPUT.PUT_LINE('  (Setup: created past order ' || v_past_order_id || ' with V-TEST-08 redemption)');
            ELSE
                DBMS_OUTPUT.PUT_LINE('  (Setup: prior redemption already exists, reusing)');
            END IF;

            BEGIN
                proc_place_order(
                    p_member_id  => v_member_id,
                    p_staff_id   => v_staff_id,
                    p_branch_id  => v_branch_id,
                    p_order_type => 'In Store',
                    p_items      => order_item_list(order_item_type('BA001', 1)),
                    p_voucher_id => 'V-TEST-08'
                );
                DBMS_OUTPUT.PUT_LINE('Test 8 Failed: Should have raised voucher redeemed error.');
            EXCEPTION
                WHEN OTHERS THEN
                    DBMS_OUTPUT.PUT_LINE('Test 8 Passed with expected error: ' || SQLERRM);
            END;
        END;
    END IF;

    -- ============================================================================
    -- TEST 9: Guest Delivery Failure (Guest restricted to In Store only)
    -- ============================================================================
    IF p_test_case IN (0, 9) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 9: Guest attempts Delivery order (should fail) ===');

        BEGIN
            proc_place_order(
                p_member_id  => NULL,
                p_staff_id   => v_staff_id,
                p_branch_id  => v_branch_id,
                p_order_type => 'Delivery',
                p_items      => order_item_list(order_item_type('BA001', 1))
            );
            DBMS_OUTPUT.PUT_LINE('Test 9 Failed: Should have raised guest in-store only error.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 9 Passed with expected error: ' || SQLERRM);
        END;
    END IF;

    -- ============================================================================
    -- TEST 10: Guest Self Pickup Failure (Guest restricted to In Store only)
    -- ============================================================================
    IF p_test_case IN (0, 10) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 10: Guest attempts Self Pickup order (should fail) ===');

        BEGIN
            proc_place_order(
                p_member_id  => NULL,
                p_staff_id   => v_staff_id,
                p_branch_id  => v_branch_id,
                p_order_type => 'Self Pickup',
                p_items      => order_item_list(order_item_type('BA001', 1))
            );
            DBMS_OUTPUT.PUT_LINE('Test 10 Failed: Should have raised guest in-store only error.');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Test 10 Passed with expected error: ' || SQLERRM);
        END;
    END IF;

    -- ============================================================================
    -- TEST 11: VIP Member Order (verify 10% discount applied)
    -- Finds a real active VIP member, places order for BA001, checks price.
    -- Expected: unit_price in order_item = original_price * 0.9
    -- ============================================================================
    IF p_test_case IN (0, 11) THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== TEST 11: VIP member order (10% VIP discount should apply) ===');

        DECLARE
            v_vip_member_id  member.member_id%TYPE;
            v_original_price item.unit_price%TYPE;
            v_recorded_price order_item.unit_price%TYPE;
            v_new_order_id   orders.order_id%TYPE;
            v_expected_price NUMBER(10,2);
        BEGIN
            -- Find a member with an active VIP renewal
            BEGIN
                SELECT member_id INTO v_vip_member_id
                FROM   vip_renewal
                WHERE  expiry_date >= TRUNC(SYSDATE)
                  AND  ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    DBMS_OUTPUT.PUT_LINE('Test 11 Skipped: No active VIP member found in vip_renewal.');
                    v_vip_member_id := NULL;
            END;

            IF v_vip_member_id IS NOT NULL THEN
                -- Get original price of BA001
                SELECT unit_price INTO v_original_price
                FROM   item
                WHERE  item_id = 'BA001';

                v_expected_price := ROUND(v_original_price * 0.9, 2);

                DBMS_OUTPUT.PUT_LINE('  VIP member_id     : ' || v_vip_member_id);
                DBMS_OUTPUT.PUT_LINE('  BA001 original    : RM' || v_original_price);
                DBMS_OUTPUT.PUT_LINE('  Expected (10% off): RM' || v_expected_price);

                BEGIN
                    proc_place_order(
                        p_member_id  => v_vip_member_id,
                        p_staff_id   => v_staff_id,
                        p_branch_id  => v_branch_id,
                        p_order_type => 'In Store',
                        p_items      => order_item_list(order_item_type('BA001', 1))
                    );

                    -- Find the order just created
                    SELECT MAX(o.order_id) INTO v_new_order_id
                    FROM   orders o
                    WHERE  o.member_id = v_vip_member_id
                      AND  o.branch_id = v_branch_id;

                    -- Check actual recorded price in order_item
                    SELECT unit_price INTO v_recorded_price
                    FROM   order_item
                    WHERE  order_id = v_new_order_id
                      AND  item_id  = 'BA001';

                    DBMS_OUTPUT.PUT_LINE('  Actual price saved: RM' || v_recorded_price);

                    IF v_recorded_price <= v_expected_price THEN
                        DBMS_OUTPUT.PUT_LINE('Test 11 Passed: VIP 10% discount applied correctly.');
                    ELSE
                        DBMS_OUTPUT.PUT_LINE('Test 11 Failed: Expected RM' || v_expected_price ||
                                             ' but got RM' || v_recorded_price ||
                                             '. Discount not applied.');
                    END IF;

                EXCEPTION
                    WHEN OTHERS THEN
                        DBMS_OUTPUT.PUT_LINE('Test 11 Failed: Unexpected error - ' || SQLERRM);
                END;
            END IF;
        END;
    END IF;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '============================================================================');
    DBMS_OUTPUT.PUT_LINE('All specified tests completed.');
    DBMS_OUTPUT.PUT_LINE('============================================================================');
END;
/
