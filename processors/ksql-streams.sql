-- =====================================================
-- Real-Time Customer Experience Intelligence Platform
-- ksqlDB Stream Processing Queries
-- =====================================================

-- Set processing guarantees
SET 'processing.guarantee' = 'exactly_once';
SET 'cache.max.bytes.buffering' = '10000000';

-- =====================================================
-- 1. CREATE BASE STREAMS FROM CONNECTORS
-- =====================================================

-- Transactions stream from PostgreSQL CDC
CREATE STREAM transactions_raw (
    transaction_id VARCHAR KEY,
    customer_id VARCHAR,
    amount DOUBLE,
    currency VARCHAR,
    merchant_id VARCHAR,
    merchant_category VARCHAR,
    location STRUCT<
        country VARCHAR,
        city VARCHAR,
        latitude DOUBLE,
        longitude DOUBLE
    >,
    payment_method VARCHAR,
    device_info STRUCT<
        device_id VARCHAR,
        device_type VARCHAR,
        ip_address VARCHAR,
        user_agent VARCHAR
    >,
    timestamp BIGINT,
    status VARCHAR
) WITH (
    KAFKA_TOPIC='customers.cdc.customerdb.public.transactions',
    VALUE_FORMAT='AVRO',
    TIMESTAMP='timestamp'
);

-- Customer profiles stream from MongoDB
CREATE STREAM customer_profiles_raw (
    customer_id VARCHAR KEY,
    email VARCHAR,
    phone VARCHAR,
    name STRUCT<first_name VARCHAR, last_name VARCHAR>,
    address STRUCT<
        street VARCHAR,
        city VARCHAR,
        state VARCHAR,
        zip_code VARCHAR,
        country VARCHAR
    >,
    preferences STRUCT<
        communication_channel ARRAY<VARCHAR>,
        product_categories ARRAY<VARCHAR>,
        notification_enabled BOOLEAN
    >,
    segments ARRAY<VARCHAR>,
    lifetime_value DOUBLE,
    account_created_at BIGINT,
    last_activity_at BIGINT
) WITH (
    KAFKA_TOPIC='mongodb.customer_profiles.profiles',
    VALUE_FORMAT='AVRO'
);

-- Clickstream events from HTTP connector
CREATE STREAM clickstream_events (
    event_id VARCHAR KEY,
    session_id VARCHAR,
    customer_id VARCHAR,
    event_type VARCHAR,
    page_url VARCHAR,
    referrer VARCHAR,
    product_id VARCHAR,
    search_query VARCHAR,
    device STRUCT<
        type VARCHAR,
        os VARCHAR,
        browser VARCHAR
    >,
    geo_location STRUCT<
        country VARCHAR,
        region VARCHAR,
        city VARCHAR
    >,
    timestamp BIGINT,
    metadata MAP<VARCHAR, VARCHAR>
) WITH (
    KAFKA_TOPIC='clickstream.events',
    VALUE_FORMAT='AVRO',
    TIMESTAMP='timestamp'
);

-- =====================================================
-- 2. FRAUD DETECTION - REAL-TIME ANOMALY DETECTION
-- =====================================================

-- Detect high-value transactions
CREATE STREAM high_value_transactions AS
SELECT
    transaction_id,
    customer_id,
    amount,
    merchant_id,
    merchant_category,
    location,
    device_info,
    timestamp,
    'HIGH_VALUE' AS alert_type,
    'Transaction exceeds $5000 threshold' AS alert_reason
FROM transactions_raw
WHERE amount > 5000
EMIT CHANGES;

-- Detect rapid successive transactions (potential fraud)
CREATE TABLE rapid_transactions AS
SELECT
    customer_id,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_amount,
    COLLECT_LIST(transaction_id) AS transaction_ids,
    WINDOWSTART AS window_start,
    WINDOWEND AS window_end
FROM transactions_raw
WINDOW TUMBLING (SIZE 5 MINUTES)
GROUP BY customer_id
HAVING COUNT(*) > 5
EMIT CHANGES;

-- Flag suspicious transactions
CREATE STREAM suspicious_transactions AS
SELECT
    t.transaction_id,
    t.customer_id,
    t.amount,
    t.merchant_id,
    t.location,
    rt.transaction_count AS recent_transaction_count,
    rt.total_amount AS recent_total_amount,
    'RAPID_TRANSACTIONS' AS fraud_type,
    (rt.transaction_count * 10) AS risk_score
FROM transactions_raw t
INNER JOIN rapid_transactions rt
    WITHIN 1 MINUTES
    ON t.customer_id = rt.customer_id
EMIT CHANGES;

