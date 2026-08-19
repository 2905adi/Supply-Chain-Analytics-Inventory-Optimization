USE inventory_optimization;

-- ============================================================
-- 07_management_decision_outputs.sql
-- Final management decision and action layer
-- ============================================================


-- 1. Executive inventory KPI summary

SELECT
    COUNT(DISTINCT SKU_ID) AS total_skus,
    COUNT(DISTINCT Warehouse_ID) AS total_warehouses,
    ROUND(AVG(Units_Sold), 2) AS avg_daily_demand,
    ROUND(AVG(Inventory_Level), 2) AS avg_inventory,
    ROUND(SUM(Unit_Cost * Inventory_Level), 2) AS inventory_value,
    SUM(Stockout_Flag) AS stockout_days,
    SUM(Order_Quantity > 0) AS replenishment_events,
    ROUND(100 * AVG(Promotion_Flag), 2) AS promotion_rate
FROM inventory_raw;


-- 2. SKU-Warehouse action matrix

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
)
SELECT
    SKU_ID,
    Warehouse_ID,
    ROUND(inventory_value, 2) AS inventory_value,
    ROUND(inventory / NULLIF(demand, 0), 2) AS days_of_cover,
    ROUND(100 * stockout_rate, 2) AS stockout_rate,
    CASE
        WHEN inventory < reorder_point
             OR inventory / NULLIF(demand, 0) < lead_time
            THEN 'EXPEDITE REPLENISHMENT'

        WHEN inventory / NULLIF(demand, 0) > lead_time * 2
            THEN 'REDUCE / HOLD ORDERS'

        WHEN stockout_rate > 0
            THEN 'REVIEW SERVICE LEVEL'

        ELSE 'MONITOR'
    END AS recommended_action
FROM metrics
ORDER BY
    CASE
        WHEN inventory < reorder_point
             OR inventory / NULLIF(demand, 0) < lead_time THEN 1
        WHEN inventory / NULLIF(demand, 0) > lead_time * 2 THEN 2
        WHEN stockout_rate > 0 THEN 3
        ELSE 4
    END,
    inventory_value DESC;


-- 3. Highest-value inventory requiring attention

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
    ROUND(inventory_value, 2) AS inventory_value,
    ROUND(inventory / NULLIF(demand, 0), 2) AS days_of_cover,
    ROUND(reorder_point, 2) AS reorder_point,
    ROUND(lead_time, 2) AS lead_time,
    CASE
        WHEN inventory < reorder_point
            THEN 'UNDERSTOCK'
        WHEN inventory / NULLIF(demand, 0) > lead_time * 2
            THEN 'OVERSTOCK'
        ELSE 'BALANCED'
    END AS inventory_status
FROM metrics
WHERE
    inventory < reorder_point
    OR inventory / NULLIF(demand, 0) > lead_time * 2
ORDER BY inventory_value DESC
LIMIT 20;


-- 4. Warehouse management priorities

WITH warehouse_metrics AS (
    SELECT
        Warehouse_ID,
        AVG(Units_Sold) AS demand,
        AVG(Inventory_Level) AS inventory,
        SUM(Unit_Cost * Inventory_Level) AS inventory_value,
        AVG(Stockout_Flag) AS stockout_rate
    FROM inventory_raw
    GROUP BY Warehouse_ID
)
SELECT
    Warehouse_ID,
    ROUND(demand, 2) AS avg_daily_demand,
    ROUND(inventory, 2) AS avg_inventory,
    ROUND(inventory_value, 2) AS inventory_value,
    ROUND(100 * stockout_rate, 2) AS stockout_rate,
    CASE
        WHEN stockout_rate > 0.01
            THEN 'HIGH SERVICE RISK'
        WHEN inventory / NULLIF(demand, 0) > 25
            THEN 'HIGH INVENTORY'
        ELSE 'STABLE'
    END AS warehouse_priority
FROM warehouse_metrics
ORDER BY inventory_value DESC;


-- 5. Inventory opportunity by action

WITH metrics AS (
    SELECT
        SKU_ID,
        Warehouse_ID,
        AVG(Units_Sold) AS demand,
        AVG(Inventory_Level) AS inventory,
        AVG(Reorder_Point) AS reorder_point,
        AVG(Supplier_Lead_Time_Days) AS lead_time,
        AVG(Unit_Cost) AS unit_cost
    FROM inventory_raw
    GROUP BY SKU_ID, Warehouse_ID
),
actions AS (
    SELECT
        *,
        CASE
            WHEN inventory < reorder_point
                THEN 'Replenishment Opportunity'
            WHEN inventory / NULLIF(demand, 0) > lead_time * 2
                THEN 'Excess Inventory Opportunity'
            ELSE 'No Immediate Action'
        END AS action_type
    FROM metrics
)
SELECT
    action_type,
    COUNT(*) AS sku_warehouse_pairs,
    ROUND(
        SUM(
            CASE
                WHEN action_type = 'Replenishment Opportunity'
                    THEN (reorder_point - inventory) * unit_cost
                WHEN action_type = 'Excess Inventory Opportunity'
                    THEN (inventory - reorder_point) * unit_cost
                ELSE 0
            END
        ), 2
    ) AS estimated_inventory_value
FROM actions
GROUP BY action_type
ORDER BY estimated_inventory_value DESC;


-- 6. Final prioritized action list

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
prioritized AS (
    SELECT
        *,
        CASE
            WHEN inventory < reorder_point
                 AND stockout_rate > 0
                THEN 'CRITICAL - REPLENISH'

            WHEN inventory < reorder_point
                 OR inventory / NULLIF(demand, 0) < lead_time
                THEN 'HIGH - REPLENISH'

            WHEN inventory / NULLIF(demand, 0) > lead_time * 2
                THEN 'HIGH - REDUCE INVENTORY'

            WHEN stockout_rate > 0
                THEN 'MEDIUM - REVIEW SERVICE'

            ELSE 'LOW - MONITOR'
        END AS priority_action
    FROM metrics
)
SELECT
    SKU_ID,
    Warehouse_ID,
    ROUND(inventory_value, 2) AS inventory_value,
    ROUND(inventory / NULLIF(demand, 0), 2) AS days_of_cover,
    ROUND(100 * stockout_rate, 2) AS stockout_rate,
    priority_action
FROM prioritized
WHERE priority_action <> 'LOW - MONITOR'
ORDER BY
    CASE
        WHEN priority_action LIKE 'CRITICAL%' THEN 1
        WHEN priority_action LIKE 'HIGH%' THEN 2
        ELSE 3
    END,
    inventory_value DESC
LIMIT 30;

USE inventory_optimization;

USE inventory_optimization;

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
)
SELECT
    COUNT(*) AS total_sku_warehouse_pairs,
    SUM(inventory < reorder_point) AS below_reorder_point,
    SUM(inventory / NULLIF(demand, 0) < lead_time) AS below_lead_time_cover,
    SUM(inventory / NULLIF(demand, 0) > lead_time * 2) AS high_cover,
    SUM(stockout_rate > 0) AS with_stockouts
FROM metrics;