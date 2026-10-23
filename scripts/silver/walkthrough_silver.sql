/*
===============================================================================
Walkthrough: Silver Layer — ดูข้อมูล "ก่อน -> หลัง" การทำความสะอาด
===============================================================================
ไฟล์นี้ใช้ทำอะไร:
    อธิบายทีละขั้นว่า silver.load_silver ทำอะไรกับแต่ละคอลัมน์
    ทุกขั้นใช้ "สูตรเดียวกับใน proc_load_silver.sql" วาง BEFORE (ค่าดิบใน Bronze)
    ไว้ข้าง AFTER (ค่าหลังแปลง) ให้เห็นภาพ
    มีแต่คำสั่ง SELECT -> ไม่แก้ไขข้อมูลใด ๆ รันกี่ครั้งก็ได้

ก่อนรัน:
    ต้องรัน ETL ถึง EXEC silver.load_silver; ให้เสร็จก่อน

วิธีใช้:
    - ไฮไลต์ทีละ STEP แล้วกด Ctrl+Enter เพื่อดูผลทีละขั้น
    - หรือกด F5 เพื่อรันทั้งไฟล์ ผลแต่ละตารางมีคอลัมน์ step บอกว่าเป็นขั้นไหน

ลำดับขั้น (ตรงกับลำดับใน proc_load_silver.sql):
    S1  loan_id        สร้าง key แทน id ที่ว่าง
    S2  loan_amnt      ข้อความ -> DECIMAL ด้วย TRY_CAST
    S3  term           ' 36 months' -> 36
    S4  int_rate       ' 11.99%' -> 11.99
    S5  ข้อความทั่วไป   TRIM / UPPER / ค่าว่าง -> NULL
    S6  annual_inc     รายได้ <= 0 -> NULL
    S7  issue_d        'Mar-2016' -> 2016-03-01
    S8  loan_status    รวมชื่อสถานะให้เป็นมาตรฐาน
    S9  zip_code       TRIM + LOWER, ว่าง -> 'n/a'
    S10 addr_state     TRIM + UPPER
    S11 กรองแถว         ทิ้งแถวที่ไม่มียอดกู้ / ไม่มีรัฐ
    S12 กันซ้ำ          ROW_NUMBER() PARTITION BY loan_id
    S13 ref_us_states  ทำความสะอาดไฟล์อ้างอิง
    S14 data type      เทียบชนิดข้อมูล Bronze vs Silver
    S15 ผลสุดท้าย
===============================================================================
*/
USE LoanGeoDW;
GO

/*-----------------------------------------------------------------------------
STEP S1: loan_id  — สร้าง key ขึ้นเอง
ทำอะไรกับข้อมูล:
    COALESCE( TRY_CAST(TRIM(id) AS BIGINT), ROW_NUMBER() OVER (...) )
    = ถ้า id มีค่าและเป็นตัวเลข ใช้ id เดิม / ถ้าว่าง ใช้เลขลำดับแถวแทน
ทำไม:
    ไฟล์นี้ id ว่างทุกแถว แต่ต้องมี key ไว้ระบุแต่ละสัญญาและใช้กันข้อมูลซ้ำ
ดูอะไร:
    id_before ว่าง (NULL) -> loan_id_after = 1, 2, 3, ...
-----------------------------------------------------------------------------*/
SELECT TOP 5
    N'S1 loan_id' AS step,
    id                                                                  AS id_before,
    COALESCE(TRY_CAST(TRIM(id) AS BIGINT),
             ROW_NUMBER() OVER (ORDER BY (SELECT NULL)))                 AS loan_id_after
FROM bronze.lending_loans;
GO

