/*
===============================================================================
Walkthrough: Bronze Layer — ดูข้อมูล "ก่อน -> หลัง" การโหลดเข้า Bronze
===============================================================================
ไฟล์นี้ใช้ทำอะไร:
    อธิบายทีละขั้นว่า bronze.load_bronze ทำอะไรกับข้อมูล
    มีแต่คำสั่ง SELECT -> ไม่แก้ไขข้อมูลใด ๆ รันกี่ครั้งก็ได้

ก่อนรัน:
    ต้องรัน ETL ให้เสร็จก่อน (init_database -> ddl_bronze -> load_bronze)

วิธีใช้:
    - ไฮไลต์ทีละ STEP แล้วกด Ctrl+Enter เพื่อดูผลทีละขั้น
    - หรือกด F5 เพื่อรันทั้งไฟล์ ผลแต่ละตารางมีคอลัมน์ step บอกว่าเป็นขั้นไหน

ภาพรวมของ Bronze:
    BEFORE = ไฟล์ CSV  (datasets/source_lending/loan_data.csv, datasets/source_ref/us_states.csv)
    AFTER  = ตาราง bronze.lending_loans, bronze.ref_us_states
    หลักการ = "เก็บของดิบตามต้นฉบับ" ไม่แปลง ไม่ทำความสะอาด
===============================================================================
*/
USE LoanGeoDW;
GO

/*-----------------------------------------------------------------------------
STEP B1: จำนวนแถว  CSV -> Bronze
ทำอะไรกับข้อมูล:
    BULK INSERT อ่านไฟล์ทีละบรรทัด โดย FIRSTROW = 2 คือข้ามบรรทัดแรก (header)
BEFORE : loan_data.csv มี 1,001 บรรทัด (header 1 + ข้อมูล 1,000)
         us_states.csv มี 52 บรรทัด (header 1 + ข้อมูล 51)
AFTER  : ต้องได้ 1,000 และ 51 แถว = โหลดครบ ไม่มีแถวหาย
-----------------------------------------------------------------------------*/
SELECT N'B1 AFTER: row count' AS step, 'bronze.lending_loans' AS table_name,
       1000 AS expected_rows_from_csv, COUNT(*) AS rows_in_bronze
FROM bronze.lending_loans
UNION ALL
SELECT N'B1 AFTER: row count', 'bronze.ref_us_states',
       51, COUNT(*)
FROM bronze.ref_us_states;
GO

/*-----------------------------------------------------------------------------
STEP B2: โครงสร้างตาราง  ทุกคอลัมน์เป็น NVARCHAR
ทำอะไรกับข้อมูล:
    สร้างตารางให้มีคอลัมน์ครบ 144 คอลัมน์ เรียงตรงกับ header ของไฟล์
    และให้ทุกคอลัมน์เป็นข้อความ (NVARCHAR)
ทำไม:
    - BULK INSERT จับคู่คอลัมน์ "ตามตำแหน่ง" ไม่ใช่ตามชื่อ จึงต้องครบและเรียงตรง
    - ถ้าตั้งเป็นตัวเลขตั้งแต่ชั้นนี้ ค่าอย่าง ' 36 months' จะทำให้โหลดล้มทั้งไฟล์
AFTER  : total_columns = 144, nvarchar_columns = 144
-----------------------------------------------------------------------------*/
SELECT N'B2 AFTER: column types' AS step,
       TABLE_SCHEMA + '.' + TABLE_NAME                              AS table_name,
       COUNT(*)                                                     AS total_columns,
       SUM(CASE WHEN DATA_TYPE = 'nvarchar' THEN 1 ELSE 0 END)      AS nvarchar_columns
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'bronze'
GROUP BY TABLE_SCHEMA, TABLE_NAME;
GO

