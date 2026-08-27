SET SERVEROUTPUT ON;

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

SET PAGESIZE 50
SET LINESIZE 150
COLUMN promotion_id    FORMAT 9999        HEADING 'Promotion ID'
COLUMN promotion_name  FORMAT A25         HEADING 'Promotion Name'
COLUMN description      FORMAT A40         HEADING 'Description'
COLUMN start_date       FORMAT A12         HEADING 'Start Date'
COLUMN end_date         FORMAT A12         HEADING 'End Date'
COLUMN item_id          FORMAT A10         HEADING 'Item ID'
COLUMN discount_type    FORMAT A15         HEADING 'Discount Type'
COLUMN discount_value   FORMAT 9990.00     HEADING 'Discount Value'

SELECT
    p.promotion_id,
    p.promotion_name,
    p.description,
    TO_CHAR(p.start_date, 'DD-MON-YYYY') AS start_date,
    TO_CHAR(p.end_date, 'DD-MON-YYYY') AS end_date,
    pd.item_id,
    pd.discount_type,
    pd.discount_value
FROM promotion p
JOIN promotion_details pd
    ON p.promotion_id = pd.promotion_id
WHERE pd.item_id IN ('BA001', 'COF001');