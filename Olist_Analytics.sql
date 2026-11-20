/* ============================================================================
   OLIST E-COMMERCE ANALYTICS
   End-to-end SQL analysis | MySQL 8.0+

   Purpose
   -------
   Analyze delivery performance, seller and geographic patterns, customer
   experience, product-category performance, and product value associated with
   delayed orders using the public Olist Brazilian e-commerce dataset.

   Source tables expected in database `olist_analytics`:
   orders, customers, order_items, order_payments, order_reviews, products,
   sellers, geolocation, category_translation.

   IMPORTANT EXECUTION NOTES
   -------------------------
   1. Import all nine source tables before running this script.
   2. Run Sections 00-02 first. Section 02 adds normalized DATETIME columns.
      If those five columns already exist, skip only the ALTER TABLE statement
      and run the UPDATE/validation statements that follow it.
   3. The script does not overwrite the original date fields. It fills separate
      *_dt columns and supports both the original D-M-Y text format and ISO text.
   4. Run view-creation sections after date conversion is complete.
   5. Diagnostic SELECT statements are safe to rerun. CREATE OR REPLACE VIEW
      statements replace the corresponding analytical views.
   6. Do not upload raw customer-level data or credentials to the repository.

   Metric conventions
   ------------------
   - Analysis population: delivered orders with valid delivered_dt and
     estimated_dt (the qualifying delivered-order population).
   - Late order: delivered_dt > estimated_dt.
   - Severe delay: more than 7 calendar days after estimated_dt.
   - Product value: SUM(order_items.price), excluding freight.
   - Low rating: average order review score <= 2; only orders with reviews are
     included in the low-rating denominator.
   - Seller-associated and category-level order totals can overlap across
     sellers/categories when one order contains multiple sellers/categories.

   Interpretation cautions
   -----------------------
   This is observational data. Findings show associations and patterns, not
   causality. Product value linked to late orders is revenue exposure, not
   proven lost revenue. Customer state is destination geography, not the cause
   or origin of a delivery delay.
   ============================================================================ */

/* ============================================================================
   00. DATABASE SELECTION AND SOURCE TABLE CHECK
   ============================================================================ */
CREATE DATABASE IF NOT EXISTS olist_analytics;
USE olist_analytics;

SELECT DATABASE() AS active_database;
SHOW TABLES;

/* ============================================================================
   01. INITIAL DATA PROFILING AND RELATIONSHIP CHECKS
   ============================================================================ */

-- 01A. Row counts across the nine imported source tables.
SELECT 'orders' AS table_name, COUNT(*) AS total_records FROM orders
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation;

-- 01B. Uniqueness checks for important identifiers.
SELECT 'orders.order_id' AS identifier,
       COUNT(*) AS total_rows,
       COUNT(DISTINCT order_id) AS unique_values
FROM orders
UNION ALL
SELECT 'customers.customer_id', COUNT(*), COUNT(DISTINCT customer_id)
FROM customers
UNION ALL
SELECT 'products.product_id', COUNT(*), COUNT(DISTINCT product_id)
FROM products
UNION ALL
SELECT 'sellers.seller_id', COUNT(*), COUNT(DISTINCT seller_id)
FROM sellers
UNION ALL
SELECT 'customers.customer_unique_id', COUNT(*),
       COUNT(DISTINCT customer_unique_id)
FROM customers;

-- 01C. Foreign-key-style orphan checks across the available source tables.
SELECT 'orders -> customers' AS relationship, COUNT(*) AS unmatched_records
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'order_items -> orders', COUNT(*)
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_items -> products', COUNT(*)
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'order_items -> sellers', COUNT(*)
FROM order_items oi
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL
UNION ALL
SELECT 'order_payments -> orders', COUNT(*)
FROM order_payments op
LEFT JOIN orders o ON op.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_reviews -> orders', COUNT(*)
FROM order_reviews r
LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

/* ============================================================================
   02. DATA QUALITY CHECKS AND DATE STANDARDIZATION
   ============================================================================ */

