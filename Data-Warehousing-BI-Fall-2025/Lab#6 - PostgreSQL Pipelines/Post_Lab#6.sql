
CREATE TABLE users (
    user_id INT PRIMARY KEY,
    signup_date DATE NOT NULL,
    age_band VARCHAR(10), -- Stores the age range (e.g., '18-25')
    country VARCHAR(50) NOT NULL,
    region VARCHAR(50)
);
INSERT INTO users (user_id, signup_date, age_band, country, region) VALUES
(101, '2022-11-04', '18-25', 'Pakistan', 'South'),
(102, '2022-04-05', '36-45', 'USA', 'North'),
(103, '2022-10-14', '18-25', 'USA', 'North'),
(104, '2022-04-08', '36-45', 'Canada', 'North'),
(105, '2022-09-07', '36-45', 'Canada', 'West'),
(106, '2022-04-15', '36-45', 'Pakistan', 'North'),
(107, '2022-03-23', '26-35', 'Pakistan', 'East'),
(108, '2022-03-07', '26-35', 'USA', 'North'),
(109, '2022-07-04', '26-35', 'Pakistan', 'East'),
(110, '2022-01-24', '26-35', 'Canada', 'North'),
(111, '2022-07-03', '36-45', 'Pakistan', 'East'),
(112, '2022-10-07', '36-45', 'USA', 'North'),
(113, '2022-11-08', '26-35', 'USA', 'South'),
(114, '2022-02-13', '26-35', 'India', 'East'),
(115, '2022-03-12', '26-35', 'India', 'West');
select* from users

CREATE TABLE titles (
    title_id INT PRIMARY KEY,
    title_name VARCHAR(255) NOT NULL,
    author_or_director VARCHAR(255),
    medium VARCHAR(50) NOT NULL, -- E.g., BOOK, FILM, SERIES, etc.
    release_year INT
);

INSERT INTO titles (title_id, title_name, author_or_director, medium, release_year) VALUES
(1, 'All the Bright Places', 'Jennifer Niven', 'BOOK', 2015),
(2, 'All the Bright Places', 'Brett Haley', 'FILM', 2020),
(3, 'Theodore Finch Diaries', 'Jennifer Niven', 'BOOK', 2017);
select* from titles
CREATE TABLE events (
    event_id INT PRIMARY KEY,
    user_id INT NOT NULL,
    title_id INT NOT NULL,
    platform_id INT NOT NULL,
    event_type VARCHAR(50) NOT NULL, -- E.g., COMMENT, SCENE_VIEW, READ, SHARE, HIGHLIGHT
    event_ts timestamp NOT NULL, -- Timestamp of the event
    scene_id FLOAT, -- Represents a scene or chapter number (can be NULL)
    duration_seconds FLOAT, -- Duration of view/read (can be NULL)
    sentiment_score FLOAT 
);
INSERT INTO events (event_id, user_id, title_id, platform_id, event_type, event_ts, scene_id, duration_seconds, sentiment_score) VALUES
(1, 106, 2, 1, 'COMMENT', '2023-05-25 05:32:00', NULL, NULL, 0.83),
(2, 128, 3, 3, 'SCENE_VIEW', '2023-05-07 04:23:00', 25.0, NULL, NULL),
(3, 120, 2, 4, 'READ', '2023-01-12 09:15:00', NULL, NULL, NULL),
(4, 129, 3, 1, 'READ', '2023-06-16 02:48:00', NULL, NULL, NULL),
(5, 105, 3, 4, 'SCENE_VIEW', '2023-02-09 16:55:00', 20.0, NULL, NULL),
(6, 130, 3, 2, 'COMMENT', '2023-04-22 20:23:00', NULL, NULL, -0.12),
(7, 117, 2, 1, 'HIGHLIGHT', '2023-02-03 10:01:00', 19.0, NULL, NULL),
(8, 119, 1, 1, 'READ', '2023-06-21 01:14:00', NULL, NULL, NULL),
(9, 128, 2, 1, 'SCENE_VIEW', '2023-02-09 21:31:00', 7.0, NULL, NULL),
(10, 124, 3, 4, 'HIGHLIGHT', '2023-05-03 12:44:00', 22.0, 463.0, NULL);
select* from events
CREATE TABLE platforms (
    platform_id INT PRIMARY KEY,
    platform_name VARCHAR(50) NOT NULL -- E.g., Web, Android, iOS, SmartTV
);
INSERT INTO platforms (platform_id, platform_name) VALUES
(1, 'Web'),
(2, 'Android'),
(3, 'iOS'),
(4, 'SmartTV');
select*from platforms
-- 1. Create the table
CREATE TABLE event_types (
    event_type_id SERIAL PRIMARY KEY, -- Auto-incrementing ID handled by SERIAL
    event_type_name VARCHAR(50) NOT NULL UNIQUE -- The actual name of the event type
);
-- 2. Insert data into the table
INSERT INTO event_types (event_type_name) VALUES
('READ'),
('HIGHLIGHT'),
('COMMENT'),
('SHARE'),
('SCENE_VIEW');
select* from event_types
drop schema if exists staging cascade;
drop schema if exists dw cascade;
create schema staging;
create schema dw;
CREATE TABLE staging.stg_titles (
    title_id INT PRIMARY KEY,
    title_name TEXT,
    author_or_director TEXT,
    medium TEXT,
    release_year INT
);
CREATE TABLE staging.stg_platforms (
    platform_id INT PRIMARY KEY,
    platform_name TEXT
);
CREATE TABLE staging.stg_event_types (
  event_type TEXT
);
CREATE TABLE staging.stg_users (
    user_id INT PRIMARY KEY,
    signup_date DATE,
    age_band TEXT,
    country TEXT,
    region TEXT
);
CREATE TABLE staging.events (
    event_id SERIAL PRIMARY KEY,
    user_id INTEGER,
    title_id INTEGER,
    platform_id INTEGER,
    event_type VARCHAR(50),
    event_ts VARCHAR(50),  -- 👈 store timestamp as text
    scene_id INTEGER,
    duration_seconds INTEGER,
    sentiment_score DOUBLE PRECISION
);
--(----------------------Section B----------------------------)
CREATE TABLE dw.dim_title (
    title_key SERIAL PRIMARY KEY, -- Surrogate Key using SERIAL
    title_id INT NOT NULL UNIQUE, 
    title_name TEXT NOT NULL,
    author_or_director TEXT,
    medium TEXT,
    release_year INT
);
CREATE TABLE dw.dim_platform (
    platform_key SERIAL PRIMARY KEY, -- Surrogate Key using SERIAL
    platform_id INT NOT NULL UNIQUE, 
    platform_name TEXT NOT NULL
);
CREATE TABLE dw.dim_event_type (
    event_type_key SERIAL PRIMARY KEY, -- Surrogate Key using SERIAL
    event_type TEXT NOT NULL UNIQUE -- The event type name is the unique identifier
);
CREATE TABLE dw.dim_user (
    user_key SERIAL PRIMARY KEY, -- Surrogate Key using SERIAL
    user_id INT NOT NULL UNIQUE, 
    signup_date DATE,
    age_band TEXT,
    country TEXT,
    region TEXT
    );
