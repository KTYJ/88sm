SET SERVEROUTPUT ON
SET LINESIZE 120
SET PAGESIZE 100
SET FEEDBACK OFF

BEGIN
    sp_customer_rfm_report(
        p_branch_id => 1001,
        p_recency   => 90,
        p_frequency => 5,
        p_monetary  => 200,
        p_ranking   => 5
    );
END;
/