-- Detect foreign transactions (location mismatch)
CREATE STREAM foreign_transactions AS
SELECT
    t.transaction_id,
    t.customer_id,
    t.amount,
    t.location AS transaction_location,
    c.address AS customer_address,
    'LOCATION_MISMATCH' AS fraud_type,
    70.0 AS risk_score
FROM transactions_raw t
INNER JOIN customer_profiles_raw c
    WITHIN 1 HOURS
    ON t.customer_id = c.customer_id
WHERE t.location->country != c.address->country
EMIT CHANGES;

-- =====================================================
-- 3. CUSTOMER 360 VIEW - ENRICHED PROFILE
-- =====================================================

-- Customer spending patterns
CREATE TABLE customer_spending_stats AS
SELECT
    customer_id,
    COUNT(*) AS total_transactions,
    SUM(amount) AS total_spent,
    AVG(amount) AS avg_transaction_amount,
    MAX(amount) AS max_transaction_amount,
    COLLECT_SET(merchant_category) AS favorite_categories,
    LATEST_BY_OFFSET(timestamp) AS last_transaction_time
FROM transactions_raw
WINDOW TUMBLING (SIZE 30 DAYS)
GROUP BY customer_id
EMIT CHANGES;

-- Customer engagement metrics from clickstream
CREATE TABLE customer_engagement AS
SELECT
    customer_id,
    COUNT(*) AS total_events,
    COUNT_DISTINCT(session_id) AS total_sessions,
    SUM(CASE WHEN event_type = 'PAGE_VIEW' THEN 1 ELSE 0 END) AS page_views,
    SUM(CASE WHEN event_type = 'ADD_TO_CART' THEN 1 ELSE 0 END) AS add_to_cart_events,
    SUM(CASE WHEN event_type = 'PURCHASE' THEN 1 ELSE 0 END) AS purchases,
    COLLECT_LIST(product_id) AS viewed_products,
    LATEST_BY_OFFSET(timestamp) AS last_activity_time
FROM clickstream_events
WHERE customer_id IS NOT NULL
WINDOW TUMBLING (SIZE 7 DAYS)
GROUP BY customer_id
EMIT CHANGES;

-- Unified customer 360 view
CREATE TABLE customer_360 AS
SELECT
    p.customer_id,
    p.email,
    p.name,
    p.address,
    p.segments,
    p.lifetime_value,
    s.total_transactions,
    s.total_spent,
    s.avg_transaction_amount,
    s.favorite_categories,
    e.total_sessions,
    e.page_views,
    e.add_to_cart_events,
    e.purchases,
    CASE
        WHEN e.purchases > 0 THEN (e.purchases * 100.0 / e.page_views)
        ELSE 0
    END AS conversion_rate,
    s.last_transaction_time,
    e.last_activity_time
FROM customer_profiles_raw p
LEFT JOIN customer_spending_stats s ON p.customer_id = s.customer_id
LEFT JOIN customer_engagement e ON p.customer_id = e.customer_id
EMIT CHANGES;

-- =====================================================
-- 4. PERSONALIZED RECOMMENDATIONS
-- =====================================================

-- Product affinity based on clickstream
CREATE TABLE product_views AS
SELECT
    product_id,
    COUNT(*) AS view_count,
    COUNT_DISTINCT(customer_id) AS unique_viewers,
    COLLECT_SET(customer_id) AS viewer_ids,
    WINDOWSTART AS window_start
FROM clickstream_events
WHERE product_id IS NOT NULL
    AND event_type IN ('PAGE_VIEW', 'CLICK')
WINDOW HOPPING (SIZE 1 HOURS, ADVANCE BY 15 MINUTES)
GROUP BY product_id
EMIT CHANGES;

-- Cart abandonment detection
CREATE STREAM cart_abandonments AS
SELECT
    customer_id,
    session_id,
    product_id,
    timestamp AS add_to_cart_time,
    'CART_ABANDONED' AS event_status
FROM clickstream_events
WHERE event_type = 'ADD_TO_CART'
    AND customer_id IS NOT NULL
PARTITION BY customer_id
EMIT CHANGES;

-- Real-time product recommendations
CREATE STREAM product_recommendations AS
SELECT
    c.customer_id,
    c.session_id,
    c.product_id AS current_product,
    pv.product_id AS recommended_product,
    pv.view_count AS recommendation_score,
    'SIMILAR_PRODUCTS' AS recommendation_type
FROM clickstream_events c
INNER JOIN product_views pv
    WITHIN 1 HOURS
    ON c.product_id != pv.product_id
WHERE c.event_type = 'PAGE_VIEW'
    AND c.product_id IS NOT NULL
EMIT CHANGES;

-- =====================================================
-- 5. CHURN PREDICTION INDICATORS
-- =====================================================

