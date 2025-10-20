-- SCHEMA: Lab7_DW

-- DROP SCHEMA IF EXISTS Lab7_DW ;

CREATE SCHEMA IF NOT EXISTS Lab7_DW
    AUTHORIZATION postgres;

CREATE TABLE Lab7_DW.dim_title (
title_key serial primary key,  -- surrogate key
title_id int,
title_name text,
author_or_director text,
medium text,
release_year int
);

CREATE TABLE Lab7_DW.dim_event_type (
event_type_key serial primary key,
event_type text
);

CREATE TABLE Lab7_DW.dim_datetime (
datetime_key serial primary key,
full_ts timestamp,
year int,
month int,
day int,
hour int
);

CREATE TABLE Lab7_DW.dim_platform (
    platform_key serial primary key,
    platform_id int,
    platform_name text
);

CREATE TABLE Lab7_DW.dim_user (
    user_key serial primary key,
    user_id int,
    signup_date date,
    age_band text,
    country text,
    region text
);

CREATE TABLE Lab7_DW.fact_engagement (
    fact_id serial primary key,
    user_key int references Lab7_DW.dim_user(user_key),
    title_key int references Lab7_DW.dim_title(title_key),
    platform_key int references Lab7_DW.dim_platform(platform_key),
    event_type_key int references Lab7_DW.dim_event_type(event_type_key),
    datetime_key int references Lab7_DW.dim_datetime(datetime_key),
    duration_seconds int,
    sentiment_score NUMERIC(5,2)
);


-- inserting into dimension tables

insert into Lab7_DW.dim_platform (platform_id, platform_name)
select distinct 
    platform_id::int,
    lower(trim(platform_name))
from staging.stg_platforms;

insert into Lab7_DW.dim_event_type (event_type)
select distinct 
    lower(trim(event_type))
from staging.stg_event_types;

insert into Lab7_DW.dim_title (title_id, title_name, author_or_director, medium, release_year)
select distinct
    title_id::int,
    lower(trim(title_name)),
    lower(trim(author_or_director)),
    lower(trim(medium)),
    release_year::int
from staging.stg_titles;

insert into Lab7_DW.dim_user (user_id, signup_date, age_band, country, region)
select distinct
    user_id::int,
    signup_date::date,
    lower(trim(age_band)),
    lower(trim(country)),
    lower(trim(region))
from staging.stg_users;

insert into Lab7_DW.dim_datetime (full_ts, year, month, day, hour)
select distinct
    event_ts::timestamp as full_ts,
    extract(year from event_ts::timestamp)::int as year,
    extract(month from event_ts::timestamp)::int as month,
    extract(day from event_ts::timestamp)::int as day,
    extract(hour from event_ts::timestamp)::int as hour
from staging.stg_events
where event_ts is not null;


insert into Lab7_DW.fact_engagement
(user_key, title_key, platform_key, event_type_key, datetime_key, duration_seconds, sentiment_score)
select
    du.user_key,
    dt.title_key,
    dp.platform_key,
    det.event_type_key,
    dd.datetime_key,
    case 
        when se.duration_seconds ~ '^[0-9]+$' then se.duration_seconds::int
        else null
    end as duration_seconds,
    nullif(se.sentiment_score, '')::numeric(5,2)
from staging.stg_events se
left join Lab7_DW.dim_user du on du.user_id = se.user_id::int
left join Lab7_DW.dim_title dt on dt.title_id = se.title_id::int
left join Lab7_DW.dim_platform dp on dp.platform_id = se.platform_id::int
left join Lab7_DW.dim_event_type det on det.event_type = lower(trim(se.event_type))
left join Lab7_DW.dim_datetime dd on dd.full_ts = se.event_ts::timestamp;


-- validation queries
select 
    (select count(*) from staging.stg_events) as staging_rows,
    (select count(*) from Lab7_DW.fact_engagement) as fact_rows;

select
    count(*) as null_key_rows
from Lab7_DW.fact_engagement
where user_key is null 
   or title_key is null
   or platform_key is null
   or event_type_key is null
   or datetime_key is null;

update Lab7_DW.fact_engagement
set duration_seconds = 0
where duration_seconds is null;

