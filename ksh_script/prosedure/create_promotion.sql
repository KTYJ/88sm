-- Drop dependent objects first
DROP PROCEDURE create_promotion;
DROP TYPE promotion_detail_list;
DROP TYPE promotion_detail_type;


CREATE TYPE promotion_detail_type AS OBJECT (
    item_id         VARCHAR2(10),
    discount_type   VARCHAR2(20),
    discount_value  NUMBER(8,2)
);
/

CREATE TYPE promotion_detail_list AS TABLE OF promotion_detail_type;
/

CREATE PROCEDURE create_promotion (
    p_promotion_name    IN promotion.promotion_name%TYPE,
    p_description       IN promotion.description%TYPE,
    p_start_date        IN promotion.start_date%TYPE,
    p_end_date          IN promotion.end_date%TYPE,
    p_promotion_details IN promotion_detail_list,
    p_promotion_id      OUT promotion.promotion_id%TYPE
)
IS
    v_item_count NUMBER;

    -- User-defined exceptions
    e_invalid_name          EXCEPTION;
    e_invalid_date          EXCEPTION;
    e_empty_details         EXCEPTION;
    e_item_not_found        EXCEPTION;
    e_invalid_discount_type EXCEPTION;
    e_invalid_discount      EXCEPTION;

BEGIN

    -- Generate promotion ID
    p_promotion_id := seq_promotion_id.NEXTVAL;

    -- ==========================================
    -- 1. Validate promotion name
    -- ==========================================
    IF p_promotion_name IS NULL THEN
        RAISE e_invalid_name;
    END IF;


    -- ==========================================
    -- 2. Validate promotion dates
    -- ==========================================
    IF p_start_date IS NULL
       OR p_end_date IS NULL
       OR p_end_date < p_start_date THEN

        RAISE e_invalid_date;
    END IF;


    -- ==========================================
    -- 3. Validate promotion details
    -- ==========================================
    IF p_promotion_details IS NULL
       OR p_promotion_details.COUNT = 0 THEN

        RAISE e_empty_details;
    END IF;


    -- ==========================================
    -- 4. Insert promotion
    -- ==========================================
    INSERT INTO promotion (
        promotion_id,
        promotion_name,
        description,
        status,
        start_date,
        end_date
    )
    VALUES (
        p_promotion_id,
        p_promotion_name,
        p_description,
        'Active',
        p_start_date,
        p_end_date
    );


    -- ==========================================
    -- 5. Insert promotion details
    -- ==========================================
    FOR i IN 1 .. p_promotion_details.COUNT
    LOOP

        -- Check item exists
        SELECT COUNT(*)
        INTO v_item_count
        FROM item
        WHERE item_id = p_promotion_details(i).item_id;

        IF v_item_count = 0 THEN
            RAISE e_item_not_found;
        END IF;


        -- Validate discount type
        IF p_promotion_details(i).discount_type
               NOT IN ('Percentage', 'Amount') THEN

            RAISE e_invalid_discount_type;
        END IF;


        -- Validate discount value
        IF p_promotion_details(i).discount_value < 0 THEN
            RAISE e_invalid_discount;
        END IF;


        -- Percentage cannot exceed 100
        IF p_promotion_details(i).discount_type = 'Percentage'
           AND p_promotion_details(i).discount_value > 100 THEN

            RAISE e_invalid_discount;
        END IF;


        -- Insert detail
        INSERT INTO promotion_details (
            promotion_id,
            item_id,
            discount_type,
            discount_value
        )
        VALUES (
            p_promotion_id,
            p_promotion_details(i).item_id,
            p_promotion_details(i).discount_type,
            p_promotion_details(i).discount_value
        );

    END LOOP;


    -- ==========================================
    -- 6. Commit
    -- ==========================================
    COMMIT;

    DBMS_OUTPUT.PUT_LINE(
        'SUCCESS: Promotion "' ||
        p_promotion_name ||
        '" created successfully.'
    );


EXCEPTION

    WHEN e_invalid_name THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            'ERROR: Promotion name cannot be empty.'
        );

    WHEN e_invalid_date THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            'ERROR: Promotion dates are invalid.'
        );

    WHEN e_empty_details THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            'ERROR: Promotion must contain at least one promotion detail.'
        );

    WHEN e_item_not_found THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            'ERROR: One of the specified items does not exist.'
        );

    WHEN e_invalid_discount_type THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            'ERROR: Discount type must be Percentage or Amount.'
        );

    WHEN e_invalid_discount THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            'ERROR: Discount value is invalid.'
        );

    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            'ERROR: Promotion ID already exists or the same item was added twice.'
        );

    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(
            'ERROR: ' || SQLERRM
        );

END create_promotion;
/