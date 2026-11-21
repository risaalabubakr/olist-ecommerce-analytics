# Project setup and reproduction guide

This guide explains how to reproduce the data-audit and SQL workflow locally. The Olist raw CSV files are not included in this repository and must be downloaded separately.

## 1. Download and organize the data

Download the [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and extract the nine CSV files into the following local folder:

- `data/raw/olist_orders_dataset.csv`
- `data/raw/olist_customers_dataset.csv`
- `data/raw/olist_order_items_dataset.csv`
- `data/raw/olist_order_payments_dataset.csv`
- `data/raw/olist_order_reviews_dataset.csv`
- `data/raw/olist_products_dataset.csv`
- `data/raw/olist_sellers_dataset.csv`
- `data/raw/olist_geolocation_dataset.csv`
- `data/raw/product_category_name_translation.csv`

Do not commit the raw CSVs. The notebooks also support a custom data location through the `OLIST_DATA_DIR` environment variable.

## 2. Prepare Python

Use Python 3.10 or later. From the repository root, create and activate a virtual environment if desired, then install the declared dependencies:

```bash
python -m venv .venv
```

Windows PowerShell:

```powershell
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
jupyter lab
```

macOS / Linux:

```bash
source .venv/bin/activate
python -m pip install -r requirements.txt
jupyter lab
```

Run the notebooks in this order:

1. `notebooks/01_dataset_audit.ipynb`
2. `notebooks/02_primary_key_identifier_analysis.ipynb`
3. `notebooks/03_foreign_key_relationship_analysis.ipynb`

Notebook 01 writes audit summaries under `data/processed/`. These are local generated outputs and are not required for the SQL script.

## 3. Prepare MySQL

Use MySQL 8.0 or later. Create/import the nine source tables in the `olist_analytics` database. The SQL script expects these table names:

- `orders`
- `customers`
- `order_items`
- `order_payments`
- `order_reviews`
- `products`
- `sellers`
- `geolocation`
- `category_translation`

The source CSV file names are documented in [data/README.md](../data/README.md). When importing, make sure the column names are preserved so they match the SQL script.

## 4. Run the SQL analysis

Open `sql/Olist_Analytics.sql` in MySQL Workbench or another MySQL 8.0+ client and execute it sequentially.

Important: Section 02 contains a one-time ALTER TABLE statement that adds five normalized date columns to `orders`. If `purchase_dt`, `approved_dt`, `carrier_dt`, `delivered_dt` and `estimated_dt` already exist, skip that ALTER TABLE statement on subsequent runs. Continue with the date-population UPDATE and validation queries. The original imported timestamp columns are preserved.

After successful date conversion, the remaining sections create or replace the analytical views and run validation queries. Review the output of the conversion checks and baseline reconciliation before using the results.

## 5. Explore the Power BI report

Open [powerbi/Olist_Dashboard.pbix](../powerbi/Olist_Dashboard.pbix) in Power BI Desktop. The three report pages are Executive Overview, Seller Performance Analysis and Customer Experience Analysis. Static screenshots in `images/` are provided for preview.

If you rebuild or refresh the report from a new local database connection, update the data-source settings in Power BI Desktop. Do not publish credentials or connection strings.

## Reproducibility note

The repository contains the analysis scripts and report, but the raw dataset and local MySQL database are external prerequisites. The Python notebooks and SQL script should be executed in the environment described above to independently reproduce the underlying outputs.