-- 02A. Review data quality. Do not deduplicate on review_id alone:
--      repeated review IDs and multiple reviews per order exist in this source.
SELECT
    COUNT(*) AS total_review_records,
    COUNT(DISTINCT review_id) AS unique_review_ids,
    COUNT(DISTINCT order_id) AS orders_with_reviews,
    SUM(CASE WHEN review_score NOT BETWEEN 1 AND 5 THEN 1 ELSE 0 END)
        AS invalid_scores,
    SUM(CASE WHEN review_comment_title IS NULL THEN 1 ELSE 0 END)
        AS missing_titles,
    SUM(CASE WHEN review_comment_message IS NULL THEN 1 ELSE 0 END)
        AS missing_messages
FROM order_reviews;

-- Review IDs that appear more than once.
SELECT review_id, COUNT(*) AS occurrences
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 15;

-- Multiple reviews per order and whether their scores conflict.
SELECT
    COUNT(*) AS orders_with_multiple_reviews,
    SUM(CASE WHEN min_score <> max_score THEN 1 ELSE 0 END)
        AS orders_with_conflicting_scores
FROM (
    SELECT order_id,
           MIN(review_score) AS min_score,
           MAX(review_score) AS max_score
    FROM order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) review_summary;

-- 02B. Inspect source date fields and the expected conversion format.
DESCRIBE orders;
SELECT
    order_purchase_timestamp AS original_value,
    COALESCE(
        STR_TO_DATE(NULLIF(TRIM(CAST(order_purchase_timestamp AS CHAR)), ''),
                    '%d-%m-%Y %H:%i'),
        STR_TO_DATE(NULLIF(TRIM(CAST(order_purchase_timestamp AS CHAR)), ''),
                    '%Y-%m-%d %H:%i:%s'),
        STR_TO_DATE(NULLIF(TRIM(CAST(order_purchase_timestamp AS CHAR)), ''),
                    '%Y-%m-%d %H:%i')
    ) AS converted_value
FROM orders
WHERE order_purchase_timestamp IS NOT NULL
LIMIT 10;

-- 02C. ONE-TIME DDL: add normalized DATETIME columns.
--      If these columns already exist, skip this ALTER TABLE statement.
ALTER TABLE orders
    ADD COLUMN purchase_dt DATETIME NULL,
    ADD COLUMN approved_dt DATETIME NULL,
    ADD COLUMN carrier_dt DATETIME NULL,
    ADD COLUMN delivered_dt DATETIME NULL,
    ADD COLUMN estimated_dt DATETIME NULL;

-- 02D. Populate normalized fields without modifying the imported source text.
--      COALESCE supports the source D-M-Y format and ISO text from a prior
--      conversion attempt. Blank strings are treated as NULL.
UPDATE orders
SET
    purchase_dt = COALESCE(
        STR_TO_DATE(NULLIF(TRIM(CAST(order_purchase_timestamp AS CHAR)), ''),
                    '%d-%m-%Y %H:%i'),
        STR_TO_DATE(NULLIF(TRIM(CAST(order_purchase_timestamp AS CHAR)), ''),
                    '%Y-%m-%d %H:%i:%s'),
        STR_TO_DATE(NULLIF(TRIM(CAST(order_purchase_timestamp AS CHAR)), ''),
                    '%Y-%m-%d %H:%i')
    ),
    approved_dt = COALESCE(
        STR_TO_DATE(NULLIF(TRIM(CAST(order_approved_at AS CHAR)), ''),
                    '%d-%m-%Y %H:%i'),
        STR_TO_DATE(NULLIF(TRIM(CAST(order_approved_at AS CHAR)), ''),
                    '%Y-%m-%d %H:%i:%s'),
        STR_TO_DATE(NULLIF(TRIM(CAST(order_approved_at AS CHAR)), ''),
                    '%Y-%m-%d %H:%i')
    ),
    carrier_dt = COALESCE(
        STR_TO_DATE(NULLIF(TRIM(CAST(order_delivered_carrier_date AS CHAR)), ''),
                    '%d-%m-%Y %H:%i'),
        STR_TO_DATE(NULLIF(TRIM(CAST(order_delivered_carrier_date AS CHAR)), ''),
                    '%Y-%m-%d %H:%i:%s'),
        STR_TO_DATE(NULLIF(TRIM(CAST(order_delivered_carrier_date AS CHAR)), ''),
                    '%Y-%m-%d %H:%i')
    ),
    delivered_dt = COALESCE(
        STR_TO_DATE(NULLIF(TRIM(CAST(order_delivered_customer_date AS CHAR)), ''),
                    '%d-%m-%Y %H:%i'),
        STR_TO_DATE(NULLIF(TRIM(CAST(order_delivered_customer_date AS CHAR)), ''),
                    '%Y-%m-%d %H:%i:%s'),
        STR_TO_DATE(NULLIF(TRIM(CAST(order_delivered_customer_date AS CHAR)), ''),
                    '%Y-%m-%d %H:%i')
    ),
    estimated_dt = COALESCE(
        STR_TO_DATE(NULLIF(TRIM(CAST(order_estimated_delivery_date AS CHAR)), ''),
                    '%d-%m-%Y %H:%i'),
        STR_TO_DATE(NULLIF(TRIM(CAST(order_estimated_delivery_date AS CHAR)), ''),
                    '%Y-%m-%d %H:%i:%s'),
        STR_TO_DATE(NULLIF(TRIM(CAST(order_estimated_delivery_date AS CHAR)), ''),
                    '%Y-%m-%d %H:%i')
    );

