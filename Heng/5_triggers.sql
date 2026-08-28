-- ==========================================
-- 5. TRIGGERS
-- ==========================================


-- ------------------------------------------
-- 5.1 DOB check on member (user) creation - must be at least 12 years old
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

-- ------------------------------------------
-- 5.2 Prevent outdated VIP renewals
-- ------------------------------------------
-- Exceptions and applications:
-- -20033: rejects VIP renewals with an expiry date in the past.
-- -20034: rejects VIP renewals where expiry is before activation.
-- -20036: rejects VIP renewals that downgrade an existing longer expiry.
CREATE OR REPLACE TRIGGER trg_vip_outdated_renewal
BEFORE INSERT ON vip_renewal
FOR EACH ROW
DECLARE
    v_current_max_expiry DATE;
BEGIN
    -- 1. Expiry must not be in the past
    IF :NEW.expiry_date < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20033, 'Cannot create an outdated VIP renewal with an expiry date in the past.');
    END IF;

    -- 2. Expiry must be after activation
    IF :NEW.expiry_date <= :NEW.activation_date THEN
        RAISE_APPLICATION_ERROR(-20034, 'VIP renewal expiry date must be after the activation date.');
    END IF;

    -- 3. New expiry must extend beyond current max expiry (no downgrade)
    SELECT MAX(expiry_date) INTO v_current_max_expiry
    FROM vip_renewal
    WHERE member_id = :NEW.member_id;

    IF v_current_max_expiry IS NOT NULL AND :NEW.expiry_date <= v_current_max_expiry THEN
        RAISE_APPLICATION_ERROR(-20036,
            'New VIP expiry date must exceed current expiry (' ||
            TO_CHAR(v_current_max_expiry, 'DD-MON-YYYY') || ').');
    END IF;

END trg_vip_outdated_renewal;
/
