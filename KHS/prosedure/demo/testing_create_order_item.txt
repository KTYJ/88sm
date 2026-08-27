SET SERVEROUTPUT ON

SET PAGESIZE 200
SET LINESIZE 140
SET FEEDBACK on
SET VERIFY OFF

COLUMN item_id FORMAT A10 HEADING 'Item ID'
COLUMN item_name FORMAT A30 HEADING 'Item Name'
COLUMN unit_price FORMAT 9990.00 HEADING 'Original Price'

COLUMN order_id FORMAT 999999 HEADING 'Order ID'
COLUMN quantity FORMAT 9990 HEADING 'Qty'
COLUMN final_price FORMAT 9990.00 HEADING 'Final Price'
COLUMN line_total FORMAT 9990.00 HEADING 'Line Total'

COLUMN member_id FORMAT 99999 HEADING 'Member ID'
COLUMN amount FORMAT 9999990 HEADING 'Points'
COLUMN transaction_type FORMAT A15 HEADING 'Type'
COLUMN redemption_date FORMAT A20 HEADING 'Date'


PROMPT ======================================================================================================================================
PROMPT 1. ITEM DETAILS BEFORE ORDER
PROMPT ==========================================================

SELECT item_id,
       item_name,
       unit_price
FROM item
WHERE item_id IN ('BA001', 'COF001');


PROMPT ==========================================================
PROMPT 2. ACTIVE PROMOTIONS
PROMPT ==========================================================

SELECT pd.promotion_id,
       pd.item_id,
       pd.discount_type,
       pd.discount_value
FROM promotion_details pd
JOIN promotion p
    ON pd.promotion_id = p.promotion_id
WHERE pd.item_id IN ('BA001', 'COF001')
  AND SYSDATE BETWEEN p.start_date AND p.end_date;


PROMPT ==========================================================
PROMPT 3. MEMBER OF ORDER
PROMPT ==========================================================

SELECT order_id,
       member_id
FROM orders
WHERE order_id = 100402;


PROMPT ==========================================================
PROMPT 4. CREATE ORDER ITEMS - NO VOUCHER
PROMPT ==========================================================

BEGIN

    sp_create_order_items(
        p_order_id => 100402,

        p_order_items => order_item_list(
            order_item_type('BA001', 2),
            order_item_type('COF001', 3)
        ),

        p_use_voucher => 0
    );

END;
/


PROMPT ==========================================================
PROMPT 5. ORDER ITEMS AFTER INSERT
PROMPT ==========================================================

SELECT order_id,
       item_id,
       quantity,
       unit_price AS final_price,
       quantity * unit_price AS line_total
FROM order_item
WHERE order_id = 100402
  AND item_id IN ('BA001', 'COF001')
ORDER BY item_id;


PROMPT ==========================================================
PROMPT 6. POINT HISTORY AFTER ORDER
PROMPT ==========================================================

SELECT ph.point_redemption_id,
       ph.order_id,
       ph.amount,
       ph.transaction_type,
       ph.redemption_date
FROM point_history ph
WHERE ph.order_id = 100402
ORDER BY ph.redemption_date DESC;