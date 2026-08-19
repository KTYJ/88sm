-- ==========================================
-- 1. DROP TABLES (Reverse Dependency Order)
-- ==========================================
DROP TABLE point_history CASCADE CONSTRAINTS;
DROP TABLE self_pickup CASCADE CONSTRAINTS;
DROP TABLE delivery CASCADE CONSTRAINTS;
DROP TABLE redemption CASCADE CONSTRAINTS;
DROP TABLE procurement CASCADE CONSTRAINTS;
DROP TABLE promotion_details CASCADE CONSTRAINTS;
DROP TABLE branch_stock CASCADE CONSTRAINTS;
DROP TABLE order_item CASCADE CONSTRAINTS;
DROP TABLE orders CASCADE CONSTRAINTS;
DROP TABLE promotion CASCADE CONSTRAINTS;
DROP TABLE supplier CASCADE CONSTRAINTS;
DROP TABLE item CASCADE CONSTRAINTS;
DROP TABLE delivery_company CASCADE CONSTRAINTS;
DROP TABLE staff CASCADE CONSTRAINTS;
DROP TABLE branch CASCADE CONSTRAINTS;
DROP TABLE member CASCADE CONSTRAINTS;
DROP TABLE voucher CASCADE CONSTRAINTS;

-- ==========================================
-- 2. PARENT TABLES (Independent)
-- ==========================================

CREATE TABLE voucher (
    voucher_id      VARCHAR2(10)      NOT NULL,
    voucher_type    VARCHAR2(20),
    voucher_value   NUMBER(8,2)     NOT NULL,
    description     VARCHAR2(255),
    exp_date        DATE,
    CONSTRAINT pk_voucher PRIMARY KEY (voucher_id),
    CONSTRAINT chk_voucher_type CHECK (voucher_type IN ('Percentage', 'Amount')),
    CONSTRAINT chk_voucher_value CHECK (voucher_value >= 0),
    CONSTRAINT chk_voucher_pct_cap CHECK ((voucher_type = 'Percentage' AND voucher_value BETWEEN 0 AND 100) OR (voucher_type = 'Amount' AND voucher_value >= 0))
);

