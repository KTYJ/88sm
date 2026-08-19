# 88 SpeedMart Database System Project Deliverables

This repository contains the complete Oracle PL/SQL database implementation for **88 SpeedMart**. All script paths below correspond directly to the execution pipeline defined in *quickstart.txt*

---

## 0. Environment Setup & Data Seeding

| Step | Script Path in `quickstart.txt` | Description |
|---|---|---|
| **Reset Data** | `@"0_resetData"` | Deletes all records in reverse dependency order and drops all sequences. *(Commented out by default)* |
| **Create Tables** | `@"1_createTable"` | Drops existing tables with cascade constraints and creates all 16 tables with complete PK, FK, and CHECK constraints. |
| **Create Sequences** | `@"2_sequence"` | Creates 12 system sequences with dedicated start values and ranges. |
| **Insert Data** | `@"3_insert"` | Seeds comprehensive master and transactional test data across all tables. |
| **Verify Data** | `@"4_verify"` | Queries and verifies row counts for all created tables. |

---

## 1. Stored Procedures (PROCS)

### **JY (Tan Jin Yuan)**
* **Place Order with Multi-Item Support & Cross-Module Integration (`proc_place_order`)**
  * **Script:** `@"TJY/procs/proc_place_order.sql"`
  * **Test / Demo:** `@"TJY/procs/test_order.sql"`
  * **Description:** Places orders with any number of item lines using custom ADT nested tables (`order_item_list`), performs upfront stock row-locking (`FOR UPDATE`), and seamlessly integrates with LW's delivery/voucher logic and KHS's order items generator.
* **Self-Pickup Order Lifecycle Management (`proc_pickup`)**
  * **Script:** `@"TJY/procs/proc_pickup.sql"`
  * **Test / Demo:** `@"TJY/procs/test_pickup.sql"`
  * **Description:** Manages self-pickup workflow status updates (`Preparing` -> `Ready` -> `Completed` / `Rescheduled` / `Expired`), enforces pickup time-window expiry guards, and auto-calculates expiration dates.

### **LW (Lee Lip Wai)**
* **Create / Update Delivery Record (`sp_create_update_delivery`)**
  * **Script:** `@"LLW/proc/proc1.txt"`
  * **Description:** Handles full delivery lifecycle (creation for orders, status updates across `Preparing`, `Out for Delivery`, `Delivered`, `Cancelled`), and protects completed deliveries from modification.
* **Redeem Voucher (`sp_redeem_voucher`)**
  * **Script:** `@"LLW/proc/proc2.txt"`
  * **Description:** Validates voucher expiration, verifies member ownership of the order, and strictly enforces one-time voucher redemption per member.

### **CXH (Chen Xiang Hui)**
* **Register New Member (`sp_register_member`)**
  * **Script:** `@"CXH/5(procedure)/procedure/register new member.txt"`
  * **Test / Demo:** `@"CXH/5(procedure)/test/test 1.txt"`, `@"CXH/5(procedure)/test/test 2.txt"`, `@"CXH/5(procedure)/test/find item.txt"`
  * **Description:** Registers new members with IC format validation (`YYMMDD-SS-NNNN`), unique email checks, duplicate checks, and default points initialization.
* **Update Item Price (`sp_update_item_price`)**
  * **Script:** `@"CXH/5(procedure)/procedure/update item price.txt"`
  * **Test / Demo:** `@"CXH/5(procedure)/test/change item price.txt"`
  * **Description:** Modifies item retail unit prices with validation ensuring new selling prices do not fall below procurement costs.

### **Ryan (Ryan Ooi)**
* **Member Order History (`proc_member_order_history`)**
  * **Script:** `@"Ryan/(Procedure1)Member order History.txt"`
  * **Test / Demo:** `@"Ryan/(Procedure1)Test.txt"`
  * **Description:** Retrieves and displays detailed chronological order history, branch locations, and spending totals for a given member.
* **Branch Stock Inventory Report (`proc_branch_stock_report`)**
  * **Script:** `@"Ryan/(Procedure2)BranchStock.txt"`
  * **Test / Demo:** `@"Ryan/(Procedure2)Test.txt"`
  * **Description:** Queries real-time stock levels for a designated branch, categorizes items, and highlights items needing restock.

### **KHS (Khoo Hou Sheng)**
* **Create Order Items with Promotion & Points (`sp_create_order_items`)**
  * **Script:** `@"KHS/prosedure/create_order_item.sql"`
  * **Test / Demo:** `@"KHS/prosedure/create_order_item_testing.sql"`
  * **Description:** Inserts order item lines, checks active promotions to calculate discounted unit prices, and computes/awards earned member loyalty points into `point_history`.