-- 02E. Check conversion failures. Non-empty source values should convert.
SELECT
    COUNT(*) AS total_orders,
    SUM(CASE WHEN NULLIF(TRIM(CAST(order_purchase_timestamp AS CHAR)), '')
                  IS NOT NULL AND purchase_dt IS NULL THEN 1 ELSE 0 END)
        AS failed_purchase_conversions,
    SUM(CASE WHEN NULLIF(TRIM(CAST(order_approved_at AS CHAR)), '')
                  IS NOT NULL AND approved_dt IS NULL THEN 1 ELSE 0 END)
        AS failed_approval_conversions,
    SUM(CASE WHEN NULLIF(TRIM(CAST(order_delivered_carrier_date AS CHAR)), '')
                  IS NOT NULL AND carrier_dt IS NULL THEN 1 ELSE 0 END)
        AS failed_carrier_conversions,
    SUM(CASE WHEN NULLIF(TRIM(CAST(order_delivered_customer_date AS CHAR)), '')
                  IS NOT NULL AND delivered_dt IS NULL THEN 1 ELSE 0 END)
        AS failed_delivery_conversions,
    SUM(CASE WHEN NULLIF(TRIM(CAST(order_estimated_delivery_date AS CHAR)), '')
                  IS NOT NULL AND estimated_dt IS NULL THEN 1 ELSE 0 END)
        AS failed_estimated_conversions
FROM orders;

-- 02F. Check chronological anomalies. Keep these records; do not delete them
--      without a separately justified data-quality rule.
SELECT
    SUM(CASE WHEN approved_dt < purchase_dt THEN 1 ELSE 0 END)
        AS approval_before_purchase,
    SUM(CASE WHEN carrier_dt < approved_dt THEN 1 ELSE 0 END)
        AS carrier_before_approval,
    SUM(CASE WHEN delivered_dt < carrier_dt THEN 1 ELSE 0 END)
        AS delivery_before_carrier,
    SUM(CASE WHEN delivered_dt < purchase_dt THEN 1 ELSE 0 END)
        AS delivery_before_purchase
FROM orders
WHERE order_status = 'delivered';

-- Inspect examples of chronology anomalies, if any.
SELECT order_id, purchase_dt, approved_dt, carrier_dt,
       delivered_dt, estimated_dt
FROM orders
WHERE order_status = 'delivered'
  AND (carrier_dt < approved_dt OR delivered_dt < carrier_dt
       OR delivered_dt < purchase_dt)
LIMIT 25;

/* ============================================================================
   03. MARKETPLACE DELIVERY BASELINE AND EXPLORATORY ANALYSIS
   ============================================================================ */

-- 03A. Overall delivered-order baseline.
SELECT
    COUNT(*) AS total_delivered_orders,
    SUM(CASE WHEN delivered_dt <= estimated_dt THEN 1 ELSE 0 END)
        AS on_time_orders,
    SUM(CASE WHEN delivered_dt > estimated_dt THEN 1 ELSE 0 END)
        AS late_orders,
    ROUND(100.0 * SUM(CASE WHEN delivered_dt > estimated_dt THEN 1 ELSE 0 END)
          / COUNT(*), 2) AS late_delivery_rate,
    ROUND(AVG(CASE WHEN delivered_dt > estimated_dt
                   THEN DATEDIFF(delivered_dt, estimated_dt) END), 2)
        AS avg_days_late,
    SUM(CASE WHEN DATEDIFF(delivered_dt, estimated_dt) > 7
             THEN 1 ELSE 0 END) AS severe_delay_orders
