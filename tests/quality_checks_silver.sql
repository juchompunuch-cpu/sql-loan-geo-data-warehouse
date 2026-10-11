/*
===============================================================================
Quality Checks: Silver Layer
===============================================================================
Script Purpose:
    Checks data consistency, accuracy and standardization in 'silver':
    - NULL or duplicate primary keys
    - Unwanted spaces
    - Invalid / out-of-range values
    - Standardized values (loan_status, zip_code, addr_state)

Usage:
    Run after EXEC silver.load_silver;
    Expectation for each query: NO ROWS returned (unless noted).
===============================================================================
*/

-- ====================================================================
-- silver.lending_loans
-- ====================================================================
-- 1) NULL or duplicate loan_id
SELECT loan_id, COUNT(*) AS cnt
FROM silver.lending_loans
GROUP BY loan_id
HAVING COUNT(*) > 1 OR loan_id IS NULL;

-- 2) Unwanted spaces / invalid state code length
SELECT addr_state
FROM silver.lending_loans
WHERE addr_state != TRIM(addr_state) OR LEN(addr_state) != 2;

-- 3) Unwanted spaces in zip_code
SELECT zip_code
FROM silver.lending_loans
WHERE zip_code != TRIM(zip_code) OR zip_code IS NULL;

-- 4) Loan amount must be positive and not NULL
SELECT loan_id, loan_amnt
FROM silver.lending_loans
WHERE loan_amnt IS NULL OR loan_amnt <= 0;

-- 5) Funded amount must not exceed loan amount
SELECT loan_id, loan_amnt, funded_amnt
FROM silver.lending_loans
WHERE funded_amnt > loan_amnt;

-- 6) Annual income must be NULL or positive
SELECT loan_id, annual_inc
FROM silver.lending_loans
WHERE annual_inc <= 0;

-- 7) Review: distinct loan_status values (INFO - expect a short, clean list,
--    no 'Does not meet the credit policy...' prefixes)
SELECT loan_status, COUNT(*) AS cnt
FROM silver.lending_loans
GROUP BY loan_status
ORDER BY cnt DESC;

-- 8) Row count reconciliation bronze vs silver (INFO - difference = dropped/duplicate rows)
SELECT
    (SELECT COUNT(*) FROM bronze.lending_loans) AS bronze_rows,
    (SELECT COUNT(*) FROM silver.lending_loans) AS silver_rows;

-- ====================================================================
-- silver.ref_us_states
-- ====================================================================
-- 9) Duplicate state codes
SELECT state_code, COUNT(*) AS cnt
FROM silver.ref_us_states
GROUP BY state_code
HAVING COUNT(*) > 1 OR state_code IS NULL;
