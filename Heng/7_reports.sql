

-- ------------------------------------------
-- Box-drawing helpers shared by all reports below.
-- Standalone schema functions (not nested in a procedure) so
-- every report procedure in this file can reuse them.
-- ------------------------------------------
CREATE OR REPLACE FUNCTION fn_center_str (
    p_str   IN VARCHAR2,
    p_width IN NUMBER
) RETURN VARCHAR2 IS
    v_left NUMBER;
BEGIN
    IF p_str IS NULL THEN
        RETURN RPAD(' ', p_width, ' ');
    END IF;

    v_left := TRUNC((p_width - LENGTH(p_str)) / 2);
    IF v_left < 0 THEN
        v_left := 0;
    END IF;

    RETURN RPAD(LPAD(p_str, LENGTH(p_str) + v_left, ' '), p_width, ' ');
END fn_center_str;
/

CREATE OR REPLACE FUNCTION fn_box_row (
    p_text  IN VARCHAR2,
    p_align IN VARCHAR2 DEFAULT 'L'
) RETURN VARCHAR2 IS
    c_inner_width CONSTANT NUMBER := 96;
BEGIN
    IF p_align = 'C' THEN
        RETURN '| ' || fn_center_str(p_text, c_inner_width) || ' |';
    ELSE
        RETURN '| ' || RPAD(NVL(p_text, ' '), c_inner_width, ' ') || ' |';
    END IF;
END fn_box_row;
/

CREATE OR REPLACE FUNCTION fn_box_sep RETURN VARCHAR2 IS
BEGIN
    RETURN '+' || RPAD('-', 98, '-') || '+';
END fn_box_sep;
/


-- ------------------------------------------
-- 7.1 Item procurement comparison between suppliers (DETAIL REPORT)
-- Row-by-row listing, ranked, for every item ever procured and
-- every supplier that has supplied it - no parameters, no
-- aggregation above item level.
-- Outer cursor walks each item that has been procured;
-- inner cursor, opened per item, walks that item's suppliers
-- ranked cheapest first.
-- ------------------------------------------
CREATE OR REPLACE PROCEDURE proc_rpt_procurement_cmp AS

    CURSOR c_items IS
        SELECT DISTINCT i.item_id, i.item_name
        FROM item i
        WHERE EXISTS (SELECT 1 FROM procurement p WHERE p.item_id = i.item_id)
        ORDER BY i.item_id;

    CURSOR c_suppliers (p_item_id item.item_id%TYPE) IS
        SELECT
            s.supplier_id,
            s.supplier_name,
            COUNT(p.procurement_id)          AS times_ordered,
            SUM(p.quantity)                  AS total_quantity_supplied,
            ROUND(AVG(p.unit_cost), 2)       AS avg_unit_cost,
            SUM(p.quantity * p.unit_cost)    AS total_spent
        FROM procurement p
        JOIN supplier s ON s.supplier_id = p.supplier_id
        WHERE p.item_id = p_item_id
        GROUP BY s.supplier_id, s.supplier_name
        HAVING COUNT(p.procurement_id) >= 1
        ORDER BY avg_unit_cost;

    v_rank PLS_INTEGER;

BEGIN
    DBMS_OUTPUT.PUT_LINE(fn_box_sep);
    DBMS_OUTPUT.PUT_LINE(fn_box_row('REPORT 7.1: ITEM PROCUREMENT COMPARISON BETWEEN SUPPLIERS', 'C'));
    DBMS_OUTPUT.PUT_LINE(fn_box_row('Generated: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI'), 'C'));
    DBMS_OUTPUT.PUT_LINE(fn_box_sep);

    FOR item_rec IN c_items LOOP
        DBMS_OUTPUT.PUT_LINE(fn_box_row(' '));
        DBMS_OUTPUT.PUT_LINE(fn_box_row(' ' || item_rec.item_id || ' - ' || item_rec.item_name));
        DBMS_OUTPUT.PUT_LINE(fn_box_row(' ' || RPAD('Rank', 6) || RPAD('Supplier', 30) ||
                              RPAD('Orders', 8) || RPAD('Total Qty', 12) ||
                              RPAD('Avg Cost', 12) || 'Total Spent'));
        DBMS_OUTPUT.PUT_LINE(fn_box_row(' ' || RPAD('-', 90, '-')));

        v_rank := 0;

        FOR sup_rec IN c_suppliers(item_rec.item_id) LOOP
            v_rank := v_rank + 1;
            DBMS_OUTPUT.PUT_LINE(fn_box_row(
                ' ' ||
                RPAD(v_rank, 6) ||
                RPAD(sup_rec.supplier_id || ' ' || SUBSTR(sup_rec.supplier_name, 1, 24), 30) ||
                RPAD(sup_rec.times_ordered, 8) ||
                RPAD(sup_rec.total_quantity_supplied, 12) ||
                RPAD(TO_CHAR(sup_rec.avg_unit_cost, '9999.99'), 12) ||
                TO_CHAR(sup_rec.total_spent, '999,999.99')
            ));
        END LOOP;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(fn_box_row(' '));
    DBMS_OUTPUT.PUT_LINE(fn_box_sep);
    DBMS_OUTPUT.PUT_LINE(fn_box_row('==== END OF REPORT ====', 'C'));
    DBMS_OUTPUT.PUT_LINE(fn_box_sep);
