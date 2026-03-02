-- ============================================================
-- Predictive Maintenance Analytics (AI4I 2020)
-- Author: Curtis Stevenson
-- Database: <your_db>
-- Base Table: raw_ai4i_data
--
-- Purpose:
-- 1) Validate raw data integrity
-- 2) Build two analysis views:
--    - maintenance_diagnostic       (uses rule-based failure-mode indicators -> leakage risk)
--    - maintenance_leakage_safe     (uses only raw sensor + product features)
-- 3) Create export-ready aggregated views for Tableau Public
--
-- Notes:
-- - We do NOT assume power_w or temp_diff_k exist as physical columns.
-- - We derive them inside views to keep raw table unchanged.
-- ============================================================

-- ==============================
-- 0) Quick Schema Sanity (optional)
-- ==============================
-- SELECT * FROM raw_ai4i_data LIMIT 5;

-- ==============================
-- 1) Validation Checks
-- ==============================

-- 1.1 Count rows and unique keys
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT uid) AS distinct_uid
FROM raw_ai4i_data;

-- 1.2 Check for NULLs in critical fields
SELECT
  SUM(CASE WHEN uid IS NULL THEN 1 ELSE 0 END) AS null_uid,
  SUM(CASE WHEN type IS NULL THEN 1 ELSE 0 END) AS null_type,
  SUM(CASE WHEN air_temp_k IS NULL THEN 1 ELSE 0 END) AS null_air_temp,
  SUM(CASE WHEN process_temp_k IS NULL THEN 1 ELSE 0 END) AS null_process_temp,
  SUM(CASE WHEN rotational_speed_rpm IS NULL THEN 1 ELSE 0 END) AS null_rpm,
  SUM(CASE WHEN torque_nm IS NULL THEN 1 ELSE 0 END) AS null_torque,
  SUM(CASE WHEN tool_wear_min IS NULL THEN 1 ELSE 0 END) AS null_tool_wear,
  SUM(CASE WHEN machine_failure IS NULL THEN 1 ELSE 0 END) AS null_machine_failure
FROM raw_ai4i_data;

-- 1.3 Validate expected ranges (flag out-of-range rows)
-- Adjust thresholds if needed, but these match the dataset description style.
SELECT
  SUM(CASE WHEN air_temp_k < 250 OR air_temp_k > 350 THEN 1 ELSE 0 END) AS out_air_temp,
  SUM(CASE WHEN process_temp_k < 250 OR process_temp_k > 370 THEN 1 ELSE 0 END) AS out_process_temp,
  SUM(CASE WHEN rotational_speed_rpm <= 0 THEN 1 ELSE 0 END) AS out_rpm,
  SUM(CASE WHEN torque_nm < 0 THEN 1 ELSE 0 END) AS out_torque,
  SUM(CASE WHEN tool_wear_min < 0 OR tool_wear_min > 300 THEN 1 ELSE 0 END) AS out_tool_wear
FROM raw_ai4i_data;

-- 1.4 Failure flag consistency checks
-- 1.4a machine_failure = 1 but no failure mode marked
SELECT COUNT(*) AS failure_flag_without_mode
FROM raw_ai4i_data
WHERE machine_failure = 1
  AND COALESCE(twf,0) = 0
  AND COALESCE(hdf,0) = 0
  AND COALESCE(pwf,0) = 0
  AND COALESCE(osf,0) = 0
  AND COALESCE(rnf,0) = 0;

-- 1.4b Any failure mode marked but machine_failure = 0
SELECT COUNT(*) AS mode_marked_without_failure_flag
FROM raw_ai4i_data
WHERE machine_failure = 0
  AND (
    COALESCE(twf,0) = 1
    OR COALESCE(hdf,0) = 1
    OR COALESCE(pwf,0) = 1
    OR COALESCE(osf,0) = 1
    OR COALESCE(rnf,0) = 1
  );

-- 1.5 Overall failure rate (baseline KPI)
SELECT
  ROUND(AVG(machine_failure::numeric), 4) AS overall_failure_rate,
  SUM(machine_failure) AS total_failures,
  COUNT(*) AS total_records
FROM raw_ai4i_data;

