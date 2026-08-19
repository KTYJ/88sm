DELETE FROM promotion_details WHERE promotion_id IN (5029);

INSERT INTO promotion_details (
    promotion_id,
    item_id,
    discount_type,
    discount_value
)
VALUES (
    5029,
    'BA001',
    'Amount',
    10
);
