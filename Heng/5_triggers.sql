-- ==========================================
-- 5. TRIGGERS
-- ==========================================

-- ------------------------------------------
-- 5.1 Block expired members from placing orders or
-- earning/redeeming points
-- ------------------------------------------
DROP TRIGGER trg_block_staff_deletion;

CREATE OR REPLACE TRIGGER trg_block_expired_member_order
BEFORE INSERT ON orders
FOR EACH ROW
DECLARE
    v_expiry_date member.expiry_date%TYPE;
BEGIN
    IF :NEW.member_id IS NOT NULL THEN
        SELECT expiry_date INTO v_expiry_date
        FROM member
        WHERE member_id = :NEW.member_id;

        IF v_expiry_date IS NOT NULL AND v_expiry_date < TRUNC(SYSDATE) THEN
            RAISE_APPLICATION_ERROR(-20030, 'Cannot place order: member ' || :NEW.member_id ||
                                     ' membership expired on ' || TO_CHAR(v_expiry_date, 'DD-MON-YYYY') || '.');
        END IF;
    END IF;
END trg_block_expired_member_order;
/

CREATE OR REPLACE TRIGGER trg_expired_member_points
BEFORE INSERT ON point_history
FOR EACH ROW
DECLARE
    v_expiry_date member.expiry_date%TYPE;
BEGIN
    SELECT expiry_date INTO v_expiry_date
    FROM member
    WHERE member_id = :NEW.member_id;

    IF v_expiry_date IS NOT NULL AND v_expiry_date < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20033, 'Cannot ' ||
                                 CASE :NEW.transaction_type
                                     WHEN 'Earned' THEN 'earn'
                                     WHEN 'Used'   THEN 'redeem'
                                     ELSE LOWER(:NEW.transaction_type)
                                 END ||
                                 ' points: member ' || :NEW.member_id ||
                                 ' membership expired on ' || TO_CHAR(v_expiry_date, 'DD-MON-YYYY') || '.');
    END IF;
END trg_expired_member_points;
/


-- ------------------------------------------
-- 5.2 DOB check on member (user) creation - must be at least 12 years old
-- ------------------------------------------
CREATE OR REPLACE TRIGGER trg_member_dob_check
BEFORE INSERT OR UPDATE OF date_of_birth ON member
FOR EACH ROW
BEGIN
    IF :NEW.date_of_birth IS NOT NULL THEN
        IF :NEW.date_of_birth > SYSDATE THEN
            RAISE_APPLICATION_ERROR(-20031, 'Date of birth cannot be in the future.');
        END IF;

        IF MONTHS_BETWEEN(SYSDATE, :NEW.date_of_birth) / 12 < 12 THEN
            RAISE_APPLICATION_ERROR(-20032, 'Member must be at least 12 years old.');
        END IF;
    END IF;
END trg_member_dob_check;
/