/*-----------------------------------------------------------------------------
STEP S2: loan_amnt, funded_amnt  — ข้อความ -> DECIMAL(18,2)
ทำอะไรกับข้อมูล:
    TRY_CAST(TRIM(x) AS DECIMAL(18,2))
    TRIM = ตัดช่องว่างหน้า-หลัง / TRY_CAST = แปลงชนิด ถ้าแปลงไม่ได้ให้เป็น NULL
ทำไม:
    - เงินต้องใช้ DECIMAL ซึ่งแม่นยำ ไม่ใช้ FLOAT ที่ปัดเศษเพี้ยนได้เมื่อ SUM หลายแถว
    - TRY_CAST ไม่ทำให้ ETL ทั้งชุดหยุดเพราะค่าเสียแถวเดียว
ดูอะไร:
    ตารางแรก: ค่าก่อน/หลัง (ตัวเลขเท่าเดิม แต่ชนิดเปลี่ยนจากข้อความเป็นเลข)
    ตารางสอง: ตัวอย่างค่าเสีย 'abc' -> TRY_CAST ได้ NULL แทนที่จะ error
-----------------------------------------------------------------------------*/
SELECT TOP 5
    N'S2 amounts' AS step,
    loan_amnt                                        AS loan_amnt_before,
    TRY_CAST(TRIM(loan_amnt) AS DECIMAL(18,2))       AS loan_amnt_after,
    funded_amnt                                      AS funded_amnt_before,
    TRY_CAST(TRIM(funded_amnt) AS DECIMAL(18,2))     AS funded_amnt_after
FROM bronze.lending_loans;

SELECT
    N'S2 demo: bad value' AS step,
    N'abc'                                   AS value_before,
    TRY_CAST(N'abc' AS DECIMAL(18,2))        AS try_cast_after;
GO

/*-----------------------------------------------------------------------------
STEP S3: term  — ' 36 months' -> 36
ทำอะไรกับข้อมูล:
    TRIM(term)                -> '36 months'   (ตัดช่องว่างหน้า)
    REPLACE(..., ' months','')-> '36'          (ลบคำว่า months)
    TRY_CAST(... AS INT)      -> 36            (แปลงเป็นจำนวนเต็ม)
ทำไม:
    ระยะเวลากู้เป็นจำนวนเดือน ควรเป็นตัวเลขเพื่อคำนวณ/กรองได้
ดูอะไร:
    GROUP BY ให้เห็นค่าทุกแบบที่มี: ' 36 months' (749) -> 36, ' 60 months' (251) -> 60
-----------------------------------------------------------------------------*/
SELECT
    N'S3 term' AS step,
    '[' + term + ']'                                      AS term_before,
    TRIM(term)                                            AS after_trim,
    REPLACE(TRIM(term), ' months', '')                    AS after_replace,
    TRY_CAST(REPLACE(TRIM(term), ' months', '') AS INT)   AS term_months_after,
    COUNT(*)                                              AS rows_cnt
FROM bronze.lending_loans
GROUP BY term;
GO

/*-----------------------------------------------------------------------------
STEP S4: int_rate  — ' 11.99%' -> 11.99
ทำอะไรกับข้อมูล:
    TRIM -> ตัดช่องว่าง / REPLACE(..., '%', '') -> ลบ % / TRY_CAST -> DECIMAL(6,2)
ทำไม:
    อัตราดอกเบี้ยเป็นเปอร์เซ็นต์ทศนิยม 2 ตำแหน่ง ต้องเป็นตัวเลขจึงหาค่าเฉลี่ยได้
ดูอะไร:
    '[ 11.99%]' -> 11.99  (เก็บเป็นหน่วยเปอร์เซ็นต์ ไม่ได้หาร 100)
-----------------------------------------------------------------------------*/
SELECT DISTINCT TOP 5
    N'S4 int_rate' AS step,
    '[' + int_rate + ']'                                        AS int_rate_before,
    TRY_CAST(REPLACE(TRIM(int_rate), '%', '') AS DECIMAL(6,2))  AS int_rate_after
FROM bronze.lending_loans
ORDER BY int_rate_after;
GO

/*-----------------------------------------------------------------------------
STEP S5: ข้อความทั่วไป  — grade, home_ownership, emp_length, purpose
ทำอะไรกับข้อมูล:
    TRIM           ตัดช่องว่างหน้า-หลัง
    UPPER          ทำเป็นตัวพิมพ์ใหญ่ให้เหมือนกันทุกแถว ('rent' กับ 'RENT' จะได้นับรวมกัน)
    NULLIF(x, '')  ถ้าเป็นข้อความว่าง ให้กลายเป็น NULL (= ไม่มีข้อมูล)
ทำไม:
    ค่าที่สะกดต่างกันนิดเดียวจะถูกนับเป็นคนละกลุ่มตอน GROUP BY
ดูอะไร:
    home_ownership ก่อน/หลัง และจำนวนแถวต่อกลุ่ม
-----------------------------------------------------------------------------*/
SELECT
    N'S5 home_ownership' AS step,
    '[' + home_ownership + ']'                     AS home_ownership_before,
    UPPER(NULLIF(TRIM(home_ownership), ''))        AS home_ownership_after,
    COUNT(*)                                       AS rows_cnt
