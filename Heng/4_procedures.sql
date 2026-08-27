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
    v_available         branch_stock.stock_quantity%TYPE;
    v_item_name         item.item_name%TYPE;
    v_from_branch_name  branch.branch_name%TYPE;
    v_to_branch_name    branch.branch_name%TYPE;
BEGIN
    IF p_from_branch = p_to_branch THEN
        RAISE_APPLICATION_ERROR(-20010, 'Source and destination branch cannot be the same.');
    END IF;

    IF p_quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'Transfer quantity must be greater than zero.');
    END IF;

    -- Multi-table lookup (old-style WHERE join) for descriptive names used in logging
    SELECT i.item_name, bf.branch_name, bt.branch_name
    INTO v_item_name, v_from_branch_name, v_to_branch_name
    FROM item i, branch bf, branch bt
    WHERE i.item_id = p_item_id
      AND bf.branch_id = p_from_branch
      AND bt.branch_id = p_to_branch;

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

    DBMS_OUTPUT.PUT_LINE('Transferred ' || p_quantity || ' x ' || v_item_name ||
                          ' from ' || v_from_branch_name || ' to ' || v_to_branch_name || '.');
    DBMS_OUTPUT.PUT_LINE('Stock distribution for ' || v_item_name || ' across branches:');

    FOR dist_rec IN (
        SELECT b.branch_id, b.branch_name, SUM(bs.stock_quantity) AS branch_total
        FROM branch_stock bs
        JOIN branch b ON b.branch_id = bs.branch_id
        WHERE bs.item_id = p_item_id
        GROUP BY b.branch_id, b.branch_name
        HAVING SUM(bs.stock_quantity) >= 0
        ORDER BY branch_total DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || dist_rec.branch_name || ': ' || dist_rec.branch_total);
    END LOOP;

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
    v_procurement_id  procurement.procurement_id%TYPE;
    v_item_name       item.item_name%TYPE;
    v_supplier_name   supplier.supplier_name%TYPE;
    v_branch_name     branch.branch_name%TYPE;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE_APPLICATION_ERROR(-20020, 'Procurement quantity must be greater than zero.');
    END IF;

    IF p_unit_cost < 0 THEN
        RAISE_APPLICATION_ERROR(-20021, 'Unit cost cannot be negative.');
    END IF;

    -- Multi-table lookup (old-style WHERE join) for descriptive names used in logging
    SELECT i.item_name, s.supplier_name, b.branch_name
    INTO v_item_name, v_supplier_name, v_branch_name
    FROM item i, supplier s, branch b
    WHERE i.item_id = p_item_id
      AND s.supplier_id = p_supplier_id
      AND b.branch_id = p_branch_id;

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

    DBMS_OUTPUT.PUT_LINE('Procurement recorded: ' || p_quantity || ' x ' || v_item_name ||
                          ' from ' || v_supplier_name || ' for ' || v_branch_name || '.');
    DBMS_OUTPUT.PUT_LINE('Supplier comparison for ' || v_item_name || ':');

    FOR sup_rec IN (
        SELECT s.supplier_id, s.supplier_name,
               COUNT(p.procurement_id)    AS times_ordered,
               SUM(p.quantity)            AS total_quantity,
               ROUND(AVG(p.unit_cost), 2) AS avg_cost
        FROM procurement p
        JOIN supplier s ON s.supplier_id = p.supplier_id
        WHERE p.item_id = p_item_id
        GROUP BY s.supplier_id, s.supplier_name
        HAVING COUNT(p.procurement_id) >= 1
        ORDER BY avg_cost ASC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || sup_rec.supplier_name || ': ' || sup_rec.times_ordered ||
                              ' orders, avg cost ' || sup_rec.avg_cost);
    END LOOP;

    COMMIT;
END proc_submit_procurement;
/
