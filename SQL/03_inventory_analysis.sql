USE inventory_optimization;

-- ============================================================
-- 03_inventory_analysis.sql
-- Inventory efficiency and working-capital analysis
-- ============================================================


-- ============================================================
-- 1. Overall Inventory Performance
-- ============================================================

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT SKU_ID) AS total_skus,
    COUNT(DISTINCT Warehouse_ID) AS total_warehouses,

    ROUND(AVG(Units_Sold), 2) AS avg_daily_demand,
    ROUND(AVG(Inventory_Level), 2) AS avg_inventory,

    ROUND(
        SUM(Unit_Cost * Inventory_Level),
        2
    ) AS estimated_inventory_value,

    ROUND(
        AVG(Inventory_Level) /
        NULLIF(AVG(Units_Sold), 0),
        2
    ) AS avg_days_of_cover,

    ROUND(
        SUM(Units_Sold) /
        NULLIF(AVG(Inventory_Level), 0),
        2
    ) AS annualized_inventory_turnover

FROM inventory_raw;


-- ============================================================
-- 2. Warehouse Inventory Efficiency
-- ============================================================

SELECT
    Warehouse_ID,

    COUNT(DISTINCT SKU_ID) AS active_skus,

    ROUND(AVG(Units_Sold), 2)
        AS avg_daily_demand,

    ROUND(AVG(Inventory_Level), 2)
        AS avg_inventory,

    ROUND(AVG(Reorder_Point), 2)
        AS avg_reorder_point,

    ROUND(
        AVG(Inventory_Level) /
        NULLIF(AVG(Units_Sold), 0),
        2
    ) AS days_of_cover,

    ROUND(
        SUM(Unit_Cost * Inventory_Level),
        2
    ) AS inventory_value,

    ROUND(
        SUM(Units_Sold) /
        NULLIF(AVG(Inventory_Level), 0),
        2
    ) AS inventory_turnover

FROM inventory_raw
GROUP BY Warehouse_ID
ORDER BY inventory_value DESC;


-- ============================================================
-- 3. SKU-Warehouse Inventory Profile
-- ============================================================

WITH inventory_profile AS (

    SELECT
        SKU_ID,
        Warehouse_ID,

        AVG(Units_Sold) AS avg_daily_demand,
        AVG(Inventory_Level) AS avg_inventory,
        AVG(Reorder_Point) AS avg_reorder_point,

        AVG(Unit_Cost) AS avg_unit_cost,

        SUM(Units_Sold) AS annual_demand,

        SUM(Unit_Cost * Inventory_Level)
            AS inventory_value

    FROM inventory_raw
    GROUP BY
        SKU_ID,
        Warehouse_ID
)

SELECT
    SKU_ID,
    Warehouse_ID,

    ROUND(avg_daily_demand, 2)
        AS avg_daily_demand,

    ROUND(avg_inventory, 2)
        AS avg_inventory,

    ROUND(avg_reorder_point, 2)
        AS avg_reorder_point,

    ROUND(
        avg_inventory /
        NULLIF(avg_daily_demand, 0),
        2
    ) AS days_of_cover,

    ROUND(inventory_value, 2)
        AS inventory_value,

    ROUND(
        annual_demand /
        NULLIF(avg_inventory, 0),
        2
    ) AS inventory_turnover

FROM inventory_profile
ORDER BY inventory_value DESC
LIMIT 20;


-- ============================================================
-- 4. Inventory Coverage Risk
-- ============================================================

WITH inventory_metrics AS (

    SELECT
        SKU_ID,
        Warehouse_ID,

        AVG(Units_Sold) AS avg_daily_demand,
        AVG(Inventory_Level) AS avg_inventory,
        AVG(Supplier_Lead_Time_Days)
            AS avg_lead_time

    FROM inventory_raw

    GROUP BY
        SKU_ID,
        Warehouse_ID
)

SELECT
    SKU_ID,
    Warehouse_ID,

    ROUND(avg_daily_demand, 2)
        AS avg_daily_demand,

    ROUND(avg_inventory, 2)
        AS avg_inventory,

    ROUND(avg_lead_time, 2)
        AS avg_lead_time,

    ROUND(
        avg_inventory /
        NULLIF(avg_daily_demand, 0),
        2
    ) AS days_of_cover,

    ROUND(
        avg_daily_demand * avg_lead_time,
        2
    ) AS lead_time_demand,

    ROUND(
        (
            avg_inventory /
            NULLIF(avg_daily_demand, 0)
        ) - avg_lead_time,
        2
    ) AS cover_above_lead_time,

    CASE
        WHEN
            (
                avg_inventory /
                NULLIF(avg_daily_demand, 0)
            ) < avg_lead_time
            THEN 'Below Lead-Time Coverage'

        WHEN
            (
                avg_inventory /
                NULLIF(avg_daily_demand, 0)
            ) <= avg_lead_time * 2
            THEN 'Balanced Coverage'

        ELSE 'High Coverage'
    END AS coverage_status

FROM inventory_metrics
ORDER BY days_of_cover DESC;


-- ============================================================
-- 5. Inventory Buffer Above Reorder Point
-- ============================================================

WITH inventory_buffer AS (

    SELECT
        SKU_ID,
        Warehouse_ID,

        AVG(Inventory_Level)
            AS avg_inventory,

        AVG(Reorder_Point)
            AS avg_reorder_point,

        AVG(Unit_Cost)
            AS avg_unit_cost

    FROM inventory_raw

    GROUP BY
        SKU_ID,
        Warehouse_ID
)

