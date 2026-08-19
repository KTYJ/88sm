CREATE OR REPLACE TRIGGER trg_member_ic_dob
BEFORE INSERT OR UPDATE OF ic, date_of_birth
ON member
FOR EACH ROW
DECLARE
    v_ic_dob DATE;
BEGIN

    -- Extract DOB from IC
    BEGIN

        v_ic_dob := TO_DATE(
            SUBSTR(:NEW.ic, 1, 6),
            'RRMMDD'
        );

    EXCEPTION

        WHEN OTHERS THEN

            RAISE_APPLICATION_ERROR(
                -20011,
                'Invalid date encoded in IC.'
            );

    END;


    -- Compare IC DOB with date_of_birth
    IF :NEW.date_of_birth IS NOT NULL
       AND TRUNC(v_ic_dob) <> TRUNC(:NEW.date_of_birth) THEN

        RAISE_APPLICATION_ERROR(
            -20012,
            'IC date of birth does not match date_of_birth.'
        );

    END IF;

END;
/