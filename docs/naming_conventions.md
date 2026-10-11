# **Naming Conventions**

This document outlines the naming conventions used for schemas, tables, views, columns, and other objects in the data warehouse.

## **General Principles**

- **Naming Conventions**: Use snake_case, with lowercase letters and underscores (`_`) to separate words.
- **Language**: Use English for all names.
- **Avoid Reserved Words**: Do not use SQL reserved words as object names.

## **Table Naming Conventions**

### **Bronze Rules**
- **`<sourcesystem>_<entity>`** — names start with the source system; entity keeps its original name.
  - `<sourcesystem>`: `lending` (loan data), `ref` (reference data)
  - Example: `lending_loans`, `ref_us_states`

### **Silver Rules**
- Same as Bronze: **`<sourcesystem>_<entity>`**
  - Example: `silver.lending_loans`

### **Gold Rules**
- Star schema tables: **`<entity>_<category>`** — business-aligned name with a category suffix (as defined in the project data model).
- Report views: **`report_<entity>`**.

| Pattern     | Meaning          | Example(s)                          |
|-------------|------------------|-------------------------------------|
| `_dim`      | Dimension table  | `geography_dim`, `loan_status_dim`  |
| `_fact`     | Fact table       | `loans_geo_fact`                    |
| `report_`   | Report view      | `report_loan_by_state`              |

## **Column Naming Conventions**

### **Surrogate Keys**
- **`<entity>_id`** — e.g. `geography_id` in `geography_dim`, `loan_status_id` in `loan_status_dim`.
- The same name is used for the foreign key in the fact table.

### **Technical Columns**
- **`dwh_<column_name>`** — system-generated metadata, e.g. `dwh_create_date`.

## **Stored Procedures**

- **`load_<layer>`** — e.g. `bronze.load_bronze`, `silver.load_silver`.
