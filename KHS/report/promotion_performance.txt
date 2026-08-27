SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 120
SET PAGESIZE 1000
SET FEEDBACK OFF
SET HEADING OFF
SET TAB OFF


CREATE OR REPLACE PROCEDURE sp_promotion_performance
(
    p_start_date   IN DATE,
    p_end_date     IN DATE,
    p_promotion_id IN promotion.promotion_id%TYPE DEFAULT NULL
)
IS

    /* ==========================================================
       1. PROMOTION CURSOR
       ========================================================== */

    CURSOR c_promotion
    IS
        SELECT
            promotion_id,
            promotion_name,
            status,
            start_date,
            end_date
        FROM promotion
        WHERE (p_promotion_id IS NULL
               OR promotion_id = p_promotion_id)
        ORDER BY promotion_id;


    /* ==========================================================
       2. PROMOTION ITEM CURSOR
       ========================================================== */

    CURSOR c_promotion_item
    (
        p_promotion_id promotion.promotion_id%TYPE
    )
    IS
        SELECT
            pd.item_id,
            i.item_name,
            pd.discount_type,
            pd.discount_value
        FROM promotion_details pd
        JOIN item i
            ON pd.item_id = i.item_id
        WHERE pd.promotion_id = p_promotion_id
        ORDER BY pd.item_id;


    /* ==========================================================
       3. ORDER ITEM CURSOR
       ========================================================== */

    CURSOR c_order_item
    (
        p_item_id item.item_id%TYPE
    )
    IS
        SELECT
            oi.order_id,
            oi.quantity,
            oi.unit_price
        FROM order_item oi
        JOIN orders o
            ON oi.order_id = o.order_id
        WHERE oi.item_id = p_item_id
          AND o.order_date >= p_start_date
          AND o.order_date < p_end_date + 1;


    /* ==========================================================
       VARIABLES
       ========================================================== */

    v_promotion_id     promotion.promotion_id%TYPE;
    v_promotion_name   promotion.promotion_name%TYPE;
    v_status           promotion.status%TYPE;
    v_start_date       promotion.start_date%TYPE;
    v_promo_end_date   promotion.end_date%TYPE;

    v_item_id          item.item_id%TYPE;
    v_item_name        item.item_name%TYPE;
    v_discount_type    promotion_details.discount_type%TYPE;
    v_discount_value   promotion_details.discount_value%TYPE;

    v_order_id         order_item.order_id%TYPE;
    v_quantity         order_item.quantity%TYPE;
    v_unit_price       order_item.unit_price%TYPE;

    v_quantity_sold    NUMBER := 0;
    v_sales_revenue    NUMBER(12,2) := 0;
    v_order_count      NUMBER := 0;

    v_promotion_total  NUMBER(12,2) := 0;
    v_promotion_qty    NUMBER := 0;


    /* ==========================================================
       FUNCTION 1 - CALCULATE QUANTITY SOLD
       ========================================================== */

    FUNCTION fn_calculate_quantity_sold(
        p_quantity_sold NUMBER,
        p_quantity      NUMBER
    ) RETURN NUMBER
    IS
    BEGIN
        RETURN p_quantity_sold + p_quantity;
    END fn_calculate_quantity_sold;

    /* ==========================================================
       FUNCTION 2 - CALCULATE SALES REVENUE
       ========================================================== */

    FUNCTION fn_calculate_sales_revenue(
        p_current_revenue NUMBER,
        p_quantity        NUMBER,
        p_unit_price      NUMBER
    ) RETURN NUMBER
    IS
    BEGIN
        RETURN p_current_revenue +
               (p_quantity * p_unit_price);
    END fn_calculate_sales_revenue;

    /* ==========================================================
       FUNCTION 3 - CALCULATE ORDER COUNT
       ========================================================== */

    FUNCTION fn_calculate_order_count(
        p_order_count NUMBER
    ) RETURN NUMBER
    IS
    BEGIN
        RETURN p_order_count + 1;
    END fn_calculate_order_count;

