# predictive-maintenance-diagnostic-vs-leakage-safe
Predictive maintenance analysis in SQL + Tableau comparing rule-based diagnostic vs leakage-safe sensor modeling (AI4I 2020).

# Predictive Maintenance: Diagnostic vs Leakage-Safe Analysis

## Executive Summary

 This project evaluates machine failure risk using two analytical perspectives:
- Diagnostic (Rule-Based) Analysis aligned with predefined failure definitions
- Leakage-Safe (Sensor-Only) Analysis using independent operational signals

While the overall machine failure rate remains constant at 3.39%, the rule-based diagnostic model produces deterministic 100% failure zones due to embedded threshold definitions within the dataset.

The leakage-safe model removes that dependency and reflects probabilistic operational risk behavior, better simulating real-world predictive analytics.

This project demonstrates the critical difference between:
- Compliance-based monitoring
- Predictive risk modeling


## Business Objective

Identify operational drivers of machine failure and estimate preventable failure reduction through:
- Maintenance optimization
- Wear monitoring
- Power regulation
- Thermal risk control

## Dataset Overview
- 10,000 machine observations
- Synthetic milling machine dataset
- Binary machine failure label
- 5 deterministic failure modes:
  - Tool Wear Failure (TWF)
  - Heat Dissipation Failure (HDF)
  - Power Failure (PWF)
  - Overstrain Failure (OSF)
  - Random Failure (RNF)

## Data Source & Attribution

This project uses the AI4I 2020 Predictive Maintenance Dataset:

Matzka, S. (2020).
Explainable Artificial Intelligence for Predictive Maintenance Applications.
2020 Third International Conference on Artificial Intelligence for Industries (AI4I).
DOI: 10.1109/AI4I49448.2020.00023

Kaggle Dataset:
https://www.kaggle.com/datasets/stephanmatzka/predictive-maintenance-dataset-ai4i-2020

The raw dataset is not included in this repository.
To reproduce this project, download the dataset directly from Kaggle.

## Analytical Framework

### 1) Diagnostic Dashboard (Rule-Based)
- Built using failure-mode aligned thresholds
- Power zones <3500W and >9000W produce deterministic failure
- Tool wear >200 minutes shows nonlinear risk escalation
- Useful for compliance enforcement and operational controls

Estimated preventable failures: 30–50%

### 2) Leakage-Safe Dashboard (Sensor-Only)
- Removes threshold-derived failure logic
- Uses only independent sensor signals
- Reflects probabilistic operational risk
- More appropriate for predictive modeling and real-world risk estimation

Estimated preventable failures: 15–25%

### 3) Comparison Dashboard

Directly contrasts:
- Deterministic trigger zones
- Probabilistic risk escalation
- KPI behavior across modeling approaches

Demonstrates the impact of data leakage on interpretation and decision-making.

## Key Findings
- Tool wear risk escalates sharply beyond ~200 minutes
- Power extremes create deterministic failures under rule logic
- Temperature interaction contributes to elevated failure probability
- Product type influences structural reliability patterns

## Operational Implications

Diagnostic Controls
- Replace tools before 200 minutes of wear
- Enforce strict power operating constraints
- Monitor thermal thresholds

Predictive Strategy
- Implement probabilistic wear scoring
- Monitor power intensity distribution
- Use multi-sensor risk scoring models

## Technical Stack
- PostgreSQL (data validation & analytical views)
- SQL (CTEs, derived fields, NTILE quartiles, aggregation)
- Tableau Public (dashboard design & KPI storytelling)
- GitHub (documentation & reproducibility)

## Repository Structure

predictive-maintenance--diagnostic-vs-leakage-safe/

│

├── sql/

│   └── predictive_maintenance_analysis.sql

│


├── tableau/

│   ├── README.md

│   ├── diagnostic_dashboard.png

│   ├── leakage_safe_dashboard.png

│   └── comparison_dashboard.png

│

└── README.md

## What This Project Demonstrates
- Manufacturing operations analytics
- SQL feature engineering
- Data leakage detection and mitigation
- Deterministic vs probabilistic modeling frameworks
- KPI engineering for executive decision-making
- Dashboard storytelling for operational leadership

## Author

Curtis Stevenson

Open to Relocation Nationwide

Manufacturing Operations Analytics