-- ==============================
-- 2) Core Derived Metrics (in-view, not stored)
-- ==============================
-- temp_diff_k = process_temp_k - air_temp_k
-- power_w = torque_nm * rotational_speed_rpm * (2*pi/60)
-- power_w uses rpm -> rad/s conversion (2π/60)

-- ==============================
-- 3) Create Diagnostic View (leakage-prone)
--    Includes failure mode columns + thresholds derived from known logic
-- ==============================
CREATE OR REPLACE VIEW maintenance_diagnostic AS
SELECT
  uid,
  product_id,
  type,

  air_temp_k,
  process_temp_k,
  (process_temp_k - air_temp_k) AS temp_diff_k,

  rotational_speed_rpm,
  torque_nm,
  (torque_nm * rotational_speed_rpm * (2 * PI() / 60)) AS power_w,

  tool_wear_min,
  machine_failure,

  -- failure modes (these create leakage if used for predictive logic)
  twf, hdf, pwf, osf, rnf,

  -- tool wear categories (threshold chosen for operational story)
  CASE
    WHEN tool_wear_min >= 200 THEN 'High Wear'
    WHEN tool_wear_min BETWEEN 100 AND 199 THEN 'Medium Wear'
    ELSE 'Low Wear'
  END AS tool_wear_category,

  -- "power band" aligned to the dataset's described failure logic thresholds
  CASE
    WHEN (torque_nm * rotational_speed_rpm * (2 * PI() / 60)) < 3500 THEN 'Low Power (Rule Failure Zone)'
    WHEN (torque_nm * rotational_speed_rpm * (2 * PI() / 60)) > 9000 THEN 'High Power (Rule Failure Zone)'
    ELSE 'Normal Power'
  END AS power_band,

  -- wear quartiles (window function showcase)
  NTILE(4) OVER (ORDER BY tool_wear_min) AS wear_quartile

FROM raw_ai4i_data;

-- ==============================
-- 4) Create Leakage-Safe View (sensor-only)
--    Removes failure-mode columns and rule-based bands derived from definitions
-- ==============================
CREATE OR REPLACE VIEW maintenance_leakage_safe AS
SELECT
  uid,
  product_id,
  type,

  air_temp_k,
  process_temp_k,
  (process_temp_k - air_temp_k) AS temp_diff_k,

  rotational_speed_rpm,
  torque_nm,
  (torque_nm * rotational_speed_rpm * (2 * PI() / 60)) AS power_w,

  tool_wear_min,
  machine_failure,

  -- still OK to categorize tool wear for analysis (not using failure-mode definitions)
  CASE
    WHEN tool_wear_min >= 200 THEN 'High Wear'
    WHEN tool_wear_min BETWEEN 100 AND 199 THEN 'Medium Wear'
    ELSE 'Low Wear'
  END AS tool_wear_category,

  NTILE(4) OVER (ORDER BY tool_wear_min) AS wear_quartile

FROM raw_ai4i_data;

-- ==============================
-- 5) Export-ready Aggregated Views for Tableau
--    These reduce "AGG()" confusion and make KPI building easy.
-- ==============================

-- 5.1 KPI baseline for each dataset version
CREATE OR REPLACE VIEW export_kpi_diagnostic AS
SELECT
  'Diagnostic' AS dataset_version,
  COUNT(*) AS total_records,
  SUM(machine_failure) AS total_failures,
  ROUND(AVG(machine_failure::numeric), 4) AS overall_failure_rate
FROM maintenance_diagnostic;

CREATE OR REPLACE VIEW export_kpi_leakage_safe AS
SELECT
  'Leakage-Safe' AS dataset_version,
  COUNT(*) AS total_records,
  SUM(machine_failure) AS total_failures,
  ROUND(AVG(machine_failure::numeric), 4) AS overall_failure_rate
FROM maintenance_leakage_safe;

-- 5.2 Failure rate by product type
CREATE OR REPLACE VIEW export_failure_by_type_diagnostic AS
SELECT
  'Diagnostic' AS dataset_version,
  type,
  COUNT(*) AS records,
  ROUND(AVG(machine_failure::numeric), 4) AS failure_rate
FROM maintenance_diagnostic
GROUP BY type;

CREATE OR REPLACE VIEW export_failure_by_type_leakage_safe AS
SELECT
  'Leakage-Safe' AS dataset_version,
  type,
  COUNT(*) AS records,
  ROUND(AVG(machine_failure::numeric), 4) AS failure_rate
