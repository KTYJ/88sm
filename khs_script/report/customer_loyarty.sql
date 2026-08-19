CREATE OR REPLACE PROCEDURE sp_customer_rfm_report
(
    p_branch_id       IN branch.branch_id%TYPE,
    p_last_order_date IN DATE DEFAULT NULL,
    p_recency         IN NUMBER DEFAULT NULL,
    p_frequency       IN NUMBER DEFAULT NULL,
    p_monetary        IN NUMBER DEFAULT NULL,
    p_ranking         IN NUMBER DEFAULT NULL
)
IS
    CURSOR c_customer (p_branch_id branch.branch_id%TYPE) IS
        SELECT DISTINCT
            m.member_id,
            m.name
        FROM member m
        JOIN orders o
            ON m.member_id = o.member_id
        WHERE o.branch_id = p_branch_id
          AND (p_last_order_date IS NULL OR o.order_date > p_last_order_date)
        ORDER BY m.member_id;

    CURSOR c_order (p_member_id member.member_id%TYPE,
                    p_branch_id branch.branch_id%TYPE) IS
        SELECT order_id, order_date
        FROM orders
        WHERE member_id = p_member_id
          AND branch_id = p_branch_id
          AND (p_last_order_date IS NULL OR order_date > p_last_order_date)
        ORDER BY order_date;

    CURSOR c_order_item (p_order_id order_item.order_id%TYPE) IS
        SELECT quantity, unit_price
        FROM order_item
        WHERE order_id = p_order_id;

    TYPE rfm_record IS RECORD (
        member_id   member.member_id%TYPE,
        member_name member.name%TYPE,
        recency     NUMBER,
        frequency   NUMBER,
        monetary    NUMBER,
        rfm_score   NUMBER
    );

    TYPE rfm_table IS TABLE OF rfm_record INDEX BY PLS_INTEGER;

    v_rfm             rfm_table;
    v_branch_name     branch.branch_name%TYPE;
    v_member_id       member.member_id%TYPE;
    v_member_name     member.name%TYPE;
    v_order_id        orders.order_id%TYPE;
    v_order_date      orders.order_date%TYPE;
    v_quantity        order_item.quantity%TYPE;
    v_unit_price      order_item.unit_price%TYPE;
    v_last_order_date orders.order_date%TYPE;
    v_recency         NUMBER;
    v_frequency       NUMBER;
    v_monetary        NUMBER;
    v_rfm_score       NUMBER;
    v_customer_count  NUMBER := 0;
    v_temp            rfm_record;

