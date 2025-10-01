
---- PART 2 — T-SQL OBJECTS & QUERIES (GLOBALGADGETS / DBO)

-- 1. CONSTRAINT: ENSURING PRODUCT PRICE MUST BE POSITIVE (> 0)
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CK_Products_UnitPrice_Positive'
      AND parent_object_id = OBJECT_ID('dbo.Products')
)
ALTER TABLE dbo.Products
  WITH CHECK ADD CONSTRAINT CK_Products_UnitPrice_Positive
  CHECK (UnitPrice > 0);

-- 2. QUERIES

-- QUERY 01: Customers older than 40 who ordered a product in the “Premium” category
SELECT DISTINCT
    CUST.CustomerID,
    CUST.FullName,
    AgeYears = DATEDIFF(year, CUST.DateOfBirth, GETDATE())
FROM dbo.Customers AS CUST
JOIN dbo.Orders    AS ORD  ON ORD.CustomerID = CUST.CustomerID
JOIN dbo.OrderItems AS OI  ON OI.OrderID     = ORD.OrderID
JOIN dbo.Products  AS PROD ON PROD.ProductID = OI.ProductID
JOIN dbo.ProductCategory AS CAT ON CAT.CategoryID = PROD.CategoryID
WHERE DATEDIFF(year, CUST.DateOfBirth, GETDATE()) > 40
  AND CAT.CategoryName = 'Premium'
ORDER BY CUST.FullName;
GO

-- QUERY 02: Number of delivered orders that include Electronics
SELECT COUNT(DISTINCT ORD.OrderID) AS DeliveredElectronicsOrders
FROM dbo.Orders AS ORD
JOIN dbo.OrderStatus AS STAT
  ON STAT.StatusID = ORD.StatusID AND STAT.StatusName = 'delivered'
WHERE EXISTS (
  SELECT 1
  FROM dbo.OrderItems AS OI
  JOIN dbo.Products AS PROD ON PROD.ProductID = OI.ProductID
  JOIN dbo.ProductCategory AS CAT ON CAT.CategoryID = PROD.CategoryID
  WHERE OI.OrderID = ORD.OrderID
    AND CAT.CategoryName = 'Electronics'
);

-- In order to meet up with the TECHNICAL REQUIREMENTS,
-- Here are extra examples to satisfy the "select at least 5 queries with joins/subqueries"

-- QUERY 03: Low stock products (< 10 units)
SELECT PROD.ProductName, INV.StockLevel
FROM dbo.Products AS PROD
JOIN dbo.Inventory AS INV ON INV.ProductID = PROD.ProductID
WHERE INV.StockLevel < 10
ORDER BY INV.StockLevel ASC;

-- QUERY 04: Customer lifetime spend
SELECT CUST.CustomerID, CUST.FullName,
       LifetimeSpend = SUM(OI.Quantity * OI.UnitPrice)
FROM dbo.Customers AS CUST
JOIN dbo.Orders AS ORD    ON ORD.CustomerID = CUST.CustomerID
JOIN dbo.OrderItems AS OI ON OI.OrderID     = ORD.OrderID
GROUP BY CUST.CustomerID, CUST.FullName
ORDER BY LifetimeSpend DESC;

-- QUERY 5 (subquery): 30-day qty per product
SELECT PROD.ProductName,
       Qty30d =
       (SELECT SUM(OI.Quantity)
        FROM dbo.OrderItems AS OI
        JOIN dbo.Orders AS ORD ON ORD.OrderID = OI.OrderID
        WHERE OI.ProductID = PROD.ProductID
          AND ORD.OrderDate >= DATEADD(day,-30,SYSDATETIME()))
FROM dbo.Products AS PROD
ORDER BY Qty30d DESC;

-- 3. (3) USER-DEFINED FUNCTIONS
-- Purpose: To fulfill the project’s technical requirement of including at least three UDFs.
-- Each function demonstrates reusability and enforces business rules:

