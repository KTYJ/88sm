SET SERVEROUTPUT ON
SET LINESIZE 150
SET PAGESIZE 50

BEGIN
    sp_create_order_items(
        p_order_id    => 100001,
        p_order_items => order_item_list(
            order_item_type('BA001', 2),
            order_item_type('COF001', 3)
        ),
        p_use_voucher => 0
    );
END;
/