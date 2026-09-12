# 📦 DataCo Smart Supply Chain — Data Analysis Project

## 📌 Project Overview
End-to-end analysis of the DataCo Smart Supply Chain dataset covering SQL,
Python EDA, Predictive Modeling, and a Statistical/Dashboard report.

## 📁 Dataset
- **Source:** Kaggle — "DataCo Smart Supply Chain for Big Data Analysis"
- **Rows:** 180,519 order lines | **Unique Orders:** 65,752 | **Markets:** 5
- **Date Range:** 2015-01-01 to 2018-01-31
- **Secondary file:** `tokenized_access_logs.csv` — 469,977 website browsing events (Sep 2017–Jan 2018)
- **Key fields:** Sales, Order Profit Per Order, Order Status, Category Name,
                  Customer Segment, Shipping Mode, Late Delivery Risk, Market

## 🛠️ Tools Used
| Tool | Purpose |
|------|---------|
| Microsoft Excel | Dashboard summarizing key tables |
| SQL Server (SSMS) | Data querying, aggregation, schema & import |
| Python (pandas / scikit-learn) | Descriptive, diagnostic, predictive & prescriptive analysis |
| Libraries | Pandas, NumPy, Matplotlib, Scipy, Scikit-learn |

## ✅ Tasks Completed

### 💾 SQL (SSMS)
- Schema creation (`SupplyChainOrders`, `AccessLogs`) and flat-file import
- Business overview aggregates (orders, sales, profit, fraud, late delivery rate)
- GROUP BY performance breakdowns (by market, category, segment)
- CASE statements and subqueries for diagnostic checks
- Window functions for ranking top categories/markets

### 🐍 Python
- Descriptive analysis — overview metrics, sales by market/category/segment, monthly trend
- Diagnostic analysis — browse-to-buy conversion, shipping mode diagnosis, fraud by payment type
- Predictive analysis — fraud detection & late-delivery-risk models (Random Forest)
- Prescriptive analysis — recommendations derived from model feature importances
- Chart generation (monthly sales, top categories, conversion index, shipping gap, confusion matrix)

### 📐 Statistics & Modeling
- Feature importance ranking for fraud and late-delivery models
- Confusion matrix and ROC-AUC evaluation for the fraud classifier
- Fraud detection — payment `Type` alone explains ~94% of feature importance
- Late delivery risk — driven mainly by scheduled shipping days (46%) and shipping mode (43%)

### 📊 Reporting
- Excel dashboard summarizing key tables (`reports/DataCo_Analysis_Dashboard.xlsx`)
- Written statistical report with methodology & findings (`reports/DataCo_Statistical_Report.docx`)

## 📸 Dashboard Preview
![Dashboard](https://github.com/AJ59-GIT/dataco-supply-chain-analysis/blob/main/Image/Excel_Dashboard.png)

## 🔍 Key Findings
- Suspected fraud (4,062 orders) occurs exclusively on `TRANSFER` payment orders
- Late delivery affects 54.8% of orders — largely determined at order time by shipping mode/schedule
- A handful of categories and markets drive the majority of total sales ($36.78M)
- Random Forest models achieve strong separation for both fraud and late-delivery prediction

## 🚀 Setup
```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
python -m venv venv && source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
cd src && python dataco_analysis.py
```
> Place `DataCoSupplyChainDataset.csv` and `tokenized_access_logs.csv` (from Kaggle) next to `src/dataco_analysis.py` before running.

## 📂 Repository Structure
```
├── src/dataco_analysis.py
├── sql/DataCo_Analysis_SSMS.sql
├── outputs/               # generated CSVs + charts/
├── reports/               # Excel dashboard + Word report
├── requirements.txt
└── README.md
```

## 👤 Author
**AJ Chauhan**
- GitHub: github.com/AJ59-GIT
- LinkedIn: linkedin.com/in/anjeetchauhan
