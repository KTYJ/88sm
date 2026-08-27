-- ==========================================
-- 6. QUERIES
-- ==========================================

SET LINESIZE 180
SET PAGESIZE 1000
SET FEEDBACK ON
SET VERIFY OFF
SET DEFINE ON
SET NULL '-'

-- ------------------------------------------
-- Helper views for this file's reports.
-- Dropped again at the end of the script.
-- ------------------------------------------
-- branch_stock_summary_view
-- Description: Provides a lightweight branch-level inventory summary.
-- It keeps one row per branch and reports total units, estimated retail
-- value, and the number of items below the low-stock threshold. It does
-- not replace Query 6.1, which remains the detailed item-level report.
CREATE OR REPLACE VIEW branch_stock_summary_view AS
SELECT
    bs.branch_id,
    SUM(bs.stock_quantity) AS total_stock,
    SUM(bs.stock_quantity * i.unit_price) AS total_stock_value,
    SUM(CASE WHEN bs.stock_quantity < 50 THEN 1 ELSE 0 END) AS low_stock_items,
    LISTAGG(
        CASE WHEN bs.stock_quantity < 50 THEN bs.item_id END,
        ', '
    ) WITHIN GROUP (ORDER BY bs.item_id) AS low_stock_item_ids
FROM branch_stock bs
JOIN item i ON i.item_id = bs.item_id
GROUP BY branch_id
HAVING SUM(bs.stock_quantity) > 0;

-- item_pair_frequency_view
-- Description: Finds pairs of different items purchased in the same
-- order and counts the distinct orders containing each pair. The
-- item_id comparison stores each pair once, while joins to item return
-- both item names. Pairs occurring in fewer than two orders are removed;
-- Query 6.2 applies the stricter top-basket threshold of five orders.
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
COLUMN branch_name       HEADING 'Branch Name'   FORMAT A24 TRUNCATE
COLUMN item_id           HEADING 'Item ID'       FORMAT A10
COLUMN item_name         HEADING 'Item Name'     FORMAT A28 TRUNCATE
COLUMN category          HEADING 'Category'      FORMAT A15 TRUNCATE
COLUMN unit_price        HEADING 'Unit Price'    FORMAT 999,999.99
COLUMN stock_quantity    HEADING 'On Hand'       FORMAT 999,999
COLUMN stock_value       HEADING 'Stock Value'   FORMAT 999,999,999.99
COLUMN last_restock_date HEADING 'Last Restock'  FORMAT A11
COLUMN stock_status      HEADING 'Status'        FORMAT A10

ACCEPT branch_id NUMBER PROMPT 'Enter branch ID for the stock report (e.g. 1001): '

PROMPT
PROMPT ===================================================================
PROMPT QUERY 6.1: STOCK REPORT FOR BRANCH &&branch_id
PROMPT ===================================================================

SELECT
    bs.branch_id,
    b.branch_name,
    i.item_id,
    i.item_name,
    i.category,
    i.unit_price,
    bs.stock_quantity,
    bs.stock_quantity * i.unit_price AS stock_value,
    TO_CHAR(bs.last_restock_date, 'DD-MON-YYYY') AS last_restock_date,
    CASE WHEN bs.stock_quantity < 50 THEN 'LOW STOCK' ELSE 'OK' END AS stock_status
FROM branch_stock bs
JOIN item i ON i.item_id = bs.item_id
JOIN branch b ON b.branch_id = bs.branch_id
WHERE bs.branch_id = &&branch_id
ORDER BY CASE WHEN bs.stock_quantity < 50 THEN 0 ELSE 1 END,
         bs.stock_quantity ASC,
         i.item_id;

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
COLUMN pair_rank       HEADING 'Rank'             FORMAT 999
COLUMN item_a          HEADING 'Item A|ID'         FORMAT A10
COLUMN item_a_name     HEADING 'Item A|Name'       FORMAT A24 TRUNCATE
COLUMN item_b          HEADING 'Item B|ID'         FORMAT A10
COLUMN item_b_name     HEADING 'Item B|Name'       FORMAT A24 TRUNCATE
COLUMN times_together  HEADING 'Orders|Together'   FORMAT 999,999
COLUMN item_a_stock    HEADING 'Item A|Stock'      FORMAT 999,999
COLUMN item_b_stock    HEADING 'Item B|Stock'      FORMAT 999,999
SET WRAP OFF
SET COLSEP ' | '
SET UNDERLINE '-'
SET RECSEP EACH
SET RECSEPCHAR '-'

PROMPT
PROMPT ===================================================================
PROMPT QUERY 6.2: PAIR FREQUENCY BASKET (TOP 20 ITEM PAIRS)
PROMPT Cross-checked against company-wide stock so marketing only
PROMPT bundles pairs both items can currently support.
PROMPT ===================================================================
PROMPT -------------------------------------------------------------------

SELECT
    ROWNUM AS pair_rank,
    item_a,
    item_a_name,
    item_b,
    item_b_name,
    times_together,
    item_a_stock,
    item_b_stock
FROM (
    SELECT
        v.item_a,
        SUBSTR(v.item_a_name, 1, 24) AS item_a_name,
        v.item_b,
        SUBSTR(v.item_b_name, 1, 24) AS item_b_name,
        v.times_together,
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

PROMPT -------------------------------------------------------------------

CLEAR COLUMNS


-- ------------------------------------------
-- 6.3 Total stock summary per branch
-- Aggregates on-hand stock quantity across all items
-- for each branch, using branch_stock_summary_view.
-- ------------------------------------------
COLUMN branch_id         HEADING 'Branch|ID'       FORMAT 9999
COLUMN branch_name       HEADING 'Branch Name'     FORMAT A26 TRUNCATE
COLUMN total_stock       HEADING 'Total|Units'     FORMAT 999,999,999
COLUMN total_stock_value HEADING 'Stock Value|(RM)' FORMAT 999,999,999.99
COLUMN low_stock_items   HEADING 'Low-Stock|Items' FORMAT 999,999
COLUMN low_stock_item_ids HEADING 'Low-Stock Item IDs' FORMAT A45 TRUNCATE

PROMPT
PROMPT ===================================================================
PROMPT QUERY 6.3: TOTAL STOCK SUMMARY PER BRANCH
PROMPT ===================================================================
PROMPT -------------------------------------------------------------------

SELECT
    b.branch_id,
    b.branch_name,
    sv.total_stock,
    sv.total_stock_value,
    sv.low_stock_items,
    sv.low_stock_item_ids
FROM branch b
JOIN branch_stock_summary_view sv ON sv.branch_id = b.branch_id
WHERE sv.total_stock >= 50000
ORDER BY sv.total_stock DESC;

PROMPT -------------------------------------------------------------------

CLEAR COLUMNS

