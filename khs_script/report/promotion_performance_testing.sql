SET SERVEROUTPUT ON

SET LINESIZE 120
SET PAGESIZE 100
SET FEEDBACK OFF
SET VERIFY OFF

PROMPT ==========================================================
PROMPT TEST 1: ALL PROMOTIONS
PROMPT ==========================================================

BEGIN
    sp_promotion_performance(
        p_start_date => DATE '2026-07-01',
        p_end_date   => DATE '2026-07-31'
    );
END;
/

PROMPT ==========================================================
PROMPT TEST 2: SPECIFIC PROMOTION
PROMPT ==========================================================

BEGIN
    sp_promotion_performance(
        p_start_date   => DATE '2026-07-01',
        p_end_date     => DATE '2026-07-31',
        p_promotion_id => 5037
    );
END;
/

PROMPT ==========================================================
PROMPT TEST 3: INVALID DATE RANGE
PROMPT ==========================================================

BEGIN
    sp_promotion_performance(
        p_start_date => DATE '2026-07-31',
        p_end_date   => DATE '2026-07-01'
    );
END;
/