FROM orders
WHERE order_status = 'delivered'
  AND delivered_dt IS NOT NULL
  AND estimated_dt IS NOT NULL;

-- 03B. Seller-level exploratory ranking. Orders containing multiple sellers
--      appear against each associated seller; seller-level counts overlap.
SELECT
    oi.seller_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN o.delivered_dt > o.estimated_dt
                        THEN o.order_id END) AS late_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE
                    WHEN o.delivered_dt > o.estimated_dt THEN o.order_id END)
          / COUNT(DISTINCT o.order_id), 2) AS late_delivery_rate
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.delivered_dt IS NOT NULL
  AND o.estimated_dt IS NOT NULL
GROUP BY oi.seller_id
HAVING COUNT(DISTINCT o.order_id) >= 30
ORDER BY late_delivery_rate DESC
LIMIT 15;

-- Highest late-order volume by seller (same overlap interpretation).
SELECT
    oi.seller_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN o.delivered_dt > o.estimated_dt
                        THEN o.order_id END) AS late_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE
                    WHEN o.delivered_dt > o.estimated_dt THEN o.order_id END)
          / COUNT(DISTINCT o.order_id), 2) AS late_delivery_rate
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.delivered_dt IS NOT NULL
  AND o.estimated_dt IS NOT NULL
GROUP BY oi.seller_id
HAVING COUNT(DISTINCT o.order_id) >= 30
ORDER BY late_orders DESC
LIMIT 15;

-- 03C. Destination-state delivery performance.
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN o.delivered_dt > o.estimated_dt
                        THEN o.order_id END) AS late_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE
                    WHEN o.delivered_dt > o.estimated_dt THEN o.order_id END)
          / COUNT(DISTINCT o.order_id), 2) AS late_delivery_rate
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.delivered_dt IS NOT NULL
  AND o.estimated_dt IS NOT NULL
GROUP BY c.customer_state
ORDER BY late_delivery_rate DESC;

-- 03D. Customer experience by delivery status.
--      Reviews are aggregated to one row per order before joining.
SELECT
    CASE WHEN o.delivered_dt > o.estimated_dt THEN 'Late'
         ELSE 'On Time' END AS delivery_status,
    COUNT(*) AS reviewed_orders,
    ROUND(AVG(r.avg_review_score), 2) AS avg_review_score,
    ROUND(100.0 * SUM(CASE WHEN r.avg_review_score <= 2 THEN 1 ELSE 0 END)
          / COUNT(*), 2) AS low_rating_percentage
FROM orders o
JOIN (
    SELECT order_id, AVG(review_score) AS avg_review_score
    FROM order_reviews
    GROUP BY order_id
) r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.delivered_dt IS NOT NULL
  AND o.estimated_dt IS NOT NULL
GROUP BY delivery_status;

-- 03E. Product value and freight by delivery status.
--      Product value is based on item price; freight is shown separately.
SELECT
    CASE WHEN o.delivered_dt > o.estimated_dt THEN 'Late'
         ELSE 'On Time' END AS delivery_status,
    COUNT(*) AS total_orders,
    ROUND(SUM(i.product_value), 2) AS total_product_value,
    ROUND(SUM(i.freight_charges), 2) AS total_freight_charges,
    ROUND(AVG(i.product_value), 2) AS avg_product_value_per_order
FROM orders o
JOIN (
    SELECT order_id, SUM(price) AS product_value,
           SUM(freight_value) AS freight_charges
    FROM order_items
    GROUP BY order_id
) i ON o.order_id = i.order_id
WHERE o.order_status = 'delivered'
  AND o.delivered_dt IS NOT NULL
  AND o.estimated_dt IS NOT NULL
GROUP BY delivery_status;

