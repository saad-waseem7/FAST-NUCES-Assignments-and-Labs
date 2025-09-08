DROP SCHEMA IF EXISTS dw_lab CASCADE;
CREATE SCHEMA dw_lab;
SET search_path = dw_lab, public;

CREATE TABLE regions_oltp (
    region_id    integer GENERATED ALWAYS as IDENTITY PRIMARY KEY,
    region_name  text NOT NULL
);

CREATE TABLE customers_oltp (
    customer_id   integer GENERATED ALWAYS as IDENTITY PRIMARY KEY,
    customer_name text NOT NULL,
    region_id     integer NOT NULL REFERENCES regions_oltp(region_id),
    signup_date   date NOT NULL
);

CREATE TABLE products_oltp (
    product_id   integer GENERATED ALWAYS as IDENTITY PRIMARY KEY,
    product_name text NOT NULL,
    category     text NOT NULL,
    unit_price   numeric(12,2) NOT NULL
);

CREATE TABLE orders_oltp (
    order_id    integer GENERATED ALWAYS as IDENTITY PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES customers_oltp(customer_id),
    order_ts    timestamp NOT NULL
);

CREATE TABLE order_items_oltp (
    order_item_id integer GENERATED ALWAYS as IDENTITY PRIMARY KEY,
    order_id      integer NOT NULL REFERENCES orders_oltp(order_id),
    product_id    integer NOT NULL REFERENCES products_oltp(product_id),
    quantity      integer NOT NULL CHECK (quantity > 0),
    unit_price    numeric(12,2) NOT NULL
);

TRUNCATE TABLE regions_oltp, customers_oltp, products_oltp, orders_oltp, order_items_oltp
RESTART IDENTITY;


select sum(quantity * unit_price) as revenue
from order_items_oltp;

-- Task 1

CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE NOT NULL,
    day_of_week INT NOT NULL,
    month INT NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    quarter INT NOT NULL,
    year INT NOT NULL
);

WITH bounds as (
    select MIN(order_ts)::date as min_d, MAX(order_ts)::date as max_d from orders_oltp
), series as (
    select g::date as d from bounds, generate_series(min_d, max_d, interval '1 day') g
)
INSERT INTO dim_date
select
    (EXTRACT(YEAR from d)::int*10000 + EXTRACT(MONTH from d)::int*100 + EXTRACT(DAY from d)::int),d,
    EXTRACT(ISODOW from d)::int,
    EXTRACT(MONTH from d)::int,
    TO_CHAR(d, 'Mon'),
    EXTRACT(QUARTER from d)::int,
    EXTRACT(YEAR from d)::int
from series;

select * from dim_date

-- Task 2

CREATE TABLE dw_lab.dim_product (
    product_sk serial PRIMARY KEY,       
    product_id integer NOT NULL,          
    product_name text NOT NULL,
    category text NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    created_at timestamp default CURRENT_TIMESTAMP,
    updated_at timestamp default CURRENT_TIMESTAMP
);

INSERT INTO dw_lab.dim_product (
    product_id,
    product_name,
    category,
    unit_price
)
select
    product_id,
    product_name,
    category,
    unit_price
from dw_lab.products_oltp;

select * from dw_lab.dim_product

-- Task 3

CREATE TABLE dw_lab.dim_customer (
    customer_sk serial PRIMARY KEY,      
    customer_id integer NOT NULL,         
    customer_name text NOT NULL,
    region_name text NOT NULL,
    signup_date DATE NOT NULL,
    created_at timestamp default CURRENT_TIMESTAMP,
    updated_at timestamp default CURRENT_TIMESTAMP
);

INSERT INTO dw_lab.dim_customer (
    customer_id,
    customer_name,
    region_name,
    signup_date
)
select
    c.customer_id,
    c.customer_name,
    r.region_name,
    c.signup_date
from dw_lab.customers_oltp c
join dw_lab.regions_oltp r on c.region_id = r.region_id;

select * from dw_lab.dim_customer

-- Task 4

CREATE TABLE fact_sales (
    fact_id serial PRIMARY KEY,
    date_key integer NOT NULL,
    product_key integer NOT NULL,
    customer_key integer NOT NULL,
    order_id_src integer NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    revenue numeric(18,2) GENERATED ALWAYS as (quantity * unit_price) STORED
);


