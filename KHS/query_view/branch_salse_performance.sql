CREATE OR REPLACE VIEW branch_sales_performance_view AS
SELECT
    b.branch_id,
    b.branch_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    NVL(SUM(oi.quantity), 0) AS quantity_sold,
    NVL(SUM(oi.quantity * oi.unit_price), 0) AS total_sales
FROM branch b
LEFT JOIN orders o
    ON b.branch_id = o.branch_id
    AND o.order_date >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -1)
    AND o.order_date < TRUNC(SYSDATE, 'MM')
LEFT JOIN order_item oi
    ON o.order_id = oi.order_id
GROUP BY
    b.branch_id,
    b.branch_name;
/

SET PAGESIZE 200
SET LINESIZE 160
SET FEEDBACK OFF

COLUMN branch_name       FORMAT A25        HEADING 'Branch'
COLUMN total_orders      FORMAT 999,990    HEADING 'Orders'
COLUMN quantity_sold     FORMAT 999,990    HEADING 'Qty Sold'
COLUMN total_sales       FORMAT 999,990.00 HEADING 'Sales (RM)'
COLUMN avg_order_value   FORMAT 999,990.00 HEADING 'Avg Order (RM)'

PROMPT ================================================================
PROMPT                    BRANCH SALES PERFORMANCE
PROMPT                    PREVIOUS MONTH
PROMPT ================================================================

SELECT
    branch_name,
    total_orders,
    quantity_sold,
    total_sales,
    CASE
        WHEN total_orders = 0
        THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_value
FROM branch_sales_performance_view
ORDER BY total_sales DESC;

SET FEEDBACK ON