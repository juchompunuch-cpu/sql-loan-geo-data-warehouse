/*
===============================================================================
Walkthrough: Gold Layer — ดูข้อมูล "ก่อน -> หลัง" การสร้าง Star Schema
===============================================================================
ไฟล์นี้ใช้ทำอะไร:
    อธิบายทีละขั้นว่า ddl_gold.sql เปลี่ยนตาราง Silver (1 ตารางแบน ๆ)
    ให้เป็น Star schema (2 Dimension + 1 Fact) และรายงานตอบโจทย์ได้อย่างไร
    มีแต่คำสั่ง SELECT -> ไม่แก้ไขข้อมูลใด ๆ รันกี่ครั้งก็ได้

ก่อนรัน:
    ต้องรัน ETL ครบถึง scripts/gold/ddl_gold.sql ให้เสร็จก่อน

วิธีใช้:
    - ไฮไลต์ทีละ STEP แล้วกด Ctrl+Enter เพื่อดูผลทีละขั้น
    - หรือกด F5 เพื่อรันทั้งไฟล์ ผลแต่ละตารางมีคอลัมน์ step บอกว่าเป็นขั้นไหน

ลำดับขั้น:
    G1  geography_dim     silver -> มิติภูมิศาสตร์ (zip + state + region)
    G2  loan_status_dim   silver -> มิติสถานะสัญญา
    G3  loans_geo_fact    แทนข้อความด้วย key ตัวเลขของมิติ
    G4  report            1,000 สัญญา -> สรุป 1 แถวต่อรัฐ
    G5  คำตอบโจทย์ 4.1 / 4.2 / 4.3
===============================================================================
*/
USE LoanGeoDW;
GO

/*-----------------------------------------------------------------------------
STEP G1a: geography_dim — นับก่อน/หลัง
ทำอะไรกับข้อมูล:
    SELECT DISTINCT zip_code, addr_state FROM silver.lending_loans
    = เก็บคู่ (zip, รัฐ) ที่ไม่ซ้ำกัน 1 คู่ = 1 แถวในมิติ
ทำไม:
    มิติเก็บ "คำอธิบาย" ครั้งเดียว แทนที่จะซ้ำอยู่ทุกสัญญา
ดูอะไร:
    silver 1,000 แถว -> มิติ 440 แถว
-----------------------------------------------------------------------------*/
SELECT
    N'G1a geography_dim count' AS step,
    (SELECT COUNT(*) FROM silver.lending_loans)                              AS silver_rows_before,
    (SELECT COUNT(*) FROM (SELECT DISTINCT zip_code, addr_state
                           FROM silver.lending_loans) d)                     AS distinct_zip_state,
    (SELECT COUNT(*) FROM gold.geography_dim)                                AS geography_dim_rows_after;
GO

/*-----------------------------------------------------------------------------
STEP G1b: ทำไม key ของมิติต้องเป็น zip + state (ไม่ใช่ zip อย่างเดียว)
ทำอะไรกับข้อมูล:
    หา zip 3 หลักที่อยู่มากกว่า 1 รัฐ
ดูอะไร:
    มี 4 zip เช่น 440xx พบทั้ง NC และ OH
    ถ้าใช้ zip อย่างเดียวเป็น key สัญญาจะถูกนับผิดรัฐ
-----------------------------------------------------------------------------*/
SELECT
    N'G1b zip in many states' AS step,
    zip_code,
    COUNT(*)                     AS states_cnt,
    STRING_AGG(addr_state, ', ') AS states
FROM (SELECT DISTINCT zip_code, addr_state FROM silver.lending_loans) d
GROUP BY zip_code
HAVING COUNT(*) > 1;
GO

