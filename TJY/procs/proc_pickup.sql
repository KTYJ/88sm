-- =============================================================================
-- Procedure: proc_pickup
-- Purpose:   Manages Self Pickup orders — update pickup_status to any valid
--            value, with expiry check and reschedule date handling.
-- Valid statuses: 'Preparing', 'Ready', 'Completed', 'Expired', 'Rescheduled'
--
-- Usage:
--   EXEC proc_pickup(12, 'Ready');
--   EXEC proc_pickup(12, 'Completed');
--   EXEC proc_pickup(12, 'Rescheduled', SYSTIMESTAMP + INTERVAL '5' DAY);
-- =============================================================================
CREATE OR REPLACE PROCEDURE proc_pickup (
    p_order_id        IN orders.order_id%TYPE,
    p_new_status      IN self_pickup.pickup_status%TYPE,
    p_reschedule_date IN TIMESTAMP DEFAULT NULL
) AS
    v_order_type     orders.order_type%TYPE;
    v_pickup_status  self_pickup.pickup_status%TYPE;
    v_exp_date       self_pickup.pickup_exp_date%TYPE;

    e_pickup_expired    EXCEPTION;
    e_wrong_order_type  EXCEPTION;
    e_invalid_status    EXCEPTION;

BEGIN
    -- 1. Validate inputs
    IF p_order_id IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('Error: Order ID cannot be NULL.');
        RETURN;
    END IF;

    IF p_new_status NOT IN ('Preparing', 'Ready', 'Completed', 'Expired', 'Rescheduled') THEN
        RAISE e_invalid_status;
    END IF;

    -- 2. Fetch and verify order type
    SELECT order_type
    INTO   v_order_type
    FROM   orders
    WHERE  order_id = p_order_id;

    IF LOWER(v_order_type) != 'self pickup' THEN
        RAISE e_wrong_order_type;
    END IF;

    -- 3. Lock and fetch self_pickup row
    SELECT sp.pickup_status, sp.pickup_exp_date
    INTO   v_pickup_status, v_exp_date
    FROM   self_pickup sp
    WHERE  sp.order_id = p_order_id
    FOR UPDATE OF sp.pickup_status;

    -- 4. Guard: past expiry window (only when setting to Completed)
    IF p_new_status = 'Completed'
       AND v_exp_date IS NOT NULL
       AND SYSTIMESTAMP > v_exp_date
    THEN
        UPDATE self_pickup
        SET    pickup_status = 'Expired'
        WHERE  order_id = p_order_id;

        COMMIT;
        RAISE e_pickup_expired;
    END IF;

    -- 5. Apply status update
    -- Compute new expiry date based on status before running UPDATE
    IF p_new_status = 'Ready' THEN
        v_exp_date := SYSTIMESTAMP + INTERVAL '3' DAY;
    ELSIF p_new_status = 'Rescheduled' THEN
        v_exp_date := CASE WHEN p_reschedule_date IS NOT NULL THEN p_reschedule_date ELSE SYSTIMESTAMP + INTERVAL '3' DAY END;
    END IF;

    UPDATE self_pickup
    SET    pickup_status   = p_new_status,
           pickup_datetime = CASE WHEN p_new_status = 'Completed' THEN SYSTIMESTAMP ELSE pickup_datetime END,
           pickup_exp_date = CASE 
                               WHEN p_new_status = 'Ready' THEN v_exp_date
                               WHEN p_new_status = 'Rescheduled' THEN v_exp_date
                               ELSE pickup_exp_date 
                             END
    WHERE  order_id = p_order_id;

    COMMIT;

    -- 6. Status-specific output messages
    IF p_new_status = 'Ready' THEN
        DBMS_OUTPUT.PUT_LINE('proc_pickup: Order ' || p_order_id || ' pickup status set to ''Ready''. Expiry date: ' ||
                             TO_CHAR(v_exp_date, 'YYYY-MM-DD HH24:MI:SS') || '.');
    ELSIF p_new_status = 'Completed' THEN
        DBMS_OUTPUT.PUT_LINE('proc_pickup: Order ' || p_order_id || ' pickup status set to ''Completed'' at ' ||
                             TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS') || '.');
    ELSIF p_new_status = 'Rescheduled' THEN
        DBMS_OUTPUT.PUT_LINE('proc_pickup: Order ' || p_order_id || ' pickup status set to ''Rescheduled''. Expiry date: ' ||
                             TO_CHAR(v_exp_date, 'YYYY-MM-DD HH24:MI:SS') || '.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('proc_pickup: Order ' || p_order_id || ' pickup status set to ''' || p_new_status || '''.');
    END IF;

EXCEPTION
    WHEN e_invalid_status THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20638, 'Invalid status ''' || p_new_status || '''. Valid values: Preparing, Ready, Completed, Expired, Rescheduled.');
    WHEN e_wrong_order_type THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20639, 'Order ' || p_order_id || ' is type ''' || v_order_type || '''. Proc handles Self Pickup only.');
    WHEN e_pickup_expired THEN
        RAISE_APPLICATION_ERROR(-20640, 'Pickup window expired for order ' || p_order_id || '. Status set to Expired. Contact 88Staff for assistance.');
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20641, 'No record found for order ' || p_order_id || '.');
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/