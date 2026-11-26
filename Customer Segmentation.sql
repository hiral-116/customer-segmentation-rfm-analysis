USE customerSegmentation_RFM;

/*====================================================
  CHECK RAW DATA
====================================================*/

-- Check total records
SELECT COUNT(*) AS Total_Rows
FROM dbo.onlineRetail;

-- Inspect sample records
SELECT TOP 10 *
FROM dbo.onlineRetail;

-- Check column names and data types
EXEC sp_help 'dbo.onlineRetail';


/*====================================================
  DATA QUALITY CHECKS
====================================================*/

-- Check missing values
SELECT
    SUM(CASE WHEN InvoiceNo IS NULL THEN 1 ELSE 0 END) AS Missing_InvoiceNo,
    SUM(CASE WHEN StockCode IS NULL THEN 1 ELSE 0 END) AS Missing_StockCode,
    SUM(CASE WHEN Description IS NULL THEN 1 ELSE 0 END) AS Missing_Description,
    SUM(CASE WHEN Quantity IS NULL THEN 1 ELSE 0 END) AS Missing_Quantity,
    SUM(CASE WHEN InvoiceDate IS NULL THEN 1 ELSE 0 END) AS Missing_InvoiceDate,
    SUM(CASE WHEN UnitPrice IS NULL THEN 1 ELSE 0 END) AS Missing_UnitPrice,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS Missing_CustomerID,
    SUM(CASE WHEN Country IS NULL THEN 1 ELSE 0 END) AS Missing_Country
FROM dbo.onlineRetail;


-- Check duplicate records
SELECT
    SUM(Duplicate_Count - 1) AS Total_Duplicate_Rows
FROM
(
    SELECT COUNT(*) AS Duplicate_Count
    FROM dbo.onlineRetail
    GROUP BY
        InvoiceNo,
        StockCode,
        Description,
        Quantity,
        InvoiceDate,
        UnitPrice,
        CustomerID,
        Country
    HAVING COUNT(*) > 1
) AS DuplicateRecords;


-- Check cancelled invoices
SELECT COUNT(*) AS Cancelled_Invoice_Rows
FROM dbo.onlineRetail
WHERE LTRIM(RTRIM(InvoiceNo)) LIKE 'C%';


-- Check invalid quantities
SELECT COUNT(*) AS Invalid_Quantity_Rows
FROM dbo.onlineRetail
WHERE Quantity IS NULL OR Quantity <= 0;


-- Check invalid prices
SELECT COUNT(*) AS Invalid_UnitPrice_Rows
FROM dbo.onlineRetail
WHERE UnitPrice IS NULL OR UnitPrice <= 0;


-- Check missing customer IDs
SELECT COUNT(*) AS Missing_Customer_Rows
FROM dbo.onlineRetail
WHERE CustomerID IS NULL;


/*====================================================
  CREATE CLEANED TABLE
====================================================*/

DROP TABLE IF EXISTS dbo.OnlineRetail_Cleaned;
GO

WITH Deduplicated AS
(
    SELECT *,
        ROW_NUMBER() OVER
        (
            PARTITION BY
                InvoiceNo,
                StockCode,
                Description,
                Quantity,
                InvoiceDate,
                UnitPrice,
                CustomerID,
                Country
            ORDER BY (SELECT NULL)
        ) AS Row_Num
    FROM dbo.onlineRetail
)

SELECT
    LTRIM(RTRIM(InvoiceNo)) AS InvoiceNo,
    LTRIM(RTRIM(StockCode)) AS StockCode,
    NULLIF(LTRIM(RTRIM(Description)), '') AS Description,
    Quantity,
    InvoiceDate,
    CAST(UnitPrice AS DECIMAL(10,2)) AS UnitPrice,
    CustomerID,
    LTRIM(RTRIM(Country)) AS Country,

    CAST(Quantity * UnitPrice AS DECIMAL(18,2)) AS LineValue

INTO dbo.OnlineRetail_Cleaned

FROM Deduplicated
WHERE Row_Num = 1;
GO

-- Final record count
SELECT COUNT(*) AS Total_Cleaned_Records
FROM dbo.OnlineRetail_Cleaned;

-- Check customers
SELECT COUNT(DISTINCT CustomerID) AS Total_Customers
FROM dbo.OnlineRetail_Cleaned;

-- Check total sales value
SELECT SUM(LineValue) AS Total_Transaction_Value
FROM dbo.OnlineRetail_Cleaned;

-- Check duplicate records
SELECT COUNT(*) AS Remaining_Duplicate_Groups
FROM
(
    SELECT
        InvoiceNo, StockCode, Description, Quantity,
        InvoiceDate, UnitPrice, CustomerID, Country
    FROM dbo.OnlineRetail_Cleaned
    GROUP BY
        InvoiceNo, StockCode, Description, Quantity,
        InvoiceDate, UnitPrice, CustomerID, Country
    HAVING COUNT(*) > 1
) AS D;



/*====================================================
  FINAL BUSINESS DATA SUMMARY
====================================================*/

SELECT
    COUNT(*) AS Total_Transactions,
    COUNT(DISTINCT InvoiceNo) AS Total_Orders,
    COUNT(DISTINCT CustomerID) AS Total_Customers,
    COUNT(DISTINCT StockCode) AS Unique_Products,
    COUNT(DISTINCT Country) AS Total_Countries,
    SUM(Quantity) AS Total_Quantity_Sold,
    SUM(LineValue) AS Total_Sales,
    MIN(InvoiceDate) AS First_Transaction_Date,
    MAX(InvoiceDate) AS Last_Transaction_Date
FROM dbo.OnlineRetail_Cleaned;


/*====================================================
  EXPORT DATA FOR PYTHON
====================================================*/

SELECT *
FROM dbo.OnlineRetail_Cleaned
ORDER BY InvoiceDate;