END proc_rpt_procurement_cmp;
/


-- ------------------------------------------
-- 7.2 In / Out stock comparison report for a branch (ON DEMAND REPORT)
-- Generated only when called, for the single branch passed in via
-- p_branch_id - e.g. EXEC proc_rpt_branch_stock_inout(1001).
-- Outer cursor walks every item stocked at the branch;
-- for each item, one inner cursor aggregates quantity received
-- (procurement) and another aggregates quantity sold (order_item)
-- via GROUP BY/HAVING, fetched as a single summed row.
-- ------------------------------------------
CREATE OR REPLACE PROCEDURE proc_rpt_branch_stock_inout (
    p_branch_id IN branch_stock.branch_id%TYPE
) AS

    CURSOR c_stock IS
        SELECT bs.item_id, i.item_name, bs.stock_quantity, bs.last_restock_date
        FROM branch_stock bs
        JOIN item i ON i.item_id = bs.item_id
        WHERE bs.branch_id = p_branch_id
        ORDER BY bs.item_id;

    CURSOR c_stock_in (p_item_id item.item_id%TYPE) IS
        SELECT SUM(p.quantity) AS total_in
        FROM procurement p
        WHERE p.branch_id = p_branch_id AND p.item_id = p_item_id
        GROUP BY p.branch_id, p.item_id
        HAVING SUM(p.quantity) >= 0;

    CURSOR c_stock_out (p_item_id item.item_id%TYPE) IS
        SELECT SUM(oi.quantity) AS total_out
        FROM orders o
        JOIN order_item oi ON oi.order_id = o.order_id
        WHERE o.branch_id = p_branch_id AND oi.item_id = p_item_id
        GROUP BY o.branch_id, oi.item_id
        HAVING SUM(oi.quantity) >= 0;

    v_total_in  NUMBER;
    v_total_out NUMBER;

BEGIN
    DBMS_OUTPUT.PUT_LINE(fn_box_sep);
    DBMS_OUTPUT.PUT_LINE(fn_box_row('REPORT 7.2: IN / OUT STOCK COMPARISON FOR BRANCH ' || p_branch_id, 'C'));
    DBMS_OUTPUT.PUT_LINE(fn_box_row('Generated: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI'), 'C'));
    DBMS_OUTPUT.PUT_LINE(fn_box_sep);
    DBMS_OUTPUT.PUT_LINE(fn_box_row(' ' || RPAD('Item ID', 10) || RPAD('Item Name', 28) ||
                          RPAD('Stock In', 10) || RPAD('Stock Out', 10) ||
                          RPAD('Current', 10) || 'Last Restock'));
    DBMS_OUTPUT.PUT_LINE(fn_box_row(' ' || RPAD('-', 90, '-')));

    FOR stock_rec IN c_stock LOOP

        OPEN c_stock_in(stock_rec.item_id);
        FETCH c_stock_in INTO v_total_in;
        IF c_stock_in%NOTFOUND THEN
            v_total_in := 0;
        END IF;
        CLOSE c_stock_in;

        OPEN c_stock_out(stock_rec.item_id);
        FETCH c_stock_out INTO v_total_out;
        IF c_stock_out%NOTFOUND THEN
            v_total_out := 0;
        END IF;
        CLOSE c_stock_out;

        DBMS_OUTPUT.PUT_LINE(fn_box_row(
            ' ' ||
            RPAD(stock_rec.item_id, 10) ||
            RPAD(SUBSTR(stock_rec.item_name, 1, 27), 28) ||
            RPAD(v_total_in, 10) ||
            RPAD(v_total_out, 10) ||
            RPAD(stock_rec.stock_quantity, 10) ||
            TO_CHAR(stock_rec.last_restock_date, 'DD-MON-YYYY')
        ));
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(fn_box_row(' '));
    DBMS_OUTPUT.PUT_LINE(fn_box_sep);
    DBMS_OUTPUT.PUT_LINE(fn_box_row('==== END OF REPORT ====', 'C'));
    DBMS_OUTPUT.PUT_LINE(fn_box_sep);
