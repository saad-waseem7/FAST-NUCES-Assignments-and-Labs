--Step 1
Create database Sales_DW
GO
Use Sales_DW
GO

--Step 2
--Create Customer dimension table in Data Warehouse which will hold customer personal details.
Create table DimCustomer
(
CustomerID int primary key identity,
CustomerAltID varchar(10) not null,
CustomerName varchar(50),
Gender varchar(20)
)
GO
--Fill the Customer dimension with sample Values
Insert into DimCustomer(CustomerAltID,CustomerName,Gender)values
('IMI-001','Henry Ford','M'),
('IMI-002','Bill Gates','M'),
('IMI-003','Muskan Shaikh','F'),
('IMI-004','Richard Thrubin','M'),
('IMI-005','Emma Wattson','F');
GO

--Step 3
--Create basic level of Product Dimension table without considering any CateGOry or SubcateGOry
Create table DimProduct
(
ProductKey int primary key identity,
ProductAltKey varchar(10)not null,
ProductName varchar(100),
ProductActualCost money,
ProductSalesCost money
)
GO
--Fill the Product dimension with sample Values
Insert into DimProduct(ProductAltKey,ProductName, ProductActualCost, ProductSalesCost)values
('ITM-001','Wheat Floor 1kg',5.50,6.50),
('ITM-002','Rice Grains 1kg',22.50,24),
('ITM-003','SunFlower Oil 1 ltr',42,43.5),
('ITM-004','Nirma Soap',18,20),
('ITM-005','Arial Washing Powder 1kg',135,139);
GO


--Step 4
--Create a Store Dimension table which will hold details related to stores available across various places.
Create table DimStores(
StoreID int primary key identity,
StoreAltID varchar(10)not null,
StoreName varchar(100),
StoreLocation varchar(100),
City varchar(100),
State varchar(100),
Country varchar(100)
)
GO
--Fill the Store Dimension with sample Values
Insert into DimStores(StoreAltID,StoreName,StoreLocation,City,State,Country )values
('LOC-A1','X-Mart','S.P. RingRoad','Ahmedabad','Guj','India'),
('LOC-A2','X-Mart','Maninagar','Ahmedabad','Guj','India'),
('LOC-A3','X-Mart','Sivranjani','Ahmedabad','Guj','India');
GO

--Step 5
--Create a Dimension Sales Person table which will hold details related to stores available across various places.
Create table DimSalesPerson
(
SalesPersonID int primary key identity,
SalesPersonAltID varchar(10)not null,
SalesPersonName varchar(100),
StoreID int,
City varchar(100),
State varchar(100),
Country varchar(100)
)
GO
--Fill the Dimension Sales Person with sample values:
Insert into DimSalesPerson(SalesPersonAltID,SalesPersonName,StoreID,City,State,Country )values
('SP-DMSPR1','Ashish',1,'Ahmedabad','Guj','India'),
('SP-DMSPR2','Ketan',1,'Ahmedabad','Guj','India'),
('SP-DMNGR1','Srinivas',2,'Ahmedabad','Guj','India'),
('SP-DMNGR2','Saad',2,'Ahmedabad','Guj','India'),
('SP-DMSVR1','Jasmin',3,'Ahmedabad','Guj','India'),
('SP-DMSVR2','Jacob',3,'Ahmedabad','Guj','India');
GO


--Step 6
CREATE TABLE DimDate
(
    DateKey INT PRIMARY KEY,            -- Format: YYYYMMDD
    FullDate DATE NOT NULL,
    Day TINYINT NOT NULL,
    Month TINYINT NOT NULL,
    Year SMALLINT NOT NULL,
    Quarter TINYINT NOT NULL,
    DayOfWeek TINYINT NOT NULL,         -- 1=Sunday, 7=Saturday
    WeekDayName VARCHAR(10) NOT NULL,
    MonthName VARCHAR(20) NOT NULL,
    IsWeekend BIT NOT NULL,
    FiscalYear SMALLINT NOT NULL,
    FiscalQuarter TINYINT NOT NULL
);
GO

DECLARE @StartDate DATE = '2010-01-01';
DECLARE @EndDate DATE = '2030-12-31';

