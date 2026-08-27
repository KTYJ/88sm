SET SERVEROUTPUT ON
SET PAGESIZE 200
SET LINESIZE 120
SET VERIFY OFF

COLUMN member_id FORMAT 9999999999 HEADING 'Member ID'
COLUMN name FORMAT A25 HEADING 'Name'
COLUMN ic FORMAT A15 HEADING 'IC'
COLUMN date_of_birth FORMAT A15 HEADING 'Date of Birth'

PROMPT ============================================================
PROMPT TEST 1: VALID IC AND MATCHING DOB
PROMPT ============================================================

INSERT INTO member (
    member_id,
    name,
    ic,
    email,
    date_of_birth
)
VALUES (
    9001,
    'Test Member 1',
    '010520-01-1234',
    'test001@email.com',
    TO_DATE('20-05-2001', 'DD-MM-YYYY')
);

COMMIT;

SELECT
    member_id,
    name,
    ic,
    TO_CHAR(date_of_birth, 'DD-MM-YYYY') AS date_of_birth
FROM member
WHERE member_id = 9001;


PROMPT ============================================================
PROMPT TEST 2: IC AND DOB DO NOT MATCH
PROMPT ============================================================

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


PROMPT ============================================================
PROMPT TEST 3: INVALID IC FORMAT
PROMPT ============================================================

INSERT INTO member (
    member_id,
    name,
    ic,
    email,
    date_of_birth
)
VALUES (
    9003,
    'Test Member 3',
    '010520011234',
    'test003@email.com',
    TO_DATE('20-05-2001', 'DD-MM-YYYY')
);


PROMPT ============================================================
PROMPT TEST 4: UPDATE DOB TO INCORRECT VALUE
PROMPT ============================================================

UPDATE member
SET date_of_birth = TO_DATE('25-05-2001', 'DD-MM-YYYY')
WHERE member_id = 9001;


PROMPT ============================================================
PROMPT TEST 5: UPDATE IC TO DIFFERENT DOB
PROMPT ============================================================

UPDATE member
SET ic = '020620-01-1234'
WHERE member_id = 9001;


PROMPT ============================================================
PROMPT FINAL MEMBER RECORD
PROMPT ============================================================

SELECT
    member_id,
    name,
    ic,
    TO_CHAR(date_of_birth, 'DD-MM-YYYY') AS date_of_birth
FROM member
WHERE member_id = 9001;


SET FEEDBACK ON

DELETE FROM member WHERE member_id IN (9001, 9002, 9003);