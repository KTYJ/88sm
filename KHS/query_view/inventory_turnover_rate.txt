CREATE OR REPLACE VIEW previous_month_sales_view AS
SELECT
    oi.item_id,
    SUM(oi.quantity) AS quantity_sold
FROM order_item oi
JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -1)
  AND o.order_date < TRUNC(SYSDATE, 'MM')
GROUP BY oi.item_id;

CREATE OR REPLACE VIEW weighted_avg_cost_view AS
SELECT
    item_id,
    SUM(quantity * unit_cost) / NULLIF(SUM(quantity), 0)
        AS weighted_avg_cost
FROM procurement
GROUP BY item_id;


CREATE OR REPLACE VIEW current_stock_view AS
SELECT
    item_id,
    SUM(stock_quantity) AS current_stock
FROM branch_stock
GROUP BY item_id;

CREATE OR REPLACE VIEW inventory_turnover_rate_view AS
SELECT
    i.item_id,
    i.item_name,
    i.category,
    NVL(s.quantity_sold, 0) AS quantity_sold,
    NVL(s.quantity_sold, 0) * NVL(pc.weighted_avg_cost, 0) AS total_cogs,
    NVL(bs.current_stock, 0) AS current_stock,
    NVL(bs.current_stock, 0) * NVL(pc.weighted_avg_cost, 0) AS inventory_value,
    CASE
        WHEN NVL(bs.current_stock, 0) = 0
             OR NVL(pc.weighted_avg_cost, 0) = 0
        THEN 0
        ELSE NVL(s.quantity_sold, 0) * NVL(pc.weighted_avg_cost, 0) /
             (NVL(bs.current_stock, 0) * NVL(pc.weighted_avg_cost, 0))
    END AS turnover_ratio
FROM item i
LEFT JOIN previous_month_sales_view s
    ON i.item_id = s.item_id
LEFT JOIN weighted_avg_cost_view pc
    ON i.item_id = pc.item_id
LEFT JOIN current_stock_view bs
    ON i.item_id = bs.item_id;

-- ================================================================
-- FORMATTING
-- ===============================================================

SET PAGESIZE 100
SET LINESIZE 95
SET FEEDBACK on

-- =========================================================
-- TITLE
-- =========================================================

TTITLE CENTER 'INVENTORY TURNOVER ANALYSIS' SKIP 1 -
       CENTER 'BY CATEGORY - PREVIOUS MONTH' SKIP 2


-- =========================================================
-- COLUMN FORMATTING
-- =========================================================

COLUMN category FORMAT A20 HEADING 'Category'
COLUMN quantity_sold FORMAT 999,990 HEADING 'Qty Sold'
COLUMN total_cogs FORMAT 999,990.00 HEADING 'COGS (RM)'
COLUMN current_stock FORMAT 999,990 HEADING 'Current Stock'
COLUMN inventory_value FORMAT 999,990.00 HEADING 'Inventory Value (RM)'
COLUMN turnover_ratio FORMAT 990.00 HEADING 'Turnover Ratio'


-- =========================================================
-- DISPLAY
-- =========================================================

SELECT
    category,
    SUM(quantity_sold) AS quantity_sold,
    SUM(total_cogs) AS total_cogs,
    SUM(current_stock) AS current_stock,
    SUM(inventory_value) AS inventory_value,
    CASE
        WHEN SUM(inventory_value) = 0
        THEN 0
        ELSE SUM(total_cogs) / SUM(inventory_value)
    END AS turnover_ratio
FROM inventory_turnover_rate_view
WHERE category IN (
    'Frozen',
    'Groceries',
    'Dairy',
    'Bakery',
    'Canned Food',
    'Snacks'
)
GROUP BY category
HAVING SUM(quantity_sold) > 200
ORDER BY turnover_ratio DESC;


-- =========================================================
-- CLEAN UP
-- =========================================================

TTITLE OFF
SET FEEDBACK ON