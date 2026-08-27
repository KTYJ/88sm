-- ==========================================
-- 5. TRIGGERS
-- ==========================================

-- ------------------------------------------
-- 5.1 Block expired members from placing orders or
-- earning/redeeming points
-- ------------------------------------------
-- Exceptions and applications:
-- -20030: prevents an expired member from inserting an order.
CREATE OR REPLACE TRIGGER trg_block_expired_member_order
BEFORE INSERT ON orders
FOR EACH ROW
DECLARE
    v_expiry_date vip_renewal.expiry_date%TYPE;
BEGIN
    IF :NEW.member_id IS NOT NULL THEN
        SELECT MAX(expiry_date) INTO v_expiry_date
        FROM vip_renewal
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
-- Exception and application:
-- -20033: prevents an expired member from earning or using points.
DECLARE
    v_member_id orders.member_id%TYPE;
    v_expiry_date vip_renewal.expiry_date%TYPE;
BEGIN
    IF :NEW.order_id IS NOT NULL THEN
        SELECT member_id INTO v_member_id
        FROM orders
        WHERE order_id = :NEW.order_id;

        IF v_member_id IS NOT NULL THEN
            SELECT MAX(expiry_date) INTO v_expiry_date
            FROM vip_renewal
            WHERE member_id = v_member_id;
        END IF;
    END IF;

    IF v_member_id IS NOT NULL
       AND v_expiry_date IS NOT NULL
       AND v_expiry_date < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20033, 'Cannot ' ||
                                 CASE :NEW.transaction_type
                                     WHEN 'Earned' THEN 'earn'
                                     WHEN 'Used'   THEN 'redeem'
                                     ELSE LOWER(:NEW.transaction_type)
                                 END ||
                                 ' points: member ' || v_member_id ||
                                 ' membership expired on ' || TO_CHAR(v_expiry_date, 'DD-MON-YYYY') || '.');
    END IF;
END trg_expired_member_points;
/


-- ------------------------------------------
-- 5.2 DOB check on member (user) creation - must be at least 12 years old
-- ------------------------------------------
-- Exceptions and applications:
-- -20031: rejects a future date of birth.
-- -20032: rejects members younger than 12 years old.
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
