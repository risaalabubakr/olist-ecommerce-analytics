# SQL analysis

**Main script:** [Olist_Analytics.sql](./Olist_Analytics.sql)

The script is written for MySQL 8.0+ and organized into numbered sections:

1. Database selection and source-table checks
2. Initial profiling and relationship checks
3. Data-quality checks and date standardization
4. Marketplace delivery baseline and exploratory checks
5. Core order-performance view
6. Seller performance and seller segments
7. Geographic performance
8. Product-category performance
9. Customer experience and exploratory repeat-purchase checks
10. Final view inventory and validation queries

## Before running

1. Download and import all nine Olist source tables into the `olist_analytics` database.
2. Review the execution notes at the top of the SQL script.
3. Run the script sequentially in MySQL Workbench or another MySQL 8.0+ client.
4. The date-standardization section adds five normalized DATETIME columns to `orders`. This ALTER TABLE operation is one-time: if those columns already exist, skip that ALTER TABLE statement and continue with the UPDATE and validation statements.
5. Confirm the conversion checks and qualifying-order baseline before relying on downstream views.

The script preserves the imported date text columns and uses separate `*_dt` columns for analysis. CREATE OR REPLACE VIEW statements can be rerun.

## Analytical views

- `vw_order_performance`: one row per qualifying delivered order, with delivery, product-value and order-level review measures.
- `vw_seller_performance`: seller-associated order and product-value metrics.
- `vw_seller_segment_summary`: seller counts and volume share for the under-20 and 20-or-more order segments.
- `vw_geography_performance`: delivery and review patterns by customer destination state.
- `vw_category_performance`: delivery and product-value patterns by translated product category.

## Interpretation notes

- The qualifying population is delivered orders with valid delivered and estimated timestamps.
- Product value is based on `order_items.price` and excludes freight.
- Seller- and category-level order counts can overlap because one order may contain multiple sellers or categories.
- The analysis is observational and does not establish that a seller, category or destination caused a delay.
