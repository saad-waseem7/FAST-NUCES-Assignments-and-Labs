create database dw_lab;

DROP SCHEMA IF EXISTS dw CASCADE;
create SCHEMA dw;


-- Create Staging Tables
DROP TABLE IF EXISTS staging_sales, staging_customer, staging_product CASCADE;
create table staging_sales (
    order_id int,
    customer_id int,
    product_id int,
    order_date DATE,
    quantity int,
    revenue NUMERIC
);

create table staging_customer (
    customer_id int,
    customer_name text,
    region text
);
create table staging_product (
    product_id int,
    product_name text,
    category text
);

-- Create DW Tables
DROP TABLE IF EXISTS dw.fact_sales, dw.dim_customer, dw.dim_product, dw.dim_date, dw.error_log CASCADE;

create table dw.dim_customer (
    customer_key serial primary key,
    customer_id int UNIQUE,
    customer_name text,
    region text
);

create table dw.dim_product (
    product_key serial primary key,
    product_id int UNIQUE,
    product_name text,
    category text
);

create table dw.dim_date (
    date_key serial primary key,
    order_date DATE UNIQUE
);

create table dw.fact_sales (
    sales_id serial primary key,
    customer_key int references dw.dim_customer(customer_key),
    product_key int references dw.dim_product(product_key),
    date_key int references dw.dim_date(date_key),
    quantity int,
    revenue NUMERIC
);

create table dw.error_log (
    error_id serial primary key,
    table_name text,
    error_reason text,
    bad_data JSonB,
    logged_at TIMESTAMP DEFAULT NOW()
);


-- Load Data from CSV 

-- Populate Dimension Tables

insert into dw.dim_customer (customer_id, customer_name, region)
select distinct customer_id, customer_name, region from staging_customer;

insert into dw.dim_product (product_id, product_name, category)
select distinct product_id, product_name, category from staging_product;

insert into dw.dim_date (order_date)
select distinct order_date from staging_sales;


-- 8. Handle Late-Arriving Customers
-- Example: insert order for a customer not in dim_customer
insert into staging_sales (order_id, customer_id, product_id, order_date, quantity, revenue)
VALUES (999, 5000, 101, '2025-09-29', 2, 200);

-- Insert missing customers as 'Unknown'
insert into dw.dim_customer (customer_id, customer_name, region)
select distinct s.customer_id, 'Unknown', 'Unknown'
from staging_sales s
LEFT join dw.dim_customer d on s.customer_id = d.customer_id
where d.customer_id IS NULL;


-- 9. Slowly Changing Dimension (Type 1)
-- Example update: change region of a customer
UPDATE staging_customer SET region = 'NewRegion' where customer_id = 1001;

-- Overwrite old value in dimension
UPDATE dw.dim_customer d
SET region = s.region
from staging_customer s
where d.customer_id = s.customer_id;


-- 10. Error Handling
-- Insert bad data
insert into staging_sales VALUES (10000, 1001, NULL, '2025-09-29', -5, -500);

-- Log invalid rows
insert into dw.error_log (table_name, error_reason, bad_data)
SELECT 'staging_sales',
       CASE 
         WHEN product_id IS NULL THEN 'NULL product_id'
         WHEN quantity < 0 THEN 'Negative quantity'
       END,
       to_jsonb(s)
from staging_sales s
where product_id IS NULL OR quantity < 0;

-- Remove invalid rows
DELETE from staging_sales where product_id IS NULL OR quantity < 0;


-- 11. Load Fact Table
insert into dw.fact_sales (customer_key, product_key, date_key, quantity, revenue)
SELECT d1.customer_key, d2.product_key, d3.date_key, s.quantity, s.revenue
from staging_sales s
join dw.dim_customer d1 on s.customer_id = d1.customer_id
join dw.dim_product d2 on s.product_id = d2.product_id
join dw.dim_date d3 on s.order_date = d3.order_date;