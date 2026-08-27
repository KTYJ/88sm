SET SERVEROUTPUT ON
SET PAGESIZE 200
SET LINESIZE 120
SET FEEDBACK ON
SET VERIFY OFF

INSERT INTO member (
    member_id,
    name,
    ic,
    email,
    date_of_birth
)
VALUES (
    9002,
    'Test Member 2',
    '010520-01-5678',
    'test002@email.com',
    TO_DATE('21-05-2001', 'DD-MM-YYYY')
);