select
    avg(duration_seconds) as avg_duration,
    avg(sentiment_score) as avg_sentiment
from Lab7_DW.fact_engagement;


-- SECTION C: ELT WORKFLOW
-- q4
create table Lab7_DW.raw_events as
select * from staging.stg_events;

-- q5
create table Lab7_DW.fact_elt (
    fact_id serial primary key,
    user_key int references Lab7_DW.dim_user(user_key),
    title_key int references Lab7_DW.dim_title(title_key),
    platform_key int references Lab7_DW.dim_platform(platform_key),
    event_type_key int references Lab7_DW.dim_event_type(event_type_key),
    datetime_key int references Lab7_DW.dim_datetime(datetime_key),
    duration_seconds int,
    sentiment_score numeric(5,2)
);

insert into Lab7_DW.fact_elt
(user_key, title_key, platform_key, event_type_key, datetime_key, duration_seconds, sentiment_score)
select
    du.user_key,
    dt.title_key,
    dp.platform_key,
    det.event_type_key,
    dd.datetime_key,
    case 
        when re.duration_seconds = '' or re.duration_seconds is null then 0
        when re.duration_seconds::float < 0 then 0
        else re.duration_seconds::float::int
    end as duration_seconds,
    coalesce(nullif(re.sentiment_score, '')::numeric(5,2), 0) as sentiment_score
from Lab7_DW.raw_events re
left join Lab7_DW.dim_user du on du.user_id = re.user_id::int
left join Lab7_DW.dim_title dt on dt.title_id = re.title_id::int
left join Lab7_DW.dim_platform dp on dp.platform_id = re.platform_id::int
left join Lab7_DW.dim_event_type det on det.event_type = lower(trim(re.event_type))
left join Lab7_DW.dim_datetime dd on dd.full_ts = re.event_ts::timestamp
where re.event_ts is not null;

-- q6
select 	
    (select count(*) from Lab7_DW.fact_engagement)  as etl_rows,
    (select count(*) from Lab7_DW.fact_elt) as elt_rows,
    (select sum(duration_seconds) from Lab7_DW.fact_engagement) as etl_sum_duration,
    (select sum(duration_seconds) from Lab7_DW.fact_elt) as elt_sum_duration,
    (select sum(sentiment_score) from Lab7_DW.fact_engagement) as etl_sum_sentiment,
    (select sum(sentiment_score) from Lab7_DW.fact_elt) as elt_sum_sentiment;


-- SECTION D: OLAP FRAMEWORK
-- q7
select
    extract(year from d.full_ts)::int  as year,
    extract(month from d.full_ts)::int as month,
    t.medium,
    sum(f.duration_seconds) / 60.0 as total_min
from Lab7_DW.fact_engagement f
join Lab7_DW.dim_datetime d on f.datetime_key = d.datetime_key
join Lab7_DW.dim_title t     on f.title_key    = t.title_key
group by 1, 2, 3
order by 1, 2, 3;

-- q8
select
    p.platform_name,
    e.event_type,
    count(*) as event_count
from Lab7_DW.fact_engagement f
join Lab7_DW.dim_platform p   on f.platform_key    = p.platform_key
join Lab7_DW.dim_event_type e on f.event_type_key  = e.event_type_key
group by 1, 2
order by 1, 2;

-- q9
select
    t.medium,
    e.event_type,
    count(*) as total_events,
    sum(f.duration_seconds) as total_duration
from Lab7_DW.fact_engagement f
join Lab7_DW.dim_title t      on f.title_key      = t.title_key
join Lab7_DW.dim_event_type e on f.event_type_key = e.event_type_key
group by cube(t.medium, e.event_type)
order by t.medium, e.event_type;

-- q10
create table Lab7_DW.agg_month_medium as
select
    extract(year from d.full_ts)::int  as year,
    extract(month from d.full_ts)::int as month,
    t.medium,
    sum(f.duration_seconds) as total_seconds,
    count(*) as event_count
from Lab7_DW.fact_engagement f
join Lab7_DW.dim_datetime d on f.datetime_key = d.datetime_key
join Lab7_DW.dim_title    t on f.title_key    = t.title_key
group by 1, 2, 3
order by 1, 2, 3;
