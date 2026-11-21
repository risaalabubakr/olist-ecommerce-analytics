# Power BI dashboard

The final report is available as [Olist_Dashboard.pbix](./Olist_Dashboard.pbix).

## Report pages

1. **Executive Overview** — delivery baseline, product value, average rating, severe delays, destination-state comparison and monthly late-delivery trend.
2. **Seller Performance** — seller population and segments, top sellers by late-delivery rate and late-order volume, with volume context.
3. **Customer Experience** — review-score comparison and low-rating incidence by delivery status.

## Data and interpretation

The report is based on the qualifying delivered-order population defined in the KPI Dictionary. Review-based measures use orders with available reviews. The late-order product-value measure uses item price and excludes freight; it is exposure associated with late orders, not demonstrated lost revenue.

The seller and category views can contain overlapping order counts because an order can involve multiple sellers or categories. The dashboard should therefore not be interpreted by summing seller/category order counts to obtain marketplace totals.

The screenshots in the repository's images folder are static previews. Use the PBIX file for the interactive report. Do not include private credentials or connection strings in the report or repository.
