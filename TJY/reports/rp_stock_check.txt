cl scr
SET SERVEROUTPUT ON;
SET DEFINE OFF;
SET LINESIZE 120;

-- =============================================================================
-- REPORT 4: Branch Stock Reorder Alert (Operational - On-Demand)
-- Tables: branch, branch_stock, item, procurement
-- Cursor: Nested (outer: branches, inner: low-stock items per branch)
-- Parameter: p_threshold (stock level below which to flag)
-- =============================================================================

CREATE OR REPLACE PROCEDURE rp_stock_reorder(p_threshold IN NUMBER DEFAULT 10) IS
    -- Outer cursor: branches with at least one item below threshold
    -- the idea is to take the branches and cycle them 1 by 1 in the inner cursor
    CURSOR c_branch IS
        SELECT DISTINCT b.branch_id, b.branch_name
        FROM   branch b
        JOIN   branch_stock bs ON bs.branch_id = b.branch_id
        WHERE  bs.stock_quantity < p_threshold
        ORDER BY b.branch_name;

    -- Inner cursor: items below threshold at specific branch
    CURSOR c_low_stock(p_branch_id NUMBER) IS
        SELECT i.item_id, i.item_name, i.category,
               bs.stock_quantity,
               TO_CHAR(bs.last_restock_date, 'DD-MON-YYYY') AS last_restock,
               (SELECT NVL(AVG(p.unit_cost), 0)
                FROM   procurement p
                WHERE  p.item_id = i.item_id) AS est_unit_price
        FROM   branch_stock bs
        JOIN   item i ON i.item_id = bs.item_id
        WHERE  bs.branch_id = p_branch_id
        AND    bs.stock_quantity < p_threshold
        ORDER BY bs.stock_quantity ASC;

    v_branch_id   branch.branch_id%TYPE;
    v_branch_name branch.branch_name%TYPE;

    v_alert_count    NUMBER := 0;
    v_urgency        VARCHAR2(10);
    v_branch_est_cost NUMBER;
    v_total_est_cost  NUMBER := 0;

    v_box_sep VARCHAR2(110) := '+' || RPAD('-', 96, '-') || '+';

    FUNCTION center_str(p_str VARCHAR2, p_width NUMBER) RETURN VARCHAR2 IS
        v_left_spaces NUMBER;
    BEGIN
        IF p_str IS NULL THEN RETURN RPAD(' ', p_width, ' '); END IF;
        v_left_spaces := TRUNC((p_width - LENGTH(p_str)) / 2);
        RETURN RPAD(LPAD(p_str, LENGTH(p_str) + v_left_spaces, ' '), p_width, ' ');
    END center_str;

    FUNCTION format_box_row(p_text VARCHAR2, p_inner_width NUMBER DEFAULT 94, p_align VARCHAR2 DEFAULT 'L') RETURN VARCHAR2 IS
    BEGIN
        IF p_align = 'C' THEN
            RETURN '| ' || center_str(p_text, p_inner_width) || ' |';
        ELSE
            RETURN '| ' || RPAD(NVL(p_text, ' '), p_inner_width, ' ') || ' |';
        END IF;
    END format_box_row;

