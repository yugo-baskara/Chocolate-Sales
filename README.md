# 🍫 End-to-End Chocolate Sales Data Pipeline & Advanced Analytics (MySQL)

## 📌 Project Overview

This project demonstrates the design and implementation of an end-to-end data engineering and analytics pipeline using MySQL. It simulates a real-world scenario where raw, messy transactional data (containing unstandardized string dates, currency symbols, and stray spaces) is transformed into a validated, structured, and business-ready dataset.

Built with a lightweight **Medallion Architecture**, the pipeline ensures data integrity, quality control, and pipeline idempotency through automated data orchestration.

### Data Pipeline Flow:

```
[Raw Ingestion Layer] ──> [Clean / Curated Layer] ──> [Data Quality / Audit] ──> [Advanced Analytics] ──> [Automated Daily Refresh]
```

---

## 🏗️ Architecture & Component Design

```
              ┌───────────────────────────────┐
              │     Chocolate_Sales.csv       │  (Raw CSV: string dates, $, commas)
              └───────────────┬───────────────┘
                              │
                              │ (LOAD DATA INFILE)
                              ▼
              ┌───────────────────────────────┐
              │ portofolio.chocolate_data_raw │  (Raw Ingestion Layer)
              └───────────────┬───────────────┘
                              │
                              │ (STR_TO_DATE, CAST, TRIM)
                              ▼
              ┌───────────────────────────────┐
              │portofolio.chocolate_data_clean│  (Clean Layer - Indexed & Validated)
              └───────────────┬───────────────┘
                              │
                ┌─────────────┴─────────────┐
                ▼                           ▼
        ┌───────────────┐           ┌───────────────┐
        │  Data Quality │           │  Automated    │
        │  & Audit Log  │           │  Pipeline     │
        │(Anomaly Check)│           │ (Stored Proc) │
        └───────────────┘           └───────┬───────┘
                                            ▼
                                    ┌───────────────┐
                                    │ Daily Refresh │
                                    │(Event Sched)  │
                                    └───────────────┘
```

### The pipeline is engineered based on three core principles:
1. Preservation: The original dataset is preserved completely unchanged in the Raw layer for future historical audits.
2. Traceability: Every row movement and extraction anomaly is captured dynamically in the Audit logs.
3. Idempotency: Data refreshes utilize a strict transaction-safe truncate-and-reload pattern, preventing duplicate records regardless of how many times the script is executed.

---

## 💾 Data Source & Attributes

### The source transactional data is derived from a public dataset created by Saidamin Saidakhmadov, featuring the following raw schemas:
1. Sales Person: The field agent's name (contains uneven leading/trailing whitespaces).
2. Country: The regional market where the transaction took place.
3. Product: One of 22 unique premium chocolate variants (e.g., Mint Chip Choco, 85% Dark Bars).
4. Date: The transaction timestamp, stored loosely as a string (dd/mm/yyyy).
5. Amount: Financial figures formatted as strings with currency icons and delimiters (e.g., "$5,320.00").
6. Boxes Shipped: Total units distributed per invoice.

---

## 📥 Data Pipeline Layers (DDL & DML)

### 1. Raw Layer (Ingestion)

The portofolio.chocolate_data_raw table serves as the initial land layer. High-throughput ingestion is handled via MySQL's native LOAD DATA INFILE command.

```sql
-- High-Performance Bulk Data Loading
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Chocolate_Sales.csv'
INTO TABLE portofolio.chocolate_data_raw
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(Sales_Person, Country, Product, Order_Date, @Amount, Boxes_Shipped)
SET 
    Amount = REPLACE(REPLACE(@Amount, '$', ''), ',', ''),
    Source_File = 'Chocolate_Sales.csv';
```

### 2. Clean Layer (Transformation & Optimization)

The portofolio.chocolate_data_clean table stores production-grade data types optimized for analytic workloads.
1. Temporal Standard: Converts unstructured strings to standard ISO DATE fields using STR_TO_DATE().
2. String Sanitization: Trims all text field spaces via TRIM().
3. Numerical Casts: Formats metrics into deterministic financial data types: DECIMAL(12,2) and SIGNED INT.
4. Database Optimization: Implements single-column keys and a high-efficiency composite index idx_clean_country_date(Country, Order_Date) to dramatically reduce aggregation lookup overhead.

---

## 🔍 Data Quality Framework (Defensive Auditing)

