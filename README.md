# sql-loan-geo-data-warehouse

Building a data warehouse with **SQL Server** to analyze loan data by **geography (US state)**, including ETL process, data modeling, and analytics.
Follows the same Medallion Architecture and project structure.

---

## 🏗️ Data Architecture

Medallion Architecture — **Bronze**, **Silver**, **Gold** (details in [docs/data_architecture.md](docs/data_architecture.md)):

1. **Bronze Layer**: Raw data as-is from CSV files, loaded with `BULK INSERT`.
2. **Silver Layer**: Data cleansing, type casting, deduplication and standardization (e.g. `loan_status`, `zip_code`, `addr_state`).
3. **Gold Layer**: Dimensional model — `geography_dim`, `loan_status_dim`, `loans_geo_fact` — plus the report view `report_loan_by_state`.

---

## 🎯 Business Questions (Topic 4: Geographic Dimension)

Use case: **Descriptive Analytics** · Model: **Dimensional model for Data Warehouse**

| # | Question | Source column | Gold metric |
|---|----------|---------------|-------------|
| 4.1 | Total loan amount by state | `loan_amnt`, `addr_state` | `total_loan_amnt` |
| 4.2 | Average annual income of borrowers by state | `annual_inc`, `addr_state` | `avg_annual_inc` |
| 4.3 | Number of Charged Off loans by state | `loan_status`, `addr_state` | `charged_off_loans` |

![Data Model](docs/data_model.png)

```sql
SELECT addr_state, region, total_loan_amnt, avg_annual_inc, charged_off_loans
FROM gold.report_loan_by_state
ORDER BY total_loan_amnt DESC;
```

---

## 🚀 Project Requirements

- **Data Sources**: Loan data (`source_lending`) and a US state reference list (`source_ref`), as CSV files.
- **Data Quality**: Cleanse invalid values (non-numeric amounts, income ≤ 0, inconsistent status labels) before analysis.
- **Integration**: Build a geographic dimension (zip_code → state → region) and a loan status dimension around one loan fact table.
- **Scope**: Latest dataset only; no historization.
- **Documentation**: Data catalog and naming conventions in `docs/`.

---

## ▶️ How to Run

1. Put the loan file at `datasets/source_lending/loan_data.csv` (see the folder README for the required header).
2. Run in SQL Server Management Studio, in order:

```sql
-- 1. Setup
scripts/init_database.sql
-- 2. Bronze
scripts/bronze/ddl_bronze.sql
scripts/bronze/proc_load_bronze.sql
EXEC bronze.load_bronze @base_path = 'C:\<your-path>\sql-loan-geo-data-warehouse\datasets\';
-- 3. Silver
scripts/silver/ddl_silver.sql
scripts/silver/proc_load_silver.sql
EXEC silver.load_silver;
tests/quality_checks_silver.sql
-- 4. Gold
scripts/gold/ddl_gold.sql
tests/quality_checks_gold.sql
```

3. (Optional) See what each step does to the data — **before vs after**, step by step.
   These scripts only run `SELECT` (no data is changed). Highlight one STEP and run it, or run the whole file:

```sql
scripts/bronze/walkthrough_bronze.sql   -- CSV -> bronze (raw, all NVARCHAR)
scripts/silver/walkthrough_silver.sql   -- bronze -> silver (each cleansing rule, before vs after)
scripts/gold/walkthrough_gold.sql       -- silver -> star schema -> report (4.1 / 4.2 / 4.3)
```

Requires SQL Server 2017+ (for `BULK INSERT ... FORMAT = 'CSV'` and `TRIM`).

---

## 📂 Repository Structure

```
sql-loan-geo-data-warehouse/
│
├── datasets/
│   ├── source_lending/              # loan_data.csv (raw loan contracts)
│   └── source_ref/                  # us_states.csv (state → division → region)
│
├── docs/
│   ├── data_architecture.md         # Architecture, data flow and star schema diagrams
│   ├── data_catalog.md              # Gold layer column descriptions
│   ├── data_model.png               # Dimensional model (star schema)
│   └── naming_conventions.md        # Naming rules for tables, columns, procedures
│
├── scripts/
│   ├── init_database.sql            # Create database LoanGeoDW + schemas
│   ├── bronze/                      # DDL + load_bronze procedure + walkthrough (before vs after)
│   ├── silver/                      # DDL + load_silver procedure + walkthrough (before vs after)
│   └── gold/                        # star schema views, report view + walkthrough (before vs after)
│
├── tests/
│   ├── quality_checks_silver.sql
│   └── quality_checks_gold.sql
│
├── README.md
├── LICENSE
└── .gitignore
```

---

## 🛡️ License

This project is licensed under the [MIT License](LICENSE).