BEGIN
    DBMS_OUTPUT.PUT_LINE('    ' || v_box_sep);
    DBMS_OUTPUT.PUT_LINE('    ' || format_box_row('BRANCH STOCK REORDER ALERT', 94, 'C'));
    DBMS_OUTPUT.PUT_LINE('    ' || format_box_row('Stock Threshold: < ' || p_threshold || ' unit(s)', 94, 'C'));
    DBMS_OUTPUT.PUT_LINE('    ' || format_box_row('Generated: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI'), 94, 'C'));
    DBMS_OUTPUT.PUT_LINE('    ' || v_box_sep);
    DBMS_OUTPUT.PUT_LINE(CHR(10));


    OPEN c_branch;
    LOOP
        FETCH c_branch INTO v_branch_id, v_branch_name;
        EXIT WHEN c_branch%NOTFOUND;
        
        v_branch_est_cost := 0;
        
        DBMS_OUTPUT.PUT_LINE('  Branch: ' || v_branch_name || ' (ID: ' || v_branch_id || ')');
        DBMS_OUTPUT.PUT_LINE('    ' || RPAD('=', 10, '=') || RPAD('=', 25, '=') ||
                             RPAD('=', 15, '=') || RPAD('=', 8, '=') || RPAD('=', 14, '=') ||
                             RPAD('=', 15, '=') || ' ' || RPAD('=', 10, '='));
        DBMS_OUTPUT.PUT_LINE('    ' || RPAD('Item ID', 10) || RPAD('Item Name', 25) ||
                             RPAD('Category', 15) || RPAD('Stock', 8) || RPAD('Last Restock', 14) ||
                             RPAD('Est. Unit Price', 16) || 'Urgency');
        DBMS_OUTPUT.PUT_LINE('    ' || RPAD('=', 10, '=') || RPAD('=', 25, '=') ||
                             RPAD('=', 15, '=') || RPAD('=', 8, '=') || RPAD('=', 14, '=') ||
                             RPAD('=', 15, '=') || ' ' || RPAD('=', 10, '='));

        FOR r2 IN c_low_stock(v_branch_id) LOOP
            IF r2.stock_quantity = 0 THEN
                v_urgency := 'CRITICAL';
            ELSIF r2.stock_quantity <= (p_threshold / 2) THEN
                v_urgency := 'HIGH';
            ELSE
                v_urgency := 'MEDIUM';
            END IF;

            DBMS_OUTPUT.PUT_LINE('    ' ||
                RPAD(r2.item_id, 10) ||
                RPAD(r2.item_name, 25) ||
                RPAD(NVL(r2.category, '-'), 15) ||
                RPAD(TO_CHAR(r2.stock_quantity), 8) ||
                RPAD(NVL(r2.last_restock, 'Never'), 14) ||
                LPAD(CASE WHEN r2.est_unit_price = 0 THEN 'N/A' ELSE TRIM(TO_CHAR(r2.est_unit_price, '99,990.00')) END, 14) || '  ' ||
                v_urgency);
            v_alert_count := v_alert_count + 1;
            v_branch_est_cost := v_branch_est_cost + ((p_threshold - r2.stock_quantity) * r2.est_unit_price);
        END LOOP;
        --DBMS_OUTPUT.PUT_LINE(chr(10));
        DBMS_OUTPUT.PUT_LINE('    ' || RPAD('=', 10, '=') || RPAD('=', 25, '=') ||
                             RPAD('=', 15, '=') || RPAD('=', 8, '=') || RPAD('=', 14, '=') ||
                             RPAD('=', 15, '=') || ' ' || RPAD('=', 10, '='));
        DBMS_OUTPUT.PUT_LINE('    ' || LPAD('       Est. Branch Procurement Cost (RM): ', 75, '.') || CHR(27) || CASE WHEN v_branch_est_cost = 0 THEN '[31m' || LPAD('N/A', 14) ELSE '[33m' || LPAD(TRIM(TO_CHAR(v_branch_est_cost, '99,990.00')), 14) END || CHR(27) || '[0m' || '  ');
        v_total_est_cost := v_total_est_cost + v_branch_est_cost;
        DBMS_OUTPUT.PUT_LINE(CHR(10));
    END LOOP;
    CLOSE c_branch;

    IF v_alert_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10));
        DBMS_OUTPUT.PUT_LINE('    ' || v_box_sep);
        DBMS_OUTPUT.PUT_LINE('    ' || format_box_row('No items below threshold of ' || p_threshold || ' units. All stock levels healthy. :D', 94, 'C'));
        DBMS_OUTPUT.PUT_LINE('    ' || v_box_sep);
    ELSE
        DBMS_OUTPUT.PUT_LINE('    ' || v_box_sep);
        DBMS_OUTPUT.PUT_LINE('    ' || format_box_row('', 94, 'C'));
        DBMS_OUTPUT.PUT_LINE('    ' || format_box_row('==== END OF REPORT ====', 94, 'C'));
        DBMS_OUTPUT.PUT_LINE('    ' || format_box_row('', 94, 'C'));
        DBMS_OUTPUT.PUT_LINE('    ' || format_box_row('TOTAL ITEMS REQUIRING REORDER :      ' || v_alert_count, 94, 'C'));
        DBMS_OUTPUT.PUT_LINE('    ' || format_box_row('TOTAL ESTIMATED COST     :  ~ ' || CASE WHEN v_total_est_cost = 0 THEN 'N/A' ELSE 'RM ' || TRIM(TO_CHAR(v_total_est_cost, '99,999,990.00')) END, 94, 'C'));
        DBMS_OUTPUT.PUT_LINE('    ' || format_box_row('', 94, 'C'));
        DBMS_OUTPUT.PUT_LINE('    ' || v_box_sep);
    END IF;
END;
/

--demo
--parameters: alert stock threshold 
EXEC rp_stock_reorder(15);