-- 03F. Category-level delivery patterns. Orders with multiple categories
--      contribute to multiple category groups; category order counts overlap.
SELECT
    COALESCE(ct.product_category_name_english, 'Unknown') AS product_category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN o.delivered_dt > o.estimated_dt
                        THEN o.order_id END) AS late_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE
                    WHEN o.delivered_dt > o.estimated_dt THEN o.order_id END)
          / COUNT(DISTINCT o.order_id), 2) AS late_delivery_rate,
    ROUND(SUM(oi.price), 2) AS product_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_translation ct
    ON p.product_category_name = ct.`ï»¿product_category_name`
WHERE o.order_status = 'delivered'
  AND o.delivered_dt IS NOT NULL
  AND o.estimated_dt IS NOT NULL
GROUP BY COALESCE(ct.product_category_name_english, 'Unknown')
HAVING COUNT(DISTINCT o.order_id) >= 100
ORDER BY late_delivery_rate DESC;

-- 03G. Repeat-customer analysis by delivery experience.
--      Exploratory only: customers have differing numbers of orders/opportunities
--      to experience a late delivery, so this is not evidence of causal retention.
SELECT
    delivery_experience,
    COUNT(*) AS customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)
          / COUNT(*), 2) AS repeat_customer_rate
FROM (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        CASE WHEN MAX(CASE WHEN o.delivered_dt > o.estimated_dt
                           THEN 1 ELSE 0 END) = 1
             THEN 'Experienced Late Delivery'
             ELSE 'Only On-Time Deliveries' END AS delivery_experience
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.delivered_dt IS NOT NULL
      AND o.estimated_dt IS NOT NULL
    GROUP BY c.customer_unique_id
) customer_analysis
GROUP BY delivery_experience;

/* ============================================================================
   04. CORE ANALYTICAL VIEW: ORDER PERFORMANCE
   ============================================================================ */

CREATE OR REPLACE VIEW vw_order_performance AS
WITH item_summary AS (
    SELECT
        order_id,
        COUNT(*) AS total_items,
        COUNT(DISTINCT seller_id) AS total_sellers,
        SUM(price) AS product_value,
        SUM(freight_value) AS freight_charges
    FROM order_items
    GROUP BY order_id
),
review_summary AS (
    SELECT
        order_id,
        AVG(review_score) AS avg_review_score,
        COUNT(*) AS review_count
    FROM order_reviews
    GROUP BY order_id
),
customer_summary AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS delivered_order_count
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.delivered_dt IS NOT NULL
      AND o.estimated_dt IS NOT NULL
    GROUP BY c.customer_unique_id
)
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_state,
    o.purchase_dt,
    o.delivered_dt,
    o.estimated_dt,
    DATEDIFF(o.delivered_dt, o.purchase_dt) AS delivery_days,
    DATEDIFF(o.delivered_dt, o.estimated_dt) AS delay_days,
    CASE WHEN o.delivered_dt > o.estimated_dt THEN 1 ELSE 0 END AS is_late,
    CASE WHEN DATEDIFF(o.delivered_dt, o.estimated_dt) > 7
         THEN 1 ELSE 0 END AS is_severely_late,
    i.total_items,
    i.total_sellers,
    i.product_value,
    i.freight_charges,
    r.avg_review_score,
    r.review_count,
    CASE WHEN r.avg_review_score IS NULL THEN NULL
         WHEN r.avg_review_score <= 2 THEN 1 ELSE 0 END AS is_low_rating,
    cs.delivered_order_count,
    CASE WHEN cs.delivered_order_count > 1 THEN 1 ELSE 0 END
        AS is_repeat_customer
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN item_summary i ON o.order_id = i.order_id
LEFT JOIN review_summary r ON o.order_id = r.order_id
LEFT JOIN customer_summary cs ON c.customer_unique_id = cs.customer_unique_id
WHERE o.order_status = 'delivered'
  AND o.delivered_dt IS NOT NULL
  AND o.estimated_dt IS NOT NULL;

-- 04A. Validate the master view against the expected qualifying population.
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    SUM(is_late) AS late_orders,
    ROUND(AVG(is_late) * 100, 2) AS late_delivery_rate,
    ROUND(SUM(product_value), 2) AS total_product_value,
    ROUND(AVG(avg_review_score), 2) AS average_review_score
FROM vw_order_performance;

/* ============================================================================
   05. SELLER PERFORMANCE AND SELLER SEGMENTS
   ============================================================================ */

