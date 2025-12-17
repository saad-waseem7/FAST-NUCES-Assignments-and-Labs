--Nested Loop
SET enable_hashjoin = off;
SET enable_mergejoin = off;
SET enable_nestloop = on;

EXPLAIN ANALYZE
SELECT 
  f.fact_transaction_sk,
  c.customer_name,
  m.merchant_name,
  f.amount
FROM dw.fact_transactions f
JOIN dw.dim_customer c ON f.customer_sk = c.customer_sk
JOIN dw.dim_merchant m ON f.merchant_sk = m.merchant_sk
WHERE f.amount > 500;

--Sort Merge Join
SET enable_hashjoin = off;
SET enable_nestloop = off;
SET enable_mergejoin = on;

EXPLAIN ANALYZE
SELECT 
  f.fact_transaction_sk,
  c.customer_name,
  t.location_region,
  f.amount
FROM dw.fact_transactions f
JOIN dw.dim_customer c    ON f.customer_sk = c.customer_sk
JOIN dw.dim_transaction_type t ON f.transaction_type_sk = t.transaction_type_sk
ORDER BY f.amount;

--Hash Join
SET enable_nestloop = off;
SET enable_mergejoin = off;
SET enable_hashjoin = on;

EXPLAIN ANALYZE
SELECT 
    b.risk_score,
    b.login_frequency,
    COUNT(*) AS total_transactions,
    SUM(f.amount) AS total_amount,
    ROUND(AVG(f.amount),2) AS avg_tx_amount
FROM dw.fact_transactions f
JOIN dw.dim_behavior_risk b
  ON f.behavior_risk_sk = b.behavior_risk_sk
GROUP BY b.risk_score, b.login_frequency
ORDER BY total_amount DESC
LIMIT 10;

--DSS vs OLTP Comparison
EXPLAIN ANALYZE
SELECT * 
FROM dw.fact_transactions
WHERE fact_transaction_sk = 1001;

EXPLAIN ANALYZE
SELECT
  t.location_region,
  d.month,
  SUM(f.amount) AS total_amount,
  SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) AS fraud_tx
FROM dw.fact_transactions f
JOIN dw.dim_transaction_type t ON f.transaction_type_sk = t.transaction_type_sk
JOIN dw.dim_date d ON f.date_sk = d.date_sk
GROUP BY t.location_region, d.month;
