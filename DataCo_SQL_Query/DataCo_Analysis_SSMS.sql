/*=====================================================================================
  DATACO SMART SUPPLY CHAIN ANALYSIS - SQL SERVER (SSMS)
  180,519 order-line rows (65,752 unique orders) | 2015-01 to 2018-01
  Plus tokenized_access_logs (469,977 website browsing events, Sep 2017 - Jan 2018)
=======================================================================================*/

IF DB_ID('DataCoAnalytics') IS NULL CREATE DATABASE DataCoAnalytics;
GO
USE DataCoAnalytics;
GO

/*----------------------------------- 0. SCHEMA -----------------------------------*/
IF OBJECT_ID('dbo.SupplyChainOrders','U') IS NOT NULL DROP TABLE dbo.SupplyChainOrders;
IF OBJECT_ID('dbo.AccessLogs','U') IS NOT NULL DROP TABLE dbo.AccessLogs;
GO

CREATE TABLE dbo.SupplyChainOrders (
    RowKey INT IDENTITY(1,1) PRIMARY KEY,
    OrderType VARCHAR(20), DaysForShippingReal INT, DaysForShipmentScheduled INT,
    BenefitPerOrder DECIMAL(12,4), SalesPerCustomer DECIMAL(12,4), DeliveryStatus VARCHAR(30),
    LateDeliveryRisk BIT, CategoryId INT, CategoryName VARCHAR(60),
    CustomerCity VARCHAR(60), CustomerCountry VARCHAR(60), CustomerSegment VARCHAR(20),
    CustomerState VARCHAR(10), DepartmentName VARCHAR(60), Market VARCHAR(20),
    OrderCity VARCHAR(60), OrderCountry VARCHAR(60), OrderDate DATETIME, OrderId INT,
    OrderItemDiscount DECIMAL(10,4), OrderItemDiscountRate DECIMAL(6,4), OrderItemId INT,
    OrderItemProductPrice DECIMAL(10,2), OrderItemProfitRatio DECIMAL(10,4),
    OrderItemQuantity INT, Sales DECIMAL(12,4), OrderItemTotal DECIMAL(12,4),
    OrderProfitPerOrder DECIMAL(12,4), OrderRegion VARCHAR(40), OrderState VARCHAR(60),
    OrderStatus VARCHAR(30), ProductCardId INT, ProductName VARCHAR(120),
    ProductPrice DECIMAL(10,2), ShippingDate DATETIME, ShippingMode VARCHAR(20)
    -- (trimmed to the columns used in analysis below; import the full CSV for all 53 fields)
);

CREATE TABLE dbo.AccessLogs (
    Product VARCHAR(150), Category VARCHAR(60), EventDate DATETIME, EventMonth VARCHAR(10),
    EventHour INT, Department VARCHAR(30), ClientIp VARCHAR(20), Url VARCHAR(500)
);
GO
-- Import each CSV via SSMS "Import Flat File" wizard (note: DataCoSupplyChainDataset.csv is
-- Latin-1 encoded, not UTF-8 - set the code page accordingly in the wizard or BULK INSERT):
-- BULK INSERT dbo.SupplyChainOrders FROM 'C:\Data\DataCoSupplyChainDataset.csv'
-- WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', CODEPAGE='1252');


/*=====================================================================================
  1. DESCRIPTIVE - What happened?
=======================================================================================*/

-- 1.1 Business overview
SELECT
    COUNT(*) AS OrderLines, COUNT(DISTINCT OrderId) AS UniqueOrders,
    SUM(Sales) AS TotalSales, SUM(OrderProfitPerOrder) AS TotalProfit,
    SUM(CASE WHEN OrderStatus = 'SUSPECTED_FRAUD' THEN 1 ELSE 0 END) AS SuspectedFraudOrders,
    AVG(CAST(LateDeliveryRisk AS FLOAT)) AS LateDeliveryRate
FROM dbo.SupplyChainOrders;
GO

-- 1.2 Performance by market
SELECT Market, COUNT(*) AS Orders, SUM(Sales) AS Sales, SUM(OrderProfitPerOrder) AS Profit
FROM dbo.SupplyChainOrders GROUP BY Market ORDER BY Sales DESC;
GO

-- 1.3 Top categories by sales
SELECT TOP 10 CategoryName, COUNT(*) AS Orders, SUM(Sales) AS Sales, SUM(OrderProfitPerOrder) AS Profit
FROM dbo.SupplyChainOrders GROUP BY CategoryName ORDER BY Sales DESC;
GO

