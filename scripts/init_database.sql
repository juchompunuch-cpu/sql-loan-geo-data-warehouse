/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    Creates a new database named 'LoanGeoDW' after checking if it already exists.
    If the database exists, it is dropped and recreated. The script then creates
    three schemas inside the database: 'bronze', 'silver', and 'gold'
    (Medallion Architecture).

WARNING:
    Running this script will DROP the entire 'LoanGeoDW' database if it exists.
    All data in the database will be permanently deleted. Proceed with caution
    and make sure you have proper backups before running this script.
=============================================================
*/

USE master;
GO

-- Drop and recreate the 'LoanGeoDW' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'LoanGeoDW')
BEGIN
    ALTER DATABASE LoanGeoDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LoanGeoDW;
END;
GO

-- Create the 'LoanGeoDW' database
CREATE DATABASE LoanGeoDW;
GO

USE LoanGeoDW;
GO

-- Create Schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
