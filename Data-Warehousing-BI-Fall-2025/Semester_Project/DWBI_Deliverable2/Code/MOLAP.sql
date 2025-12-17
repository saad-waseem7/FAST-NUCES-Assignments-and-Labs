-- 1) Total transactions and total amount (global snapshot)
CREATE MATERIALIZED VIEW cube_global_snapshot AS
SELECT 
    COUNT(*) AS total_transactions,
    SUM(amount) AS total_amount
FROM dw.fact_transactions;

SELECT * FROM cube_global_snapshot;

-- 2) Daily transaction volume & total amount (time series)
CREATE MATERIALIZED VIEW cube_daily_tx AS
SELECT
    d.date_value AS date,
    COUNT(*) AS tx_count,
    SUM(f.amount) AS total_amount
FROM dw.fact_transactions f
JOIN dw.dim_date d ON f.date_sk = d.date_sk
GROUP BY d.date_sk, d.date_value;

SELECT * FROM cube_daily_tx ORDER BY date;

-- 3) Fraud rate by region (region-level risk)
CREATE MATERIALIZED VIEW cube_region_fraud AS
SELECT
    t.location_region,
    COUNT(*) AS total_tx,
    SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) AS fraud_tx
FROM dw.fact_transactions f
JOIN dw.dim_transaction_type t ON f.transaction_type_sk = t.transaction_type_sk
GROUP BY t.location_region;

SELECT 
  location_region,
  total_tx,
  fraud_tx,
  ROUND(100.0 * fraud_tx / NULLIF(total_tx, 0), 2) AS fraud_rate_pct
FROM cube_region_fraud
ORDER BY fraud_rate_pct DESC;

-- 4) Monthly fraud trend (year, month)
CREATE MATERIALIZED VIEW cube_monthly_fraud AS
SELECT
    d.year,
    d.month,
    COUNT(*) AS total_tx,
    SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) AS fraud_tx
FROM dw.fact_transactions f
JOIN dw.dim_date d ON f.date_sk = d.date_sk
GROUP BY d.year, d.month;

SELECT *,
  ROUND(100.0 * fraud_tx / NULLIF(total_tx, 0), 2) AS fraud_rate_pct
FROM cube_monthly_fraud
ORDER BY year, month;

-- 5) Device type usage and fraud rate (device_type from dim_customer)
CREATE MATERIALIZED VIEW cube_device_fraud AS
SELECT
    c.device_type,
    COUNT(*) AS total_tx,
    SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) AS fraud_tx
FROM dw.fact_transactions f
JOIN dw.dim_customer c ON f.customer_sk = c.customer_sk
GROUP BY c.device_type;

SELECT 
  device_type,
  total_tx,
  fraud_tx,
  ROUND(100.0 * fraud_tx / NULLIF(total_tx, 0), 2) AS fraud_rate_pct
FROM cube_device_fraud
ORDER BY fraud_rate_pct DESC;

-- 6) Risk-category vs fraud rate (bucket risk_score from dim_behavior_risk)
CREATE MATERIALIZED VIEW cube_risk_bucket AS
SELECT
  CASE
    WHEN b.risk_score < 30 THEN 'Low'
    WHEN b.risk_score BETWEEN 30 AND 70 THEN 'Medium'
    ELSE 'High'
  END AS risk_bucket,
  COUNT(*) AS total_tx,
  SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) AS fraud_tx
FROM dw.fact_transactions f
JOIN dw.dim_behavior_risk b ON f.behavior_risk_sk = b.behavior_risk_sk
GROUP BY 1;

SELECT 
  risk_bucket,
  total_tx,
  fraud_tx,
  ROUND(100.0 * fraud_tx / NULLIF(total_tx, 0), 2) AS fraud_rate_pct
FROM cube_risk_bucket
ORDER BY fraud_rate_pct DESC;

-- 7) High-value anomaly detection: transactions > mean + 3*stddev
CREATE MATERIALIZED VIEW cube_tx_stats AS
SELECT 
  AVG(amount) AS mean_amt, 
  STDDEV_POP(amount) AS std_amt
FROM dw.fact_transactions;

SELECT
  f.fact_transaction_sk,
  f.amount,
  c.customer_name,
  m.merchant_name,
  d.date_value
FROM dw.fact_transactions f
JOIN dw.dim_customer c ON f.customer_sk = c.customer_sk
JOIN dw.dim_merchant m ON f.merchant_sk = m.merchant_sk
JOIN dw.dim_date d ON f.date_sk = d.date_sk
CROSS JOIN cube_tx_stats
WHERE f.amount > (cube_tx_stats.mean_amt + 3 * cube_tx_stats.std_amt)
ORDER BY f.amount DESC;

-- 8) Account flow summary: total inflow & outflow per account (aggregated)
CREATE MATERIALIZED VIEW cube_account_flow AS
SELECT
  acc,
  SUM(total_out) AS total_outflow,
  SUM(total_in) AS total_inflow
FROM (
  SELECT sender_account AS acc, SUM(amount) AS total_out, 0::numeric AS total_in
  FROM dw.fact_transactions GROUP BY sender_account
  UNION ALL
  SELECT receiver_account AS acc, 0::numeric AS total_out, SUM(amount) AS total_in
  FROM dw.fact_transactions GROUP BY receiver_account
) x
GROUP BY acc;

SELECT * FROM cube_account_flow ORDER BY total_inflow DESC LIMIT 20;

-- 9) CUBE example: merchant, region, month — amount and frauds for all combinations
CREATE MATERIALIZED VIEW cube_merchant_region_month AS
SELECT
  m.merchant_name,
  t.location_region,
  d.month,
  SUM(f.amount) AS total_amount,
  SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) AS fraud_tx
FROM dw.fact_transactions f
JOIN dw.dim_merchant m ON f.merchant_sk = m.merchant_sk
JOIN dw.dim_transaction_type t ON f.transaction_type_sk = t.transaction_type_sk
JOIN dw.dim_date d ON f.date_sk = d.date_sk
GROUP BY CUBE (m.merchant_name, t.location_region, d.month);

SELECT * FROM cube_merchant_region_month
ORDER BY merchant_name NULLS FIRST, location_region NULLS FIRST, month NULLS FIRST;


