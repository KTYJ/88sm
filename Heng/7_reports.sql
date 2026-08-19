-- ==========================================
-- 7. REPORTS (as stored procedures using nested cursors)
-- ==========================================

-- ------------------------------------------
-- 7.1 Item procurement comparison between suppliers
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
        ORDER BY avg_unit_cost;

    v_rank PLS_INTEGER;

BEGIN
    DBMS_OUTPUT.PUT_LINE('===================================================================');
    DBMS_OUTPUT.PUT_LINE('REPORT 7.1: ITEM PROCUREMENT COMPARISON BETWEEN SUPPLIERS');
    DBMS_OUTPUT.PUT_LINE('===================================================================');

    FOR item_rec IN c_items LOOP
        DBMS_OUTPUT.PUT_LINE(CHR(10) || item_rec.item_id || ' - ' || item_rec.item_name);
        DBMS_OUTPUT.PUT_LINE(RPAD('Rank', 6) || RPAD('Supplier', 30) ||
                              RPAD('Orders', 8) || RPAD('Total Qty', 12) ||
                              RPAD('Avg Cost', 12) || 'Total Spent');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));

        v_rank := 0;

        FOR sup_rec IN c_suppliers(item_rec.item_id) LOOP
            v_rank := v_rank + 1;
            DBMS_OUTPUT.PUT_LINE(
                RPAD(v_rank, 6) ||
                RPAD(sup_rec.supplier_id || ' ' || SUBSTR(sup_rec.supplier_name, 1, 24), 30) ||
                RPAD(sup_rec.times_ordered, 8) ||
                RPAD(sup_rec.total_quantity_supplied, 12) ||
                RPAD(TO_CHAR(sup_rec.avg_unit_cost, '9999.99'), 12) ||
                TO_CHAR(sup_rec.total_spent, '999,999.99')
            );
        END LOOP;
    END LOOP;
END proc_rpt_procurement_cmp;
/


-- ------------------------------------------
-- 7.2 In / Out stock comparison report for a branch
-- Outer cursor walks every item stocked at the branch;
-- for each item, one inner cursor sums quantity received
-- (procurement) and another sums quantity sold (order_item),
-- both totalled procedurally row by row.
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
        SELECT quantity
        FROM procurement
        WHERE branch_id = p_branch_id AND item_id = p_item_id;

    CURSOR c_stock_out (p_item_id item.item_id%TYPE) IS
        SELECT oi.quantity
        FROM orders o
        JOIN order_item oi ON oi.order_id = o.order_id
        WHERE o.branch_id = p_branch_id AND oi.item_id = p_item_id;

    v_total_in  NUMBER;
    v_total_out NUMBER;

BEGIN
    DBMS_OUTPUT.PUT_LINE('===================================================================');
    DBMS_OUTPUT.PUT_LINE('REPORT 7.2: IN / OUT STOCK COMPARISON FOR BRANCH ' || p_branch_id);
    DBMS_OUTPUT.PUT_LINE('===================================================================');
    DBMS_OUTPUT.PUT_LINE(RPAD('Item ID', 10) || RPAD('Item Name', 28) ||
                          RPAD('Stock In', 10) || RPAD('Stock Out', 10) ||
                          RPAD('Current', 10) || 'Last Restock');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 88, '-'));

    FOR stock_rec IN c_stock LOOP

        v_total_in := 0;
        FOR in_rec IN c_stock_in(stock_rec.item_id) LOOP
            v_total_in := v_total_in + in_rec.quantity;
        END LOOP;

        v_total_out := 0;
        FOR out_rec IN c_stock_out(stock_rec.item_id) LOOP
            v_total_out := v_total_out + out_rec.quantity;
        END LOOP;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(stock_rec.item_id, 10) ||
            RPAD(SUBSTR(stock_rec.item_name, 1, 27), 28) ||
            RPAD(v_total_in, 10) ||
            RPAD(v_total_out, 10) ||
            RPAD(stock_rec.stock_quantity, 10) ||
            TO_CHAR(stock_rec.last_restock_date, 'DD-MON-YYYY')
        );
    END LOOP;
END proc_rpt_branch_stock_inout;
/


-- ------------------------------------------
-- Example usage:
-- SET SERVEROUTPUT ON SIZE UNLIMITED
-- EXEC proc_rpt_procurement_cmp;
-- EXEC proc_rpt_branch_stock_inout(1001);
-- ------------------------------------------
