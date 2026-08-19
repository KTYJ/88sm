SET SERVEROUTPUT ON
SET LINESIZE 120
SET PAGESIZE 100
SET FEEDBACK OFF

PROMPT
PROMPT ===============================================================================================
PROMPT TEST 1: ALL CUSTOMERS
PROMPT ===============================================================================================

BEGIN
    sp_customer_rfm_report(
        p_branch_id => 1001
    );
END;
/

PROMPT
PROMPT ===============================================================================================
PROMPT TEST 2: TOP 5 CUSTOMERS
PROMPT ===============================================================================================

BEGIN
    sp_customer_rfm_report(
        p_branch_id => 1001,
        p_ranking   => 5
    );
END;
/

PROMPT
PROMPT ===============================================================================================
PROMPT TEST 3: FILTER + TOP 5
PROMPT ===============================================================================================

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