-- FN_01: AGE IN WHOLE YEARS – CALCULATES CUSTOMER AGE IN YEARS
CREATE OR ALTER FUNCTION dbo.fn_01_AgeYears (@DateOfBirth date)
RETURNS int
AS
BEGIN
  RETURN DATEDIFF(year, @DateOfBirth, CONVERT(date, GETDATE()))
       - CASE WHEN DATEFROMPARTS(YEAR(GETDATE()), MONTH(@DateOfBirth), DAY(@DateOfBirth)) > GETDATE()
              THEN 1 ELSE 0 END;
END;

-- EXAMPLES OF FUNCTION 1
-- Single Value
SELECT dbo.fn_01_AgeYears('1985-01-10') AS AgeYears;
-- Per-Customer
SELECT TOP 10
  Customers.CustomerID,
  Customers.FullName,
  dbo.fn_01_AgeYears(Customers.DateOfBirth) AS AgeYears
FROM dbo.Customers AS Customers
ORDER BY Customers.CustomerID;

-- FN_02: ORDERLINETOTALS – RETURNS LINE TOTALS PER ORDER
CREATE OR ALTER FUNCTION dbo.fn_02_OrderLineTotals (@OrderID int)
RETURNS TABLE
AS
RETURN
  SELECT
      OrderItemID,
      ProductID,
      LineTotal = Quantity * UnitPrice
  FROM dbo.OrderItems
  WHERE OrderID = @OrderID;

-- EXAMPLES OF FUNCTION 2
-- Find a real OrderID first (any existing one)
SELECT TOP 5 Orders.OrderID, Orders.OrderDate
FROM dbo.Orders AS Orders
ORDER BY Orders.OrderID;
-- Use one of those OrderIDs (e.g., 5)
SELECT *
FROM dbo.fn_02_OrderLineTotals(5);        -- returns OrderItemID, ProductID, LineTotal
-- With details 
SELECT
  OI.OrderID,
  OI.ProductID,
  Products.ProductName,
  OI.Quantity,
  OI.UnitPrice,
  T.LineTotal
FROM dbo.OrderItems AS OI
JOIN dbo.Products AS Products
  ON Products.ProductID = OI.ProductID
CROSS APPLY dbo.fn_02_OrderLineTotals(OI.OrderID) AS T
WHERE T.OrderItemID = OI.OrderItemID;

-- FN_03: ELIGIBLEREVIEW -- CHECKS IF A CUSTOMER CAN SUBMIT A REVIEW FOR A PRODUCT IN A DELIVERED ORDER
CREATE OR ALTER FUNCTION dbo.fn_03_IsEligibleReview
(
  @OrderID int,
  @ProductID int,
  @CustomerID int
)
RETURNS bit
AS
BEGIN
  DECLARE @Result bit = 0;

  IF EXISTS
  (
    SELECT 1
    FROM dbo.OrderItems AS OI
    JOIN dbo.Orders AS ORD      ON ORD.OrderID  = OI.OrderID
    JOIN dbo.OrderStatus AS STAT ON STAT.StatusID = ORD.StatusID
    WHERE OI.OrderID    = @OrderID
      AND OI.ProductID  = @ProductID
      AND ORD.CustomerID = @CustomerID
      AND STAT.StatusName = 'delivered'
  )
    SET @Result = 1;
  RETURN @Result;
END;

-- CHECKING TO SEE IF THE 3 FUNCTIONS REALLY EXIST.
SELECT name, type_desc
FROM sys.objects
WHERE schema_id = SCHEMA_ID('dbo')
  AND name IN ('fn_01_AgeYears','fn_02_OrderLineTotals','fn_03_IsEligibleReview');

 --4. (4) STORED PROCEDURES

-- SP_01: SEARCH PRODUCTS BY NAME, SORT BY MOST RECENT ORDER DATE
CREATE OR ALTER PROCEDURE dbo.sp_01_SearchProducts
  @SearchTerm nvarchar(200)
