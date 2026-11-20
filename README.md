# Olist E-commerce Operational Performance & Customer Experience Analytics

An end-to-end business analytics project using the Olist Brazilian e-commerce dataset to investigate delivery performance, customer experience, seller and category patterns, and product value associated with delayed orders.

## Business question

How can an e-commerce marketplace improve delivery reliability and customer experience while reducing operational inefficiencies and protecting revenue?

## Project objectives

- Establish a baseline for delivery performance.
- Identify delivery patterns across time, customer destination states, sellers and product categories.
- Examine the relationship between delivery status and customer review scores.
- Quantify the product value associated with delayed orders.
- Recommend practical operational actions and monitoring KPIs.

## Dataset

The project uses the public Olist Brazilian e-commerce dataset (2016–2018), integrating nine source tables: orders, customers, order items, order payments, order reviews, products, sellers, geolocation and category translation.

See [data/README.md](./data/README.md) for the source link, table descriptions and local folder setup. Raw CSV files are not committed to this repository.

## Tools and methodology

**Tools:** MySQL, SQL, Python, pandas, NumPy, Power BI

**Methodology:** Lean Six Sigma DMAIC

| DMAIC phase | How it is applied |
|---|---|
| **Define** | Frame late delivery as the operational problem and establish objectives, scope and exclusions. |
| **Measure** | Establish baseline metrics for delivery, severe delays, customer ratings and product value associated with late orders. |
| **Analyze** | Examine patterns across time, destination states, sellers and categories; compare customer ratings by delivery status. |
| **Improve** | Propose seller monitoring, severe-delay intervention, geographic investigation and proactive customer communication. |
| **Control** | Define recurring monitoring of late deliveries, severe delays, customer ratings and seller-level performance. |

## Project workflow

1. **Python data understanding:** Audit source tables, profile identifier candidates, and check table relationships.
2. **SQL analysis:** Prepare date fields, validate data quality, establish delivery baselines, and create analytical views.
3. **Power BI reporting:** Present executive, seller-performance and customer-experience findings in an interactive three-page dashboard.
4. **DMAIC recommendations:** Translate descriptive findings into operational recommendations and proposed monitoring metrics.

## Key results

| Metric | Result |
|---|---:|
| Qualifying delivered orders | 96,470 |
| On-time orders | 88,644 (91.89%) |
| Late orders | 7,826 (8.11%) |
| Severe delays (more than 7 days) | 2,862 |
| Total product value | R$13,220,248.93 |
| Product value associated with late orders | R$1,158,920.51 (8.77%) |
| Average review score | 4.16 / 5 |
| Qualifying sellers | 2,970 |

## Main findings

- Late orders represented 8.11% of qualifying delivered orders.
- Product value associated with late orders was approximately R$1.16 million (8.77% of total product value). This is **revenue exposure**, not demonstrated lost revenue.
- Average review scores were 4.29 for on-time orders and 2.57 for late orders.
- Low-rating incidence (review score of 2 or below) was 9.19% for on-time orders and 53.99% for late orders.
- Delivery performance varied across destination states, sellers and product categories.

## Recommendations

1. Prioritize investigation and intervention for severe delays.
2. Monitor seller performance using both late-delivery rate and order volume.
3. Investigate geographic and category-level delivery patterns.
4. Improve proactive customer communication for at-risk deliveries.
5. Track late-delivery rate, severe-delay rate and customer ratings over time.

## Project report

Read the [one-page DMAIC project summary](./reports/Olist_Project_Summary.pdf) for the problem statement, methodology, key metrics, findings, recommendations and limitations.

## Repository structure

```text
olist-ecommerce-analytics/
├── README.md
├── data/
│   └── README.md
├── notebooks/
│   ├── README.md
│   ├── 01_dataset_audit.ipynb
│   ├── 02_primary_key_identifier_analysis.ipynb
│   └── 03_foreign_key_relationship_analysis.ipynb
├── sql/
│   ├── README.md
│   └── Olist_Analytics.sql
├── powerbi/
│   └── README.md
├── images/
│   └── README.md
└── reports/
    ├── README.md
    └── Olist_Project_Summary.pdf
```

## How to run the Python notebooks

Run the notebooks in the order listed in [notebooks/README.md](./notebooks/README.md). Download the Olist CSV files separately and place them in `data/raw/`, or set the `OLIST_DATA_DIR` environment variable to your local dataset folder.

## Limitations and interpretation

- The dataset is observational; associations do not establish causation.
- It does not provide detailed courier tracking, logistics costs or inventory history.
- Customer ratings are not available for every order.
- Repeat purchasing is uncommon in the dataset, so retention findings are exploratory.
- Customer state represents delivery destination geography, not the origin or cause of a delay.
- Product value associated with delayed orders should not be described as actual lost revenue.

## Metric definitions

- **Late order:** delivered after the estimated delivery date.
- **Severe delay:** more than 7 days late.
- **Product value:** item price (product revenue basis), excluding freight.
- Percentages use their stated qualifying-order or product-value denominators.

---

*Project results are based on the analysis documented in the SQL and Python files. The one-page project summary is available in `reports/`. The Power BI dashboard file and visual previews are not yet published in this repository.*