CREATE TABLE dw.dim_datetime (
    date_key SERIAL PRIMARY KEY, -- Surrogate Key using SERIAL
    year INT,
	month INT,
	day INT,
	hour INT
    );
select * from dw.dim_datetime
-- Re-create the fact table with measures and a primary key
DROP TABLE IF EXISTS dw.fact_engagement CASCADE;
CREATE TABLE dw.fact_engagement (
    engagement_key BIGSERIAL PRIMARY KEY,  
    -- Foreign Keys
    title_key INT NOT NULL REFERENCES dw.dim_title(title_key),
    user_key INT NOT NULL REFERENCES dw.dim_user(user_key),
    platform_key INT NOT NULL REFERENCES dw.dim_platform(platform_key),
    event_type_key INT NOT NULL REFERENCES dw.dim_event_type(event_type_key),
    date_key INT NOT NULL REFERENCES dw.dim_datetime(date_key),   
    -- Measures from staging.stg_events
    duration_seconds INT,
    sentiment_score REAL,   
    -- Additional useful fields
    event_id INT NOT NULL UNIQUE, -- Store the natural key for audit/tracing
    event_timestamp_text TEXT -- Store the original timestamp string for tracing
);
--Question # 2
INSERT INTO dw.dim_datetime (year, month, day, hour)
SELECT DISTINCT
    EXTRACT(YEAR FROM event_ts::timestamp) AS year,
    EXTRACT(MONTH FROM event_ts::timestamp) AS month,
    EXTRACT(DAY FROM event_ts::timestamp) AS day,
    EXTRACT(HOUR FROM event_ts::timestamp) AS hour
FROM staging.events
WHERE event_ts IS NOT NULL;
	INSERT INTO dw.dim_platform (platform_id, platform_name)
