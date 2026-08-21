-- ==========================================
-- CLEAR ALL DATA & OBJECTS
-- (Assuming starting from scratch)
-- ==========================================

BEGIN
    -- 1. Drop all procedures, functions, packages, views, triggers, sequences, and types
    FOR obj IN (
        SELECT object_name, object_type 
        FROM user_objects 
        WHERE object_type IN ('PROCEDURE', 'FUNCTION', 'PACKAGE', 'VIEW', 'TRIGGER', 'SEQUENCE', 'TYPE')
    ) LOOP
        BEGIN
            IF obj.object_type = 'TYPE' THEN
                EXECUTE IMMEDIATE 'DROP ' || obj.object_type || ' "' || obj.object_name || '" FORCE';
            ELSE
                EXECUTE IMMEDIATE 'DROP ' || obj.object_type || ' "' || obj.object_name || '"';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Failed to drop ' || obj.object_type || ' ' || obj.object_name || ': ' || SQLERRM);
        END;
    END LOOP;

    -- 2. Drop all tables
    FOR tbl IN (
        SELECT table_name 
        FROM user_tables
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE "' || tbl.table_name || '" CASCADE CONSTRAINTS';
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Failed to drop TABLE ' || tbl.table_name || ': ' || SQLERRM);
        END;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('All data has been cleared');
END;
/