SET SERVEROUTPUT ON
SET PAGESIZE 200
SET LINESIZE 140
SET FEEDBACK OFF
SET VERIFY OFF

COLUMN item_id FORMAT A10 HEADING 'Item ID'
COLUMN item_name FORMAT A30 HEADING 'Item Name'
COLUMN unit_price FORMAT 9990.00 HEADING 'Unit Price'
COLUMN promotion_id FORMAT 999999 HEADING 'Promotion ID'
COLUMN discount_type FORMAT A20 HEADING 'Discount Type'
COLUMN discount_value FORMAT 9990.00 HEADING 'Discount Value'

DELETE FROM promotion_details WHERE promotion_id IN (5028, 5029, 5030);

PROMPT ============================================================
PROMPT ITEM PRICE
PROMPT ============================================================

SELECT
    item_id,
    item_name,
    unit_price
FROM item
WHERE item_id = 'BA001';


PROMPT ============================================================
PROMPT TEST 1: VALID AMOUNT DISCOUNT
PROMPT ============================================================

INSERT INTO promotion_details (
    promotion_id,
    item_id,
    discount_type,
    discount_value
)
VALUES (
    5028,
    'BA001',
    'Amount',
    5
);

PROMPT
PROMPT Result: Promotion should be inserted successfully.


PROMPT ============================================================
PROMPT TEST 2: DISCOUNT HIGHER THAN UNIT PRICE
PROMPT ============================================================

INSERT INTO promotion_details (
    promotion_id,
    item_id,
    discount_type,
    discount_value
)
VALUES (
    5029,
    'BA001',
    'Amount',
    10
);

PROMPT
PROMPT Result: Should be rejected by trigger.


PROMPT ============================================================
PROMPT TEST 3: VALID PERCENTAGE DISCOUNT
PROMPT ============================================================

INSERT INTO promotion_details (
    promotion_id,
    item_id,
    discount_type,
    discount_value
)
VALUES (
    5030,
    'BA001',
    'Percentage',
    50
);

PROMPT
PROMPT Result: Percentage discount should be inserted successfully.


PROMPT ============================================================
PROMPT PROMOTION DETAILS AFTER TEST
PROMPT ============================================================

SELECT
    promotion_id,
    item_id,
    discount_type,
    discount_value
FROM promotion_details
WHERE promotion_id IN (5028, 5029, 5030)
ORDER BY promotion_id;


SET FEEDBACK ON