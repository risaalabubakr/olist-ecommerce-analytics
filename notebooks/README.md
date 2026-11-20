# Python notebooks

The notebooks document the initial data understanding and source-table validation work. Run them in this order:

| Order | Notebook | Purpose |
|---|---|---|
| 01 | [Dataset Audit](./01_dataset_audit.ipynb) | Inspect all nine source tables, schema, row counts, missing values, duplicate rows and export audit summaries. |
| 02 | [Primary Key and Identifier Analysis](./02_primary_key_identifier_analysis.ipynb) | Profile candidate identifiers using uniqueness, null and duplicate metrics. |
| 03 | [Foreign Key and Relationship Analysis](./03_foreign_key_relationship_analysis.ipynb) | Check key relationships between tables and inspect geography/category mapping gaps. |

## Setup

- Use Python 3 with pandas and NumPy.
- Download the Olist CSV files separately; raw data is not committed to this repository.
- By default, notebooks expect the CSVs in `data/raw/` relative to the project root.
- Alternatively, set the `OLIST_DATA_DIR` environment variable to the folder containing the CSVs.
- Run Jupyter from either the project root or the `notebooks/` folder.

## Scope note

A separate local MySQL troubleshooting notebook used during initial table loading is intentionally not part of the reproducible analysis sequence. It contained table-replacement commands (`TRUNCATE TABLE` and `DROP TABLE`) and should not be run as a general-purpose analysis notebook without reviewing and adapting those operations first.