SELECT DISTINCT platform_id, INITCAP(platform_name)
FROM staging.stg_platforms;
INSERT INTO dw.dim_title (
    title_id, 
    title_name, 
    author_or_director, 
    medium, 
    release_year 
)
SELECT DISTINCT 
    title_id, 
    title_name, 
    author_or_director, 
    medium, 
    release_year
FROM staging.stg_titles
INSERT INTO dw.dim_user (
    user_id, 
    signup_date, 
    age_band, 
    country, 
    region
)
SELECT DISTINCT 
    user_id, 
    signup_date, 
    age_band, 
    country, 
    region
FROM staging.stg_users
INSERT INTO dw.dim_event_type (
    event_type
)
SELECT DISTINCT 
    INITCAP(event_type) -- Ensures consistent capitalization, e.g., 'view' becomes 'View'
FROM staging.stg_event_types
INSERT INTO dw.fact_engagement (
    title_key, 
    user_key, 
    platform_key, 
    event_type_key, 
    date_key, 
    duration_seconds, 
    sentiment_score,
    event_id,
    event_timestamp_text
)
SELECT 
    -- Surrogate Key Lookups (SKL)
    DT.title_key,
    DU.user_key,
    DP.platform_key,
    DE.event_type_key,
    DD.date_key,
    -- Measures
    SE.duration_seconds,
    SE.sentiment_score,
    -- Audit/Tracing Keys
    SE.event_id,
    SE.event_ts
FROM 
    staging.events SE
INNER JOIN 
    dw.dim_title DT ON SE.title_id = DT.title_id
INNER JOIN 
    dw.dim_user DU ON SE.user_id = DU.user_id
INNER JOIN 
    dw.dim_platform DP ON SE.Platform_id = DP.platform_id
INNER JOIN 
    dw.dim_event_type DE ON INITCAP(SE.event_type) = DE.event_type
INNER JOIN 
    dw.dim_datetime DD ON 
        EXTRACT(YEAR FROM SE.event_ts::TIMESTAMP) = DD.year AND
        EXTRACT(MONTH FROM SE.event_ts::TIMESTAMP) = DD.month AND
        EXTRACT(DAY FROM SE.event_ts::TIMESTAMP) = DD.day AND
        EXTRACT(HOUR FROM SE.event_ts::TIMESTAMP) = DD.hour;
-----------------------------Question3--------------------------------
-- Check counts in both tables
SELECT 
    (SELECT COUNT(*) FROM staging.events) AS staging_event_count,
    (SELECT COUNT(*) FROM dw.fact_engagement) AS fact_event_count,
    (SELECT COUNT(*) FROM staging.events) - (SELECT COUNT(*) FROM dw.fact_engagement) AS difference;
SELECT 
    COUNT(*) AS null_key_count
FROM dw.fact_engagement
WHERE title_key IS NULL 
   OR user_key IS NULL 
   OR platform_key IS NULL 
   OR event_type_key IS NULL 
   OR date_key IS NULL;
SELECT 
    ROUND(AVG(CAST(duration_seconds AS numeric)), 2) AS avg_duration_seconds,
    ROUND(AVG(CAST(sentiment_score AS numeric)), 3) AS avg_sentiment_score,
    MIN(CAST(duration_seconds AS numeric)) AS min_duration,
    MAX(CAST(duration_seconds AS numeric)) AS max_duration,
    MIN(CAST(sentiment_score AS numeric)) AS min_sentiment,
    MAX(CAST(sentiment_score AS numeric)) AS max_sentiment
FROM dw.fact_engagement;
--Question 4--------------
-- Raw copy of titles
CREATE TABLE dw.raw_titles AS
SELECT * FROM staging.stg_titles;
--  Raw copy of platforms
CREATE TABLE dw.raw_platforms AS
SELECT * FROM staging.stg_platforms;
--  Raw copy of event types
CREATE TABLE dw.raw_event_types AS
SELECT * FROM staging.stg_event_types;
-- Raw copy of users
CREATE TABLE dw.raw_users AS
SELECT * FROM staging.stg_users;
-- Raw copy of events
CREATE TABLE dw.raw_events AS
SELECT * FROM staging.events;
--Question 5----------------
CREATE TABLE dw.fact_engagement_elt (
    event_id INT PRIMARY KEY,
    user_key INT,
    title_key INT,
    platform_key INT,
    event_type_key INT,
    date_key INT,
    scene_id INT,
    duration_seconds INT,
    sentiment_score DOUBLE PRECISION
);
INSERT INTO dw.fact_engagement_elt (
    event_id,
    user_key,
    title_key,
    platform_key,
    event_type_key,
    date_key,
    scene_id,
    duration_seconds,
    sentiment_score
)
SELECT
    re.event_id,
    du.user_key,
    dt.title_key,
    dp.platform_key,
    det.event_type_key,
    dd.date_key,
    re.scene_id,
    CASE 
        WHEN re.duration_seconds IS NULL OR re.duration_seconds < 0 THEN 0 
        ELSE re.duration_seconds 
    END AS duration_seconds,
    COALESCE(re.sentiment_score, 0) AS sentiment_score