-- Identify inactive customers
CREATE TABLE inactive_customers AS
SELECT
    customer_id,
    LATEST_BY_OFFSET(timestamp) AS last_activity,
    COUNT(*) AS activity_count_last_30_days,
    'AT_RISK_CHURN' AS status
FROM clickstream_events
WHERE customer_id IS NOT NULL
WINDOW TUMBLING (SIZE 30 DAYS)
GROUP BY customer_id
HAVING COUNT(*) < 5
EMIT CHANGES;

-- Declining engagement pattern
CREATE TABLE declining_engagement AS
SELECT
    customer_id,
    COUNT(*) AS current_period_events,
    LAG(COUNT(*)) OVER (PARTITION BY customer_id) AS previous_period_events,
    CASE
        WHEN LAG(COUNT(*)) OVER (PARTITION BY customer_id) > 0
        THEN ((COUNT(*) - LAG(COUNT(*))) * 100.0 / LAG(COUNT(*)))
        ELSE 0
    END AS engagement_change_percent
FROM clickstream_events
WHERE customer_id IS NOT NULL
WINDOW TUMBLING (SIZE 7 DAYS)
GROUP BY customer_id
HAVING engagement_change_percent < -30
EMIT CHANGES;

-- =====================================================
-- 6. REAL-TIME ALERTS AND NOTIFICATIONS
-- =====================================================

-- Create alerts stream for all critical events
CREATE STREAM customer_alerts AS
SELECT
    customer_id,
    'FRAUD_ALERT' AS alert_type,
    'HIGH_VALUE_TRANSACTION' AS alert_subtype,
    CAST(amount AS VARCHAR) AS alert_data,
    timestamp AS alert_time
FROM high_value_transactions
EMIT CHANGES;

-- Insert additional alert types
INSERT INTO customer_alerts
SELECT
    customer_id,
    'FRAUD_ALERT' AS alert_type,
    fraud_type AS alert_subtype,
    CONCAT('Risk Score: ', CAST(risk_score AS VARCHAR)) AS alert_data,
    ROWTIME AS alert_time
FROM suspicious_transactions
EMIT CHANGES;

INSERT INTO customer_alerts
SELECT
    customer_id,
    'CHURN_RISK' AS alert_type,
    'INACTIVE_CUSTOMER' AS alert_subtype,
    CONCAT('Last activity: ', CAST(last_activity AS VARCHAR)) AS alert_data,
    ROWTIME AS alert_time
FROM inactive_customers
EMIT CHANGES;

-- =====================================================
-- 7. BUSINESS METRICS DASHBOARD
-- =====================================================

-- Real-time revenue metrics
CREATE TABLE revenue_metrics AS
SELECT
    'GLOBAL' AS metric_key,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_revenue,
    AVG(amount) AS avg_transaction_value,
    COUNT_DISTINCT(customer_id) AS unique_customers,
    WINDOWSTART AS window_start,
    WINDOWEND AS window_end
FROM transactions_raw
WHERE status = 'APPROVED'
WINDOW TUMBLING (SIZE 1 HOURS)
GROUP BY 'GLOBAL'
EMIT CHANGES;

-- Revenue by merchant category
CREATE TABLE revenue_by_category AS
SELECT
    merchant_category,
    COUNT(*) AS transaction_count,
    SUM(amount) AS category_revenue,
    AVG(amount) AS avg_amount,
    WINDOWSTART AS window_start
FROM transactions_raw
WHERE status = 'APPROVED'
WINDOW TUMBLING (SIZE 1 HOURS)
GROUP BY merchant_category
EMIT CHANGES;

-- Conversion funnel metrics
CREATE TABLE conversion_funnel AS
SELECT
    'FUNNEL' AS funnel_key,
    SUM(CASE WHEN event_type = 'PAGE_VIEW' THEN 1 ELSE 0 END) AS page_views,
    SUM(CASE WHEN event_type = 'ADD_TO_CART' THEN 1 ELSE 0 END) AS add_to_cart,
    SUM(CASE WHEN event_type = 'PURCHASE' THEN 1 ELSE 0 END) AS purchases,
    CASE
        WHEN SUM(CASE WHEN event_type = 'PAGE_VIEW' THEN 1 ELSE 0 END) > 0
        THEN (SUM(CASE WHEN event_type = 'PURCHASE' THEN 1 ELSE 0 END) * 100.0 /
              SUM(CASE WHEN event_type = 'PAGE_VIEW' THEN 1 ELSE 0 END))
        ELSE 0
    END AS conversion_rate
FROM clickstream_events
WINDOW TUMBLING (SIZE 1 HOURS)
GROUP BY 'FUNNEL'
EMIT CHANGES;
