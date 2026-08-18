SET SERVEROUTPUT ON
SET PAGESIZE 200
SET LINESIZE 140
SET FEEDBACK OFF
SET VERIFY OFF

DELETE FROM order_item WHERE Order_ID = 100401;

COLUMN item_id FORMAT A10 HEADING 'Item ID'
COLUMN item_name FORMAT A30 HEADING 'Item Name'
COLUMN unit_price FORMAT 9990.00 HEADING 'Unit Price'
COLUMN order_id FORMAT 999999 HEADING 'Order ID'
COLUMN quantity FORMAT 9990 HEADING 'Qty'

PROMPT ==========================================================
PROMPT ITEM DETAILS BEFORE ORDER
PROMPT ==========================================================
SELECT item_id,
       item_name,
       unit_price
FROM item
WHERE item_id IN ('BA001', 'COF001');


PROMPT ==========================================================
PROMPT CREATE ORDER ITEMS
PROMPT ==========================================================
BEGIN
    sp_create_order_items(
        p_order_id => 100401,
        p_order_items => order_item_list(
            order_item_type('BA001', 2),
            order_item_type('COF001', 3)
        ),
        p_use_voucher =>0
    );
END;
/

PROMPT ==========================================================
PROMPT ORDER ITEM RECORDS AFTER INSERT
PROMPT ==========================================================
SELECT order_id,
       item_id,
       quantity,
       unit_price
FROM order_item
WHERE order_id = 100401
  AND item_id IN ('BA001', 'COF001');
