/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    Performs the ETL (Extract, Transform, Load) process to populate the
    'silver' schema tables from the 'bronze' schema.
    Actions Performed:
        - Truncates Silver tables (full load).
        - Inserts transformed and cleansed data from Bronze into Silver.

    Transformations (silver.lending_loans):
        - Data type casting (TRY_CAST so bad values become NULL, not errors)
        - loan_id: source 'id' is empty in the public LoanStats extract, so a
          surrogate row number is generated (source id kept when present)
        - Drop non-loan rows (footer/summary lines with no loan_amnt / addr_state)
        - ' 36 months' -> 36 ; ' 11.99%' -> 11.99 ; 'Mar-2016' -> 2016-03-01
        - annual_inc <= 0 -> NULL (invalid income)
        - loan_status standardization:
              'Does not meet the credit policy. Status:Charged Off' -> 'Charged Off'
              'Does not meet the credit policy. Status:Fully Paid'  -> 'Fully Paid'
        - zip_code: TRIM + LOWER, empty -> 'n/a'
        - addr_state: TRIM + UPPER

Parameters:
    None.

Usage Example:
    EXEC silver.load_silver;
===============================================================================
*/
CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME,
            @batch_start_time DATETIME, @batch_end_time DATETIME;
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Silver Layer';
        PRINT '================================================';

        ------------------------------------------------
        -- silver.lending_loans
        ------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.lending_loans';
        TRUNCATE TABLE silver.lending_loans;

        PRINT '>> Inserting Data Into: silver.lending_loans';
        WITH cleaned AS (
            SELECT
                COALESCE(
                    TRY_CAST(TRIM(id) AS BIGINT),
                    ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
                )                                                              AS loan_id,
                TRY_CAST(TRIM(loan_amnt) AS DECIMAL(18,2))                     AS loan_amnt,
                TRY_CAST(TRIM(funded_amnt) AS DECIMAL(18,2))                   AS funded_amnt,
                TRY_CAST(REPLACE(TRIM(term), ' months', '') AS INT)            AS term_months,
                TRY_CAST(REPLACE(TRIM(int_rate), '%', '') AS DECIMAL(6,2))     AS int_rate,
                UPPER(TRIM(grade))                                             AS grade,
                NULLIF(TRIM(emp_length), '')                                   AS emp_length,
                UPPER(NULLIF(TRIM(home_ownership), ''))                        AS home_ownership,
                CASE
                    WHEN TRY_CAST(TRIM(annual_inc) AS DECIMAL(18,2)) > 0
                        THEN TRY_CAST(TRIM(annual_inc) AS DECIMAL(18,2))
                    ELSE NULL
                END                                                            AS annual_inc,
                TRY_CONVERT(DATE, '01 ' + REPLACE(TRIM(issue_d), '-', ' '), 106) AS issue_date, -- 'Mar-2016'
                CASE
                    WHEN TRIM(loan_status) LIKE '%Charged Off' THEN 'Charged Off'
                    WHEN TRIM(loan_status) LIKE '%Fully Paid'  THEN 'Fully Paid'
                    WHEN NULLIF(TRIM(loan_status), '') IS NULL THEN 'n/a'
                    ELSE TRIM(loan_status)
                END                                                            AS loan_status,
                NULLIF(TRIM(purpose), '')                                      AS purpose,
                COALESCE(LOWER(NULLIF(TRIM(zip_code), '')), 'n/a')             AS zip_code,
                UPPER(TRIM(addr_state))                                        AS addr_state
            FROM bronze.lending_loans
            WHERE TRY_CAST(TRIM(loan_amnt) AS DECIMAL(18,2)) IS NOT NULL
              AND NULLIF(TRIM(addr_state), '') IS NOT NULL
        ),
        dedup AS (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY issue_date DESC) AS flag_last
            FROM cleaned
        )
        INSERT INTO silver.lending_loans (
            loan_id, loan_amnt, funded_amnt, term_months, int_rate, grade,
            emp_length, home_ownership, annual_inc, issue_date,
            loan_status, purpose, zip_code, addr_state
        )
        SELECT
            loan_id, loan_amnt, funded_amnt, term_months, int_rate, grade,
            emp_length, home_ownership, annual_inc, issue_date,
            loan_status, purpose, zip_code, addr_state
        FROM dedup
        WHERE flag_last = 1;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        ------------------------------------------------
        -- silver.ref_us_states
        ------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.ref_us_states';
        TRUNCATE TABLE silver.ref_us_states;

        PRINT '>> Inserting Data Into: silver.ref_us_states';
        INSERT INTO silver.ref_us_states (state_code, state_name, region, division)
        SELECT DISTINCT
            UPPER(TRIM(state_code)),
            TRIM(state_name),
            TRIM(region),
            TRIM(division)
        FROM bronze.ref_us_states
        WHERE NULLIF(TRIM(state_code), '') IS NOT NULL;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        SET @batch_end_time = GETDATE();
        PRINT '==========================================';
        PRINT 'Loading Silver Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '==========================================';
    END TRY
    BEGIN CATCH
        PRINT '==========================================';
        PRINT 'ERROR OCCURRED DURING LOADING SILVER LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State  : ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '==========================================';
    END CATCH
END;
GO