SELECT
    SKU_ID,
    Warehouse_ID,

    ROUND(avg_inventory, 2)
        AS avg_inventory,

    ROUND(avg_reorder_point, 2)
        AS avg_reorder_point,

    ROUND(
        avg_inventory - avg_reorder_point,
        2
    ) AS inventory_buffer_units,

    ROUND(
        (
            avg_inventory - avg_reorder_point
        ) * avg_unit_cost,
        2
    ) AS buffer_value,

    CASE
        WHEN avg_inventory < avg_reorder_point
            THEN 'Below Reorder Point'

        WHEN avg_inventory <= avg_reorder_point * 1.25
            THEN 'Tight Buffer'

        WHEN avg_inventory <= avg_reorder_point * 1.50
            THEN 'Healthy Buffer'

        ELSE 'High Buffer'
    END AS buffer_status

FROM inventory_buffer
ORDER BY buffer_value DESC;


-- ============================================================
-- 6. Working Capital Concentration
-- ============================================================

WITH sku_inventory AS (

    SELECT
        SKU_ID,

        SUM(Unit_Cost * Inventory_Level)
            AS inventory_value

    FROM inventory_raw
    GROUP BY SKU_ID
),

ranked_inventory AS (

    SELECT
        SKU_ID,
        inventory_value,

        SUM(inventory_value) OVER ()
            AS total_inventory_value,

        SUM(inventory_value) OVER (
            ORDER BY inventory_value DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS cumulative_inventory_value

    FROM sku_inventory
)

SELECT
    SKU_ID,

    ROUND(inventory_value, 2)
        AS inventory_value,

    ROUND(
        100 * inventory_value /
        total_inventory_value,
        2
    ) AS inventory_value_percentage,

    ROUND(
        100 * cumulative_inventory_value /
        total_inventory_value,
        2
    ) AS cumulative_value_percentage,

    CASE
        WHEN
            cumulative_inventory_value /
            total_inventory_value <= 0.80
            THEN 'A - High Value'

        WHEN
            cumulative_inventory_value /
            total_inventory_value <= 0.95
            THEN 'B - Medium Value'

        ELSE 'C - Low Value'
    END AS value_segment

FROM ranked_inventory
ORDER BY inventory_value DESC;


-- ============================================================
-- 7. Replenishment Efficiency
-- ============================================================

WITH replenishment AS (

    SELECT
        SKU_ID,
        Warehouse_ID,

        SUM(Units_Sold) AS total_demand,

        SUM(Order_Quantity) AS total_replenished,

        SUM(Order_Quantity > 0)
            AS replenishment_events,

        AVG(Supplier_Lead_Time_Days)
            AS avg_lead_time

    FROM inventory_raw

    GROUP BY
        SKU_ID,
        Warehouse_ID
)

SELECT
    SKU_ID,
    Warehouse_ID,

    ROUND(total_demand, 0)
        AS total_demand,

    ROUND(total_replenished, 0)
        AS total_replenished,

    replenishment_events,

    ROUND(avg_lead_time, 2)
        AS avg_lead_time,

    ROUND(
        total_replenished /
        NULLIF(total_demand, 0),
        3
    ) AS replenishment_to_demand_ratio,

    CASE
        WHEN
            total_replenished /
            NULLIF(total_demand, 0) < 0.90
            THEN 'Potential Under-Replenishment'

        WHEN
            total_replenished /
            NULLIF(total_demand, 0) <= 1.05
            THEN 'Balanced'

        ELSE 'Potential Over-Replenishment'
    END AS replenishment_status

FROM replenishment
ORDER BY replenishment_to_demand_ratio DESC;


-- ============================================================
-- 8. Inventory Priority Ranking
-- ============================================================

WITH inventory_metrics AS (

    SELECT
        SKU_ID,
        Warehouse_ID,

        AVG(Units_Sold)
            AS avg_daily_demand,

        AVG(Inventory_Level)
            AS avg_inventory,

        AVG(Reorder_Point)
            AS avg_reorder_point,

        AVG(Supplier_Lead_Time_Days)
            AS avg_lead_time,

        SUM(Unit_Cost * Inventory_Level)
            AS inventory_value

    FROM inventory_raw

    GROUP BY
        SKU_ID,
        Warehouse_ID
),

scored AS (

    SELECT
        *,
        
        avg_inventory /
        NULLIF(avg_daily_demand, 0)
            AS days_of_cover,

        CASE
            WHEN
                avg_inventory /
                NULLIF(avg_daily_demand, 0)
                > avg_lead_time * 2
                THEN 2

            WHEN
                avg_inventory /
                NULLIF(avg_daily_demand, 0)
                > avg_lead_time
                THEN 1

            ELSE 0
        END AS coverage_risk_score,

        CASE
            WHEN avg_inventory > avg_reorder_point * 1.5
                THEN 2

            WHEN avg_inventory > avg_reorder_point
                THEN 1

            ELSE 0
        END AS buffer_score

    FROM inventory_metrics
)

SELECT
    SKU_ID,
    Warehouse_ID,

    ROUND(avg_daily_demand, 2)
        AS avg_daily_demand,

    ROUND(avg_inventory, 2)
        AS avg_inventory,

    ROUND(days_of_cover, 2)
        AS days_of_cover,

    ROUND(avg_lead_time, 2)
        AS avg_lead_time,

    ROUND(avg_reorder_point, 2)
        AS avg_reorder_point,

    ROUND(inventory_value, 2)
        AS inventory_value,

    coverage_risk_score + buffer_score
        AS inventory_priority_score,

    CASE
        WHEN coverage_risk_score + buffer_score >= 3
            THEN 'High Priority'

        WHEN coverage_risk_score + buffer_score = 2
            THEN 'Medium Priority'

        ELSE 'Low Priority'
    END AS management_priority

FROM scored
ORDER BY
    inventory_priority_score DESC,
    inventory_value DESC;