FROM dw.raw_events re
LEFT JOIN dw.dim_user du
    ON re.user_id = du.user_id
LEFT JOIN dw.dim_title dt
    ON re.title_id = dt.title_id
LEFT JOIN dw.dim_platform dp
    ON re.platform_id = dp.platform_id
LEFT JOIN dw.dim_event_type det
    ON re.event_type = det.event_type
LEFT JOIN dw.dim_datetime dd
    ON dd.year = EXTRACT(YEAR FROM re.event_ts::timestamp)
   AND dd.month = EXTRACT(MONTH FROM re.event_ts::timestamp)
   AND dd.day = EXTRACT(DAY FROM re.event_ts::timestamp)
   AND dd.hour = EXTRACT(HOUR FROM re.event_ts::timestamp);
--Question 6--------------
SELECT
    (SELECT COUNT(*) FROM dw.fact_engagement) AS etl_rows,
    (SELECT COUNT(*) FROM dw.fact_engagement_elt) AS elt_rows,
    (SELECT SUM(duration_seconds) FROM dw.fact_engagement) AS etl_sum,
    (SELECT SUM(duration_seconds) FROM dw.fact_engagement_elt) AS elt_sum;

----Question 7--------------------
SELECT 
    dd.year,
    dd.month,
    dt.medium,
    ROUND(SUM(fe.duration_seconds) / 60.0, 2) AS total_engagement_minutes
FROM 
    dw.fact_engagement fe
JOIN 
    dw.dim_title dt ON fe.title_key = dt.title_key
JOIN 
    dw.dim_datetime dd ON fe.date_key = dd.date_key
GROUP BY 
    dd.year, dd.month, dt.medium
ORDER BY 
    dd.year, dd.month, dt.medium;
--Question 8---------
SELECT 
    dp.platform_name,
    det.event_type,
    COUNT(*) AS event_count
FROM 
    dw.fact_engagement fe
JOIN 
    dw.dim_platform dp ON fe.platform_key = dp.platform_key
JOIN 
    dw.dim_event_type det ON fe.event_type_key = det.event_type_key
GROUP BY 
    dp.platform_name, det.event_type
ORDER BY 
    dp.platform_name, det.event_type;
--Question 9-----	
SELECT 
    dt.medium,
    det.event_type,
    SUM(fe.duration_seconds) AS total_duration_seconds,
    COUNT(*) AS event_count
FROM 
    dw.fact_engagement fe
JOIN 
    dw.dim_title dt ON fe.title_key = dt.title_key
JOIN 
    dw.dim_event_type det ON fe.event_type_key = det.event_type_key
GROUP BY 
    CUBE(dt.medium, det.event_type)
ORDER BY 
    dt.medium, det.event_type;
--Question 10-------

CREATE TABLE dw.agg_month_medium AS
SELECT
    dd.year::int AS year,
    dd.month::int AS month,
    dt.medium,
    SUM(fe.duration_seconds) AS total_seconds,
    COUNT(*) AS event_count
FROM 
    dw.fact_engagement fe
JOIN 
    dw.dim_datetime dd ON fe.date_key = dd.date_key
JOIN 
    dw.dim_title dt ON fe.title_key = dt.title_key
GROUP BY 
    dd.year, dd.month, dt.medium
ORDER BY 
    dd.year, dd.month, dt.medium;

--Question 11
DROP TABLE IF EXISTS dw.scene_views CASCADE;
DROP TABLE IF EXISTS dw.highlights CASCADE;

CREATE TABLE dw.scene_views AS
SELECT 
    fe.engagement_key,
    du.user_id,
    du.country,
    du.region,
    dt.title_name,
    dt.medium,
    dp.platform_name,
    dd.year,
    dd.month,
    dd.day,
    fe.duration_seconds,
    fe.sentiment_score
FROM 
    dw.fact_engagement fe
JOIN dw.dim_user du ON fe.user_key = du.user_key
JOIN dw.dim_title dt ON fe.title_key = dt.title_key
JOIN dw.dim_platform dp ON fe.platform_key = dp.platform_key
JOIN dw.dim_datetime dd ON fe.date_key = dd.date_key
JOIN dw.dim_event_type det ON fe.event_type_key = det.event_type_key
WHERE 
    det.event_type = 'Scene_View';  -- match capitalization with dim_event_type