* **Create Promotion with Details (`sp_create_promotion_with_details`)**
  * **Script:** `@"KHS/prosedure/create_promotion.sql"`
  * **Test / Demo:** `@"KHS/prosedure/create_promotion_testing.sql"`
  * **Description:** Creates promotional campaigns (header in `promotion` and line items in `promotion_details`) with start/end date validation and discount percentage/amount caps.

### **Heng (Heng Tian Li)**
* **Branch Stock Transfer (`proc_transfer_stock`)**
  * **Script:** `@"Heng/4_procedures.sql"`
  * **Test / Demo:** Embedded in `@"Heng/4_procedures.sql"`
  * **Description:** Transfers inventory between branches with inventory locking, balance verification at the source branch, and automatic destination stock creation/updating.
* **Submit Stock Procurement (`proc_submit_procurement`)**
  * **Script:** `@"Heng/4_procedures.sql"`
  * **Test / Demo:** Embedded in `@"Heng/4_procedures.sql"`
  * **Description:** Records new procurement orders from suppliers using sequences and automatically replenishes the receiving branch's stock quantity.

---

## 2. Queries & Views (QUERY / VIEW)

### **JY (Tan Jin Yuan)**
* **Branch Efficiency & Sales per Staff**
  * **Script:** `@"TJY/queryview/branch_eff.sql"`
  * **Views:** `branch_staff_count_view`, `monthly_sales_view`
  * **Description:** Analyzes monthly sales revenue, order volumes, and labor productivity (sales per staff headcount) across branches.
* **Branch Profitability & Net Margin Analysis**
  * **Script:** `@"TJY/queryview/branch_profit.sql"`
  * **Views:** `branch_revenue_view`, `avg_item_cost`, `branch_cost_view`, `branch_profitability_view`
  * **Description:** Multi-year profitability query analyzing total revenue vs. procurement COGS to derive net profit, average order value, and branch performance rankings.

### **LW (Lee Lip Wai)**
* **Top Selling Products Analysis**
  * **Script:** `@"LLW/query/query1.txt"`
  * **Views:** `v_top_selling_items`
  * **Description:** Identifies highest-volume items, revenue generated per product, and ordering frequency across all categories.
* **Order Fulfillment Channel Trends**
  * **Script:** `@"LLW/query/query2.txt"`
  * **Views:** `v_order_type_trend`
  * **Description:** Compares annual revenue and order volumes across fulfillment channels (`In Store`, `Delivery`, `Self Pickup`).

### **CXH (Chen Xiang Hui)**
* **Supplier Procurement Performance**
  * **Script:** `@"CXH/2/(1)View/Complete_vw_supplier_performance AS.txt"`
  * **Views:** `vw_supplier_performance`
  * **Description:** Evaluates suppliers based on total items supplied, branches served, total quantity delivered, and total procurement spend.
* **Member Purchasing Behavior & Tier Segmentation**
  * **Script:** `@"CXH/3/(1)View/member purchase behaviour.txt"`
  * **Views:** `vw_member_purchase_behavior`
  * **Description:** Segments customers into tiers (`VIP CUSTOMER`, `HIGH VALUE`, `REGULAR`, `LOW ACTIVITY`) based on order counts, unique item variety, and lifetime spending.

### **Ryan (Ryan Ooi)**
* **Voucher Redemption Effectiveness**
  * **Script:** `@"Ryan/(Query1)VoucherEffectiveness.txt"`
  * **Views:** `view_voucher_effectiveness`
  * **Description:** Measures voucher popularity, total discount values granted, redemption rates, and revenue generated from voucher-assisted sales.
* **Item Price & Sales Performance**
  * **Script:** `@"Ryan/(Query2)Item Price & Sales Performance.txt"`
  * **Views:** `view_item_sales_summary`
  * **Description:** Compares current retail prices against historical order volumes to assess price elasticity and revenue contribution per item.

### **KHS (Khoo Hou Sheng)**
* **Inventory Turnover Analysis by Category**
  * **Script:** `@"KHS/query_view/inventory_turnover_rate.sql"`
  * **Views:** `previous_month_sales_view`, `weighted_avg_cost_view`, `current_stock_view`, `inventory_turnover_rate_view`
  * **Description:** Computes monthly COGS vs. average inventory holding values to calculate inventory turnover ratios across item categories.
* **Branch Sales Performance**
  * **Script:** `@"KHS/query_view/branch_salse_performance.sql"`
  * **Views:** `branch_sales_performance_view`
  * **Description:** Summarizes previous-month branch sales, order volume, total units sold, and average ticket size.

### **Heng (Heng Tian Li)**
* **Branch On-Hand Stock Status**
  * **Script:** `@"Heng/6_queries.sql"` (Query 6.1)
  * **Description:** Interactive on-demand branch stock query displaying real-time quantities with automated `LOW STOCK` vs `OK` status flags.
