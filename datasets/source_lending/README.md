# source_lending

`loan_data.csv` — Lending Club loan sample (LoanStats), 1,000 loans × 144 columns, issued 2016.

- Encoding: UTF-8 with BOM, CRLF line endings
- Column `id` is empty in this public extract → silver generates a surrogate `loan_id`
- Columns used in the Gold data model: `loan_amnt`, `funded_amnt`, `annual_inc`, `loan_status`, `zip_code`, `addr_state`

`scripts/bronze/ddl_bronze.sql` mirrors all 144 columns in header order (BULK INSERT maps by position).
