--Section A 

CREATE SCHEMA bronze;
CREATE SCHEMA silver;
CREATE SCHEMA gold;

create table bronze.dim_customer_raw 
(
customer_key text,
customer_name	text,
region	text,
loyalty_tier text
);

create table bronze.dim_product_raw
(
product_key text,
product_name	text,
category	text,
price_usd text
);

create table bronze.dim_date_raw
(
date_key	text,
full_date	text,
day	text,
month	text,
year text
);

create table bronze.fact_sales_raw
(
sales_key	text,
date_key	text,
customer_key	text,
product_key	text,
quantity	text,
revenue_usd	text,
channel text
);


--Row Counts
SELECT 'dim_customer_raw' as table_name, COUNT(*) AS total_rows FROM bronze.dim_customer_raw
UNION ALL
SELECT 'dim_product_raw', COUNT(*) FROM bronze.dim_product_raw
UNION ALL
SELECT 'dim_date_raw', COUNT(*) FROM bronze.dim_date_raw
UNION ALL
SELECT 'fact_sales_raw', COUNT(*) FROM bronze.fact_sales_raw;


-- Null values in dim_customer_raw 
SELECT
    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS null_customer_key_count,
    SUM(CASE WHEN customer_name IS NULL THEN 1 ELSE 0 END) AS null_customer_name_count,
    SUM(CASE WHEN region IS NULL THEN 1 ELSE 0 END) AS null_region_count,
    SUM(CASE WHEN loyalty_tier IS NULL THEN 1 ELSE 0 END) AS null_loyalty_tier_count
FROM bronze.dim_customer_raw;

-- Null values in dim_product_raw 
SELECT
    SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) AS null_product_key_count,
    SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END) AS null_product_name_count,
    SUM(CASE WHEN category IS NULL THEN 1 ELSE 0 END) AS null_category_count,
    SUM(CASE WHEN price_usd IS NULL THEN 1 ELSE 0 END) AS null_price_usd_count
FROM bronze.dim_product_raw;

-- Null values in dim_date_raw 
SELECT
    SUM(CASE WHEN date_key IS NULL THEN 1 ELSE 0 END) AS null_date_key_count,
    SUM(CASE WHEN full_date IS NULL THEN 1 ELSE 0 END) AS null_full_date_count,
    SUM(CASE WHEN day IS NULL THEN 1 ELSE 0 END) AS null_day_count,
    SUM(CASE WHEN month IS NULL THEN 1 ELSE 0 END) AS null_month_count,
    SUM(CASE WHEN year IS NULL THEN 1 ELSE 0 END) AS null_year_count
FROM bronze.dim_date_raw;

-- Null values in fact_sales_raw 
SELECT
    SUM(CASE WHEN sales_key IS NULL THEN 1 ELSE 0 END) AS null_sales_key_count,
    SUM(CASE WHEN date_key IS NULL THEN 1 ELSE 0 END) AS null_date_key_count,
    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS null_customer_key_count,
    SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) AS null_product_key_count,
    SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) AS null_quantity_count,
    SUM(CASE WHEN revenue_usd IS NULL THEN 1 ELSE 0 END) AS null_revenue_usd_count,
    SUM(CASE WHEN channel IS NULL THEN 1 ELSE 0 END) AS null_channel_count
FROM bronze.fact_sales_raw;


-- Check for duplicate primary keys in dim_customer_raw
SELECT customer_key, COUNT(*) AS frequency
FROM bronze.dim_customer_raw
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- Check for duplicate primary keys in dim_product_raw
SELECT product_key, COUNT(*) AS frequency
FROM bronze.dim_product_raw
GROUP BY product_key
HAVING COUNT(*) > 1;

-- Check for duplicate primary keys in dim_date_raw
SELECT date_key, COUNT(*) AS frequency
FROM bronze.dim_date_raw
GROUP BY date_key
HAVING COUNT(*) > 1;

-- Check for duplicate primary keys in fact_sales_raw
SELECT sales_key, COUNT(*) AS frequency
FROM bronze.fact_sales_raw
GROUP BY sales_key
HAVING COUNT(*) > 1;

-- dim_customer_raw 'customer_key' for non-integer formats
SELECT * FROM bronze.dim_customer_raw
WHERE customer_key !~ '^[0-9]+$';


-- dim_product_raw 'product_key' and 'price_usd' for non-integer formats
SELECT * FROM bronze.dim_product_raw
WHERE product_key !~ '^[0-9]+$'
   OR price_usd !~ '^[0-9]+$';


-- dim_date_raw for format issues
SELECT *
FROM bronze.dim_date_raw
WHERE
    -- Check if date_key is not an integer
    date_key !~ '^[0-9]+$'
    OR
    -- Check if day is not an integer
    day !~ '^[0-9]+$'
    OR
    -- Check if month is not an integer
    month !~ '^[0-9]+$'
    OR
    -- Check if year is not an integer
    year !~ '^[0-9]+$'
    OR
    -- Check if full_date does not match YYYY-MM-DD pattern
    full_date !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$';