* **Market Basket Pair Frequency Analysis**
  * **Script:** `@"Heng/6_queries.sql"` (Query 6.2)
  * **Description:** Self-join associative query finding the top 20 item pairs most frequently bought together in the same transaction.

---

## 3. Triggers (TRIGS)

### **JY (Tan Jin Yuan)**
* **`trg_stock_deduct`** (After Insert on `order_item`)
  * **Script:** `@"tjy/trigs/trig1.sql"`
  * **Test / Demo:** `@"tjy/trigs/trigger_test.sql"`
  * **Description:** Automatically deducts branch inventory when an item is ordered, with full consistency checks for order/item existence, branch stock assignment, and stock sufficiency.
* **`trg_points_balance`** (After Insert on `point_history`)
  * **Script:** `@"tjy/trigs/trig2.sql"`
  * **Test / Demo:** `@"tjy/trigs/trigger_test.sql"`
  * **Description:** Automatically increments or decrements member `points_balance` upon `'Earned'` or `'Used'` point transactions, preventing overdrafts.

### **LW (Lee Lip Wai)**
* **`trg_stock_low_alert`** (After Update of `stock_quantity` on `branch_stock`)
  * **Script:** `@"LLW/trig/trig2.txt"`
  * **Description:** Real-time warning alert fired when an item's branch inventory falls below the safety threshold of 20 units.
* **Voucher / Stock Safety Trigger**
  * **Script:** `@"LLW/trig/trig1.txt"`
  * **Description:** Trigger / validation logic enforcing voucher eligibility and stock safeguards.

### **CXH (Chen Xiang Hui)**
* **`trg_validate_item_price`** (Before Update of `unit_price` on `item`)
  * **Script:** `@"CXH/6(trigger)/trigger/Prevent selling below procurement cost.txt"`
  * **Description:** Prevents setting retail selling prices lower than the item's latest procurement cost.
* **Member Points / Integrity Trigger**
  * **Script:** `@"CXH/6(trigger)/trigger/triggers.txt"`
  * **Description:** Enforces non-negative constraints and data integrity on member point balances.

### **Ryan (Ryan Ooi)**
* **`trg_prevent_duplicate_voucher`** (Before Insert on `redemption`)
  * **Script:** `@"Ryan/(Trigger1)PreventDuplicateVoucherRedemption.txt"`
  * **Test / Demo:** `@"Ryan/(Trigger1)test.txt"`
  * **Description:** Enforces one-time voucher policy by preventing multiple redemptions of the same voucher by the same member.
* **`trg_prevent_expired_voucher`** (Before Insert on `redemption`)
  * **Script:** `@"Ryan/(Trigger2)PreventExpiredVoucherRedemption.txt"`
  * **Test / Demo:** `@"Ryan/(Trigger2)test.txt"`
  * **Description:** Validates voucher expiry timestamp against current system date before allowing redemption.

### **KHS (Khoo Hou Sheng)**
* **`trg_member_ic_dob`** (Before Insert/Update on `member`)
  * **Script:** `@"KHS/trigger/trg_member_ic_dob.sql"`
  * **Test / Demo:** `@"KHS/trigger/trg_member_ic_dob_testing.sql"`
  * **Description:** Extracts birth date encoded in Malaysian IC format (`YYMMDD-SS-NNNN`) and ensures it matches the registered `date_of_birth`.
* **`trg_promotion_discount_price`** (Before Insert/Update on `promotion_details`)
  * **Script:** `@"KHS/trigger/trg_promotion_discount_price.sql"`
  * **Test / Demo:** `@"KHS/trigger/trg_promotion_discount_price_test.sql"`
  * **Description:** Prevents flat amount discount values from exceeding the item's current unit retail price.

### **Heng (Heng Tian Li)**
* **`trg_block_staff_deletion`** (Before Delete on `staff`)
  * **Script:** `@"Heng/5_triggers.sql"`
  * **Description:** Restricts staff record deletion if the staff member is linked to historical customer orders.
* **`trg_member_dob_check`** (Before Insert/Update on `member`)
  * **Script:** `@"Heng/5_triggers.sql"`
  * **Description:** Validates that member birth dates are not in the future and ensures members meet the minimum age requirement (>= 12 years old).

---

## 4. Reports (REPORTS)

