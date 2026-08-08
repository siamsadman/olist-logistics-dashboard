-- ==========================================
-- OLIST LOGISTICS & DELIVERY DASHBOARD
-- Fact Table Population
-- Run after 02_dim_date_extend.sql.
-- ==========================================

-- ==========================================
-- 1. fact_deliveries
-- Grain: one row per order. Sourced from stg_orders_logistics
-- (placeholder dates already cleaned to NULL in 00_staging_prep.sql),
-- joined to stg_customers for the customer key and to a
-- pre-aggregated freight total from stg_order_items.
-- ==========================================
INSERT INTO fact_deliveries (
    order_id, customer_unique_id, order_status,
    purchase_date_key, approved_date_key, carrier_date_key,
    delivered_date_key, estimated_delivery_date_key,
    total_freight_value, delivery_days, approval_days,
    shipping_days, days_vs_estimate, is_delivered, is_late
)
SELECT
    o.order_id,
    c.customer_unique_id,
    o.order_status,
    CONVERT(INT, FORMAT(o.order_purchase_timestamp, 'yyyyMMdd')) AS purchase_date_key,
    CASE WHEN o.order_approved_at IS NULL THEN NULL
         ELSE CONVERT(INT, FORMAT(o.order_approved_at, 'yyyyMMdd')) END AS approved_date_key,
    CASE WHEN o.order_delivered_carrier_date IS NULL THEN NULL
         ELSE CONVERT(INT, FORMAT(o.order_delivered_carrier_date, 'yyyyMMdd')) END AS carrier_date_key,
    CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL
         ELSE CONVERT(INT, FORMAT(o.order_delivered_customer_date, 'yyyyMMdd')) END AS delivered_date_key,
    CONVERT(INT, FORMAT(o.order_estimated_delivery_date, 'yyyyMMdd')) AS estimated_delivery_date_key,
    ISNULL(f.total_freight, 0) AS total_freight_value,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) AS delivery_days,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_approved_at) AS approval_days,
    DATEDIFF(DAY, o.order_delivered_carrier_date, o.order_delivered_customer_date) AS shipping_days,
    DATEDIFF(DAY, o.order_estimated_delivery_date, o.order_delivered_customer_date) AS days_vs_estimate,
    CASE WHEN o.order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END AS is_delivered,
    CASE WHEN o.order_delivered_customer_date IS NULL THEN NULL
         WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
         ELSE 0 END AS is_late
FROM stg_orders_logistics o
INNER JOIN stg_customers c ON o.customer_id = c.customer_id
LEFT JOIN (
    SELECT order_id, SUM(freight_value) AS total_freight
    FROM stg_order_items
    GROUP BY order_id
) f ON o.order_id = f.order_id;
GO

-- ==========================================
-- 2. bridge_order_seller
-- DISTINCT matters: an order can have multiple line items from
-- the same seller, which would otherwise violate the primary key.
-- ==========================================
INSERT INTO bridge_order_seller (order_id, seller_id)
SELECT DISTINCT order_id, seller_id
FROM stg_order_items;
GO

-- ==========================================
-- 3. bridge_order_product
-- Same DISTINCT reasoning as above.
-- ==========================================
INSERT INTO bridge_order_product (order_id, product_id)
SELECT DISTINCT order_id, product_id
FROM stg_order_items;
GO

-- ==========================================
-- 4. Add order_value and total_weight_g to fact_deliveries
-- Used on page 3 for the freight-as-%-of-order-value KPI and
-- the freight-vs-weight scatter plot. Both are aggregated from
-- stg_order_items / stg_products, same pattern as total_freight_value.
--
-- Note: 775 orders will show NULL for both columns - these are
-- the same 775 orders (known from Part 1) that have zero rows in
-- order_items, i.e. cancelled or unavailable before fulfillment.
-- This is expected, not a data error.
-- ==========================================
ALTER TABLE fact_deliveries ADD order_value DECIMAL(10,2);
GO

UPDATE fd
SET fd.order_value = oi.total_price
FROM fact_deliveries fd
INNER JOIN (
    SELECT order_id, SUM(price) AS total_price
    FROM stg_order_items
    GROUP BY order_id
) oi ON fd.order_id = oi.order_id;
GO

ALTER TABLE fact_deliveries ADD total_weight_g DECIMAL(12,2);
GO

UPDATE fd
SET fd.total_weight_g = w.total_weight
FROM fact_deliveries fd
INNER JOIN (
    SELECT oi.order_id, SUM(p.product_weight_g) AS total_weight
    FROM stg_order_items oi
    INNER JOIN stg_products p ON oi.product_id = p.product_id
    GROUP BY oi.order_id
) w ON fd.order_id = w.order_id;
GO

-- ==========================================
-- Post-load validation
-- ==========================================
SELECT 'fact_deliveries' AS tbl, COUNT(*) AS row_count FROM fact_deliveries
UNION ALL SELECT 'bridge_order_seller', COUNT(*) FROM bridge_order_seller
UNION ALL SELECT 'bridge_order_product', COUNT(*) FROM bridge_order_product;
-- Expected: fact_deliveries 99,441 | bridge_order_seller 100,010 | bridge_order_product ~110,000

-- Sanity check: no order should show negative delivery time
SELECT COUNT(*) AS negative_delivery_days
FROM fact_deliveries WHERE delivery_days < 0;
-- Expected: 0

-- Sanity check: is_late distribution
SELECT is_late, COUNT(*) AS order_count
FROM fact_deliveries GROUP BY is_late;
-- Expected: 0 (on-time) ~88,649 | 1 (late) ~7,827 | NULL (unresolved) 2,965

-- Sanity check: order_value / total_weight_g nulls should match
-- the known 775 zero-item orders exactly
SELECT COUNT(*) AS orders_missing_value FROM fact_deliveries WHERE order_value IS NULL;
SELECT COUNT(*) AS orders_missing_weight FROM fact_deliveries WHERE total_weight_g IS NULL;
-- Expected: 775 for both
