---- PHASE 1-- DATABASE DESIGN & IMPLEMENTATION + POPULATION + DIAGRAM

-- CREATE DATABASE 
CREATE DATABASE GlobalGadgets;
GO
USE GlobalGadgets;
GO

-- CREATE LOOKUP TABLES

-- CREATE A TABLE FOR PAYMENT METHOD, PRODUCT CATEGORY, AND ORDER STATUS

CREATE TABLE dbo.PaymentMethod (
  PaymentMethodID int IDENTITY(1,1) PRIMARY KEY,
  MethodName sysname NOT NULL UNIQUE -- (CARD, PAYPAL, BANK TRANSFER)
);

CREATE TABLE dbo.ProductCategory (
  CategoryID int IDENTITY(1,1) PRIMARY KEY,
  CategoryName sysname NOT NULL UNIQUE
);

CREATE TABLE dbo.OrderStatus (
  StatusID int IDENTITY(1,1) PRIMARY KEY,
  StatusName sysname NOT NULL UNIQUE      --(PENDING, SHIPPED, DELIVERED, OR CANCELLED)
);

-- CREATE CORE TABLE

-- CREATE TABLE FOR CUSTOMER DETAILS 

CREATE TABLE dbo.Customers (
  CustomerID int IDENTITY(1,1) PRIMARY KEY,
  FullName nvarchar(200) NOT NULL,
  BillingAddress nvarchar(300) NOT NULL,
  DateOfBirth date NOT NULL
    CONSTRAINT CK_Customers_DOB CHECK (DateOfBirth < CONVERT(date, GETDATE())),
  PreferredPaymentMethodID int NOT NULL
    CONSTRAINT FK_Customers_PaymentMethod REFERENCES dbo.PaymentMethod(PaymentMethodID),
  Username nvarchar(100) NOT NULL UNIQUE,
  PasswordHash varbinary(64) NOT NULL,
  Email nvarchar(255) NULL,
  Telephone nvarchar(50) NULL,
  IsActive bit NOT NULL DEFAULT(1),
  DeactivatedAt datetime2 NULL
    CONSTRAINT CK_Customers_DeactivatedAt CHECK (DeactivatedAt IS NULL OR DeactivatedAt <= SYSDATETIME())
);

-- CREATE TABLE FOR SUPPLIERS DETAILS 

CREATE TABLE dbo.Suppliers (
  SupplierID int IDENTITY(1,1) PRIMARY KEY,
  SupplierName nvarchar(200) NOT NULL UNIQUE,
  ContactEmail nvarchar(255) NULL,
  ContactPhone nvarchar(50) NULL
);

-- CREATE TABLE FOR PRODUCT DETAILS 

CREATE TABLE dbo.Products (
  ProductID int IDENTITY(1,1) PRIMARY KEY,
  ProductName nvarchar(200) NOT NULL,
  CategoryID int NOT NULL
    CONSTRAINT FK_Products_Category REFERENCES dbo.ProductCategory(CategoryID),
  UnitPrice decimal(12,2) NOT NULL
    CONSTRAINT CK_Products_UnitPrice_Positive CHECK (UnitPrice > 0),
  IsActive bit NOT NULL DEFAULT(1)
);

-- CREATE TABLE FOR SUPPLIERS PRODUCT DETAILS 

CREATE TABLE dbo.SupplierProducts (
  SupplierID int NOT NULL
    CONSTRAINT FK_SupplierProducts_Supplier REFERENCES dbo.Suppliers(SupplierID),
  ProductID int NOT NULL
    CONSTRAINT FK_SupplierProducts_Product REFERENCES dbo.Products(ProductID),
  LeadTimeDays int NOT NULL
    CONSTRAINT CK_SupplierProducts_LeadTime CHECK (LeadTimeDays BETWEEN 0 AND 365),
  CONSTRAINT PK_SupplierProducts PRIMARY KEY (SupplierID, ProductID)
);

-- CREATE TABLE FOR ORDERS DETAILS 

