SELECT COUNT(*) FROM dw.fact_transactions;

-- B-Tree index
CREATE INDEX idx_fact_amount_btree
ON dw.fact_transactions (amount);

-- bitmap indexing
CREATE INDEX idx_fact_isfraud
ON dw.fact_transactions (is_fraud);


-- TEST QUERIES FOR B-TREE INDEXING

-- sequential scan
SET enable_seqscan = on;
SET enable_indexscan = off;
SET enable_bitmapscan = off;

EXPLAIN ANALYZE
SELECT *
FROM dw.fact_transactions
WHERE amount BETWEEN 5000 AND 10000;

-- indexing scan

SET enable_seqscan = off;
SET enable_bitmapscan = on;
SET enable_indexscan = on;

EXPLAIN ANALYZE
SELECT *
FROM dw.fact_transactions
WHERE amount BETWEEN 5000 AND 10000;

-- TEST QUERIES FOR BITMAP INDEXING

-- 1 sequential scan
SET enable_seqscan = on;
SET enable_indexscan = off;
SET enable_bitmapscan = off;

EXPLAIN ANALYZE
SELECT *
FROM dw.fact_transactions
WHERE is_fraud = TRUE;

-- 2 indexing scan
SET enable_seqscan = off;
SET enable_indexscan = off;
SET enable_bitmapscan = on;

EXPLAIN ANALYZE
SELECT *
FROM dw.fact_transactions
WHERE is_fraud = TRUE;

		

-- Combined query
SET enable_seqscan = on;
SET enable_indexscan = off;
SET enable_bitmapscan = off;

EXPLAIN ANALYZE
SELECT *
FROM dw.fact_transactions
WHERE is_fraud = TRUE AND amount > 10000;

-- With Aggregated function
SET enable_seqscan = on;
SET enable_indexscan = off;
SET enable_bitmapscan = off;

EXPLAIN ANALYZE
SELECT COUNT(*)
FROM dw.fact_transactions
WHERE is_fraud = TRUE;

SET enable_seqscan = off;
SET enable_indexscan = on;
SET enable_bitmapscan = on;

EXPLAIN ANALYZE
SELECT SUM(amount)
FROM dw.fact_transactions
WHERE is_fraud = TRUE;

-- DSS query
SET enable_seqscan = off;
SET enable_indexscan = on;
SET enable_bitmapscan = on;


EXPLAIN ANALYZE
SELECT 
    dt.year,
    dt.month,
    ttt.location_region,
    dm.merchant_name,
    dc.device_type,
    
    COUNT(f.fact_transaction_sk) AS total_transactions,
    SUM(f.amount) AS total_amount,
    
    SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) AS total_frauds,
    ROUND(
        100.0 * SUM(CASE WHEN f.is_fraud  THEN 1 ELSE 0 END) 
        / NULLIF(COUNT(f.fact_transaction_sk), 0), 2
    ) AS fraud_rate_percent,
    
    AVG(br.risk_score) AS avg_risk_score,
    MAX(br.risk_score) AS max_risk_score,
    MIN(br.risk_score) AS min_risk_score,
    
    AVG(br.session_duration) AS avg_session_duration,
    AVG(br.login_frequency) AS avg_login_frequency
    
FROM dw.fact_transactions f
JOIN dw.dim_customer dc 
    ON f.customer_sk = dc.customer_sk
JOIN dw.dim_behavior_risk br 
    ON f.behavior_risk_sk = br.behavior_risk_sk
JOIN dw.dim_date dt 
    ON f.date_sk = dt.date_sk
JOIN dw.dim_merchant dm 
    ON f.merchant_sk = dm.merchant_sk
JOIN dw.dim_transaction_type ttt 
    ON f.transaction_type_sk = ttt.transaction_type_sk

WHERE dt.year >= 2023
  AND f.amount > 1000
  AND ttt.location_region IS NOT NULL

GROUP BY 
    dt.year,
    dt.month,
    ttt.location_region,
    dm.merchant_name,
    dc.device_type

HAVING 
    COUNT(f.fact_transaction_sk) > 50
    AND SUM(CASE WHEN f.is_fraud THEN 1 ELSE 0 END) > 5

ORDER BY 
    fraud_rate_percent DESC,
    avg_risk_score DESC
LIMIT 50;

--OLTP query
SET enable_seqscan = on;
SET enable_indexscan = off;
SET enable_bitmapscan = off;

EXPLAIN ANALYZE
SELECT 
    fact_transaction_sk,
    sender_account,
    receiver_account,
    amount,
    is_fraud
FROM dw.fact_transactions
WHERE amount > 1000
  AND is_fraud = FALSE
  AND load_timestamp BETWEEN '2024-01-01' AND '2025-01-01'
  AND sender_account LIKE 'PK%'
ORDER BY amount DESC;