/*-----------------------------------------------------------------------------
STEP B3: ค่าดิบถูกเก็บ "ตามต้นฉบับ"
ทำอะไรกับข้อมูล:
    FORMAT = 'CSV' + FIELDQUOTE = '"'  -> ถอดเครื่องหมาย " ที่ครอบค่าออกให้
    แต่ "ไม่" ตัดช่องว่าง ไม่ตัด % ไม่แปลงวันที่ -> ค่ายังดิบเหมือนในไฟล์
ดูอะไร:
    ใส่ [ ] ครอบค่าไว้ จะเห็นช่องว่างหน้าคำ เช่น [ 36 months], [ 11.99%]
    และวันที่ยังเป็นข้อความ 'Mar-2016'
-----------------------------------------------------------------------------*/
SELECT TOP 5
    N'B3 AFTER: raw values' AS step,
    '[' + term       + ']'  AS term_raw,
    '[' + int_rate   + ']'  AS int_rate_raw,
    '[' + issue_d    + ']'  AS issue_d_raw,
    '[' + annual_inc + ']'  AS annual_inc_raw,
    '[' + loan_status+ ']'  AS loan_status_raw,
    '[' + zip_code   + ']'  AS zip_code_raw,
    '[' + addr_state + ']'  AS addr_state_raw
FROM bronze.lending_loans;
GO

/*-----------------------------------------------------------------------------
STEP B4: พิสูจน์ว่าทำไมยังแปลงเป็นตัวเลขตรง ๆ ไม่ได้
ทำอะไรกับข้อมูล:
    ลองแปลง term และ int_rate เป็นตัวเลขตรง ๆ ด้วย TRY_CAST
ดูอะไร:
    ได้ NULL ทั้งหมด เพราะมีคำว่า months / เครื่องหมาย % ปนอยู่
    -> ต้องไปทำความสะอาดก่อนในชั้น Silver
    (ถ้าใช้ CAST ธรรมดาจะขึ้น error "Conversion failed" และหยุดทั้ง query)
-----------------------------------------------------------------------------*/
SELECT TOP 5
    N'B4 why clean first' AS step,
    term                                  AS term_raw,
    TRY_CAST(term AS INT)                 AS term_cast_directly,
    int_rate                              AS int_rate_raw,
    TRY_CAST(int_rate AS DECIMAL(6,2))    AS int_rate_cast_directly
FROM bronze.lending_loans;
GO

/*-----------------------------------------------------------------------------
STEP B5: คอลัมน์ id ว่างทั้งไฟล์
ทำอะไรกับข้อมูล:
    นับว่า id ว่างกี่แถว (ไฟล์ LoanStats สาธารณะลบ id ออก)
ดูอะไร:
    empty_id = 1000 จากทั้งหมด 1000 -> ใช้เป็น key ไม่ได้
    -> ชั้น Silver ต้องสร้าง loan_id ขึ้นเองด้วย ROW_NUMBER()
-----------------------------------------------------------------------------*/
SELECT
    N'B5 id column' AS step,
    COUNT(*)                                                     AS total_rows,
    SUM(CASE WHEN NULLIF(TRIM(id), '') IS NULL THEN 1 ELSE 0 END) AS empty_id
FROM bronze.lending_loans;
GO

/*-----------------------------------------------------------------------------
STEP B6: Reference data (us_states.csv)
ทำอะไรกับข้อมูล:
    โหลดไฟล์อ้างอิงรายชื่อรัฐแบบเดียวกัน (ไม่แปลงอะไร)
    ไฟล์นี้ไม่ใช่ข้อมูลต้นทาง แต่กลุ่มเตรียมเพิ่ม เพื่อเติม region ให้มิติภูมิศาสตร์
ดูอะไร:
    state_code -> state_name -> region -> division  (51 แถว = 50 รัฐ + DC)
-----------------------------------------------------------------------------*/
SELECT TOP 5
    N'B6 AFTER: reference' AS step,
    state_code, state_name, region, division
FROM bronze.ref_us_states;
GO