WITH DateRange AS
(
    SELECT @StartDate AS DateValue
    UNION ALL
    SELECT DATEADD(DAY, 1, DateValue)
    FROM DateRange
    WHERE DateValue < @EndDate
)
INSERT INTO DimDate (DateKey, FullDate, Day, Month, Year, Quarter, DayOfWeek, WeekDayName, MonthName, IsWeekend, FiscalYear, FiscalQuarter)
SELECT 
    CONVERT(INT, FORMAT(DateValue, 'yyyyMMdd')) AS DateKey,
    DateValue,
    DAY(DateValue) AS Day,
    MONTH(DateValue) AS Month,
    YEAR(DateValue) AS Year,
    DATEPART(QUARTER, DateValue) AS Quarter,
    DATEPART(WEEKDAY, DateValue) AS DayOfWeek,
    DATENAME(WEEKDAY, DateValue) AS WeekDayName,
    DATENAME(MONTH, DateValue) AS MonthName,
    CASE WHEN DATEPART(WEEKDAY, DateValue) IN (1,7) THEN 1 ELSE 0 END AS IsWeekend,
    CASE 
       WHEN MONTH(DateValue) >= 4 THEN YEAR(DateValue)
       ELSE YEAR(DateValue) - 1
    END AS FiscalYear,
    CASE 
       WHEN MONTH(DateValue) >= 4 THEN DATEPART(QUARTER, DateValue)
       ELSE ((DATEPART(QUARTER, DateValue) + 3) % 4) + 1
    END AS FiscalQuarter
FROM DateRange
OPTION (MAXRECURSION 0);
GO

select * from DimDate;

--Step 7
CREATE TABLE Dim_Time
(
    TimeKey INT PRIMARY KEY,           -- Seconds from midnight (0 to 86399)
    TimeValue TIME(0) NOT NULL,
    Hour24 TINYINT NOT NULL,
    Hour12 TINYINT NOT NULL,
    AMPM CHAR(2) NOT NULL,
    Minute TINYINT NOT NULL,
    Second TINYINT NOT NULL,
    TimeDescription VARCHAR(20),
    TimeCateGOry VARCHAR(20)
);
GO

DECLARE @Second INT = 0;

WHILE @Second < 86400
BEGIN
    DECLARE @Time TIME(0) = DATEADD(SECOND, @Second, '00:00:00');
    DECLARE @Hour24 TINYINT = DATEPART(HOUR, @Time);
    DECLARE @Minute TINYINT = DATEPART(MINUTE, @Time);
    DECLARE @SecondPart TINYINT = DATEPART(SECOND, @Time);
    DECLARE @AMPM CHAR(2) = CASE WHEN @Hour24 < 12 THEN 'AM' ELSE 'PM' END;
    DECLARE @Hour12 TINYINT = CASE 
                                WHEN @Hour24 = 0 THEN 12 
                                WHEN @Hour24 > 12 THEN @Hour24 - 12 
                                ELSE @Hour24
                             END;
    DECLARE @TimeDesc VARCHAR(20) = FORMAT(@Time, 'hh:mm:ss');
    
    DECLARE @TimeCat VARCHAR(20) =
        CASE 
            WHEN @Hour24 >= 5 AND @Hour24 < 12 THEN 'Morning'
            WHEN @Hour24 >= 12 AND @Hour24 < 17 THEN 'Afternoon'
            WHEN @Hour24 >= 17 AND @Hour24 < 21 THEN 'Evening'
            ELSE 'Night'
        END;

    INSERT INTO Dim_Time (TimeKey, TimeValue, Hour24, Hour12, AMPM, Minute, Second, TimeDescription, TimeCateGOry)
    VALUES (@Second, @Time, @Hour24, @Hour12, @AMPM, @Minute, @SecondPart, @TimeDesc, @TimeCat);

    SET @Second = @Second + 1;
END;
GO

select * from Dim_Time;

--Step 8

Create Table FactProductSales
(
TransactionId bigint primary key identity,
SalesInvoiceNumber int not null,
SalesDateKey int,
SalesTimeKey int,
SalesTimeAltKey int,
StoreID int not null,
CustomerID int not null,
ProductID int not null,
SalesPersonID int not null,
Quantity float,
SalesTotalCost money,
ProductActualCost money,
Deviation float
)
GO

