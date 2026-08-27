-- cd "88sm"
@"0_resetData"
@"1_createTable"
@"2_sequence"
@"3_insert"
@"4_verify"

--create index
@"CXH/index/index.txt"

@"LLW/index/index.txt"

@"KHS/index/index.sql"

@"Heng/index_heng.sql"

@"Ryan/Index.txt"

@"TJY/index/index_tjy.sql"

-- create trigger
@"tjy/trigs/trig1.sql"
@"tjy/trigs/trig2.sql"
commit;
@"tjy/trigs/trigger_test.sql"

@"Ryan/(Trigger1)PreventDuplicateVoucherRedemption.txt"
@"Ryan/(Trigger2)PreventExpiredVoucherRedemption.txt"
commit;
@"Ryan/(Trigger1)test.txt"
@"Ryan/(Trigger2)test.txt"

@"LLW/trig/trig1.txt"
@"LLW/trig/trig2.txt"

@"KHS/trigger/trg_member_ic_dob.sql"
@"KHS/trigger/trg_promotion_discount_price.sql"
commit;
@"KHS/trigger/demo/demo_trg_member_ic_dob.sql"
@"KHS/trigger/demo/demo_trg_promotion_discount_price.sql"
@"KHS/trigger/demo/testing_trg_member_ic_dob.sql"
@"KHS/trigger/demo/testing_trg_promotion_discount_price.sql"
commit;

@"CXH/6(trigger)/trigger/Prevent selling below procurement cost.txt"
@"CXH/6(trigger)/trigger/expiry_trigger.txt"

@"Heng/5_triggers.sql"


--functions
@"CXH/FUCNTION/Member total spending.txt"


-- create view/query
@"CXH/2/(1)View/Complete_vw_supplier_performance AS.txt"
@"CXH/3/(1)View/member purchase behaviour.txt"

@"KHS/query_view/inventory_turnover_rate.sql"
@"KHS/query_view/supplier_item_sales.sql"

@"Heng/6_queries.sql"

@"LLW/query/query1.txt"
@"LLW/query/query2.txt"

@"Ryan/(Query1)VoucherEffectiveness.txt"
@"Ryan/(Query2)Item Price & Sales Performance.txt"

@"TJY/queryview/branch_eff.sql"
@"TJY/queryview/branch_profit.sql"


-- proc
@"CXH/5(procedure)/procedure/register new member.txt"
@"CXH/5(procedure)/procedure/update item price.txt"
@"CXH/5(procedure)/test/test 1.txt"
@"CXH/5(procedure)/test/test 2.txt"
@"CXH/5(procedure)/test/change item price.txt"
@"CXH/5(procedure)/test/find item.txt"

@"Heng/4_procedures.sql"

@"LLW/proc/proc1.txt"
@"LLW/proc/proc2.txt"

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

@"LLW/report/report1.txt"
@"LLW/report/report2.txt"

@"Ryan/(Report 1)Delivery Company Performance Report.txt"
@"Ryan/(Report 2)Member Point Activity Report.txt"

@"TJY/reports/rp_mth_spend.sql"
@"TJY/reports/rp_stock_check.sql"
