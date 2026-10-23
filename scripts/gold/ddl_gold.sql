/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    Creates views for the Gold layer (Dimensional Model / Star Schema)
    for the GEOGRAPHIC dimension topic. See docs/data_model.png.

    Star Schema:
        gold.geography_dim    (one row per zip_code + addr_state)
        gold.loan_status_dim  (one row per standardized loan_status)
        gold.loans_geo_fact   (one row per loan contract)

    Report view (closes the 3 business questions):
        gold.report_loan_by_state
            4.1 total loan amount by state           (SUM loan_amnt)
            4.2 average annual income by state       (AVG annual_inc)
            4.3 number of Charged Off loans by state (COUNT where loan_status = 'Charged Off')

Usage:
    SELECT * FROM gold.report_loan_by_state ORDER BY total_loan_amnt DESC;

Walkthrough (before -> after, step by step):
    scripts/gold/walkthrough_gold.sql
===============================================================================
*/

-- =============================================================================
-- Dimension: gold.geography_dim
-- =============================================================================
IF OBJECT_ID('gold.geography_dim', 'V') IS NOT NULL
    DROP VIEW gold.geography_dim;
GO

CREATE VIEW gold.geography_dim AS
SELECT
    ROW_NUMBER() OVER (ORDER BY g.addr_state, g.zip_code) AS geography_id,  -- surrogate key
    g.zip_code,
    g.addr_state,
    COALESCE(r.region, 'n/a')                              AS region        -- from state reference
FROM (
    SELECT DISTINCT zip_code, addr_state
    FROM silver.lending_loans
    WHERE addr_state IS NOT NULL
) g
LEFT JOIN silver.ref_us_states r
    ON g.addr_state = r.state_code;
GO

-- =============================================================================
-- Dimension: gold.loan_status_dim
-- =============================================================================
IF OBJECT_ID('gold.loan_status_dim', 'V') IS NOT NULL
    DROP VIEW gold.loan_status_dim;
GO

CREATE VIEW gold.loan_status_dim AS
SELECT
    ROW_NUMBER() OVER (ORDER BY s.loan_status) AS loan_status_id,  -- surrogate key
    s.loan_status
FROM (
    SELECT DISTINCT loan_status
    FROM silver.lending_loans
) s;
GO

-- =============================================================================
-- Fact: gold.loans_geo_fact
-- =============================================================================
IF OBJECT_ID('gold.loans_geo_fact', 'V') IS NOT NULL
    DROP VIEW gold.loans_geo_fact;
GO

CREATE VIEW gold.loans_geo_fact AS
SELECT
    l.loan_amnt,
    l.funded_amnt,
    l.annual_inc,
    g.geography_id,
    s.loan_status_id
FROM silver.lending_loans l
LEFT JOIN gold.geography_dim g
    ON  l.zip_code   = g.zip_code
    AND l.addr_state = g.addr_state
LEFT JOIN gold.loan_status_dim s
    ON  l.loan_status = s.loan_status;
GO

-- =============================================================================
-- Report: gold.report_loan_by_state  (4.1 / 4.2 / 4.3)
-- =============================================================================
IF OBJECT_ID('gold.report_loan_by_state', 'V') IS NOT NULL
    DROP VIEW gold.report_loan_by_state;
GO

CREATE VIEW gold.report_loan_by_state AS
SELECT
    g.addr_state,
    g.region,
    COUNT(*)                                                       AS total_loans,
    SUM(f.loan_amnt)                                               AS total_loan_amnt,    -- 4.1
    CAST(AVG(f.annual_inc) AS DECIMAL(18,2))                       AS avg_annual_inc,     -- 4.2 (NULL incomes ignored)
    SUM(CASE WHEN s.loan_status = 'Charged Off' THEN 1 ELSE 0 END) AS charged_off_loans   -- 4.3
FROM gold.loans_geo_fact f
JOIN gold.geography_dim   g ON f.geography_id   = g.geography_id
JOIN gold.loan_status_dim s ON f.loan_status_id = s.loan_status_id
GROUP BY g.addr_state, g.region;
GO
