CREATE DATABASE dw_project;

-- 0. Create schemas if not exists
DROP SCHEMA IF EXISTS staging CASCADE;
DROP SCHEMA IF EXISTS dw CASCADE;
CREATE SCHEMA staging;
CREATE SCHEMA dw;

-- ========================
-- 1. staging.stg_users
-- ========================
CREATE TABLE staging.stg_user (
    customer_name    TEXT,
    customer_email   TEXT,
    merchant_name    TEXT,
    merchant_email   TEXT,
    card_number      VARCHAR(20),
    card_expiry      VARCHAR(10),   -- e.g., "Jun-30"
    device_type      TEXT
);

-- ========================
-- 2. staging.stg_accounts
-- ========================
CREATE TABLE staging.stg_accounts (
    sender_account    VARCHAR(20),
    receiver_account  VARCHAR(20),
    amount            NUMERIC(10,2),
    is_fraud          BOOLEAN
);

-- ========================
-- 3. staging.stg_transaction_type
-- ========================
CREATE TABLE staging.stg_transaction_type (
    transaction_id     INT,
    transaction_type   TEXT,
    location_region    TEXT,
    ip_prefix          VARCHAR(20),
    timestamp          TIMESTAMP
);

-- ========================
-- 4. staging.stg_behavior_risk
-- ========================
CREATE TABLE staging.stg_behavior_risk (
    login_frequency    INT,
    session_duration   NUMERIC(10,2),
    purchase_pattern   TEXT,
    risk_score         NUMERIC(5,2),
    anomaly            TEXT    -- e.g., 'low_risk', 'high_risk'
);

-- Verification queries
SELECT COUNT(*) FROM staging.stg_user;
SELECT COUNT(*) FROM staging.stg_accounts;
SELECT COUNT(*) FROM staging.stg_transaction_type;
SELECT COUNT(*) FROM staging.stg_behavior_risk;

-- ==========================================================
-- 2️⃣ Dimension Tables
-- ==========================================================

DROP TABLE dw.dim_customer CASCADE;

-- dim_customer: stores unique customers
CREATE TABLE dw.dim_customer (
    customer_sk        SERIAL PRIMARY KEY,
    customer_name      TEXT NOT NULL,
    customer_email     TEXT UNIQUE,
    card_number        VARCHAR(20),
    card_expiry        VARCHAR(10),
    device_type        TEXT
);

-- dim_merchant: stores unique merchants
CREATE TABLE dw.dim_merchant (
    merchant_sk        SERIAL PRIMARY KEY,
    merchant_name      TEXT NOT NULL,
    merchant_email     TEXT UNIQUE
);

-- dim_transaction_type: stores different transaction categories
CREATE TABLE dw.dim_transaction_type (
    transaction_type_sk  SERIAL PRIMARY KEY,
    transaction_type     TEXT NOT NULL,
    location_region      TEXT,
    ip_prefix            VARCHAR(20)
);

-- dim_behavior_risk: stores behavioral and risk features
CREATE TABLE dw.dim_behavior_risk (
    behavior_risk_sk   SERIAL PRIMARY KEY,
    login_frequency    INT,
    session_duration   NUMERIC(10,2),
    purchase_pattern   TEXT,
    risk_score         NUMERIC(5,2),
    anomaly            TEXT
);

-- dim_date: generic date dimension for analysis
CREATE TABLE dw.dim_date (
    date_sk            SERIAL PRIMARY KEY,
    full_ts            TIMESTAMP,
    date_value         DATE,
    day                INT,
    month              INT,
    year               INT
);

-- ==========================================================
-- 3️⃣ Fact Table
-- ==========================================================