--  Create dw.highlights
CREATE TABLE dw.highlights AS
SELECT 
    fe.engagement_key,
    du.user_id,
    du.country,
    du.region,
    dt.title_name,
    dt.medium,
    dp.platform_name,
    dd.year,
    dd.month,
    dd.day,
    fe.duration_seconds,
    fe.sentiment_score
FROM 
    dw.fact_engagement fe
JOIN dw.dim_user du ON fe.user_key = du.user_key
JOIN dw.dim_title dt ON fe.title_key = dt.title_key
JOIN dw.dim_platform dp ON fe.platform_key = dp.platform_key
JOIN dw.dim_datetime dd ON fe.date_key = dd.date_key
JOIN dw.dim_event_type det ON fe.event_type_key = det.event_type_key
WHERE 
    det.event_type = 'Highlight';  -- match capitalization with dim_event_type
--Checks 
SELECT 
    (SELECT COUNT(*) FROM dw.scene_views) AS scene_view_count,
    (SELECT COUNT(*) FROM dw.highlights) AS highlight_count;

-- Preview data
SELECT * FROM dw.scene_views LIMIT 5;
SELECT * FROM dw.highlights LIMIT 5;

--Question 12
--  Disable Hash and Merge Joins, enable Nested Loop
SET enable_hashjoin = off;
SET enable_mergejoin = off;
SET enable_nestloop = on;

--  Run EXPLAIN ANALYZE to observe actual join behavior
EXPLAIN ANALYZE
SELECT 
    sv.user_id,
    sv.title_name AS scene_title,
    hl.title_name AS highlight_title,
    sv.medium,
    sv.platform_name,
    sv.duration_seconds AS scene_duration,
    hl.duration_seconds AS highlight_duration,
    sv.sentiment_score AS scene_sentiment,
    hl.sentiment_score AS highlight_sentiment,
    sv.year,
    sv.month
FROM 
    dw.scene_views sv
JOIN 
    dw.highlights hl
    ON sv.user_id = hl.user_id
    AND sv.title_name = hl.title_name
    AND sv.year = hl.year
    AND sv.month = hl.month;

-- Reset planner settings to default
RESET enable_hashjoin;
RESET enable_mergejoin;
RESET enable_nestloop;

--Question 13
-- Configure PostgreSQL to use only Merge Join
SET enable_hashjoin = off;
SET enable_mergejoin = on;
SET enable_nestloop = off;

--  Run EXPLAIN ANALYZE to see Sort-Merge join plan
EXPLAIN ANALYZE
SELECT 
    sv.user_id,
    sv.title_name AS scene_title,
    hl.title_name AS highlight_title,
    sv.medium,
    sv.platform_name,
    sv.duration_seconds AS scene_duration,
    hl.duration_seconds AS highlight_duration,
    sv.sentiment_score AS scene_sentiment,
    hl.sentiment_score AS highlight_sentiment,
    sv.year,
    sv.month
FROM 
    dw.scene_views sv
JOIN 
    dw.highlights hl
    ON sv.user_id = hl.user_id
    AND sv.title_name = hl.title_name
    AND sv.year = hl.year
    AND sv.month = hl.month;

-- Reset planner settings back to default
RESET enable_hashjoin;
RESET enable_mergejoin;
RESET enable_nestloop;

--Question 14
-- Configure PostgreSQL to use only Hash Join
SET enable_hashjoin = on;
SET enable_mergejoin = off;
SET enable_nestloop = off;

-- Run EXPLAIN ANALYZE to observe Hash Join execution
EXPLAIN ANALYZE
SELECT 
    sv.user_id,
    sv.title_name AS scene_title,
    hl.title_name AS highlight_title,
    sv.medium,
    sv.platform_name,
    sv.duration_seconds AS scene_duration,
    hl.duration_seconds AS highlight_duration,
    sv.sentiment_score AS scene_sentiment,
    hl.sentiment_score AS highlight_sentiment,
    sv.year,
    sv.month
FROM 
    dw.scene_views sv
JOIN 
    dw.highlights hl
    ON sv.user_id = hl.user_id
    AND sv.title_name = hl.title_name
    AND sv.year = hl.year
    AND sv.month = hl.month;

-- Reset planner settings to default
RESET enable_hashjoin;
RESET enable_mergejoin;
RESET enable_nestloop;