FROM bronze.lending_loans
GROUP BY home_ownership;

SELECT
    N'S5 emp_length' AS step,
    '[' + ISNULL(emp_length, 'NULL') + ']'         AS emp_length_before,
    NULLIF(TRIM(emp_length), '')                   AS emp_length_after,
    COUNT(*)                                       AS rows_cnt
FROM bronze.lending_loans
GROUP BY emp_length
ORDER BY rows_cnt DESC;
GO

/*-----------------------------------------------------------------------------
STEP S6: annual_inc  — รายได้ <= 0 -> NULL
ทำอะไรกับข้อมูล:
    CASE WHEN รายได้ > 0 THEN รายได้ ELSE NULL END
ทำไม:
    รายได้ 0 หรือติดลบไม่สมเหตุสมผลสำหรับผู้กู้
    ใส่ NULL (ไม่ใช่ 0) เพราะ AVG() ข้ามค่า NULL ให้เอง
    ถ้าเก็บเป็น 0 ค่าเฉลี่ยของรัฐ (คำถาม 4.2) จะถูกดึงต่ำกว่าความจริง
ดูอะไร:
    ตารางแรก: แถวที่มีปัญหา (UT, Joint App) รายได้ 0 -> NULL
    ตารางสอง: ค่าเฉลี่ยของ UT ถ้าใช้ NULL เทียบกับถ้าใส่ 0  -> เห็นว่าต่างกันมาก
-----------------------------------------------------------------------------*/
SELECT
    N'S6 annual_inc invalid row' AS step,
    addr_state,
    annual_inc                                             AS annual_inc_before,
    CASE WHEN TRY_CAST(TRIM(annual_inc) AS DECIMAL(18,2)) > 0
         THEN TRY_CAST(TRIM(annual_inc) AS DECIMAL(18,2))
         ELSE NULL END                                     AS annual_inc_after,
    application_type,
    annual_inc_joint
FROM bronze.lending_loans
WHERE TRY_CAST(TRIM(annual_inc) AS DECIMAL(18,2)) <= 0;

SELECT
    N'S6 why NULL not 0 (state UT)' AS step,
    COUNT(*)                                                         AS loans_in_UT,
    CAST(AVG(CASE WHEN TRY_CAST(annual_inc AS DECIMAL(18,2)) > 0
                  THEN TRY_CAST(annual_inc AS DECIMAL(18,2)) END) AS DECIMAL(18,2))
                                                                     AS avg_if_null_used,
    CAST(AVG(CASE WHEN TRY_CAST(annual_inc AS DECIMAL(18,2)) > 0
                  THEN TRY_CAST(annual_inc AS DECIMAL(18,2)) ELSE 0 END) AS DECIMAL(18,2))
                                                                     AS avg_if_zero_used
FROM bronze.lending_loans
WHERE TRIM(addr_state) = 'UT';
GO

/*-----------------------------------------------------------------------------
STEP S7: issue_d  — 'Mar-2016' -> 2016-03-01
ทำอะไรกับข้อมูล:
    REPLACE(TRIM(issue_d), '-', ' ')  -> 'Mar 2016'
    '01 ' + ...                        -> '01 Mar 2016'  (เติมวันที่ 1 ของเดือน)
    TRY_CONVERT(DATE, ..., 106)        -> 2016-03-01     (style 106 = 'dd mon yyyy')
ทำไม:
    เก็บเป็น DATE จริงจะเรียง/กรองตามเวลาได้ ต้นทางมีแค่เดือน-ปี จึงใช้วันที่ 1
ดูอะไร:
    ไฟล์นี้ออกสัญญาเดือนเดียว (Mar-2016) ทั้ง 1,000 แถว
-----------------------------------------------------------------------------*/
SELECT
    N'S7 issue_d' AS step,
    issue_d                                                          AS issue_d_before,
    '01 ' + REPLACE(TRIM(issue_d), '-', ' ')                         AS middle_step,
    TRY_CONVERT(DATE, '01 ' + REPLACE(TRIM(issue_d), '-', ' '), 106) AS issue_date_after,
    COUNT(*)                                                         AS rows_cnt
FROM bronze.lending_loans
GROUP BY issue_d;
GO