-- fact_sales_raw for non-integer formats in all numeric fields
SELECT * FROM bronze.fact_sales_raw
WHERE sales_key !~ '^[0-9]+$'
   OR date_key !~ '^[0-9]+$'
   OR customer_key !~ '^[0-9]+$'
   OR product_key !~ '^[0-9]+$'
   OR quantity !~ '^[0-9]+$'
   OR revenue_usd !~ '^[0-9]+$';


-- SEction B

-- silver.dim_customer
CREATE TABLE silver.dim_customer AS
SELECT DISTINCT
    CAST(trim(customer_key) AS INT) AS customer_key,
    customer_name AS customer_name,
    region AS customer_region,
    loyalty_tier AS customer_loyalty_tier
FROM
    bronze.dim_customer_raw
WHERE customer_key is not NULL AND customer_key ~ '^[0-9]+$';

-- silver.dim_product
CREATE TABLE silver.dim_product AS
SELECT DISTINCT
    CAST(trim(product_key) AS INT) AS product_key,
    product_name AS product_name,
    category AS product_category,
    CAST(trim(price_usd) AS INT) AS product_price_usd
FROM
    bronze.dim_product_raw
WHERE
    product_key IS NOT NULL
    AND product_key ~ '^[0-9]+$'
    AND price_usd IS NOT NULL
    AND price_usd ~ '^[0-9]+$';

-- silver.dim_date
CREATE TABLE silver.dim_date AS
SELECT DISTINCT
    CAST(trim(date_key) AS INT) AS date_key,
    CAST(trim(full_date) AS DATE) AS full_date, 
    CAST(trim(day) AS INT) AS day,
    CAST(trim(month) AS INT) AS month,
    CAST(trim(year) AS INT) AS year
FROM
    bronze.dim_date_raw
WHERE
    date_key IS NOT NULL AND date_key ~ '^[0-9]+$'
    AND full_date IS NOT NULL
    AND day IS NOT NULL AND day ~ '^[0-9]+$'
    AND month IS NOT NULL AND month ~ '^[0-9]+$'
    AND year IS NOT NULL AND year ~ '^[0-9]+$';
	
-- silver.fact_sales_clean
CREATE TABLE silver.fact_sales AS
SELECT DISTINCT
    CAST(TRIM(sales_key) AS INT) AS sales_key,
    CAST(TRIM(date_key) AS INT) AS date_key,
    CAST(TRIM(customer_key) AS INT) AS customer_key,
    CAST(TRIM(product_key) AS DECIMAL)::INT AS product_key,
    CAST(TRIM(quantity) AS INT) AS quantity,
    CAST(TRIM(revenue_usd) AS INT) AS revenue_usd,
    channel AS sales_channel
FROM
    bronze.fact_sales_raw
WHERE
    sales_key IS NOT NULL AND sales_key ~ '^[0-9]+$'
    AND date_key IS NOT NULL AND date_key ~ '^[0-9]+$'
    AND customer_key IS NOT NULL AND customer_key ~ '^[0-9]+$'
    AND product_key IS NOT NULL AND product_key ~ '^[0-9]+(\.[0-9]+)?$'
    AND quantity IS NOT NULL AND quantity ~ '^[0-9]+$'
    AND revenue_usd IS NOT NULL AND revenue_usd ~ '^[0-9]+$';

-- Section C

-- gold.dim_customer
CREATE TABLE gold.dim_customer (
    customer_sk SERIAL PRIMARY KEY,
    customer_key INT NOT NULL,
    customer_name VARCHAR(255),
    customer_region VARCHAR(100),
    customer_loyalty_tier VARCHAR(50)
);

INSERT INTO gold.dim_customer (customer_key, customer_name, customer_region, customer_loyalty_tier)
SELECT customer_key, customer_name, customer_region, customer_loyalty_tier
FROM silver.dim_customer;

-- gold.dim_product
CREATE TABLE gold.dim_product (
    product_sk SERIAL PRIMARY KEY,  
    product_key INT NOT NULL,
    product_name VARCHAR(255),
    product_category VARCHAR(100),
    product_price_usd INT
);

INSERT INTO gold.dim_product (product_key, product_name, product_category, product_price_usd)
SELECT product_key, product_name, product_category, product_price_usd
FROM silver.dim_product;
   

-- gold.dim_date
CREATE TABLE gold.dim_date (
    date_sk SERIAL PRIMARY KEY, 
    date_key INT NOT NULL,
    full_date DATE,
    day INT,
    month INT,
    year INT
);

INSERT INTO gold.dim_date (date_key, full_date, day, month, year)
SELECT date_key, full_date, day, month, year
FROM silver.dim_date;