-- Trigger to limit dob will be created after the table
CREATE TABLE member (
    member_id       NUMBER(10)      NOT NULL,
    name            VARCHAR2(100)   NOT NULL,
    ic              VARCHAR2(14)    NOT NULL UNIQUE,
    email           VARCHAR2(40)    UNIQUE,
    address         VARCHAR2(255),
    date_of_birth   DATE,
    expiry_date     DATE,
    points_balance  NUMBER(10)      DEFAULT 0,
    CONSTRAINT pk_member PRIMARY KEY (member_id),
    CONSTRAINT chk_member_ic CHECK (REGEXP_LIKE(ic, '^[0-9]{6}-[0-9]{2}-[0-9]{4}$')),
    CONSTRAINT chk_member_email CHECK (REGEXP_LIKE (email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')),
    CONSTRAINT chk_member_points CHECK (points_balance >= 0)
);

-- CREATE OR REPLACE TRIGGER trg_member_dob
-- BEFORE INSERT OR UPDATE ON member
-- FOR EACH ROW
-- BEGIN
--     IF :NEW.date_of_birth > SYSDATE THEN
--         RAISE_APPLICATION_ERROR(-20001, 'Date of birth cannot be in the future.');
--     END IF;
-- END;
-- /

CREATE TABLE branch (
    branch_id       NUMBER(10)      NOT NULL,
    branch_name     VARCHAR2(100)   NOT NULL,
    address         VARCHAR2(255),
    CONSTRAINT pk_branch PRIMARY KEY (branch_id)
);

CREATE TABLE staff (
    staff_id        NUMBER(10)      NOT NULL,
    branch_id       NUMBER(10)      NOT NULL,
    staff_name      VARCHAR2(100)   NOT NULL,
    position        VARCHAR2(50),
    contact_no      VARCHAR2(15),
    CONSTRAINT pk_staff PRIMARY KEY (staff_id),
    CONSTRAINT fk_staff_branch FOREIGN KEY (branch_id) REFERENCES branch (branch_id),
    CONSTRAINT chk_staff_contact CHECK (REGEXP_LIKE(contact_no, '^0[1-9][0-9]?-[0-9]{7,8}$'))
);

CREATE TABLE delivery_company (
    company_id      NUMBER(10)      NOT NULL,
    company_name    VARCHAR2(100)   NOT NULL,
    contact_no      VARCHAR2(15),
    delivery_charge NUMBER(8,2),
    CONSTRAINT pk_delivery_company PRIMARY KEY (company_id),
    CONSTRAINT chk_company_contact CHECK (REGEXP_LIKE(contact_no, '^0[1-9][0-9]?-[0-9]{7,8}$')),
    CONSTRAINT chk_delivery_charge CHECK (delivery_charge >= 0)
);

CREATE TABLE item (
    item_id         VARCHAR2(10)    NOT NULL,
    item_name       VARCHAR2(100)   NOT NULL,
    description     VARCHAR2(255),
    unit_price      NUMBER(8,2)     NOT NULL,
    category        VARCHAR2(50),
    CONSTRAINT pk_item PRIMARY KEY (item_id),
    CONSTRAINT chk_item_price CHECK (unit_price >= 0)
);

CREATE TABLE supplier (
    supplier_id     NUMBER(10)      NOT NULL,
    supplier_name   VARCHAR2(100)   NOT NULL,
    contact_person  VARCHAR2(100),
    phone_no        VARCHAR2(15),
    email           VARCHAR2(100),
    address         VARCHAR2(255),
    CONSTRAINT pk_supplier PRIMARY KEY (supplier_id),
    CONSTRAINT chk_supplier_phone CHECK (REGEXP_LIKE(phone_no, '^0[1-9][0-9]?-[0-9]{7,8}$')),
    CONSTRAINT chk_supplier_email CHECK (REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'))
);

CREATE TABLE promotion (
    promotion_id    NUMBER(10)      NOT NULL,
    promotion_name  VARCHAR2(100)   NOT NULL,
    description     VARCHAR2(255),
    status          VARCHAR2(20),
    start_date      DATE,
    end_date        DATE,
    CONSTRAINT pk_promotion PRIMARY KEY (promotion_id),
    CONSTRAINT chk_promotion_status CHECK (status IN ('Active', 'Inactive', 'Expired')),
    CONSTRAINT chk_promotion_dates CHECK (end_date >= start_date)
);

-- ==========================================
-- 3. TRANSACTION & ASSOCIATIVE TABLES
-- ==========================================

CREATE TABLE orders (
    order_id        NUMBER(10)      NOT NULL,
    member_id       NUMBER(10),
    staff_id        NUMBER(10),
    branch_id       NUMBER(10)      NOT NULL,
    order_date      TIMESTAMP       DEFAULT SYSDATE NOT NULL,
    order_type      VARCHAR2(20),
    CONSTRAINT pk_orders PRIMARY KEY (order_id),
    CONSTRAINT fk_orders_member FOREIGN KEY (member_id) REFERENCES member (member_id),
    CONSTRAINT fk_orders_staff FOREIGN KEY (staff_id) REFERENCES staff (staff_id),
    CONSTRAINT fk_orders_branch FOREIGN KEY (branch_id) REFERENCES branch (branch_id),
    CONSTRAINT chk_order_type CHECK (order_type IN ('Delivery', 'Self Pickup', 'In Store'))
);

CREATE TABLE order_item (
    order_id        NUMBER(10)      NOT NULL,
    item_id         VARCHAR2(10)    NOT NULL,
    quantity        NUMBER(6)       NOT NULL,
    unit_price      NUMBER(8,2)     NOT NULL,
    CONSTRAINT pk_order_item PRIMARY KEY (order_id, item_id),
    CONSTRAINT fk_orderitem_order FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT fk_orderitem_item FOREIGN KEY (item_id) REFERENCES item (item_id),
    CONSTRAINT chk_orderitem_qty CHECK (quantity > 0),
    CONSTRAINT chk_orderitem_price CHECK (unit_price >= 0)
);

CREATE TABLE branch_stock (
    branch_id         NUMBER(10)    NOT NULL,
    item_id           VARCHAR2(10)  NOT NULL,
    stock_quantity    NUMBER(8)     DEFAULT 0,
    last_restock_date DATE          DEFAULT SYSDATE,
    CONSTRAINT pk_branch_stock PRIMARY KEY (branch_id, item_id),
    CONSTRAINT fk_branchstock_branch FOREIGN KEY (branch_id) REFERENCES branch (branch_id),
    CONSTRAINT fk_branchstock_item FOREIGN KEY (item_id) REFERENCES item (item_id),
    CONSTRAINT chk_stock_qty CHECK (stock_quantity >= 0)
);

CREATE TABLE promotion_details (
    promotion_id    NUMBER(10)      NOT NULL,
    item_id         VARCHAR2(10)    NOT NULL,
    discount_type   VARCHAR2(20),
    discount_value  NUMBER(8,2),
    CONSTRAINT pk_promotion_details PRIMARY KEY (promotion_id, item_id),
    CONSTRAINT fk_promodetails_promotion FOREIGN KEY (promotion_id) REFERENCES promotion (promotion_id),
    CONSTRAINT fk_promodetails_item FOREIGN KEY (item_id) REFERENCES item (item_id),
    CONSTRAINT chk_discount_type CHECK (discount_type IN ('Percentage', 'Amount')),
    CONSTRAINT chk_discount_value CHECK (discount_value >= 0),
    CONSTRAINT chk_discount_pct_cap CHECK ((discount_type = 'Percentage' AND discount_value BETWEEN 0 AND 100) OR (discount_type = 'Amount' AND discount_value >= 0))
);

CREATE TABLE procurement (
    procurement_id   NUMBER(10)      NOT NULL,
    item_id          VARCHAR2(10)    NOT NULL,
    supplier_id      NUMBER(10)      NOT NULL,
    branch_id        NUMBER(10)      NOT NULL,                    -- which branch ordered it
    quantity         NUMBER(8)       NOT NULL,                    -- how many units ordered
    unit_cost        NUMBER(8,2)     NOT NULL,                    -- cost per unit from supplier
    procurement_date DATE            DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_procurement PRIMARY KEY (procurement_id),
    CONSTRAINT fk_procurement_item     FOREIGN KEY (item_id)     REFERENCES item (item_id),
    CONSTRAINT fk_procurement_supplier FOREIGN KEY (supplier_id) REFERENCES supplier (supplier_id),
    CONSTRAINT fk_procurement_branch   FOREIGN KEY (branch_id)   REFERENCES branch (branch_id),
    CONSTRAINT chk_procurement_qty     CHECK (quantity > 0),
    CONSTRAINT chk_procurement_cost    CHECK (unit_cost >= 0)
);


CREATE TABLE redemption (
    redemption_id   NUMBER(10)      NOT NULL,
    voucher_id      VARCHAR2(10)      NOT NULL,
    order_id        NUMBER(10)      NOT NULL,
    redeemed_date   TIMESTAMP       DEFAULT SYSDATE,
    CONSTRAINT pk_redemption PRIMARY KEY (redemption_id),
    CONSTRAINT fk_redemption_voucher FOREIGN KEY (voucher_id) REFERENCES voucher (voucher_id),
    CONSTRAINT fk_redemption_order FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

-- ==========================================
-- 4. CHILD TABLES (Specific extensions)
-- ==========================================

CREATE TABLE delivery (
    delivery_id      NUMBER(10)     NOT NULL,
    order_id         NUMBER(10)     NOT NULL UNIQUE,
    company_id       NUMBER(10)     NOT NULL,
    delivery_address VARCHAR2(255)  NOT NULL,
    delivery_date    TIMESTAMP,
    delivery_status  VARCHAR2(20)   DEFAULT 'Pending',
    CONSTRAINT pk_delivery PRIMARY KEY (delivery_id),
    CONSTRAINT fk_delivery_order FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT fk_delivery_company FOREIGN KEY (company_id) REFERENCES delivery_company (company_id),
    CONSTRAINT chk_delivery_status CHECK (delivery_status IN ('Delivered', 'Out for Delivery', 'Pending', 'Preparing', 'Cancelled'))
);

CREATE TABLE self_pickup (
    pickup_id       NUMBER(10)      NOT NULL,
    order_id        NUMBER(10)      NOT NULL UNIQUE,
    pickup_datetime TIMESTAMP,
    pickup_status   VARCHAR2(20)    DEFAULT 'Preparing',
    pickup_exp_date TIMESTAMP,
    CONSTRAINT pk_self_pickup PRIMARY KEY (pickup_id),
    CONSTRAINT fk_pickup_order FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT chk_pickup_status CHECK (pickup_status IN ('Completed', 'Ready', 'Preparing', 'Expired', 'Rescheduled', 'Cancelled'))
);

CREATE TABLE point_history (
    point_redemption_id NUMBER(10)  NOT NULL,
    member_id           NUMBER(10)  NOT NULL,
    amount              NUMBER(10)  NOT NULL,
    transaction_type                VARCHAR2(10),
    redemption_date     TIMESTAMP   DEFAULT SYSDATE,
    CONSTRAINT pk_point_history PRIMARY KEY (point_redemption_id),
    CONSTRAINT fk_pointhistory_member FOREIGN KEY (member_id) REFERENCES member (member_id),
    CONSTRAINT chk_point_type CHECK (transaction_type IN ('Earned', 'Used')),
    CONSTRAINT chk_point_amount CHECK (amount > 0)
);

COMMIT;