CREATE TABLE dbo.Orders (
  OrderID int IDENTITY(1,1) PRIMARY KEY,
  CustomerID int NOT NULL
    CONSTRAINT FK_Orders_Customer REFERENCES dbo.Customers(CustomerID),
  OrderDate datetime2 NOT NULL DEFAULT (SYSDATETIME()),
  ShippingMethod nvarchar(100) NOT NULL,
  StatusID int NOT NULL
    CONSTRAINT FK_Orders_Status REFERENCES dbo.OrderStatus(StatusID),
  PaymentMethodID int NOT NULL
    CONSTRAINT FK_Orders_PaymentMethod REFERENCES dbo.PaymentMethod(PaymentMethodID)
);

-- CREATE TABLE FOR ORDERS ITEMS DETAILS 

CREATE TABLE dbo.OrderItems (
  OrderItemID int IDENTITY(1,1) PRIMARY KEY,
  OrderID int NOT NULL
    CONSTRAINT FK_OrderItems_Order REFERENCES dbo.Orders(OrderID),
  ProductID int NOT NULL
    CONSTRAINT FK_OrderItems_Product REFERENCES dbo.Products(ProductID),
  Quantity int NOT NULL CHECK (Quantity > 0),
  UnitPrice decimal(12,2) NOT NULL CHECK (UnitPrice > 0),
  rv rowversion,
  CONSTRAINT UQ_OrderItems_Order_Product UNIQUE (OrderID, ProductID)
);
CREATE INDEX IX_OrderItems_Order   ON dbo.OrderItems(OrderID);
CREATE INDEX IX_OrderItems_Product ON dbo.OrderItems(ProductID) INCLUDE (OrderID, Quantity, UnitPrice);

-- CREATE TABLE FOR INVENTORY DETAILS 
CREATE TABLE dbo.Inventory (
  ProductID int PRIMARY KEY
    CONSTRAINT FK_Inventory_Product REFERENCES dbo.Products(ProductID),
  StockLevel int NOT NULL CONSTRAINT CK_Inventory_StockLevel CHECK (StockLevel >= 0),
  rv rowversion
);

-- CREATE TABLE FOR REVIEWS/FEEDBACK

CREATE TABLE dbo.Reviews (
  ReviewID int IDENTITY(1,1) PRIMARY KEY,
  OrderID int NOT NULL
    CONSTRAINT FK_Reviews_Order REFERENCES dbo.Orders(OrderID),
  ProductID int NOT NULL,
  CustomerID int NOT NULL
    CONSTRAINT FK_Reviews_Customer REFERENCES dbo.Customers(CustomerID),
  Rating tinyint NOT NULL CONSTRAINT CK_Reviews_Rating CHECK (Rating BETWEEN 1 AND 5),
  ReviewText nvarchar(1000) NULL,
  ReviewDate date NOT NULL DEFAULT (CONVERT(date, GETDATE())),
  CONSTRAINT UQ_Reviews_Order_Product UNIQUE (OrderID, ProductID),
  CONSTRAINT FK_Reviews_OrderItems UNIQUE (OrderID, ProductID)  -- matches UQ on OrderItems
);

-- Wire Reviews(OrderID,ProductID) to OrderItems(OrderID,ProductID)
ALTER TABLE dbo.Reviews WITH CHECK
ADD CONSTRAINT FK_Reviews_OrderItems_Composite
FOREIGN KEY (OrderID, ProductID)
REFERENCES dbo.OrderItems(OrderID, ProductID);


--  SEEDING THE TABLE WITH MINIMUM OF 7 DATA PER MAIN TABLE.

-- INSERTING SEEDS INTO THE LOOKUP TABLE
INSERT dbo.PaymentMethod(MethodName) VALUES ('Card'),('PayPal'),('Bank Transfer');
INSERT dbo.ProductCategory(CategoryName) VALUES ('Electronics'),('Home'),('Premium'),('Toys');
INSERT dbo.OrderStatus(StatusName) VALUES ('pending'),('shipped'),('delivered'),('cancelled');

SELECT * FROM PaymentMethod;
SELECT * FROM ProductCategory;
SELECT * FROM OrderStatus;

