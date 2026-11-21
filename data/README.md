# Dataset

This project uses the public **Brazilian E-Commerce Public Dataset by Olist** (2016–2018).

**Source:** [Olist Brazilian E-Commerce Public Dataset on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

The source download contains nine CSV tables:

| CSV table | Description |
|---|---|
| olist_orders_dataset.csv | Order status and key order timestamps |
| olist_customers_dataset.csv | Customer identifiers and destination geography |
| olist_order_items_dataset.csv | Products, sellers, item prices and freight by order |
| olist_order_payments_dataset.csv | Payment type, installments and payment values |
| olist_order_reviews_dataset.csv | Customer review scores and comments |
| olist_products_dataset.csv | Product attributes and category keys |
| olist_sellers_dataset.csv | Seller identifiers and location |
| olist_geolocation_dataset.csv | Zip-code-prefix latitude/longitude reference |
| product_category_name_translation.csv | Portuguese-to-English category translation |

## Local folder setup

After downloading and extracting the dataset, place the nine CSV files in `data/raw/` at the repository root. The Python notebooks expect the original filenames listed above.

Raw CSVs are not committed to this repository. Download them from the source above and keep them locally in `data/raw/`. The notebooks also support a custom folder through the `OLIST_DATA_DIR` environment variable.

See [the project setup guide](../docs/PROJECT_SETUP.md) for the Python and MySQL workflow.
