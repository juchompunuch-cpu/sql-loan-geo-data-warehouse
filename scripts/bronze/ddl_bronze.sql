/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    Creates tables in the 'bronze' schema ONLY IF they do not exist yet.
    Running this script again does NOT drop the tables, so loaded data is kept
    (bronze.load_bronze truncates and reloads the data itself).
    Bronze stores raw data AS-IS from the source CSV files, so every
    column is NVARCHAR (no type conversion, no cleansing).

NOTE:
    bronze.lending_loans mirrors ALL 144 columns of the Lending Club
    file (LoanStats) in the exact header order, because BULK INSERT maps
    columns by position. Only a few columns move on to silver.

To change a table's structure, re-run scripts/init_database.sql (drops the
whole database) or drop the table manually first; this script will then
create it with the new layout.
===============================================================================
*/

-- Source 1: Lending (loan contracts, Lending Club LoanStats - 144 columns)
IF OBJECT_ID('bronze.lending_loans', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.lending_loans (
        id                                          NVARCHAR(255),
        member_id                                   NVARCHAR(255),
        loan_amnt                                   NVARCHAR(255),
        funded_amnt                                 NVARCHAR(255),
        funded_amnt_inv                             NVARCHAR(255),
        term                                        NVARCHAR(255),
        int_rate                                    NVARCHAR(255),
        installment                                 NVARCHAR(255),
        grade                                       NVARCHAR(255),
        sub_grade                                   NVARCHAR(255),
        emp_title                                   NVARCHAR(MAX),
        emp_length                                  NVARCHAR(255),
        home_ownership                              NVARCHAR(255),
        annual_inc                                  NVARCHAR(255),
        verification_status                         NVARCHAR(255),
        issue_d                                     NVARCHAR(255),
        loan_status                                 NVARCHAR(255),
        pymnt_plan                                  NVARCHAR(255),
        url                                         NVARCHAR(MAX),
        [desc]                                      NVARCHAR(MAX),
        purpose                                     NVARCHAR(255),
        title                                       NVARCHAR(MAX),
        zip_code                                    NVARCHAR(255),
        addr_state                                  NVARCHAR(255),
        dti                                         NVARCHAR(255),
        delinq_2yrs                                 NVARCHAR(255),
        earliest_cr_line                            NVARCHAR(255),
        inq_last_6mths                              NVARCHAR(255),
        mths_since_last_delinq                      NVARCHAR(255),
        mths_since_last_record                      NVARCHAR(255),
        open_acc                                    NVARCHAR(255),
        pub_rec                                     NVARCHAR(255),
        revol_bal                                   NVARCHAR(255),
        revol_util                                  NVARCHAR(255),
        total_acc                                   NVARCHAR(255),
        initial_list_status                         NVARCHAR(255),
        out_prncp                                   NVARCHAR(255),
        out_prncp_inv                               NVARCHAR(255),
        total_pymnt                                 NVARCHAR(255),
        total_pymnt_inv                             NVARCHAR(255),
        total_rec_prncp                             NVARCHAR(255),
        total_rec_int                               NVARCHAR(255),
        total_rec_late_fee                          NVARCHAR(255),
        recoveries                                  NVARCHAR(255),
        collection_recovery_fee                     NVARCHAR(255),
        last_pymnt_d                                NVARCHAR(255),
        last_pymnt_amnt                             NVARCHAR(255),
        next_pymnt_d                                NVARCHAR(255),
        last_credit_pull_d                          NVARCHAR(255),
        collections_12_mths_ex_med                  NVARCHAR(255),
        mths_since_last_major_derog                 NVARCHAR(255),
        policy_code                                 NVARCHAR(255),
        application_type                            NVARCHAR(255),
        annual_inc_joint                            NVARCHAR(255),
        dti_joint                                   NVARCHAR(255),
        verification_status_joint                   NVARCHAR(255),
        acc_now_delinq                              NVARCHAR(255),
        tot_coll_amt                                NVARCHAR(255),
        tot_cur_bal                                 NVARCHAR(255),
        open_acc_6m                                 NVARCHAR(255),
        open_act_il                                 NVARCHAR(255),
        open_il_12m                                 NVARCHAR(255),
        open_il_24m                                 NVARCHAR(255),
        mths_since_rcnt_il                          NVARCHAR(255),
        total_bal_il                                NVARCHAR(255),
        il_util                                     NVARCHAR(255),
        open_rv_12m                                 NVARCHAR(255),
        open_rv_24m                                 NVARCHAR(255),
        max_bal_bc                                  NVARCHAR(255),
        all_util                                    NVARCHAR(255),
        total_rev_hi_lim                            NVARCHAR(255),
        inq_fi                                      NVARCHAR(255),
        total_cu_tl                                 NVARCHAR(255),
        inq_last_12m                                NVARCHAR(255),
        acc_open_past_24mths                        NVARCHAR(255),
        avg_cur_bal                                 NVARCHAR(255),
        bc_open_to_buy                              NVARCHAR(255),
        bc_util                                     NVARCHAR(255),
        chargeoff_within_12_mths                    NVARCHAR(255),
        delinq_amnt                                 NVARCHAR(255),
        mo_sin_old_il_acct                          NVARCHAR(255),
        mo_sin_old_rev_tl_op                        NVARCHAR(255),
        mo_sin_rcnt_rev_tl_op                       NVARCHAR(255),
        mo_sin_rcnt_tl                              NVARCHAR(255),
        mort_acc                                    NVARCHAR(255),
        mths_since_recent_bc                        NVARCHAR(255),
        mths_since_recent_bc_dlq                    NVARCHAR(255),
        mths_since_recent_inq                       NVARCHAR(255),
        mths_since_recent_revol_delinq              NVARCHAR(255),
        num_accts_ever_120_pd                       NVARCHAR(255),
        num_actv_bc_tl                              NVARCHAR(255),
        num_actv_rev_tl                             NVARCHAR(255),
        num_bc_sats                                 NVARCHAR(255),
        num_bc_tl                                   NVARCHAR(255),
        num_il_tl                                   NVARCHAR(255),
        num_op_rev_tl                               NVARCHAR(255),
        num_rev_accts                               NVARCHAR(255),
        num_rev_tl_bal_gt_0                         NVARCHAR(255),
        num_sats                                    NVARCHAR(255),
        num_tl_120dpd_2m                            NVARCHAR(255),
        num_tl_30dpd                                NVARCHAR(255),
        num_tl_90g_dpd_24m                          NVARCHAR(255),
        num_tl_op_past_12m                          NVARCHAR(255),
        pct_tl_nvr_dlq                              NVARCHAR(255),
        percent_bc_gt_75                            NVARCHAR(255),
        pub_rec_bankruptcies                        NVARCHAR(255),
        tax_liens                                   NVARCHAR(255),
        tot_hi_cred_lim                             NVARCHAR(255),
        total_bal_ex_mort                           NVARCHAR(255),
        total_bc_limit                              NVARCHAR(255),
        total_il_high_credit_limit                  NVARCHAR(255),
        revol_bal_joint                             NVARCHAR(255),
        sec_app_earliest_cr_line                    NVARCHAR(255),
        sec_app_inq_last_6mths                      NVARCHAR(255),
        sec_app_mort_acc                            NVARCHAR(255),
        sec_app_open_acc                            NVARCHAR(255),
        sec_app_revol_util                          NVARCHAR(255),
        sec_app_open_act_il                         NVARCHAR(255),
        sec_app_num_rev_accts                       NVARCHAR(255),
        sec_app_chargeoff_within_12_mths            NVARCHAR(255),
        sec_app_collections_12_mths_ex_med          NVARCHAR(255),
        sec_app_mths_since_last_major_derog         NVARCHAR(255),
        hardship_flag                               NVARCHAR(255),
        hardship_type                               NVARCHAR(255),
        hardship_reason                             NVARCHAR(255),
        hardship_status                             NVARCHAR(255),
        deferral_term                               NVARCHAR(255),
        hardship_amount                             NVARCHAR(255),
        hardship_start_date                         NVARCHAR(255),
        hardship_end_date                           NVARCHAR(255),
        payment_plan_start_date                     NVARCHAR(255),
        hardship_length                             NVARCHAR(255),
        hardship_dpd                                NVARCHAR(255),
        hardship_loan_status                        NVARCHAR(255),
        orig_projected_additional_accrued_interest  NVARCHAR(255),
        hardship_payoff_balance_amount              NVARCHAR(255),
        hardship_last_payment_amount                NVARCHAR(255),
        debt_settlement_flag                        NVARCHAR(255),
        debt_settlement_flag_date                   NVARCHAR(255),
        settlement_status                           NVARCHAR(255),
        settlement_date                             NVARCHAR(255),
        settlement_amount                           NVARCHAR(255),
        settlement_percentage                       NVARCHAR(255),
        settlement_term                             NVARCHAR(255)
    );
END
GO

-- Source 2: Reference (US states -> geographic hierarchy)
IF OBJECT_ID('bronze.ref_us_states', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.ref_us_states (
        state_code  NVARCHAR(10),
        state_name  NVARCHAR(100),
        region      NVARCHAR(50),
        division    NVARCHAR(50)
    );
END
GO
