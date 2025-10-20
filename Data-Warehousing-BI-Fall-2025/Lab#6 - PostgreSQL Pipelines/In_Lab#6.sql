-- Create schemas if not exists
create schema if not exists staging;
create schema if not exists dw;

-- 1. staging.stg_users
drop table if exists staging.stg_users;
create table staging.stg_users (
    user_id int primary key,
    signup_date DATE,
    age_band text,
    country text,
    region text
);

-- 2. staging.stg_titles
drop table if exists staging.stg_titles;
create table staging.stg_titles (
    title_id int primary key,
    title_name text,
    author_or_director text,
    medium text,             -- e.g. Film, Book
    release_year int
);

-- 3. staging.stg_platforms
drop table if exists staging.stg_platforms;
create table staging.stg_platforms (
    platform_id int primary key,
    platform_name text
);

-- 4. staging.stg_event_types
drop table if exists staging.stg_event_types;
create table staging.stg_event_types (
    event_type text primary key
);

-- 5. staging.stg_events
drop table if exists staging.stg_events;
create table staging.stg_events (
    event_id int primary key,
    user_id int,
    title_id int,
    platform_id int,
    event_type text,
    event_ts TIMESTAMP,
    scene_id int,
    duration_seconds int,
    sentiment_score NUMERIC(5,2)
	)

--Section B — Star Schema Design (ETL Path)
--Create DW Dimension & Fact Tables

create schema if not exists dw;

-- 1. Dimension: dim_user
drop table if exists dw.dim_user;
create table dw.dim_user (
    user_sk SERIAL primary key,
    user_id int,
    signup_date DATE,
    age_band text,
    country text,
    region text
);

-- 2. Dimension: dim_title
drop table if exists dw.dim_title;
create table dw.dim_title (
    title_sk SERIAL primary key,
    title_id int,
    title_name text,
    author_or_director text,
    medium text,
    release_year int
);

-- 3. Dimension: dim_platform
drop table if exists dw.dim_platform;
create table dw.dim_platform (
    platform_sk SERIAL primary key,
    platform_id int,
    platform_name text
);

-- 4. Dimension: dim_event_type
drop table if exists dw.dim_event_type;
create table dw.dim_event_type (
    event_type_sk SERIAL primary key,
    event_type text
);

-- 5. Dimension: dim_datetime
drop table if exists dw.dim_datetime;
create table dw.dim_datetime (
    datetime_sk SERIAL primary key,
    full_ts TIMESTAMP,
    year int,
    month int,
    day int,
    hour int
);

-- 6. Fact Table: fact_engagement
drop table if exists dw.fact_engagement;
create table dw.fact_engagement (
    fact_id SERIAL primary key,
    user_sk int,
    title_sk int,
    platform_sk int,
    event_type_sk int,
    datetime_sk int,
    duration_seconds int,
    sentiment_score NUMERIC(5,2),

    foreign key (user_sk) references dw.dim_user(user_sk),
    foreign key (title_sk) references dw.dim_title(title_sk),
    foreign key (platform_sk) references dw.dim_platform(platform_sk),
    foreign key (event_type_sk) references dw.dim_event_type(event_type_sk),
    foreign key (datetime_sk) references dw.dim_datetime(datetime_sk)
);

-- Q2 ETL – Transform and Load
-- dim_title
insert into dw.dim_title (title_id, title_name, author_or_director, medium)
select distinct 
       title_id, 
       INITCAP(title_name), 
       INITCAP(author_or_director), 
       UPPER(medium)
from staging.stg_titles;


-- dim_user
insert into dw.dim_user (user_id, signup_date, age_band, country, region)
select distinct
    s.user_id,
    s.signup_date,
    INITCAP(s.age_band),
    INITCAP(s.country),
    INITCAP(s.region)
from staging.stg_users as s
where s.user_id is not null;

-- dim_platform
insert into dw.dim_platform (platform_id, platform_name)
select distinct platform_id, INITCAP(platform_name)
from staging.stg_platforms;

-- dim_event_type
insert into dw.dim_event_type (event_type)
select distinct
    UPPER(event_type)
from staging.stg_event_types;


-- dim_datetime
insert into dw.dim_datetime (full_ts, year, month, day, hour)
select distinct event_ts,
       EXTRACT(YEAR  from event_ts)::int,
       EXTRACT(MONTH from event_ts)::int,
       EXTRACT(DAY   from event_ts)::int,
       EXTRACT(HOUR  from event_ts)::int
from staging.stg_events
where event_ts is not null;

-- Step 2. Load Fact Table (join + Map Surrogates)
insert into dw.fact_engagement (
    user_sk, title_sk, platform_sk, event_type_sk, datetime_sk,
    duration_seconds, sentiment_score
)
select
    du.user_sk,
    dt.title_sk,
    dp.platform_sk,
    det.event_type_sk,
    dd.datetime_sk,
    e.duration_seconds,
    e.sentiment_score
from staging.stg_events e
join dw.dim_user du on du.user_id = e.user_id
join dw.dim_title dt on dt.title_id = e.title_id
join dw.dim_platform dp on dp.platform_id = e.platform_id
join dw.dim_event_type det on det.event_type = UPPER(e.event_type)
join dw.dim_datetime dd on dd.full_ts = e.event_ts;

-- Q3. Validation Queries
-- Compare staging vs fact row count
select
    (select COUNT(*) from staging.stg_events) as staging_count,
    (select COUNT(*) from dw.fact_engagement) as fact_count;