AS
BEGIN
  SET NOCOUNT ON;

  SELECT
      PROD.ProductID,
      PROD.ProductName,
      CAT.CategoryName,
      MostRecentOrderDate = MAX(ORD.OrderDate)
  FROM dbo.Products AS PROD
  JOIN dbo.ProductCategory AS CAT ON CAT.CategoryID = PROD.CategoryID
  LEFT JOIN dbo.OrderItems AS OI   ON OI.ProductID = PROD.ProductID
  LEFT JOIN dbo.Orders AS ORD      ON ORD.OrderID  = OI.OrderID
  WHERE PROD.ProductName LIKE '%' + @SearchTerm + '%'
  GROUP BY PROD.ProductID, PROD.ProductName, CAT.CategoryName
  ORDER BY MostRecentOrderDate DESC, PROD.ProductName;
END;
GO
-- EXAMPLE:
EXEC dbo.sp_01_SearchProducts @SearchTerm = 'Pro';

-- SP_02: PRODUCTS ORDERED TODAY FOR A CUSTOMER + SUPPLIERS
CREATE OR ALTER PROCEDURE dbo.sp_02_TodayProductsAndSuppliersForCustomer
  @CustomerID int
AS
BEGIN
  SET NOCOUNT ON;

  SELECT
      ORD.OrderID,
      OrderDate = CONVERT(date, ORD.OrderDate),
      PROD.ProductName,
      SUP.SupplierName
  FROM dbo.Orders AS ORD
  JOIN dbo.OrderItems AS OI     ON OI.OrderID   = ORD.OrderID
  JOIN dbo.Products AS PROD     ON PROD.ProductID = OI.ProductID
  JOIN dbo.SupplierProducts AS SUPPROD ON SUPPROD.ProductID = PROD.ProductID
  JOIN dbo.Suppliers AS SUP     ON SUP.SupplierID = SUPPROD.SupplierID
  WHERE ORD.CustomerID = @CustomerID
    AND CONVERT(date, ORD.OrderDate) = CONVERT(date, GETDATE())
  ORDER BY ORD.OrderID, PROD.ProductName, SUP.SupplierName;
END;
GO
-- EXAMPLE: 
EXEC dbo.sp_02_TodayProductsAndSuppliersForCustomer @CustomerID = 1;

-- SP_03: UPDATE SUPPLIER DETAILS (RETURNS UPDATED ROW)
CREATE OR ALTER PROCEDURE dbo.sp_03_UpdateSupplier
  @SupplierID   int,
  @SupplierName nvarchar(200) = NULL,
  @ContactEmail nvarchar(255) = NULL,
  @ContactPhone nvarchar(50)  = NULL
AS
BEGIN
  SET NOCOUNT ON;

  UPDATE dbo.Suppliers
  SET SupplierName = COALESCE(@SupplierName, SupplierName),
      ContactEmail = COALESCE(@ContactEmail, ContactEmail),
      ContactPhone = COALESCE(@ContactPhone, ContactPhone)
  WHERE SupplierID = @SupplierID;

SELECT * FROM dbo.Suppliers WHERE SupplierID = @SupplierID;
END;
GO
-- EXAMPLE:
EXEC dbo.sp_03_UpdateSupplier @SupplierID=1, @ContactEmail='new@acme.com';

-- SP_04: DELETE AN ORDER ONLY IF IT’S DELIVERED
CREATE OR ALTER PROCEDURE dbo.sp_04_DeleteDeliveredOrder
  @OrderID int
AS
BEGIN
  SET NOCOUNT ON;

  IF NOT EXISTS
  (
     SELECT 1
     FROM dbo.Orders AS ORD
     JOIN dbo.OrderStatus AS STAT
       ON STAT.StatusID = ORD.StatusID
     WHERE ORD.OrderID = @OrderID
       AND STAT.StatusName = 'delivered'
  )
  BEGIN
     THROW 50001, 'Order is not in Delivered status.', 1;
  END

  DELETE FROM dbo.OrderItems WHERE OrderID = @OrderID;
  DELETE FROM dbo.Orders     WHERE OrderID = @OrderID;
