CREATE OR REPLACE VIEW branch_staff_count_view AS
SELECT branch_id, COUNT(staff_id) AS staff_count
FROM staff
GROUP BY branch_id;

CREATE OR REPLACE VIEW monthly_sales_view AS
SELECT 
    b.branch_id,
    b.branch_name,
    TO_CHAR(o.order_date, 'YYYY-MM') AS month,
    SUM(oi.quantity * oi.unit_price) AS monthly_sales,
    COUNT(DISTINCT o.order_id) AS monthly_orders
FROM branch b
JOIN orders o ON b.branch_id = o.branch_id
JOIN order_item oi ON o.order_id = oi.order_id
GROUP BY b.branch_id, b.branch_name, TO_CHAR(o.order_date, 'YYYY-MM');
cl scr
ACCEPT no_mths NUMBER PROMPT 'Enter number of months for efficiency report (e.g., 12 or 24) [24]: ' DEFAULT 24

SET LINESIZE 100
SET PAGESIZE 25
SET VERIFY OFF
SET UNDERLINE '='
SET DEFINE ON

COLUMN branch_location  FORMAT A20          HEADING 'Branch Location' 
COLUMN headcount        FORMAT 9,999        HEADING 'Staff Headcount'
COLUMN total_orders     FORMAT 9,999        HEADING 'Total Orders'
COLUMN total_sales      FORMAT 9,999,999.99 HEADING 'Total Sales (RM)'
COLUMN sales_per_staff  FORMAT 9,999,999.99 HEADING 'Sales Per Staff (RM)'

COLUMN start_month NEW_VALUE v_start_month NOPRINT
COLUMN end_month   NEW_VALUE v_end_month   NOPRINT

-- for formatting
SELECT 
    TO_CHAR(ADD_MONTHS(SYSDATE, -&no_mths), 'YYYY-MM') AS start_month,
    TO_CHAR(SYSDATE, 'YYYY-MM') AS end_month
FROM dual;

TTITLE CENTER 'Branch Efficiency: Headcount vs Sales (&v_start_month to &v_end_month)' SKIP 1 -
       RIGHT 'Page: ' FORMAT 999 SQL.PNO SKIP 1 -
       CENTER '----------------------------------------------' SKIP 2

BTITLE CENTER '----------------------------------------------' SKIP 1 -
       CENTER '*** End of Report ***' SKIP 1

SELECT 
    TRIM(REGEXP_REPLACE(b.branch_name, '88 SpeedMart', '', 1, 0, 'i')) AS branch_location,
    sc.staff_count AS headcount,
    SUM(msv.monthly_orders) AS total_orders,
    SUM(msv.monthly_sales) AS total_sales,
    SUM(msv.monthly_sales) / sc.staff_count AS sales_per_staff
FROM branch b
JOIN branch_staff_count_view sc
    ON b.branch_id = sc.branch_id
JOIN monthly_sales_view msv
    ON b.branch_id = msv.branch_id
WHERE TO_DATE(msv.month, 'YYYY-MM') >= ADD_MONTHS(TRUNC(SYSDATE, 'MM'), -&no_mths)
GROUP BY 
    b.branch_name,
    sc.staff_count
HAVING SUM(msv.monthly_sales) > 1000
   AND SUM(msv.monthly_orders) >= 10 
ORDER BY sales_per_staff DESC;

TTITLE OFF
BTITLE OFF
DROP VIEW branch_staff_count_view;
DROP VIEW monthly_sales_view;

CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES
SET UNDERLINE '-'