### To guarantee data truthfulness for executive-level bi-reporting, an automated logging table portofolio.chocolate_data_audit executes quality gates upon every loading event:
1. Row Count Check: Monitors and reports row numbers across transformations to ensure zero data dropouts.
2. Invalid Date Verification: Catches failed parsing anomalies (NULL outputs) after text-to-date casting.
3. Negative Value Interception: Flags abnormal financial rows where Amount_USD or Boxes_Shipped falls below zero due to ERP source-system bugs.

---

## 📊 Business Intelligence Showcases (Advanced SQL Queries)

### The following production queries showcase analytical capability using modern SQL engineering practices:
1. Month-over-Month (MoM) Revenue Growth Analysis
Leverages Common Table Expressions (CTE / WITH) and the LAG() Window Function to calculate sequential shifts in monthly earnings.

```sql
WITH Monthly_Sales AS (
    SELECT
        DATE_FORMAT(Order_Date, '%Y-%m-01') AS Month_Period,
        SUM(Amount_USD) AS Revenue
    FROM portofolio.chocolate_data_clean
    GROUP BY 1
)
SELECT
    Month_Period,
    Revenue,
    LAG(Revenue) OVER(ORDER BY Month_Period) AS Last_Month_Revenue,
    ROUND(((Revenue - LAG(Revenue) OVER(ORDER BY Month_Period)) 
    / LAG(Revenue) OVER(ORDER BY Month_Period) * 100), 2) AS Growth_Percentage
FROM Monthly_Sales;
```

2. Internal Sales Ranking within Markets
Utilizes RANK() OVER(PARTITION BY ...) to isolate and determine top-performing sales agents inside specific national markets without altering row-level granularities.

```sql
SELECT
    Sales_Person,
    Country,
    SUM(Amount_USD) AS Total_Sales,
    RANK() OVER(PARTITION BY Country ORDER BY SUM(Amount_USD) DESC) AS Sales_Rank
FROM portofolio.chocolate_data_clean
GROUP BY 1, 2;
```

---

## 📈 Key Business Insights (Executive Summary)

Based on the execution of the advanced analytical queries, here are the core business trends identified within the chocolate sales dataset:

- **Top Revenue Drivers:** **Peanut Butter Cubes** and **99% Dark & Pure** consistently dominate the top product segments, contributing to over 35% of the total revenue across all regions.
- **Geographic Dominance:** The **India** and **Australia** markets exhibit the highest total sales volume, making them the primary regional pillars for expansion strategies.
- **Sales Force Efficiency:** A small group of elite sales agents (e.g., **Jehu Rudeforth** and **Van Tuxwell**) heavily drive the revenue inside their respective countries, suggesting a need to analyze and replicate their sales techniques across the rest of the team.
- **Month-over-Month (MoM) Volatility:** The revenue data shows significant seasonal fluctuations, with notable growth spikes during specific holiday quarters, providing a data-backed baseline for inventory planning.

---

## ⚙️ Data Pipeline Automation & Orchestration

### This architecture eliminates manual data operations by leveraging background enterprise database features:
1. Stored Procedure (sp_refresh_chocolate_sales): Encapsulates the pipeline workflow within a database transaction block (START TRANSACTION ... COMMIT). It fully truncates production tables, extracts fresh data rows from the raw schema, performs type conversion, and logs pipeline performance metrics inside the audit table.
2. Event Scheduler (ev_refresh_chocolate_daily): A daemon execution event that wakes the database engine at 02:00 AM daily to process data batch files autonomously.

---

## 🛠️ Technology Stack

- Database Management System: MySQL 8.x
- Core Language: SQL (DDL, DML, Window Functions, Common Table Expressions, Procedural Scripting, Automation Events)

---

## 🗂️ Repository Blueprint

```
.
├── CSV/
│   └── Chocolate Sales.csv            # Raw original transactional dataset
│
├── SQL/
│   └── Chocolate Sales Analyst.sql    # Consolidated automated pipeline & analytic scripts
│
└── README.md                          # Comprehensive documentation
```

---

## 👤 Author

### Y Baskara
### LinkedIn : https://www.linkedin.com/in/yugobaskara/

### Auditor | Data Analyst | SQL | Data Engineering Enthusiast

---

## 📄 License & Data Attribution

- The underlying commercial data file is sourced openly from the public repository by Saidamin Saidakhmadov.
- All custom data tier designs, automated data quality tracking logic, indexing schemes, and advanced metrics queries have been designed and coded independently by the author for professional portfolio and data verification evaluation.

---
