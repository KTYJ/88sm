SET SERVEROUTPUT ON;

------------------------------------------------------------
-- TEST 1: Successful promotion
-- Valid promotion with 2 items
------------------------------------------------------------

DECLARE
    v_promotion_id promotion.promotion_id%TYPE;
BEGIN

    create_promotion(
        p_promotion_name    => 'Summer Sale',
        p_description       => 'Summer promotion with discounts',
        p_start_date        => DATE '2026-07-21',
        p_end_date          => DATE '2026-10-31',

        p_promotion_details => promotion_detail_list(
            promotion_detail_type(
                'BA001',
                'Percentage',
                10
            ),
            promotion_detail_type(
                'COF001',
                'Amount',
                5
            )
        ),

        p_promotion_id      => v_promotion_id
    );

    DBMS_OUTPUT.PUT_LINE(
        'Generated Promotion ID: ' || v_promotion_id
    );

END;
/