BEGIN

    /* ==========================================================
       1. VALIDATE DATE
       ========================================================== */

    IF p_start_date IS NULL
       OR p_end_date IS NULL THEN

        RAISE_APPLICATION_ERROR(
            -20020,
            'Start date and end date are required.'
        );

    END IF;


    IF p_start_date > p_end_date THEN

        RAISE_APPLICATION_ERROR(
            -20021,
            'Start date cannot be later than end date.'
        );

    END IF;


    /* ==========================================================
       2. REPORT HEADER
       ========================================================== */

    DBMS_OUTPUT.PUT_LINE(
        '==================================================================================================='
    );

    DBMS_OUTPUT.PUT_LINE(
        '                         PROMOTION PERFORMANCE REPORT'
    );

    DBMS_OUTPUT.PUT_LINE(
        '==================================================================================================='
    );

    DBMS_OUTPUT.PUT_LINE(
        'Period : ' ||
        TO_CHAR(p_start_date, 'DD-MM-YYYY') ||
        ' to ' ||
        TO_CHAR(p_end_date, 'DD-MM-YYYY')
    );

    DBMS_OUTPUT.PUT_LINE(
        '==================================================================================================='
    );


    /* ==========================================================
       3. OUTER CURSOR - PROMOTION
       ========================================================== */

    OPEN c_promotion;

    LOOP

        FETCH c_promotion
        INTO v_promotion_id,
             v_promotion_name,
             v_status,
             v_start_date,
             v_promo_end_date;

        EXIT WHEN c_promotion%NOTFOUND;


        v_promotion_qty := 0;
        v_promotion_total := 0;


        /* ======================================================
           PROMOTION INFORMATION
           ====================================================== */

        DBMS_OUTPUT.PUT_LINE('');

        DBMS_OUTPUT.PUT_LINE(
            'Promotion ID   : ' ||
            v_promotion_id
        );

        DBMS_OUTPUT.PUT_LINE(
            'Promotion Name : ' ||
            v_promotion_name
        );

        DBMS_OUTPUT.PUT_LINE(
            'Status         : ' ||
            v_status
        );

        DBMS_OUTPUT.PUT_LINE(
            '---------------------------------------------------------------------------------------------------'
        );


        /* ======================================================
           TABLE HEADER
           ====================================================== */

        DBMS_OUTPUT.PUT_LINE(
            RPAD('Item ID', 10) ||
            RPAD('Item Name', 24) ||
            RPAD('Discount Type', 20) ||
            LPAD('Discount Value', 16) ||
            LPAD('Qty Sold', 10) ||
            LPAD('Revenue (RM)', 16)
        );

        DBMS_OUTPUT.PUT_LINE(
            '---------------------------------------------------------------------------------------------------'
        );


        /* ======================================================
           4. NESTED CURSOR - PROMOTION ITEMS
           ====================================================== */

        OPEN c_promotion_item(v_promotion_id);

        LOOP

            FETCH c_promotion_item
            INTO v_item_id,
                 v_item_name,
                 v_discount_type,
                 v_discount_value;

            EXIT WHEN c_promotion_item%NOTFOUND;


            v_quantity_sold := 0;
            v_sales_revenue := 0;
            v_order_count := 0;


            /* ==================================================
               5. NESTED CURSOR - ORDER ITEMS
               ================================================== */

            OPEN c_order_item(v_item_id);

            LOOP

                FETCH c_order_item
                INTO v_order_id,
                     v_quantity,
                     v_unit_price;

                EXIT WHEN c_order_item%NOTFOUND;


                v_quantity_sold :=
                    fn_calculate_quantity_sold(
                        v_quantity_sold,
                        v_quantity
                    );


                v_sales_revenue :=
                    fn_calculate_sales_revenue(
                        v_sales_revenue,
                        v_quantity,
                        v_unit_price
                    );


                v_order_count :=
                    fn_calculate_order_count(
                        v_order_count
                    );

            END LOOP;

            CLOSE c_order_item;


            /* ==================================================
               6. PROMOTION TOTAL
               ================================================== */

            v_promotion_qty :=
                v_promotion_qty + v_quantity_sold;

            v_promotion_total :=
                v_promotion_total + v_sales_revenue;


            /* ==================================================
               7. DISPLAY ITEM RESULT
               ================================================== */

            DBMS_OUTPUT.PUT_LINE(
                RPAD(
                    TO_CHAR(v_item_id),
                    10
                ) ||

                RPAD(
                    SUBSTR(v_item_name, 1, 24),
                    24
                ) ||

                RPAD(
                    SUBSTR(v_discount_type, 1, 20),
                    20
                ) ||

                LPAD(
                    TO_CHAR(
                        v_discount_value,
                        'FM999,990.00'
                    ),
                    16
                ) ||

                LPAD(
                    TO_CHAR(
                        v_quantity_sold,
                        'FM999,990'
                    ),
                    10
                ) ||

                LPAD(
                    TO_CHAR(
                        v_sales_revenue,
                        'FM999,990.00'
                    ),
                    16
                )
            );

        END LOOP;

        CLOSE c_promotion_item;


        /* ======================================================
           8. PROMOTION SUMMARY
           ====================================================== */

        DBMS_OUTPUT.PUT_LINE(
            '---------------------------------------------------------------------------------------------------'
        );

        DBMS_OUTPUT.PUT_LINE(
            'Promotion Total Quantity : ' ||
            TO_CHAR(
                v_promotion_qty,
                'FM999,990'
            )
        );

        DBMS_OUTPUT.PUT_LINE(
            'Promotion Total Revenue : RM' ||
            TO_CHAR(
                v_promotion_total,
                'FM999,990.00'
            )
        );

    END LOOP;

    CLOSE c_promotion;


    /* ==========================================================
       9. REPORT FOOTER
       ========================================================== */

    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE(
        '==================================================================================================='
    );

    DBMS_OUTPUT.PUT_LINE(
        '                              END OF REPORT'
    );

    DBMS_OUTPUT.PUT_LINE(
        '==================================================================================================='
    );


EXCEPTION

    WHEN OTHERS THEN

        IF c_order_item%ISOPEN THEN
            CLOSE c_order_item;
        END IF;

        IF c_promotion_item%ISOPEN THEN
            CLOSE c_promotion_item;
        END IF;

        IF c_promotion%ISOPEN THEN
            CLOSE c_promotion;
        END IF;

        RAISE_APPLICATION_ERROR(
            -20022,
            'Error generating promotion performance report: ' ||
            SQLERRM
        );

END;
/