FROM maintenance_leakage_safe
GROUP BY type;

-- 5.3 Failure rate by tool wear category
CREATE OR REPLACE VIEW export_failure_by_wear_category_diagnostic AS
SELECT
  'Diagnostic' AS dataset_version,
  tool_wear_category,
  COUNT(*) AS records,
  ROUND(AVG(machine_failure::numeric), 4) AS failure_rate
FROM maintenance_diagnostic
GROUP BY tool_wear_category;

CREATE OR REPLACE VIEW export_failure_by_wear_category_leakage_safe AS
SELECT
  'Leakage-Safe' AS dataset_version,
  tool_wear_category,
  COUNT(*) AS records,
  ROUND(AVG(machine_failure::numeric), 4) AS failure_rate
FROM maintenance_leakage_safe
GROUP BY tool_wear_category;

-- 5.4 Failure rate by wear quartile
CREATE OR REPLACE VIEW export_failure_by_wear_quartile_diagnostic AS
SELECT
  'Diagnostic' AS dataset_version,
  wear_quartile,
  COUNT(*) AS records,
  ROUND(AVG(machine_failure::numeric), 4) AS failure_rate
FROM maintenance_diagnostic
GROUP BY wear_quartile
ORDER BY wear_quartile;

CREATE OR REPLACE VIEW export_failure_by_wear_quartile_leakage_safe AS
SELECT
  'Leakage-Safe' AS dataset_version,
  wear_quartile,
  COUNT(*) AS records,
  ROUND(AVG(machine_failure::numeric), 4) AS failure_rate
FROM maintenance_leakage_safe
GROUP BY wear_quartile
ORDER BY wear_quartile;

-- 5.5 Power band exposure (Diagnostic only; based on rule definitions)
CREATE OR REPLACE VIEW export_failure_by_power_band_diagnostic AS
SELECT
  'Diagnostic' AS dataset_version,
  power_band,
  COUNT(*) AS records,
  ROUND(AVG(machine_failure::numeric), 4) AS failure_rate
FROM maintenance_diagnostic
GROUP BY power_band;

-- 5.6 Temperature sensitivity proxy (bin temp_diff_k to make a clean bar chart)
-- Binning temp_diff_k into integer buckets (K)
CREATE OR REPLACE VIEW export_failure_by_temp_diff_bin_leakage_safe AS
SELECT
  'Leakage-Safe' AS dataset_version,
  FLOOR(temp_diff_k)::int AS temp_diff_bin_k,
  COUNT(*) AS records,
  ROUND(AVG(machine_failure::numeric), 4) AS failure_rate
FROM maintenance_leakage_safe
GROUP BY FLOOR(temp_diff_k)::int
ORDER BY temp_diff_bin_k;

CREATE OR REPLACE VIEW export_failure_by_temp_diff_bin_diagnostic AS
SELECT
  'Diagnostic' AS dataset_version,
  FLOOR(temp_diff_k)::int AS temp_diff_bin_k,
  COUNT(*) AS records,
  ROUND(AVG(machine_failure::numeric), 4) AS failure_rate
FROM maintenance_diagnostic
GROUP BY FLOOR(temp_diff_k)::int
ORDER BY temp_diff_bin_k;

-- 5.7 Power sensitivity proxy for Leakage-Safe (bin power_w)
CREATE OR REPLACE VIEW export_failure_by_power_bin_leakage_safe AS
SELECT
  'Leakage-Safe' AS dataset_version,
  (FLOOR(power_w / 2000) * 2000)::int AS power_bin_w,
  COUNT(*) AS records,
  ROUND(AVG(machine_failure::numeric), 4) AS failure_rate
FROM maintenance_leakage_safe
GROUP BY (FLOOR(power_w / 2000) * 2000)::int
ORDER BY power_bin_w;

-- ==============================
-- 6) Final sanity checks for derived metrics exist in views
-- ==============================
SELECT
  MIN(tool_wear_min) AS min_tool_wear,
  MAX(tool_wear_min) AS max_tool_wear,
  MIN(power_w) AS min_power_w,
  MAX(power_w) AS max_power_w,
  MIN(temp_diff_k) AS min_temp_diff,
  MAX(temp_diff_k) AS max_temp_diff
FROM maintenance_diagnostic;
