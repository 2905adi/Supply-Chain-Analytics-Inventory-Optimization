USE inventory_optimization;

-- ============================================================
-- 06_inventory_risk_optimization.sql
-- Inventory risk scoring and optimization priorities
-- ============================================================


-- 1. SKU-Warehouse risk profile

WITH metrics AS (
    SELECT
        SKU_ID,
        Warehouse_ID,
        AVG(Units_Sold) AS demand,
        AVG(Inventory_Level) AS inventory,
        AVG(Reorder_Point) AS reorder_point,
        AVG(Supplier_Lead_Time_Days) AS lead_time,
        SUM(Unit_Cost * Inventory_Level) AS inventory_value
    FROM inventory_raw
    GROUP BY SKU_ID, Warehouse_ID
)
SELECT
    SKU_ID,
    Warehouse_ID,
    ROUND(demand, 2) AS avg_demand,
    ROUND(inventory, 2) AS avg_inventory,
    ROUND(reorder_point, 2) AS reorder_point,
    ROUND(lead_time, 2) AS lead_time,
    ROUND(inventory / NULLIF(demand, 0), 2) AS days_of_cover,
    ROUND(inventory_value, 2) AS inventory_value,
    CASE
        WHEN inventory < reorder_point
            THEN 'Understock'
        WHEN inventory / NULLIF(demand, 0) < lead_time
            THEN 'Lead-Time Risk'
        WHEN inventory / NULLIF(demand, 0) > lead_time * 2
            THEN 'Overstock'
        ELSE 'Balanced'
    END AS inventory_status
FROM metrics
ORDER BY inventory_value DESC;


-- 2. Understock exposure

SELECT
    SKU_ID,
    Warehouse_ID,
    ROUND(AVG(Inventory_Level), 2) AS avg_inventory,
    ROUND(AVG(Reorder_Point), 2) AS reorder_point,
    ROUND(
        AVG(Reorder_Point - Inventory_Level), 2
    ) AS inventory_gap,
    ROUND(
        AVG(
            CASE
                WHEN Inventory_Level < Reorder_Point
                THEN (Reorder_Point - Inventory_Level) * Unit_Cost
                ELSE 0
            END
        ), 2
    ) AS estimated_gap_value
FROM inventory_raw
GROUP BY SKU_ID, Warehouse_ID
HAVING AVG(Inventory_Level) < AVG(Reorder_Point)
ORDER BY estimated_gap_value DESC;


-- 3. Overstock exposure

SELECT
    SKU_ID,
    Warehouse_ID,
    ROUND(AVG(Inventory_Level), 2) AS avg_inventory,
    ROUND(AVG(Units_Sold), 2) AS avg_demand,
    ROUND(
        AVG(Inventory_Level) /
        NULLIF(AVG(Units_Sold), 0), 2
    ) AS days_of_cover,
    ROUND(
        AVG(
            CASE
                WHEN Inventory_Level >
                     Reorder_Point * 1.5
                THEN (Inventory_Level - Reorder_Point) * Unit_Cost
                ELSE 0
            END
        ), 2
    ) AS excess_inventory_value
FROM inventory_raw
GROUP BY SKU_ID, Warehouse_ID
HAVING AVG(Inventory_Level) > AVG(Reorder_Point) * 1.5
ORDER BY excess_inventory_value DESC;


-- 4. Stockout risk by SKU-Warehouse

SELECT
    SKU_ID,
    Warehouse_ID,
    SUM(Stockout_Flag) AS stockout_days,
    COUNT(*) AS total_days,
    ROUND(
        100 * AVG(Stockout_Flag), 2
    ) AS stockout_rate,
    ROUND(AVG(Units_Sold), 2) AS avg_demand,
    ROUND(AVG(Inventory_Level), 2) AS avg_inventory
FROM inventory_raw
GROUP BY SKU_ID, Warehouse_ID
HAVING SUM(Stockout_Flag) > 0
ORDER BY stockout_rate DESC, stockout_days DESC;


-- 5. Composite inventory priority score

WITH metrics AS (
    SELECT
        SKU_ID,
        Warehouse_ID,
        AVG(Units_Sold) AS demand,
        AVG(Inventory_Level) AS inventory,
        AVG(Reorder_Point) AS reorder_point,
        AVG(Supplier_Lead_Time_Days) AS lead_time,
        AVG(Stockout_Flag) AS stockout_rate,
        SUM(Unit_Cost * Inventory_Level) AS inventory_value
    FROM inventory_raw
    GROUP BY SKU_ID, Warehouse_ID
),
scored AS (
    SELECT
        *,
        (inventory < reorder_point) AS understock_risk,
        (
            inventory / NULLIF(demand, 0) < lead_time
        ) AS lead_time_risk,
        (
            inventory / NULLIF(demand, 0) > lead_time * 2
        ) AS overstock_risk,
        (stockout_rate > 0) AS stockout_risk
    FROM metrics
)
SELECT
    SKU_ID,
    Warehouse_ID,
    ROUND(inventory_value, 2) AS inventory_value,
    ROUND(inventory / NULLIF(demand, 0), 2) AS days_of_cover,
    ROUND(100 * stockout_rate, 2) AS stockout_rate,
    (
        understock_risk +
        lead_time_risk +
        overstock_risk +
        stockout_risk
    ) AS risk_score,
    CASE
        WHEN (
            understock_risk +
            lead_time_risk +
            overstock_risk +
            stockout_risk
        ) >= 2 THEN 'High Priority'
        WHEN (
            understock_risk +
            lead_time_risk +
            overstock_risk +
            stockout_risk
        ) = 1 THEN 'Medium Priority'
        ELSE 'Low Priority'
    END AS management_priority
FROM scored
ORDER BY risk_score DESC, inventory_value DESC;


-- 6. Final optimization opportunity summary

WITH metrics AS (
    SELECT
        SKU_ID,
        Warehouse_ID,
        AVG(Inventory_Level) AS inventory,
        AVG(Reorder_Point) AS reorder_point,
        AVG(Units_Sold) AS demand,
        AVG(Unit_Cost) AS unit_cost,
        AVG(Supplier_Lead_Time_Days) AS lead_time
    FROM inventory_raw
    GROUP BY SKU_ID, Warehouse_ID
)
SELECT
    CASE
        WHEN inventory < reorder_point
            THEN 'Understock'
        WHEN inventory / NULLIF(demand, 0) > lead_time * 2
            THEN 'Overstock'
        ELSE 'Balanced'
    END AS inventory_status,
    COUNT(*) AS sku_warehouse_pairs,
    ROUND(
        SUM(
            CASE
                WHEN inventory < reorder_point
                    THEN (reorder_point - inventory) * unit_cost
                WHEN inventory / NULLIF(demand, 0) > lead_time * 2
                    THEN (inventory - reorder_point) * unit_cost
                ELSE 0
            END
        ), 2
    ) AS estimated_opportunity_value
FROM metrics
GROUP BY inventory_status
ORDER BY estimated_opportunity_value DESC;