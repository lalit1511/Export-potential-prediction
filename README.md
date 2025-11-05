# 🧭 Export Potential Analysis (EPA) – SQL & Data Modeling Project

## 📘 Overview
This project implements the **Export Potential Assessment (EPA)** methodology to identify high-potential export products and markets using **2021 global trade data**.

The analysis leverages **SQL-based computation** of trade indicators such as market share, trade balance, and normalized export potential, following the equations from the official *EPA Methodology Document (2023)*.

---

## 🧮 Project Objectives
- Evaluate a country’s **export potential** at the product (HS code) level.  
- Quantify trade performance using the indicators:  
  - **TBik** → Trade Balance Index  
  - **MSik** → Projected Market Share  
  - **Vijk** → Export Potential Value (Equations 2 & 3)  
- Combine data from multiple sources (trade, GDP) to project **supply-side strength** and **market attractiveness**.

---

## 🗂️ Datasets Used
| Dataset | Description | Source |
|----------|--------------|--------|
| `world_trade_2021_final_table` | Global import/export values by country and HS code | UN Comtrade / ITC Trade Map |
| `final_gdp_table` | GDP data for 2021 & projected GDP for 2026 | World Bank / IMF |
| `Vijk_Terms_Table_2021_final` | Preprocessed export flow matrix used for Equation 2 | Derived from trade data |

---

## ⚙️ Methodology & Equations

### 1️⃣ Trade Balance Indicator (TBik)
\[
TB_{ik} = \min\left(\frac{X_{ik}}{M_{ik}}, 1\right)
\]
- Measures export-import ratio capped at 1.  
- **SQL Output →** `Supply_TBik_Table`

---

### 2️⃣ Export Potential Value (Vijk)
\[
V_{ijk}^{(2)} = Global\_Share \times \left(\frac{V_{ij}}{\sum_k Export\_Amount}\right) \times V_{jk}
\]  
\[
V_{ijk}^{(3)} = V_{ijk}^{(2)} \times \left(\frac{1}{Normalization\_Factor}\right)
\]
- Normalizes country-wise export potential.  
- **SQL Output →** `Vijk_Eq_2_Table` and `Vijk_Eq_3_Table`

---

### 3️⃣ Projected Market Share (MSik)
\[
MS_{ik} = \frac{Vik \times gdp_i}{\sum_i (Vik \times gdp_i)}
\]
- Combines export strength and projected GDP growth.  
- **SQL Output →** `Supply_MSik_Table`

---

### 4️⃣ Supply Potential
\[
Supply_{ik} = TB_{ik} \times MS_{ik}
\]
- Final indicator representing the **export readiness** of a country for a given product.

---

## 🏗️ SQL Workflow Summary
| Step | Table Name | Purpose |
|------|-------------|----------|
| 1 | `Supply_TBik_Table` | Calculates Export-Import ratio (TBik) |
| 2 | `Vijk_Eq_2_Table` | Equation 2 – Base export potential |
| 3 | `Vijk_Eq_3_Table` | Equation 3 – Normalized export potential |
| 4 | `Supply_MSik_Table` | Projected Market Share (MSik) |
| 5 | `Supply_ik_Final` | Combines TBik × MSik to calculate final supply index |

---

## 🧠 Tools & Technologies
- **SQL** (CTE-based calculations)
- **Python / Pandas** (for data cleaning & visualization, optional)
- **Google Colab / MySQL Workbench**
- **Data Visualization:** Matplotlib / Power BI (optional)

---

## 📊 Key Insights
- Identifies products (HS codes) with **strong export potential**.  
- Highlights countries that can **expand trade** based on GDP growth and supply strength.  
- Provides a **quantitative trade modeling framework** reusable for other years.

---

## 📁 Repository Structure
├── SQL_Scripts/
│ ├── TBik_Calculation.sql
│ ├── Vijk_Equation_2.sql
│ ├── Vijk_Equation_3.sql
│ ├── MSik_Calculation.sql
│ └── Supply_ik_Final.sql
├── Data/
│ ├── world_trade_2021_final_table.csv
│ ├── final_gdp_table.csv
│ └── Vijk_Terms_Table_2021_final.csv
├── EPA_Methodology_2023.pdf
├── README.md
└── results/
├── supply_potential_summary.csv
└── visualizations/


## ⭐ Acknowledgements
- **EPA Methodology 2023 (ITC / UNCTAD Framework)**  
- **UN Comtrade Database** for trade statistics  
- **World Bank / IMF** for GDP projections  