INSERT INTO fact_sales(date_key, product_key, customer_key, order_id_src, quantity, unit_price)
select
    (EXTRACT(YEAR from o.order_ts)::int * 10000 + EXTRACT(MONTH from o.order_ts)::int * 100 + EXTRACT(DAY from o.order_ts)::int) as date_key,
    dp.product_sk as product_key,
    dc.customer_sk as customer_key,
    o.order_id as order_id_src,
    oi.quantity,
    oi.unit_price
from dw_lab.order_items_oltp as oi
join dw_lab.orders_oltp o on oi.order_id = o.order_id
join dw_lab.dim_product dp on dp.product_id = oi.product_id
join dw_lab.dim_customer dc on dc.customer_id = o.customer_id;

select * from fact_sales

-- Task 5

-- Comparing total sales revenue between the OLAP warehouse and the original OLTP source
-- This helps validate data consistency and correctness after the ETL pipeline execution.
-- Two CTEs defined for clarity:
-- 1. olap: Aggregates total revenue stored in the data warehouse's fact_sales table.
-- 2. oltp: Recomputes revenue directly from transactional data in order_items_oltp by multiplying quantity and unit price.
-- Final output presents both revenue figures side by side to easily verify if the warehouse matches the source.

WITH 
olap as (
    select sum(revenue)::numeric(18,2) as fact_rev
    from fact_sales
),

oltp as (
    select sum(quantity * unit_price)::numeric(18,2) as det_rev
    from order_items_oltp
)
select * from olap CROSS join oltp;

-- Task 1 (Part-c)

CREATE TABLE fact_sales_wide as
select 
    fs.sales_id,
    
    fs.product_key,
    p.product_name,
    p.category,
    p.unit_price,
    
    fs.customer_key,
    c.customer_name,
    c.region_name,
    
    fs.date_key,
    d.full_date,
    d.month,
    d.month_name,
    d.quarter,
    d.year,
    
    fs.quantity,
    fs.revenue

from fact_sales fs
left join dim_product  p on fs.product_key  = p.product_id      
left join dim_customer c on fs.customer_key = c.customer_id     
left join dim_date     d on fs.date_key     = d.full_date;      

select 
    fs.cnt as fact_sales_count,
    fsw.cnt as fact_sales_wide_count,
    fs.rev as fact_sales_revenue,
    fsw.rev as fact_sales_wide_revenue
from
    (select count(*) as cnt, sum(revenue) as rev from fact_sales) fs,
    (select count(*) as cnt, sum(revenue) as rev from fact_sales_wide) fsw;

-- Task 2

ALTER TABLE dim_product
ADD COLUMN default_region character varying(255);
update dim_product dp
SET default_region = subquery.region_name
from (
    select
        fs.product_key,
        dc.region_name,
        ROW_NUMBER() over (PARTITION BY fs.product_key order by fs.date_key) as rn
    from
        fact_sales fs
    join
        dim_customer dc on fs.customer_key = dc.customer_key
) as subquery
where dp.product_key = subquery.product_key
AND subquery.rn = 1;

select
    default_region,
    count(product_key) as number_of_products
from
    dim_product
group by
    default_region
order by
    number_of_products desc;

-- Task 3

DROP TABLE IF EXISTS agg_sales_m_cat_region;

CREATE TABLE agg_sales_m_cat_region as
select 
    make_date(d.year, d.month, 1) as month_start,
    p.category,
    c.region_name,
    sum(fs.revenue)::numeric(18,2) as revenue,
    sum(fs.quantity)::bigint as units,
    count(distinct fs.order_id_src)::bigint as orders

from fact_sales fs
join dim_product p   on fs.product_key  = p.product_id
join dim_customer c  on fs.customer_key = c.customer_id
join dim_date d      on fs.date_key     = d.full_date

group by 
    make_date(d.year, d.month, 1),
    p.category,
    c.region_name
order by 
    month_start, category, region_name;

	select 
    make_date(d.year, d.month, 1) as month_start,
    p.category,
    c.region_name,
    sum(fs.revenue)::numeric(18,2) as revenue,
    sum(fs.quantity)::bigint as units,
    count(distinct fs.order_id_src)::bigint as orders

from fact_sales fs
join dim_product p   on fs.product_key  = p.product_id
join dim_customer c  on fs.customer_key = c.customer_id
join dim_date d      on fs.date_key     = d.full_date
group by 
    make_date(d.year, d.month, 1),
    p.category,
    c.region_name
order by 
    month_start, category, region_name;