END proc_rpt_branch_stock_inout;
/


-- ------------------------------------------
-- 7.3 Company-wide branch performance summary (SUMMARY REPORT)
-- High-level, aggregated-only figures for management - no
-- item/order-level rows, just category and branch totals.
-- Outer cursor walks each branch; nested inner cursor
-- aggregates that branch's sales by item category. Running
-- branch and grand totals are accumulated as the cursors loop.
-- ------------------------------------------
CREATE OR REPLACE PROCEDURE proc_rpt_company_summary AS

    CURSOR c_branch IS
        SELECT branch_id, branch_name
        FROM branch
        ORDER BY branch_id;

    CURSOR c_branch_category_sales (p_branch_id branch.branch_id%TYPE) IS
        SELECT
            i.category,
            COUNT(DISTINCT o.order_id)       AS order_count,
            SUM(oi.quantity)                 AS total_qty,
            SUM(oi.quantity * oi.unit_price) AS total_sales
        FROM orders o
        JOIN order_item oi ON oi.order_id = o.order_id
        JOIN item i ON i.item_id = oi.item_id
        WHERE o.branch_id = p_branch_id
        GROUP BY i.category
        HAVING SUM(oi.quantity * oi.unit_price) > 0
        ORDER BY total_sales DESC;

    v_branch_total_sales  NUMBER;
    v_branch_total_orders NUMBER;
    v_grand_total_sales   NUMBER := 0;
    v_grand_total_orders  NUMBER := 0;

BEGIN
    DBMS_OUTPUT.PUT_LINE(fn_box_sep);
    DBMS_OUTPUT.PUT_LINE(fn_box_row('REPORT 7.3: COMPANY-WIDE BRANCH PERFORMANCE SUMMARY', 'C'));
    DBMS_OUTPUT.PUT_LINE(fn_box_row('Generated: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI'), 'C'));
    DBMS_OUTPUT.PUT_LINE(fn_box_sep);

    FOR branch_rec IN c_branch LOOP
        DBMS_OUTPUT.PUT_LINE(fn_box_row(' '));
        DBMS_OUTPUT.PUT_LINE(fn_box_row(' ' || branch_rec.branch_id || ' - ' || branch_rec.branch_name));
        DBMS_OUTPUT.PUT_LINE(fn_box_row(' ' || RPAD('Category', 18) || RPAD('Orders', 10) ||
                              RPAD('Qty Sold', 12) || 'Total Sales (RM)'));
        DBMS_OUTPUT.PUT_LINE(fn_box_row(' ' || RPAD('-', 60, '-')));

        v_branch_total_sales  := 0;
        v_branch_total_orders := 0;

        FOR cat_rec IN c_branch_category_sales(branch_rec.branch_id) LOOP
            DBMS_OUTPUT.PUT_LINE(fn_box_row(
                ' ' ||
                RPAD(cat_rec.category, 18) ||
                RPAD(cat_rec.order_count, 10) ||
                RPAD(cat_rec.total_qty, 12) ||
                TO_CHAR(cat_rec.total_sales, '999,999.99')
            ));
            v_branch_total_sales  := v_branch_total_sales + cat_rec.total_sales;
            v_branch_total_orders := v_branch_total_orders + cat_rec.order_count;
        END LOOP;

        DBMS_OUTPUT.PUT_LINE(fn_box_row(' ' || RPAD('-', 60, '-')));
        DBMS_OUTPUT.PUT_LINE(fn_box_row(' Branch total: ' || v_branch_total_orders || ' orders, RM ' ||
                              TO_CHAR(v_branch_total_sales, '999,999.99')));

        v_grand_total_sales  := v_grand_total_sales + v_branch_total_sales;
        v_grand_total_orders := v_grand_total_orders + v_branch_total_orders;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(fn_box_row(' '));
    DBMS_OUTPUT.PUT_LINE(fn_box_sep);
    DBMS_OUTPUT.PUT_LINE(fn_box_row('COMPANY GRAND TOTAL: ' || v_grand_total_orders || ' orders, RM ' ||
                          TO_CHAR(v_grand_total_sales, '999,999,999.99'), 'C'));
    DBMS_OUTPUT.PUT_LINE(fn_box_sep);
END proc_rpt_company_summary;
/


-- ------------------------------------------
-- Example usage:
-- SET SERVEROUTPUT ON SIZE UNLIMITED
-- SET LINESIZE 110
-- EXEC proc_rpt_procurement_cmp;          -- detail report
-- EXEC proc_rpt_branch_stock_inout(1001); -- on demand report (branch param)
-- EXEC proc_rpt_company_summary;          -- summary report
-- ------------------------------------------
