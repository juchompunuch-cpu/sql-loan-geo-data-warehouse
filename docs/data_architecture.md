# Data Architecture

Medallion Architecture (Bronze → Silver → Gold) on SQL Server.

## Mapping: Business Questions → Use Case → Model

| Business question (Topic 4: Geographic dimension) | Use Case | Model |
|---|---|---|
| 4.1 Total loan amount by state (`addr_state`) | Descriptive Analytics | Data Model (Dimensional model) for Data Warehouse |
| 4.2 Average annual income (`annual_inc`) by state | Descriptive Analytics | Data Model (Dimensional model) for Data Warehouse |
| 4.3 Number of Charged Off loans (`loan_status`) by state | Descriptive Analytics | Data Model (Dimensional model) for Data Warehouse |

## Data Flow

```mermaid
flowchart LR
    subgraph Sources
        A[source_lending<br/>loan_data.csv]
        B[source_ref<br/>us_states.csv]
    end
    subgraph Bronze["Bronze (raw, tables)"]
        C[lending_loans]
        D[ref_us_states]
    end
    subgraph Silver["Silver (cleansed, tables)"]
        E[lending_loans]
        F[ref_us_states]
    end
    subgraph Gold["Gold (business, views)"]
        G[geography_dim]
        S[loan_status_dim]
        H[loans_geo_fact]
        I[report_loan_by_state]
    end
    A -->|BULK INSERT<br/>load_bronze| C
    B -->|BULK INSERT<br/>load_bronze| D
    C -->|load_silver| E
    D -->|load_silver| F
    E --> G
    F -->|region| G
    E --> S
    E --> H
    G --> H
    S --> H
    H --> I
    G --> I
    S --> I
```

| Layer  | Object type | Load method                        | Transformations |
|--------|-------------|------------------------------------|-----------------|
| Bronze | Table       | Full load (truncate + BULK INSERT) | None (as-is, all NVARCHAR) |
| Silver | Table       | Full load (truncate + insert)      | Type casting, cleansing, dedup, standardization |
| Gold   | View        | No load                            | Dimensional model (star schema), aggregation |

## Data Model (Star Schema)

![Data Model](data_model.png)

```mermaid
erDiagram
    geography_dim   ||--o{ loans_geo_fact : "geography_id"
    loan_status_dim ||--o{ loans_geo_fact : "loan_status_id"
    geography_dim {
        nvarchar zip_code
        nvarchar addr_state
        nvarchar region
        int geography_id PK
    }
    loans_geo_fact {
        decimal loan_amnt
        decimal funded_amnt
        decimal annual_inc
        int geography_id FK
        int loan_status_id FK
    }
    loan_status_dim {
        nvarchar loan_status
        int loan_status_id PK
    }
```
