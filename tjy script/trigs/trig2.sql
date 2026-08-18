SET DEFINE OFF;

-- =============================================================================
-- TRIGGER 2: trg_points_balance
-- by TAN JIN YUAN
-- Description: Automatically updates member's points_balance whenever a new
--              point_history record is inserted. Includes consistency checks
--              for amount validity, transaction type validity, member existence,
--              and sufficient points balance when using points.
-- =============================================================================
DROP TRIGGER trg_points_balance;
CREATE OR REPLACE TRIGGER trg_points_balance
AFTER INSERT ON point_history
FOR EACH ROW
DECLARE
    v_current_points  member.points_balance%TYPE;
BEGIN
    -- 1. Check amount validity
    IF :NEW.amount IS NULL OR :NEW.amount <= 0 THEN
        RAISE_APPLICATION_ERROR(-20020, 'Point transaction amount must be greater than zero.');
    END IF;

    -- 2. Check transaction type validity
    IF :NEW.transaction_type NOT IN ('Earned', 'Used') THEN
        RAISE_APPLICATION_ERROR(-20021, 'Invalid transaction type: ' || :NEW.transaction_type || '. Must be ''Earned'' or ''Used''.');
    END IF;

    -- 3. Verify member exists and retrieve current points balance
    SELECT MAX(points_balance) INTO v_current_points
    FROM   member
    WHERE  member_id = :NEW.member_id;

    IF v_current_points IS NULL THEN
        RAISE_APPLICATION_ERROR(-20022, 'Invalid member_id (' || :NEW.member_id || ') — record does not exist in member table.');
    END IF;

    -- 4. Check for sufficient points if transaction type is 'Used'
    IF :NEW.transaction_type = 'Used' AND v_current_points < :NEW.amount THEN
        RAISE_APPLICATION_ERROR(-20023, 'Insufficient points for member ' || :NEW.member_id || '. Available: ' || v_current_points || ', Required: ' || :NEW.amount || '.');
    END IF;

    -- 5. Perform points update
    IF :NEW.transaction_type = 'Earned' THEN
        UPDATE member
        SET    points_balance = points_balance + :NEW.amount
        WHERE  member_id = :NEW.member_id;
        DBMS_OUTPUT.PUT_LINE('trg_points_balance: Successfully added ' || :NEW.amount || ' points to member ' || :NEW.member_id || '.');
    ELSIF :NEW.transaction_type = 'Used' THEN
        UPDATE member
        SET    points_balance = points_balance - :NEW.amount
        WHERE  member_id = :NEW.member_id;
        DBMS_OUTPUT.PUT_LINE('trg_points_balance: Successfully deducted ' || :NEW.amount || ' points from member ' || :NEW.member_id || '.');
    END IF;

END trg_points_balance;
/