END;

BEGIN TRANSACTION
ROLLBACK
GO
-- EXAMPLE:
EXEC dbo.sp_04_DeleteDeliveredOrder @OrderID = 1;

-- 5. VIEW

-- VW_01: ORDERS WITH TOTALS, CATEGORY, SUPPLIER, AND ANY REVIEWS
CREATE OR ALTER VIEW dbo.vw_01_OrderHistory
WITH SCHEMABINDING
AS
SELECT
    ORD.OrderID,
    ORD.OrderDate,
    CUST.CustomerID,
    CUST.FullName,
    CAT.CategoryName,
    SUP.SupplierName,
    OrderTotal = SUM(OI.Quantity * OI.UnitPrice),
    AvgRating  = AVG(CAST(REV.Rating AS decimal(9,2))),
    ReviewsCount = COUNT_BIG(REV.ReviewID),
    RowCountForSchemaBinding = COUNT_BIG(*)   -- needed if indexing the view later
FROM dbo.Orders AS ORD
JOIN dbo.Customers AS CUST   ON CUST.CustomerID = ORD.CustomerID
JOIN dbo.OrderItems AS OI    ON OI.OrderID      = ORD.OrderID
JOIN dbo.Products AS PROD    ON PROD.ProductID  = OI.ProductID
JOIN dbo.ProductCategory AS CAT ON CAT.CategoryID = PROD.CategoryID
LEFT JOIN dbo.SupplierProducts AS SUPPROD ON SUPPROD.ProductID = PROD.ProductID
LEFT JOIN dbo.Suppliers AS SUP ON SUP.SupplierID = SUPPROD.SupplierID
LEFT JOIN dbo.Reviews AS REV
       ON REV.OrderID  = ORD.OrderID
      AND REV.ProductID = PROD.ProductID
GROUP BY ORD.OrderID, ORD.OrderDate, CUST.CustomerID, CUST.FullName, CAT.CategoryName, SUP.SupplierName;
GO

-- EXAMPLE:
SELECT TOP 20 * FROM dbo.vw_01_OrderHistory ORDER BY OrderDate DESC;

-- 6. TRIGGER

-- TRG_01: WHEN AN ORDER BECOMES 'CANCELLED', RETURN QUANTITIES TO INVENTORY

-- Remove the old trigger (safe to run)
-- Drop old trigger if it exists
IF OBJECT_ID('dbo.trg_01_Orders_CancelRestock', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_01_Orders_CancelRestock;
GO

CREATE TRIGGER dbo.trg_01_Orders_CancelRestock
ON dbo.Orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Only restock if StatusName changed to 'cancelled'
    UPDATE INV
       SET INV.StockLevel = INV.StockLevel + X.Qty
    FROM dbo.Inventory AS INV
    JOIN (
        SELECT OI.ProductID, SUM(OI.Quantity) AS Qty
        FROM dbo.OrderItems AS OI
        JOIN inserted AS I ON I.OrderID = OI.OrderID
        JOIN deleted  AS D ON D.OrderID = OI.OrderID
        JOIN dbo.OrderStatus AS NewStat ON NewStat.StatusID = I.StatusID
        JOIN dbo.OrderStatus AS OldStat ON OldStat.StatusID = D.StatusID
        WHERE NewStat.StatusName = 'cancelled'
          AND OldStat.StatusName <> 'cancelled'
        GROUP BY OI.ProductID
    ) AS X
      ON X.ProductID = INV.ProductID;
END;
GO

-- TEST STEPS
-- Before cancelling
SELECT * FROM dbo.Inventory;

-- Cancel an order
UPDATE dbo.Orders
SET StatusID = (SELECT StatusID FROM dbo.OrderStatus WHERE StatusName='cancelled')
WHERE OrderID = 2;

-- After cancelling
SELECT * FROM dbo.Inventory;