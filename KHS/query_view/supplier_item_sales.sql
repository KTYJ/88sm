-- ================================================================
-- SUPPLIER ITEM SALES PERFORMANCE REPORT
-- ================================================================

-- ================================================================
-- 1. CREATE VIEW
-- ================================================================

CREATE OR REPLACE VIEW supplier_item_sales_view AS
SELECT
    s.supplier_id,
    s.supplier_name,
    i.item_id,
    i.item_name,
    i.category,
    oi.order_id,
    oi.quantity,
    oi.unit_price,
    o.order_date
FROM supplier s
JOIN procurement p
    ON s.supplier_id = p.supplier_id
JOIN item i
    ON p.item_id = i.item_id
JOIN order_item oi
    ON i.item_id = oi.item_id
JOIN orders o
    ON oi.order_id = o.order_id;


-- ================================================================
-- 2. REPORT FORMATTING
-- ================================================================

SET PAGESIZE 200
SET LINESIZE 160
SET FEEDBACK on

COLUMN supplier_name   FORMAT A30        HEADING 'Supplier'
COLUMN item_name       FORMAT A25        HEADING 'Item'
COLUMN category        FORMAT A20        HEADING 'Category'
COLUMN quantity_sold   FORMAT 999,990    HEADING 'Qty Sold'
COLUMN total_sales     FORMAT 999,990.00 HEADING 'Sales (RM)'


-- ================================================================
-- 3. SUPPLIER ITEM SALES REPORT
-- ================================================================

PROMPT =================================================================
PROMPT                 SUPPLIER ITEM SALES PERFORMANCE
PROMPT =================================================================

SELECT
    supplier_name,
    category,
    SUM(quantity) AS quantity_sold,
    SUM(quantity * unit_price) AS total_sales
FROM supplier_item_sales_view
WHERE order_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -1)
  AND order_date < TRUNC(SYSDATE, 'MM')
GROUP BY
    supplier_id,
    supplier_name,
    category
HAVING SUM(quantity) > 200
ORDER BY
    supplier_name,
    quantity_sold DESC;


PROMPT =================================================================

SET FEEDBACK ON