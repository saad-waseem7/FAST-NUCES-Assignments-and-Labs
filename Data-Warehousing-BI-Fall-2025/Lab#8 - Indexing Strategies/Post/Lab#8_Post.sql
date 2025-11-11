
--Section A – Setup
-- Create schemas
CREATE SCHEMA IF NOT EXISTS bookverse_stg;
CREATE SCHEMA IF NOT EXISTS bookverse_dw;

-- Create staging tables in bookverse_stg schema
CREATE TABLE bookverse_stg.bookverse_sales (
    sale_id INT PRIMARY KEY,
    book_id INT,
    cust_id INT,
    sale_date DATE,
    quantity INT,
    revenue_usd DECIMAL(10, 2)
);

CREATE TABLE bookverse_stg.bookverse_customers (
    cust_id INT PRIMARY KEY,
    region VARCHAR(50),
    age_group VARCHAR(50)
);

CREATE TABLE bookverse_stg.bookverse_books (
    book_id INT PRIMARY KEY,
    title VARCHAR(255),
    author_id INT,
    genre VARCHAR(100),
    price_usd DECIMAL(10, 2)
);

CREATE TABLE bookverse_stg.bookverse_authors (
    author_id INT PRIMARY KEY,
    author_name VARCHAR(255),
    country VARCHAR(100)
);

--Create DW Tables
-- Dimension tables with surrogate keys
CREATE TABLE bookverse_dw.dim_author (
    author_sk SERIAL PRIMARY KEY,
    author_id INT UNIQUE NOT NULL,
    author_name VARCHAR(255),
    country VARCHAR(100)
);

CREATE TABLE bookverse_dw.dim_book (
    book_sk SERIAL PRIMARY KEY,
    book_id INT UNIQUE NOT NULL,
    title VARCHAR(255),
    author_sk INT NOT NULL,
    genre VARCHAR(100),
    price_usd DECIMAL(10, 2),
    FOREIGN KEY (author_sk) REFERENCES bookverse_dw.dim_author(author_sk)
);

CREATE TABLE bookverse_dw.dim_customer (
    customer_sk SERIAL PRIMARY KEY,
    cust_id INT UNIQUE NOT NULL,
    region VARCHAR(50),
    age_group VARCHAR(50)
);

CREATE TABLE bookverse_dw.dim_date (
    date_sk SERIAL PRIMARY KEY,
    date DATE UNIQUE NOT NULL,
    year INT,
    quarter INT,
    month INT,
    day INT,
    day_of_week INT
);

-- Fact table
CREATE TABLE bookverse_dw.fact_sales (
    sale_sk SERIAL PRIMARY KEY,
    sale_id INT UNIQUE NOT NULL,
    book_sk INT NOT NULL,
    customer_sk INT NOT NULL,
    cust_id INT NOT NULL,  
    date_sk INT NOT NULL,
    quantity INT,
    revenue_usd DECIMAL(10, 2),
    FOREIGN KEY (book_sk) REFERENCES bookverse_dw.dim_book(book_sk),
    FOREIGN KEY (customer_sk) REFERENCES bookverse_dw.dim_customer(customer_sk),
    FOREIGN KEY (date_sk) REFERENCES bookverse_dw.dim_date(date_sk)
);

-- Load authors with surrogate keys
INSERT INTO bookverse_dw.dim_author (author_id, author_name, country)
SELECT DISTINCT author_id, author_name, country
FROM bookverse_stg.bookverse_authors;

-- Load books linking to dim_author
INSERT INTO bookverse_dw.dim_book (book_id, title, author_sk, genre, price_usd)
SELECT b.book_id, b.title, a.author_sk, b.genre, b.price_usd
FROM bookverse_stg.bookverse_books b
JOIN bookverse_dw.dim_author a ON b.author_id = a.author_id;

-- Load customers with surrogate keys
INSERT INTO bookverse_dw.dim_customer (cust_id, region, age_group)
SELECT DISTINCT cust_id, region, age_group
FROM bookverse_stg.bookverse_customers;

-- Load date dimension with date parts extracted
INSERT INTO bookverse_dw.dim_date (date, year, quarter, month, day, day_of_week)
SELECT DISTINCT 
    sale_date AS date,
    EXTRACT(YEAR FROM sale_date),
    EXTRACT(QUARTER FROM sale_date),
    EXTRACT(MONTH FROM sale_date),
    EXTRACT(DAY FROM sale_date),
    EXTRACT(DOW FROM sale_date)
FROM bookverse_stg.bookverse_sales;

-- Load fact sales joining surrogate keys
INSERT INTO bookverse_dw.fact_sales (sale_id, book_sk, customer_sk, cust_id, date_sk, quantity, revenue_usd)
SELECT 
    s.sale_id,
    b.book_sk,
    c.customer_sk,
    s.cust_id,  -- source cust_id included in insert
    d.date_sk,
    s.quantity,
    s.revenue_usd
FROM bookverse_stg.bookverse_sales s
JOIN bookverse_dw.dim_book b ON s.book_id = b.book_id
JOIN bookverse_dw.dim_customer c ON s.cust_id = c.cust_id
JOIN bookverse_dw.dim_date d ON s.sale_date = d.date;

--Q11. B-Tree vs Hash Index
CREATE INDEX idx_fact_sales_book_sk_btree ON bookverse_dw.fact_sales USING btree(book_sk);
CREATE INDEX idx_fact_sales_book_sk_hash ON bookverse_dw.fact_sales USING hash(book_sk);

EXPLAIN ANALYZE
SELECT SUM(revenue_usd) AS total_revenue
FROM bookverse_dw.fact_sales
WHERE book_sk = 90;

--Q12. Composite & Clustered Index
CREATE INDEX idx_fact_sales_book_sk_date_sk ON bookverse_dw.fact_sales (book_sk, date_sk);

CLUSTER bookverse_dw.fact_sales USING idx_fact_sales_book_sk_date_sk;

EXPLAIN ANALYZE
SELECT * FROM bookverse_dw.fact_sales
WHERE book_sk = 56
AND date_sk = 254;  

--Q13. Bitmap Index Simulation
CREATE INDEX idx_fact_sales_book_sk_btree ON bookverse_dw.fact_sales USING btree(book_sk);

CREATE INDEX idx_fact_sales_book_sk_hash ON bookverse_dw.fact_sales USING hash(book_sk);

EXPLAIN ANALYZE
SELECT SUM(revenue_usd)
FROM bookverse_dw.fact_sales
WHERE book_sk = 70; 

--Q15. Create a Materialized View
CREATE MATERIALIZED VIEW monthly_total_revenue AS
SELECT
    date_trunc('month', d.date) AS month,
    SUM(f.revenue_usd) AS total_revenue
FROM bookverse_dw.fact_sales f
JOIN bookverse_dw.dim_date d ON f.date_sk = d.date_sk
GROUP BY month
WITH DATA;

EXPLAIN ANALYZE
SELECT * FROM monthly_total_revenue
WHERE month = '300';  

EXPLAIN ANALYZE
SELECT
    date_trunc('month', d.date) AS month,
    SUM(f.revenue_usd) AS total_revenue
FROM bookverse_dw.fact_sales f
JOIN bookverse_dw.dim_date d ON f.date_sk = d.date_sk
GROUP BY month
WHERE month = '300';