/*-----------------------------------------------------------------------------
STEP S8: loan_status  — รวมชื่อสถานะให้เป็นมาตรฐาน
ทำอะไรกับข้อมูล:
    ...LIKE '%Charged Off' -> 'Charged Off'
    ...LIKE '%Fully Paid'  -> 'Fully Paid'
    ว่าง                    -> 'n/a'
    อื่น ๆ                  -> คงค่าเดิม (ตัดช่องว่าง)
ทำไม:
    ไฟล์ Lending Club รุ่นเก่ามีสถานะยาว เช่น
    'Does not meet the credit policy. Status:Charged Off'
    ถ้าไม่รวม จะนับ Charged Off (คำถาม 4.3) ได้ไม่ครบ
ดูอะไร:
    ตารางแรก: สถานะจริงในไฟล์นี้ก่อน/หลัง + จำนวน
    ตารางสอง: ตัวอย่างค่าที่ "ไฟล์นี้ไม่มี" แต่กฎรองรับไว้ล่วงหน้า
-----------------------------------------------------------------------------*/
SELECT
    N'S8 loan_status' AS step,
    loan_status AS loan_status_before,
    CASE
        WHEN TRIM(loan_status) LIKE '%Charged Off' THEN 'Charged Off'
        WHEN TRIM(loan_status) LIKE '%Fully Paid'  THEN 'Fully Paid'
        WHEN NULLIF(TRIM(loan_status), '') IS NULL THEN 'n/a'
        ELSE TRIM(loan_status)
    END         AS loan_status_after,
    COUNT(*)    AS rows_cnt
FROM bronze.lending_loans
GROUP BY loan_status
ORDER BY rows_cnt DESC;

SELECT
    N'S8 demo: rule for other files' AS step,
    v.loan_status_before,
    CASE
        WHEN TRIM(v.loan_status_before) LIKE '%Charged Off' THEN 'Charged Off'
        WHEN TRIM(v.loan_status_before) LIKE '%Fully Paid'  THEN 'Fully Paid'
        WHEN NULLIF(TRIM(v.loan_status_before), '') IS NULL THEN 'n/a'
        ELSE TRIM(v.loan_status_before)
    END AS loan_status_after
FROM (VALUES
        (N'Does not meet the credit policy. Status:Charged Off'),
        (N'Does not meet the credit policy. Status:Fully Paid'),
        (N''),
        (N' Current')
     ) AS v(loan_status_before);
GO

/*-----------------------------------------------------------------------------
STEP S9: zip_code  — TRIM + LOWER, ว่าง -> 'n/a'
ทำอะไรกับข้อมูล:
    COALESCE( LOWER(NULLIF(TRIM(zip_code), '')), 'n/a' )
    = ตัดช่องว่าง -> ว่างให้เป็น NULL -> ทำตัวพิมพ์เล็ก -> ถ้ายัง NULL ใส่ 'n/a'
ทำไม:
    zip_code ใช้เป็น key ของมิติภูมิศาสตร์
    ถ้าปล่อยเป็น NULL ตอน JOIN  NULL = NULL ไม่เป็นจริง -> แถวหลุดจาก Fact
    จึงใส่ 'n/a' เป็นสมาชิก "ไม่ทราบ" ของมิติแทน
    เก็บเป็นข้อความ เพราะมี 'xx' และเลข 0 นำหน้าจะหายถ้าเป็นตัวเลข
ดูอะไร:
    ตารางแรก: ค่าจริงในไฟล์ / ตารางสอง: ตัวอย่างค่าว่าง, NULL, ตัวพิมพ์ใหญ่
-----------------------------------------------------------------------------*/
SELECT TOP 5
    N'S9 zip_code' AS step,
    '[' + zip_code + ']'                                AS zip_code_before,
    COALESCE(LOWER(NULLIF(TRIM(zip_code), '')), 'n/a')  AS zip_code_after
FROM bronze.lending_loans;

SELECT
    N'S9 demo: edge cases' AS step,
    '[' + ISNULL(v.zip_before, 'NULL') + ']'                  AS zip_code_before,
    COALESCE(LOWER(NULLIF(TRIM(v.zip_before), '')), 'n/a')    AS zip_code_after
FROM (VALUES (N' 945XX'), (N''), (NULL)) AS v(zip_before);
GO

