# Python notebooks

The notebooks document the initial data-understanding and source-table validation work. Run them in this order:

| Order | Notebook | Purpose |
|---|---|---|
| 01 | [Dataset Audit](./01_dataset_audit.ipynb) | Inspect the nine source tables, schema, row counts, missing values, duplicate rows and export audit summaries. |
| 02 | [Primary Key and Identifier Analysis](./02_primary_key_identifier_analysis.ipynb) | Profile single-column identifiers and test expected composite keys at the relevant table grain. |
| 03 | [Foreign Key and Relationship Analysis](./03_foreign_key_relationship_analysis.ipynb) | Check child-to-parent relationships and distinguish missing values from non-null unmatched geography/category values. |

## Setup

- Use Python 3.10 or later.
- Install dependencies from the repository root with: `python -m pip install -r requirements.txt`.
- Download the nine Olist CSV source files separately; raw data is not committed.
- By default, the notebooks expect the CSVs in `data/raw/` relative to the repository root.
- Alternatively, set the `OLIST_DATA_DIR` environment variable to the folder containing the nine CSV files.
- Start Jupyter from the repository root with: `jupyter lab`.

## Outputs

Notebook 01 exports its dataset and missing-value summaries to `data/processed/`. Keep generated audit files local unless there is a specific reason to publish a sanitized, aggregated result.

## Scope note

A separate local MySQL troubleshooting notebook used during initial table loading is intentionally excluded from the reproducible analysis sequence. It contained table-replacement commands (`TRUNCATE TABLE` and `DROP TABLE`) and should not be run as a general-purpose analysis notebook without reviewing those operations.