/*-----------------------------------------------------------------------------
STEP G1c: geography_dim — หน้าตาหลังสร้าง
ทำอะไรกับข้อมูล:
    1) ROW_NUMBER() OVER (ORDER BY addr_state, zip_code) -> geography_id (surrogate key)
    2) LEFT JOIN silver.ref_us_states ON addr_state = state_code -> เติม region
    3) หา region ไม่เจอ -> 'n/a' (LEFT JOIN จึงไม่มีแถวหาย)
ดูอะไร:
    BEFORE (silver) มีแค่ zip_code, addr_state
    AFTER  (dim)    มี geography_id + region เพิ่ม
-----------------------------------------------------------------------------*/
SELECT TOP 5
    N'G1c BEFORE: silver columns' AS step,
    zip_code, addr_state
FROM (SELECT DISTINCT zip_code, addr_state FROM silver.lending_loans) d
ORDER BY addr_state, zip_code;

SELECT TOP 5
    N'G1c AFTER: gold.geography_dim' AS step,
    geography_id, zip_code, addr_state, region
FROM gold.geography_dim
ORDER BY geography_id;
GO

/*-----------------------------------------------------------------------------
STEP G1d: ผลของการเติม region จากไฟล์อ้างอิง
ทำอะไรกับข้อมูล:
    นับจำนวนรัฐ / แถวในมิติ แยกตาม region
ดูอะไร:
    มี 4 region (Midwest, Northeast, South, West) และ "ไม่มี" 'n/a'
    = ทุกรัฐในข้อมูลสินเชื่อจับคู่กับไฟล์อ้างอิงได้ครบ
-----------------------------------------------------------------------------*/
SELECT
    N'G1d region enrichment' AS step,
    region,
    COUNT(DISTINCT addr_state) AS states_cnt,
    COUNT(*)                   AS geography_rows
FROM gold.geography_dim
GROUP BY region
ORDER BY region;
GO

/*-----------------------------------------------------------------------------
STEP G2: loan_status_dim
ทำอะไรกับข้อมูล:
    SELECT DISTINCT loan_status FROM silver แล้วใส่เลข loan_status_id
ทำไม:
    สถานะใช้ "กรอง/จัดกลุ่ม" ไม่ได้ใช้บวกลบ จึงเป็นมิติ
    ใช้ตอบคำถาม 4.3 (นับ Charged Off)
ดูอะไร:
    BEFORE: silver 1,000 แถวมีสถานะ 6 แบบ (พร้อมจำนวน)
    AFTER : มิติ 6 แถว แต่ละแบบได้ id ของตัวเอง
-----------------------------------------------------------------------------*/
SELECT
    N'G2 BEFORE: silver.loan_status' AS step,
    loan_status,
    COUNT(*) AS loans_cnt
FROM silver.lending_loans
GROUP BY loan_status
ORDER BY loan_status;

SELECT
    N'G2 AFTER: gold.loan_status_dim' AS step,
    loan_status_id,
    loan_status
FROM gold.loan_status_dim
ORDER BY loan_status_id;
GO

/*-----------------------------------------------------------------------------
STEP G3: loans_geo_fact — แทนข้อความด้วย key ของมิติ
ทำอะไรกับข้อมูล:
    silver.lending_loans
      LEFT JOIN gold.geography_dim   ON zip_code + addr_state -> ได้ geography_id
      LEFT JOIN gold.loan_status_dim ON loan_status           -> ได้ loan_status_id
    เก็บเฉพาะตัวเลขที่จะรวม (measures) + key 2 ตัว
ทำไม:
    Grain ของ Fact = 1 แถวต่อ 1 สัญญา
    Fact เก็บแค่ตัวเลขกับ key ส่วนคำอธิบายไปอยู่ในมิติ
ดูอะไร:
    ตารางแรก (BEFORE -> AFTER): ข้อความ zip/รัฐ/สถานะ ถูกแทนด้วย id ตัวเลข
    ตารางสอง: หน้าตาจริงของ gold.loans_geo_fact
    ตารางสาม: จำนวนแถว silver = fact (ไม่มีสัญญาหายตอน JOIN)
-----------------------------------------------------------------------------*/
SELECT TOP 10
    N'G3 BEFORE -> AFTER' AS step,
    l.loan_id,
    l.zip_code, l.addr_state,  g.geography_id,     -- ข้อความ -> key
    l.loan_status,             s.loan_status_id,   -- ข้อความ -> key
    l.loan_amnt, l.funded_amnt, l.annual_inc       -- measures ส่งต่อตามเดิม
