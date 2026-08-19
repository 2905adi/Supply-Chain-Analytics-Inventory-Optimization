USE inventory_optimization;


-- 1. Executive decision summary

SELECT
    COUNT(DISTINCT SKU_ID) AS skus,
    COUNT(DISTINCT Warehouse_ID) AS warehouses,
    ROUND(SUM(Unit_Cost * Inventory_Level), 2) AS inventory_value,
    ROUND(AVG(Inventory_Level / NULLIF(Units_Sold, 0)), 2) AS avg_days_cover,
    SUM(Stockout_Flag) AS stockout_days,
    ROUND(100 * AVG(Promotion_Flag), 2) AS promotion_rate
FROM inventory_raw;


-- 2. SKU-Warehouse decision profile

WITH m AS (
    SELECT
        SKU_ID,
        Warehouse_ID,
        AVG(Units_Sold) AS demand,
        AVG(Inventory_Level) AS inventory,
        AVG(Reorder_Point) AS reorder_point,
        AVG(Supplier_Lead_Time_Days) AS lead_time,
        AVG(Demand_Forecast) AS forecast,
        AVG(ABS(Units_Sold - Demand_Forecast)) AS forecast_error,
        SUM(Unit_Cost * Inventory_Level) AS inventory_value,
        AVG(Promotion_Flag) AS promotion_rate
    FROM inventory_raw
    GROUP BY SKU_ID, Warehouse_ID
)
SELECT
    SKU_ID,
    Warehouse_ID,
    ROUND(inventory_value, 2) AS inventory_value,
    ROUND(inventory / NULLIF(demand, 0), 2) AS days_cover,
    ROUND(reorder_point, 2) AS reorder_point,
    ROUND(lead_time, 2) AS lead_time,
    ROUND(forecast_error, 2) AS forecast_error,
    ROUND(100 * promotion_rate, 1) AS promotion_rate
FROM m
ORDER BY inventory_value DESC
LIMIT 20;


-- 3. Inventory concentration by warehouse

SELECT
    Warehouse_ID,
    ROUND(SUM(Unit_Cost * Inventory_Level), 2) AS inventory_value,
    ROUND(AVG(Inventory_Level / NULLIF(Units_Sold, 0)), 2) AS avg_days_cover,
    ROUND(AVG(Reorder_Point), 2) AS avg_reorder_point,
    ROUND(AVG(Supplier_Lead_Time_Days), 2) AS avg_lead_time,
    SUM(Stockout_Flag) AS stockout_days
FROM inventory_raw
GROUP BY Warehouse_ID
ORDER BY inventory_value DESC;


-- 4. Potential excess inventory

WITH m AS (
    SELECT
        SKU_ID,
        Warehouse_ID,
        AVG(Units_Sold) AS demand,
        AVG(Inventory_Level) AS inventory,
        AVG(Reorder_Point) AS reorder_point,
        AVG(Demand_Forecast) AS forecast,
        SUM(Unit_Cost * Inventory_Level) AS inventory_value
    FROM inventory_raw
    GROUP BY SKU_ID, Warehouse_ID
),
ranked AS (
    SELECT
        *,
        NTILE(4) OVER (
            ORDER BY inventory / NULLIF(demand, 0)
        ) AS cover_quartile
    FROM m
)
SELECT
    SKU_ID,
    Warehouse_ID,
    ROUND(inventory_value, 2) AS inventory_value,
    ROUND(inventory / NULLIF(demand, 0), 2) AS days_cover,
    ROUND(reorder_point, 2) AS reorder_point,
    ROUND(forecast, 2) AS forecast,
    CASE
        WHEN cover_quartile = 4
             AND inventory > reorder_point
            THEN 'REVIEW EXCESS'
        ELSE 'NORMAL'
    END AS action
FROM ranked
WHERE cover_quartile = 4
ORDER BY inventory_value DESC;


-- 5. Management action summary

WITH m AS (
    SELECT
        SKU_ID,
        Warehouse_ID,
        AVG(Units_Sold) AS demand,
        AVG(Inventory_Level) AS inventory,
        AVG(Reorder_Point) AS reorder_point,
        SUM(Unit_Cost * Inventory_Level) AS inventory_value,
        AVG(Stockout_Flag) AS stockout_rate
    FROM inventory_raw
    GROUP BY SKU_ID, Warehouse_ID
),
r AS (
    SELECT
        *,
        NTILE(4) OVER (
            ORDER BY inventory / NULLIF(demand, 0)
        ) AS cover_quartile
    FROM m
)
SELECT
    CASE
        WHEN inventory < reorder_point
            THEN 'REPLENISH'
        WHEN stockout_rate > 0
            THEN 'SERVICE REVIEW'
        WHEN cover_quartile = 4
             AND inventory > reorder_point
            THEN 'EXCESS INVENTORY REVIEW'
        ELSE 'MONITOR'
    END AS management_action,
    COUNT(*) AS sku_warehouse_pairs,
    ROUND(SUM(inventory_value), 2) AS inventory_value
FROM r
GROUP BY management_action
ORDER BY inventory_value DESC;


-- 6. Final priority list

WITH m AS (
    SELECT
        SKU_ID,
        Warehouse_ID,
        AVG(Units_Sold) AS demand,
        AVG(Inventory_Level) AS inventory,
        AVG(Reorder_Point) AS reorder_point,
        AVG(Stockout_Flag) AS stockout_rate,
        SUM(Unit_Cost * Inventory_Level) AS inventory_value
    FROM inventory_raw
    GROUP BY SKU_ID, Warehouse_ID
),
r AS (
    SELECT
        *,
        NTILE(4) OVER (
            ORDER BY inventory / NULLIF(demand, 0)
        ) AS cover_quartile
    FROM m
)
SELECT
    SKU_ID,
    Warehouse_ID,
    ROUND(inventory_value, 2) AS inventory_value,
    ROUND(inventory / NULLIF(demand, 0), 2) AS days_cover,
    CASE
        WHEN inventory < reorder_point
            THEN 'HIGH - REPLENISH'
        WHEN stockout_rate > 0
            THEN 'MEDIUM - SERVICE REVIEW'
        WHEN cover_quartile = 4
            THEN 'MEDIUM - EXCESS REVIEW'
        ELSE 'LOW - MONITOR'
    END AS priority_action
FROM r
WHERE
    inventory < reorder_point
    OR stockout_rate > 0
    OR cover_quartile = 4
ORDER BY inventory_value DESC
LIMIT 30;

