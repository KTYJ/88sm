cl scr 
SET SERVEROUTPUT On;
SET DEFINE OFF;
SET LINESIZE 120;
-- SET SERVEROUTPUT ON FORMAT WORD_WRAPPED;

set pagesize 100;

-- =============================================================================
-- REPORT 2: Monthly Spending by Member Report (Detail)
-- Tables: member, orders, order_item, item, branch
-- =============================================================================

CREATE OR REPLACE PROCEDURE rp_mthly_spend_mem (v_top_n in NUMBER DEFAULT 10) IS
    
    -- cursor: top members by spending within a given calendar-month window
    CURSOR c_member(p_start DATE, p_end DATE) IS
        SELECT m.member_id, m.name, m.email, m.points_balance,
               (SELECT MAX(expiry_date) FROM vip_renewal v WHERE v.member_id = m.member_id) AS expiry_date,
               COUNT(DISTINCT o.order_id) AS order_count,
               NVL(SUM(oi.quantity * oi.unit_price), 0) AS total_spent
        FROM   member m
        JOIN orders o      ON o.member_id = m.member_id
        JOIN order_item oi ON oi.order_id = o.order_id
        WHERE  TRUNC(o.order_date) BETWEEN p_start AND p_end
        GROUP BY m.member_id, m.name, m.email, m.points_balance
        ORDER BY total_spent DESC;

-- Cursor: most visited branch per member (returns 1 row - top branch)
CURSOR c_fav_branch (
    p_member_id NUMBER,
    p_start DATE,
    p_end DATE
) IS
SELECT branch_name, visit_count
FROM (
        SELECT b.branch_name, COUNT(o.order_id) AS visit_count
        FROM orders o
            JOIN branch b ON b.branch_id = o.branch_id
        WHERE
            o.member_id = p_member_id
            AND TRUNC (o.order_date) BETWEEN p_start AND p_end
        GROUP BY
            b.branch_name
        ORDER BY visit_count DESC
    )
WHERE
    ROWNUM = 1;

-- Inner cursor: top products bought by member (by total quantity)
CURSOR c_top_products (
    p_member_id NUMBER,
    p_start DATE,
    p_end DATE
) IS
SELECT
    item_name,
    category,
    total_qty,
    total_value,
    ROWNUM AS rnk
FROM (
        SELECT i.item_name, i.category, SUM(oi.quantity) AS total_qty, SUM(oi.quantity * oi.unit_price) AS total_value
        FROM
            order_item oi
            JOIN orders o ON o.order_id = oi.order_id
            JOIN item i ON i.item_id = oi.item_id
        WHERE
            o.member_id = p_member_id
            AND TRUNC (o.order_date) BETWEEN p_start AND p_end
        GROUP BY
            i.item_name, i.category
        ORDER BY total_qty DESC
    )
WHERE
    ROWNUM <= 5;

-- Variables
v_member_counter NUMBER := 0;

v_total_members NUMBER := 0;

v_status VARCHAR2 (20);

v_start_date DATE;

v_end_date DATE;

v_fav_branch VARCHAR2 (100);

v_fav_visits NUMBER;

-- border line for box
v_box_sep VARCHAR2 (110) := '+' || RPAD('-', 108, '-') || '+';

-- ================================================================================================================================

-- ============================================================
-- FUNCTION center_str(p_str VARCHAR2, p_width NUMBER)
--
-- PURPOSE : Centers a given string within a specified width.
-- INPUTS  : p_str   - The string to center
--           p_width - Total width of the output
-- OUTPUT  : A string padded with spaces so that p_str is centered.
-- NOTES   : If p_str is NULL, returns spaces of length p_width.
--
-- EXAMPLE :
--   center_str('Hello', 20)
--   Result (brackets show boundaries):
--   [       Hello        ]
--    <-7-><Hello><--8--->
--
--   center_str(NULL, 10)
--   Result: [          ]  (10 spaces)
-- ============================================================
    FUNCTION center_str(p_str VARCHAR2, p_width NUMBER) RETURN VARCHAR2 IS
        v_left_spaces NUMBER;
    BEGIN
        IF p_str IS NULL THEN RETURN RPAD(' ', p_width, ' '); END IF;
        v_left_spaces := TRUNC((p_width - LENGTH(p_str)) / 2);
        RETURN RPAD(LPAD(p_str, LENGTH(p_str) + v_left_spaces, ' '), p_width, ' ');
    END center_str;


