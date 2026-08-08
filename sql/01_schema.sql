-- ==========================================
-- OLIST LOGISTICS & DELIVERY DASHBOARD
-- Star Schema DDL
-- ==========================================
-- New objects only. dim_date, dim_customer, dim_seller, and
-- dim_product are reused as-is from Part 1's schema. dim_order,
-- fact_order_items, and fact_payments are not touched by this
-- project.
--
-- fact_deliveries sits at order grain (one row per order_id).
-- Two bridge tables resolve the many-to-many relationships
-- between orders and sellers, and orders and product categories,
-- since an order can legitimately involve more than one seller
-- or span more than one category.
-- ==========================================

-- ==========================================
-- FACT: Deliveries (grain = one row per order)
-- ==========================================
CREATE TABLE fact_deliveries (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50) REFERENCES dim_customer(customer_unique_id),
    order_status VARCHAR(20),

    -- role-playing date keys; only purchase_date_key is guaranteed non-null
    purchase_date_key INT REFERENCES dim_date(date_key),
    approved_date_key INT NULL REFERENCES dim_date(date_key),
    carrier_date_key INT NULL REFERENCES dim_date(date_key),
    delivered_date_key INT NULL REFERENCES dim_date(date_key),
    estimated_delivery_date_key INT NULL REFERENCES dim_date(date_key),

    -- pre-computed measures, kept in SQL for validation convenience
    -- (also derivable in DAX from the date keys alone)
    total_freight_value DECIMAL(10,2),
    order_value DECIMAL(10,2) NULL,       -- added in 03_load_facts.sql
    total_weight_g DECIMAL(12,2) NULL,    -- added in 03_load_facts.sql
    delivery_days INT NULL,               -- delivered_date - purchase_date
    approval_days INT NULL,               -- approved_date - purchase_date
    shipping_days INT NULL,               -- delivered_date - carrier_date
    days_vs_estimate INT NULL,            -- delivered_date - estimated_date; negative = early
    is_delivered BIT,
    is_late BIT NULL                      -- NULL if not yet delivered, not "0"
);

-- ==========================================
-- BRIDGE: Order to Seller
-- An order can include line items from more than one seller.
-- ==========================================
CREATE TABLE bridge_order_seller (
    order_id VARCHAR(50) REFERENCES fact_deliveries(order_id),
    seller_id VARCHAR(50) REFERENCES dim_seller(seller_id),
    PRIMARY KEY (order_id, seller_id)
);

-- ==========================================
-- BRIDGE: Order to Product
-- An order can include items from more than one product category.
-- ==========================================
CREATE TABLE bridge_order_product (
    order_id VARCHAR(50) REFERENCES fact_deliveries(order_id),
    product_id VARCHAR(50) REFERENCES dim_product(product_id),
    PRIMARY KEY (order_id, product_id)
);

-- ==========================================
-- NOTE ON MODEL RELATIONSHIPS (set in Power BI, not SQL)
-- ==========================================
-- fact_deliveries -> dim_date: five relationships, one per date key.
--   Only purchase_date_key is set active by default; the other
--   four are invoked with USERELATIONSHIP() in DAX as needed.
-- bridge_order_seller -> fact_deliveries and
-- bridge_order_product -> fact_deliveries: both must have
--   cross-filter direction set to "Both", not the default "Single",
--   or filters on seller/category will not reach fact_deliveries.
