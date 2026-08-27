DROP PROCEDURE sp_create_order_items;
DROP TYPE order_item_list;
DROP TYPE order_item_type;

CREATE OR REPLACE TYPE order_item_type AS OBJECT (
    item_id   VARCHAR2(10),
    quantity  NUMBER
);
/

CREATE OR REPLACE TYPE order_item_list AS TABLE OF order_item_type;
/

CREATE OR REPLACE PROCEDURE sp_create_order_items (
    p_order_id       IN order_item.order_id%TYPE,
    p_order_items    IN order_item_list,
    p_use_voucher    IN NUMBER DEFAULT 0
)
IS
    v_original_price  item.unit_price%TYPE;
    v_final_price     NUMBER(10,2);
    v_order_total     NUMBER(10,2) := 0;
    v_member_id       orders.member_id%TYPE;

    v_discount_type   promotion_details.discount_type%TYPE;
    v_discount_value  promotion_details.discount_value%TYPE;

    e_empty_order      EXCEPTION;
    e_invalid_item     EXCEPTION;

BEGIN

    -- ==========================================
    -- 1. Validate order items
    -- ==========================================

    IF p_order_items IS NULL
       OR p_order_items.COUNT = 0 THEN

        RAISE e_empty_order;

    END IF;


    -- ==========================================
    -- 2. Process every order item
    -- ==========================================

    FOR i IN 1 .. p_order_items.COUNT
    LOOP

        -- ======================================
        -- 2.1 Get original item price
        -- ======================================

        BEGIN

            SELECT unit_price
            INTO v_original_price
            FROM item
            WHERE item_id = p_order_items(i).item_id;

        EXCEPTION

            WHEN NO_DATA_FOUND THEN
                RAISE e_invalid_item;

        END;


        -- ======================================
        -- 2.2 Start with original price
        -- ======================================

        v_final_price := v_original_price;


        -- ======================================
        -- 2.3 Check active promotion
        -- ======================================

        BEGIN

            SELECT discount_type,
                discount_value
            INTO v_discount_type,
                v_discount_value
            FROM (
                SELECT pd.discount_type,
                    pd.discount_value
                FROM promotion_details pd
                JOIN promotion p
                ON pd.promotion_id = p.promotion_id
                WHERE pd.item_id = p_order_items(i).item_id
                AND SYSDATE BETWEEN p.start_date AND p.end_date
                ORDER BY p.start_date DESC
            )
            WHERE ROWNUM = 1;


            -- ==================================
            -- 2.4 Apply promotion
            -- ==================================

            IF v_discount_type = 'Percentage' THEN

                v_final_price :=
                    v_final_price -
                    (v_final_price * v_discount_value / 100);

            ELSIF v_discount_type = 'Amount' THEN

                v_final_price :=
                    v_final_price - v_discount_value;

            END IF;


        EXCEPTION

            WHEN NO_DATA_FOUND THEN

                -- No promotion
                NULL;

        END;


        -- ======================================
        -- 3.5 Prevent negative price
        -- ======================================

        IF v_final_price < 0 THEN
            v_final_price := 0;
        END IF;


        -- ======================================
        -- 3.6 Round final price
        -- ======================================

        v_final_price := ROUND(v_final_price, 2);


        -- ======================================
        -- 3.7 Insert into ORDER_ITEM
        -- ======================================

        INSERT INTO order_item (
            order_id,
            item_id,
            quantity,
            unit_price
        )
        VALUES (
            p_order_id,
            p_order_items(i).item_id,
            p_order_items(i).quantity,
            v_final_price
        );


        v_order_total := v_order_total + (p_order_items(i).quantity * v_final_price);

        DBMS_OUTPUT.PUT_LINE(
            'Item ' ||
            p_order_items(i).item_id ||
            ' added. Final Unit Price: RM' ||
            v_final_price ||
            ' | Running total: RM' ||
            v_order_total
        );

    END LOOP;

    IF p_use_voucher IS NULL OR p_use_voucher = 0 THEN
        SELECT o.member_id
        INTO v_member_id
        FROM orders o
        WHERE o.order_id = p_order_id;

        IF v_member_id IS NOT NULL AND v_order_total > 0 THEN
            INSERT INTO point_history (
                point_redemption_id,
                order_id,
                amount,
                transaction_type,
                redemption_date
            )
            VALUES (
                seq_point_history_id.NEXTVAL,
                p_order_id,
                TRUNC(v_order_total),
                'Earned',
                SYSDATE
            );

            DBMS_OUTPUT.PUT_LINE(
                'Points earned for order ' || p_order_id ||
                ': ' || TRUNC(v_order_total)
            );
        END IF;
    ELSE
        DBMS_OUTPUT.PUT_LINE(
            'Voucher used for order ' || p_order_id ||
            '. No points earned.'
        );
    END IF;

    COMMIT;


    DBMS_OUTPUT.PUT_LINE(
        'SUCCESS: Order items created successfully.'
    );


EXCEPTION

    WHEN e_empty_order THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(
            -20001,
            'Order must contain at least one item.'
        );

    WHEN e_invalid_item THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(
            -20003,
            'Item ' ||
            p_order_items(1).item_id ||
            ' does not exist.'
        );

    WHEN OTHERS THEN

        ROLLBACK;

        DBMS_OUTPUT.PUT_LINE(
            'ERROR: ' || SQLERRM
        );

END sp_create_order_items;
/