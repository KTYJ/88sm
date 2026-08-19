CREATE OR REPLACE TRIGGER trg_promotion_discount_price
BEFORE INSERT OR UPDATE OF item_id, discount_type, discount_value
ON promotion_details
FOR EACH ROW
DECLARE
    v_unit_price item.unit_price%TYPE;
BEGIN

    -- Get item's current unit price
    SELECT unit_price
    INTO v_unit_price
    FROM item
    WHERE item_id = :NEW.item_id;


    -- Only Amount discount is compared with item price
    IF :NEW.discount_type = 'Amount'
       AND :NEW.discount_value > v_unit_price THEN

        RAISE_APPLICATION_ERROR(
            -20020,
            'Promotion discount cannot be higher than the item unit price.'
        );

    END IF;


EXCEPTION

    WHEN NO_DATA_FOUND THEN

        RAISE_APPLICATION_ERROR(
            -20021,
            'Item does not exist.'
        );

END;
/