/*-----------------------------------------------------------------------------
STEP S10: addr_state  — TRIM + UPPER
ทำอะไรกับข้อมูล:
    UPPER(TRIM(addr_state))  เช่น ' ca' -> 'CA'
ทำไม:
    addr_state คือมิติหลักของคำถาม 4.1-4.3 ต้องสะกดเหมือนกันทุกแถว
    และต้องตรงกับ state_code ในไฟล์อ้างอิงเพื่อ JOIN หา region
ดูอะไร:
    ตารางแรก: จำนวนรัฐก่อน/หลัง (50 = ไฟล์นี้สะอาดอยู่แล้ว)
    ตารางสอง: ตัวอย่างค่าที่สะกดไม่เป็นมาตรฐาน
-----------------------------------------------------------------------------*/
SELECT
    N'S10 addr_state' AS step,
    COUNT(DISTINCT addr_state)               AS distinct_states_before,
    COUNT(DISTINCT UPPER(TRIM(addr_state)))  AS distinct_states_after
FROM bronze.lending_loans;

SELECT
    N'S10 demo: messy codes' AS step,
    '[' + v.state_before + ']'   AS addr_state_before,
    UPPER(TRIM(v.state_before))  AS addr_state_after
FROM (VALUES (N' ca'), (N'Tx '), (N'NY')) AS v(state_before);
GO

/*-----------------------------------------------------------------------------
STEP S11: กรองแถวที่ใช้ไม่ได้
ทำอะไรกับข้อมูล:
    WHERE TRY_CAST(TRIM(loan_amnt) AS DECIMAL(18,2)) IS NOT NULL
      AND NULLIF(TRIM(addr_state), '') IS NOT NULL
    = เก็บเฉพาะแถวที่มียอดกู้เป็นตัวเลข และมีรหัสรัฐ
ทำไม:
    แถวที่ไม่มียอดกู้หรือไม่มีรัฐ ตอบคำถามไม่ได้ทั้ง 3 ข้อ
    และไฟล์ LoanStats มักมีบรรทัดสรุปท้ายไฟล์ที่ไม่ใช่สัญญาจริง
ดูอะไร:
    rows_before = 1000, rows_kept = 1000, rows_dropped = 0 (ไฟล์ชุดนี้ไม่มีแถวเสีย)
-----------------------------------------------------------------------------*/
SELECT
    N'S11 filter rows' AS step,
    COUNT(*) AS rows_before,
    SUM(CASE WHEN TRY_CAST(TRIM(loan_amnt) AS DECIMAL(18,2)) IS NOT NULL
              AND NULLIF(TRIM(addr_state), '') IS NOT NULL
             THEN 1 ELSE 0 END) AS rows_kept,
    SUM(CASE WHEN TRY_CAST(TRIM(loan_amnt) AS DECIMAL(18,2)) IS NULL
              OR NULLIF(TRIM(addr_state), '') IS NULL
             THEN 1 ELSE 0 END) AS rows_dropped
FROM bronze.lending_loans;
GO

/*-----------------------------------------------------------------------------
STEP S12: กันข้อมูลซ้ำ (dedup)
ทำอะไรกับข้อมูล:
    ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY issue_date DESC) AS flag_last
    แล้วเก็บเฉพาะ flag_last = 1
    = ถ้า loan_id ซ้ำ ให้เก็บแถวที่ issue_date ล่าสุดไว้แถวเดียว
ทำไม:
    กันไม่ให้สัญญาเดียวกันถูกนับซ้ำในยอดรวม
ดูอะไร:
    ไฟล์นี้ id ว่าง ทุกแถวได้เลขใหม่ไม่ซ้ำ -> ไม่มีแถวถูกตัด
    (เป็นตัวกันไว้สำหรับไฟล์ที่มี id จริง)
-----------------------------------------------------------------------------*/
SELECT
    N'S12 dedup' AS step,
    (SELECT COUNT(*) FROM bronze.lending_loans
      WHERE TRY_CAST(TRIM(loan_amnt) AS DECIMAL(18,2)) IS NOT NULL
        AND NULLIF(TRIM(addr_state), '') IS NOT NULL)        AS rows_before_dedup,
    COUNT(*)                                                  AS rows_after_dedup,
    COUNT(DISTINCT loan_id)                                   AS distinct_loan_id
FROM silver.lending_loans;
GO

