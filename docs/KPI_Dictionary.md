# KPI Dictionary

This document defines the principal metrics used in the Olist analysis and Power BI report. Keep the population and denominator attached to each percentage when interpreting results.

## Analysis population

**Qualifying delivered orders:** orders where `order_status = 'delivered'` and both `delivered_dt` and `estimated_dt` are valid (non-null).

The reported baseline contains 96,470 qualifying delivered orders. Orders without a valid actual or estimated delivery timestamp are excluded from delivery-rate calculations.

## Delivery metrics

| KPI | Definition | Denominator / notes |
|---|---|---|
| Total qualifying delivered orders | Count of distinct order_id in the qualifying population | 96,470 in the reported baseline |
| On-time orders | delivered_dt is on or before estimated_dt | Qualifying delivered orders |
| On-time delivery rate | On-time orders / qualifying delivered orders | 88,644 / 96,470 = 91.89% |
| Late orders | delivered_dt is after estimated_dt | Qualifying delivered orders |
| Late-delivery rate | Late orders / qualifying delivered orders | 7,826 / 96,470 = 8.11% |
| Severe-delay orders | delivered_dt is more than 7 calendar days after estimated_dt | Severe-delay count; threshold is strictly greater than 7 days |
| Delivery days | Calendar-day difference between delivered_dt and purchase_dt | Calculated with DATEDIFF |

## Product-value metrics

| KPI | Definition | Denominator / notes |
|---|---|---|
| Product value | Sum of order_items.price | Excludes freight_value |
| Late-order product value | Sum of item price for qualifying late orders | Product value associated with late orders; not proven lost revenue |
| Late-order product-value share | Late-order product value / total qualifying product value | 8.77% in the reported baseline |

Reported values: total product value R$13,220,248.93; late-order product value R$1,158,920.51.

## Customer-experience metrics

| KPI | Definition | Denominator / notes |
|---|---|---|
| Average review score | Average order-level review score | Review records are first aggregated to order level; only orders with a score contribute |
| Average score — on time | Mean order-level score for on-time orders | Reviewed qualifying orders only |
| Average score — late | Mean order-level score for late orders | Reviewed qualifying orders only |
| Low rating | Order-level average review score is less than or equal to 2 | Review threshold is 2 or below |
| Low-rating share | Reviewed orders with order-level average score <= 2 / all reviewed qualifying orders in the delivery-status group | Missing ratings are excluded, not treated as low ratings |

Reported average score: 4.16 overall, 4.29 on-time and 2.57 late. Low-rating share: 9.19% on-time and 53.99% late.

## Seller metrics

| KPI | Definition | Denominator / notes |
|---|---|---|
| Qualifying sellers | Sellers with at least one order in the qualifying delivered-order population | 2,970 in the reported baseline |
| Emerging seller | Seller with fewer than 20 qualifying seller-associated orders | Project-defined segmentation threshold |
| Higher-volume seller | Seller with 20 or more qualifying seller-associated orders | Project-defined segmentation threshold |
| Seller late-delivery rate | Seller-associated late distinct orders / seller-associated qualifying distinct orders | A single marketplace order may be associated with multiple sellers |

Seller-associated order totals can overlap when one order contains items from more than one seller. Do not add seller-level order counts to calculate marketplace orders.

## Customer repeat-purchase metric

A repeat customer is a customer_unique_id with more than one distinct qualifying delivered order in the analysis population. The repeat-purchase analysis is exploratory because repeat buyers are relatively uncommon in this dataset and customers with more orders have more opportunities to experience a late delivery.

## General interpretation rules

- The analysis is observational and does not establish causality.
- Customer state is the delivery destination state.
- Category-level order counts can overlap when an order contains items from multiple categories.
- Review-based measures exclude orders without available reviews.
- Product value uses item price and excludes freight.
- Reported late-order product value is exposure associated with delayed orders, not demonstrated lost revenue.