| Member | Procedure / Report Name | Script Path in `quickstart.txt` | Test / Demo Path | Type & Cursor Structure |
|---|---|---|---|---|
| **JY (Tan Jin Yuan)** | `rp_mthly_spend_mem(v_top_n)` | `@"TJY/reports/rp_mth_spend.sql"` | Embedded in script | **Detail Report (On-Demand)**<br>• Triple Nested Cursors: Top Members by Spending -> Most Visited Branch -> Top 5 Purchased Products per Member.<br>• Dynamic ANSI color styling & ASCII box framing. |
| **JY (Tan Jin Yuan)** | `rp_stock_reorder(p_threshold)` | `@"TJY/reports/rp_stock_check.sql"` | Embedded in script | **Operational Report (On-Demand)**<br>• Nested Cursors: Outer loop for branches with low stock, Inner loop for low-stock items.<br>• Computes estimated branch and total procurement replenishment cost. |
| **LW (Lee Lip Wai)** | `rpt_category_sales_summary(p_cat)` | `@"LLW/report/report1.txt"` | Embedded in script | **Summary Report (On-Demand)**<br>• Parameterized cursor calculating units sold, revenue, and item counts per category. |
| **LW (Lee Lip Wai)** | `rpt_top_members_summary(p_top_m, p_top_i)` | `@"LLW/report/report2.txt"` | Embedded in script | **Detail Report (On-Demand)**<br>• Nested Cursors: Outer loop for top spenders, Inner cursor for favorite items per member. |
| **CXH (Chen Xiang Hui)** | `rpt_member_voucher_redemption(p_mid)` | `@"CXH/report/Member voucher redemption.txt"` | Embedded in script | **Detail Report (On-Demand)**<br>• Nested Cursors: Outer loop for member orders, Inner cursor for redeemed vouchers and savings. |
| **CXH (Chen Xiang Hui)** | `rpt_supplier_procurement` | `@"CXH/report/supplier procurement summary.txt"` | Embedded in script | **Summary Report**<br>• Cursor ranking suppliers by total procurement cost, item variety, and delivered volume. |
| **Ryan (Ryan Ooi)** | `proc_delivery_performance_report` | `@"Ryan/(Report 1)Delivery Company Performance Report.txt"` | Embedded in script | **Summary Report**<br>• Aggregates on-time delivery rates, pending shipments, and revenue per courier. |
| **Ryan (Ryan Ooi)** | `proc_member_point_activity_report` | `@"Ryan/(Report 2)Member Point Activity Report.txt"` | Embedded in script | **Detail Report (On-Demand)**<br>• Analyzes member points earned vs. redeemed history over time. |
| **KHS (Khoo Hou Sheng)** | `sp_customer_loyalty_report` | `@"KHS/report/customer_loyarty.sql"` | `@"KHS/report/customer_loyarty_testing.sql"` | **Detail Report**<br>• Analyzes points accumulation, average order frequency, and loyalty tier distribution. |
| **KHS (Khoo Hou Sheng)** | `sp_promotion_performance_report` | `@"KHS/report/promotion_performance.sql"` | `@"KHS/report/promotion_performance_testing.sql"` | **Summary Report**<br>• Analyzes promotion campaign sales uplift, total discount amounts absorbed, and item volumes. |
| **Heng (Heng Tian Li)** | `proc_rpt_procurement_cmp` | `@"Heng/7_reports.sql"` | Embedded in script | **Summary Report**<br>• Compares procurement unit prices across multiple suppliers for common items. |
| **Heng (Heng Tian Li)** | `proc_rpt_branch_stock_inout(p_bid)` | `@"Heng/7_reports.sql"` | Embedded in script | **Detail Report (On-Demand)**<br>• Parameterized cursor tracking branch on-hand inventory quantities and last restock dates. |

---

## 5. Indexes (INDEXES)

| Member | Script Path in `quickstart.txt` | Index Name & Target Column(s) | Type |
|---|---|---|---|
| **CXH (Chen Xiang Hui)** | `@"CXH/index/1/Index 1/index(procedure supplier).txt"` | `idx_procurement_supplier` ON `procurement(supplier_id)` | B-Tree |
| **CXH (Chen Xiang Hui)** | `@"CXH/index/1/index 2/CREATE INDEX idx_orders_member_date.txt"` | `idx_orders_member_date` ON `orders(member_id, order_date)` | Composite B-Tree |
| **LW (Lee Lip Wai)** | `@"LLW/index/index.txt"` | `idx_orders_type` ON `orders(order_type)`<br>`idx_order_item_item` ON `order_item(item_id)` | B-Tree |
| **Ryan (Ryan Ooi)** | `@"Ryan/Index.txt"` | `idx_redemption_voucher` ON `redemption(voucher_id)`<br>`idx_redemption_order` ON `redemption(order_id)` | B-Tree |
| **JY (Tan Jin Yuan)** | `@"TJY/index/index_tjy.sql"` | `idx_orders_date` ON `orders(order_date)`<br>`idx_stock_qty` ON `branch_stock(stock_quantity)`<br>`idx_procurement_date` ON `procurement(procurement_date)`<br>`idx_procurement_item` ON `procurement(item_id)`<br>`idx_subtotal` ON `order_item(quantity * unit_price)` | B-Tree & Function-Based |

---

## 6. Execution Instructions

To execute the entire database system from start to finish, run the master script in Oracle SQL*Plus:

```sql
@"quickstart.txt"
```