-- fact_transactions: central table containing measurable data (amount, fraud)
CREATE TABLE dw.fact_transactions (
    fact_transaction_sk SERIAL PRIMARY KEY,
    customer_sk         INT REFERENCES dw.dim_customer(customer_sk),
    merchant_sk         INT REFERENCES dw.dim_merchant(merchant_sk),
    transaction_type_sk INT REFERENCES dw.dim_transaction_type(transaction_type_sk),
    behavior_risk_sk    INT REFERENCES dw.dim_behavior_risk(behavior_risk_sk),
    date_sk             INT REFERENCES dw.dim_date(date_sk),

    sender_account      VARCHAR(20),
    receiver_account    VARCHAR(20),
    amount              NUMERIC(12,2),
    is_fraud            BOOLEAN,

    load_timestamp      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_fact_transactions_customer ON dw.fact_transactions(customer_sk);
CREATE INDEX idx_fact_transactions_date ON dw.fact_transactions(date_sk);
CREATE INDEX idx_fact_transactions_fraud ON dw.fact_transactions(is_fraud);

-- ==============================================================
-- 2. ETL Workflow (Extract Transform Load) 
-- Fraud Detection Data Warehouse
-- ==============================================================

-- ==============================================================
-- 1. CLEANING & TRANSFORMATION EXAMPLES
-- ==============================================================

-- Example 1: Normalize device type names (uppercasing + trimming)
UPDATE staging.stg_user
SET device_type = INITCAP(TRIM(device_type));
select * from staging.stg_user;

-- Example 2: Fix date format and cast to DATE in transaction_type
-- Convert 'timestamp' column from text (e.g., 11/04/2022 12:47) → DATE format
ALTER TABLE staging.stg_transaction_type
ALTER COLUMN "timestamp" TYPE TIMESTAMP
USING TO_TIMESTAMP("timestamp", 'DD/MM/YYYY HH24:MI');
select * from staging.stg_transaction_type;

-- Example 3: Remove rows with NULL critical fields
DELETE FROM staging.stg_accounts
WHERE sender_account IS NULL OR receiver_account IS NULL OR amount IS NULL;
SELECT COUNT(*) FROM staging.stg_accounts;

-- Example 4: Remove duplicates from staging tables (optional but good practice)
DELETE FROM staging.stg_user a
USING staging.stg_user b
WHERE a.ctid < b.ctid
  AND a.customer_email = b.customer_email;

-- Exampke 5: Scientific Notation Card Number Transformation
-- Step 1
UPDATE staging.stg_user
SET card_number = TRIM(TO_CHAR(card_number::numeric, 'FM99999999999999999999'));
-- Step 2
UPDATE staging.stg_user
SET card_number = LPAD(card_number, 16, '0')
WHERE LENGTH(card_number) < 16;

select * from staging.stg_user;
select * from staging.stg_accounts;
select * from staging.stg_behavior_risk;
SELECT * FROM staging.stg_accounts;


-- ==============================================================
-- 2. LOAD DIMENSIONS
-- ==============================================================

-- ==========================================================
-- ETL: Load Data into dw.dim_customer
-- Source: staging.stg_user
-- ==========================================================
INSERT INTO dw.dim_customer (
    customer_name,
    customer_email,
    card_number,
    card_expiry,
    device_type
)
SELECT
    -- Clean and format customer name (first letter uppercase)
    INITCAP(TRIM(customer_name)) AS customer_name,

    -- Lowercase and trim email
    LOWER(TRIM(customer_email)) AS customer_email,

    -- 🧠 Transformation: Fix scientific notation (e.g., 5.02096E+11 → 502096000000)
    CASE
        WHEN card_number ~ 'E' THEN 
            TRIM(TO_CHAR(CAST(card_number AS NUMERIC), 'FM9999999999999999999'))
        ELSE TRIM(card_number)
    END AS card_number,

    -- Keep expiry format as text, handle missing values
    COALESCE(TRIM(card_expiry), 'Unknown') AS card_expiry,

    -- Normalize device type
    INITCAP(COALESCE(TRIM(device_type), 'Unknown')) AS device_type

FROM staging.stg_user
WHERE customer_name IS NOT NULL;
select * from dw.dim_customer;

INSERT INTO dw.dim_merchant (merchant_name, merchant_email)
SELECT DISTINCT
    INITCAP(TRIM(merchant_name)),
    LOWER(TRIM(merchant_email))
FROM staging.stg_user s
WHERE merchant_email IS NOT NULL
ON CONFLICT (merchant_email) DO NOTHING;
select * from dw.dim_merchant;


INSERT INTO dw.dim_transaction_type (transaction_type, location_region, ip_prefix)
SELECT
    INITCAP(TRIM(transaction_type)) AS transaction_type,
    INITCAP(TRIM(location_region)) AS location_region,
    ip_prefix
FROM staging.stg_transaction_type
WHERE transaction_type IS NOT NULL;
select * from dw.dim_transaction_type;

-- ==========================================================
-- ETL: Load Behavior & Risk Dimension
-- Transformation: Fill missing risk scores and clean anomalies
-- ==========================================================

INSERT INTO dw.dim_behavior_risk (login_frequency, session_duration, purchase_pattern, risk_score, anomaly)
SELECT
    COALESCE(login_frequency, 0),
    ROUND(COALESCE(session_duration, 0.0), 2),
    INITCAP(TRIM(purchase_pattern)),
    COALESCE(risk_score, 0.00),
    CASE 
        WHEN anomaly IS NULL OR anomaly = '' THEN 'None'
        ELSE INITCAP(TRIM(anomaly))
    END AS anomaly
FROM staging.stg_behavior_risk;
select * from dw.dim_behavior_risk;

-- ==========================================================
-- ETL: Load Date Dimension
-- Transformation: Extract components from timestamp
-- ==========================================================

INSERT INTO dw.dim_date (full_ts, date_value, day, month, year)
SELECT
    timestamp AS full_ts,
    CAST(timestamp AS DATE) AS date_value,
    EXTRACT(DAY FROM timestamp)::INT AS day,
    EXTRACT(MONTH FROM timestamp)::INT AS month,
    EXTRACT(YEAR FROM timestamp)::INT AS year
FROM staging.stg_transaction_type
WHERE timestamp IS NOT NULL;
select * from dw.dim_date;


-- ==============================================================
-- 3. LOAD FACT TABLE
-- ==============================================================
INSERT INTO dw.fact_transactions (
    customer_sk,
    merchant_sk,
    transaction_type_sk,
    behavior_risk_sk,
    date_sk,
    sender_account,
    receiver_account,
    amount,
    is_fraud
)
SELECT
    dc.customer_sk,
    dm.merchant_sk,
    dtt.transaction_type_sk,
    dbr.behavior_risk_sk,
    dd.date_sk,
    sa.sender_account,
    sa.receiver_account,
    sa.amount,
    sa.is_fraud
FROM staging.stg_accounts sa
CROSS JOIN LATERAL (
    SELECT customer_sk FROM dw.dim_customer ORDER BY RANDOM() LIMIT 1
) dc
CROSS JOIN LATERAL (
    SELECT merchant_sk FROM dw.dim_merchant ORDER BY RANDOM() LIMIT 1
) dm
CROSS JOIN LATERAL (
    SELECT transaction_type_sk FROM dw.dim_transaction_type ORDER BY RANDOM() LIMIT 1
) dtt
CROSS JOIN LATERAL (
    SELECT behavior_risk_sk FROM dw.dim_behavior_risk ORDER BY RANDOM() LIMIT 1
) dbr
CROSS JOIN LATERAL (
    SELECT date_sk FROM dw.dim_date ORDER BY RANDOM() LIMIT 1
) dd;
select * from dw.fact_transactions;

-- Record count verification for each table
SELECT 'dim_customer' AS table_name, COUNT(*) FROM dw.dim_customer
UNION ALL
SELECT 'dim_merchant', COUNT(*) FROM dw.dim_merchant
UNION ALL
SELECT 'dim_transaction_type', COUNT(*) FROM dw.dim_transaction_type
UNION ALL
SELECT 'dim_behavior_risk', COUNT(*) FROM dw.dim_behavior_risk
UNION ALL
SELECT 'dim_date', COUNT(*) FROM dw.dim_date
UNION ALL
SELECT 'fact_transactions', COUNT(*) FROM dw.fact_transactions;
