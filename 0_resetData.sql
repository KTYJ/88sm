-- ==========================================
-- CLEAR ALL DATA (Reverse Dependency Order)
-- ==========================================

-- 1. Child tables (Level 4)
DELETE FROM point_history;
DELETE FROM self_pickup;
DELETE FROM delivery;
DELETE FROM redemption;

-- 2. Transaction / Associative tables (Level 3)
DELETE FROM procurement;
DELETE FROM promotion_details;
DELETE FROM branch_stock;
DELETE FROM order_item;

-- 3. Dependent parent tables (Level 2)
DELETE FROM orders;
DELETE FROM staff;

-- 4. Independent parent tables (Level 1)
DELETE FROM promotion;
DELETE FROM supplier;
DELETE FROM item;
DELETE FROM delivery_company;
DELETE FROM branch;
DELETE FROM member;
DELETE FROM voucher;

-- 5. DROP ALL SEQUENCES
DROP SEQUENCE seq_voucher_id;
DROP SEQUENCE seq_branch_id;
DROP SEQUENCE seq_company_id;
DROP SEQUENCE seq_supplier_id;
DROP SEQUENCE seq_staff_id;
DROP SEQUENCE seq_promotion_id;
DROP SEQUENCE seq_member_id;
DROP SEQUENCE seq_point_history_id;
DROP SEQUENCE seq_procurement_id;
DROP SEQUENCE seq_redemption_id;
DROP SEQUENCE seq_pickup_id;
DROP SEQUENCE seq_delivery_id;
DROP SEQUENCE seq_order_id;

COMMIT;