-- 1.4 Monthly sales trend
SELECT FORMAT(OrderDate, 'yyyy-MM') AS OrderMonth, COUNT(DISTINCT OrderId) AS Orders, SUM(Sales) AS Sales
FROM dbo.SupplyChainOrders GROUP BY FORMAT(OrderDate, 'yyyy-MM') ORDER BY OrderMonth;
GO


/*=====================================================================================
  2. DIAGNOSTIC - Why did it happen?
=======================================================================================*/

-- 2.1 Fraud rate by payment type (the single strongest diagnostic finding)
SELECT OrderType,
       SUM(CASE WHEN OrderStatus = 'SUSPECTED_FRAUD' THEN 1 ELSE 0 END) AS FraudCount,
       COUNT(*) AS Total,
       CAST(SUM(CASE WHEN OrderStatus = 'SUSPECTED_FRAUD' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) AS FraudRate
FROM dbo.SupplyChainOrders
GROUP BY OrderType ORDER BY FraudRate DESC;
GO

-- 2.2 Scheduled vs actual shipping days by mode (diagnoses the late-delivery cause)
SELECT ShippingMode,
       AVG(CAST(DaysForShipmentScheduled AS FLOAT)) AS AvgScheduledDays,
       AVG(CAST(DaysForShippingReal AS FLOAT)) AS AvgRealDays,
       AVG(CAST(LateDeliveryRisk AS FLOAT)) AS LateRate
FROM dbo.SupplyChainOrders
GROUP BY ShippingMode ORDER BY LateRate DESC;
GO

-- 2.3 Profit distribution by category (diagnoses where the business makes/loses money)
SELECT CategoryName, COUNT(*) AS Orders, SUM(OrderProfitPerOrder) AS TotalProfit,
       SUM(CASE WHEN OrderProfitPerOrder < 0 THEN 1 ELSE 0 END) AS LossMakingOrders
FROM dbo.SupplyChainOrders
GROUP BY CategoryName ORDER BY TotalProfit ASC;
GO

-- 2.4 Between vs within-category profit variance (SQL proxy for the ANOVA in Python)
;WITH Overall AS (SELECT AVG(OrderProfitPerOrder) AS grand_mean FROM dbo.SupplyChainOrders),
CategoryStats AS (
    SELECT CategoryName, COUNT(*) AS n, AVG(OrderProfitPerOrder) AS cat_mean, VAR(OrderProfitPerOrder) AS cat_var
    FROM dbo.SupplyChainOrders GROUP BY CategoryName
)
SELECT
    SUM(n * POWER(cat_mean - o.grand_mean, 2)) / (COUNT(*) - 1) AS BetweenCategoryVariance,
    AVG(cat_var) AS AvgWithinCategoryVariance
FROM CategoryStats, Overall o GROUP BY o.grand_mean;
GO

-- 2.5 Browse-to-buy conversion by department (cross-table diagnostic - requires both tables loaded)
;WITH BrowseCounts AS (
    SELECT LOWER(LTRIM(RTRIM(Department))) AS Dept, COUNT(*) AS BrowseEvents
    FROM dbo.AccessLogs GROUP BY LOWER(LTRIM(RTRIM(Department)))
),
OrderCounts AS (
    SELECT LOWER(DepartmentName) AS Dept, COUNT(*) AS Orders
    FROM dbo.SupplyChainOrders
    WHERE LOWER(DepartmentName) IN ('fan shop','apparel','golf','footwear','outdoors','fitness')
    GROUP BY LOWER(DepartmentName)
),
Totals AS (
    SELECT (SELECT SUM(BrowseEvents) FROM BrowseCounts WHERE Dept IN
            ('fan shop','apparel','golf','footwear','outdoors','fitness')) AS TotalBrowse,
           (SELECT SUM(Orders) FROM OrderCounts) AS TotalOrders
)
SELECT b.Dept,
       CAST(b.BrowseEvents AS FLOAT) / t.TotalBrowse AS BrowseShare,
       CAST(o.Orders AS FLOAT) / t.TotalOrders AS OrderShare,
       (CAST(o.Orders AS FLOAT) / t.TotalOrders) / (CAST(b.BrowseEvents AS FLOAT) / t.TotalBrowse) AS ConversionIndex
FROM BrowseCounts b
JOIN OrderCounts o ON b.Dept = o.Dept
CROSS JOIN Totals t
ORDER BY ConversionIndex DESC;
GO


/*=====================================================================================
  3. PREDICTIVE - Which orders carry risk?
  (Rule-based proxies for the Random Forest models in the Python script)
=======================================================================================*/

-- 3.1 Fraud risk flag (payment type dominates the real model's feature importance)
SELECT OrderId, OrderType, Sales, CustomerSegment,
    CASE WHEN OrderType = 'TRANSFER' THEN 'Review queue' ELSE 'Low risk' END AS FraudRiskFlag
FROM dbo.SupplyChainOrders;
GO

-- 3.2 Validate the flag against actual outcomes
;WITH Flagged AS (
    SELECT *, CASE WHEN OrderType = 'TRANSFER' THEN 'Review queue' ELSE 'Low risk' END AS FraudRiskFlag
    FROM dbo.SupplyChainOrders
)
SELECT FraudRiskFlag, COUNT(*) AS Orders,
       CAST(SUM(CASE WHEN OrderStatus='SUSPECTED_FRAUD' THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) AS ActualFraudRate
FROM Flagged GROUP BY FraudRiskFlag;
GO

-- 3.3 Late-delivery risk flag (scheduled days + shipping mode, per the diagnostic finding)
SELECT OrderId, ShippingMode, DaysForShipmentScheduled,
    CASE WHEN ShippingMode IN ('First Class','Second Class') THEN 'High risk' ELSE 'Low risk' END AS LateRiskFlag
FROM dbo.SupplyChainOrders;
GO

-- 3.4 Monthly trend with 3-month moving average (excludes the anomalous final months manually in WHERE)
;WITH Monthly AS (
    SELECT FORMAT(OrderDate, 'yyyy-MM') AS OrderMonth, SUM(Sales) AS Sales
    FROM dbo.SupplyChainOrders
    WHERE OrderDate < '2017-10-01'
    GROUP BY FORMAT(OrderDate, 'yyyy-MM')
)
SELECT OrderMonth, Sales,
       AVG(Sales) OVER (ORDER BY OrderMonth ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS MovingAvg3Month
FROM Monthly ORDER BY OrderMonth;
GO


/*=====================================================================================
  4. PRESCRIPTIVE - What should we do about it?
=======================================================================================*/

-- 4.1 Orders to route to fraud review right now
SELECT OrderId, Sales, CustomerSegment, Market,
       'Review: TRANSFER payment' AS Action
FROM dbo.SupplyChainOrders
WHERE OrderType = 'TRANSFER' AND OrderStatus NOT IN ('SUSPECTED_FRAUD','CANCELED');
GO

-- 4.2 Departments to audit for conversion (below-average conversion index)
;WITH BrowseCounts AS (
    SELECT LOWER(LTRIM(RTRIM(Department))) AS Dept, COUNT(*) AS BrowseEvents
    FROM dbo.AccessLogs GROUP BY LOWER(LTRIM(RTRIM(Department)))
),
OrderCounts AS (
    SELECT LOWER(DepartmentName) AS Dept, COUNT(*) AS Orders
    FROM dbo.SupplyChainOrders
    WHERE LOWER(DepartmentName) IN ('fan shop','apparel','golf','footwear','outdoors','fitness')
    GROUP BY LOWER(DepartmentName)
)
SELECT b.Dept,
       (CAST(o.Orders AS FLOAT)/(SELECT SUM(Orders) FROM OrderCounts)) /
       (CAST(b.BrowseEvents AS FLOAT)/(SELECT SUM(BrowseEvents) FROM BrowseCounts WHERE Dept IN
            ('fan shop','apparel','golf','footwear','outdoors','fitness'))) AS ConversionIndex,
       'AUDIT: below-proportional conversion' AS Action
FROM BrowseCounts b JOIN OrderCounts o ON b.Dept = o.Dept
WHERE (CAST(o.Orders AS FLOAT)/(SELECT SUM(Orders) FROM OrderCounts)) /
      (CAST(b.BrowseEvents AS FLOAT)/(SELECT SUM(BrowseEvents) FROM BrowseCounts WHERE Dept IN
            ('fan shop','apparel','golf','footwear','outdoors','fitness'))) < 1.0
ORDER BY ConversionIndex ASC;
GO

-- 4.3 Category-level margin recovery priority (highest order count among loss-making categories)
SELECT TOP 5 CategoryName, COUNT(*) AS Orders, SUM(OrderProfitPerOrder) AS TotalProfit,
       'PRIORITIZE: high volume, negative total profit' AS Action
FROM dbo.SupplyChainOrders
GROUP BY CategoryName
HAVING SUM(OrderProfitPerOrder) < 0
ORDER BY Orders DESC;
GO

/*=====================================================================================
  END OF SCRIPT
=======================================================================================*/
