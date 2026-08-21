-- ==========================================
-- 6. QUERIES
-- ==========================================

SET LINESIZE 180
SET PAGESIZE 1000
SET FEEDBACK ON
SET VERIFY OFF
SET NULL '-'

-- ------------------------------------------
-- Helper views for this file's reports.
-- Dropped again at the end of the script.
-- ------------------------------------------
CREATE OR REPLACE VIEW branch_stock_summary_view AS
SELECT branch_id, SUM(stock_quantity) AS total_stock
FROM branch_stock
GROUP BY branch_id
HAVING SUM(stock_quantity) > 0;

CREATE OR REPLACE VIEW item_pair_frequency_view AS
SELECT
    oi1.item_id                  AS item_a,
    ia.item_name                 AS item_a_name,
    oi2.item_id                  AS item_b,
    ib.item_name                 AS item_b_name,
    COUNT(DISTINCT oi1.order_id) AS times_together
FROM order_item oi1
JOIN order_item oi2 ON oi1.order_id = oi2.order_id AND oi1.item_id < oi2.item_id
JOIN item ia ON ia.item_id = oi1.item_id
JOIN item ib ON ib.item_id = oi2.item_id
GROUP BY oi1.item_id, ia.item_name, oi2.item_id, ib.item_name
HAVING COUNT(DISTINCT oi1.order_id) >= 2;


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


-- ------------------------------------------
-- 6.1b Stock summary by category for the same branch
-- Aggregates the item-level detail above into per-category
-- totals, flagging categories that are collectively low.
-- ------------------------------------------
COLUMN category      HEADING 'Category'      FORMAT A15 TRUNCATE
COLUMN item_count    HEADING 'Item Count'    FORMAT 9,999
COLUMN total_qty     HEADING 'Total Qty'     FORMAT 999,999
COLUMN avg_qty       HEADING 'Avg Qty'       FORMAT 9,999.99

PROMPT
PROMPT ===================================================================
PROMPT QUERY 6.1b: STOCK SUMMARY BY CATEGORY FOR BRANCH &&branch_id
PROMPT ===================================================================

SELECT
    i.category,
    COUNT(i.item_id)          AS item_count,
    SUM(bs.stock_quantity)    AS total_qty,
    ROUND(AVG(bs.stock_quantity), 2) AS avg_qty
FROM branch_stock bs
JOIN item i ON i.item_id = bs.item_id
WHERE bs.branch_id = &&branch_id
GROUP BY i.category
HAVING SUM(bs.stock_quantity) > 0
ORDER BY total_qty ASC;

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
COLUMN item_a_stock    HEADING 'Item A|Co. Stock' FORMAT 999,999
COLUMN item_b_stock    HEADING 'Item B|Co. Stock' FORMAT 999,999

PROMPT
PROMPT ===================================================================
PROMPT QUERY 6.2: PAIR FREQUENCY BASKET (TOP 20 ITEM PAIRS)
PROMPT Cross-checked against company-wide stock so marketing only
PROMPT bundles pairs both items can currently support.
PROMPT ===================================================================

SELECT *
FROM (
    SELECT
        v.item_a, v.item_a_name, v.item_b, v.item_b_name, v.times_together,
        NVL(sa.total_qty, 0) AS item_a_stock,
        NVL(sb.total_qty, 0) AS item_b_stock
    FROM item_pair_frequency_view v
    JOIN (SELECT item_id, SUM(stock_quantity) AS total_qty
          FROM branch_stock
          GROUP BY item_id) sa ON sa.item_id = v.item_a
    JOIN (SELECT item_id, SUM(stock_quantity) AS total_qty
          FROM branch_stock
          GROUP BY item_id) sb ON sb.item_id = v.item_b
    WHERE v.times_together >= 5
    ORDER BY v.times_together DESC
)
WHERE ROWNUM <= 20;

CLEAR COLUMNS


-- ------------------------------------------
-- 6.3 Total stock summary per branch
-- Aggregates on-hand stock quantity across all items
-- for each branch, using branch_stock_summary_view.
-- ------------------------------------------
COLUMN branch_id    HEADING 'Branch ID'    FORMAT 9999
COLUMN branch_name  HEADING 'Branch Name'  FORMAT A30 TRUNCATE
COLUMN total_stock  HEADING 'Total Stock'  FORMAT 999,999,999

PROMPT
PROMPT ===================================================================
PROMPT QUERY 6.3: TOTAL STOCK SUMMARY PER BRANCH
PROMPT ===================================================================

SELECT
    b.branch_id,
    b.branch_name,
    sv.total_stock
FROM branch b
JOIN branch_stock_summary_view sv ON sv.branch_id = b.branch_id
WHERE sv.total_stock >= 50000
ORDER BY sv.total_stock DESC;

CLEAR COLUMNS

DROP VIEW branch_stock_summary_view;
DROP VIEW item_pair_frequency_view;
