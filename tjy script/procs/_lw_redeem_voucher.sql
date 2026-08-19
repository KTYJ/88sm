CREATE OR REPLACE PROCEDURE sp_redeem_voucher (
    p_voucher_id  IN voucher.voucher_id%TYPE,
    p_order_id    IN redemption.order_id%TYPE,
    p_member_id   IN orders.member_id%TYPE
) AS
    v_exp_date     voucher.exp_date%TYPE;
    v_order_member orders.member_id%TYPE;
    v_member_cnt   NUMBER;
    v_redeemed      NUMBER;
    v_redemption_id NUMBER;
BEGIN
    -- Validation 1: voucher must exist and not be expired
    SELECT exp_date INTO v_exp_date
    FROM   voucher
    WHERE  voucher_id = p_voucher_id;

    IF v_exp_date < SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20040, 'This voucher has expired on ' ||
            TO_CHAR(v_exp_date, 'DD-MM-YYYY'));
    END IF;

    -- Validation 2: member must exist
    SELECT COUNT(*)
    INTO   v_member_cnt
    FROM   member
    WHERE  member_id = p_member_id;

    IF v_member_cnt = 0 THEN
        RAISE_APPLICATION_ERROR(-20041, 'Member ' || p_member_id || ' does not exist.');
    END IF;

    -- Validation 3: order must belong to this member (if member order)
    SELECT member_id INTO v_order_member
    FROM   orders
    WHERE  order_id = p_order_id;

    IF v_order_member IS NOT NULL AND v_order_member <> p_member_id THEN
        RAISE_APPLICATION_ERROR(-20042, 'This order does not belong to the member.');
    END IF;

    -- Validation 4: one-time use - this member must not have
    -- redeemed this voucher before
    SELECT COUNT(*) INTO v_redeemed
    FROM   redemption r
    JOIN   orders o ON r.order_id = o.order_id
    WHERE  r.voucher_id = p_voucher_id
    AND    o.member_id = p_member_id;

    IF v_redeemed > 0 THEN
        RAISE_APPLICATION_ERROR(-20044,
            'Member ' || p_member_id || ' has already redeemed voucher ' ||
            p_voucher_id || '. Each voucher can be redeemed only once per member.');
    END IF;

    -- Insert redemption record (auto-generate to avoid PK collision)
    SELECT NVL(MAX(redemption_id), 0) + 1 INTO v_redemption_id FROM redemption;

    INSERT INTO redemption (redemption_id, voucher_id, order_id, redeemed_date)
    VALUES (v_redemption_id,
            p_voucher_id, p_order_id, SYSTIMESTAMP);

    DBMS_OUTPUT.PUT_LINE('Voucher ' || p_voucher_id ||
        ' redeemed for order ' || p_order_id);
    COMMIT;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20043, 'Voucher or order not found.');
    WHEN OTHERS THEN
        IF SQLCODE BETWEEN -20999 AND -20000 THEN
            RAISE;
        ELSE
            RAISE_APPLICATION_ERROR(-20905, 'sp_redeem_voucher failed: ' || SQLERRM);
        END IF;
END;
/