-- ============================================================
-- FUNCTION format_box_row(p_text VARCHAR2,
--                         p_inner_width NUMBER DEFAULT 106,
--                         p_align       VARCHAR2 DEFAULT 'L')
--
-- PURPOSE : Formats a row inside a text box with walls "| text |".
-- INPUTS  : p_text        - The text to display
--           p_inner_width - Width of the inner text area (default 106)
--           p_align       - Alignment ('L' = left, 'C' = center)
-- OUTPUT  : A string representing a box row with text inside.
-- NOTES   : Uses center_str for centering; defaults to left alignment.
--
-- EXAMPLE (p_inner_width = 20 for readability):
--
--   format_box_row('Member: Alice', 20, 'L')
--   | Member: Alice        |
--
--   format_box_row('Centered', 20, 'C')
--   |       Centered       |
--
--   format_box_row(NULL, 20, 'L')
--   |                      |
-- ============================================================
    FUNCTION format_box_row(p_text VARCHAR2, p_inner_width NUMBER DEFAULT 106, p_align VARCHAR2 DEFAULT 'L') RETURN VARCHAR2 IS
    BEGIN
        IF p_align = 'C' THEN
            RETURN '| ' || center_str(p_text, p_inner_width) || ' |';
        ELSE
            RETURN '| ' || RPAD(NVL(p_text, ' '), p_inner_width, ' ') || ' |';
        END IF;
    END format_box_row;


-- ============================================================
-- FUNCTION format_rank_box_top(p_rank  NUMBER,
--                              p_width NUMBER DEFAULT 108)
--
-- PURPOSE : Creates the top border of a box with rank label embedded
--           in the centre of the dashed separator line.
-- INPUTS  : p_rank  - Rank number to embed in the border
--           p_width - Inner dash width (default 108, gives 110 total)
-- OUTPUT  : A string with rank centred between dashes.
--
-- EXAMPLE :
--   format_rank_box_top(1)   -- label ' RANK 1 ' = 8 chars
--   +-------------------------------------------------- RANK 1 --------------------------------------------------+
--    <--------------------50 dashes-------------------><RANK 1 ><--------------------50 dashes------------------->+
--
--   format_rank_box_top(10)  -- label ' RANK 10 ' = 9 chars
--   +------------------------------------------------- RANK 10 -------------------------------------------------+
--
-- NOTES   : Total output length = p_width + 2 (for the two '+' walls).
--           Odd-width labels: left side gets one fewer dash than right.
-- ============================================================
    FUNCTION format_rank_box_top(p_rank NUMBER, p_width NUMBER DEFAULT 108) RETURN VARCHAR2 IS
        v_label       VARCHAR2(20) := ' RANK ' || p_rank || ' ';
        v_label_color VARCHAR2(50) := CHR(27) || '[33m' || v_label || CHR(27) || '[0m';
        v_left        NUMBER;
        v_right       NUMBER;
    BEGIN
        -- Use visible label length for dash calculation (ANSI codes have no display width)
        v_left  := TRUNC((p_width - LENGTH(v_label)) / 2);
        v_right := p_width - LENGTH(v_label) - v_left;
        RETURN '+' || RPAD('-', v_left, '-') || v_label_color || RPAD('-', v_right, '-') || '+';
    END format_rank_box_top;


-- ============================================================
-- FUNCTION get_member_status(p_expiry_date DATE)
--
-- PURPOSE : Derives membership status label from VIP expiry date.
-- INPUTS  : p_expiry_date - The member's VIP expiry date
-- OUTPUT  : 'NON-VIP', 'VIP EXPIRED', 'VIP EXPIRING SOON' (within 30 days), or 'VIP ACTIVE'
--
-- EXAMPLE :
--   get_member_status(NULL)          => 'NON-VIP'
--   get_member_status(SYSDATE - 1)   => 'VIP EXPIRED'
--   get_member_status(SYSDATE + 15)  => 'VIP EXPIRING SOON'
--   get_member_status(SYSDATE + 60)  => 'VIP ACTIVE'
-- ============================================================
    FUNCTION get_member_status(p_expiry_date DATE) RETURN VARCHAR2 IS
    BEGIN
        IF p_expiry_date IS NULL THEN
            RETURN 'NON-VIP';
        ELSIF p_expiry_date < SYSDATE THEN
            RETURN 'VIP EXPIRED';
        ELSIF p_expiry_date < SYSDATE + 30 THEN
            RETURN 'VIP EXPIRING SOON';
        ELSE
            RETURN 'VIP ACTIVE';
        END IF;
    END get_member_status;


