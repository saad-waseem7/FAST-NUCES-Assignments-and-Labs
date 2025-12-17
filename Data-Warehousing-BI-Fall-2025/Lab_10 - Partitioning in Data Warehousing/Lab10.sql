--Section A – Base Setup
--Task 1 – Create Partitioning Schema
CREATE SCHEMA IF NOT EXISTS partition_lab;
SET search_path TO partition_lab;

--Task 2 – Create a Non-Partitioned Fact Table
CREATE TABLE partition_lab.fact_sales (
    sales_key     INT,
    date_key      INT,
    customer_key  INT,
    product_key   INT,
    quantity      INT,
    revenue_usd   NUMERIC,
    channel       TEXT
);


select * from partition_lab.fact_sales;

--Section B – Horizontal Partitioning (Range + List + Hash)

--Task 1 – Range Partitioning by Year (Date Dimension)
--1. Create the parent table:
CREATE TABLE fact_sales_horz (
    sales_key     INT,
    date_key      INT,
    year          INT,
    customer_key  INT,
    product_key   INT,
    quantity      INT,
    revenue_usd   NUMERIC,
    channel       TEXT
) PARTITION BY RANGE (date_key);

INSERT INTO fact_sales_horz (sales_key, date_key, year, customer_key, product_key, quantity, revenue_usd, channel)
SELECT
    sales_key,
    date_key,
    date_key / 10000 AS year, -- if date_key is YYYYMMDD, extract year
    customer_key,
    product_key,
    quantity,
    revenue_usd,
    channel
FROM partition_lab.fact_sales;

CREATE TABLE fact_sales_2023 PARTITION OF fact_sales_horz
    FOR VALUES FROM (20230101) TO (20231231);

CREATE TABLE fact_sales_2024 PARTITION OF fact_sales_horz
    FOR VALUES FROM (20240101) TO (20241231);

--4. Validate Partition Pruning
EXPLAIN ANALYZE
SELECT SUM(revenue_usd)
FROM fact_sales_horz
WHERE date_key BETWEEN 20230101 AND 20230131;

--5. Create List Partitioned Table
CREATE TABLE fact_sales_list (
    sales_key     INT,
    date_key      INT,
    customer_key  INT,
    product_key   INT,
    quantity      INT,
    revenue_usd   NUMERIC,
    channel       TEXT
) PARTITION BY LIST (channel);

CREATE TABLE fact_sales_online
PARTITION OF fact_sales_list
FOR VALUES IN ('Online');

CREATE TABLE fact_sales_store
PARTITION OF fact_sales_list
FOR VALUES IN ('InStore');

INSERT INTO fact_sales_list
SELECT *
FROM partition_lab.fact_sales;

--6. Query Partition Specific Data
EXPLAIN ANALYZE
SELECT SUM(revenue_usd)
FROM fact_sales_list
WHERE channel = 'Online';

--Task 3 – Hash Partitioning by Customer Key
--7. Create Hash Partitioned Table
CREATE TABLE fact_sales_hash (
    sales_key     INT,
    date_key      INT,
    customer_key  INT,
    product_key   INT,
    quantity      INT,
    revenue_usd   NUMERIC,
    channel       TEXT
) PARTITION BY HASH (customer_key);

--Create 4 hash buckets:
CREATE TABLE fact_sales_h0 PARTITION OF fact_sales_hash FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE fact_sales_h1 PARTITION OF fact_sales_hash FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE fact_sales_h2 PARTITION OF fact_sales_hash FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE fact_sales_h3 PARTITION OF fact_sales_hash FOR VALUES WITH (MODULUS 4, REMAINDER 3);

INSERT INTO fact_sales_hash
SELECT * FROM partition_lab.fact_sales;

--8. Validate Hash Distribution
SELECT 'P0', COUNT(*) FROM fact_sales_h0 UNION ALL
SELECT 'P1', COUNT(*) FROM fact_sales_h1 UNION ALL
SELECT 'P2', COUNT(*) FROM fact_sales_h2 UNION ALL
SELECT 'P3', COUNT(*) FROM fact_sales_h3;

--9. Create Two Vertical Tables
--Hot Table
CREATE TABLE product_hot (
    product_key INT PRIMARY KEY,
    category TEXT,
    price_usd NUMERIC
);
--Cold Table
CREATE TABLE product_cold (
    product_key INT PRIMARY KEY REFERENCES product_hot(product_key),
    product_name TEXT
);

CREATE TABLE partition_lab.product (
    product_key   SERIAL PRIMARY KEY,
    product_name  VARCHAR(100) NOT NULL,
    category      VARCHAR(50),
    price_usd     DECIMAL(10, 2)
);

INSERT INTO product_hot (product_key, category, price_usd)
SELECT product_key, category, price_usd FROM partition_lab.product;

INSERT INTO product_cold (product_key, product_name)
SELECT product_key, product_name FROM partition_lab.product;

--10. Compare Query Performance
--Query only hot columns:
EXPLAIN ANALYZE  
SELECT 
    category,
    AVG(price_usd) as avg_price
FROM product_hot 
GROUP BY category;

--Query needing cold column join:
EXPLAIN ANALYZE  
SELECT ph.category, pc.product_name  
FROM product_hot ph  
JOIN product_cold pc USING (product_key);

--11. OLTP style Query
EXPLAIN ANALYZE  
SELECT * FROM fact_sales_horz  
WHERE sales_key = 155;

--12. DSS style Query
EXPLAIN ANALYZE  
SELECT customer_key, SUM(revenue_usd)  
FROM fact_sales_horz  
GROUP BY customer_key;