BEGIN
    IF p_branch_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20010, 'Branch ID is required.');
    END IF;

    IF p_ranking IS NOT NULL AND p_ranking <= 0 THEN
        RAISE_APPLICATION_ERROR(-20012, 'Minimum RFM score must be greater than 0.');
    END IF;

    SELECT branch_name
    INTO v_branch_name
    FROM branch
    WHERE branch_id = p_branch_id;

    OPEN c_customer(p_branch_id);
    LOOP
        FETCH c_customer INTO v_member_id, v_member_name;
        EXIT WHEN c_customer%NOTFOUND;

        v_last_order_date := NULL;
        v_frequency := 0;
        v_monetary := 0;

        OPEN c_order(v_member_id, p_branch_id);
        LOOP
            FETCH c_order INTO v_order_id, v_order_date;
            EXIT WHEN c_order%NOTFOUND;

            v_frequency := v_frequency + 1;

            IF v_last_order_date IS NULL OR v_order_date > v_last_order_date THEN
                v_last_order_date := v_order_date;
            END IF;

            OPEN c_order_item(v_order_id);
            LOOP
                FETCH c_order_item INTO v_quantity, v_unit_price;
                EXIT WHEN c_order_item%NOTFOUND;
                v_monetary := v_monetary + (v_quantity * v_unit_price);
            END LOOP;
            CLOSE c_order_item;
        END LOOP;
        CLOSE c_order;

        v_recency := TRUNC(SYSDATE) - TRUNC(v_last_order_date);

        v_rfm_score := 0;

        IF v_recency <= 30 THEN
            v_rfm_score := v_rfm_score + 3;
        ELSIF v_recency <= 90 THEN
            v_rfm_score := v_rfm_score + 2;
        ELSE
            v_rfm_score := v_rfm_score + 1;
        END IF;

        IF v_frequency >= 10 THEN
            v_rfm_score := v_rfm_score + 3;
        ELSIF v_frequency >= 5 THEN
            v_rfm_score := v_rfm_score + 2;
        ELSE
            v_rfm_score := v_rfm_score + 1;
        END IF;

        IF v_monetary >= 500 THEN
            v_rfm_score := v_rfm_score + 3;
        ELSIF v_monetary >= 200 THEN
            v_rfm_score := v_rfm_score + 2;
        ELSE
            v_rfm_score := v_rfm_score + 1;
        END IF;

        IF (p_recency IS NULL OR v_recency <= p_recency)
           AND (p_frequency IS NULL OR v_frequency >= p_frequency)
           AND (p_monetary IS NULL OR v_monetary >= p_monetary)
        THEN
            v_customer_count := v_customer_count + 1;
            v_rfm(v_customer_count).member_id := v_member_id;
            v_rfm(v_customer_count).member_name := v_member_name;
            v_rfm(v_customer_count).recency := v_recency;
            v_rfm(v_customer_count).frequency := v_frequency;
            v_rfm(v_customer_count).monetary := v_monetary;
            v_rfm(v_customer_count).rfm_score := v_rfm_score;
        END IF;
    END LOOP;
    CLOSE c_customer;

    IF v_customer_count > 1 THEN
        FOR i IN 1 .. v_customer_count - 1 LOOP
            FOR j IN i + 1 .. v_customer_count LOOP
                IF v_rfm(j).rfm_score > v_rfm(i).rfm_score
                   OR (v_rfm(j).rfm_score = v_rfm(i).rfm_score AND v_rfm(j).recency < v_rfm(i).recency)
                   OR (v_rfm(j).rfm_score = v_rfm(i).rfm_score AND v_rfm(j).recency = v_rfm(i).recency AND v_rfm(j).frequency > v_rfm(i).frequency)
                   OR (v_rfm(j).rfm_score = v_rfm(i).rfm_score AND v_rfm(j).recency = v_rfm(i).recency AND v_rfm(j).frequency = v_rfm(i).frequency AND v_rfm(j).monetary > v_rfm(i).monetary)
                THEN
                    v_temp := v_rfm(i);
                    v_rfm(i) := v_rfm(j);
                    v_rfm(j) := v_temp;
                END IF;
            END LOOP;
        END LOOP;
    END IF;

    DBMS_OUTPUT.PUT_LINE('===============================================================================================');
    DBMS_OUTPUT.PUT_LINE('CUSTOMER RFM REPORT');
    DBMS_OUTPUT.PUT_LINE('BRANCH: ' || v_branch_name);
    DBMS_OUTPUT.PUT_LINE('===============================================================================================');
    DBMS_OUTPUT.PUT_LINE(RPAD('Rank', 6) || RPAD('Customer', 25) || LPAD('Recency (Days)', 15) || LPAD('Frequency (Orders)', 20) || LPAD('Monetary (RM)', 17) || LPAD('RFM Score', 12));
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------------');

    FOR i IN 1 .. v_customer_count LOOP
        IF p_ranking IS NOT NULL AND v_rfm(i).rfm_score < p_ranking THEN
            CONTINUE;
        END IF;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(i, 6) ||
            RPAD(v_rfm(i).member_name, 25) ||
            LPAD(v_rfm(i).recency, 15) ||
            LPAD(v_rfm(i).frequency, 20) ||
            LPAD(TO_CHAR(v_rfm(i).monetary, '999,990.00'), 17) ||
            LPAD(v_rfm(i).rfm_score, 12)
        );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------------------');

    IF p_ranking IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('Customers Shown: ' || v_customer_count);
    ELSE
        DBMS_OUTPUT.PUT_LINE('Customers Shown: ' || v_customer_count);
        DBMS_OUTPUT.PUT_LINE('Minimum RFM Score: ' || p_ranking);
    END IF;

    DBMS_OUTPUT.PUT_LINE('================================================================================');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20011, 'Branch ID ' || p_branch_id || ' does not exist.');
END;
/