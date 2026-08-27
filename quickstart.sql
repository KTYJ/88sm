-- cd "88sm"
@"0_resetData.txt"
@"1_createTable.txt"
@"2_sequence.txt"
@"3_insert.txt"
@"4_verify.txt"
-- INDEX (DONE CHECKED BY KTYJ 28/8/2026)
@"CXH/index/index.txt"
@"LLW/index/index.txt"
@"KHS/index/index.txt"
@"Heng/index_heng.txt"
@"Ryan/Index.txt"
@"TJY/index/index_tjy.txt"

-- TRIGGER (HENG NEEDS CHECKING)
@"tjy/trigs/trig1.txt"
@"tjy/trigs/trig2.txt"
commit;
@"tjy/trigs/trigger_test.txt"
@"Ryan/(Trigger1)PreventDuplicateVoucherRedemption.txt"
@"Ryan/(Trigger2)PreventExpiredVoucherRedemption.txt"
commit;
@"Ryan/(Trigger1)test.txt"
@"Ryan/(Trigger2)test.txt"

@"LLW/trig/trg_order_item_stock_restore.txt"
@"LLW/trig/trg_stock_low_alert.txt"
commit;
@"LLW/trig/test-trg_order_item_stock_restore.txt"
@"LLW/trig/test-trg_stock_low_alert.txt"

@"KHS/trigger/trg_member_ic_dob.txt"
@"KHS/trigger/trg_promotion_discount_price.txt"
commit;
@"KHS/trigger/demo/demo_trg_member_ic_dob.txt"
@"KHS/trigger/demo/demo_trg_promotion_discount_price.txt"
--skip below
@"KHS/trigger/demo/testing_trg_member_ic_dob.txt"
@"KHS/trigger/demo/testing_trg_promotion_discount_price.txt"
commit;

@"CXH/trigger/trigger/Prevent selling below procurement cost.txt"
@"CXH/trigger/trigger/expiry_trigger_for_vip.txt"

@"Heng/5_triggers.txt"


-- FUNCTION (DONE CHECKED BY KTYJ 28/8/2026)
@"CXH/FUCNTION/Member total spending.txt"

-- VIEW/QUERY (DONE CHECKED BY KTYJ 28/8/2026)
@"CXH/viewquery/Complete_vw_supplier_performance AS.txt"
@"CXH/viewquery/member purchase behaviour.txt"

@"KHS/query_view/inventory_turnover_rate.txt"
@"KHS/query_view/supplier_item_sales.txt"

@"Heng/6_queries.txt"

@"LLW/query/order_type_trend.txt"
@"LLW/query/top_selling_items.txt"

@"Ryan/(Query1)VoucherEffectiveness.txt"
@"Ryan/(Query2)Item Price & Sales Performance.txt"

@"TJY/queryview/branch_eff.txt"
@"TJY/queryview/branch_profit.txt"


-- proc
@"CXH/procedure/register new member.txt"
@"CXH/procedure/update item price.txt"
@"CXH/procedure/insert_member.txt"
@"CXH/procedure/update_new_price_testing.txt"

@"Heng/4_procedures.txt"

@"LLW/PROC/sp_create_update_delivery.txt"
@"LLW/PROC/sp_redeem_voucher.txt"

@"LLW/PROC/test-sp_create_update_delivery.txt"
@"LLW/PROC/test-sp_redeem_voucher.txt"

@"KHS/prosedure/create_order_item.txt"
@"KHS/prosedure/create_promotion.txt"

@"KHS/prosedure/demo/demo_create_order_item.txt"
@"KHS/prosedure/demo/demo_create_promotion.txt"

@"TJY/procs/proc_pickup.txt"
@"TJY/procs/test_pickup.txt"
@"TJY/procs/proc_place_order.txt"
@"TJY/procs/test_order.txt"

@"Ryan/(Procedure1)Member order History.txt"
@"Ryan/(Procedure1)Test.txt"
@"Ryan/(Procedure2)BranchStock.txt"
@"Ryan/(Procedure2)Test.txt"


--report
@"CXH/report/Member voucher redemption.txt"
@"CXH/report/supplier procurement summary.txt"

@"Heng/7_reports.txt"

@"KHS/report/customer_loyarty.txt"
@"KHS/report/demo/demo_customer_loyarty.txt"
@"KHS/report/promotion_performance.txt"
@"KHS/report/demo/demo_promotion_performance.txt"

@"LLW/report/rpt_category_sales_summary.txt"
@"LLW/report/rpt_top_members_summary.txt"

@"Ryan/(Report 1)Delivery Company Performance Report.txt"
@"Ryan/(Report 2)Member Point Activity Report.txt"

@"TJY/reports/rp_mth_spend.txt"
@"TJY/reports/rp_stock_check.txt"

