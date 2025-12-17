CREATE DATABASE project;

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
--  Dimension Tables
-- ==========================================================

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

-- ==========================================================
-- 2️⃣ Create fact_transactions_elt Table
-- ==========================================================

DROP TABLE IF EXISTS dw.fact_transactions_elt CASCADE;

CREATE TABLE dw.fact_transactions_elt (
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


-- Load Customers
INSERT INTO dw.dim_customer (customer_name, customer_email, card_number, card_expiry, device_type)
SELECT DISTINCT
    customer_name,
    customer_email,
    card_number,
    card_expiry,
    device_type
FROM staging.stg_user
WHERE customer_email IS NOT NULL
ON CONFLICT (customer_email) DO NOTHING;

-- Load Merchants
INSERT INTO dw.dim_merchant (merchant_name, merchant_email)
SELECT DISTINCT
    s.merchant_name,
    s.merchant_email
FROM staging.stg_user s
WHERE s.merchant_email IS NOT NULL;

-- Load Transaction Types
INSERT INTO dw.dim_transaction_type (transaction_type, location_region, ip_prefix)
SELECT DISTINCT
    t.transaction_type,
    t.location_region,
    t.ip_prefix
FROM staging.stg_transaction_type t
WHERE t.transaction_type IS NOT NULL;

-- Load Behavior & Risk
INSERT INTO dw.dim_behavior_risk (login_frequency, session_duration, purchase_pattern, risk_score, anomaly)
SELECT DISTINCT
    b.login_frequency,
    b.session_duration,
    b.purchase_pattern,
    b.risk_score,
    b.anomaly
FROM staging.stg_behavior_risk b;

-- Load Dates
INSERT INTO dw.dim_date (full_ts, date_value, day, month, year)
SELECT DISTINCT
    t.timestamp AS full_ts,
    DATE(t.timestamp) AS date_value,
    EXTRACT(DAY FROM t.timestamp)::INT AS day,
    EXTRACT(MONTH FROM t.timestamp)::INT AS month,
    EXTRACT(YEAR FROM t.timestamp)::INT AS year
FROM staging.stg_transaction_type t;

-- ==========================================================
-- Transform and Load into fact_transactions_elt
-- ==========================================================


-- ==========================================================
-- ELT Insert into Fact Table
-- ==========================================================
-- Load 1000 rows at a time
INSERT INTO dw.fact_transactions_elt (
    customer_sk, merchant_sk, transaction_type_sk, behavior_risk_sk, date_sk,
    sender_account, receiver_account, amount, is_fraud
)
SELECT
    dc.customer_sk,
    dm.merchant_sk,
    dtt.transaction_type_sk,
    dbr.behavior_risk_sk,
    dd.date_sk,
    a.sender_account,
    a.receiver_account,
    a.amount,
    a.is_fraud
FROM staging.stg_user s
JOIN dw.dim_customer dc ON s.customer_email = dc.customer_email
JOIN dw.dim_merchant dm ON s.merchant_email = dm.merchant_email
JOIN staging.stg_accounts a ON TRUE
JOIN staging.stg_transaction_type stt ON TRUE
JOIN dw.dim_transaction_type dtt ON stt.transaction_type = dtt.transaction_type
JOIN staging.stg_behavior_risk b ON TRUE
JOIN dw.dim_behavior_risk dbr ON b.risk_score = dbr.risk_score
JOIN dw.dim_date dd ON DATE(stt.timestamp) = dd.date_value
LIMIT  OFFSET 50000 ;
select * from dw.fact_transactions_elt;

-- ==========================================================
-- Validation: Compare ETL vs ELT
-- ==========================================================

-- Compare Record Counts
SELECT
    'ETL' AS source,
    COUNT(*) AS total_records,
    SUM(amount)::NUMERIC(12,2) AS total_amount
FROM dw.fact_transactions
UNION ALL
SELECT
    'ELT' AS source,
    COUNT(*) AS total_records,
    SUM(amount)::NUMERIC(12,2) AS total_amount
FROM dw.fact_transactions_elt;

-- ==========================================================
-- End of ELT Script
-- ==========================================================

select COUNT(*) from dw.fact_transactions;
SELECT SUM(amount) FROM dw.fact_transactions;

SELECT COUNT(*) FROM dw.fact_transactions_elt;
SELECT SUM(amount) FROM dw.fact_transactions_elt;

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
SELECT 'fact_transactions_elt', COUNT(*) FROM dw.fact_transactions_elt;





