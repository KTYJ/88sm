-- ==========================================
-- 5. TRIGGERS
-- ==========================================

-- ------------------------------------------
-- 5.1 Block staff deletion when they have orders
-- ------------------------------------------
CREATE OR REPLACE TRIGGER trg_block_staff_deletion
BEFORE DELETE ON staff
FOR EACH ROW
DECLARE
    v_order_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_order_count
    FROM orders
    WHERE staff_id = :OLD.staff_id;

    IF v_order_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20030, 'Cannot delete staff: staff member has existing orders.');
    END IF;
END trg_block_staff_deletion;
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
