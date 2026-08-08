-- ==========================================
-- OLIST LOGISTICS & DELIVERY DASHBOARD
-- dim_date Range Extension
-- Run after 01_schema.sql, before 03_load_facts.sql.
--
-- dim_date was built in Part 1 covering only the purchase-date
-- range (through 2018-10-17). order_estimated_delivery_date
-- projects up to 26 days past the latest purchase date, so
-- loading fact_deliveries without first extending dim_date
-- throws a foreign key violation on estimated_delivery_date_key.
--
-- This only adds new rows for dates that don't already exist -
-- no existing dim_date row is modified, so Part 1's dashboard
-- is unaffected.
-- ==========================================

;WITH Numbers AS (
    SELECT TOP (DATEDIFF(DAY, '2018-10-17', '2018-11-12'))
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dim_date (date_key, full_date, year, quarter, month, month_name, day, day_name, week_of_year, is_weekend, year_month, is_complete_month)
SELECT
    CONVERT(INT, FORMAT(d, 'yyyyMMdd'))            AS date_key,
    d                                                AS full_date,
    YEAR(d)                                          AS year,
    DATEPART(QUARTER, d)                             AS quarter,
    MONTH(d)                                         AS month,
    DATENAME(MONTH, d)                               AS month_name,
    DAY(d)                                           AS day,
    DATENAME(WEEKDAY, d)                             AS day_name,
    DATEPART(WEEK, d)                                AS week_of_year,
    CASE WHEN DATENAME(WEEKDAY, d) IN ('Saturday','Sunday') THEN 1 ELSE 0 END AS is_weekend,
    FORMAT(d, 'yyyy-MM')                             AS year_month,
    0                                                 AS is_complete_month  -- all new rows fall after Aug 2018, already excluded from trend visuals
FROM Numbers
CROSS APPLY (SELECT DATEADD(DAY, n, '2018-10-17') AS d) AS Dates;
GO

-- ==========================================
-- Validation - dim_date should now span 2016-09-04 to 2018-11-12,
-- with 800 total rows (774 original + 26 new)
-- ==========================================
SELECT MIN(full_date) AS min_date, MAX(full_date) AS max_date, COUNT(*) AS row_count
FROM dim_date;