-- INSERTING (10) DATA SEEDS INTO CUSTOMERS TABLE
INSERT dbo.Customers(FullName,BillingAddress,DateOfBirth,PreferredPaymentMethodID,Username,PasswordHash,Email,Telephone) VALUES
 ('Ada Lovelace','1 Logic Ln','1985-01-10',1,'ada',0x34,'ada@gmail.com','+23491624265'),
 ('Grace Hopper','2 Navy St','1970-03-09',1,'grace',0x21,'grace@yahoo.com',NULL),
 ('Alan Turing','3 Enigma Rd','1980-06-23',2,'alan',0x61,'alan@splendor.com','+2349768268'),
 ('Linus Torvalds','4 Kernel Av','1971-12-28',2,'linus',0x81,'linus@naija.com','+23464782665'),
 ('Tim Berners-Lee','5 Web Way','1965-06-08',3,'tim',0x91,NULL,'+23472539665'),
 ('Margaret Hamilton','6 Apollo Ct','1956-08-17',1,'margaret',0x05,'mh@gmail.com','+23400736285'),
 ('Barbara Liskov','7 Abstraction Dr','1960-11-07',2,'barbara',0x08,'bl@gmail.com',NULL),
 ('Edsger Dijkstra','8 Path Ln','1945-05-11',2,'edsger',0x10,'ed@gmail.com',NULL),
 ('Donald Knuth','9 TeX Rd','1938-01-10',1,'donald',0x65,'dk@gmail.com',NULL),
 ('Katherine Johnson','10 Apollo St','1918-08-26',3,'katherine',0x97,'kj@gmail.com',NULL);

Select * from Customers;
  
-- INSERTING (6) DATA SEEDS INTO THE SUPPLIERS TABLE
INSERT dbo.Suppliers(SupplierName, ContactEmail, ContactPhone) VALUES
 ('Acme Supply','acme@gmail.com','+234674683986'),
 ('Globex','globex@yahoo.com','+1-+23463986222'),
 ('sidtoso','sidtoso@gmail.com','+234133000393'),
 ('Initech','sales@initech.com','+23400936444'),
 ('Umbrella','sales@umbrella.com','+23473986155'),
 ('Wayne Enterprises','wayne@store.com','+23460053286');

Select * from Suppliers;

-- INSERTING (12) DATA SEEDS INTO THE PRODUCT TABLE
INSERT dbo.Products(ProductName, CategoryID, UnitPrice, IsActive) VALUES
 ('Smartphone X',   (SELECT CategoryID FROM dbo.ProductCategory WHERE CategoryName='Electronics'),  699.00, 1),
 ('NoiseCancel Pro',(SELECT CategoryID FROM dbo.ProductCategory WHERE CategoryName='Premium'),      299.00, 1),
 ('AirFryer 2L',    (SELECT CategoryID FROM dbo.ProductCategory WHERE CategoryName='Home'),         129.00, 1),
 ('4K TV 55"',      (SELECT CategoryID FROM dbo.ProductCategory WHERE CategoryName='Electronics'),  899.00, 1),
 ('Robot Toy',      (SELECT CategoryID FROM dbo.ProductCategory WHERE CategoryName='Toys'),           59.00, 1),
 ('HiFi Amp',       (SELECT CategoryID FROM dbo.ProductCategory WHERE CategoryName='Premium'),       799.00, 1),
 ('Gaming Laptop',  (SELECT CategoryID FROM dbo.ProductCategory WHERE CategoryName='Electronics'),  1599.00, 1),
 ('Smartwatch Z',   (SELECT CategoryID FROM dbo.ProductCategory WHERE CategoryName='Electronics'),  249.00, 1),
 ('Espresso Maker', (SELECT CategoryID FROM dbo.ProductCategory WHERE CategoryName='Home'),         179.00, 1),
 ('Robot Vacuum',   (SELECT CategoryID FROM dbo.ProductCategory WHERE CategoryName='Home'),         349.00, 1),
 ('Drone Pro',      (SELECT CategoryID FROM dbo.ProductCategory WHERE CategoryName='Electronics'),  499.00, 1),
 ('Bluetooth Speaker',(SELECT CategoryID FROM dbo.ProductCategory WHERE CategoryName='Premium'),    199.00, 1);

 Select * from Products;

-- INSERTING (36) SEEDS  INTO SUPPLIERPRODUCTS (bridge) TABLE — multiple suppliers per product
INSERT dbo.SupplierProducts(SupplierID, ProductID, LeadTimeDays)
SELECT s.SupplierID, p.ProductID,
       CASE WHEN p.UnitPrice >= 800 THEN 10 WHEN p.UnitPrice >= 300 THEN 7 ELSE 5 END
