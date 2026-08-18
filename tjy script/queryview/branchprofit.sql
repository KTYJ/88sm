cl scr
-- Sequence for ranking outlet performance
DROP SEQUENCE seq_branch_rank;

CREATE SEQUENCE seq_branch_rank START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- View 1: Branch Revenue (total sales for the last 2 years)
CREATE OR REPLACE VIEW branch_revenue_view AS
SELECT 
    o.branch_id, 
    SUM(oi.quantity * oi.unit_price) AS total_revenue
FROM orders o
JOIN order_item oi 
    ON o.order_id = oi.order_id
WHERE o.order_date >= ADD_MONTHS(SYSDATE, -24)
GROUP BY o.branch_id;

-- View 2: Average Item Procurement Cost (last 2 years)
CREATE OR REPLACE VIEW avg_item_cost AS
SELECT 
    item_id, 
    AVG(unit_cost) AS avg_unit_cost
FROM procurement
WHERE procurement_date >= ADD_MONTHS(SYSDATE, -24)
GROUP BY item_id;

-- View 3: Branch Cost / COGS (last 2 years)
CREATE OR REPLACE VIEW branch_cost_view AS
SELECT 
    o.branch_id, 
    SUM(oi.quantity * aic.avg_unit_cost) AS total_cost
FROM orders o
JOIN order_item oi 
    ON o.order_id = oi.order_id
JOIN avg_item_cost aic 
    ON oi.item_id = aic.item_id
WHERE o.order_date >= ADD_MONTHS(SYSDATE, -24)
GROUP BY o.branch_id;

-- View 4: Branch Profitability (last 2 years, positive net profit)
CREATE OR REPLACE VIEW branch_profitability_view AS
SELECT
    b.branch_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    br.total_revenue,
    bc.total_cost,
    (br.total_revenue - bc.total_cost) AS net_profit,
    ROUND(br.total_revenue / COUNT(DISTINCT o.order_id), 2) AS avg_order_val
FROM branch b
JOIN orders o 
    ON b.branch_id = o.branch_id
JOIN branch_revenue_view br 
    ON o.branch_id = br.branch_id
JOIN branch_cost_view bc 
    ON o.branch_id = bc.branch_id
WHERE o.order_date >= ADD_MONTHS(SYSDATE, -24)
GROUP BY
    b.branch_name,
    br.total_revenue,
    bc.total_cost
HAVING (br.total_revenue - bc.total_cost) > 0;

-- ============================================================
-- QUERY 1: Branch Profitability Report (Last 2 Years)
-- ============================================================
SET LINESIZE 120
SET PAGESIZE 30
SET VERIFY OFF
SET UNDERLINE '='
SET DEFINE ON

COLUMN rank          FORMAT 99          HEADING ' Rank '  
COLUMN branch_loc   FORMAT A25         HEADING 'Branch Location'
COLUMN total_orders  FORMAT 9,999       HEADING 'Total Orders'
COLUMN total_revenue FORMAT 9,999,999.99 HEADING 'Total Revenue (RM)'
COLUMN total_cost    FORMAT 9,999,999.99 HEADING 'Total Cost (RM)'
COLUMN net_profit    FORMAT 9,999,999.99 HEADING 'Net Profit (RM)'
COLUMN avg_order_val FORMAT 9,999.99     HEADING 'Avg Order Value (RM)'

-- Define variables and capture values
COLUMN start_year NEW_VALUE v_start_year NOPRINT
COLUMN end_year   NEW_VALUE v_end_year   NOPRINT

-- This query populates the variables
SELECT
    TO_CHAR(ADD_MONTHS(SYSDATE, -24), 'YYYY') AS start_year,
    TO_CHAR(SYSDATE, 'YYYY') AS end_year
FROM dual;

-- TTITLE & BTITLE
TTITLE CENTER 'Branch Profitability Report' SKIP 1 -
       CENTER '&v_start_year - &v_end_year, Positive Net Profit' SKIP 1 -
       LEFT 'Page: ' FORMAT 999 SQL.PNO SKIP 1 -
       CENTER '----------------------------------------------' SKIP 3

BTITLE CENTER '----------------------------------------------' SKIP 1 -
       CENTER '*** End of Report ***' SKIP 1

SELECT 
    seq_branch_rank.NEXTVAL AS rank, 
    v.branch_loc, 
    v.total_orders, 
    v.total_revenue, 
    v.total_cost, 
    v.avg_order_val, 
    v.net_profit
FROM (
    SELECT
        TRIM(REGEXP_REPLACE(branch_name, '88 SpeedMart', '', 1, 0, 'i')) AS branch_loc, 
        total_orders, 
        total_revenue, 
        total_cost, 
        avg_order_val, 
        net_profit
    FROM branch_profitability_view
    ORDER BY net_profit DESC
) v;

TTITLE OFF
BTITLE OFF
DROP SEQUENCE seq_branch_rank;
DROP VIEW branch_profitability_view;
DROP VIEW branch_cost_view;
DROP VIEW branch_revenue_view;
DROP VIEW avg_item_cost;

CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES
SET UNDERLINE '-'
SET DEFINE OFF