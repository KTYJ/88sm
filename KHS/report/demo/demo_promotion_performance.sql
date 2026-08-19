SET SERVEROUTPUT ON

SET LINESIZE 120
SET PAGESIZE 100
SET FEEDBACK OFF
SET VERIFY OFF

BEGIN
    sp_promotion_performance(
        p_start_date   => DATE '2026-07-01',
        p_end_date     => DATE '2026-07-31',
        p_promotion_id => 5033
    );
END;
/