-- Add relation between fact table foreign keys to Primary keys of Dimensions
AlTER TABLE FactProductSales ADD CONSTRAINT
FK_StoreID FOREIGN KEY (StoreID)REFERENCES DimStores(StoreID);
AlTER TABLE FactProductSales ADD CONSTRAINT
FK_CustomerID FOREIGN KEY (CustomerID)REFERENCES Dimcustomer(CustomerID);
AlTER TABLE FactProductSales ADD CONSTRAINT
FK_ProductKey FOREIGN KEY (ProductID)REFERENCES Dimproduct(ProductKey);
AlTER TABLE FactProductSales ADD CONSTRAINT
FK_SalesPersonID FOREIGN KEY (SalesPersonID)REFERENCES Dimsalesperson(SalesPersonID);
GO
AlTER TABLE FactProductSales ADD CONSTRAINT
FK_SalesDateKey FOREIGN KEY (SalesDateKey)REFERENCES DimDate(DateKey);
GO
AlTER TABLE FactProductSales ADD CONSTRAINT
FK_SalesTimeKey FOREIGN KEY (SalesTimeKey)REFERENCES Dim_Time(TimeKey);
GO

INSERT INTO FactProductSales (
    SalesInvoiceNumber, SalesDateKey, SalesTimeKey, SalesTimeAltKey,
    StoreID, CustomerID, ProductID, SalesPersonID, Quantity,
    ProductActualCost, SalesTotalCost, Deviation
) VALUES
-- Sales on 1-Jan-2013
(1, 20130101, 44347, 121907, 1, 1, 1, 1, 2, 11, 13, 2),
(1, 20130101, 44347, 121907, 1, 1, 2, 1, 1, 22.50, 24, 1.5),
(1, 20130101, 44347, 121907, 1, 1, 3, 1, 1, 42, 43.5, 1.5),
(2, 20130101, 44519, 122159, 1, 2, 3, 1, 1, 42, 43.5, 1.5),
(2, 20130101, 44519, 122159, 1, 2, 4, 1, 3, 54, 60, 6),
(3, 20130101, 52415, 143335, 1, 3, 2, 2, 2, 11, 13, 2),
(3, 20130101, 52415, 143335, 1, 3, 3, 2, 1, 42, 43.5, 1.5),
(3, 20130101, 52415, 143335, 1, 3, 4, 2, 3, 54, 60, 6),
(3, 20130101, 52415, 143335, 1, 3, 5, 2, 1, 135, 139, 4),
-- Sales on 2-Jan-2013
(4, 20130102, 44347, 121907, 1, 1, 1, 1, 2, 11, 13, 2),
(4, 20130102, 44347, 121907, 1, 1, 2, 1, 1, 22.50, 24, 1.5),
(5, 20130102, 44519, 122159, 1, 2, 3, 1, 1, 42, 43.5, 1.5),
(5, 20130102, 44519, 122159, 1, 2, 4, 1, 3, 54, 60, 6),
(6, 20130102, 52415, 143335, 1, 3, 2, 2, 2, 11, 13, 2),
(6, 20130102, 52415, 143335, 1, 3, 5, 2, 1, 135, 139, 4),
(7, 20130102, 44347, 121907, 2, 1, 4, 3, 3, 54, 60, 6),
(7, 20130102, 44347, 121907, 2, 1, 5, 3, 1, 135, 139, 4),
-- Sales on 3-Jan-2013
(8, 20130103, 59326, 162846, 1, 1, 3, 1, 2, 84, 87, 3),
(8, 20130103, 59326, 162846, 1, 1, 4, 1, 3, 54, 60, 3),
(9, 20130103, 59349, 162909, 1, 2, 1, 1, 1, 5.5, 6.5, 1),
(9, 20130103, 59349, 162909, 1, 2, 2, 1, 1, 22.50, 24, 1.5),
(10, 20130103, 67390, 184310, 1, 3, 1, 2, 2, 11, 13, 2),
(10, 20130103, 67390, 184310, 1, 3, 4, 2, 3, 54, 60, 6),
(11, 20130103, 74877, 204757, 2, 1, 2, 3, 1, 5.5, 6.5, 1),
(11, 20130103, 74877, 204757, 2, 1, 3, 3, 1, 42, 43.5, 1.5);

GO
select * from FactProductSales