-- gold.fact_sales
CREATE TABLE gold.fact_sales AS
SELECT
    s.sales_key,
    d.date_sk,         
    c.customer_sk,       
    p.product_sk,       
    s.quantity,
    s.revenue_usd,
    s.sales_channel 
FROM silver.fact_sales s
JOIN gold.dim_customer c
    ON s.customer_key = c.customer_key
JOIN gold.dim_product p
    ON s.product_key = p.product_key
JOIN gold.dim_date d
    ON s.date_key = d.date_key;  


-- Revenue by Region
CREATE TABLE gold.sales_by_region AS
SELECT 
    c.customer_region,
    SUM(s.revenue_usd) AS total_revenue,
    COUNT(*) AS total_transactions,
    AVG(s.revenue_usd) AS avg_transaction_value
FROM gold.fact_sales s
JOIN gold.dim_customer c ON s.customer_sk = c.customer_sk
GROUP BY c.customer_region;


-- Revenue by Product Category
CREATE TABLE gold.sales_by_category AS
SELECT 
    p.product_category,
    SUM(s.revenue_usd) AS total_revenue,
    SUM(s.quantity) AS total_quantity,
    COUNT(DISTINCT p.product_sk) AS unique_products
FROM gold.fact_sales s
JOIN gold.dim_product p ON s.product_sk = p.product_sk
GROUP BY p.product_category;

-- Monthly Sales
CREATE TABLE gold.monthly_sales AS
SELECT 
    d.year,
    d.month,
    d.full_date,
    SUM(s.revenue_usd) AS monthly_revenue,
    SUM(s.quantity) AS monthly_quantity,
    COUNT(*) AS monthly_transactions
FROM gold.fact_sales s
JOIN gold.dim_date d ON s.date_sk = d.date_sk
GROUP BY d.year, d.month, d.full_date
ORDER BY d.year, d.month;

-- Customer Lifetime Value
CREATE TABLE gold.customer_lifetime_value AS
SELECT 
    c.customer_key,
    c.customer_name,
    c.customer_region,
    COUNT(*) AS total_transactions,
    SUM(s.revenue_usd) AS lifetime_revenue,
    AVG(s.revenue_usd) AS avg_order_value,
    MAX(d.full_date) AS last_purchase_date
FROM gold.fact_sales s
JOIN gold.dim_customer c ON s.customer_sk = c.customer_sk
JOIN gold.dim_date d ON s.date_sk = d.date_sk
GROUP BY c.customer_key, c.customer_name, c.customer_region;


-- Section D

-- MERGE INTO silver.dim_customer (Upsert)
MERGE INTO silver.dim_customer t
USING (
    SELECT DISTINCT
        CAST(TRIM(customer_key) AS INT) AS customer_key,
        customer_name,
        region AS customer_region,
        loyalty_tier AS customer_loyalty_tier
    FROM bronze.dim_customer_raw
    WHERE customer_key IS NOT NULL AND customer_key ~ '^[0-9]+$'
) s ON t.customer_key = s.customer_key
WHEN MATCHED THEN
    UPDATE SET
        customer_name = s.customer_name,
        customer_region = s.customer_region,
        customer_loyalty_tier = s.customer_loyalty_tier
WHEN NOT MATCHED THEN
    INSERT (customer_key, customer_name, customer_region, customer_loyalty_tier)
    VALUES (s.customer_key, s.customer_name, s.customer_region, s.customer_loyalty_tier);


-- Create initial history snapshot
CREATE TABLE silver.dim_customer_history AS
SELECT *, CURRENT_TIMESTAMP AS version_ts, '2025-12-08 12:49:00'::TIMESTAMP AS load_ts
FROM silver.dim_customer;

-- After MERGE, capture new version
INSERT INTO silver.dim_customer_history
SELECT *, CURRENT_TIMESTAMP AS version_ts, CURRENT_TIMESTAMP AS load_ts
FROM silver.dim_customer;


-- Query specific version by timestamp
SELECT * FROM silver.dim_customer_history
WHERE version_ts BETWEEN '2025-12-08 12:00:00' AND '2025-12-08 13:00:00';

-- Latest version only
SELECT * FROM silver.dim_customer_history
WHERE version_ts = (SELECT MAX(version_ts) FROM silver.dim_customer_history);

-- Compare versions
SELECT 
    c1.customer_key,
    c1.customer_name AS current_name,
    c2.customer_name AS previous_name,
    c1.version_ts
FROM silver.dim_customer_history c1
LEFT JOIN silver.dim_customer_history c2 
    ON c1.customer_key = c2.customer_key 
    AND c2.version_ts = (SELECT MAX(version_ts) FROM silver.dim_customer_history WHERE version_ts < c1.version_ts);

-- Add new column 
ALTER TABLE silver.fact_sales 
ADD COLUMN source_system TEXT DEFAULT 'legacy_crm';
