# SQL analysis

**Main script:** [Olist_Analytics.sql](./Olist_Analytics.sql)

The script is organized into numbered sections:

1. Database selection and source-table check
2. Initial data profiling and relationship checks
3. Data-quality checks and date standardization
4. Marketplace delivery baseline and exploratory analysis
5. Core order-performance view
6. Seller performance and seller segments
7. Geographic performance
8. Product-category performance
9. Customer experience and retention checks
10. Final view inventory and quick validation

## Requirements and execution notes

- MySQL 8.0+ is recommended.
- Import the nine original Olist CSV source tables into the `olist_analytics` database before running the analysis.
- Read the execution notes at the top of the SQL script before running it.
- The script adds normalized `*_dt` date columns. If those columns already exist, skip the one-time `ALTER TABLE` statement.
- Seller- and category-level order counts may overlap when an order contains multiple sellers or categories.
- Results are observational and should not be interpreted as proof of causation.
