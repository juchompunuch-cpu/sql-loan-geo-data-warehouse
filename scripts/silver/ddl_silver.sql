/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Script Purpose:
    Creates tables in the 'silver' schema, dropping existing tables
    if they already exist.
    Silver holds cleansed, standardized and correctly-typed data.
    Every table gets the technical column 'dwh_create_date'.

Run this script to re-define the DDL structure of 'silver' tables.
===============================================================================
*/

IF OBJECT_ID('silver.lending_loans', 'U') IS NOT NULL
    DROP TABLE silver.lending_loans;
GO

CREATE TABLE silver.lending_loans (
    loan_id          BIGINT,
    loan_amnt        DECIMAL(18,2),
    funded_amnt      DECIMAL(18,2),
    term_months      INT,
    int_rate         DECIMAL(6,2),          -- percent, e.g. 10.65
    grade            NVARCHAR(5),
    emp_length       NVARCHAR(50),
    home_ownership   NVARCHAR(50),
    annual_inc       DECIMAL(18,2),
    issue_date       DATE,
    loan_status      NVARCHAR(50),          -- standardized status
    purpose          NVARCHAR(100),
    zip_code         NVARCHAR(10),          -- 3-digit prefix, e.g. '860xx'
    addr_state       NVARCHAR(2),
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO

IF OBJECT_ID('silver.ref_us_states', 'U') IS NOT NULL
    DROP TABLE silver.ref_us_states;
GO

CREATE TABLE silver.ref_us_states (
    state_code       NVARCHAR(2),
    state_name       NVARCHAR(100),
    region           NVARCHAR(50),
    division         NVARCHAR(50),
    dwh_create_date  DATETIME2 DEFAULT GETDATE()
);
GO
