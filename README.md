# SQL Analytics Portfolio

This repository showcases my ability to design **data-driven SQL systems** and leverage **AI-assisted query generation** (ChatGPT + GitHub Copilot) to accelerate analysis — while still writing clean, verifiable, production-ready code.

It contains two real-world MySQL 8+ projects focused on **data warehousing** and **marketing analytics / conversion intelligence**.

---

## Repository Contents

data-analytics-sql-ai-assisted/
│
├── SQL Queries.sql # Dimensional model + ETL logic
├── SQL_Queries 2.sql # KPI, conversion, and revenue analysis
└── README.md

---

##  1. Awards Data Warehouse  
**File:** `SQL Queries.sql`

A full dimensional model for academic and institutional award data.  
Built from a messy staging table (`stg_awards`), this script normalizes and enforces data integrity through relational design.

**Highlights**
- Designed **fact/dimension architecture**:  
  `dim_country`, `dim_affiliation`, `dim_author`, `dim_award_type`, `fact_award`
- Added **pseudo-email generation** for incomplete records (MD5-based hashing)
- Implemented **referential integrity**, indexing, and data-quality checks  
- Enables **BI dashboards & compliance analytics** (affiliation, country, award type)
- Fully **MySQL 8-compliant**, using `utf8mb4` for multilingual datasets  

**AI-assist usage:** ChatGPT for schema optimization / constraint logic and Copilot for repetitive column syntax.

---

## 2. Marketing Conversion Analytics  
**File:** `SQL_Queries 2.sql`

A complete analytics suite tracking **abstract submissions → registrations → payments**, used to measure engagement and conversion across global events.

**Highlights**
- Derived **conversion funnels** and **revenue KPIs** by user, event, country, and affiliation  
- Computed **average / stddev ticket pricing** to recommend dynamic pricing tiers  
- Segmented **new vs returning** paid users for cohort insights  
- Generated **executive summary tables:**
  - `marketing_geo_event_insights_jul2024_sep2025`
  - `marketing_country_insights_jul2024_sep2025`
  - `marketing_affiliation_insights_jul2024_sep2025`
- Modularized with **CTEs + window functions** for readability and performance  

**AI-assist usage:** Prompt-driven refactoring for nested queries, followed by manual testing and optimization.

---

## Environment Setup
- **Database:** MySQL 8 + (InnoDB, `utf8mb4` collation)  
- **Tables required:**
  - For warehouse: `stg_awards`
  - For analytics: `users`, `abstract_submissions`, `registrations`, `events`, `countries`
- **Run order:**
  1️ Execute `SQL Queries.sql` to build and populate the warehouse  
  2️ Execute `SQL_Queries 2.sql` to generate conversion and revenue insight tables  

---

## Skills Demonstrated
- Advanced SQL (CTEs, joins, window functions, rollups, constraints)  
- Data-warehouse design & ETL pipeline automation  
- KPI / conversion-funnel / revenue analytics  
- AI-assisted development (Prompt Engineering + GitHub Copilot)  
- Real-world data validation and compliance-oriented design  

---

## Why This Project Matters
AI tools don’t replace technical thinking — they amplify it.  
Every query here began as a business question, evolved through prompt-aided design, and ended as a **tested, explainable, decision-ready output**.

---

---

> 🧩 All SQL queries were developed, validated, and tested in MySQL 8 using real-world datasets.  
> AI tools (ChatGPT + GitHub Copilot) were used strictly for ideation and syntax refinement.