CREATE OR REPLACE VIEW vw_seller_performance AS
WITH seller_order_summary AS (
    SELECT
        seller_id,
        order_id,
        SUM(price) AS seller_product_value
    FROM order_items
    GROUP BY seller_id, order_id
),
review_summary AS (
    SELECT order_id, AVG(review_score) AS avg_review_score
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    so.seller_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN o.delivered_dt > o.estimated_dt
                        THEN o.order_id END) AS late_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE
                    WHEN o.delivered_dt > o.estimated_dt THEN o.order_id END)
          / COUNT(DISTINCT o.order_id), 2) AS late_delivery_rate,
    ROUND(SUM(so.seller_product_value), 2) AS product_value,
    ROUND(AVG(r.avg_review_score), 2) AS avg_review_score
FROM orders o
JOIN seller_order_summary so ON o.order_id = so.order_id
LEFT JOIN review_summary r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.delivered_dt IS NOT NULL
  AND o.estimated_dt IS NOT NULL
GROUP BY so.seller_id;

-- Number of sellers with qualifying delivered orders.
SELECT COUNT(*) AS qualifying_sellers
FROM vw_seller_performance;

-- Sellers excluded because they have no qualifying delivered orders.
SELECT COUNT(DISTINCT s.seller_id) AS sellers_without_qualifying_orders
FROM sellers s
WHERE NOT EXISTS (
    SELECT 1
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE oi.seller_id = s.seller_id
      AND o.order_status = 'delivered'
      AND o.delivered_dt IS NOT NULL
      AND o.estimated_dt IS NOT NULL
);

-- Seller segmentation: labels match the Power BI segment names.
-- Seller-associated order totals can exceed marketplace distinct order count
-- because an order can contain more than one seller.
CREATE OR REPLACE VIEW vw_seller_segment_summary AS
SELECT
    CASE WHEN total_orders < 20
         THEN 'Emerging Sellers (<20 Orders)'
         ELSE 'Higher-Volume Sellers (20+ Orders)' END AS seller_group,
    COUNT(DISTINCT seller_id) AS seller_count,
    SUM(total_orders) AS seller_associated_orders,
    ROUND(100.0 * SUM(total_orders) /
          SUM(SUM(total_orders)) OVER (), 2) AS order_volume_share_pct,
    ROUND(SUM(product_value), 2) AS seller_associated_product_value
FROM vw_seller_performance
GROUP BY CASE WHEN total_orders < 20
              THEN 'Emerging Sellers (<20 Orders)'
              ELSE 'Higher-Volume Sellers (20+ Orders)' END;

SELECT * FROM vw_seller_segment_summary;

/* ============================================================================
   06. GEOGRAPHIC PERFORMANCE
   ============================================================================ */

-- Item and review data are pre-aggregated to one row per order before joining.
-- This avoids multiplying order-level measures by the number of items.
CREATE OR REPLACE VIEW vw_geography_performance AS
WITH item_summary AS (
    SELECT order_id, SUM(price) AS product_value
    FROM order_items
    GROUP BY order_id
),
review_summary AS (
    SELECT order_id, AVG(review_score) AS avg_review_score
    FROM order_reviews
    GROUP BY order_id
)
SELECT
    c.customer_state,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN o.delivered_dt > o.estimated_dt THEN 1 ELSE 0 END)
        AS late_orders,
    ROUND(100.0 * SUM(CASE WHEN o.delivered_dt > o.estimated_dt
                           THEN 1 ELSE 0 END) / COUNT(*), 2)
        AS late_delivery_rate,
    ROUND(SUM(i.product_value), 2) AS product_value,
    ROUND(AVG(r.avg_review_score), 2) AS avg_review_score
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN item_summary i ON o.order_id = i.order_id
LEFT JOIN review_summary r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.delivered_dt IS NOT NULL
  AND o.estimated_dt IS NOT NULL
GROUP BY c.customer_state;

-- State-level reconciliation to the qualifying delivered-order baseline.
SELECT
    COUNT(*) AS total_states,
    SUM(total_orders) AS total_orders,
    SUM(late_orders) AS late_orders
FROM vw_geography_performance;

/* ============================================================================
   07. PRODUCT CATEGORY PERFORMANCE
   ============================================================================ */

