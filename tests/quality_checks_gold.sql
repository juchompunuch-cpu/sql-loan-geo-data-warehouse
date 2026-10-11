/*
===============================================================================
Quality Checks: Gold Layer
===============================================================================
Script Purpose:
    Validates integrity, consistency and accuracy of the Gold layer:
    - Uniqueness of surrogate keys and business keys in dimensions
    - Referential integrity between fact and dimensions
    - Report totals reconcile with fact / silver totals

Usage:
    Run after creating the gold views.
    Expectation for each query: NO ROWS returned (unless noted).
===============================================================================
*/

-- ====================================================================
-- gold.geography_dim
-- ====================================================================
-- 1) Uniqueness of geography_id
SELECT geography_id, COUNT(*) AS cnt
FROM gold.geography_dim
GROUP BY geography_id
HAVING COUNT(*) > 1;

-- 2) Uniqueness of business key (zip_code + addr_state)
SELECT zip_code, addr_state, COUNT(*) AS cnt
FROM gold.geography_dim
GROUP BY zip_code, addr_state
HAVING COUNT(*) > 1;

-- 3) States missing from reference list (INFO - fix us_states.csv if any)
SELECT DISTINCT addr_state
FROM gold.geography_dim
WHERE region = 'n/a';

-- ====================================================================
-- gold.loan_status_dim
-- ====================================================================
-- 4) Uniqueness of loan_status_id and loan_status
SELECT loan_status_id, COUNT(*) AS cnt
FROM gold.loan_status_dim
GROUP BY loan_status_id
HAVING COUNT(*) > 1;

SELECT loan_status, COUNT(*) AS cnt
FROM gold.loan_status_dim
GROUP BY loan_status
HAVING COUNT(*) > 1;

-- ====================================================================
-- gold.loans_geo_fact
-- ====================================================================
-- 5) Referential integrity: every fact row links to both dimensions
SELECT *
FROM gold.loans_geo_fact
WHERE geography_id IS NULL OR loan_status_id IS NULL;

-- 6) Fact row count = silver row count  (expect diff = 0)
SELECT
    (SELECT COUNT(*) FROM silver.lending_loans)
  - (SELECT COUNT(*) FROM gold.loans_geo_fact) AS diff_rows;

-- ====================================================================
-- gold.report_loan_by_state
-- ====================================================================
-- 7) Reconcile report vs silver (4.1 & 4.3) -> expect diff = 0
SELECT
    (SELECT SUM(loan_amnt) FROM silver.lending_loans WHERE addr_state IS NOT NULL)
  - (SELECT SUM(total_loan_amnt) FROM gold.report_loan_by_state)                    AS diff_loan_amnt,
    (SELECT COUNT(*) FROM silver.lending_loans
      WHERE addr_state IS NOT NULL AND loan_status = 'Charged Off')
  - (SELECT SUM(charged_off_loans) FROM gold.report_loan_by_state)                  AS diff_charged_off;
