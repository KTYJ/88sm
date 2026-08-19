-- ==========================================
-- 4. PROCEDURES
-- ==========================================

-- ------------------------------------------
-- 4.1 Transfer stock between branches
-- ------------------------------------------
CREATE OR REPLACE PROCEDURE proc_transfer_stock (
    p_from_branch   IN branch_stock.branch_id%TYPE,
    p_to_branch     IN branch_stock.branch_id%TYPE,
    p_item_id       IN branch_stock.item_id%TYPE,
    p_quantity      IN branch_stock.stock_quantity%TYPE
) AS
    v_available branch_stock.stock_quantity%TYPE;
BEGIN
    IF p_from_branch = p_to_branch THEN
        RAISE_APPLICATION_ERROR(-20010, 'Source and destination branch cannot be the same.');
    END IF;

    IF p_quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'Transfer quantity must be greater than zero.');
    END IF;

    -- Lock and check source stock
    BEGIN
        SELECT stock_quantity INTO v_available
        FROM branch_stock
        WHERE branch_id = p_from_branch AND item_id = p_item_id
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20012, 'Item not stocked at source branch.');
    END;

    IF v_available < p_quantity THEN
        RAISE_APPLICATION_ERROR(-20013, 'Insufficient stock at source branch for transfer.');
    END IF;

    -- Deduct from source
    UPDATE branch_stock
    SET stock_quantity = stock_quantity - p_quantity
    WHERE branch_id = p_from_branch AND item_id = p_item_id;

    -- Add to destination (create row if it doesn't exist yet)
    UPDATE branch_stock
    SET stock_quantity = stock_quantity + p_quantity,
        last_restock_date = SYSDATE
    WHERE branch_id = p_to_branch AND item_id = p_item_id;

    IF SQL%ROWCOUNT = 0 THEN
        INSERT INTO branch_stock (branch_id, item_id, stock_quantity, last_restock_date)
        VALUES (p_to_branch, p_item_id, p_quantity, SYSDATE);
    END IF;

    COMMIT;
END proc_transfer_stock;
/


-- ------------------------------------------
-- 4.2 Submit stock procurement for a branch / item
-- ------------------------------------------
CREATE OR REPLACE PROCEDURE proc_submit_procurement (
    p_branch_id     IN procurement.branch_id%TYPE,
    p_item_id       IN procurement.item_id%TYPE,
    p_supplier_id   IN procurement.supplier_id%TYPE,
    p_quantity      IN procurement.quantity%TYPE,
    p_unit_cost     IN procurement.unit_cost%TYPE
) AS
    v_procurement_id procurement.procurement_id%TYPE;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20020, 'Procurement quantity must be greater than zero.');
    END IF;

    IF p_unit_cost < 0 THEN
        RAISE_APPLICATION_ERROR(-20021, 'Unit cost cannot be negative.');
    END IF;

    v_procurement_id := seq_procurement_id.NEXTVAL;

    INSERT INTO procurement (
        procurement_id, item_id, supplier_id, branch_id,
        quantity, unit_cost, procurement_date
    ) VALUES (
        v_procurement_id, p_item_id, p_supplier_id, p_branch_id,
        p_quantity, p_unit_cost, SYSDATE
    );

    -- Receive the procured stock straight into the branch's stock
    UPDATE branch_stock
    SET stock_quantity = stock_quantity + p_quantity,
        last_restock_date = SYSDATE
    WHERE branch_id = p_branch_id AND item_id = p_item_id;

    IF SQL%ROWCOUNT = 0 THEN
        INSERT INTO branch_stock (branch_id, item_id, stock_quantity, last_restock_date)
        VALUES (p_branch_id, p_item_id, p_quantity, SYSDATE);
    END IF;

    COMMIT;
END proc_submit_procurement;
/