/*-----------------------------------------------------------------------------
STEP S13: silver.ref_us_states  — ทำความสะอาดไฟล์อ้างอิง
ทำอะไรกับข้อมูล:
    SELECT DISTINCT  UPPER(TRIM(state_code)), TRIM(...) อื่น ๆ
    WHERE state_code ไม่ว่าง
ทำไม:
    รหัสรัฐต้องเป็นตัวพิมพ์ใหญ่ไม่มีช่องว่าง จึงจะ JOIN กับ addr_state ได้
    DISTINCT กันรัฐซ้ำ ไม่ให้สัญญาถูกนับซ้ำตอน JOIN
ดูอะไร:
    51 แถว -> 51 แถว และตัวอย่างค่าก่อน/หลัง
-----------------------------------------------------------------------------*/
SELECT
    N'S13 ref_us_states count' AS step,
    (SELECT COUNT(*) FROM bronze.ref_us_states) AS rows_before,
    (SELECT COUNT(*) FROM silver.ref_us_states) AS rows_after;

SELECT TOP 5
    N'S13 ref_us_states values' AS step,
    b.state_code   AS state_code_before,
    s.state_code   AS state_code_after,
    s.state_name,
    s.region,
    s.dwh_create_date
FROM bronze.ref_us_states b
JOIN silver.ref_us_states s
  ON UPPER(TRIM(b.state_code)) = s.state_code;
GO

/*-----------------------------------------------------------------------------
STEP S14: เทียบชนิดข้อมูล  Bronze (ก่อน) vs Silver (หลัง)
ทำอะไรกับข้อมูล:
    อ่านโครงสร้างตารางจาก INFORMATION_SCHEMA.COLUMNS ของทั้งสองชั้นมาวางคู่กัน
ทำไม:
    สรุปให้เห็นในตารางเดียวว่าแต่ละคอลัมน์เปลี่ยนจากข้อความเป็นชนิดอะไร
    เช่น เงิน -> decimal(18,2), term -> int, วันที่ -> date
    และ Silver มีคอลัมน์เทคนิค dwh_create_date = เวลาที่โหลดเข้า DW
ดูอะไร:
    คอลัมน์ bronze_type (ก่อน) กับ silver_type (หลัง)
-----------------------------------------------------------------------------*/
SELECT
    N'S14 data types' AS step,
    b.COLUMN_NAME AS bronze_column,
    b.DATA_TYPE + CASE WHEN b.CHARACTER_MAXIMUM_LENGTH = -1 THEN '(max)'
                       WHEN b.CHARACTER_MAXIMUM_LENGTH IS NOT NULL
                            THEN '(' + CAST(b.CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) + ')'
                       ELSE '' END AS bronze_type,
    s.COLUMN_NAME AS silver_column,
    s.DATA_TYPE + CASE WHEN s.DATA_TYPE = 'decimal'
                            THEN '(' + CAST(s.NUMERIC_PRECISION AS VARCHAR(10)) + ','
                                     + CAST(s.NUMERIC_SCALE AS VARCHAR(10)) + ')'
                       WHEN s.CHARACTER_MAXIMUM_LENGTH IS NOT NULL
                            THEN '(' + CAST(s.CHARACTER_MAXIMUM_LENGTH AS VARCHAR(10)) + ')'
                       ELSE '' END AS silver_type
FROM INFORMATION_SCHEMA.COLUMNS s
LEFT JOIN INFORMATION_SCHEMA.COLUMNS b
       ON  b.TABLE_SCHEMA = 'bronze'
       AND b.TABLE_NAME   = 'lending_loans'
       AND b.COLUMN_NAME  = CASE s.COLUMN_NAME
                                WHEN 'loan_id'     THEN 'id'
                                WHEN 'term_months' THEN 'term'
                                WHEN 'issue_date'  THEN 'issue_d'
                                ELSE s.COLUMN_NAME
                            END
WHERE s.TABLE_SCHEMA = 'silver'
  AND s.TABLE_NAME   = 'lending_loans'
ORDER BY s.ORDINAL_POSITION;
GO

/*-----------------------------------------------------------------------------
STEP S15: ผลสุดท้ายใน Silver
ทำอะไรกับข้อมูล:
    ผลของ INSERT INTO silver.lending_loans หลังผ่านทุกขั้นข้างบน
ดูอะไร:
    ค่าสะอาด ชนิดถูกต้อง พร้อมส่งต่อให้ Gold (Star schema)
-----------------------------------------------------------------------------*/
SELECT TOP 10
    N'S15 AFTER: silver.lending_loans' AS step,
    *
FROM silver.lending_loans
ORDER BY loan_id;
GO
