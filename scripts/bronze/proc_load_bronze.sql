/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    Loads data into the 'bronze' schema from external CSV files.
    - Truncates the bronze tables before loading data (full load).
    - Uses BULK INSERT to load data from CSV files into bronze tables.

Parameters:
    @base_path  Folder that contains the 'datasets' folder of this project,
                e.g. 'C:\sql\sql-loan-geo-data-warehouse\datasets\'

Usage Example:
    EXEC bronze.load_bronze @base_path = 'C:\sql\sql-loan-geo-data-warehouse\datasets\';

NOTE:
    FORMAT = 'CSV' / FIELDQUOTE require SQL Server 2017 or later.
===============================================================================
*/
CREATE OR ALTER PROCEDURE bronze.load_bronze
    @base_path NVARCHAR(400)
AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME,
            @batch_start_time DATETIME, @batch_end_time DATETIME,
            @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Bronze Layer';
        PRINT '================================================';

        ------------------------------------------------
        PRINT '------------------------------------------------';
        PRINT 'Loading Lending Tables';
        PRINT '------------------------------------------------';

        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.lending_loans';
        TRUNCATE TABLE bronze.lending_loans;

        PRINT '>> Inserting Data Into: bronze.lending_loans';
        SET @sql = N'BULK INSERT bronze.lending_loans
            FROM ''' + @base_path + N'source_lending\loan_data.csv''
            WITH (
                FORMAT = ''CSV'',
                FIRSTROW = 2,
                FIELDQUOTE = ''"'',
                FIELDTERMINATOR = '','',
                ROWTERMINATOR = ''0x0d0a'',   -- source file uses CRLF line endings
                CODEPAGE = ''65001'',         -- UTF-8 (file starts with a BOM)
                TABLOCK
            );';
        EXEC sp_executesql @sql;
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        ------------------------------------------------
        PRINT '------------------------------------------------';
        PRINT 'Loading Reference Tables';
        PRINT '------------------------------------------------';

        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.ref_us_states';
        TRUNCATE TABLE bronze.ref_us_states;

        PRINT '>> Inserting Data Into: bronze.ref_us_states';
        SET @sql = N'BULK INSERT bronze.ref_us_states
            FROM ''' + @base_path + N'source_ref\us_states.csv''
            WITH (
                FORMAT = ''CSV'',
                FIRSTROW = 2,
                FIELDQUOTE = ''"'',
                FIELDTERMINATOR = '','',
                ROWTERMINATOR = ''0x0a'',
                CODEPAGE = ''65001'',
                TABLOCK
            );';
        EXEC sp_executesql @sql;
        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        SET @batch_end_time = GETDATE();
        PRINT '==========================================';
        PRINT 'Loading Bronze Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '==========================================';
    END TRY
    BEGIN CATCH
        PRINT '==========================================';
        PRINT 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number : ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State  : ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '==========================================';
    END CATCH
END;
GO