CREATE OR REPLACE VIEW vw_category_performance AS
WITH category_orders AS (
    SELECT
        o.order_id,
        p.product_category_name,
        oi.price,
        o.delivered_dt,
        o.estimated_dt
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
      AND o.delivered_dt IS NOT NULL
      AND o.estimated_dt IS NOT NULL
),
category_translation_clean AS (
    SELECT
        `ï»¿product_category_name` AS category_name,
        product_category_name_english AS category_english
    FROM category_translation
)
SELECT
    COALESCE(ct.category_english, 'Unknown') AS product_category,
    COUNT(DISTINCT co.order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN co.delivered_dt > co.estimated_dt
                        THEN co.order_id END) AS late_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE
                    WHEN co.delivered_dt > co.estimated_dt THEN co.order_id END)
          / COUNT(DISTINCT co.order_id), 2) AS late_delivery_rate,
    ROUND(SUM(co.price), 2) AS product_value
FROM category_orders co
LEFT JOIN category_translation_clean ct
    ON co.product_category_name = ct.category_name
GROUP BY COALESCE(ct.category_english, 'Unknown');

-- Category totals are intentionally not expected to equal distinct marketplace
-- order counts: orders containing several categories appear in each category.
SELECT
    COUNT(*) AS total_categories,
    SUM(total_orders) AS category_order_counts,
    SUM(late_orders) AS category_late_order_counts,
    ROUND(SUM(product_value), 2) AS total_product_value
FROM vw_category_performance;

/* ============================================================================
   08. CUSTOMER EXPERIENCE AND RETENTION CHECKS FROM THE MASTER VIEW
   ============================================================================ */

-- Low-rating incidence by delivery status. The denominator excludes orders
-- without an available review, consistent with the project dashboard measure.
SELECT
    is_late,
    COUNT(DISTINCT order_id) AS reviewed_orders,
    COUNT(DISTINCT CASE WHEN avg_review_score <= 2 THEN order_id END)
        AS low_rated_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE
                    WHEN avg_review_score <= 2 THEN order_id END)
          / COUNT(DISTINCT order_id), 2) AS low_rating_share
FROM vw_order_performance
WHERE avg_review_score IS NOT NULL
GROUP BY is_late
ORDER BY is_late;

-- Review-score distribution.
SELECT
    avg_review_score,
    COUNT(DISTINCT order_id) AS order_count
FROM vw_order_performance
WHERE avg_review_score IS NOT NULL
GROUP BY avg_review_score
ORDER BY avg_review_score;

-- Customer repeat-purchase baseline using qualifying delivered orders.
SELECT
    COUNT(*) AS unique_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END)
          / COUNT(*), 2) AS repeat_customer_rate
FROM (
    SELECT c.customer_unique_id,
           COUNT(DISTINCT o.order_id) AS order_count
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.delivered_dt IS NOT NULL
      AND o.estimated_dt IS NOT NULL
    GROUP BY c.customer_unique_id
) customer_orders;

/* ============================================================================
   09. FINAL VIEW INVENTORY AND QUICK VALIDATION
   ============================================================================ */

SHOW FULL TABLES
FROM olist_analytics
WHERE Table_type = 'VIEW';

SELECT * FROM vw_order_performance LIMIT 10;
SELECT * FROM vw_seller_performance LIMIT 10;
SELECT * FROM vw_seller_segment_summary;
SELECT * FROM vw_geography_performance ORDER BY late_delivery_rate DESC;
SELECT * FROM vw_category_performance ORDER BY late_delivery_rate DESC LIMIT 20;

-- Optional: inspect the final seller-segment view definition.
SHOW CREATE VIEW vw_seller_segment_summary;

/* ============================================================================
   END OF SCRIPT

   Removed from the working version:
   - Repeated exploratory queries that produced identical results.
   - Earlier draft versions of vw_geography_performance that joined order_items
     directly and could multiply order-level review metrics.
   - Earlier draft seller-segment labels superseded by the final labels.
   - A later self-referencing CREATE OR REPLACE VIEW attempt for
     vw_seller_segment_summary; it was not a valid final view definition.
   - An UPDATE that rewrote the original text date columns before parsing them
     again. The final approach preserves raw fields and uses *_dt columns.
   ============================================================================ */
