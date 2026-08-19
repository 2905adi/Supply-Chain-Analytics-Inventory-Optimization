/* ============================================================
PROJECT : Inventory Optimization & Replenishment System
SCRIPT  : 04_demand_forecast_analysis.sql
PURPOSE : Demand variability and forecast performance analysis

============================================================ */

USE inventory_optimization;


-- ============================================================
-- 1. Overall Demand & Forecast Performance
-- ============================================================

SELECT
    COUNT(*) AS total_records,
    ROUND(AVG(Units_Sold), 2) AS avg_daily_demand,
    ROUND(STDDEV_POP(Units_Sold), 2) AS demand_std_dev,
    ROUND(AVG(Demand_Forecast), 2) AS avg_forecast,
    ROUND(AVG(ABS(Units_Sold - Demand_Forecast)), 2) AS forecast_mae,
    ROUND(
        100 * AVG(ABS(Units_Sold - Demand_Forecast))
        / NULLIF(AVG(Units_Sold), 0),
        2
    ) AS forecast_error_pct
FROM inventory_raw;


-- ============================================================
-- 2. SKU-Level Demand Volatility
-- ============================================================

SELECT
    SKU_ID,
    ROUND(AVG(Units_Sold), 2) AS avg_daily_demand,
    ROUND(STDDEV_POP(Units_Sold), 2) AS demand_std_dev,
    ROUND(
        STDDEV_POP(Units_Sold)
        / NULLIF(AVG(Units_Sold), 0),
        3
    ) AS demand_cv,
    ROUND(SUM(Units_Sold), 0) AS total_demand
FROM inventory_raw
GROUP BY SKU_ID
ORDER BY demand_cv DESC;


-- ============================================================
-- 3. SKU-Warehouse Forecast Accuracy
-- ============================================================

SELECT
    SKU_ID,
    Warehouse_ID,
    ROUND(AVG(Units_Sold), 2) AS avg_demand,
    ROUND(AVG(Demand_Forecast), 2) AS avg_forecast,
    ROUND(
        AVG(ABS(Units_Sold - Demand_Forecast)),
        2
    ) AS forecast_mae,
    ROUND(
        100 * AVG(ABS(Units_Sold - Demand_Forecast))
        / NULLIF(AVG(Units_Sold), 0),
        2
    ) AS forecast_error_pct
FROM inventory_raw
GROUP BY SKU_ID, Warehouse_ID
ORDER BY forecast_error_pct DESC
LIMIT 20;


-- ============================================================
-- 4. Demand Volatility Segmentation
-- ============================================================

WITH demand_metrics AS (
    SELECT
        SKU_ID,
        AVG(Units_Sold) AS avg_demand,
        STDDEV_POP(Units_Sold) AS demand_std
    FROM inventory_raw
    GROUP BY SKU_ID
)

SELECT
    SKU_ID,
    ROUND(avg_demand, 2) AS avg_demand,
    ROUND(demand_std, 2) AS demand_std,
    ROUND(
        demand_std / NULLIF(avg_demand, 0),
        3
    ) AS demand_cv,
    CASE
        WHEN demand_std / NULLIF(avg_demand, 0) >= 0.47
            THEN 'High Volatility'
        WHEN demand_std / NULLIF(avg_demand, 0) >= 0.44
            THEN 'Medium Volatility'
        ELSE 'Low Volatility'
    END AS volatility_segment
FROM demand_metrics
ORDER BY demand_cv DESC;


-- ============================================================
-- 5. Promotion Impact on Demand
-- ============================================================

SELECT
    Promotion_Flag,
    COUNT(*) AS records,
    ROUND(AVG(Units_Sold), 2) AS avg_demand,
    ROUND(AVG(Demand_Forecast), 2) AS avg_forecast,
    ROUND(
        AVG(Units_Sold - Demand_Forecast),
        2
    ) AS avg_forecast_bias
FROM inventory_raw
GROUP BY Promotion_Flag
ORDER BY Promotion_Flag;


-- ============================================================
-- 6. Stockout & Forecast Risk Analysis
-- ============================================================

SELECT
    Stockout_Flag,
    COUNT(*) AS records,
    ROUND(AVG(Units_Sold), 2) AS avg_demand,
    ROUND(AVG(Inventory_Level), 2) AS avg_inventory,
    ROUND(AVG(Demand_Forecast), 2) AS avg_forecast,
    ROUND(
        AVG(ABS(Units_Sold - Demand_Forecast)),
        2
    ) AS forecast_mae,
    ROUND(
        AVG(Inventory_Level - Reorder_Point),
        2
    ) AS avg_inventory_buffer
FROM inventory_raw
GROUP BY Stockout_Flag
ORDER BY Stockout_Flag;


-- ============================================================
-- 7. Highest-Risk SKU-Warehouse Combinations
-- ============================================================

WITH demand_risk AS (
    SELECT
        SKU_ID,
        Warehouse_ID,
        AVG(Units_Sold) AS avg_demand,
        STDDEV_POP(Units_Sold) AS demand_std,
        AVG(Demand_Forecast) AS avg_forecast,
        AVG(Inventory_Level) AS avg_inventory,
        AVG(Reorder_Point) AS avg_reorder_point
    FROM inventory_raw
    GROUP BY SKU_ID, Warehouse_ID
)

SELECT
    SKU_ID,
    Warehouse_ID,
    ROUND(avg_demand, 2) AS avg_demand,
    ROUND(
        demand_std / NULLIF(avg_demand, 0),
        3
    ) AS demand_cv,
    ROUND(
        ABS(avg_demand - avg_forecast),
        2
    ) AS forecast_gap,
    ROUND(avg_inventory, 2) AS avg_inventory,
    ROUND(avg_reorder_point, 2) AS avg_reorder_point,
    CASE
        WHEN avg_inventory < avg_reorder_point
             AND demand_std / NULLIF(avg_demand, 0) >= 0.47
            THEN 'Critical'
        WHEN avg_inventory < avg_reorder_point
            THEN 'Replenishment Risk'
        WHEN demand_std / NULLIF(avg_demand, 0) >= 0.47
            THEN 'Demand Risk'
        ELSE 'Normal'
    END AS risk_status
FROM demand_risk
ORDER BY
    CASE
        WHEN avg_inventory < avg_reorder_point
             AND demand_std / NULLIF(avg_demand, 0) >= 0.47 THEN 1
        WHEN avg_inventory < avg_reorder_point THEN 2
        WHEN demand_std / NULLIF(avg_demand, 0) >= 0.47 THEN 3
        ELSE 4
    END,
    demand_cv DESC;
