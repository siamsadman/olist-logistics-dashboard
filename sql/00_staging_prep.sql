-- ==========================================
-- OLIST LOGISTICS & DELIVERY DASHBOARD
-- Staging Preparation
-- Run before 01_schema.sql.
--
-- Part 1's data_cleaning.py filled missing delivery timestamp
-- columns with a placeholder '1900-01-01 00:00:00' instead of
-- leaving them null. This was harmless for Part 1 (sales/revenue
-- never did date math on these columns) but would corrupt every
-- delivery-time and on-time-rate measure in this project.
--
-- Rather than update Part 1's stg_orders table in place, we
-- duplicate it here and clean the copy, so Part 1's pipeline and
-- published dashboard remain completely untouched.
-- ==========================================

-- ==========================================
-- 1. Duplicate stg_orders into a project-local copy
-- ==========================================
SELECT *
INTO stg_orders_logistics
FROM stg_orders;
GO

-- ==========================================
-- 2. Confirm the scale of the placeholder-date problem
-- before fixing it (documented here for reproducibility)
-- ==========================================
SELECT
    SUM(CASE WHEN order_approved_at = '1900-01-01 00:00:00' THEN 1 ELSE 0 END) AS approved_placeholder,
    SUM(CASE WHEN order_delivered_carrier_date = '1900-01-01 00:00:00' THEN 1 ELSE 0 END) AS carrier_placeholder,
    SUM(CASE WHEN order_delivered_customer_date = '1900-01-01 00:00:00' THEN 1 ELSE 0 END) AS customer_placeholder
FROM stg_orders_logistics;
-- Expected result: 160 / 1,783 / 2,965
-- This funnel-shaped pattern (each stage losing more orders than
-- the last) reflects orders dropping out at different points in
-- the fulfillment lifecycle - not a data error.

-- ==========================================
-- 3. Convert the placeholder strings back to true NULLs
-- ==========================================
UPDATE stg_orders_logistics SET order_approved_at = NULL
WHERE order_approved_at = '1900-01-01 00:00:00';

UPDATE stg_orders_logistics SET order_delivered_carrier_date = NULL
WHERE order_delivered_carrier_date = '1900-01-01 00:00:00';

UPDATE stg_orders_logistics SET order_delivered_customer_date = NULL
WHERE order_delivered_customer_date = '1900-01-01 00:00:00';
GO

-- ==========================================
-- 4. Confirm the fix - all three counts should now be 0
-- ==========================================
SELECT
    SUM(CASE WHEN order_approved_at = '1900-01-01 00:00:00' THEN 1 ELSE 0 END) AS approved_placeholder,
    SUM(CASE WHEN order_delivered_carrier_date = '1900-01-01 00:00:00' THEN 1 ELSE 0 END) AS carrier_placeholder,
    SUM(CASE WHEN order_delivered_customer_date = '1900-01-01 00:00:00' THEN 1 ELSE 0 END) AS customer_placeholder
FROM stg_orders_logistics;

-- ==========================================
-- 5. Confirm order_estimated_delivery_date has no nulls
-- (needed before 02_dim_date_extend.sql, since this column
-- is not null-guarded in the fact load and would throw a
-- FORMAT() error on a null value)
-- ==========================================
SELECT COUNT(*) AS estimated_date_nulls
FROM stg_orders_logistics
WHERE order_estimated_delivery_date IS NULL;
-- Expected result: 0
