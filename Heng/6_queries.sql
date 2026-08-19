-- ==========================================
-- 6. QUERIES
-- ==========================================

SET LINESIZE 180
SET PAGESIZE 1000
SET FEEDBACK ON
SET VERIFY OFF
SET NULL '-'

-- ------------------------------------------
-- 6.1 Stock report for a branch
-- Current on-hand quantity for every item stocked at the
-- given branch, flagged Low Stock when below threshold.
-- Prompts once for &&branch_id and reuses it.
-- ------------------------------------------
COLUMN branch_id         HEADING 'Branch ID'     FORMAT 9999
COLUMN item_id           HEADING 'Item ID'       FORMAT A10
COLUMN item_name         HEADING 'Item Name'     FORMAT A28 TRUNCATE
COLUMN category          HEADING 'Category'      FORMAT A15 TRUNCATE
COLUMN stock_quantity    HEADING 'On Hand'       FORMAT 999,999
COLUMN last_restock_date HEADING 'Last Restock'  FORMAT A11
COLUMN stock_status      HEADING 'Status'        FORMAT A10

ACCEPT branch_id NUMBER PROMPT 'Enter branch ID for the stock report (e.g. 1001): '

PROMPT
PROMPT ===================================================================
PROMPT QUERY 6.1: STOCK REPORT FOR BRANCH &&branch_id
PROMPT ===================================================================

SELECT
    bs.branch_id,
    i.item_id,
    i.item_name,
    i.category,
    bs.stock_quantity,
    TO_CHAR(bs.last_restock_date, 'DD-MON-YYYY') AS last_restock_date,
    CASE WHEN bs.stock_quantity < 50 THEN 'LOW STOCK' ELSE 'OK' END AS stock_status
FROM branch_stock bs
JOIN item i ON i.item_id = bs.item_id
WHERE bs.branch_id = &&branch_id
ORDER BY bs.stock_quantity ASC, i.item_id;

CLEAR COLUMNS
UNDEFINE branch_id;


-- ------------------------------------------
-- 6.2 Pair frequency basket analysis
-- Identifies which pairs of items (size 2) are most
-- frequently bought together in the same order.
-- ------------------------------------------
COLUMN item_a          HEADING 'Item A'         FORMAT A10
COLUMN item_a_name     HEADING 'Item A Name'    FORMAT A22 TRUNCATE
COLUMN item_b          HEADING 'Item B'         FORMAT A10
COLUMN item_b_name     HEADING 'Item B Name'    FORMAT A22 TRUNCATE
COLUMN times_together  HEADING 'Times Bought|Together' FORMAT 999,999

PROMPT
PROMPT ===================================================================
PROMPT QUERY 6.2: PAIR FREQUENCY BASKET (TOP 20 ITEM PAIRS)
PROMPT ===================================================================

SELECT *
FROM (
    SELECT
        oi1.item_id            AS item_a,
        ia.item_name           AS item_a_name,
        oi2.item_id            AS item_b,
        ib.item_name           AS item_b_name,
        COUNT(DISTINCT oi1.order_id) AS times_together
    FROM order_item oi1
    JOIN order_item oi2 ON oi1.order_id = oi2.order_id AND oi1.item_id < oi2.item_id
    JOIN item ia ON ia.item_id = oi1.item_id
    JOIN item ib ON ib.item_id = oi2.item_id
    GROUP BY oi1.item_id, ia.item_name, oi2.item_id, ib.item_name
    ORDER BY times_together DESC
)
WHERE ROWNUM <= 20;

CLEAR COLUMNS
