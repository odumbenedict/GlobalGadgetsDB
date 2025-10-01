# 📊 Global Gadgets Database – SQL Server Project

![SQL Server](https://img.shields.io/badge/SQL%20Server-T--SQL-red?logo=microsoftsqlserver&logoColor=white)
![SSMS](https://img.shields.io/badge/Tool-SSMS-blue)
![Status](https://img.shields.io/badge/Status-Completed-green)

A **SQL Server database project** for **Global Gadgets**, a large online retailer.  
This project was developed as part of an **Advanced Databases (Level 7) assignment** and demonstrates **professional database design, normalization, and advanced T-SQL implementation**.

---

## 🚀 Project Overview

Global Gadgets required a new database to consolidate customer, product, supplier, order, and inventory data.  
The previous system suffered from:
- ❌ Fragmented customer/order data  
- ❌ Manual stock adjustments after cancellations  
- ❌ Unauthenticated reviews from customers without verified deliveries  
- ❌ No durable record for deactivated accounts  

### ✅ This project solves these issues with:
- **3NF Normalized Schema** → eliminates redundancy & anomalies  
- **Business Rules in T-SQL** → authentic reviews, auto-restocking on cancellations  
- **Constraints & Triggers** → enforce data integrity at source  
- **Advanced Programmability** → UDFs, Stored Procedures, Views for reuse  
- **Concurrency Control** → READ COMMITTED SNAPSHOT isolation  
- **Security & Recovery** → password hashing, least-privilege roles, backup strategy  

---

## 🛠️ Features Implemented

### Database Design
- Tables: **Customers, Products, Suppliers, Orders, OrderItems, Inventory, Reviews**
- Lookup tables: **ProductCategory, PaymentMethod, OrderStatus**
- ER diagram provided in report

### T-SQL Objects
- **Constraints**: e.g., product price must be > 0, rating between 1–5  
- **User-Defined Functions (UDFs)**:
  - `fn_AgeYears` → calculate age from DOB  
  - `fn_OrderLineTotals` → compute order totals  
  - `fn_IsEligibleReview` → enforce review eligibility  
- **Stored Procedures (SPs)**:
  - `sp_SearchProducts` → search by product name  
  - `sp_TodayProductsAndSuppliersForCustomer` → list today’s customer orders & suppliers  
  - `sp_UpdateSupplier` → safely update supplier details  
  - `sp_DeleteDeliveredOrder` → only delete delivered orders  
- **View**: `vw_OrderHistory` → consolidated customer orders, totals, suppliers, and categories  
- **Trigger**: `trg_OrderCancelRestock` → restores stock levels when an order is cancelled  

### Analytical Queries
1. List **customers older than 40** who purchased Premium products  
2. Count of **delivered Electronics orders**  

---

## 📂 Repository Contents

- 📄 `Odum_Benedict.pdf` → Final academic report (with screenshots & analysis)  
- 📝 `Part1_Schema_Seed.sql` → Schema creation & seed data  
- 📝 `Part2_Objects_Queries.sql` → Constraints, queries, stored procedures, UDFs, views, triggers  
- 💾 `GlobalGadgetsDB.bak` → SQL Server backup file (restorable database)  
- 📘 `README.md` → Project documentation  

---

## ⚡ Getting Started

### 🔹 Restore Database from Backup
Copy the `.bak` file to your SQL Server backup folder (e.g., `C:\SQLBackups\`) and run:

```sql
RESTORE DATABASE GlobalGadgetsDB
FROM DISK = 'C:\SQLBackups\GlobalGadgetsDB.bak'
WITH MOVE 'GlobalGadgetsDB' TO 'C:\SQLData\GlobalGadgetsDB.mdf',
     MOVE 'GlobalGadgetsDB_log' TO 'C:\SQLLogs\GlobalGadgetsDB.ldf',
     REPLACE, RECOVERY;