-- Check for null keys
select COUNT(*) as null_keys
from dw.fact_engagement
where user_sk is null
   or title_sk is null
   or platform_sk is null
   or event_type_sk is null
   or datetime_sk is null;
-- Validate averages (duration, sentiment)
select
    AVG(duration_seconds)::NUMERIC(10,2) as avg_duration,
    AVG(sentiment_score)::NUMERIC(10,2) as avg_sentiment
from dw.fact_engagement;

-- Section C – ELT Workflow
-- Q4. Create a Raw Landing Table
-- This table copies everything as-is from staging (no transformations).
-- Drop if already exists
drop table if exists dw.raw_events;

-- Create raw landing table directly from staging
create table dw.raw_events as
select * from staging.stg_events;

-- Q5. Transform Inside the DW
-- Create fact_engagement_elt
drop table if exists dw.fact_engagement_elt;
create table dw.fact_engagement_elt (
    fact_id SERIAL primary key,
    user_sk int,
    title_sk int,
    platform_sk int,
    event_type_sk int,
    datetime_sk int,
    duration_seconds int,
    sentiment_score NUMERIC(5,2),
    foreign key (user_sk) references dw.dim_user(user_sk),
    foreign key (title_sk) references dw.dim_title(title_sk),
    foreign key (platform_sk) references dw.dim_platform(platform_sk),
    foreign key (event_type_sk) references dw.dim_event_type(event_type_sk),
    foreign key (datetime_sk) references dw.dim_datetime(datetime_sk)
);

-- Q2️. Transform + Load
insert into dw.fact_engagement_elt (
    user_sk, title_sk, platform_sk, event_type_sk, datetime_sk,
    duration_seconds, sentiment_score
)
select
    du.user_sk,
    dt.title_sk,
    dp.platform_sk,
    det.event_type_sk,
    dd.datetime_sk,

    -- Clean duration: replace negatives or nulls with 0
    CASE 
        WHEN r.duration_seconds is null THEN 0
        WHEN r.duration_seconds < 0 THEN 0
        ELSE r.duration_seconds
    END as duration_seconds,

    -- Clean sentiment: default to 0 if NULL
    COALESCE(r.sentiment_score, 0) as sentiment_score

from dw.raw_events r
join dw.dim_user du on du.user_id = r.user_id
join dw.dim_title dt on dt.title_id = r.title_id
join dw.dim_platform dp on dp.platform_id = r.platform_id
join dw.dim_event_type det on det.event_type = UPPER(r.event_type)
join dw.dim_datetime dd on dd.full_ts = r.event_ts;


-- Q6. Compare ETL vs ELT Results
select
    (select COUNT(*) from dw.fact_engagement)      as etl_rows,
    (select COUNT(*) from dw.fact_engagement_elt)  as elt_rows,
    (select SUM(duration_seconds) from dw.fact_engagement)      as etl_sum,
    (select SUM(duration_seconds) from dw.fact_engagement_elt)  as elt_sum;


-- Q7. Monthly Engagement by Medium
-- Show total engagement minutes per month per medium (BOOK, FILM).
drop table if exists dw.agg_month_medium;

create table dw.agg_month_medium as
select
    EXTRACT(YEAR from d.full_ts)::int   as year,
    EXTRACT(MONTH from d.full_ts)::int  as month,
    t.medium,
    SUM(f.duration_seconds) as total_seconds,
    COUNT(*) as event_count
from dw.fact_engagement f
join dw.dim_datetime d on f.datetime_sk = d.datetime_sk
join dw.dim_title t on f.title_sk = t.title_sk
group by 
    EXTRACT(YEAR from d.full_ts),
    EXTRACT(MONTH from d.full_ts),
    t.medium;

-- 8. Event Type Distribution by Platform
-- Count how many events of each type occur on each platform.
select
    p.platform_name,
    et.event_type,
    COUNT(*) as event_count
from dw.fact_engagement f
join dw.dim_platform   p  on f.platform_sk   = p.platform_sk
join dw.dim_event_type et on f.event_type_sk = et.event_type_sk
group by p.platform_name, et.event_type
order by p.platform_name, et.event_type;

-- Q9. CUBE Query (Medium × Event Type)
-- Aggregate totals at all roll-up levels using the SQL CUBE operator.
select
    t.medium,
    et.event_type,
    SUM(f.duration_seconds) as total_duration,
    COUNT(*) as event_count
from dw.fact_engagement f
join dw.dim_title      t  on f.title_sk      = t.title_sk
join dw.dim_event_type et on f.event_type_sk = et.event_type_sk
group by CUBE(t.medium, et.event_type)
order by t.medium, et.event_type;

-- Q10. Pre-Aggregated MOLAP Table
--Create a summary table dw.agg_month_medium storing monthly, medium-level aggregates.
drop table if exists dw.agg_month_medium;

create table dw.agg_month_medium as
select
    EXTRACT(YEAR  from d.full_ts)::int as year,
    EXTRACT(MONTH from d.full_ts)::int as month,
    t.medium,
    SUM(f.duration_seconds) as total_seconds,
    COUNT(*)                as event_count
from dw.fact_engagement f
join dw.dim_datetime d on f.datetime_sk = d.datetime_sk
join dw.dim_title    t on f.title_sk    = t.title_sk
group by 1, 2, 3
order by year, month, t.medium;


select * from dw.agg_month_medium order by year, month, medium;