FROM silver.lending_loans l
LEFT JOIN gold.geography_dim g
       ON l.zip_code = g.zip_code AND l.addr_state = g.addr_state
LEFT JOIN gold.loan_status_dim s
       ON l.loan_status = s.loan_status
ORDER BY l.loan_id;

SELECT TOP 10
    N'G3 AFTER: gold.loans_geo_fact' AS step,
    *
FROM gold.loans_geo_fact;

SELECT
    N'G3 row check' AS step,
    (SELECT COUNT(*) FROM silver.lending_loans) AS silver_rows,
    (SELECT COUNT(*) FROM gold.loans_geo_fact)  AS fact_rows,
    (SELECT COUNT(*) FROM gold.loans_geo_fact
      WHERE geography_id IS NULL OR loan_status_id IS NULL) AS fact_rows_missing_key;
GO

/*-----------------------------------------------------------------------------
STEP G4: report_loan_by_state — จากรายสัญญา เป็น 1 แถวต่อรัฐ
ทำอะไรกับข้อมูล:
    Fact JOIN 2 มิติ แล้ว GROUP BY addr_state, region
      COUNT(*)                         -> total_loans
      SUM(loan_amnt)                   -> 4.1 ยอดกู้รวม
      AVG(annual_inc)                  -> 4.2 รายได้เฉลี่ย (ข้าม NULL)
      SUM(CASE 'Charged Off' THEN 1)   -> 4.3 จำนวน Charged Off
ดูอะไร:
    ตัวอย่างรัฐ CA
    BEFORE: คำนวณเองจากสัญญา CA ใน silver
    AFTER : แถว CA ใน gold.report_loan_by_state  -> ตัวเลขต้องตรงกัน
-----------------------------------------------------------------------------*/
SELECT
    N'G4 BEFORE: CA from silver' AS step,
    COUNT(*)                                                       AS total_loans,
    SUM(loan_amnt)                                                 AS total_loan_amnt,
    CAST(AVG(annual_inc) AS DECIMAL(18,2))                         AS avg_annual_inc,
    SUM(CASE WHEN loan_status = 'Charged Off' THEN 1 ELSE 0 END)   AS charged_off_loans
FROM silver.lending_loans
WHERE addr_state = 'CA';

SELECT
    N'G4 AFTER: CA in report' AS step,
    total_loans, total_loan_amnt, avg_annual_inc, charged_off_loans
FROM gold.report_loan_by_state
WHERE addr_state = 'CA';

SELECT
    N'G4 row check' AS step,
    (SELECT COUNT(*) FROM gold.loans_geo_fact)       AS fact_rows_before,
    (SELECT COUNT(*) FROM gold.report_loan_by_state) AS report_rows_after;
GO

/*-----------------------------------------------------------------------------
STEP G5: คำตอบโจทย์
ดูอะไร:
    4.1 รัฐที่ยอดกู้รวมสูงสุด
    4.2 รัฐที่รายได้เฉลี่ยสูงสุด (ดู total_loans ประกอบ รัฐที่สัญญาน้อยค่าเฉลี่ยแกว่งง่าย)
    4.3 รัฐที่มี Charged Off มากที่สุด
-----------------------------------------------------------------------------*/
SELECT TOP 5
    N'G5 answer 4.1' AS step,
    addr_state, region, total_loans, total_loan_amnt
FROM gold.report_loan_by_state
ORDER BY total_loan_amnt DESC;

SELECT TOP 5
    N'G5 answer 4.2' AS step,
    addr_state, region, total_loans, avg_annual_inc
FROM gold.report_loan_by_state
ORDER BY avg_annual_inc DESC;

SELECT TOP 5
    N'G5 answer 4.3' AS step,
    addr_state, region, total_loans, charged_off_loans
FROM gold.report_loan_by_state
ORDER BY charged_off_loans DESC;
GO
