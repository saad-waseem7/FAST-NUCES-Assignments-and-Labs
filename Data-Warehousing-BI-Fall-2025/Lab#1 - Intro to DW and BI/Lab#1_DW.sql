USE master;
GO

-- Create Database
CREATE DATABASE salesdb;
GO

-- Switch to the new database
USE salesdb;
GO

-- Create Sales table
CREATE TABLE Sales (
    sale_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    region VARCHAR(50),
    sale_date DATE,
    quantity INT,
    unit_price DECIMAL(10,2)
);
GO

-- Insert sample data
INSERT INTO Sales (sale_id, product_name, category, region, sale_date, quantity, unit_price)
VALUES
(1, 'Laptop', 'Electronics', 'North', '2024-01-15', 5, 800.00),
(2, 'Mobile Phone', 'Electronics', 'South', '2024-01-20', 10, 500.00),
(3, 'Desk Chair', 'Furniture', 'East', '2024-02-05', 7, 120.00),
(4, 'Tablet', 'Electronics', 'West', '2024-02-10', 8, 300.00),
(5, 'Headphones', 'Electronics', 'North', '2024-02-15', 15, 100.00),
(6, 'Office Desk', 'Furniture', 'East', '2024-02-18', 6, 200.00),
(7, 'Smartwatch', 'Electronics', 'South', '2024-03-01', 12, 250.00),
(8, 'Bookshelf', 'Furniture', 'West', '2024-03-05', 4, 150.00),
(9, 'Printer', 'Electronics', 'North', '2024-03-10', 9, 400.00),
(10, 'Monitor', 'Electronics', 'South', '2024-03-15', 11, 350.00);
GO

ALTER TABLE Sales
ADD Revenue AS (quantity * unit_price);
GO

SELECT * FROM Sales