UPDATE promotion_details
SET discount_type = 'Amount',
    discount_value = 30
WHERE promotion_id = 5015
  AND item_id = 'NU001';