-- ================================================================================================================================
BEGIN
    -- Calculate first and last day of the previous calendar month
    v_start_date := TRUNC(ADD_MONTHS(SYSDATE, -1), 'MM');
    v_end_date   := LAST_DAY(ADD_MONTHS(SYSDATE, -1));

    SELECT COUNT(DISTINCT member_id) INTO v_total_members
    FROM   orders
    WHERE  TRUNC(order_date) BETWEEN v_start_date AND v_end_date;

    -- REPORT HEADER (Centered)
    DBMS_OUTPUT.PUT_LINE(center_str(v_box_sep, 120));
    DBMS_OUTPUT.PUT_LINE(center_str(format_box_row(UPPER(TO_CHAR(v_start_date, 'fmMonth YYYY')) || ' - TOP ' || v_top_n || ' MEMBER SPENDING REPORT', 106, 'C'), 120));
    DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('Generated: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI'), 106, 'C'), 120));
    DBMS_OUTPUT.PUT_LINE(center_str(v_box_sep, 120));
    DBMS_OUTPUT.PUT_LINE(' ');

    FOR r IN c_member(v_start_date, v_end_date) LOOP
        v_member_counter := v_member_counter + 1;

        -- Determine membership status
        v_status := get_member_status(r.expiry_date);

        -- Fetch most visited branch
        v_fav_branch := 'N/A';
        v_fav_visits := 0;
        FOR r_br IN c_fav_branch(r.member_id, v_start_date, v_end_date) LOOP
            v_fav_branch := r_br.branch_name;
            v_fav_visits := r_br.visit_count;
        END LOOP;

        -- MEMBER DETAILS (Upper Section with Embedded Rank in Top Border)
        DBMS_OUTPUT.PUT_LINE(center_str(format_rank_box_top(v_member_counter), 120));
        DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('', 106, 'C'), 120));
        DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('  Member: ' || r.name || ' (ID: ' || r.member_id || ')  [' || v_status || ']', 106, 'L'), 120));
        DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('  Email : ' || NVL(r.email, 'N/A') || '   |   Expiry: ' || TO_CHAR(r.expiry_date, 'DD-MON-YYYY'), 106, 'L'), 120));
        DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('  Orders: ' || r.order_count || 
                                                       '   |   Spent : RM ' || TRIM(TO_CHAR(r.total_spent, '99,999.00')) || 
                                                       '   |   Points Balance: ' || r.points_balance, 106, 'L'), 120));
        DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('  Most Visited Branch: ' || v_fav_branch ||
                                                       '  - ' || v_fav_visits || ' visit(s)', 106, 'L'), 120));
        
        DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('  ' || RPAD('-', 102, '-'), 106, 'L'), 120));
        
        -- TOP PRODUCTS SECTION HEADER
        DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('  TOP PRODUCTS PURCHASED', 106, 'L'), 120));
        DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('  ' || RPAD('-', 102, '-'), 106, 'L'), 120));
        DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('    ' || 
                             RPAD('#', 5) ||
                             RPAD('Product Name', 40) || 
                             RPAD('Category', 20) ||
                             RPAD('Qty Bought', 13) || 
                             'Total Value (RM)', 106, 'L'), 120));
                             
        DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('    ' || 
                             RPAD('-', 3, '-') || '  ' ||
                             RPAD('-', 38, '-') || '  ' ||
                             RPAD('-', 18, '-') || '  ' ||
                             RPAD('-', 10, '-') || '  ' ||
                             RPAD('-', 16, '-'), 106, 'L'), 120));

        -- TOP PRODUCTS LOOP (Bottom Section)
        -- using %  rowtype loop
        FOR r_prod IN c_top_products(r.member_id, v_start_date, v_end_date) LOOP   
            DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('    ' ||
                RPAD(r_prod.rnk, 5) ||
                RPAD(r_prod.item_name, 40) ||
                RPAD(NVL(r_prod.category, 'N/A'), 20) ||
                RPAD(r_prod.total_qty, 13) ||
                TRIM(TO_CHAR(r_prod.total_value, '99,999.00')), 106, 'L'), 120));
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('', 106, 'L'), 120));

        -- BOTTOM CLOSING BOX LINE
        DBMS_OUTPUT.PUT_LINE(center_str(v_box_sep, 120));
        DBMS_OUTPUT.PUT_LINE(' ');

        exit when v_member_counter = v_top_n;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(CHR(10));

    -- REPORT FOOTER (Centered)
    DBMS_OUTPUT.PUT_LINE(center_str(v_box_sep, 120));
    DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('==== END OF REPORT ====', 106, 'C'), 120));
    DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('', 106, 'C'), 120));
    DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('Showing Top ' || v_member_counter || ' of ' || v_total_members || ' Total Members (that made purchases in ' || TO_CHAR(v_start_date, 'FMMONTH YYYY') || ')', 106, 'C'), 120));
    DBMS_OUTPUT.PUT_LINE(center_str(format_box_row('', 106, 'C'), 120));
    DBMS_OUTPUT.PUT_LINE(center_str(v_box_sep, 120));
END;
/

--demo
-- params: top x
exec rp_mthly_spend_mem(3)