FROM dbo.Suppliers s
JOIN dbo.Products p ON 1=1
WHERE s.SupplierName IN ('Acme Supply','Globex','Sidtoso')
  AND p.ProductName IN ('Smartphone X','NoiseCancel Pro','AirFryer 2L','4K TV 55"','Robot Toy',
                        'HiFi Amp','Gaming Laptop','Smartwatch Z','Espresso Maker','Robot Vacuum','Drone Pro','Bluetooth Speaker');

SELECT * FROM SupplierProducts;

-- INSERT SEEDS INTO INVENTORY TABLE — start all products at 50 units
INSERT dbo.Inventory(ProductID, StockLevel)
SELECT ProductID, 50 FROM dbo.Products;

SELECT * FROM Inventory;

-- INSERT 10 SEEDS DATA INTO ORDERS TABLE
DECLARE @pending   int = (SELECT StatusID FROM dbo.OrderStatus WHERE StatusName='pending');
DECLARE @shipped   int = (SELECT StatusID FROM dbo.OrderStatus WHERE StatusName='shipped');
DECLARE @delivered int = (SELECT StatusID FROM dbo.OrderStatus WHERE StatusName='delivered');
DECLARE @cancelled int = (SELECT StatusID FROM dbo.OrderStatus WHERE StatusName='cancelled');

INSERT dbo.Orders(CustomerID, OrderDate, ShippingMethod, StatusID, PaymentMethodID) VALUES
 (1,  SYSDATETIME(),                  'Courier', @delivered,  1),
 (2,  DATEADD(day,-1,SYSDATETIME()),  'Courier', @shipped,    1),
 (3,  DATEADD(day,-2,SYSDATETIME()),  'Pickup',  @cancelled,  2),
 (4,  DATEADD(day,-10,SYSDATETIME()), 'Courier', @delivered,  2),
 (5,  DATEADD(day,-40,SYSDATETIME()), 'Courier', @delivered,  3),
 (6,  SYSDATETIME(),                  'Courier', @pending,    1),
 (7,  DATEADD(day,-2,SYSDATETIME()),  'Courier', @delivered,  2),
 (8,  SYSDATETIME(),                  'Courier', @pending,    1),
 (9,  DATEADD(day,-3,SYSDATETIME()),  'Pickup',  @shipped,    2),
 (10, DATEADD(day,-5,SYSDATETIME()),  'Courier', @delivered,  3);

 SELECT * FROM Orders;

-- INSERT (19) SEED DATA INTO ORDER ITEMS TABLE – one row per product per order 

INSERT dbo.OrderItems(OrderID, ProductID, Quantity, UnitPrice) VALUES
 (1,  1, 1, 699.00), (1,  2, 1, 299.00),
 (2,  4, 1, 899.00),
 (3,  2, 2, 299.00),
 (4,  6, 1, 799.00), (4,  5, 2,  59.00),
 (5,  1, 1, 699.00), (5,  6, 1, 799.00), (5,  4, 1, 899.00),
 (6,  3, 1, 129.00),
 (7,  7, 1,1599.00), (7,  11,1, 499.00),
 (8,  8, 1, 249.00), (8,  12,1, 199.00),
 (9,  9, 1, 179.00), (9,  10,1, 349.00),
 (10, 1, 1, 699.00), (10, 2,1, 299.00), (10, 4,1, 899.00);

 SELECT * FROM OrderItems;

-- INSERTING DATA INTO THE REVIEWS TABLE — for delivered orders only (1 per product per order)
INSERT dbo.Reviews(OrderID, ProductID, CustomerID, Rating, ReviewText) VALUES
 (1, 1, 1, 5, N'Excellent phone'),
 (1, 2, 1, 4, N'Good noise cancellation'),
 (4, 6, 4, 4, N'Great amplifier'),
 (5, 4, 5, 5, N'Beautiful TV'),
 (7, 7, 7, 5, N'Crazy fast laptop'),
 (10,1,10,5, N'Love it'),
 (10,2,10,4, N'Does the job');

SELECT * FROM Reviews;