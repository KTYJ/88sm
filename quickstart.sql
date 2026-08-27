-- cd "88sm"
@"0_resetData"
@"1_createTable"
@"2_sequence"
@"3_insert"
@"4_verify"
-- INDEX (DONE CHECKED BY KTYJ 28/8/2026)
@"CXH/index/index.txt"
@"LLW/index/index.txt"
@"KHS/index/index.sql"
@"Heng/index_heng.sql"
@"Ryan/Index.txt"
@"TJY/index/index_tjy.sql"

-- TRIGGER (HENG NEEDS CHECKING)
@"tjy/trigs/trig1.sql"
@"tjy/trigs/trig2.sql"
commit;
@"tjy/trigs/trigger_test.sql"
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

@"KHS/trigger/trg_member_ic_dob.sql"
@"KHS/trigger/trg_promotion_discount_price.sql"
commit;
@"KHS/trigger/demo/demo_trg_member_ic_dob.sql"
@"KHS/trigger/demo/demo_trg_promotion_discount_price.sql"
--skip below
@"KHS/trigger/demo/testing_trg_member_ic_dob.sql"
@"KHS/trigger/demo/testing_trg_promotion_discount_price.sql"
commit;

@"CXH/trigger/trigger/Prevent selling below procurement cost.txt"
@"CXH/trigger/trigger/expiry_trigger_for_vip.txt"

@"Heng/5_triggers.sql"


-- FUNCTION (DONE CHECKED BY KTYJ 28/8/2026)
@"CXH/FUCNTION/Member total spending.txt"

-- VIEW/QUERY (DONE CHECKED BY KTYJ 28/8/2026)
@"CXH/viewquery/Complete_vw_supplier_performance AS.txt"
@"CXH/viewquery/member purchase behaviour.txt"

@"KHS/query_view/inventory_turnover_rate.sql"
@"KHS/query_view/supplier_item_sales.sql"

@"Heng/6_queries.sql"

@"LLW/query/order_type_trend.txt"
@"LLW/query/top_selling_items.txt"

@"Ryan/(Query1)VoucherEffectiveness.txt"
@"Ryan/(Query2)Item Price & Sales Performance.txt"

@"TJY/queryview/branch_eff.sql"
@"TJY/queryview/branch_profit.sql"


-- proc
@"CXH/procedure/register new member.txt"
@"CXH/procedure/update item price.txt"
@"CXH/procedure/insert_member.txt"
@"CXH/procedure/update_new_price_testing.txt"

@"Heng/4_procedures.sql"

@"LLW/PROC/sp_create_update_delivery.txt"
@"LLW/PROC/sp_redeem_voucher.txt"

@"LLW/PROC/test-sp_create_update_delivery.txt"
@"LLW/PROC/test-sp_redeem_voucher.txt"

@"KHS/prosedure/create_order_item.sql"
@"KHS/prosedure/create_promotion.sql"

@"KHS/prosedure/demo/demo_create_order_item.sql"
@"KHS/prosedure/demo/demo_create_promotion.sql"

@"TJY/procs/proc_pickup.sql"
@"TJY/procs/test_pickup.sql"
@"TJY/procs/proc_place_order.sql"
@"TJY/procs/test_order.sql"

@"Ryan/(Procedure1)Member order History.txt"
@"Ryan/(Procedure1)Test.txt"
@"Ryan/(Procedure2)BranchStock.txt"
@"Ryan/(Procedure2)Test.txt"


--report
@"CXH/report/Member voucher redemption.txt"
@"CXH/report/supplier procurement summary.txt"

@"Heng/7_reports.sql"

@"KHS/report/customer_loyarty.sql"
@"KHS/report/demo/demo_customer_loyarty.sql"
@"KHS/report/promotion_performance.sql"
@"KHS/report/demo/demo_promotion_performance.sql"

@"LLW/report/rpt_category_sales_summary.txt"
@"LLW/report/rpt_top_members_summary.txt"

@"Ryan/(Report 1)Delivery Company Performance Report.txt"
@"Ryan/(Report 2)Member Point Activity Report.txt"

@"TJY/reports/rp_mth_spend.sql"
@"TJY/reports/rp_stock_check.sql"
